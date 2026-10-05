#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Captura lo que pasa en el APIM y en el MI mientras se invoca una tool desde
#  el cliente MCP. El conector solo dice "MCP tool call failed", sin codigo ni
#  detalle; el error real esta en estos dos logs.
#
#  USO (por SSH en la VM):
#     bash capturar-fallo-tool.sh
#     ...y mientras corre, pedirle a Claude que ejecute la tool que falla.
#     Cortar con Ctrl+C cuando termine el intento.
# ---------------------------------------------------------------------------
set -u
MI="${MI_HOME:-$(ls -d /opt/wso2/wso2mi-* 2>/dev/null | head -1)}"
AM="${APIM_HOME:-$(ls -d /opt/wso2/wso2am-* /opt/wso2am-* 2>/dev/null | head -1)}"
MILOG="$MI/repository/logs/wso2carbon.log"
AMLOG="$AM/repository/logs/wso2carbon.log"

echo "MI  : $MILOG"
echo "APIM: $AMLOG"
for f in "$MILOG" "$AMLOG"; do
  [ -f "$f" ] || echo "  !! no existe: $f"
done
echo
echo "=== escuchando. Ahora pedile a Claude que ejecute la tool. Ctrl+C para cortar. ==="
echo

PAT='alm/pedido|man/ot|toolsMCPAPI|toolsALMAPI|toolsbpmAPI|ERROR|Timeout|TIMEOUT|101[0-9][0-9][0-9]|9009[0-9][0-9]|CORRELATION'

tail -F -n0 "$MILOG" 2>/dev/null | grep --line-buffered -E "$PAT" | sed 's/^/[MI]   /' &
P1=$!
tail -F -n0 "$AMLOG" 2>/dev/null | grep --line-buffered -E "$PAT" | sed 's/^/[APIM] /' &
P2=$!
trap 'kill $P1 $P2 2>/dev/null; echo; echo "=== fin ==="' INT TERM
wait
