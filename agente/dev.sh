#!/usr/bin/env bash
# Levanta el orquestador en desarrollo, sin Docker.
#
#   ./agente/dev.sh            arranca el servicio en el puerto 8099
#   ./agente/dev.sh test       corre la suite de tests
#   ./agente/dev.sh smoke      corre el smoke test real (gasta tokens)
#
# Usa el venv de .venv-agente, y lo crea si no existe.
set -euo pipefail
cd "$(dirname "$0")/.."

VENV=.venv-agente
PY=${PYTHON:-/usr/bin/python3.12}

if [ ! -d "$VENV" ]; then
    echo "Creando entorno virtual en $VENV con $PY"
    "$PY" -m venv "$VENV"
    "$VENV/bin/pip" install --quiet --upgrade pip
    "$VENV/bin/pip" install --quiet -r agente/requirements-dev.txt
fi

# Variables: primero .env del repo, despues ~/.agente-minero.env si existe.
[ -f .env ] && { set -a; . ./.env; set +a; }
[ -f "$HOME/.agente-minero.env" ] && { set -a; . "$HOME/.agente-minero.env"; set +a; }
export AGENTE_PROMPT_PATH="${AGENTE_PROMPT_PATH:-$PWD/prompts/agente-minero.md}"

case "${1:-run}" in
    test)  exec "$VENV/bin/python" -m pytest tests/ -q ;;
    smoke) AGENTE_SMOKE_REAL=1 exec "$VENV/bin/python" -m pytest tests/test_smoke_real.py -v ;;
    run)   exec "$VENV/bin/python" -m uvicorn agente.api:app --host 127.0.0.1 --port 8099 --reload ;;
    *)     echo "uso: $0 [run|test|smoke]" >&2; exit 2 ;;
esac
