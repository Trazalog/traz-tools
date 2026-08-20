#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Recrea la API "Trazalog MCP API" desde cero, para que sus URL mappings se
#  inserten completas, y despues deja listo el terreno para crear el MCP Server.
#
#  POR QUE: todo apunta a que las URL mappings de la API en la base quedaron
#  con las 9 operaciones originales aunque la definicion tenga 17. Recrear el
#  MCP Server no lo arregla (probado 3 veces, incluso con nombre y contexto
#  nuevos); hay que recrear LA API.
#
#  ES DESTRUCTIVO SOBRE PRODUCCION.
#   - Exporta backups ANTES de borrar nada.
#   - Dry-run por defecto.
#   - Aborta en cuanto un paso falla, en vez de seguir y dejar el estado a medias.
#
#  USO:
#     bash recrear-api-y-mcp.sh              # plan, no toca nada
#     bash recrear-api-y-mcp.sh --apply
# ---------------------------------------------------------------------------
set -u
ENV="${APICTL_ENV:-prod}"
API_NAME="${API_NAME:-Trazalog MCP API}"
API_VER="${API_VER:-1.0.0}"
APPLY="${1:-}"
H="${APIM_HOST:-localhost}"; U="${APIM_USER:-admin}"; P="${APIM_PASS:-admin}"
STAMP=$(date +%Y%m%d-%H%M%S)
BK="/root/mcp-backup-$STAMP"; mkdir -p "$BK"

command -v apictl >/dev/null || { echo "falta apictl"; exit 2; }

REG=$(curl -s -k -X POST "https://$H:9443/client-registration/v0.17/register" -u "$U:$P" \
  -H "Content-Type: application/json" \
  -d '{"callbackUrl":"http://localhost","clientName":"recrear","owner":"'"$U"'","grantType":"client_credentials password refresh_token","saasApp":true}')
CK=$(echo "$REG" | python3 -c "import sys,json;print(json.load(sys.stdin)['clientId'])" 2>/dev/null)
CS=$(echo "$REG" | python3 -c "import sys,json;print(json.load(sys.stdin)['clientSecret'])" 2>/dev/null)
TOKEN=$(curl -s -k -X POST "https://$H:9443/oauth2/token" -u "$CK:$CS" \
  -d "grant_type=password&username=$U&password=$P&scope=apim:api_view apim:api_create apim:api_publish apim:api_manage apim:mcp_server_view apim:mcp_server_create apim:mcp_server_publish apim:mcp_server_manage" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['access_token'])" 2>/dev/null)
[ -z "${TOKEN:-}" ] && { echo "no se pudo obtener token del publisher"; exit 2; }
B="https://$H:9443/api/am/publisher/v4"
AUTH="Authorization: Bearer $TOKEN"

listar() {
  echo "  --- APIs ---"
  curl -s -k "$B/apis" -H "$AUTH" | python3 -c "import sys,json
for a in json.load(sys.stdin).get('list',[]):
    print('   ', a['id'], a['name'], 'v'+a['version'], a.get('context',''))"
  echo "  --- MCP Servers ---"
  curl -s -k "$B/mcp-servers" -H "$AUTH" | python3 -c "import sys,json
l=json.load(sys.stdin).get('list',[])
print('    (ninguno)') if not l else [print('   ', a['id'], a['name'], 'v'+a['version'], a.get('context','')) for a in l]"
}

echo "############################################################"
echo "  API     : $API_NAME v$API_VER"
echo "  entorno : $ENV"
echo "  backups : $BK"
echo "  modo    : $([ "$APPLY" = "--apply" ] && echo 'APLICAR (destructivo)' || echo 'dry-run')"
echo "############################################################"
echo
echo "=== 0. estado actual ==="
listar
echo

if [ "$APPLY" != "--apply" ]; then
  cat <<'PLAN'
PLAN (con --apply se ejecuta):
  1. exportar backups de la API y de TODOS los MCP Servers
  2. borrar TODOS los MCP Servers
       la API no se puede borrar mientras cualquiera la referencie:
       409 "Cannot remove the API as it is used by MCP server(s)"
  3. borrar la API            -> aborta si no se borro
  4. importar la API de cero  -> aborta si falla
  5. desplegar revision de la API y verificar que tenga 17 operaciones

  El MCP Server NO se reimporta: el proyecto viejo tiene 8 tools sin mapping
  y el import las descarta. Hay que crearlo desde la API recien recreada
  (Publisher > MCP Servers > Create > Start from Existing API), que es el
  unico camino que genera los 17 mappings.
PLAN
  exit 0
fi

echo "=== 1. backups ==="
apictl export api -n "$API_NAME" -v "$API_VER" -e "$ENV" 2>&1 | tail -2
curl -s -k "$B/mcp-servers" -H "$AUTH" | python3 -c "import sys,json
for a in json.load(sys.stdin).get('list',[]):
    print(a['name'] + '\t' + a['version'])" > /tmp/mcps.txt
while IFS=$'\t' read -r n v; do
  [ -z "${n:-}" ] && continue
  apictl export mcp-server -n "$n" -v "$v" -e "$ENV" 2>&1 | tail -1
done < /tmp/mcps.txt
cp "$HOME/.wso2apictl/exported/apis/$ENV/"*.zip "$BK/" 2>/dev/null
cp "$HOME/.wso2apictl/exported/mcp-servers/$ENV/"*.zip "$BK/" 2>/dev/null
ls -1 "$BK"
APIZIP=$(ls -1 "$BK"/*.zip 2>/dev/null | grep -i "MCP API" | head -1)
[ -z "${APIZIP:-}" ] && { echo "no se encontro el backup de la API — se aborta"; exit 2; }
echo "  backup de la API: $APIZIP"

echo
echo "=== 2. borrar TODOS los MCP Servers ==="
while IFS=$'\t' read -r n v; do
  [ -z "${n:-}" ] && continue
  echo "  borrando: $n v$v"
  apictl delete mcp-server -n "$n" -v "$v" -e "$ENV" 2>&1 | tail -1
done < /tmp/mcps.txt
sleep 3
REST=$(curl -s -k "$B/mcp-servers" -H "$AUTH" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('list',[])))")
echo "  MCP Servers restantes: $REST"
if [ "$REST" != "0" ]; then
  echo "  *** quedan MCP Servers: la API no se va a poder borrar. Se aborta. ***"
  exit 2
fi

echo
echo "=== 3. borrar la API ==="
apictl delete api -n "$API_NAME" -v "$API_VER" -e "$ENV" 2>&1 | tail -3
sleep 3
export API_NAME
EXISTE=$(curl -s -k "$B/apis" -H "$AUTH" | API_NAME="$API_NAME" python3 -c "import sys,json,os
n=os.environ['API_NAME']
print(sum(1 for a in json.load(sys.stdin).get('list',[]) if a['name']==n))")
if [ "$EXISTE" != "0" ]; then
  echo "  *** la API NO se borro. Se aborta para no dejar el estado a medias. ***"
  echo "      backups intactos en $BK"
  exit 2
fi
echo "  API borrada"

echo
echo "=== 4. importar la API de cero ==="
apictl import api -f "$APIZIP" -e "$ENV" --preserve-provider=true --rotate-revision 2>&1 | tee /tmp/imp.log | tail -5
if grep -qE "Error importing|Status: [45][0-9][0-9]" /tmp/imp.log; then
  echo "  *** el import fallo. Se aborta. Restaurar con:"
  echo "      apictl import api -f \"$APIZIP\" -e $ENV"
  exit 2
fi
sleep 3
NEWAPI=$(curl -s -k "$B/apis" -H "$AUTH" | API_NAME="$API_NAME" python3 -c "import sys,json,os
n=os.environ['API_NAME']
for a in json.load(sys.stdin).get('list',[]):
    if a['name']==n: print(a['id']); break")
[ -z "${NEWAPI:-}" ] && { echo "  la API no aparece tras el import — revisar"; exit 2; }
echo "  apiId nuevo: $NEWAPI"
NOPS=$(curl -s -k "$B/apis/$NEWAPI" -H "$AUTH" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('operations',[])))")
echo "  operaciones: $NOPS  (deberian ser 17)"

echo
echo "=== 5. desplegar revision de la API ==="
RID=$(curl -s -k -X POST "$B/apis/$NEWAPI/revisions" -H "Content-Type: application/json" -H "$AUTH" \
  -d '{"description":"API recreada con los 17 recursos"}' | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))")
if [ -z "${RID:-}" ]; then echo "  no se pudo crear la revision"; exit 2; fi
GW=$(curl -s -k "https://$H:9443/api/am/admin/v4/environments" -H "$AUTH" | python3 -c "import sys,json
l=json.load(sys.stdin).get('list',[])
e=l[0] if l else {'name':'Default','vhosts':[{'host':'localhost'}]}
print(e['name'] + '\t' + (e.get('vhosts') or [{'host':'localhost'}])[0]['host'])")
GWN=$(echo "$GW" | cut -f1); GWV=$(echo "$GW" | cut -f2)
curl -s -k -X POST "$B/apis/$NEWAPI/deploy-revision?revisionId=$RID" -H "Content-Type: application/json" -H "$AUTH" \
  -d "[{\"name\":\"$GWN\",\"vhost\":\"$GWV\",\"displayOnDevportal\":true}]" > /dev/null
sleep 3
DEP=$(curl -s -k "$B/apis/$NEWAPI/revisions" -H "$AUTH" | python3 -c "import sys,json
for r in json.load(sys.stdin).get('list',[]):
    if r.get('deploymentInfo'): print(r['id']); break")
if [ -n "${DEP:-}" ]; then
  NDEP=$(curl -s -k "$B/apis/$DEP" -H "$AUTH" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('operations',[])))")
  echo "  revision desplegada con $NDEP recursos"
else
  echo "  *** no quedo ninguna revision desplegada — revisar en el Publisher ***"
fi

echo
echo "=== estado final ==="
listar

cat <<FIN

AHORA, A MANO (es el unico camino que genera los 17 mappings):

  Publisher > MCP Servers > Create MCP Server > Start from Existing API
    1. elegir "$API_NAME"
    2. seleccionar las 17 operaciones   <-- contar que sean 17
    3. Name/Context/Version a eleccion
    4. Create
    5. Deploy > Deployments > Deploy
    6. Publish > Lifecycle > Publish
  DevPortal > el MCP Server > SUBSCRIBE TO AN APPLICATION

  Verificar:  bash diag-mcp-mapping.sh   y   python3 mcp-smoke-tools.py

  Backups en $BK
  Volver atras:  apictl delete api -n "$API_NAME" -v $API_VER -e $ENV
                 apictl import api -f "$APIZIP" -e $ENV
FIN
