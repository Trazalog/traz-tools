#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Inspecciona el MCP Server por el Publisher REST API y muestra, tool por
#  tool, si tiene apiOperationMapping o viene null.
#
#  Responde la pregunta que la UI no deja contestar (la pantalla Tools
#  revienta por wso2/api-manager#5106): el mapping esta roto EN LA BASE del
#  APIM, o el gateway esta sirviendo una revision vieja?
#
#  SOLO LEE. No hace ningun PUT.
#
#  USO (por SSH en la VM):  bash scripts/dev/diag-mcp-mapping.sh
# ---------------------------------------------------------------------------
set -u
H="${APIM_HOST:-localhost}"
U="${APIM_USER:-admin}"
P="${APIM_PASS:-admin}"

echo "=== 1. token de publisher ==="
REG=$(curl -s -k -X POST "https://$H:9443/client-registration/v0.17/register" \
  -u "$U:$P" -H "Content-Type: application/json" \
  -d '{"callbackUrl":"http://localhost","clientName":"mcp_diag","owner":"'"$U"'","grantType":"client_credentials password refresh_token","saasApp":true}')
CK=$(echo "$REG" | python3 -c "import sys,json;print(json.load(sys.stdin)['clientId'])" 2>/dev/null)
CS=$(echo "$REG" | python3 -c "import sys,json;print(json.load(sys.stdin)['clientSecret'])" 2>/dev/null)
if [ -z "${CK:-}" ]; then echo "  fallo el registro: $REG"; exit 2; fi
TOKEN=$(curl -s -k -X POST "https://$H:9443/oauth2/token" -u "$CK:$CS" \
  -d "grant_type=password&username=$U&password=$P&scope=apim:api_view apim:api_manage apim:mcp_server_view apim:mcp_server_manage" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['access_token'])" 2>/dev/null)
if [ -z "${TOKEN:-}" ]; then echo "  no se pudo obtener token"; exit 2; fi
echo "  ok"
echo

echo "=== 2. MCP Servers publicados ==="
curl -s -k "https://$H:9443/api/am/publisher/v4/mcp-servers" -H "Authorization: Bearer $TOKEN" \
 | python3 -c "
import sys,json
d=json.load(sys.stdin)
for a in d.get('list',[]):
    print(f\"  {a['id']}  {a['name']:28} v{a.get('version','')}  ctx={a.get('context','')}  {a.get('lifeCycleStatus','')}\")
"
echo
ID=$(curl -s -k "https://$H:9443/api/am/publisher/v4/mcp-servers" -H "Authorization: Bearer $TOKEN" \
 | python3 -c "import sys,json;l=json.load(sys.stdin).get('list',[]);print(l[0]['id'] if l else '')")
[ -z "$ID" ] && { echo "no hay MCP Servers"; exit 1; }

echo "=== 3. tool por tool: tiene apiOperationMapping? ==="
curl -s -k "https://$H:9443/api/am/publisher/v4/mcp-servers/$ID" -H "Authorization: Bearer $TOKEN" \
 > /tmp/mcp-server.json
python3 - <<'PY'
import json
d=json.load(open('/tmp/mcp-server.json'))
ops=d.get('operations',[])
print(f"  MCP Server: {d.get('name')} v{d.get('version')}  ctx={d.get('context')}")
print(f"  endpointConfig: {'PRESENTE' if d.get('endpointConfig') else '*** AUSENTE (da 404) ***'}")
print(f"  operaciones: {len(ops)}\n")
ok=bad=0
for o in sorted(ops, key=lambda x: str(x.get('target'))):
    m=o.get('apiOperationMapping')
    if m:
        b=m.get('backendOperation') or {}
        print(f"    OK    {str(o.get('target')):34} {str(o.get('verb') or ''):5} -> {b.get('verb','?')} {b.get('target','?')}  (api={m.get('apiName','?')})")
        ok+=1
    else:
        print(f"    NULL  {str(o.get('target')):34} {str(o.get('verb') or ''):5} -> SIN MAPPING")
        bad+=1
print(f"\n  con mapping: {ok}   |   sin mapping: {bad}")
if bad:
    print("\n  >>> El mapping esta roto EN LA BASE del APIM, no es la revision desplegada.")
    print("      No se repara redesplegando: hay que rehacer esas operaciones.")
PY
echo
echo "=== 3b. LA API FUENTE: tiene los recursos que las tools necesitan? ==="
APIID=$(python3 -c "
import json
d=json.load(open('/tmp/mcp-server.json'))
for o in d.get('operations',[]):
    m=o.get('apiOperationMapping')
    if m: print(m.get('apiId','')); break
")
if [ -z "${APIID:-}" ]; then
  echo "  ninguna tool tiene mapping: no se puede deducir la API fuente"
else
  curl -s -k "https://$H:9443/api/am/publisher/v4/apis/$APIID" -H "Authorization: Bearer $TOKEN" > /tmp/mcp-api-fuente.json
  python3 - <<'PY'
import json
try:
    a=json.load(open('/tmp/mcp-api-fuente.json'))
except Exception:
    print("  no se pudo leer la API fuente"); raise SystemExit
print(f"  API fuente: {a.get('name')} v{a.get('version')}  ctx={a.get('context')}  estado={a.get('lifeCycleStatus')}")
recursos={(o.get('verb'), o.get('target')) for o in a.get('operations',[])}
print(f"  recursos en la API: {len(recursos)}")
d=json.load(open('/tmp/mcp-server.json'))
falt=[]
for o in d.get('operations',[]):
    if o.get('apiOperationMapping'): continue
    falt.append(o.get('target'))
print()
print("  Las 8 tools sin mapping necesitan estos recursos. Estan en la API?")
# heuristica: buscar por nombre de tool en los targets de la API
import re
for t in sorted(falt):
    cand=[r for r in recursos if t.split('_')[-1] in (r[1] or '')]
    print(f"    {t:32} -> {'candidato: '+str(cand[0]) if cand else 'NO HAY RECURSO PARECIDO'}")
print()
print("  Recursos de la API fuente (verb target):")
for v,t in sorted(recursos, key=lambda x:str(x[1])):
    print(f"    {str(v):6} {t}")
PY
fi
echo
echo "=== 4. revisiones y cual esta desplegada ==="
curl -s -k "https://$H:9443/api/am/publisher/v4/mcp-servers/$ID/revisions" -H "Authorization: Bearer $TOKEN" \
 | python3 -c "
import sys,json
for r in json.load(sys.stdin).get('list',[]):
    dep=r.get('deploymentInfo') or []
    where=', '.join(f\"{x.get('name')}({'desplegada' if x.get('status')=='CREATED' or x.get('deployedTime') else '?'})\" for x in dep) or 'NO desplegada'
    print(f\"  rev {r.get('displayName','?'):8} id={r.get('id','')[:8]}  {where}\")
" 2>/dev/null || echo "  (sin revisiones)"
echo
echo "JSON del MCP Server : /tmp/mcp-server.json"
echo "JSON de la API fuente: /tmp/mcp-api-fuente.json"
