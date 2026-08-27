#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Diagnostico del KPI de MTTR, capa por capa, DESDE LA VM del MCP.
#
#  Corre los 3 niveles por separado para saber DONDE se corta:
#     1. DataService      -> la query contra la base
#     2. Fachada MCP (MI) -> la tool, sin pasar por el APIM
#     3. Gateway (APIM)   -> lo que ve Claude
#
#  El MI NO valida la firma del X-JWT-Assertion: solo decodifica el payload
#  en base64 y lee los claims empr_id / empr_id_mysql (ver EmprIdFromHeader.xml).
#  Por eso el nivel 2 se puede probar con un JWT sintetico, sin Dnato.
#
#  USO (por SSH en la VM):
#     bash scripts/dev/diag-kpi-mttr.sh
#     bash scripts/dev/diag-kpi-mttr.sh 15 2026-07-01 2026-07-31
# ---------------------------------------------------------------------------
set -u
EMP="${1:-15}"          # id de empresa en assetv2 (MySQL). 15 = Tierra Capayan
INI="${2:-2026-07-01}"
FIN="${3:-2026-07-31}"
MI="http://localhost:8290"

# JWT sintetico: header.payload.firma-ignorada
JWT="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJlbXByX2lkIjoiMTUiLCJlbXByX2lkX215c3FsIjoiMTUiLCJzdWIiOiJkaWFnQHRyYXphbG9nIn0.diagnostico"

echo "empresa=$EMP  periodo=$INI..$FIN"
echo

echo "=== NIVEL 1 — DataService (la query contra la base) ==="
U1="$MI/services/MANDataService/KpiMttrxFecha/empresa/$EMP/fec_inicio/$INI/fec_fin/$FIN/empresa2/$EMP/fec_inicio2/$INI/fec_fin2/$FIN"
echo "  $U1"
curl -sS -m 120 -w '\n  -> HTTP %{http_code}  en %{time_total}s\n' -H "Accept: application/json" "$U1"
echo

echo "=== NIVEL 2 — fachada MCP en el MI (la tool, sin APIM) ==="
U2="$MI/tools/mcp/mcp/man/kpi/mttr?fec_inicio=$INI&fec_fin=$FIN"
echo "  $U2"
curl -sS -m 120 -w '\n  -> HTTP %{http_code}  en %{time_total}s\n' \
     -H "Accept: application/json" -H "X-JWT-Assertion: $JWT" "$U2"
echo

echo "=== NIVEL 2b — la misma tool SIN el header de identidad ==="
echo "  (esperado: identity_missing. Si da eso, la ruta existe y el MI esta sano)"
curl -sS -m 120 -w '\n  -> HTTP %{http_code}\n' -H "Accept: application/json" "$U2"
echo

echo "=== NIVEL 3 — gateway APIM (lo que ve Claude) ==="
curl -sS -m 120 -k -w '\n  -> HTTP %{http_code}\n' \
  -X POST "https://localhost:8243/trazalog/mcp/1.0/mcp" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"man_get_kpi_mttr\",\"arguments\":{\"fec_inicio\":\"$INI\",\"fec_fin\":\"$FIN\"}},\"id\":1}"
echo
echo "--------------------------------------------------------------------"
echo "COMO LEER EL RESULTADO"
echo "  1 falla            -> el problema es la query o la conexion a la base"
echo "  1 ok, 2 falla      -> el problema es la fachada (toolsMCPAPI en el .car)"
echo "  1 y 2 ok, 3 falla  -> el problema es el APIM (mapeo de la tool / endpoint /"
echo "                        suscripcion). Ver doc/mcp/republicar-mcp-server.md"
