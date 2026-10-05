#!/bin/bash
# Actualiza el issue E7-CICD-01 en GitHub con el body actualizado
# (incluye creación de CLAUDE.md que faltaba)
# Uso: chmod +x update-issues-after-fix.sh && ./update-issues-after-fix.sh

set -euo pipefail

REPO="Trazalog/traz-tools"

echo "Buscando issue E7-CICD-01 en $REPO..."

# Buscar el número del issue por título
ISSUE_NUM=$(gh issue list \
  --repo "$REPO" \
  --search '"[E7-CICD-01]" in:title' \
  --state all \
  --limit 1 \
  --json number \
  --jq '.[0].number')

if [[ -z "$ISSUE_NUM" || "$ISSUE_NUM" == "null" ]]; then
  echo "ERROR: No se encontró el issue E7-CICD-01"
  echo "Verificá que ya creaste los issues con create-backlog-issues.sh"
  exit 1
fi

echo "Encontrado: issue #$ISSUE_NUM"

# Crear archivo temporal con el nuevo body
NEW_BODY=$(mktemp)
cat > "$NEW_BODY" << 'BODY_EOF'
Como PM técnico, necesito la rama develop-v3 creada y protegida en GitHub, para separar el flujo de features de v3 del flujo de soporte de v2 (que sigue en develop).

Decisión documentada en CICD_STRATEGY: develop sigue siendo línea de soporte v2 sin cambios; develop-v3 es donde se construye v3.

Esta tarea es **mixta**:
- Pasos que requieren permisos admin de GitHub → los hace el PM (vos)
- Archivos del repo (CLAUDE.md, CONTRIBUTING.md, PR template) → los hace Claude Code CLI

CRITERIOS DE ACEPTACIÓN:
1. Rama develop-v3 creada a partir de develop actual (lo hace PM)
2. Branch protection configurada: requiere PR, requiere CI verde, no permite force push (lo hace PM en UI de GitHub)
3. CONTRIBUTING.md actualizado con sección "Trabajo en v3" aclarando: features v3 → develop-v3, fixes v2 → develop, sync semanal (lo hace Claude CLI)
4. PR template configurado en .github/pull_request_template.md con checklist mínimo: descripción del cambio, issue linkeado, AC cumplido, tests pasando (lo hace Claude CLI)
5. Archivo CLAUDE.md creado en la raíz del repo con contexto persistente del proyecto: qué es Trazalog v3, stack técnico (PHP/CodeIgniter 3, WSO2 4.6.0, Bonita BPM, MySQL/MariaDB), estructura del repo, convenciones de código, convenciones de branching, links a documentos de referencia (docs/v3/MCP_ARCHITECTURE.md, CICD_STRATEGY.md), comandos comunes. Este archivo lo lee Claude Code CLI automáticamente al arrancar cada sesión, ahorrando tiempo de contexto (lo hace Claude CLI)

DEFINICIÓN DE LISTO:
- [ ] Rama develop-v3 visible en GitHub
- [ ] Branch protection activa
- [ ] CONTRIBUTING.md actualizado
- [ ] PR template creado
- [ ] CLAUDE.md creado en la raíz del repo
- [ ] Reviewed por PM
BODY_EOF

# Actualizar el issue
echo "Actualizando body del issue #$ISSUE_NUM..."
gh issue edit "$ISSUE_NUM" \
  --repo "$REPO" \
  --body-file "$NEW_BODY"

rm -f "$NEW_BODY"

echo ""
echo "✓ Issue #$ISSUE_NUM (E7-CICD-01) actualizado correctamente"
echo ""
echo "Cambios aplicados:"
echo "  - Aclarado que la tarea es mixta (PM + Claude CLI)"
echo "  - Agregado AC #5: crear archivo CLAUDE.md en la raíz del repo"
echo "  - Agregado checklist de DoD: CLAUDE.md creado"
echo ""
echo "Para verificar: https://github.com/$REPO/issues/$ISSUE_NUM"
