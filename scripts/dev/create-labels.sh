#!/bin/bash
# Script para crear todos los labels necesarios para el backlog v3
# Uso: chmod +x create-labels.sh && ./create-labels.sh

set -euo pipefail

REPO="Trazalog/traz-tools"

echo "Creando labels en $REPO..."
echo ""

# Epic labels
echo "Epic labels:"
gh label create "e0" --repo "$REPO" --color "C5E1A5" --description "Épica 0 - Infraestructura" 2>/dev/null || echo "  e0: ya existe"
gh label create "e1" --repo "$REPO" --color "B3E5FC" --description "Épica 1 - APIs WSO2" 2>/dev/null || echo "  e1: ya existe"
gh label create "e2" --repo "$REPO" --color "B3E5FC" --description "Épica 2 - MCP Gateway" 2>/dev/null || echo "  e2: ya existe"
gh label create "e3" --repo "$REPO" --color "FFE0B2" --description "Épica 3 - Experiencias" 2>/dev/null || echo "  e3: ya existe"
gh label create "e4" --repo "$REPO" --color "FFE0B2" --description "Épica 4 - Descubrimiento" 2>/dev/null || echo "  e4: ya existe"
gh label create "e5" --repo "$REPO" --color "F8BBD0" --description "Épica 5 - Pricing" 2>/dev/null || echo "  e5: ya existe"
gh label create "e6" --repo "$REPO" --color "F8BBD0" --description "Épica 6 - Early Adopter" 2>/dev/null || echo "  e6: ya existe"
gh label create "e7" --repo "$REPO" --color "D1C4E9" --description "Épica 7 - CI/CD" 2>/dev/null || echo "  e7: ya existe"
gh label create "e8" --repo "$REPO" --color "D1C4E9" --description "Épica 8 - Regresión Pareto" 2>/dev/null || echo "  e8: ya existe"
gh label create "e9" --repo "$REPO" --color "ECEFF1" --description "Épica 9 - Backlog Futuro" 2>/dev/null || echo "  e9: ya existe"

echo ""
echo "Priority labels (MoSCoW):"
gh label create "must-have" --repo "$REPO" --color "B71C1C" --description "MoSCoW: Must have" 2>/dev/null || echo "  must-have: ya existe"
gh label create "should-have" --repo "$REPO" --color "F57F17" --description "MoSCoW: Should have" 2>/dev/null || echo "  should-have: ya existe"
gh label create "could-have" --repo "$REPO" --color "33691E" --description "MoSCoW: Could have" 2>/dev/null || echo "  could-have: ya existe"
gh label create "wont-have" --repo "$REPO" --color "424242" --description "MoSCoW: Won't have (this iteration)" 2>/dev/null || echo "  wont-have: ya existe"

echo ""
echo "Type labels:"
gh label create "type:técnica" --repo "$REPO" --color "0288D1" --description "Tarea técnica" 2>/dev/null || echo "  type:técnica: ya existe"
gh label create "type:funcional" --repo "$REPO" --color "00897B" --description "Feature funcional" 2>/dev/null || echo "  type:funcional: ya existe"
gh label create "type:documentación" --repo "$REPO" --color "8E24AA" --description "Documentación" 2>/dev/null || echo "  type:documentación: ya existe"
gh label create "type:investigación" --repo "$REPO" --color "5D4037" --description "Research/Análisis" 2>/dev/null || echo "  type:investigación: ya existe"

echo ""
echo "Other labels:"
gh label create "db-migration" --repo "$REPO" --color "C62828" --description "Requiere migración de schema BD" 2>/dev/null || echo "  db-migration: ya existe"

echo ""
echo "✓ Labels creados"
echo ""
echo "PRÓXIMO PASO:"
echo "Ejecutá: ./create-backlog-issues.sh"
