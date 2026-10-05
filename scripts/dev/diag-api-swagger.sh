#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  El APIM guarda DOS cosas distintas para una API:
#    - operations / URL mappings  (lo que devuelve GET /apis/{id})
#    - la definicion OpenAPI      (GET /apis/{id}/swagger)
#  Pueden estar desincronizadas. findMatchingTemplate trabaja sobre las
#  URITemplates, que se derivan de la definicion.
#
#  Este script compara las dos.  SOLO LEE.
# ---------------------------------------------------------------------------
set -u
H="${APIM_HOST:-localhost}"; U="${APIM_USER:-admin}"; P="${APIM_PASS:-admin}"
AID="${API_ID:-fde905d1-8e04-48f8-95a3-ee691319c965}"

REG=$(curl -s -k -X POST "https://$H:9443/client-registration/v0.17/register" -u "$U:$P" \
  -H "Content-Type: application/json" \
  -d '{"callbackUrl":"http://localhost","clientName":"sw_diag","owner":"'"$U"'","grantType":"client_credentials password refresh_token","saasApp":true}')
CK=$(echo "$REG"|python3 -c "import sys,json;print(json.load(sys.stdin)['clientId'])")
CS=$(echo "$REG"|python3 -c "import sys,json;print(json.load(sys.stdin)['clientSecret'])")
TOKEN=$(curl -s -k -X POST "https://$H:9443/oauth2/token" -u "$CK:$CS" \
  -d "grant_type=password&username=$U&password=$P&scope=apim:api_view apim:api_manage apim:mcp_server_view apim:mcp_server_manage" \
  |python3 -c "import sys,json;print(json.load(sys.stdin)['access_token'])")
B="https://$H:9443/api/am/publisher/v4"

echo "=== A) operations / URL mappings de la API ==="
curl -s -k "$B/apis/$AID" -H "Authorization: Bearer $TOKEN" \
 | python3 -c "
import sys,json
a=json.load(sys.stdin)
ops=sorted((o['verb'],o['target']) for o in a.get('operations',[]))
print(f'  {len(ops)} operations')
for v,t in ops: print(f'    {v:6} {t}')
" > /tmp/A.txt; cat /tmp/A.txt

echo
echo "=== B) definicion OpenAPI guardada en la API ==="
curl -s -k "$B/apis/$AID/swagger" -H "Authorization: Bearer $TOKEN" > /tmp/api-swagger.json
python3 -c "
import json
try:
    d=json.load(open('/tmp/api-swagger.json'))
except Exception as e:
    print('  no es JSON:', open('/tmp/api-swagger.json').read()[:200]); raise SystemExit
paths=d.get('paths',{})
tot=[(m.upper(),p) for p,v in paths.items() for m in v if m.lower() in ('get','post','put','delete','patch')]
print(f'  {len(tot)} operaciones en la definicion (openapi={d.get(\"openapi\") or d.get(\"swagger\")})')
for v,t in sorted(tot, key=lambda x:x[1]): print(f'    {v:6} {t}')
" > /tmp/B.txt; cat /tmp/B.txt

echo
echo "=== DIFERENCIA (esto es lo que importa) ==="
diff <(grep -E "^    (GET|POST|PUT|DELETE|PATCH)" /tmp/A.txt | awk '{print $1,$2}' | sort) \
     <(grep -E "^    (GET|POST|PUT|DELETE|PATCH)" /tmp/B.txt | awk '{print $1,$2}' | sort) \
  && echo "  A y B coinciden — la definicion NO es el problema" \
  || echo "  << solo en operations   >> solo en la definicion OpenAPI"
echo
echo "Definicion completa en /tmp/api-swagger.json"
