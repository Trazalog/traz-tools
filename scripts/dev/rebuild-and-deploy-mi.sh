#!/bin/bash
# rebuild-and-deploy-mi.sh
#
# Objetivo: recompilar ToolsAPIProject (Maven) y desplegar el .car resultante
# al WSO2 MI local, reiniciando el servicio. Es el ciclo completo que faltaba:
# scripts/dev/setup-mi-b4-car-deploy.sh (histórico, tarea B4/ADR-008) asume
# que el .car YA está compilado — este script lo compila primero.
#
# Usar cada vez que cambies algo en _backend/api/ToolsAPIProject/ (APIs,
# sequences, DataServices — toolsMANAPI, toolsMCPAPI, toolsALMAPI,
# ALMDataService, MANDataService, etc.) y quieras probarlo en el MI local.
#
# NO cubre el redespliegue de APIs en el APIM (Publisher) — eso es un paso
# de consola aparte, ver doc/infra/wso2-redeploy-artifacts.md.
#
# PRE: MI_HOME instalado (default ~/.wso2-mi/micro-integrator/wso2mi-4.5.0).
#      JAVA_HOME con JDK 17 si no se exporta explícito (mismo que usa DEV).
# USO: ./scripts/dev/rebuild-and-deploy-mi.sh [--no-restart]
#      --no-restart: compila y copia el .car, pero no reinicia el MI
#      (útil si preferís reiniciarlo vos a mano, o si vas a copiar más de
#      un .car antes de reiniciar).

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_DIR="$REPO_ROOT/_backend/api/ToolsAPIProject/ToolsAPIProject"
MI_HOME="${MI_HOME:-$HOME/.wso2-mi/micro-integrator/wso2mi-4.5.0}"
MI_HTTP="http://localhost:8290"
CAR="$PROJECT_DIR/target/ToolsAPIProject_1.0.0.car"
JAVA_HOME="${JAVA_HOME:-$(ls -d "$HOME/.sdkman/candidates/java/17"* 2>/dev/null | head -1)}"
NO_RESTART=false
[ "${1:-}" = "--no-restart" ] && NO_RESTART=true

log() { echo "[rebuild-and-deploy-mi] $*"; }
die() { echo "[ERROR] $*" >&2; exit 1; }

[ -x "$JAVA_HOME/bin/java" ] || die "JAVA_HOME no encontrado: $JAVA_HOME (¿tenés JDK 17 vía sdkman?)"
[ -d "$MI_HOME" ] || die "MI_HOME no encontrado: $MI_HOME"
export JAVA_HOME

# ── Paso 1: compilar (Maven) ──────────────────────────────────────
log "Compilando ToolsAPIProject (./mvnw clean install)..."
( cd "$PROJECT_DIR" && ./mvnw -q clean install )
[ -f "$CAR" ] || die "El build terminó pero no se encontró el .car en $CAR — revisar el log de Maven"
log "Build OK: $CAR"

# ── Paso 2: copiar el .car al MI ──────────────────────────────────
cp "$CAR" "$MI_HOME/repository/deployment/server/carbonapps/"
log "CAR copiado a $MI_HOME/repository/deployment/server/carbonapps/"

if $NO_RESTART; then
  log "--no-restart: listo, no se reinició el MI. Copiar el CAR no alcanza para" \
      "que tome los cambios si el MI ya está corriendo — hace falta reiniciarlo a mano."
  exit 0
fi

# ── Paso 3: reiniciar el MI (parar si está corriendo, después arrancar) ──
# micro-integrator.sh NO tiene subcomando "status" (solo start/stop/restart/
# version) — se determina "¿está corriendo?" mirando el PID file a mano,
# mismo criterio que ya usa scripts/dev/setup-mi-b4-car-deploy.sh.
PID_FILE="$MI_HOME/wso2carbon.pid"
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE")
  if ps -p "$OLD_PID" >/dev/null 2>&1; then
    log "MI corriendo (PID $OLD_PID) — deteniendo..."
    "$MI_HOME/bin/micro-integrator.sh" stop || true
    sleep 3
  else
    rm "$PID_FILE"
    log "PID stale eliminado ($OLD_PID)"
  fi
fi

log "Iniciando MI..."
"$MI_HOME/bin/micro-integrator.sh" start

log "Esperando startup (máx 60s)..."
for i in $(seq 1 12); do
  sleep 5
  if curl -s -o /dev/null --connect-timeout 2 "$MI_HTTP/tools/man"; then
    log "MI responde en $MI_HTTP"
    break
  fi
  echo -n "."
done

log ""
log "=== rebuild-and-deploy-mi.sh COMPLETADO ==="
log "Revisar $MI_HOME/repository/logs/wso2carbon.log si algún CApp no deployó"
log "(ej: ALMDataService puede fallar si no hay conectividad a su BD — ver STATE.md)"
