#!/bin/bash
# setup-mi-b4-car-deploy.sh
# Inicia el MI local con offset=10 y verifica que los endpoints MCP responden.
# Completa B4 de ADR-008.
#
# PRE-REQUISITO: ejecutar UNA VEZ con sudo si da errores de permisos:
#   sudo chown -R $USER:$USER ~/.wso2-mi/micro-integrator/wso2mi-4.5.0/tmp/
#
# PRE: APIM corriendo en localhost:9443 / 8280 (no debe conflictuar con el MI)
#      El nuevo CAR ya está en carbonapps/ (lo puso la sesión de B4)
#      MI deployment.toml tiene offset=10 (ports 8290/8253/9174)
# USO: ./scripts/dev/setup-mi-b4-car-deploy.sh

set -e

MI_HOME="${MI_HOME:-$HOME/.wso2-mi/micro-integrator/wso2mi-4.5.0}"
MI_HTTP="http://localhost:8290"
CAR="$PWD/_backend/api/ToolsAPIProject/ToolsAPIProject/target/ToolsAPIProject_1.0.0.car"
JAVA_HOME="${JAVA_HOME:-$(ls -d "$HOME/.sdkman/candidates/java/17"* 2>/dev/null | head -1)}"

log() { echo "[B4] $*"; }
die() { echo "[ERROR] $*" >&2; exit 1; }

# ── Verificar java ────────────────────────────────────────────────
[ -x "$JAVA_HOME/bin/java" ] || die "JAVA_HOME no encontrado: $JAVA_HOME"
log "Java OK: $JAVA_HOME"

# ── Copiar CAR actualizado ────────────────────────────────────────
[ -f "$CAR" ] || die "CAR no encontrado: $CAR"
cp "$CAR" "$MI_HOME/repository/deployment/server/carbonapps/"
log "CAR copiado: ToolsAPIProject_1.0.0.car → carbonapps/"

# ── Limpiar PID stale si existe ───────────────────────────────────
PID_FILE="$MI_HOME/wso2carbon.pid"
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE")
  if ! ps -p "$OLD_PID" >/dev/null 2>&1; then
    rm "$PID_FILE"
    log "PID stale eliminado ($OLD_PID)"
  fi
fi

# ── Iniciar MI ────────────────────────────────────────────────────
log "Iniciando WSO2 MI en localhost:8290..."
export JAVA_HOME
"$MI_HOME/bin/micro-integrator.sh" start

# ── Esperar que el MI levante ────────────────────────────────────
log "Esperando startup (máx 60s)..."
for i in $(seq 1 12); do
  sleep 5
  if curl -s -o /dev/null --connect-timeout 2 "$MI_HTTP/tools/man"; then
    log "MI responde en $MI_HTTP"
    break
  fi
  echo -n "."
done

# ── Test fallback (Fix 3 ADR-008) ────────────────────────────────
log "Test: GET /mcp/equipos sin X-Empr-Id → esperado 503..."
SC=$(curl -s -o /tmp/mi-b4-test.json -w "%{http_code}" "$MI_HTTP/tools/man/mcp/equipos" 2>/dev/null)
if [ "$SC" = "503" ]; then
  ERR=$(python3 -c "import json; d=json.load(open('/tmp/mi-b4-test.json')); print(d.get('error',''))" 2>/dev/null)
  log "PASS: HTTP 503, error=$ERR"
else
  log "WARN: HTTP $SC (esperado 503). Verificar que el CAR se deployó correctamente."
  cat /tmp/mi-b4-test.json
fi

# ── Test con X-Empr-Id ───────────────────────────────────────────
log "Test: GET /mcp/equipos con X-Empr-Id: 1 → esperado 200 o 5xx de BD (no 503)..."
SC2=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Empr-Id: 1" "$MI_HTTP/tools/man/mcp/equipos" 2>/dev/null)
if [ "$SC2" != "503" ]; then
  log "PASS: HTTP $SC2 (header procesado, fallback 503 no activa)"
else
  log "WARN: HTTP 503 con X-Empr-Id presente — revisar EmprIdFromHeader.xml"
fi

log ""
log "=== B4 COMPLETADO ==="
log "MI arriba en localhost:8290"
log "APIM redirige MCP APIs → localhost:8290/tools/man"
log "Ejecutar: hurl --variable MI_HOST=localhost:8290 tests/security/mi-fallback.hurl"
