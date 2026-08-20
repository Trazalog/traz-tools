#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  HIPOTESIS: queda algo asociado al nombre/contexto del MCP Server que
#  sobrevive al borrado, y por eso un artefacto nuevo vuelve a mapear
#  exactamente las mismas 9 operaciones viejas.
#
#  Esta prueba crea un MCP Server con nombre y contexto COMPLETAMENTE NUEVOS,
#  a partir del proyecto ya reparado (que lleva los 17 apiOperationMapping en
#  el YAML). No toca el MCP Server actual.
#
#  Si las 17 mapean -> era el nombre/contexto, y hay solucion.
#  Si vuelven a fallar las mismas 8 -> el problema es de las operaciones.
#
#  USO:  bash probar-mcp-nombre-nuevo.sh [nombre] [contexto]
# ---------------------------------------------------------------------------
set -u
ENV="${APICTL_ENV:-prod}"
NUEVO_NOMBRE="${1:-Trazalog Tools}"
NUEVO_CTX="${2:-/trazalog/tools}"
VER="1.0"
SRC="/tmp/mcp-apictl/src"
WORK=/tmp/mcp-nuevo; rm -rf "$WORK"; mkdir -p "$WORK"

[ -d "$SRC" ] || { echo "no existe $SRC — correr antes fix-mcp-via-apictl.sh"; exit 2; }
cp -r "$SRC" "$WORK/src"
YML=$(find "$WORK/src" -name "mcp_server.yaml" | head -1)
[ -z "${YML:-}" ] && { echo "no se encontro mcp_server.yaml"; exit 2; }

echo "=== renombrando el proyecto ==="
python3 - "$YML" "$NUEVO_NOMBRE" "$NUEVO_CTX" <<'PY'
import sys, yaml
p, nombre, ctx = sys.argv[1], sys.argv[2], sys.argv[3]
doc = yaml.safe_load(open(p, encoding='utf-8'))
d = doc.get("data", doc)
print(f"  {d.get('name')} ({d.get('context')})  ->  {nombre} ({ctx})")
d["name"] = nombre
d["displayName"] = nombre
d["context"] = ctx
d.pop("id", None)                      # que el APIM asigne uno nuevo
d["lifeCycleStatus"] = "CREATED"       # alta limpia
ops = d.get("operations", [])
con = sum(1 for o in ops if o.get("apiOperationMapping"))
print(f"  {len(ops)} tools, {con} con apiOperationMapping en el YAML")
yaml.safe_dump(doc, open(p, "w", encoding='utf-8'), allow_unicode=True, sort_keys=False)
PY

# el directorio raiz del proyecto lleva el nombre
OLD_DIR=$(find "$WORK/src" -maxdepth 1 -mindepth 1 -type d | head -1)
NEW_DIR="$WORK/src/${NUEVO_NOMBRE}-${VER}"
[ "$OLD_DIR" != "$NEW_DIR" ] && mv "$OLD_DIR" "$NEW_DIR"

ZIP="$WORK/${NUEVO_NOMBRE}_${VER}.zip"
( cd "$WORK/src" && zip -qr "$ZIP" . )
echo "  proyecto: $ZIP"

echo
echo "=== importando como MCP Server NUEVO (no toca el actual) ==="
apictl import mcp-server -f "$ZIP" -e "$ENV" --rotate-revision 2>&1 | tail -8

echo
echo "=== resultado: cuantas tools quedaron mapeadas ==="
echo "  bash /tmp/diag-mcp-mapping.sh    (va a listar los DOS MCP Servers)"
echo
echo "  Si el nuevo tiene 17 con mapping -> era el nombre/contexto."
echo "  Despues hay que: Deploy + Publish + suscribir la app en el DevPortal,"
echo "  y apuntar el conector de Claude a la URL nueva:"
echo "     https://mcp.cloudtrazalog.com${NUEVO_CTX}/${VER}/mcp"
