#!/bin/bash
# install-apim.sh
# Instalación NATIVA (sin Docker) de WSO2 API Manager 4.6.0 en la VM de GCP.
# Aplica ADR-011: descomprime el .zip, ajusta el hostname público y el heap
# prioritario del APIM, y deja el servicio corriendo bajo systemd.
#
# Registro/metadata interno del APIM (apim_db/shared_db): se deja en la H2
# embebida por defecto del producto — decisión explícita de Rodolfo
# (2026-07-28, ver nota de implementación en ADR-011 punto 6) para no sumar
# la complejidad de esquemas de PostgreSQL en un piloto de 1-2 usuarios.
# Este script NO toca `[database.*]` en deployment.toml.
#
# Fuera de alcance de este script (ver doc/v3/deployment-gcp.md):
#   - Configuración de identidad ([apim.jwt], Key Manager federado Dnato,
#     ADR-008/ADR-009). Es clase 🔴 (identidad/seguridad) — no se toca acá.
#   - Migración de las DataServices de negocio del MI a PostgreSQL (aparte,
#     no relacionada con el registro interno del APIM).
#
# PRE:
#   - deploy/gcp/.env presente (copiar de .env.example y completar)
#   - .zip de WSO2 APIM descargado manualmente desde wso2.com (requiere
#     cuenta) en la ruta APIM_ZIP_PATH — ver doc/infra/wso2-install.md §2
# USO: sudo ./install-apim.sh   (en la VM GCP)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

log() { echo "[install-apim] $*"; }
die() { echo "[ERROR] $*" >&2; exit 1; }

[ -f "$ENV_FILE" ] || die "No se encontró $ENV_FILE — copiar .env.example y completar"
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

for var in APIM_ZIP_PATH APIM_HOME APIM_XMS APIM_XMX MCP_DOMAIN \
           MCP_RESOURCE_URL DNATO_OAUTH_URL; do
  [ -n "${!var:-}" ] || die "Falta $var en .env"
done

[ -f "$APIM_ZIP_PATH" ] || die "No se encontró el zip de APIM en $APIM_ZIP_PATH"

WSO2_USER="${WSO2_SYSTEM_USER:-wso2carbon}"
INSTALL_PARENT="$(dirname "$APIM_HOME")"

# ── Usuario de sistema dedicado (sin login) ──────────────────────
if ! id "$WSO2_USER" >/dev/null 2>&1; then
  log "Creando usuario de sistema $WSO2_USER..."
  useradd --system --no-create-home --shell /usr/sbin/nologin "$WSO2_USER"
fi

# ── Descompresión ─────────────────────────────────────────────────
if [ -d "$APIM_HOME" ]; then
  log "AVISO: $APIM_HOME ya existe — se omite la descompresión (instalación existente)"
else
  log "Descomprimiendo $APIM_ZIP_PATH en $INSTALL_PARENT..."
  mkdir -p "$INSTALL_PARENT"
  UNZIP_TMP="$(mktemp -d)"
  unzip -q "$APIM_ZIP_PATH" -d "$UNZIP_TMP"
  UNZIPPED_DIR="$(find "$UNZIP_TMP" -mindepth 1 -maxdepth 1 -type d | head -1)"
  [ -n "$UNZIPPED_DIR" ] || die "El zip no contiene el directorio esperado"
  mv "$UNZIPPED_DIR" "$APIM_HOME"
  rmdir "$UNZIP_TMP" 2>/dev/null || true
fi
find "$APIM_HOME/bin" -iname "*.sh" -exec chmod +x {} \;

# ── deployment.toml: solo el hostname público. database.apim_db/shared_db
# quedan en su H2 embebida por defecto (ver nota al inicio del script) ──
TOML="$APIM_HOME/repository/conf/deployment.toml"
BACKUP="$TOML.orig-$(date +%Y%m%d%H%M%S)"
cp "$TOML" "$BACKUP"
log "Backup del deployment.toml original: $BACKUP"

MCP_DOMAIN="$MCP_DOMAIN" python3 - "$TOML" <<'PYEOF'
import os
import re
import sys

path = sys.argv[1]
with open(path) as f:
    content = f.read()

hostname = os.environ["MCP_DOMAIN"]

# hostname público — usado por APIM para generar URLs de la gateway/consolas
content = re.sub(r'(?m)^hostname\s*=.*$', f'hostname = "{hostname}"', content, count=1)

# https_endpoint del gateway — es el que APIM usa para construir el campo
# `resource` del PRM y la URL del header WWW-Authenticate. Si queda en el
# default (https://localhost:${mgt.transport.https.port}), el PRM anuncia
# "https://localhost:8243/..." y ningún cliente externo puede resolverlo.
# Mismo cambio que scripts/dev/setup-ngrok.sh hace con la URL de ngrok en DEV.
content = re.sub(
    r'(?m)^https_endpoint\s*=.*$',
    f'https_endpoint = "https://{hostname}"',
    content,
    count=1,
)

with open(path, "w") as f:
    f.write(content)
PYEOF

log "deployment.toml actualizado: hostname=$MCP_DOMAIN, https_endpoint=https://$MCP_DOMAIN"
log "  (database.apim_db/shared_db sin tocar — H2 por defecto)"
log "PENDIENTE fuera de este script (clase 🔴): [apim.jwt] + Key Manager federado Dnato"
log "  (ADR-008/ADR-009) — ver doc/identity/apim-keymanager-dnato.md antes de dar de alta el primer cliente"

# ── Heap sizes ─────────────────────────────────────────────────────
API_SH="$APIM_HOME/bin/api-manager.sh"
if grep -qE -- '-Xm[sx][0-9]+[mMgG]' "$API_SH" 2>/dev/null; then
  sed -i -E "s/-Xms[0-9]+[mMgG]/-Xms$APIM_XMS/g; s/-Xmx[0-9]+[mMgG]/-Xmx$APIM_XMX/g" "$API_SH"
  log "Heap del APIM ajustado en api-manager.sh: -Xms$APIM_XMS -Xmx$APIM_XMX"
else
  log "AVISO: no se encontraron flags -Xms/-Xmx en api-manager.sh — ajustar heap manualmente"
fi

# ── JAVA_HOME (JDK 21 requerido por WSO2 4.6.0 — ver doc/v3/deployment-gcp.md §4) ──
# systemd no lee /etc/profile.d, así que hace falta resolver JAVA_HOME acá y
# escribirlo explícitamente en el unit (a diferencia de DEV, que lo setea en
# el perfil de shell — ver doc/infra/wso2-install.md).
if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
  JAVA_HOME_RESOLVED="$JAVA_HOME"
else
  JAVA_BIN="$(command -v java || true)"
  [ -n "$JAVA_BIN" ] || die "No se encontró Java. Instalar JDK 21 Temurin primero (doc/v3/deployment-gcp.md §4)."
  JAVA_BIN="$(readlink -f "$JAVA_BIN")"
  JAVA_HOME_RESOLVED="$(dirname "$(dirname "$JAVA_BIN")")"
fi
"$JAVA_HOME_RESOLVED/bin/java" -version 2>&1 | grep -q '"21\.' \
  || die "Se requiere JDK 21 (WSO2 4.6.0) — detectado: $("$JAVA_HOME_RESOLVED/bin/java" -version 2>&1 | head -1)"
log "JAVA_HOME detectado: $JAVA_HOME_RESOLVED (JDK 21 verificado)"

# ── Permisos y systemd ─────────────────────────────────────────────
chown -R "$WSO2_USER:$WSO2_USER" "$APIM_HOME"

# El zip se descomprime en un directorio temporal y se mueve (mv) a
# $APIM_HOME — el mv no actualiza el contexto de SELinux, así que los
# binarios quedan etiquetados como el temp (tmp_t) y systemd no puede
# ejecutarlos ("Permission denied" aunque el chmod +x esté bien). Restaurar
# el contexto correcto en distros con SELinux (Rocky/RHEL) evita este fallo.
if command -v restorecon >/dev/null 2>&1; then
  restorecon -R "$APIM_HOME"
  log "Contexto de SELinux restaurado en $APIM_HOME"
fi

sed -e "s#{{APIM_HOME}}#$APIM_HOME#g" -e "s#{{WSO2_USER}}#$WSO2_USER#g" \
    -e "s#{{JAVA_HOME}}#$JAVA_HOME_RESOLVED#g" \
    -e "s#{{MCP_RESOURCE_URL}}#$MCP_RESOURCE_URL#g" \
    -e "s#{{DNATO_OAUTH_URL}}#$DNATO_OAUTH_URL#g" \
  "$SCRIPT_DIR/systemd/wso2am.service" > /etc/systemd/system/wso2am.service
systemctl daemon-reload
systemctl enable wso2am.service

# ── CAR OAuthDiscovery — PRM RFC 9728 (ver deployment-gcp.md §6.2-bis) ──
# Sin este CAR, /.well-known/oauth-protected-resource devuelve 404 y Claude.ai
# nunca descubre que el Authorization Server es Dnato: cae al fallback
# host-based y pega contra https://<dominio>/authorize, que no existe.
# Es un CAR del APIM, distinto e independiente del .car de ToolsAPIProject
# (ese va en el MI). Equivalente al paso 3b de scripts/dev/setup-ngrok.sh.
DISCOVERY_SRC="$SCRIPT_DIR/../../_backend/api/ApimDiscoveryProject"
DISCOVERY_CAR="$DISCOVERY_SRC/build/trazalog-discovery-1.0.0.car"
APIM_CARBONAPPS="$APIM_HOME/repository/deployment/server/carbonapps"

if [ -f "$DISCOVERY_CAR" ]; then
  mkdir -p "$APIM_CARBONAPPS"
  cp "$DISCOVERY_CAR" "$APIM_CARBONAPPS/"
  chown "$WSO2_USER:$WSO2_USER" "$APIM_CARBONAPPS/trazalog-discovery-1.0.0.car"
  log "CAR OAuthDiscovery desplegado en $APIM_CARBONAPPS"
  log "  trazalog.mcp.resource.url = $MCP_RESOURCE_URL"
  log "  trazalog.dnato.oauth.url  = $DNATO_OAUTH_URL"
else
  log "AVISO: no se encontró $DISCOVERY_CAR"
  log "  Generarlo con: bash $DISCOVERY_SRC/build.sh"
  log "  Sin este CAR el conector MCP de Claude.ai NO va a poder autenticarse."
fi

log ""
log "=== install-apim.sh COMPLETADO ==="
log "Servicio wso2am instalado y habilitado (NO se inicia automáticamente)."
log "Para arrancar: systemctl start wso2am && journalctl -u wso2am -f"
