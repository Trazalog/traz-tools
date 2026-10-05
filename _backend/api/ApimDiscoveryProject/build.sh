#!/usr/bin/env bash
# build.sh — Empaqueta y deploya el CAR OAuthDiscovery en APIM.
#
# Uso:
#   bash build.sh                          # solo construye el .car
#   APIM_HOME=/ruta/apim bash build.sh     # construye + deploya
#
# El CAR contiene la Synapse API OAuthDiscovery que sirve el PRM (RFC 9728).
# Las URLs se inyectan como Java system properties en el startup de APIM:
#   -Dtrazalog.mcp.resource.url=https://<apim>/trazalog-equipos/1.0/mcp
#   -Dtrazalog.dnato.oauth.url=https://<dnato>/traz-comp-dnato/oauth
#
# setup-ngrok.sh exporta esas propiedades vía JAVA_OPTS antes de arrancar APIM.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
BUILD_DIR="$SCRIPT_DIR/build"
CAR_NAME="trazalog-discovery-1.0.0.car"

echo "=== Build OAuthDiscovery CAR ==="

mkdir -p "$BUILD_DIR"
rm -f "$BUILD_DIR/$CAR_NAME"

cd "$SRC_DIR"
zip -r "$BUILD_DIR/$CAR_NAME" . -x "*.DS_Store" > /dev/null
echo "  Generado: $BUILD_DIR/$CAR_NAME"

# Deploy si APIM_HOME está definido
if [[ -n "${APIM_HOME:-}" ]]; then
    CARBONAPPS_DIR="$APIM_HOME/repository/deployment/server/carbonapps"
    mkdir -p "$CARBONAPPS_DIR"
    cp "$BUILD_DIR/$CAR_NAME" "$CARBONAPPS_DIR/"
    echo "  Deployado en: $CARBONAPPS_DIR/$CAR_NAME"
else
    echo "  (No deployado — setear APIM_HOME para deployar automáticamente)"
    echo "  Deploy manual: cp $BUILD_DIR/$CAR_NAME \$APIM_HOME/repository/deployment/server/carbonapps/"
fi

echo "=== Listo ==="
