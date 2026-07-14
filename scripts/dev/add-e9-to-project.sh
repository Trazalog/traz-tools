#!/usr/bin/env bash
# ============================================================
# add-e9-to-project.sh
# Agrega los 6 issues de la épica E9 al Project board y
# completa los campos custom (Sprint, Story Points, Mes,
# Stream CICD, Tipo, Doc-link, Requiere migración BD).
#
# Hace autodiscovery del Project y de los IDs de cada campo
# custom — no requiere hardcodear IDs.
#
# Prerequisitos:
#   - gh CLI autenticado con scope 'project' (gh auth refresh -s project)
#   - jq instalado
#
# Uso: bash add-e9-to-project.sh
# ============================================================

set -euo pipefail

REPO_OWNER="Trazalog"
REPO_NAME="traz-tools"
PROJECT_TITLE="Trazalog v3 MVP"

# ── helpers ────────────────────────────────────────────────────
die() { echo "❌ $*" >&2; exit 1; }
ok()  { echo "✅ $*"; }
log() { echo "→ $*"; }

# Verificar prerequisitos
command -v jq >/dev/null || die "jq no está instalado. sudo apt install jq"
gh auth status >/dev/null 2>&1 || die "gh CLI no autenticado. gh auth login"

# Verificar scope 'project'
gh api graphql -f query='query { viewer { login } }' >/dev/null 2>&1 \
  || die "gh no tiene scope 'project'. Ejecutá: gh auth refresh -s project"

echo "═══════════════════════════════════════════════════════════"
echo "📋 Agregando E9 al Project board y completando campos"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ── PASO 1: encontrar el Project ID ────────────────────────────
log "Buscando Project '$PROJECT_TITLE'..."

# Probar primero a nivel ORG, después a nivel USER, después a nivel REPO
PROJECT_DATA=$(gh api graphql -f query='
  query($org: String!, $title: String!) {
    organization(login: $org) {
      projectsV2(first: 20, query: $title) {
        nodes { id number title }
      }
    }
  }' -f org="$REPO_OWNER" -f title="$PROJECT_TITLE" 2>/dev/null \
  | jq -r ".data.organization.projectsV2.nodes[] | select(.title==\"$PROJECT_TITLE\") | .id + \"|\" + (.number|tostring)" \
  || echo "")

if [[ -z "$PROJECT_DATA" ]]; then
  log "No encontrado a nivel org, probando a nivel repo..."
  PROJECT_DATA=$(gh api graphql -f query='
    query($owner: String!, $repo: String!) {
      repository(owner: $owner, name: $repo) {
        projectsV2(first: 20) {
          nodes { id number title }
        }
      }
    }' -f owner="$REPO_OWNER" -f repo="$REPO_NAME" \
    | jq -r ".data.repository.projectsV2.nodes[] | select(.title==\"$PROJECT_TITLE\") | .id + \"|\" + (.number|tostring)")
fi

[[ -z "$PROJECT_DATA" ]] && die "Project '$PROJECT_TITLE' no encontrado. Revisá el nombre exacto."

PROJECT_ID=$(echo "$PROJECT_DATA" | cut -d'|' -f1)
PROJECT_NUMBER=$(echo "$PROJECT_DATA" | cut -d'|' -f2)
ok "Project encontrado: #$PROJECT_NUMBER (ID: $PROJECT_ID)"
echo ""

# ── PASO 2: obtener IDs de campos custom y sus options ─────────
log "Descubriendo campos custom del Project..."

FIELDS_JSON=$(gh api graphql -f query='
  query($project: ID!) {
    node(id: $project) {
      ... on ProjectV2 {
        fields(first: 30) {
          nodes {
            ... on ProjectV2Field { id name dataType }
            ... on ProjectV2SingleSelectField {
              id name dataType
              options { id name }
            }
          }
        }
      }
    }
  }' -f project="$PROJECT_ID")

get_field_id() {
  echo "$FIELDS_JSON" | jq -r ".data.node.fields.nodes[] | select(.name==\"$1\") | .id" | head -1
}
get_option_id() {
  echo "$FIELDS_JSON" | jq -r ".data.node.fields.nodes[] | select(.name==\"$1\") | .options[]? | select(.name==\"$2\") | .id" | head -1
}

# Campos esperados — si alguno no existe, avisar pero seguir
declare -A FIELD_IDS
for f in "Sprint" "Story Points" "Mes" "Stream CICD" "Tipo" "Doc-link" "Requiere migración BD" "Status"; do
  id=$(get_field_id "$f")
  if [[ -n "$id" ]]; then
    FIELD_IDS["$f"]="$id"
    log "Campo '$f' → $id"
  else
    log "⚠️  Campo '$f' NO encontrado en el Project — se omitirá"
    FIELD_IDS["$f"]=""
  fi
done
echo ""

# ── PASO 3: para cada issue, agregar al Project y completar campos ──
echo "📌 Procesando los 6 issues de E9..."
echo ""

# Tabla de valores por issue
# Formato: ISSUE_TITLE_FRAGMENT|SPRINT|SP|MES|STREAM|TIPO|DOC|MIGRACION_BD|STATUS
declare -a ISSUES=(
  "E9-IDENT-01|Sprint 2|5|M1|Stream 1 — Features v3|Investigación|MCP_ARCHITECTURE.md#6.6|No|Sprint Ready"
  "E9-IDENT-02|Sprint 2|2|M1|Stream 1 — Features v3|Documentación|MCP_ARCHITECTURE.md#6.5|No|Backlog"
  "E9-IDENT-03|Sprint 2|8|M2|Stream 1 — Features v3|Técnica|MCP_ARCHITECTURE.md#6.7|No|Backlog"
  "E9-IDENT-04|Sprint 2|5|M2|Stream 1 — Features v3|Técnica|MCP_ARCHITECTURE.md#6.7|No|Backlog"
  "E9-IDENT-05|Sprint 2|5|M2|Stream 1 — Features v3|Técnica|MCP_ARCHITECTURE.md#6.4|No|Backlog"
  "E9-IDENT-06|Sprint 2|3|M2|Stream 1 — Features v3|Técnica|MCP_ARCHITECTURE.md#6.5|Sí|Backlog"
)

# Función para setear un campo de texto/numero
set_text_field() {
  local item_id="$1" field_id="$2" value="$3" type="$4"
  [[ -z "$field_id" || -z "$value" ]] && return 0
  if [[ "$type" == "number" ]]; then
    gh api graphql -f query='
      mutation($project:ID!,$item:ID!,$field:ID!,$value:Float!){
        updateProjectV2ItemFieldValue(input:{projectId:$project,itemId:$item,fieldId:$field,value:{number:$value}}){projectV2Item{id}}
      }' -f project="$PROJECT_ID" -f item="$item_id" -f field="$field_id" -F value="$value" >/dev/null
  else
    gh api graphql -f query='
      mutation($project:ID!,$item:ID!,$field:ID!,$value:String!){
        updateProjectV2ItemFieldValue(input:{projectId:$project,itemId:$item,fieldId:$field,value:{text:$value}}){projectV2Item{id}}
      }' -f project="$PROJECT_ID" -f item="$item_id" -f field="$field_id" -f value="$value" >/dev/null
  fi
}

# Función para setear un campo single-select por nombre de option
set_select_field() {
  local item_id="$1" field_name="$2" option_name="$3"
  local field_id="${FIELD_IDS[$field_name]}"
  [[ -z "$field_id" || -z "$option_name" ]] && return 0
  local option_id=$(get_option_id "$field_name" "$option_name")
  if [[ -z "$option_id" ]]; then
    log "  ⚠️  Option '$option_name' no existe en campo '$field_name' — omitiendo"
    return 0
  fi
  gh api graphql -f query='
    mutation($project:ID!,$item:ID!,$field:ID!,$option:String!){
      updateProjectV2ItemFieldValue(input:{projectId:$project,itemId:$item,fieldId:$field,value:{singleSelectOptionId:$option}}){projectV2Item{id}}
    }' -f project="$PROJECT_ID" -f item="$item_id" -f field="$field_id" -f option="$option_id" >/dev/null
}

for line in "${ISSUES[@]}"; do
  IFS='|' read -r FRAG SPRINT SP MES STREAM TIPO DOC MIGRA STATUS <<< "$line"
  echo "─── $FRAG ──────────────────────────"

  # Buscar issue por fragmento de título
  ISSUE_NODE_ID=$(gh issue list --repo "$REPO_OWNER/$REPO_NAME" --state open --search "$FRAG in:title" \
    --json id,title --jq ".[] | select(.title | contains(\"$FRAG\")) | .id" | head -1)
  [[ -z "$ISSUE_NODE_ID" ]] && { log "  ⚠️ issue $FRAG no encontrado, salteando"; continue; }
  log "  Issue node ID: $ISSUE_NODE_ID"

  # Agregar al Project (idempotente: si ya está, devuelve el item existente)
  ITEM_ID=$(gh api graphql -f query='
    mutation($project:ID!, $content:ID!) {
      addProjectV2ItemById(input:{projectId:$project, contentId:$content}) {
        item { id }
      }
    }' -f project="$PROJECT_ID" -f content="$ISSUE_NODE_ID" \
    | jq -r '.data.addProjectV2ItemById.item.id')
  log "  Agregado al Project (item: $ITEM_ID)"

  # Completar campos
  set_select_field "$ITEM_ID" "Sprint" "$SPRINT"
  set_text_field "$ITEM_ID" "${FIELD_IDS[Story Points]}" "$SP" "number"
  set_select_field "$ITEM_ID" "Mes" "$MES"
  set_select_field "$ITEM_ID" "Stream CICD" "$STREAM"
  set_select_field "$ITEM_ID" "Tipo" "$TIPO"
  set_text_field "$ITEM_ID" "${FIELD_IDS[Doc-link]}" "$DOC" "text"
  set_select_field "$ITEM_ID" "Requiere migración BD" "$MIGRA"
  set_select_field "$ITEM_ID" "Status" "$STATUS"

  ok "  Campos completados"
  echo ""
done

echo "═══════════════════════════════════════════════════════════"
ok "Listo. Verificá en el Project board:"
echo "   https://github.com/orgs/$REPO_OWNER/projects/$PROJECT_NUMBER"
echo ""
echo "Si algún campo dice '⚠️ no encontrado' arriba, es porque el"
echo "nombre exacto en el Project es diferente. Avisame y lo ajusto."
echo "═══════════════════════════════════════════════════════════"
