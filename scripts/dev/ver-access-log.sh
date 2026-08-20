#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  El log de Synapse no dice la URL ni el status de cada request. El access
#  log del APIM y del MI si. Esto es lo que decide si una tool fallo por
#  status, por ruta o por timeout.
#
#  USO:  bash ver-access-log.sh            ultimas lineas relevantes
#        bash ver-access-log.sh -f         seguir en vivo
# ---------------------------------------------------------------------------
set -u
MI="${MI_HOME:-$(ls -d /opt/wso2/wso2mi-* 2>/dev/null | head -1)}"
AM="${APIM_HOME:-$(ls -d /opt/wso2/wso2am-* 2>/dev/null | head -1)}"
PAT='alm/pedido|man/ot|/mcp|trazalog'

echo "=== 1. el fix del 200 esta en el CAR DESPLEGADO? ==="
CAR="$MI/repository/deployment/server/carbonapps/ToolsAPIProject_1.0.0.car"
if [ -f "$CAR" ]; then
  T=$(mktemp -d); unzip -qo "$CAR" -d "$T"
  N=$(find "$T" -name "toolsMCPAPI*.xml" | head -1 | xargs grep -c 'name="HTTP_SC" value="200"' 2>/dev/null || echo 0)
  echo "  $CAR"
  echo "  ocurrencias de HTTP_SC=200: $N   (esperado: 2)"
  [ "$N" -lt 2 ] && echo "  *** el CAR desplegado NO tiene el fix — rebuildear y volver a copiar ***"
  rm -rf "$T"
else
  echo "  no se encontro el CAR en $CAR"
fi

echo
echo "=== 2. access logs disponibles ==="
ls -1t "$AM"/repository/logs/http_access_*.log "$MI"/repository/logs/http_access_*.log 2>/dev/null | head -6

echo
echo "=== 3. requests recientes (metodo, URL, status) ==="
for L in $(ls -1t "$AM"/repository/logs/http_access_*.log 2>/dev/null | head -1) \
         $(ls -1t "$MI"/repository/logs/http_access_*.log 2>/dev/null | head -1); do
  [ -f "$L" ] || continue
  case "$L" in *wso2am*) TAG="[APIM]";; *) TAG="[MI]  ";; esac
  if [ "${1:-}" = "-f" ]; then
    tail -F -n0 "$L" | grep --line-buffered -iE "$PAT" | sed "s|^|$TAG |" &
  else
    echo "--- $TAG $L"
    grep -iE "$PAT" "$L" | tail -25 | sed "s|^|$TAG |"
  fi
done
[ "${1:-}" = "-f" ] && { echo "  (siguiendo en vivo — Ctrl+C para cortar)"; trap 'kill $(jobs -p) 2>/dev/null' INT TERM; wait; }
