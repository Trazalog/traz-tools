#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  El Publisher muestra la WORKING COPY de la API. El gateway sirve la ultima
#  REVISION DESPLEGADA. Pueden diferir: si se agregaron recursos y no se
#  desplego una revision nueva, el Publisher los muestra pero el gateway no
#  los tiene -- y el mapping del MCP Server contra esos recursos queda null.
#
#  Este script compara las dos cosas.  SOLO LEE.
# ---------------------------------------------------------------------------
set -u
H="${APIM_HOST:-localhost}"; U="${APIM_USER:-admin}"; P="${APIM_PASS:-admin}"

REG=$(curl -s -k -X POST "https://$H:9443/client-registration/v0.17/register" -u "$U:$P" \
  -H "Content-Type: application/json" \
  -d '{"callbackUrl":"http://localhost","clientName":"rev_diag","owner":"'"$U"'","grantType":"client_credentials password refresh_token","saasApp":true}')
CK=$(echo "$REG"|python3 -c "import sys,json;print(json.load(sys.stdin)['clientId'])")
CS=$(echo "$REG"|python3 -c "import sys,json;print(json.load(sys.stdin)['clientSecret'])")
TOKEN=$(curl -s -k -X POST "https://$H:9443/oauth2/token" -u "$CK:$CS" \
  -d "grant_type=password&username=$U&password=$P&scope=apim:api_view apim:api_manage apim:mcp_server_view apim:mcp_server_manage" \
  |python3 -c "import sys,json;print(json.load(sys.stdin)['access_token'])")
B="https://$H:9443/api/am/publisher/v4"
AID="fde905d1-8e04-48f8-95a3-ee691319c965"   # Trazalog MCP API

echo "=== WORKING COPY de la API (lo que ves en el Publisher) ==="
curl -s -k "$B/apis/$AID" -H "Authorization: Bearer $TOKEN" \
 | python3 -c "
import sys,json
a=json.load(sys.stdin); ops=a.get('operations',[])
print(f'  {a[\"name\"]} v{a[\"version\"]} — {len(ops)} recursos')
"
echo
echo "=== REVISIONES de la API y cual esta desplegada ==="
curl -s -k "$B/apis/$AID/revisions" -H "Authorization: Bearer $TOKEN" > /tmp/api-revs.json
python3 -c "
import json
d=json.load(open('/tmp/api-revs.json'))
for r in d.get('list',[]):
    dep=r.get('deploymentInfo') or []
    est=', '.join(f\"{x.get('name')} desplegada {x.get('deployedTime','')}\" for x in dep) or 'NO desplegada'
    print(f\"  {r.get('displayName','?'):12} id={r.get('id','')[:8]}  creada={r.get('createdTime','')[:19]}  {est}\")
"
echo
echo "=== RECURSOS DE LA REVISION DESPLEGADA (lo que realmente sirve el gateway) ==="
RID=$(python3 -c "
import json
d=json.load(open('/tmp/api-revs.json'))
for r in d.get('list',[]):
    if r.get('deploymentInfo'): print(r['id']); break
")
if [ -z "${RID:-}" ]; then
  echo "  *** NINGUNA revision de la API esta desplegada ***"
else
  curl -s -k "$B/apis/$RID" -H "Authorization: Bearer $TOKEN" \
   | python3 -c "
import sys,json
a=json.load(sys.stdin); ops=a.get('operations',[])
print(f'  revision con {len(ops)} recursos:')
for o in sorted(ops,key=lambda x:str(x.get('target'))):
    print(f\"    {str(o.get('verb')):6} {o.get('target')}\")
"
fi
echo
echo "  Si la working copy tiene 17 y la revision desplegada tiene menos,"
echo "  esa es la causa: hay que desplegar una revision NUEVA de la API"
echo "  ANTES de reparar el mapping del MCP Server."
