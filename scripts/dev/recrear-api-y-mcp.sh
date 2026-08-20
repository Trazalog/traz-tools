#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Recrea la API "Trazalog MCP API" desde cero y despues el MCP Server.
#
#  POR QUE: todo apunta a que las URL mappings de la API en la base quedaron
#  con las 9 operaciones originales aunque la definicion tenga 17. Recrear el
#  MCP Server no lo arregla (probado con artefacto, nombre y contexto nuevos);
#  hay que recrear LA API para que las 17 filas se inserten juntas.
#
#  ES DESTRUCTIVO SOBRE LA API DE PRODUCCION.
#  - Exporta un backup ANTES de borrar nada.
#  - Dry-run por defecto: sin --apply solo muestra el plan.
#  - Si algo falla a mitad, el backup permite reimportar la API tal cual estaba.
#
#  USO:
#     bash recrear-api-y-mcp.sh              # plan, no toca nada
#     bash recrear-api-y-mcp.sh --apply
# ---------------------------------------------------------------------------
set -u
ENV="${APICTL_ENV:-prod}"
API_NAME="${API_NAME:-Trazalog MCP API}"
API_VER="${API_VER:-1.0.0}"
MCP_NAME="${MCP_NAME:-Trazalog MCP}"
MCP_VER="${MCP_VER:-1.0}"
APPLY="${1:-}"
H="${APIM_HOST:-localhost}"; U="${APIM_USER:-admin}"; P="${APIM_PASS:-admin}"
STAMP=$(date +%Y%m%d-%H%M%S)
BK="/root/mcp-backup-$STAMP"; mkdir -p "$BK"

command -v apictl >/dev/null || { echo "falta apictl"; exit 2; }

tok() {
  local reg ck cs
  reg=$(curl -s -k -X POST "https://$H:9443/client-registration/v0.17/register" -u "$U:$P" \
    -H "Content-Type: application/json" \
    -d '{"callbackUrl":"http://localhost","clientName":"recrear","owner":"'"$U"'","grantType":"client_credentials password refresh_token","saasApp":true}')
  ck=$(echo "$reg"|python3 -c "import sys,json;print(json.load(sys.stdin)['clientId'])")
  cs=$(echo "$reg"|python3 -c "import sys,json;print(json.load(sys.stdin)['clientSecret'])")
  curl -s -k -X POST "https://$H:9443/oauth2/token" -u "$ck:$cs" \
    -d "grant_type=password&username=$U&password=$P&scope=apim:api_view apim:api_create apim:api_publish apim:api_manage apim:mcp_server_view apim:mcp_server_create apim:mcp_server_publish apim:mcp_server_manage" \
    |python3 -c "import sys,json;print(json.load(sys.stdin)['access_token'])"
}
TOKEN=$(tok); B="https://$H:9443/api/am/publisher/v4"
[ -z "$TOKEN" ] && { echo "no se pudo obtener token"; exit 2; }

echo "############################################################"
echo "  API      : $API_NAME v$API_VER"
echo "  MCP      : $MCP_NAME v$MCP_VER"
echo "  entorno  : $ENV     backups en: $BK"
echo "  modo     : $([ "$APPLY" = "--apply" ] && echo 'APLICAR (destructivo)' || echo 'dry-run')"
echo "############################################################"
echo

echo "=== 0. estado actual ==="
curl -s -k "$B/apis" -H "Authorization: Bearer $TOKEN" | python3 -c "
import sys,json
for a in json.load(sys.stdin).get('list',[]):
    print(f\"  API  {a['id']}  {a['name']:22} v{a['version']:8} ctx={a.get('context')}\")"
curl -s -k "$B/mcp-servers" -H "Authorization: Bearer $TOKEN" | python3 -c "
import sys,json
for a in json.load(sys.stdin).get('list',[]):
    print(f\"  MCP  {a['id']}  {a['name']:22} v{a['version']:8} ctx={a.get('context')}\")"
echo

if [ "$APPLY" != "--apply" ]; then
  echo "PLAN (con --apply se ejecuta):"
  echo "  1. exportar la API y el MCP Server a $BK"
  echo "  2. borrar el MCP Server"
  echo "  3. borrar la API"
  echo "  4. importar la API desde el backup (las 17 URL mappings se insertan juntas)"
  echo "  5. desplegar revision de la API"
  echo "  6. importar el MCP Server, con el apiId nuevo ya corregido en el YAML"
  echo "  7. desplegar revision del MCP Server"
  echo "  8. verificar el mapping"
  echo
  echo "  Despues, a mano: Publish del MCP Server y suscribir la app en el DevPortal."
  exit 0
fi

echo "=== 1. backups ==="
apictl export api -n "$API_NAME" -v "$API_VER" -e "$ENV" 2>&1 | tail -2
apictl export mcp-server -n "$MCP_NAME" -v "$MCP_VER" -e "$ENV" 2>&1 | tail -2
cp -v "$HOME/.wso2apictl/exported/apis/$ENV/"*.zip "$BK/" 2>/dev/null
cp -v "$HOME/.wso2apictl/exported/mcp-servers/$ENV/"*.zip "$BK/" 2>/dev/null
APIZIP=$(ls -1 "$BK"/*.zip | grep -i "MCP API" | head -1)
[ -z "${APIZIP:-}" ] && { echo "no se encontro el backup de la API — se aborta"; exit 2; }
echo "  backup de la API: $APIZIP"

echo
echo "=== 2-3. borrar MCP Server y API ==="
apictl delete mcp-server -n "$MCP_NAME" -v "$MCP_VER" -e "$ENV" 2>&1 | tail -2
sleep 2
apictl delete api -n "$API_NAME" -v "$API_VER" -e "$ENV" 2>&1 | tail -2
sleep 3

echo
echo "=== 4. importar la API de cero ==="
apictl import api -f "$APIZIP" -e "$ENV" --preserve-provider=true --rotate-revision 2>&1 | tail -5
sleep 3
NEWAPI=$(curl -s -k "$B/apis" -H "Authorization: Bearer $TOKEN" | python3 -c "
import sys,json
for a in json.load(sys.stdin).get('list',[]):
    if a['name']=='''$API_NAME''': print(a['id']); break")
[ -z "${NEWAPI:-}" ] && { echo "la API no aparece despues del import — revisar"; exit 2; }
echo "  apiId nuevo: $NEWAPI"
N=$(curl -s -k "$B/apis/$NEWAPI" -H "Authorization: Bearer $TOKEN" | python3 -c "
import sys,json;print(len(json.load(sys.stdin).get('operations',[])))")
echo "  operaciones: $N (deberian ser 17)"

echo
echo "=== 5. desplegar revision de la API ==="
python3 - "$B" "$TOKEN" "$NEWAPI" "$H" <<'PY'
import json,subprocess,sys
B,TK,ID,H = sys.argv[1:5]
def c(a,d=None):
    cmd=["curl","-sS","-k"]+a+(["-d",d] if d else [])
    return subprocess.run(cmd,capture_output=True,text=True).stdout
auth=["-H",f"Authorization: Bearer {TK}"]
r=json.loads(c(["-X","POST",f"{B}/apis/{ID}/revisions","-H","Content-Type: application/json"]+auth,
               json.dumps({"description":"recreada con 17 recursos"})))
rid=r.get("id")
if not rid: print("  no se pudo crear la revision:",json.dumps(r)[:200]); sys.exit(1)
envs=json.loads(c([f"https://{H}:9443/api/am/admin/v4/environments"]+auth)).get("list",[])
gw=envs[0] if envs else {"name":"Default","vhosts":[{"host":H}]}
body=[{"name":gw["name"],"vhost":(gw.get("vhosts") or [{"host":H}])[0]["host"],"displayOnDevportal":True}]
c(["-X","POST",f"{B}/apis/{ID}/deploy-revision?revisionId={rid}","-H","Content-Type: application/json"]+auth,
  json.dumps(body))
print("  revision desplegada")
PY
sleep 3

echo
echo "=== 6. importar el MCP Server con el apiId nuevo ==="
MCPZIP=$(ls -1 "$BK"/*.zip | grep -iv "MCP API" | head -1)
[ -z "${MCPZIP:-}" ] && { echo "no hay backup del MCP Server"; exit 2; }
W=/tmp/mcp-recrear; rm -rf $W; mkdir -p $W/src
unzip -qo "$MCPZIP" -d $W/src
YML=$(find $W/src -name mcp_server.yaml | head -1)
python3 - "$YML" "$NEWAPI" <<'PY'
import sys,yaml
p,newid=sys.argv[1],sys.argv[2]
doc=yaml.safe_load(open(p,encoding='utf-8')); d=doc.get("data",doc)
d.pop("id",None); d["lifeCycleStatus"]="CREATED"
n=0
for o in d.get("operations",[]):
    m=o.get("apiOperationMapping")
    if m: m["apiId"]=newid; n+=1
print(f"  apiId actualizado en {n} tools")
yaml.safe_dump(doc,open(p,"w",encoding='utf-8'),allow_unicode=True,sort_keys=False)
PY
NZ="$W/mcp.zip"; ( cd $W/src && zip -qr "$NZ" . )
apictl import mcp-server -f "$NZ" -e "$ENV" --rotate-revision 2>&1 | tail -5
sleep 3

echo
echo "=== 7-8. verificar ==="
curl -s -k "$B/mcp-servers" -H "Authorization: Bearer $TOKEN" | python3 -c "
import sys,json
l=json.load(sys.stdin).get('list',[])
print(f'  {len(l)} MCP Server(s)')
for a in l: print(f\"    {a['id']}  {a['name']}  ctx={a.get('context')}\")"
MID=$(curl -s -k "$B/mcp-servers" -H "Authorization: Bearer $TOKEN" | python3 -c "
import sys,json;l=json.load(sys.stdin).get('list',[]);print(l[0]['id'] if l else '')")
[ -n "$MID" ] && curl -s -k "$B/mcp-servers/$MID" -H "Authorization: Bearer $TOKEN" | python3 -c "
import sys,json
d=json.load(sys.stdin); ops=d.get('operations',[])
bad=[o['target'] for o in ops if not o.get('apiOperationMapping')]
print(f'  {len(ops)} tools — sin mapping: {len(bad)}')
[print('    -',b) for b in bad]
print('  *** TODAS MAPEADAS ***' if not bad else '  el problema persiste')"

echo
echo "FALTA A MANO:"
echo "  - Publisher: Deploy del MCP Server (si no quedo desplegado) y Publish"
echo "  - DevPortal: suscribir la aplicacion al MCP Server"
echo "  - backups en $BK  (para volver atras: apictl import api -f <zip> -e $ENV)"
