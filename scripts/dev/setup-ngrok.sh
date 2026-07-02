#!/usr/bin/env bash
# =============================================================================
# setup-ngrok.sh — Configura ngrok para sesión de desarrollo MCP + Claude.ai
#
# QUÉ HACE:
#   1. Inicia ngrok con 2 túneles: APIM gateway (8243) y Dnato (80)
#   2. Obtiene las URLs públicas de ambos túneles
#   3. Actualiza hostname en deployment.toml del APIM
#   4. Reinicia APIM
#   5. Actualiza el issuer del Key Manager "Resident Key Manager" en APIM
#      para que el PRM devuelva la URL pública de Dnato en authorization_servers
#   6. Imprime las variables de entorno a exportar para Dnato (Apache/PHP)
#
# PRE-REQUISITOS:
#   - ngrok instalado y autenticado (ngrok config add-authtoken <token>)
#   - APIM instalado en APIM_HOME
#   - APIM en puerto 9443 (admin) y 8243 (gateway NIO)
#   - Apache (Dnato) en puerto 80
#   - JWKS server PHP en puerto 8090 (arrancar aparte con start-jwks-server.sh)
#
# USO:
#   export APIM_HOME=/mnt/win/dev/wso2am-4.6.0
#   bash scripts/dev/setup-ngrok.sh
#
# PARA VOLVER A LOCALHOST:
#   bash scripts/dev/setup-ngrok.sh --reset
# =============================================================================

set -euo pipefail

APIM_HOME="${APIM_HOME:-/mnt/win/dev/wso2am-4.6.0}"
DEPLOYMENT_TOML="$APIM_HOME/repository/conf/deployment.toml"
APIM_ADMIN_URL="https://localhost:9443"
APIM_ADMIN_CREDENTIALS="admin:admin"
RESIDENT_KM_ID="f5fce9df-5735-48c3-b39f-c3dab97a7a5e"  # Resident Key Manager UUID

NGROK_API_URL="http://localhost:4040/api/tunnels"  # ngrok local API

# ─── MODO RESET ──────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--reset" ]]; then
  echo "=== RESET: restaurar hostname=localhost e issuer=http://localhost/oauth en APIM ==="
  sed -i 's/^hostname = .*/hostname = "localhost"/' "$DEPLOYMENT_TOML"
  # Restaurar el issuer URL-based a la URL local
  sed -i 's|^name = "https://[^"]*\.ngrok[^"]*"|name = "http://localhost/oauth"|g' "$DEPLOYMENT_TOML"
  # Restaurar https_endpoint del gateway al valor local
  sed -i 's|^https_endpoint = "https://[^"]*\.ngrok[^"]*"|https_endpoint = "https://localhost:8243"|' "$DEPLOYMENT_TOML"
  echo "deployment.toml restaurado."
  echo ""
  echo "Reiniciando APIM..."
  "$APIM_HOME/bin/api-manager.sh" stop 2>/dev/null || true
  sleep 5
  "$APIM_HOME/bin/api-manager.sh" start
  echo ""
  echo "Esperar ~60s para que APIM arranque, luego correr:"
  echo "  curl -s -k -u admin:admin -X PUT $APIM_ADMIN_URL/api/am/admin/v4/key-managers/$RESIDENT_KM_ID \\"
  echo "    -H 'Content-Type: application/json' \\"
  echo "    -d '{\"name\":\"Resident Key Manager\",\"type\":\"default\",\"enabled\":true,\"issuer\":\"http://localhost/oauth\",\"tokenEndpoint\":\"https://localhost:9443/oauth2/token\",\"certificates\":{\"type\":\"JWKS\",\"value\":\"https://localhost:9443/oauth2/jwks\"},\"availableGrantTypes\":[\"authorization_code\"],\"enableTokenGeneration\":true,\"enableSelfValidationJWT\":true,\"additionalProperties\":{\"ServerURL\":\"https://localhost:9443/services/\",\"TokenURL\":\"https://localhost:9443/oauth2/token\",\"RevokeURL\":\"https://localhost:9443/oauth2/revoke\",\"self_validate_jwt\":true,\"validation_enable\":true}}'"
  exit 0
fi

# ─── PASO 1: VERIFICAR ngrok CORRIENDO ───────────────────────────────────────
echo "=== Paso 1: Verificar ngrok ==="
if ! curl -s "$NGROK_API_URL" > /dev/null 2>&1; then
  echo ""
  echo "ERROR: ngrok no está corriendo (API en $NGROK_API_URL no responde)."
  echo ""
  echo "Opciones para iniciar ngrok con 2 túneles:"
  echo ""
  echo "  Opción A — config file (recomendado, un solo comando):"
  echo "  Crear ~/.config/ngrok/ngrok.yml con:"
  echo "    version: '3'"
  echo "    tunnels:"
  echo "      apim:"
  echo "        proto: http"
  echo "        addr: 8243"
  echo "      dnato:"
  echo "        proto: http"
  echo "        addr: 80"
  echo "  Luego:  ngrok start --all"
  echo ""
  echo "  Opción B — 2 terminales separadas:"
  echo "    Terminal 1: ngrok http 8243 --host-header=localhost"
  echo "    Terminal 2: ngrok http 80 --host-header=localhost"
  echo ""
  exit 1
fi

# ─── PASO 2: OBTENER URLs DE ngrok ───────────────────────────────────────────
echo "=== Paso 2: Obtener URLs de ngrok ==="

TUNNELS=$(curl -s "$NGROK_API_URL" 2>/dev/null)

# Buscar el túnel que apunta a :8280 (APIM gateway HTTP — ngrok termina TLS por su lado)
NGROK_APIM_URL=$(echo "$TUNNELS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for t in d.get('tunnels', []):
    # El túnel APIM se llama 'apim' (puede apuntar a 8280 directo o al shim en 8899)
    if t.get('name','') == 'apim':
        u = t.get('public_url','')
        if u.startswith('https://'):
            print(u)
            break
" 2>/dev/null)

# Buscar el túnel que apunta a :80 (Dnato)
NGROK_DNATO_URL=$(echo "$TUNNELS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for t in d.get('tunnels', []):
    addr = t.get('config',{}).get('addr','')
    if ':80' in addr or addr == '80':
        u = t.get('public_url','')
        if u.startswith('https://'):
            print(u)
            break
" 2>/dev/null)

if [[ -z "$NGROK_APIM_URL" ]]; then
  echo "ERROR: No se encontró túnel ngrok para puerto 8280 (APIM)."
  echo "Túneles activos:"
  echo "$TUNNELS" | python3 -c "import sys,json; [print(t.get('public_url','?'), '->', t.get('config',{}).get('addr','?')) for t in json.load(sys.stdin).get('tunnels',[])]" 2>/dev/null
  exit 1
fi

if [[ -z "$NGROK_DNATO_URL" ]]; then
  echo "ERROR: No se encontró túnel ngrok para puerto 80 (Dnato)."
  exit 1
fi

# Extraer solo el hostname sin https://
NGROK_APIM_HOST="${NGROK_APIM_URL#https://}"
NGROK_DNATO_HOST="${NGROK_DNATO_URL#https://}"

echo "  APIM gateway: $NGROK_APIM_URL  (hostname: $NGROK_APIM_HOST)"
echo "  Dnato:        $NGROK_DNATO_URL  (hostname: $NGROK_DNATO_HOST)"

# ─── PASO 3: ACTUALIZAR deployment.toml ──────────────────────────────────────
echo ""
echo "=== Paso 3: Actualizar deployment.toml ==="

DNATO_ISSUER_NGROK="${NGROK_DNATO_URL}/traz-comp-dnato/oauth"
CURRENT_HOSTNAME=$(grep '^hostname' "$DEPLOYMENT_TOML" | sed 's/hostname = "\(.*\)"/\1/')
CURRENT_ISSUER=$(grep '^name = "http' "$DEPLOYMENT_TOML" | head -1 | sed 's/name = "\(.*\)"/\1/')

echo "  hostname actual: $CURRENT_HOSTNAME → $NGROK_APIM_HOST"
echo "  issuer actual:   $CURRENT_ISSUER → $DNATO_ISSUER_NGROK"

# Backup antes de modificar
cp "$DEPLOYMENT_TOML" "${DEPLOYMENT_TOML}.bak.$(date +%Y%m%d%H%M%S)"

# Actualizar hostname del servidor
sed -i "s|^hostname = .*|hostname = \"$NGROK_APIM_HOST\"|" "$DEPLOYMENT_TOML"

# Actualizar https_endpoint del gateway (afecta resource_metadata en WWW-Authenticate y PRM resource)
sed -i "s|^https_endpoint = .*|https_endpoint = \"$NGROK_APIM_URL\"|" "$DEPLOYMENT_TOML"

# Actualizar el [[apim.jwt.issuer]] name URL-based (para validar JWTs de Dnato ngrok)
sed -i "s|^name = \"http[^\"]*\"|name = \"$DNATO_ISSUER_NGROK\"|g" "$DEPLOYMENT_TOML"

echo "  deployment.toml actualizado. Backup en ${DEPLOYMENT_TOML}.bak.*"

# ─── PASO 4: REINICIAR APIM ──────────────────────────────────────────────────
echo ""
echo "=== Paso 4: Reiniciar APIM ==="

# Inyectar URLs como Java system properties para que el CAR OAuthDiscovery las lea en runtime.
# El CAR usa get-property('system','trazalog.mcp.resource.url') y trazalog.dnato.oauth.url.
MCP_RESOURCE_URL="$NGROK_APIM_URL/trazalog-equipos/1.0/mcp"
DNATO_AS_URL="$NGROK_DNATO_URL/traz-comp-dnato/oauth"
export JAVA_OPTS="${JAVA_OPTS:-} -Dtrazalog.mcp.resource.url=${MCP_RESOURCE_URL} -Dtrazalog.dnato.oauth.url=${DNATO_AS_URL}"
echo "  JAVA_OPTS inyectado:"
echo "    trazalog.mcp.resource.url  = $MCP_RESOURCE_URL"
echo "    trazalog.dnato.oauth.url   = $DNATO_AS_URL"

"$APIM_HOME/bin/api-manager.sh" stop 2>/dev/null || true
sleep 5
"$APIM_HOME/bin/api-manager.sh" start

echo "  APIM reiniciando..."
echo -n "  Esperando startup"

# Esperar hasta 120 segundos que el admin API responda
TIMEOUT=120
ELAPSED=0
while ! curl -s -k -u $APIM_ADMIN_CREDENTIALS "$APIM_ADMIN_URL/api/am/admin/v4/key-managers" > /dev/null 2>&1; do
  sleep 5
  ELAPSED=$((ELAPSED + 5))
  echo -n "."
  if [[ $ELAPSED -ge $TIMEOUT ]]; then
    echo ""
    echo "  ERROR: APIM no arrancó en ${TIMEOUT}s. Ver logs en $APIM_HOME/repository/logs/wso2carbon.log"
    exit 1
  fi
done
echo ""
echo "  APIM listo."

# ─── PASO 3b: VERIFICAR / DEPLOY CAR OAuthDiscovery (PRM RFC 9728) ───────────
# El CAR en $APIM_HOME/repository/deployment/server/carbonapps/ es la fuente
# definitiva. Se deploya via Carbon Application Deployer (sobrevive registry sync).
# Las URLs vienen de JAVA_OPTS ya inyectado en el Paso 4.
echo ""
echo "=== Paso 3b: Verificar CAR OAuthDiscovery en carbonapps/ ==="

CARBONAPPS_DIR="$APIM_HOME/repository/deployment/server/carbonapps"
CAR_SOURCE="$(dirname "$(readlink -f "$0")")/../../_backend/api/ApimDiscoveryProject"
CAR_FILE="$CARBONAPPS_DIR/trazalog-discovery-1.0.0.car"

mkdir -p "$CARBONAPPS_DIR"

if [[ ! -f "$CAR_FILE" ]]; then
    echo "  CAR no encontrado, construyendo y desplegando..."
    APIM_HOME="$APIM_HOME" bash "$CAR_SOURCE/build.sh"
else
    echo "  CAR ya presente: $CAR_FILE"
fi

# Verificar que el PRM responda
echo -n "  Verificando PRM..."
PRM_RESPONSE=$(curl -s "http://localhost:8280/.well-known/oauth-protected-resource" 2>/dev/null)
PRM_RESOURCE=$(echo "$PRM_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('resource','?'))" 2>/dev/null || echo "?")
if [[ "$PRM_RESOURCE" == *"trazalog-equipos"* ]]; then
    echo " OK"
    echo "    resource = $PRM_RESOURCE"
else
    echo " WARNING: PRM no responde o URL vacía (resource='$PRM_RESOURCE'). Verificar logs APIM."
fi

# ─── PASO 5: ACTUALIZAR KM ISSUER ────────────────────────────────────────────
echo ""
echo "=== Paso 5: Actualizar Resident KM issuer → $NGROK_DNATO_URL/oauth ==="

DNATO_ISSUER="${NGROK_DNATO_URL}/traz-comp-dnato/oauth"

curl -s -k -u $APIM_ADMIN_CREDENTIALS \
  -X PUT "$APIM_ADMIN_URL/api/am/admin/v4/key-managers/$RESIDENT_KM_ID" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Resident Key Manager\",
    \"displayName\": null,
    \"type\": \"default\",
    \"description\": \"This is Resident Key Manager\",
    \"enabled\": true,
    \"issuer\": \"$DNATO_ISSUER\",
    \"tokenEndpoint\": \"${DNATO_ISSUER}/token\",
    \"revokeEndpoint\": \"${DNATO_ISSUER}/revoke\",
    \"certificates\": {\"type\": \"JWKS\", \"value\": \"${DNATO_ISSUER}/.well-known/jwks.json\"},
    \"availableGrantTypes\": [\"authorization_code\"],
    \"enableTokenGeneration\": false,
    \"enableMapOAuthConsumerApps\": false,
    \"enableOAuthAppCreation\": false,
    \"enableSelfValidationJWT\": true,
    \"availableGrantTypes\": [\"authorization_code\"],
    \"additionalProperties\": {
      \"ServerURL\": \"https://localhost:9443/services/\",
      \"self_validate_jwt\": true,
      \"validation_enable\": true,
      \"enable_token_hash\": false
    },
    \"tokenValidation\": [{\"type\": \"JWT\", \"enable\": true, \"value\": {\"body\": {}, \"header\": {}}}]
  }" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
if 'id' in d:
    print('  KM issuer actualizado. issuer =', d.get('issuer',''))
else:
    print('  ERROR actualizando KM:', d.get('message',''), d.get('description',''))
" 2>/dev/null

# Verificar PRM
echo ""
echo "  Verificando PRM de trazalog-equipos:"
PRM=$(curl -s -k "https://localhost:8243/trazalog-equipos/1.0/.well-known/oauth-protected-resource" 2>/dev/null)
echo "$PRM" | python3 -m json.tool 2>/dev/null | sed 's/^/    /'

# ─── PASO 6: INSTRUCCIONES PARA DNATO ────────────────────────────────────────
echo ""
echo "=== Paso 6: Configurar Dnato ==="
echo ""
  echo "  deployment.toml ya fue actualizado (Paso 3) con:"
  echo "    hostname = \"$NGROK_APIM_HOST\""
  echo "    [[apim.jwt.issuer]] name = \"$DNATO_ISSUER\""
  echo "  APIM fue reiniciado para tomar esos cambios."
  echo ""
echo ""
echo "  AHORA: Exportar variables de entorno para Dnato antes de iniciar Apache:"
echo ""
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │  export DNATO_PUBLIC_URL=\"${NGROK_DNATO_URL}/traz-comp-dnato\" │"
echo "  │  export DNATO_ISSUER=\"${DNATO_ISSUER}\"                        │"
echo "  │  # Luego configurar en XAMPP httpd-vhosts.conf y reiniciar:    │"
echo "  │  sudo /opt/lampp/lampp restartapache                            │"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""
echo "  En XAMPP: agregar SetEnv en el VirtualHost traz-comp.local en"
echo "  /opt/lampp/etc/extra/httpd-vhosts.conf (ver instrucciones abajo)."
echo ""

# ─── RESUMEN ─────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════════════"
echo "  RESUMEN SESIÓN NGROK"
echo "═══════════════════════════════════════════════════════════════════════"
echo "  APIM gateway (público):  $NGROK_APIM_URL"
echo "  Dnato (público):         $NGROK_DNATO_URL"
echo "  MCP connector URL:       $NGROK_APIM_URL/trazalog-equipos/1.0/mcp"
echo "  DNATO_ISSUER:            $DNATO_ISSUER"
echo ""
echo "  En Claude.ai → Settings → Connectors → Add custom integration:"
echo "    URL: $NGROK_APIM_URL/trazalog-equipos/1.0/mcp"
echo ""
echo "  NOTA Fix A: Los métodos 'initialize' y 'tools/list' NO requieren auth"
echo "  (hardcoded en McpInitHandler.class). La autenticación se dispara al"
echo "  primer 'tools/call'. Esto es suficiente para el flujo OAuth 2.1 PKCE."
echo "═══════════════════════════════════════════════════════════════════════"
