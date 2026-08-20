#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Repara el apiOperationMapping de las tools del MCP Server usando apictl,
#  que es un camino distinto al Publisher REST API (el PUT no persiste el
#  mapping — verificado 2 veces, ver doc/mcp/republicar-mcp-server.md).
#
#  Por que puede funcionar: el proyecto que exporta apictl incluye el
#  apiOperationMapping explicito en mcp_server.yaml, y el import lo lee de ahi
#  (confirmado en wso2/api-manager#5174, que muestra esa estructura).
#
#  Flujo:  export -> completar los mappings faltantes en el YAML -> import
#
#  Requiere apictl instalado. Si no lo esta:
#    curl -LO https://github.com/wso2/product-apim-tooling/releases/download/v4.6.1/apictl-4.6.1-linux-amd64.tar.gz
#    tar -xzf apictl-4.6.1-linux-amd64.tar.gz && sudo mv apictl /usr/local/bin/
#    apictl version
#
#  USO:
#    bash fix-mcp-via-apictl.sh                # exporta y muestra que cambiaria
#    bash fix-mcp-via-apictl.sh --apply        # ademas importa
# ---------------------------------------------------------------------------
set -u
ENV="${APICTL_ENV:-prod}"
NAME="${MCP_NAME:-Trazalog MCP}"
VER="${MCP_VER:-1.0}"
APPLY="${1:-}"
WORK=/tmp/mcp-apictl; rm -rf "$WORK"; mkdir -p "$WORK"

command -v apictl >/dev/null || { echo "apictl no esta instalado — ver el encabezado de este script"; exit 2; }

echo "=== entorno apictl ==="
apictl get envs 2>/dev/null | head -5
echo
echo "  Si '$ENV' no aparece arriba, crearlo y loguearse primero:"
echo "     apictl add env $ENV --apim https://localhost:9443"
echo "     apictl login $ENV -u admin"
echo

echo "=== 1. exportar el MCP Server ==="
apictl export mcp-server -n "$NAME" -v "$VER" -e "$ENV" --format YAML 2>&1 | tail -3
ZIP=$(find "$HOME/.wso2apictl/exported/mcp-servers/$ENV" -name "*.zip" -newermt "-5 minutes" 2>/dev/null | head -1)
[ -z "${ZIP:-}" ] && ZIP=$(find "$HOME/.wso2apictl/exported" -name "*.zip" 2>/dev/null | head -1)
[ -z "${ZIP:-}" ] && { echo "no se encontro el zip exportado"; exit 2; }
echo "  zip: $ZIP"

echo
echo "=== 2. completar los apiOperationMapping faltantes ==="
unzip -qo "$ZIP" -d "$WORK/src"
YML=$(find "$WORK/src" -name "mcp_server.yaml" | head -1)
[ -z "${YML:-}" ] && { echo "no se encontro mcp_server.yaml en el proyecto"; find "$WORK/src" -type f | head -20; exit 2; }
echo "  yaml: ${YML#$WORK/src/}"
cp "$YML" "$WORK/mcp_server.yaml.bak"

python3 - "$YML" <<'PY'
import sys, json
try:
    import yaml
except ImportError:
    print("  falta PyYAML:  sudo dnf install -y python3-pyyaml   (o pip3 install pyyaml)"); sys.exit(2)

MAPEO = {
 "man_get_lecturas":           ("GET", "/mcp/man/lecturas"),
 "man_get_preventivos":        ("GET", "/mcp/man/preventivos"),
 "man_get_kpi_disponibilidad": ("GET", "/mcp/man/kpi/disponibilidad"),
 "man_get_kpi_mttr":           ("GET", "/mcp/man/kpi/mttr"),
 "man_get_kpi_mttf":           ("GET", "/mcp/man/kpi/mttf"),
 "man_get_kpi_fallas":         ("GET", "/mcp/man/kpi/fallas"),
 "alm_get_depositos":          ("GET", "/mcp/alm/depositos"),
 "alm_get_vencimientos":       ("GET", "/mcp/alm/vencimientos"),
}
p = sys.argv[1]
doc = yaml.safe_load(open(p, encoding='utf-8'))
data = doc.get("data", doc)
ops = data.get("operations", [])
ref = next((o.get("apiOperationMapping") for o in ops if o.get("apiOperationMapping")), None)
if not ref:
    print("  ninguna tool tiene mapping en el YAML: no se puede deducir la API fuente"); sys.exit(2)
print(f"  API fuente: {ref.get('apiName')} ({ref.get('apiId')})  ctx={ref.get('apiContext')}")
n = 0
for o in ops:
    if o.get("apiOperationMapping"): continue
    t = o.get("target")
    if t not in MAPEO:
        print(f"    ?? {t} sin regla — se deja"); continue
    verb, target = MAPEO[t]
    o["apiOperationMapping"] = {
        "apiId": ref["apiId"], "apiName": ref["apiName"],
        "apiVersion": ref["apiVersion"], "apiContext": ref["apiContext"],
        "backendOperation": {"target": target, "verb": verb},
    }
    print(f"    -> {t:30} {verb} {target}")
    n += 1
if n:
    yaml.safe_dump(doc, open(p, "w", encoding='utf-8'), allow_unicode=True, sort_keys=False)
print(f"  {n} mapping(s) completados en el YAML")
PY
[ $? -ne 0 ] && exit 2

echo
echo "=== 3. re-empaquetar ==="
BASE=$(basename "$ZIP"); NEW="$WORK/$BASE"
( cd "$WORK/src" && zip -qr "$NEW" . )
echo "  $NEW"

if [ "$APPLY" != "--apply" ]; then
  echo
  echo "DRY-RUN. Para importarlo:"
  echo "  apictl import mcp-server -f \"$NEW\" -e $ENV --update-mcp-server=true --rotate-revision"
  echo "  (o volver a correr este script con --apply)"
  exit 0
fi

echo
echo "=== 4. importar ==="
apictl import mcp-server -f "$NEW" -e "$ENV" --update-mcp-server=true --rotate-revision 2>&1 | tail -10

echo
echo "=== 5. verificar ==="
echo "  python3 /tmp/mcp-smoke-tools.py"
