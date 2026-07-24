#!/bin/bash
# setup-reverse-proxy.sh
# Instala Caddy nativo (repo oficial, sin Docker) y lo configura como reverse
# proxy TLS para mcp.cloudtrazalog.com → APIM Gateway (:8243). Aplica ADR-011
# #7 (Let's Encrypt automático) y #9 (9443 nunca público).
#
# SO objetivo: Rocky Linux 9 (IDR-001 en TRAZALOG_v3_MCP_ARCHITECTURE.md §9-10 —
# no Ubuntu ni CentOS 7). Fuente de instalación: repo oficial de Caddy vía Copr
# (https://caddyserver.com/docs/install#fedora-redhat-centos).
#
# PRE: deploy/gcp/.env presente, con MCP_DOMAIN y LETSENCRYPT_EMAIL completos.
#      DNS de MCP_DOMAIN ya apuntando a la IP pública de esta VM (paso manual
#      de Rodolfo en su consola de GCP — ver doc/v3/deployment-gcp.md).
#      Firewall del proyecto GCP con 80/443 abiertos y 9443 cerrado al público.
# USO: sudo ./setup-reverse-proxy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

log() { echo "[reverse-proxy] $*"; }
die() { echo "[ERROR] $*" >&2; exit 1; }

[ -f "$ENV_FILE" ] || die "No se encontró $ENV_FILE — copiar .env.example y completar"
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

for var in MCP_DOMAIN LETSENCRYPT_EMAIL; do
  [ -n "${!var:-}" ] || die "Falta $var en .env"
done

# ── Instalación de Caddy (repo oficial vía Copr, si no está instalado) ──
if ! command -v caddy >/dev/null 2>&1; then
  log "Instalando Caddy desde el repo oficial (Copr, sección CentOS/RHEL de caddyserver.com/docs/install)..."
  dnf install -y dnf-plugins-core
  dnf copr enable -y @caddy/caddy
  dnf install -y caddy
else
  log "Caddy ya está instalado ($(caddy version))"
fi

# ── Config: Caddyfile + env file para el servicio systemd ────────
cp "$SCRIPT_DIR/reverse-proxy/Caddyfile" /etc/caddy/Caddyfile

cat > /etc/caddy/gcp.env <<EOF
MCP_DOMAIN=$MCP_DOMAIN
LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL
EOF
chmod 600 /etc/caddy/gcp.env

mkdir -p /etc/systemd/system/caddy.service.d
cat > /etc/systemd/system/caddy.service.d/override.conf <<'EOF'
[Service]
EnvironmentFile=/etc/caddy/gcp.env
EOF

mkdir -p /var/log/caddy
chown caddy:caddy /var/log/caddy

systemctl daemon-reload
systemctl enable caddy
systemctl restart caddy

log ""
log "=== setup-reverse-proxy.sh COMPLETADO ==="
log "Caddy escuchando en :80/:443 para $MCP_DOMAIN, proxy a https://127.0.0.1:8243"
log "Verificar: systemctl status caddy && curl -I https://$MCP_DOMAIN"
log "Recordar: el firewall del proyecto GCP debe abrir 80/443 y NO exponer 9443 (ADR-011 #9)"
