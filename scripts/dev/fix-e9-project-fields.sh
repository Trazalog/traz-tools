#!/usr/bin/env bash
# ============================================================
# fix-e9-project-fields.sh
# Corrige los 2 campos que no se asignaron correctamente:
#   1. Doc-link (nombre del campo difiere en el Project)
#   2. Requiere migración BD — option 'Sí' (acento o valor diferente)
#
# ANTES DE EJECUTAR: ajustar las variables de la sección
# CONFIGURACION con los nombres exactos del Project.
# ============================================================

set -euo pipefail

PROJECT_ID="PVT_kwDOAkWBOs4BWy2w"    # ya conocido del script anterior
REPO_OWNER="Trazalog"
REPO_NAME="traz-tools"

# ── CONFIGURACION — ajustar estos valores ─────────────────────

# Nombre EXACTO del campo de doc en el Project (ej: "Doc link", "Doc-Link", "Link")
DOC_FIELD_NAME="Doc-Link"

# Nombre EXACTO de la option 'Sí' en el campo Requiere migración BD
# (ej: "Si", "Sí", "YES", "Requiere", "true")
OPCION_SI="Si"

# ─────────────────────────────────────────────────────────────

die() { echo "❌ $*" >&2; exit 1; }
ok()  { echo "✅ $*"; }
log() { echo "→ $*"; }

echo "═══════════════════════════════════════════════════════════"
echo "🔧 Corrigiendo campos Doc-link y Requiere migración BD"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Obtener campos del Project
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

# Mostrar todos los campos disponibles para que puedas ver los nombres exactos
echo "Campos disponibles en el Project:"
echo "$FIELDS_JSON" | jq -r '.data.node.fields.nodes[] | "  \(.name) [\(.dataType)]"'
echo ""

get_field_id() {
  echo "$FIELDS_JSON" | jq -r ".data.node.fields.nodes[] | select(.name==\"$1\") | .id" | head -1
}
get_option_id() {
  echo "$FIELDS_JSON" | jq -r ".data.node.fields.nodes[] | select(.name==\"$1\") | .options[]? | select(.name==\"$2\") | .id" | head -1
}

# Mostrar opciones del campo Requiere migración BD
echo "Opciones disponibles en 'Requiere migración BD':"
echo "$FIELDS_JSON" | jq -r '.data.node.fields.nodes[] | select(.name=="Requiere migración BD") | .options[]? | "  \(.name) → \(.id)"'
echo ""

# IDs de los campos
DOC_FIELD_ID=$(get_field_id "$DOC_FIELD_NAME")
MIGRA_FIELD_ID=$(get_field_id "Requiere migración BD")
MIGRA_SI_OPTION_ID=$(get_option_id "Requiere migración BD" "$OPCION_SI")

[[ -z "$DOC_FIELD_ID" ]] && echo "⚠️  Campo '$DOC_FIELD_NAME' no encontrado — ajustá DOC_FIELD_NAME arriba" || log "Campo Doc: $DOC_FIELD_ID"
[[ -z "$MIGRA_SI_OPTION_ID" ]] && echo "⚠️  Option '$OPCION_SI' no encontrada — ajustá OPCION_SI arriba" || log "Option Sí: $MIGRA_SI_OPTION_ID"

# Item IDs ya conocidos del script anterior
declare -A ITEMS=(
  ["E9-IDENT-01"]="PVTI_lADOAkWBOs4BWy2wzgtXWB8"
  ["E9-IDENT-02"]="PVTI_lADOAkWBOs4BWy2wzgtXWDs"
  ["E9-IDENT-03"]="PVTI_lADOAkWBOs4BWy2wzgtXWFo"
  ["E9-IDENT-04"]="PVTI_lADOAkWBOs4BWy2wzgtXWG0"
  ["E9-IDENT-05"]="PVTI_lADOAkWBOs4BWy2wzgtXWIg"
  ["E9-IDENT-06"]="PVTI_lADOAkWBOs4BWy2wzgtXWM4"
)

# Doc-link por issue
declare -A DOC_VALUES=(
  ["E9-IDENT-01"]="MCP_ARCHITECTURE.md#6.6"
  ["E9-IDENT-02"]="MCP_ARCHITECTURE.md#6.5"
  ["E9-IDENT-03"]="MCP_ARCHITECTURE.md#6.7"
  ["E9-IDENT-04"]="MCP_ARCHITECTURE.md#6.7"
  ["E9-IDENT-05"]="MCP_ARCHITECTURE.md#6.4"
  ["E9-IDENT-06"]="MCP_ARCHITECTURE.md#6.5"
)

echo ""
echo "📌 Aplicando correcciones..."
echo ""

for ISSUE in E9-IDENT-01 E9-IDENT-02 E9-IDENT-03 E9-IDENT-04 E9-IDENT-05 E9-IDENT-06; do
  ITEM_ID="${ITEMS[$ISSUE]}"
  echo "─── $ISSUE ───"

  # Doc-link (campo de texto)
  if [[ -n "$DOC_FIELD_ID" ]]; then
    gh api graphql -f query='
      mutation($project:ID!,$item:ID!,$field:ID!,$value:String!){
        updateProjectV2ItemFieldValue(input:{projectId:$project,itemId:$item,fieldId:$field,value:{text:$value}}){projectV2Item{id}}
      }' \
      -f project="$PROJECT_ID" -f item="$ITEM_ID" \
      -f field="$DOC_FIELD_ID" -f value="${DOC_VALUES[$ISSUE]}" >/dev/null
    log "  Doc-link: ${DOC_VALUES[$ISSUE]}"
  fi

  # Requiere migración BD = Sí (solo E9-IDENT-06)
  if [[ "$ISSUE" == "E9-IDENT-06" && -n "$MIGRA_FIELD_ID" && -n "$MIGRA_SI_OPTION_ID" ]]; then
    gh api graphql -f query='
      mutation($project:ID!,$item:ID!,$field:ID!,$option:String!){
        updateProjectV2ItemFieldValue(input:{projectId:$project,itemId:$item,fieldId:$field,value:{singleSelectOptionId:$option}}){projectV2Item{id}}
      }' \
      -f project="$PROJECT_ID" -f item="$ITEM_ID" \
      -f field="$MIGRA_FIELD_ID" -f option="$MIGRA_SI_OPTION_ID" >/dev/null
    log "  Requiere migración BD: $OPCION_SI"
  fi

  ok "  $ISSUE corregido"
done

echo ""
echo "═══════════════════════════════════════════════════════════"
ok "Correcciones aplicadas"
echo "   Verificá: https://github.com/orgs/Trazalog/projects/3"
echo "═══════════════════════════════════════════════════════════"
