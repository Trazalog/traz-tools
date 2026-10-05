#!/usr/bin/env bash
# =============================================================================
# probe-discovery-chain.sh — Valida los 13 pasos del flujo OAuth 2.1 discovery
#
# Ejecuta cada paso del flujo que Claude.ai haría automáticamente:
#   1-2:  Gatillo del discovery (401 + WWW-Authenticate)
#   3-5:  PRM discovery (RFC 9728 path-based + host-based)
#   6-7:  AS metadata discovery (RFC 8414)
#   8-9:  Dynamic Client Registration (RFC 7591)
#   10-11: OAuth PKCE flow (automatizado con JWT de prueba de Dnato)
#   12-13: MCP call con JWT válido
#
# IMPORTANTE: Si este probe pasa los 13 pasos pero el botón Connect de Claude.ai
# falla, documentar como "servidor correcto, posible bug del cliente web"
# y probar desde Claude Code CLI / Claude Desktop.
#
# USO:
#   NGROK_APIM_URL=https://ea79-35-237-63-54.ngrok-free.app \
#   NGROK_DNATO_URL=https://3928-35-237-63-54.ngrok-free.app \
#   bash tests/oauth/probe-discovery-chain.sh
#
# Las URLs ngrok pueden autodescubrirse desde la API local de ngrok si no se
# proporcionan como variables de entorno.
# =============================================================================

set -euo pipefail

# ─── Configuración ────────────────────────────────────────────────────────────

DNATO_PRIVATE_KEY="${DNATO_PRIVATE_KEY:-/mnt/win/dev/git/traz-comp-dnato/application/config/keys/jwt_private.pem}"
EMPR_ID="${EMPR_ID:-1}"
TEST_EMAIL="${TEST_EMAIL:-test@trazalog.com}"
CONSUMER_KEY="z_CtMHRzWPSgY8aXWYxFuzsOli4a"

# ─── Autodescubrimiento de ngrok ──────────────────────────────────────────────

if [[ -z "${NGROK_APIM_URL:-}" ]]; then
    NGROK_APIM_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
for t in d.get('tunnels',[]):
    if ':8280' in t.get('config',{}).get('addr',''):
        u=t.get('public_url','')
        if u.startswith('https://'): print(u); break
" 2>/dev/null)
fi
if [[ -z "${NGROK_DNATO_URL:-}" ]]; then
    NGROK_DNATO_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
for t in d.get('tunnels',[]):
    addr=t.get('config',{}).get('addr','')
    if ':80' in addr or addr=='80':
        u=t.get('public_url','')
        if u.startswith('https://'): print(u); break
" 2>/dev/null)
fi

if [[ -z "$NGROK_APIM_URL" || -z "$NGROK_DNATO_URL" ]]; then
    echo "ERROR: No se encontraron túneles ngrok. Asegurarse de que ngrok esté corriendo."
    echo "  Manual: export NGROK_APIM_URL=https://... NGROK_DNATO_URL=https://..."
    exit 1
fi

MCP_URL="${NGROK_APIM_URL}/trazalog-equipos/1.0/mcp"
DNATO_BASE="${NGROK_DNATO_URL}/traz-comp-dnato"
DNATO_ISSUER="${DNATO_BASE}/oauth"

PASS=0
FAIL=0

# ─── Helpers ──────────────────────────────────────────────────────────────────

ok()   { echo "  ✓ $*"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $*"; FAIL=$((FAIL+1)); }
step() { echo ""; echo "── Paso $1: $2"; }

assert_status() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        ok "HTTP $actual"
    else
        fail "HTTP $actual (esperado: $expected) — $label"
    fi
}

assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        ok "$label"
    else
        fail "$label — no encontrado: '$needle'"
    fi
}

assert_equals() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        ok "$label"
    else
        fail "$label\n    esperado: '$expected'\n    actual:   '$actual'"
    fi
}

# ─── Mint JWT de prueba ───────────────────────────────────────────────────────

mint_jwt() {
    python3 - << PYEOF
import base64, json, subprocess, time
from pathlib import Path

priv = Path("${DNATO_PRIVATE_KEY}")
if not priv.exists():
    print("ERROR: clave privada no encontrada: ${DNATO_PRIVATE_KEY}", flush=True)
    exit(1)

now = int(time.time())
header  = {"alg": "RS256", "typ": "JWT", "kid": "dnato-rs256-v1"}
payload = {
    "iss": "${DNATO_ISSUER}",
    "aud": "trazalog-mcp",
    "iat": now,
    "exp": now + 3600,
    "sub": "${TEST_EMAIL}",
    "email": "${TEST_EMAIL}",
    "empr_id": "${EMPR_ID}",
    "role": "admin",
    "azp": "${CONSUMER_KEY}",
}

def b64(data):
    if isinstance(data, str): data = data.encode()
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

h = b64(json.dumps(header, separators=(',',':')))
p = b64(json.dumps(payload, separators=(',',':')))
si = f"{h}.{p}"
sig = subprocess.run(
    ["openssl", "dgst", "-sha256", "-sign", str(priv)],
    input=si.encode(), capture_output=True, check=True
).stdout
print(f"{si}.{b64(sig)}")
PYEOF
}

# ─── INICIO ───────────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  OAuth 2.1 Discovery Chain Probe — Trazalog MCP"
echo "═══════════════════════════════════════════════════════════════"
echo "  APIM: $NGROK_APIM_URL"
echo "  Dnato: $NGROK_DNATO_URL"
echo "  MCP:  $MCP_URL"
echo ""

# ─── PASO 1: 401 al llamar MCP sin token ─────────────────────────────────────

step 1 "POST $MCP_URL sin token → 401"
RESP1=$(curl -s -i --max-time 10 \
    -X POST "$MCP_URL" \
    -H "Content-Type: application/json" \
    -H "ngrok-skip-browser-warning: true" \
    -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get_equipos","arguments":{}},"id":1}' \
    2>/dev/null)
STATUS1=$(echo "$RESP1" | grep -m1 "^HTTP" | awk '{print $2}')
assert_status "sin token → 401" "401" "$STATUS1"

# ─── PASO 2: WWW-Authenticate bien formado ───────────────────────────────────

step 2 "WWW-Authenticate contiene resource_metadata con URL ngrok APIM"
WWW_AUTH=$(echo "$RESP1" | grep -i "^www-authenticate:" | head -1)
echo "  Header: $WWW_AUTH"
EXPECTED_PRM_URL="${NGROK_APIM_URL}/trazalog-equipos/1.0/.well-known/oauth-protected-resource"
assert_contains "resource_metadata presente" 'resource_metadata=' "$WWW_AUTH"
assert_contains "URL ngrok en resource_metadata" "$EXPECTED_PRM_URL" "$WWW_AUTH"
# Verificar que NO tenga localhost
if echo "$WWW_AUTH" | grep -q "localhost"; then
    fail "WWW-Authenticate contiene 'localhost' — debe ser URL pública ngrok"
else
    ok "No contiene localhost"
fi

# ─── PASO 3: PRM path-based RFC 9728 ─────────────────────────────────────────

step 3 "GET /.well-known/oauth-protected-resource/trazalog-equipos/1.0/mcp (RFC 9728 path-based)"
PRM_PATH_URL="${NGROK_APIM_URL}/.well-known/oauth-protected-resource/trazalog-equipos/1.0/mcp"
PRM_PATH_RESP=$(curl -s -w "\n__STATUS__%{http_code}" --max-time 10 \
    "$PRM_PATH_URL" \
    -H "ngrok-skip-browser-warning: true" 2>/dev/null)
PRM_PATH_STATUS=$(echo "$PRM_PATH_RESP" | grep "__STATUS__" | sed 's/__STATUS__//')
PRM_PATH_BODY=$(echo "$PRM_PATH_RESP" | sed '/__STATUS__/d')
assert_status "PRM path-based" "200" "$PRM_PATH_STATUS"
echo "  Body: $PRM_PATH_BODY"

# ─── PASO 3b: PRM host-based RFC 9728 fallback ───────────────────────────────

step "3b" "GET /.well-known/oauth-protected-resource (RFC 9728 host-based fallback)"
PRM_HOST_URL="${NGROK_APIM_URL}/.well-known/oauth-protected-resource"
PRM_HOST_RESP=$(curl -s -w "\n__STATUS__%{http_code}" --max-time 10 \
    "$PRM_HOST_URL" \
    -H "ngrok-skip-browser-warning: true" 2>/dev/null)
PRM_HOST_STATUS=$(echo "$PRM_HOST_RESP" | grep "__STATUS__" | sed 's/__STATUS__//')
assert_status "PRM host-based" "200" "$PRM_HOST_STATUS"

# ─── PASO 4: resource field exacto ───────────────────────────────────────────

step 4 "PRM: campo 'resource' coincide EXACTAMENTE con la URL del MCP connector"
PRM_RESOURCE=$(echo "$PRM_PATH_BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('resource',''))" 2>/dev/null)
echo "  resource: $PRM_RESOURCE"
echo "  esperado: $MCP_URL"
assert_equals "'resource' exacto" "$MCP_URL" "$PRM_RESOURCE"

# ─── PASO 5: authorization_servers[0] = Dnato ────────────────────────────────

step 5 "PRM: authorization_servers[0] = Dnato (primer elemento, el que usa Claude)"
PRM_AS0=$(echo "$PRM_PATH_BODY" | python3 -c "
import sys,json
d=json.load(sys.stdin)
servers=d.get('authorization_servers',[])
print(servers[0] if servers else 'EMPTY')
" 2>/dev/null)
EXPECTED_AS="$DNATO_ISSUER"
echo "  authorization_servers[0]: $PRM_AS0"
echo "  esperado: $EXPECTED_AS"
assert_equals "authorization_servers[0] exacto" "$EXPECTED_AS" "$PRM_AS0"

# ─── PASO 6: AS metadata de Dnato ────────────────────────────────────────────

step 6 "GET AS metadata RFC 8414 desde Dnato"
AS_META_URL="${DNATO_ISSUER}/.well-known/oauth-authorization-server"
AS_META_RESP=$(curl -s -w "\n__STATUS__%{http_code}" --max-time 10 \
    "$AS_META_URL" \
    -H "ngrok-skip-browser-warning: true" 2>/dev/null)
AS_META_STATUS=$(echo "$AS_META_RESP" | grep "__STATUS__" | sed 's/__STATUS__//')
AS_META_BODY=$(echo "$AS_META_RESP" | sed '/__STATUS__/d')
assert_status "AS metadata" "200" "$AS_META_STATUS"
echo "  Body: $AS_META_BODY"

# ─── PASO 7: registration_endpoint presente ──────────────────────────────────

step 7 "AS metadata contiene registration_endpoint"
REG_ENDPOINT=$(echo "$AS_META_BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('registration_endpoint','MISSING'))" 2>/dev/null)
echo "  registration_endpoint: $REG_ENDPOINT"
if [[ "$REG_ENDPOINT" == "MISSING" || -z "$REG_ENDPOINT" ]]; then
    fail "registration_endpoint ausente en AS metadata"
else
    ok "registration_endpoint presente: $REG_ENDPOINT"
fi
EXPECTED_REG="${DNATO_BASE}/oauth/register"
assert_equals "registration_endpoint exacto" "$EXPECTED_REG" "$REG_ENDPOINT"

# ─── PASO 8: DCR — registro de cliente ───────────────────────────────────────

step 8 "POST $REG_ENDPOINT (RFC 7591 DCR) → 201 con client_id"
DCR_RESP=$(curl -s -w "\n__STATUS__%{http_code}" --max-time 10 \
    -X POST "$REG_ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "ngrok-skip-browser-warning: true" \
    -d '{"redirect_uris":["https://claude.ai/oauth/callback"],"grant_types":["authorization_code"],"response_types":["code"],"token_endpoint_auth_method":"none"}' \
    2>/dev/null)
DCR_STATUS=$(echo "$DCR_RESP" | grep "__STATUS__" | sed 's/__STATUS__//')
DCR_BODY=$(echo "$DCR_RESP" | sed '/__STATUS__/d')
assert_status "DCR" "201" "$DCR_STATUS"
echo "  Body: $DCR_BODY"

# ─── PASO 9: client_id correcto ──────────────────────────────────────────────

step 9 "DCR devuelve client_id = 'trazalog-mcp-connector'"
CLIENT_ID=$(echo "$DCR_BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('client_id','MISSING'))" 2>/dev/null)
echo "  client_id: $CLIENT_ID"
assert_equals "client_id" "trazalog-mcp-connector" "$CLIENT_ID"
AUTH_ENDPOINT=$(echo "$AS_META_BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('authorization_endpoint',''))" 2>/dev/null)
TOKEN_ENDPOINT=$(echo "$AS_META_BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token_endpoint',''))" 2>/dev/null)
ok "authorization_endpoint: $AUTH_ENDPOINT"
ok "token_endpoint: $TOKEN_ENDPOINT"

# ─── PASOS 10-11: OAuth PKCE flow ────────────────────────────────────────────
# Los pasos 10 (browser login) y 11 (exchange code) requieren interacción del
# usuario. Los automatizamos mintiendo un JWT directamente con la clave Dnato.

step "10-11" "[AUTOMATIZADO] Mintear JWT con clave real Dnato (simula token post-login)"
echo "  (En flujo real: usuario hace login en $AUTH_ENDPOINT)"
echo "  (Aquí: JWT minted directamente para validar el gateway)"
JWT=$(mint_jwt)
if [[ -z "$JWT" || "$JWT" == ERROR* ]]; then
    fail "No se pudo mintear JWT: $JWT"
    echo ""
    echo "FALLO CRÍTICO: no se puede continuar sin JWT"
    exit 1
fi
JWT_HEADER=$(echo "$JWT" | cut -d. -f1 | base64 -d 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "(no decodificable)")
JWT_PAYLOAD=$(echo "$JWT" | cut -d. -f2 | python3 -c "
import sys,base64,json
p=sys.stdin.read().strip()
p+='=='*((4-len(p)%4)%4)
print(json.dumps(json.loads(base64.urlsafe_b64decode(p)), indent=2))
" 2>/dev/null || echo "(no decodificable)")
ok "JWT minted"
echo "  iss:     $(echo "$JWT_PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('iss','?'))" 2>/dev/null)"
echo "  empr_id: $(echo "$JWT_PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('empr_id','?'))" 2>/dev/null)"
echo "  exp:     $(echo "$JWT_PAYLOAD" | python3 -c "import sys,json,datetime; d=json.load(sys.stdin); print(datetime.datetime.fromtimestamp(d.get('exp',0)))" 2>/dev/null)"

# ─── PASO 12: tools/list con JWT ─────────────────────────────────────────────

step 12 "POST $MCP_URL con JWT válido → 200 (tools/list)"
TOOLS_RESP=$(curl -s -w "\n__STATUS__%{http_code}" --max-time 15 \
    -X POST "$MCP_URL" \
    -H "Authorization: Bearer $JWT" \
    -H "Content-Type: application/json" \
    -H "ngrok-skip-browser-warning: true" \
    -d '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":1}' \
    2>/dev/null)
TOOLS_STATUS=$(echo "$TOOLS_RESP" | grep "__STATUS__" | sed 's/__STATUS__//')
TOOLS_BODY=$(echo "$TOOLS_RESP" | sed '/__STATUS__/d')
assert_status "tools/list con JWT" "200" "$TOOLS_STATUS"

# ─── PASO 13: tools presentes ────────────────────────────────────────────────

step 13 "Respuesta contiene herramientas MCP esperadas"
TOOL_NAMES=$(echo "$TOOLS_BODY" | python3 -c "
import sys,json
d=json.load(sys.stdin)
tools=d.get('result',{}).get('tools',[])
for t in tools:
    print(' ', t.get('name','?'))
" 2>/dev/null)
if [[ -z "$TOOL_NAMES" ]]; then
    fail "No se encontraron herramientas en la respuesta"
    echo "  Body: $TOOLS_BODY"
else
    ok "Herramientas disponibles:"
    echo "$TOOL_NAMES"
fi
assert_contains "get_equipos presente" "get_equipos" "$TOOL_NAMES"
assert_contains "get_equipo presente"  "get_equipo"  "$TOOL_NAMES"

# ─── RESUMEN ──────────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════════════════"
TOTAL=$((PASS+FAIL))
if [[ $FAIL -eq 0 ]]; then
    echo "  RESULTADO: ✓ TODOS LOS PASOS PASARON ($PASS/$TOTAL)"
    echo ""
    echo "  Servidor correcto. Si el botón Connect de Claude.ai web falla,"
    echo "  documentar como 'servidor OK, posible bug cliente #217/#410/#271'."
    echo "  Probar desde: Claude Code CLI / Claude Desktop"
else
    echo "  RESULTADO: ✗ $FAIL FALLOS de $TOTAL pasos ($PASS pasaron)"
fi
echo "═══════════════════════════════════════════════════════════════"
echo ""

[[ $FAIL -eq 0 ]]
