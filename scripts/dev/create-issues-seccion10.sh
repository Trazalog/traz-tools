#!/usr/bin/env bash
# ============================================================
# create-issues-seccion10.sh
# Crea los 6 issues de la Sección 10 (MCP Architecture Doc)
# en el repo Trazalog/traz-tools via GitHub CLI (gh).
#
# Prerequisito: gh auth login con permisos de write en el repo.
# Uso: bash create-issues-seccion10.sh
# ============================================================

set -euo pipefail

REPO="Trazalog/traz-tools"

echo "🚀 Creando issues de Sección 10 — MCP Testing, Distribución y Publicación"
echo "   Repo: $REPO"
echo ""

# ─── ISSUE 1: E0-INF-10 ─────────────────────────────────────────────────────
echo "📌 Creando E0-INF-10..."
gh issue create \
  --repo "$REPO" \
  --title "[E0-INF-10] Instalar Node.js 22+ y MCP Inspector en DEV (workstation Ubuntu 24)" \
  --label "e0,must-have,type:técnica" \
  --body "Como PM técnico, necesito Node.js 22+ y MCP Inspector instalados en mi workstation Ubuntu 24, para poder validar cada tool MCP durante el desarrollo sin necesidad de un cliente IA real (DDR-001, sección 10.2 del MCP Architecture Doc).

Sin MCP Inspector no hay Etapa 1 de testing — el loop de feedback técnico queda bloqueado.

## Responsabilidad
🖐 **Tarea manual del PM** — se ejecuta junto con E0-INF-01.

## Pasos

\`\`\`bash
# 1. Instalar Node.js 22 LTS (via NodeSource)
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

# 2. Verificar
node --version   # → v22.x.x
npx --version

# 3. Smoke test MCP Inspector
npx @modelcontextprotocol/inspector
# Abre UI en http://localhost:6274 — verificar y cerrar con Ctrl+C
\`\`\`

## CRITERIOS DE ACEPTACIÓN
1. Node.js 22+ instalado en DEV: \`node --version\` devuelve \`v22.x.x\`
2. npx disponible sin instalación global adicional
3. MCP Inspector ejecuta correctamente y abre UI en localhost:6274
4. \`doc/infra/mcp-inspector-setup.md\` con comandos exactos y 3 formas de uso (Node, Python FastMCP, HTTP remoto)
5. Checklist de validación de tools MCP documentado en el mismo archivo

## DEFINICIÓN DE LISTO
- [ ] \`node --version\` devuelve \`v22.x.x\` en DEV
- [ ] UI de MCP Inspector accesible en localhost:6274
- [ ] \`doc/infra/mcp-inspector-setup.md\` commiteado en develop-v3
- [ ] Reviewed por PM

**Ref:** MCP_ARCHITECTURE.md#10.2 — DDR-001
**Sprint:** Sprint 1 — M1
**Story Points:** 1
**Dependencias:** E0-INF-01"

echo "   ✅ E0-INF-10 creado"

# ─── ISSUE 2: E0-INF-11 ─────────────────────────────────────────────────────
echo "📌 Creando E0-INF-11..."
gh issue create \
  --repo "$REPO" \
  --title "[E0-INF-11] Instalar y configurar ngrok en DEV para testing MCP con Claude real" \
  --label "e0,must-have,type:técnica" \
  --body "Como PM técnico, necesito ngrok instalado y configurado en mi workstation Ubuntu 24, para poder exponer el WSO2 MCP Gateway local como URL HTTPS pública y conectarlo a Claude.ai para testing end-to-end (Etapa 2, sección 10.3 del MCP Architecture Doc).

Sin ngrok no hay forma de validar que las descripciones semánticas de las tools sean comprendidas correctamente por Claude antes de ir a producción. Plan free es suficiente (\$0).

## Responsabilidad
🖐 **Tarea manual del PM** — se ejecuta **junto con E0-INF-04** (necesitás WSO2 corriendo en el puerto 8243).

## Pasos

\`\`\`bash
# 1. Instalar ngrok
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo \"deb https://ngrok-agent.s3.amazonaws.com buster main\" | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt update && sudo apt install ngrok

# 2. Autenticar (token en dashboard.ngrok.com → Your Authtoken)
ngrok config add-authtoken <TU_TOKEN>

# 3. Smoke test (con WSO2 corriendo en 8243)
ngrok http 8243
# Output esperado: https://abc123.ngrok-free.app -> http://localhost:8243
\`\`\`

> ⚠️ La URL cambia en cada reinicio (plan free). Para testing está bien — producción usa dominio estable en GCP.

## CRITERIOS DE ACEPTACIÓN
1. Cuenta ngrok free creada y authtoken configurado
2. Binario ngrok instalado en DEV y accesible desde PATH
3. Smoke test: \`ngrok http 8243\` genera URL HTTPS pública válida
4. \`doc/infra/ngrok-setup.md\` con procedimiento, limitaciones y workarounds del plan free

## DEFINICIÓN DE LISTO
- [ ] \`ngrok version\` devuelve versión instalada
- [ ] Tunnel a localhost:8243 genera URL HTTPS accesible desde internet
- [ ] \`doc/infra/ngrok-setup.md\` commiteado en develop-v3
- [ ] Reviewed por PM

**Ref:** MCP_ARCHITECTURE.md#10.3
**Sprint:** Sprint 1 — M1 (activar junto con E0-INF-04)
**Story Points:** 1
**Dependencias:** E0-INF-10"

echo "   ✅ E0-INF-11 creado"

# ─── ISSUE 3: E0-INF-12 ─────────────────────────────────────────────────────
echo "📌 Creando E0-INF-12..."
gh issue create \
  --repo "$REPO" \
  --title "[E0-INF-12] Activar Claude Pro y configurar custom connector de DEV en Claude.ai" \
  --label "e0,must-have,type:técnica" \
  --body "Como PM técnico, necesito al menos Claude Pro activo en mi cuenta Claude.ai, para poder agregar el MCP server de DEV como custom connector y validar tools con Claude real antes de ir a producción (DDR-002, sección 10.3 del MCP Architecture Doc).

El plan Free de Claude.ai no permite custom connectors. Esta activación habilita la Etapa 2 del ciclo de testing MCP — es el paso final antes de la validación con el cliente minero piloto.

## Responsabilidad
🖐 **Tarea manual del PM** — 15 minutos, requiere E0-INF-11 completado y ngrok activo.

## Pasos
1. Verificar que tu cuenta Claude.ai sea **Pro, Max, Team o Enterprise**.
2. Con WSO2 en DEV corriendo y ngrok activo, copiar URL del tunnel (ej: \`https://abc123.ngrok-free.app\`).
3. En Claude.ai → **Settings → Connectors → Add custom connector**.
4. URL: \`https://abc123.ngrok-free.app/mcp\`
5. Claude descubre tools vía \`tools/list\` automáticamente.
6. Smoke test: pedir a Claude \"listá los equipos disponibles\" y verificar que invoca la tool correcta.

## CRITERIOS DE ACEPTACIÓN
1. Cuenta Claude.ai del PM en plan Pro o superior
2. Custom connector configurado con la URL ngrok del MCP server de DEV
3. Claude detecta las tools MCP vía tools/list
4. Smoke test: tool read-only invocada con resultado esperado
5. \`doc/infra/testing-workflow.md\` con decisión de cuándo usar Inspector (Etapa 1) vs Claude.ai con ngrok (Etapa 2)

## DEFINICIÓN DE LISTO
- [ ] Plan Pro activo en cuenta del PM
- [ ] Custom connector configurado con tool visible en Claude.ai
- [ ] Smoke test de tool read-only pasado
- [ ] \`doc/infra/testing-workflow.md\` commiteado
- [ ] Reviewed por PM

**Ref:** MCP_ARCHITECTURE.md#10.3 — DDR-002
**Sprint:** Sprint 1 — M1 (activar junto con E0-INF-04)
**Story Points:** 1
**Dependencias:** E0-INF-11"

echo "   ✅ E0-INF-12 creado"

# ─── ISSUE 4: E0-INF-13 ─────────────────────────────────────────────────────
echo "📌 Creando E0-INF-13..."
gh issue create \
  --repo "$REPO" \
  --title "[E0-INF-13] Definir estándar de tool annotations (readOnlyHint/destructiveHint) para todas las tools MCP" \
  --label "e0,must-have,type:documentación" \
  --body "Como PM técnico, necesito un estándar documentado de tool annotations para todas las tools MCP de Trazalog v3, porque es requisito obligatorio del Claude Connectors Directory y representa el 30% de los rechazos de Anthropic si se omite (DDR-004, sección 10.5 del MCP Architecture Doc).

Hacerlo desde el día 1 evita un refactor masivo sobre todas las tools antes del submit Q2 2027. Cada tool de v3 debe declarar si es de solo lectura o destructiva desde el momento de su creación.

## CRITERIOS DE ACEPTACIÓN
1. Crear \`doc/mcp/tool-annotations-standard.md\` con:
   - Definición de \`readOnlyHint\` vs \`destructiveHint\` con criterios claros
   - Código Python (FastMCP) de ejemplo para ambos tipos
   - Configuración equivalente para WSO2 Virtual MCP Server
   - Tabla de clasificación de las 6 tools Phase 1:

     | Tool | Annotation |
     |---|---|
     | get_equipment | readOnlyHint |
     | get_ot | readOnlyHint |
     | get_kpis | readOnlyHint |
     | get_stock | readOnlyHint |
     | get_preventivos | readOnlyHint |
     | create_ot | destructiveHint |

   - Árbol de decisión para tools futuras (3 preguntas)
2. Agregar referencia al doc en la sección PR checklist del CICD_STRATEGY.md

## DEFINICIÓN DE LISTO
- [ ] \`doc/mcp/tool-annotations-standard.md\` commiteado en develop-v3
- [ ] Clasificación de las 6 tools Phase 1 incluida
- [ ] \`CICD_STRATEGY.md\` actualizado con referencia al doc
- [ ] Reviewed por PM

**Commit sugerido:** \`docs(mcp): add tool annotations standard for Connectors Directory compliance [E0-INF-13]\`
**Ref:** MCP_ARCHITECTURE.md#10.5; MCP_ARCHITECTURE.md#10.9 — DDR-004
**Sprint:** Sprint 1 — M1
**Story Points:** 2
**Dependencias:** E1-API-01"

echo "   ✅ E0-INF-13 creado"

# ─── ISSUE 5: E8-DIR-01 ─────────────────────────────────────────────────────
echo "📌 Creando E8-DIR-01..."
gh issue create \
  --repo "$REPO" \
  --title "[E8-DIR-01] Producir privacy policy, documentación pública y test account para el Connectors Directory" \
  --label "e8,must-have,type:documentación" \
  --body "Como equipo de Trazalog, necesitamos producir los artefactos requeridos por Anthropic para el submit al Claude Connectors Directory (sección 10.5 del MCP Architecture Doc), para poder lanzar el submit en Q2 2027 sin bloquearnos por falta de assets.

Los ⚠️ de la tabla 10.5 deben estar todos en ✅ antes de enviar el formulario. Producirlos tarde retrasa el submit y el discovery público como canal de marketing pasivo.

## CRITERIOS DE ACEPTACIÓN
1. **Privacy policy** de Trazalog MCP publicada en URL pública (ej: trazalog.com/privacy-mcp)
2. **Documentación pública** con mínimo 3 ejemplos de uso por tool Phase 1 (en doc/ y en landing pública)
3. **Test account** configurada con datos de muestra representativos del sector minero
4. **Branding:** logo Trazalog en SVG y PNG (múltiples tamaños), favicon preparado
5. **Checklist completa:** todos los ⚠️ de tabla 10.5 resueltos y en ✅
6. Review interno aprobado antes de enviar a Anthropic

## DEFINICIÓN DE LISTO
- [ ] Privacy policy en URL pública
- [ ] Documentación con 3+ ejemplos por tool Phase 1
- [ ] Test account operativa con datos de muestra mineros
- [ ] Logo y favicon entregados
- [ ] Checklist 10.5 completamente en ✅
- [ ] Reviewed por PM + socio comercial

**Ref:** MCP_ARCHITECTURE.md#10.4; MCP_ARCHITECTURE.md#10.5
**Mes:** M5 (Q1 2027)
**Story Points:** 5
**Dependencias:** E5-EA-01 (al menos 4 semanas con cliente piloto)"

echo "   ✅ E8-DIR-01 creado"

# ─── ISSUE 6: E8-DIR-02 ─────────────────────────────────────────────────────
echo "📌 Creando E8-DIR-02..."
gh issue create \
  --repo "$REPO" \
  --title "[E8-DIR-02] Submit al Claude Connectors Directory de Anthropic (Q2 2027)" \
  --label "e8,must-have,type:técnica" \
  --body "Como equipo de Trazalog, necesitamos enviar el formulario de submission al Claude Connectors Directory de Anthropic (sección 10.7 del MCP Architecture Doc), para activar el discovery público de Trazalog como canal de marketing pasivo para el sector industrial e IOT.

Este es el hito que convierte el MCP de Trazalog de 'herramienta para clientes contractuales' a 'producto descubrible por cualquier usuario de Claude'. Se difiere a Q2 2027 intencionalmente (DDR-003) para validar primero con el cliente minero piloto.

## CRITERIOS DE ACEPTACIÓN
1. Todos los requisitos de E8-DIR-01 completados y verificados
2. Al menos 4 semanas de uso real con el cliente minero piloto validadas
3. Formulario de submission enviado: https://claude.com/docs/connectors/building/submission
4. Respuesta de Anthropic recibida (aprobado o feedback documentado)
5. Si aprobado: connector visible y verificado en claude.com/connectors
6. Si rechazado: feedback documentado con plan de acción para resubmit

## DEFINICIÓN DE LISTO
- [ ] Submit enviado a Anthropic
- [ ] Connector visible en el directory (o feedback de rechazo documentado con plan de acción)
- [ ] Reviewed por PM + socio comercial

**Ref:** MCP_ARCHITECTURE.md#10.7 — DDR-003
**Mes:** M6 (Q2 2027)
**Story Points:** 3
**Dependencias:** E8-DIR-01"

echo "   ✅ E8-DIR-02 creado"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "✅ Los 6 issues de la Sección 10 fueron creados exitosamente"
echo ""
echo "Issues creados:"
echo "  E0-INF-10 — Node.js 22+ y MCP Inspector en DEV         [Sprint 1 / M1]"
echo "  E0-INF-11 — ngrok en DEV                               [Sprint 1 / M1]"
echo "  E0-INF-12 — Claude Pro + custom connector DEV          [Sprint 1 / M1]"
echo "  E0-INF-13 — Estándar de tool annotations MCP           [Sprint 1 / M1]"
echo "  E8-DIR-01 — Prep para Connectors Directory             [M5 / Q1 2027]"
echo "  E8-DIR-02 — Submit al Connectors Directory             [M6 / Q2 2027]"
echo ""
echo "Labels necesarios (crear si no existen):"
echo "  gh label create 'e8' --color '7B68EE' --description 'Épica 8 - Connectors Directory' --repo $REPO"
echo "  gh label create 'type:documentación' --color 'BFD4F2' --description 'Tarea de documentación' --repo $REPO"
echo "════════════════════════════════════════════════════════════"
