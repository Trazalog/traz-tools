#!/bin/bash
# setup-apim-b3-mcp-apis.sh
# Aplica la configuración B3 de ADR-008 en el APIM DEV:
#   1. Importa la EmprIdInjectorPolicy como operation policy
#   2. Asocia la policy a las APIs MCP (Equipos y OTs)
#   3. Publica ambas APIs
#   4. Crea/verifica la app TrazalogDnatoMCP y sus suscripciones
#
# PRE: APIM corriendo en localhost:9443 con [[apim.jwt.issuer]] configurado
#      jwks-server.php corriendo en localhost:8090
# USO: ./scripts/dev/setup-apim-b3-mcp-apis.sh

set -e

APIM_BASE="https://localhost:9443"
DCR_CLIENT_ID="ibmfSZrcmtQVQOEYMIQAfNimo98a"
DCR_CLIENT_SECRET="b2ya6dh9LG85XqqKTL9D3klDDNMa"
POLICY_ZIP="/tmp/EmprIdInjectorPolicy_v1.zip"
POLICY_NAME="EmprIdInjectorPolicy"
POLICY_VERSION="v1"

log() { echo "[B3] $*"; }
die() { echo "[ERROR] $*" >&2; exit 1; }

# ── Token de Publisher/Admin ──────────────────────────────────────
log "Obteniendo token de acceso..."
TOKEN=$(curl -sk -u "$DCR_CLIENT_ID:$DCR_CLIENT_SECRET" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=password&username=admin&password=admin&scope=apim:api_view apim:api_create apim:api_publish apim:common_operation_policy_manage apim:subscribe apim:app_manage apim:policies_import_export' \
  "$APIM_BASE/oauth2/token" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('access_token',''))")
[ -z "$TOKEN" ] && die "No se pudo obtener token"
log "Token OK"

# ── Importar EmprIdInjectorPolicy ────────────────────────────────
[ -f "$POLICY_ZIP" ] || die "Archivo no encontrado: $POLICY_ZIP — ejecutar setup de B2 primero"

log "Verificando si la policy ya existe..."
EXISTS=$(curl -sk -H "Authorization: Bearer $TOKEN" \
  "$APIM_BASE/api/am/publisher/v4/operation-policies?limit=100" 2>/dev/null | \
  python3 -c "import sys,json; d=json.load(sys.stdin); ids=[p['id'] for p in d.get('list',[]) if p['name']=='$POLICY_NAME']; print(ids[0] if ids else '')")

if [ -n "$EXISTS" ]; then
  POLICY_ID="$EXISTS"
  log "Policy ya importada: $POLICY_ID"
else
  log "Importando EmprIdInjectorPolicy..."
  RESULT=$(curl -sk -X POST -H "Authorization: Bearer $TOKEN" \
    -F "file=@$POLICY_ZIP" "$APIM_BASE/api/am/publisher/v4/operation-policies/import" 2>/dev/null)
  POLICY_ID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))")
  [ -z "$POLICY_ID" ] && die "Error importando policy: $RESULT"
  log "Policy importada: $POLICY_ID"
fi

# ── Listar APIs MCP ──────────────────────────────────────────────
log "Buscando APIs MCP..."
APIS=$(curl -sk -H "Authorization: Bearer $TOKEN" \
  "$APIM_BASE/api/am/publisher/v4/apis?limit=20" 2>/dev/null | \
  python3 -c "
import sys, json
d = json.load(sys.stdin)
for a in d.get('list',[]):
    if 'MCP' in a['name'] or 'mcp' in a['name'].lower():
        print(f\"{a['id']}|{a['name']}|{a['lifeCycleStatus']}\")
")
[ -z "$APIS" ] && die "No se encontraron APIs MCP. Importar las specs primero."

# ── Aplicar policy y publicar cada API ──────────────────────────
echo "$APIS" | while IFS='|' read -r API_ID API_NAME STATUS; do
  log "Procesando $API_NAME ($API_ID) — estado: $STATUS"

  # Obtener y modificar el objeto API
  API_OBJ=$(curl -sk -H "Authorization: Bearer $TOKEN" \
    "$APIM_BASE/api/am/publisher/v4/apis/$API_ID" 2>/dev/null)

  UPDATED=$(echo "$API_OBJ" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for op in d.get('operations', []):
    op['operationPolicies']['request'] = [{
        'policyName': '$POLICY_NAME',
        'policyVersion': '$POLICY_VERSION',
        'policyId': '$POLICY_ID',
        'parameters': {}
    }]
print(json.dumps(d))
")

  curl -sk -X PUT -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d "$UPDATED" "$APIM_BASE/api/am/publisher/v4/apis/$API_ID" > /dev/null 2>&1
  log "  Policy asociada a $API_NAME"

  if [ "$STATUS" != "PUBLISHED" ]; then
    curl -sk -X POST -H "Authorization: Bearer $TOKEN" \
      "$APIM_BASE/api/am/publisher/v4/apis/change-lifecycle?apiId=$API_ID&action=Publish" > /dev/null 2>&1
    log "  Publicada $API_NAME"
  else
    log "  Ya estaba publicada"
  fi
done

# ── Suscripciones para TrazalogDnatoMCP ─────────────────────────
log "Verificando aplicación TrazalogDnatoMCP..."
APP_ID=$(curl -sk -H "Authorization: Bearer $TOKEN" \
  "$APIM_BASE/api/am/devportal/v3/applications?limit=20" 2>/dev/null | \
  python3 -c "import sys,json; d=json.load(sys.stdin); ids=[a['applicationId'] for a in d.get('list',[]) if a['name']=='TrazalogDnatoMCP']; print(ids[0] if ids else '')")

if [ -z "$APP_ID" ]; then
  log "Creando aplicación TrazalogDnatoMCP..."
  APP=$(curl -sk -X POST -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"name":"TrazalogDnatoMCP","throttlingPolicy":"Unlimited","description":"App para JWTs Dnato ADR-008 MVP"}' \
    "$APIM_BASE/api/am/devportal/v3/applications" 2>/dev/null)
  APP_ID=$(echo "$APP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('applicationId',''))")

  # Generar keys
  KEYS=$(curl -sk -X POST -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"keyType":"PRODUCTION","keyManager":"Resident Key Manager","grantTypesToBeSupported":["client_credentials"]}' \
    "$APIM_BASE/api/am/devportal/v3/applications/$APP_ID/generate-keys" 2>/dev/null)
  CONSUMER_KEY=$(echo "$KEYS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('consumerKey',''))")
  log "  App creada. consumerKey para azp: $CONSUMER_KEY"
else
  log "  App ya existe: $APP_ID"
  CONSUMER_KEY=$(curl -sk -H "Authorization: Bearer $TOKEN" \
    "$APIM_BASE/api/am/devportal/v3/applications/$APP_ID/keys" 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); ks=[k for k in d.get('list',[]) if k['keyType']=='PRODUCTION']; print(ks[0]['consumerKey'] if ks else 'NO_KEYS')")
  log "  consumerKey: $CONSUMER_KEY"
fi

# Suscribir a las APIs MCP
echo "$APIS" | while IFS='|' read -r API_ID API_NAME STATUS; do
  curl -sk -X POST -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"applicationId\":\"$APP_ID\",\"apiId\":\"$API_ID\",\"throttlingPolicy\":\"Unlimited\"}" \
    "$APIM_BASE/api/am/devportal/v3/subscriptions" > /dev/null 2>&1
  log "  Suscripción a $API_NAME (OK o ya existía)"
done

log ""
log "=== B3 COMPLETADO ==="
log "consumer key para 'azp' en JWTs de prueba: $CONSUMER_KEY"
log "Incluir en el payload JWT: \"azp\": \"$CONSUMER_KEY\""
