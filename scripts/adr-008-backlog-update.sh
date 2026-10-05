#!/usr/bin/env bash
# ============================================================
# adr-008-backlog-update.sh
# Registra en GitHub las 5 tareas derivadas de ADR-008
# (validación JWT en APIM como Key Manager federado).
#
# Todas estas tareas YA FUERON EJECUTADAS Y VERIFICADAS en DEV
# por Claude Code, así que se crean y se cierran en el mismo paso,
# dejando el registro histórico en el backlog.
#
# También actualiza E9-IDENT-05 con una nota de reorientación
# (su mitad WSO2/MI fue reemplazada por el enfoque APIM de ADR-008).
#
# Prerequisito: gh CLI autenticado.
# Uso: bash adr-008-backlog-update.sh
# ============================================================

set -euo pipefail

REPO="Trazalog/traz-tools"

echo "═══════════════════════════════════════════════════════════"
echo "🔐 Registrando tareas ADR-008 (ya ejecutadas en DEV)"
echo "   Repo: $REPO"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ── Label para ADR-008 ─────────────────────────────────────────
gh label create "adr-008" --color "5319E7" \
  --description "Validación JWT en APIM como Key Manager federado" \
  --repo "$REPO" 2>/dev/null && echo "+ label adr-008 creado" || echo "= label adr-008 ya existe"
echo ""

# ── Función: crear issue ya cerrado con comentario de cierre ──
create_closed_issue() {
  local title="$1"
  local body="$2"
  local close_comment="$3"

  echo "📌 $title"
  # Crear el issue
  local url=$(gh issue create --repo "$REPO" \
    --title "$title" \
    --label "e9,adr-008,must-have,type:técnica" \
    --body "$body")
  echo "   creado: $url"
  # Extraer número y cerrarlo
  local num=$(echo "$url" | grep -oE '[0-9]+$')
  gh issue close "$num" --repo "$REPO" --comment "$close_comment"
  echo "   ✅ cerrado (#$num)"
  echo ""
}

# ── B1 ─────────────────────────────────────────────────────────
create_closed_issue \
  "[E9-IDENT-07] ADR-008 B1 — Exponer JWKS de Dnato accesible para APIM" \
  "Derivada de ADR-008. Dnato expone su JWKS endpoint (\`/oauth/.well-known/jwks.json\`) con la clave pública RS256 para que el APIM valide la firma de los JWT emitidos por Dnato.

## DoD
- [x] JWKS endpoint accesible desde el APIM
- [x] Clave pública RS256 publicada en el JWKS

**Ref:** MCP_ARCHITECTURE.md ADR-008
**Sprint:** Sprint 2" \
  "✅ Verificado en DEV. JWKS accesible (B1 del checklist ADR-008). Ejecutado por Claude Code."

# ── B2 ─────────────────────────────────────────────────────────
create_closed_issue \
  "[E9-IDENT-08] ADR-008 B2 — Configurar Dnato como Key Manager federado en APIM" \
  "Derivada de ADR-008. Se configura Dnato como Key Manager externo en el APIM (módulo Key Managers en /admin). El APIM valida los JWT directamente vía el JWKS de Dnato, reemplazando el patrón passthrough donde el MI validaba con JwtValidator.xml.

## DoD
- [x] Dnato registrado como Key Manager externo en APIM
- [x] Validación JWT activa vía JWKS endpoint de Dnato
- [x] OAuth2 nativo del APIM sigue activo para APIs legacy (coexistencia)

**Ref:** MCP_ARCHITECTURE.md ADR-008
**Sprint:** Sprint 2" \
  "✅ Verificado en DEV. KM Dnato configurado en APIM (B2 del checklist ADR-008). Ejecutado por Claude Code."

# ── B3 ─────────────────────────────────────────────────────────
create_closed_issue \
  "[E9-IDENT-09] ADR-008 B3 — EmprIdInjectorPolicy en APIM + publicar APIs" \
  "Derivada de ADR-008. La inyección de \`X-Empr-Id\` se hace ahora como policy/mediación del APIM (no del MI). El APIM extrae el claim \`empr_id\` del JWT ya validado y lo inyecta como header downstream. Las APIs de Equipos y OTs se publican con esta policy aplicada.

## DoD
- [x] EmprIdInjectorPolicy configurada en el APIM
- [x] Anti-spoofing verificado: el APIM ignora cualquier X-Empr-Id que mande el cliente e inyecta el del JWT (verificado: cliente manda 999, APIM inyecta 42 del JWT)
- [x] APIs Equipos y OTs publicadas con la policy

**Ref:** MCP_ARCHITECTURE.md ADR-008
**Sprint:** Sprint 2" \
  "✅ Verificado en DEV. EmprIdInjectorPolicy + APIs publicadas (B3 del checklist ADR-008). Anti-spoofing confirmado: APIM ignora X-Empr-Id:999 del cliente e inyecta 42 del JWT. Ejecutado por Claude Code."

# ── B4 ─────────────────────────────────────────────────────────
create_closed_issue \
  "[E9-IDENT-10] ADR-008 B4 — Desplegar CAR al MI corriendo en :8290" \
  "Derivada de ADR-008. El MI recibe el \`X-Empr-Id\` ya validado e inyectado por el APIM — NO ejecuta JwtValidator.xml para tráfico MCP. CAR desplegado, MI corriendo en el puerto :8290.

## DoD
- [x] CAR desplegado al MI
- [x] MI corriendo en :8290
- [x] MI recibe X-Empr-Id del APIM (log confirmado: TARGET_CONTEXT = .../mcp/equipos/42)

**Ref:** MCP_ARCHITECTURE.md ADR-008
**Sprint:** Sprint 2" \
  "✅ Verificado en DEV. CAR desplegado, MI en :8290 recibe X-Empr-Id (B4 del checklist ADR-008). Ejecutado por Claude Code."

# ── B5 ─────────────────────────────────────────────────────────
create_closed_issue \
  "[E9-IDENT-11] ADR-008 B5 — Tests Hurl de validación JWT en APIM" \
  "Derivada de ADR-008. Tests de seguridad ejecutados en DEV contra el APIM (:8243).

## Casos verificados en DEV
- [x] 503 sin X-Empr-Id (Fix 3)
- [x] JWT inválido → 401
- [x] JWT real firmado con clave Dnato → APIM acepta, empr_id=42 llega al MI
- [x] Anti-spoofing: APIM ignora X-Empr-Id:999 del cliente, inyecta 42 del JWT

## Pendiente para TEST/PROD (requiere BD con datos)
- [ ] Casos 'g' de aislamiento SQL end-to-end — marcados con TODO en los tests

**Ref:** MCP_ARCHITECTURE.md ADR-008
**Sprint:** Sprint 2" \
  "✅ Verificado en DEV. Tests Hurl ejecutados, anti-spoofing OK (B5 del checklist ADR-008). Casos 'g' de aislamiento SQL quedan como TODO para TEST/PROD con datos. Ejecutado por Claude Code."

# ─────────────────────────────────────────────────────────────
# Nota de reorientación en E9-IDENT-05
# ─────────────────────────────────────────────────────────────
echo "📌 Actualizando E9-IDENT-05 con nota de reorientación..."
NUM=$(gh issue list --repo "$REPO" --search "E9-IDENT-05 in:title" --state all \
  --json number,title --jq '.[] | select(.title | contains("E9-IDENT-05")) | .number' | head -1)
if [[ -n "$NUM" ]]; then
  gh issue comment "$NUM" --repo "$REPO" --body \
"📋 **Reorientado por ADR-008.** La mitad WSO2 de esta historia (validación JWT en el MI vía JwtValidator.xml + EmprIdInjector.xml en el MI) fue reemplazada por el enfoque de ADR-008: el APIM valida el JWT como Key Manager federado de Dnato e inyecta X-Empr-Id antes del MI.

Lo que se conserva de E9-IDENT-05:
- ✅ El componente JWKS/RS256 de Dnato (E9-IDENT-03) — es justamente lo que ADR-008 necesita
- ✅ Los tests Hurl conceptuales — re-apuntados a :8243 (APIM) en E9-IDENT-11

Lo que se descartó del flujo MCP:
- JwtValidator.xml del MI (se mantiene en repo para referencia, no se ejecuta en tráfico MCP)
- La inyección de X-Empr-Id se movió del MI al APIM (EmprIdInjectorPolicy)

Implementación efectiva en E9-IDENT-07 a 11 (B1-B5 de ADR-008), todas verificadas en DEV."
  echo "   ✅ E9-IDENT-05 actualizado (#$NUM)"
else
  echo "   ⚠️ E9-IDENT-05 no encontrado — actualizar manualmente"
fi
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "✅ ADR-008 registrado en GitHub"
echo ""
echo "Creados y cerrados (ya ejecutados en DEV):"
echo "  E9-IDENT-07  B1 JWKS accesible"
echo "  E9-IDENT-08  B2 KM Dnato en APIM"
echo "  E9-IDENT-09  B3 EmprIdInjectorPolicy + APIs publicadas"
echo "  E9-IDENT-10  B4 CAR al MI :8290"
echo "  E9-IDENT-11  B5 Tests Hurl ejecutados"
echo ""
echo "Reorientado: E9-IDENT-05 (nota agregada)"
echo ""
echo "⚠️  Recordá agregar estos issues al Project board (vista tabla)"
echo "    con Sprint=Sprint 2, Status=Done, y correrlos por add-to-project"
echo "    si querés que aparezcan en el board."
echo "═══════════════════════════════════════════════════════════"
