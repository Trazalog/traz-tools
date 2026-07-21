#!/bin/bash
# install-apim.sh
# Instalación NATIVA (sin Docker) de WSO2 API Manager 4.6.0 en la VM de GCP.
# Aplica ADR-011: descomprime el .zip, conecta el registro/metadata interno
# de APIM a la PostgreSQL externa ya existente, ajusta el heap prioritario
# del APIM, y deja el servicio corriendo bajo systemd.
#
# Fuera de alcance de este script (ver doc/v3/deployment-gcp.md):
#   - Configuración de identidad ([apim.jwt], Key Manager federado Dnato,
#     ADR-008/ADR-009). Es clase 🔴 (identidad/seguridad) — no se toca acá.
#   - Migración de las DataServices de negocio del MI a PostgreSQL.
#
# PRE:
#   - deploy/gcp/.env presente (copiar de .env.example y completar)
#   - .zip de WSO2 APIM descargado manualmente desde wso2.com (requiere
#     cuenta) en la ruta APIM_ZIP_PATH — ver doc/infra/wso2-install.md §2
#   - Driver JDBC de PostgreSQL descargado en PG_JDBC_JAR_PATH
#     (https://jdbc.postgresql.org/download/)
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

for var in APIM_ZIP_PATH APIM_HOME APIM_XMS APIM_XMX PG_HOST PG_PORT PG_DB_APIM PG_DB_SHARED PG_USER PG_PASSWORD MCP_DOMAIN; do
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

# ── Driver JDBC PostgreSQL ────────────────────────────────────────
if [ -n "${PG_JDBC_JAR_PATH:-}" ] && [ -f "$PG_JDBC_JAR_PATH" ]; then
  cp "$PG_JDBC_JAR_PATH" "$APIM_HOME/repository/components/lib/"
  log "Driver JDBC PostgreSQL copiado a repository/components/lib/"
else
  log "AVISO: PG_JDBC_JAR_PATH no configurado o inexistente."
  log "  Copiar manualmente el .jar del driver a $APIM_HOME/repository/components/lib/ antes de arrancar."
fi

# ── deployment.toml: hostname + database.apim_db + database.shared_db ──
TOML="$APIM_HOME/repository/conf/deployment.toml"
BACKUP="$TOML.orig-$(date +%Y%m%d%H%M%S)"
cp "$TOML" "$BACKUP"
log "Backup del deployment.toml original: $BACKUP"

MCP_DOMAIN="$MCP_DOMAIN" PG_HOST="$PG_HOST" PG_PORT="$PG_PORT" \
PG_DB_APIM="$PG_DB_APIM" PG_DB_SHARED="$PG_DB_SHARED" \
PG_USER="$PG_USER" PG_PASSWORD="$PG_PASSWORD" \
python3 - "$TOML" <<'PYEOF'
import os
import re
import sys

path = sys.argv[1]
with open(path) as f:
    content = f.read()

env = os.environ
hostname = env["MCP_DOMAIN"]

# hostname público — usado por APIM para generar URLs de la gateway/consolas
content = re.sub(r'(?m)^hostname\s*=.*$', f'hostname = "{hostname}"', content, count=1)

def pg_block(db_name, db_user, db_password):
    return (
        f'type = "postgre"\n'
        f'url = "jdbc:postgresql://{env["PG_HOST"]}:{env["PG_PORT"]}/{db_name}"\n'
        f'username = "{db_user}"\n'
        f'password = "{db_password}"\n'
        f'driver = "org.postgresql.Driver"\n'
        f'validationQuery = "SELECT 1"\n'
    )

def replace_block(content, header, new_body):
    pattern = re.compile(rf'(\[{re.escape(header)}\]\n)(?:(?!\[).*\n?)*', re.MULTILINE)
    replacement = f'[{header}]\n{new_body}'
    if pattern.search(content):
        return pattern.sub(replacement, content, count=1)
    return content.rstrip('\n') + '\n\n' + replacement

content = replace_block(content, "database.apim_db", pg_block(env["PG_DB_APIM"], env["PG_USER"], env["PG_PASSWORD"]))
content = replace_block(content, "database.shared_db", pg_block(env["PG_DB_SHARED"], env["PG_USER"], env["PG_PASSWORD"]))

with open(path, "w") as f:
    f.write(content)
PYEOF

log "deployment.toml actualizado: hostname=$MCP_DOMAIN, database.apim_db y database.shared_db → PostgreSQL externa"
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

# ── Permisos y systemd ─────────────────────────────────────────────
chown -R "$WSO2_USER:$WSO2_USER" "$APIM_HOME"

sed -e "s#{{APIM_HOME}}#$APIM_HOME#g" -e "s#{{WSO2_USER}}#$WSO2_USER#g" \
  "$SCRIPT_DIR/systemd/wso2am.service" > /etc/systemd/system/wso2am.service
systemctl daemon-reload
systemctl enable wso2am.service

log ""
log "=== install-apim.sh COMPLETADO ==="
log "Servicio wso2am instalado y habilitado (NO se inicia automáticamente)."
log "Para arrancar: systemctl start wso2am && journalctl -u wso2am -f"
