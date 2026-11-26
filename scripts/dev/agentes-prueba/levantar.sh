#!/usr/bin/env bash
# Levanta lo que necesita la prueba manual de los agentes.
#
# Se corre en: terminal local, desde la raíz de la copia de prueba de Tools,
# con la conexión segura (VPN) a DEV levantada.
#
#   scripts/dev/agentes-prueba/levantar.sh          base de agentes, integrador de prueba (8301) y motor (8099)
#   scripts/dev/agentes-prueba/levantar.sh parar    apaga el integrador de prueba
#
# - El integrador de prueba es una COPIA del Micro Integrator, en
#   ~/.local/share/agentes-prueba/ (puerto 8301). El MI instalado del PM
#   (puerto 8290) no se toca nunca: la copia se hace leyéndolo, y "parar" solo
#   apaga el proceso que corre desde la carpeta de la copia.
# - El motor queda en primer plano: se corta con Ctrl+C.
# - Variables: ~/.agente-minero.env y después ~/.agentes-prueba.env, que apunta
#   a la base de agentes de prueba (agentes_manual) y al integrador de prueba.
set -euo pipefail
cd "$(dirname "$0")/../../.."

DATOS=${PRUEBA_DATOS_DIR:-$HOME/.local/share/agentes-prueba}
MI=$DATOS/wso2mi-4.5.0
MI_ORIGEN=$HOME/.wso2-mi/micro-integrator/wso2mi-4.5.0
JAVA=${JAVA_HOME:-$HOME/.wso2-mi/java/jdk-21.0.10+7}

pid_mi() { pgrep -f -- "-Dcarbon.home=$MI " || true; }

if [ "${1:-}" = parar ]; then
    p=$(pid_mi)
    [ -n "$p" ] && kill $p && echo "Integrador de prueba apagado." || echo "El integrador de prueba no estaba prendido."
    exit 0
fi

[ -f "$HOME/.agentes-prueba.env" ] || { echo "Falta ~/.agentes-prueba.env (ver doc/agente/guion-prueba-agentes.md §9)" >&2; exit 2; }
set -a; . "$HOME/.agente-minero.env"; . "$HOME/.agentes-prueba.env"; set +a

# 0. Base de agentes de prueba (contenedor; si estaba apagado, lo prende)
if command -v docker >/dev/null && docker ps -a --format '{{.Names}}' | grep -qx agentes-pg-prueba; then
    docker start agentes-pg-prueba >/dev/null
    for _ in $(seq 1 30); do
        docker exec agentes-pg-prueba pg_isready -q 2>/dev/null && break
        sleep 1
    done
    echo "✅ Base de agentes de prueba prendida"
fi

# 1. Integrador de prueba
if [ -z "$(pid_mi)" ]; then
    if [ ! -d "$MI" ]; then
        echo "Primera vez: copio el Micro Integrator a $DATOS (ocupa ~1 GB)"
        mkdir -p "$DATOS"
        cp -a "$MI_ORIGEN" "$MI"
    fi
    scripts/dev/mi-local-agentes.sh "$MI" >/dev/null
    (cd "$MI" && JAVA_HOME=$JAVA nohup bin/micro-integrator.sh > "$DATOS/mi.log" 2>&1 &)
    echo -n "Prendiendo el integrador de prueba (tarda menos de un minuto)"
    for _ in $(seq 1 90); do
        grep -q "Micro Integrator started" "$DATOS/mi.log" 2>/dev/null && break
        echo -n .; sleep 2
    done
    echo
    grep -q "Micro Integrator started" "$DATOS/mi.log" || { echo "No arrancó: mirá $DATOS/mi.log" >&2; exit 1; }
fi
echo "✅ Integrador de prueba en el puerto 8301"

# 2. Motor de los agentes
export AGENTE_PROMPTS_DIR="${AGENTE_PROMPTS_DIR:-$PWD/prompts}"
echo "✅ Motor de los agentes en el puerto 8099 (Ctrl+C para cortarlo)"
exec .venv-agente/bin/python -m uvicorn agente.api:app --host 127.0.0.1 --port 8099
