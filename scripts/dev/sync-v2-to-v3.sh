#!/usr/bin/env bash
# Sincroniza fixes de develop (soporte v2) hacia develop-v3 (desarrollo v3).
# Ejecutar semanalmente. Si hay conflictos, resolver manualmente y volver a correr.
set -euo pipefail

DEVELOP="origin/develop"
TARGET="develop-v3"
MERGE_MSG="chore: sync v2 fixes from develop"

echo "→ Actualizando refs remotos"
git fetch origin

echo "→ Verificando estado del working tree"
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "✗ Hay cambios sin commitear. Hacé commit o stash antes de correr este script."
  exit 1
fi

echo "→ Cambiando a ${TARGET}"
git checkout "${TARGET}"
git pull origin "${TARGET}"

echo "→ Verificando si hay commits nuevos en develop para mergear"
COMMITS_TO_MERGE=$(git log --oneline "${TARGET}..${DEVELOP}" | wc -l | tr -d ' ')

if [ "${COMMITS_TO_MERGE}" -eq 0 ]; then
  echo "✓ develop-v3 ya está sincronizado con develop. Nada que mergear."
  exit 0
fi

echo "  ${COMMITS_TO_MERGE} commit(s) a mergear desde ${DEVELOP}:"
git log --oneline "${TARGET}..${DEVELOP}"
echo ""

echo "→ Mergeando ${DEVELOP}"
git merge "${DEVELOP}" --no-ff -m "${MERGE_MSG}"

echo "→ Push a origin"
git push origin "${TARGET}"

echo "✓ Sincronización completa"
