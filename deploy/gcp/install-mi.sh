#!/bin/bash
# install-mi.sh
# Instalación NATIVA (sin Docker) de WSO2 Micro Integrator en la VM de GCP.
# Aplica ADR-011: descomprime el .zip, deja el heap del MI en su mínimo
# funcional (el grueso de RAM va al APIM — ver install-apim.sh), y deja el
# servicio corriendo bajo systemd.
#
# Fuera de alcance de este script (ver doc/v3/deployment-gcp.md):
#   - Deploy del .car (ToolsAPIProject) — se copia a carbonapps/ por separado,
#     igual que en DEV (ver scripts/dev/setup-mi-b4-car-deploy.sh).
#   - Migración de las DataServices de negocio (MySQL → PostgreSQL): las
#     datasources del proyecto (AssetPlannerDataSource, ToolsDataSource)
#     están embebidas en el .car y se reconfiguran ahí, no en esta VM.
#     Ver doc/identity/dataservices-remediation-phase-a.md.
#
# PRE:
#   - deploy/gcp/.env presente (copiar de .env.example y completar)
#   - .zip de WSO2 MI descargado manualmente desde wso2.com en MI_ZIP_PATH
# USO: sudo ./install-mi.sh   (en la VM GCP)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

log() { echo "[install-mi] $*"; }
die() { echo "[ERROR] $*" >&2; exit 1; }

[ -f "$ENV_FILE" ] || die "No se encontró $ENV_FILE — copiar .env.example y completar"
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

for var in MI_ZIP_PATH MI_HOME MI_XMS MI_XMX; do
  [ -n "${!var:-}" ] || die "Falta $var en .env"
done

[ -f "$MI_ZIP_PATH" ] || die "No se encontró el zip de MI en $MI_ZIP_PATH"

WSO2_USER="${WSO2_SYSTEM_USER:-wso2carbon}"
INSTALL_PARENT="$(dirname "$MI_HOME")"

# ── Usuario de sistema dedicado (compartido con el APIM) ──────────
if ! id "$WSO2_USER" >/dev/null 2>&1; then
  log "Creando usuario de sistema $WSO2_USER..."
  useradd --system --no-create-home --shell /usr/sbin/nologin "$WSO2_USER"
fi

# ── Descompresión ─────────────────────────────────────────────────
if [ -d "$MI_HOME" ]; then
  log "AVISO: $MI_HOME ya existe — se omite la descompresión (instalación existente)"
else
  log "Descomprimiendo $MI_ZIP_PATH en $INSTALL_PARENT..."
  mkdir -p "$INSTALL_PARENT"
  UNZIP_TMP="$(mktemp -d)"
  unzip -q "$MI_ZIP_PATH" -d "$UNZIP_TMP"
  UNZIPPED_DIR="$(find "$UNZIP_TMP" -mindepth 1 -maxdepth 1 -type d | head -1)"
  [ -n "$UNZIPPED_DIR" ] || die "El zip no contiene el directorio esperado"
  mv "$UNZIPPED_DIR" "$MI_HOME"
  rmdir "$UNZIP_TMP" 2>/dev/null || true
fi
find "$MI_HOME/bin" -iname "*.sh" -exec chmod +x {} \;

# ── Heap size (mínimo funcional — default de fábrica es -Xms256m -Xmx1024m) ──
MI_SH="$MI_HOME/bin/micro-integrator.sh"
if grep -qE -- '-Xm[sx][0-9]+[mMgG]' "$MI_SH" 2>/dev/null; then
  sed -i -E "s/-Xms[0-9]+[mMgG]/-Xms$MI_XMS/g; s/-Xmx[0-9]+[mMgG]/-Xmx$MI_XMX/g" "$MI_SH"
  log "Heap del MI ajustado en micro-integrator.sh: -Xms$MI_XMS -Xmx$MI_XMX"
else
  log "AVISO: no se encontraron flags -Xms/-Xmx en micro-integrator.sh — ajustar heap manualmente"
fi

# ── Permisos y systemd ─────────────────────────────────────────────
chown -R "$WSO2_USER:$WSO2_USER" "$MI_HOME"

sed -e "s#{{MI_HOME}}#$MI_HOME#g" -e "s#{{WSO2_USER}}#$WSO2_USER#g" \
  "$SCRIPT_DIR/systemd/wso2mi.service" > /etc/systemd/system/wso2mi.service
systemctl daemon-reload
systemctl enable wso2mi.service

log ""
log "=== install-mi.sh COMPLETADO ==="
log "Servicio wso2mi instalado y habilitado (NO se inicia automáticamente)."
log "Recordar copiar el .car actualizado a $MI_HOME/repository/deployment/server/carbonapps/ antes de arrancar."
log "Para arrancar: systemctl start wso2mi && journalctl -u wso2mi -f"
