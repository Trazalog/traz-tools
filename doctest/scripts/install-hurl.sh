#!/usr/bin/env bash
# install-hurl.sh — instala Hurl (suite de tests de contrato MCP, Doc 3 §5).
#
# DÓNDE SE EJECUTA: en la terminal de la máquina donde vayas a correr los tests
#   (tu equipo local, o el runner de GitHub Actions). No necesita sudo: instala
#   el binario en ~/.local/bin (o en $HURL_INSTALL_DIR si la definís).
#
# Uso:
#   bash doctest/scripts/install-hurl.sh          # instala la versión fijada abajo
#   HURL_VERSION=8.0.1 bash doctest/scripts/install-hurl.sh
#
# Si ~/.local/bin no está en tu PATH, el script te dice qué línea agregar.
set -euo pipefail

HURL_VERSION="${HURL_VERSION:-8.0.1}"
INSTALL_DIR="${HURL_INSTALL_DIR:-$HOME/.local/bin}"

os="$(uname -s)"
arch="$(uname -m)"
case "$os-$arch" in
  Linux-x86_64)  target="x86_64-unknown-linux-gnu" ;;
  Linux-aarch64) target="aarch64-unknown-linux-gnu" ;;
  Darwin-x86_64) target="x86_64-apple-darwin" ;;
  Darwin-arm64)  target="aarch64-apple-darwin" ;;
  *)
    echo "✖ Plataforma no contemplada: $os-$arch"
    echo "  Instalá Hurl a mano desde https://github.com/Orange-OpenSource/hurl/releases"
    exit 1
    ;;
esac

if command -v hurl >/dev/null 2>&1; then
  instalada="$(hurl --version | head -1 | awk '{print $2}')"
  if [ "$instalada" = "$HURL_VERSION" ]; then
    echo "✓ Hurl $instalada ya está instalado en $(command -v hurl)"
    exit 0
  fi
  echo "→ Hurl $instalada instalado; se va a agregar la versión $HURL_VERSION en $INSTALL_DIR"
fi

tarball="hurl-${HURL_VERSION}-${target}.tar.gz"
url="https://github.com/Orange-OpenSource/hurl/releases/download/${HURL_VERSION}/${tarball}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "→ Descargando $url"
curl -fsSL "$url" -o "$tmp/$tarball"
tar -xzf "$tmp/$tarball" -C "$tmp"

mkdir -p "$INSTALL_DIR"
install -m 0755 "$tmp/hurl-${HURL_VERSION}-${target}/bin/hurl" "$INSTALL_DIR/hurl"
install -m 0755 "$tmp/hurl-${HURL_VERSION}-${target}/bin/hurlfmt" "$INSTALL_DIR/hurlfmt"

echo "✓ Instalado en $INSTALL_DIR/hurl"
"$INSTALL_DIR/hurl" --version

case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *)
    echo
    echo "⚠️  $INSTALL_DIR no está en tu PATH. Agregá esta línea a tu ~/.bashrc o ~/.zshrc:"
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    ;;
esac
