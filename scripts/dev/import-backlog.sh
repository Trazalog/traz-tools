#!/usr/bin/env bash
# Importa el backlog de v3 desde el CSV a GitHub Issues + Project
# Requisitos: gh CLI autenticado, csvkit (sudo apt install csvkit)
# Uso: ./import-backlog.sh trazalog-v3-issues.csv <project-number>

set -euo pipefail

CSV="${1:-trazalog-v3-issues.csv}"
PROJECT_NUMBER="${2:?'Pass project number as 2nd arg (visible in URL of Project)'}"
REPO="${3:-trazalog/traz-tools}"  # ajustar al nombre real del repo

if [[ ! -f "$CSV" ]]; then
  echo "CSV no encontrado: $CSV"
  exit 1
fi

# Saltar header
tail -n +2 "$CSV" | while IFS=, read -r title body labels status priority mes deps tipo origen stream doclink sp db epic_id; do
  # Strip quotes
  title=$(echo "$title" | sed 's/^"//;s/"$//')
  body=$(echo "$body" | sed 's/^"//;s/"$//')
  labels=$(echo "$labels" | sed 's/^"//;s/"$//')

  echo "Creando: $title"

  # Crear issue
  issue_url=$(gh issue create \
    --repo "$REPO" \
    --title "$title" \
    --body "$body" \
    --label "$labels" 2>/dev/null || echo "")

  if [[ -z "$issue_url" ]]; then
    echo "  ERROR: no se pudo crear el issue"
    continue
  fi

  echo "  Creado: $issue_url"

  # Agregar al Project
  gh project item-add "$PROJECT_NUMBER" --owner "${REPO%%/*}" --url "$issue_url" 2>/dev/null || echo "  WARN: no se pudo agregar al Project"

  sleep 1  # rate limit GitHub
done

echo "Importación completa"
