#!/usr/bin/env bash
# ============================================================
# create-epic-e9-identity.sh
# Crea la épica E9 (Identidad y Multi-Tenancy) y sus 6 issues
# en el repo Trazalog/traz-tools.
#
# Origen: secciones 6.3/6.4 del MCP Architecture Doc.
# La capa de identidad es prerequisito BLOQUEANTE del Sprint 2.
#
# Prerequisito: gh CLI autenticado con permisos de write.
# Uso: bash create-epic-e9-identity.sh
# ============================================================

set -euo pipefail

REPO="Trazalog/traz-tools"

echo "═══════════════════════════════════════════════════════════"
echo "🔐 Creando Épica E9 — Identidad y Multi-Tenancy"
echo "   Repo: $REPO"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ── Crear labels si no existen ───────────────────────────────
echo "🏷  Verificando labels..."
gh label create "e9" --color "0E8A16" --description "Épica 9 - Identidad y Multi-Tenancy" --repo "$REPO" 2>/dev/null && echo "   + label e9 creado" || echo "   = label e9 ya existe"
gh label create "type:investigación" --color "FEF2C0" --description "Tarea de investigación de código" --repo "$REPO" 2>/dev/null && echo "   + label type:investigación creado" || echo "   = label type:investigación ya existe"
gh label create "bloqueante" --color "B60205" --description "Bloquea otras tareas del sprint" --repo "$REPO" 2>/dev/null && echo "   + label bloqueante creado" || echo "   = label bloqueante ya existe"
echo ""

# ─────────────────────────────────────────────────────────────
# E9-IDENT-01 — Investigación de código
# ─────────────────────────────────────────────────────────────
echo "📌 Creando E9-IDENT-01..."
gh issue create \
  --repo "$REPO" \
  --title "[E9-IDENT-01] Investigación de código: modelo de autenticación y multi-tenancy actual" \
  --label "e9,must-have,bloqueante,type:investigación" \
  --body "Como equipo de arquitectura, necesitamos entender cómo funciona hoy el login de Trazalog y la resolución del empr_id, porque el modelo MCP requiere que el empr_id viaje como claim de un token en lugar de vivir en la sesión PHP.

> 🔴 **BLOQUEANTE.** Las decisiones de arquitectura TAD-IDENT-P01 a P04 dependen de los resultados de esta investigación. Es la primera tarea del Sprint 2 y no puede saltarse. Es de SOLO LECTURA del código — no modifica nada.

## CRITERIOS DE ACEPTACIÓN
Entregable: \`doc/identity/auth-research-2026.md\` con 5 secciones:
1. **Flujo de login actual** — diagrama Mermaid: dónde está implementado, cómo autentica, cómo resuelve el empr_id, dónde lo guarda en sesión
2. **Integración con Bonita** — existencia y contrato de la API de Memberships; cómo se mapea el 'group' de Bonita al empr_id
3. **Viabilidad OAuth** — si el stack PHP puede participar de un flujo OAuth 2.1 + PKCE sin reescritura mayor; grado de acoplamiento del login a Bonita
4. **Auditoría de aislamiento (crítico)** — lista explícita de DataServices/.dbs que NO filtran por empr_id / id_empresa
5. **Insumos para decisiones** — resumen de hallazgos que informan cada decisión pendiente P01, P02, P03, P04

## DEFINICIÓN DE LISTO
- [ ] doc/identity/auth-research-2026.md con las 5 secciones
- [ ] Diagrama Mermaid del flujo de login
- [ ] Lista explícita de DataServices sin filtro por empresa
- [ ] Commit en develop-v3
- [ ] PM notificado para revisión (insumo de E9-IDENT-02)

**Ref:** MCP_ARCHITECTURE.md#6.6
**Sprint:** Sprint 2 | **Story Points:** 5 | **Dependencias:** ninguna"

echo "   ✅ E9-IDENT-01 creado"

# ─────────────────────────────────────────────────────────────
# E9-IDENT-02 — Cierre de decisiones
# ─────────────────────────────────────────────────────────────
echo "📌 Creando E9-IDENT-02..."
gh issue create \
  --repo "$REPO" \
  --title "[E9-IDENT-02] Cerrar decisiones de arquitectura de identidad TAD-IDENT-P01 a P04" \
  --label "e9,must-have,type:documentación" \
  --body "Como equipo de arquitectura, necesitamos cerrar las 4 decisiones pendientes de identidad usando la investigación E9-IDENT-01 como insumo, para poder implementar la capa de identidad sobre bases firmes.

> Workshop de arquitectura (PM + Claude Web). El MCP Architecture Doc es explícito: estas decisiones NO deben asumirse resueltas antes de la investigación de código.

## DECISIONES A CERRAR
- **TAD-IDENT-P01:** ¿Quién actúa como Authorization Server — WSO2 o el stack Trazalog actual? (recomendación preliminar del arquitecto: Opción 3.2 — Trazalog mantiene el login, WSO2 valida — pero NO confirmada)
- **TAD-IDENT-P02:** ¿Comportamiento del MVP ante un usuario con más de una empresa en Bonita?
- **TAD-IDENT-P03:** ¿Mecanismo concreto de consulta de Memberships de Bonita?
- **TAD-IDENT-P04:** ¿Alcance de la corrección de DataServices que no filtran por empresa?

## CRITERIOS DE ACEPTACIÓN
1. Documento \`doc/adr/ADR-007-identity-decisions.md\` con las 4 decisiones cerradas y justificadas
2. Cada decisión referencia los hallazgos de E9-IDENT-01 que la sustentan
3. El ADR-007 define con claridad suficiente para que E9-IDENT-03 y E9-IDENT-05 se implementen sin ambigüedad

## DEFINICIÓN DE LISTO
- [ ] doc/adr/ADR-007-identity-decisions.md con P01-P04 cerradas
- [ ] Aprobado por el PM
- [ ] Commit en develop-v3

**Ref:** MCP_ARCHITECTURE.md#6.5
**Sprint:** Sprint 2 | **Story Points:** 2 | **Dependencias:** E9-IDENT-01"

echo "   ✅ E9-IDENT-02 creado"

# ─────────────────────────────────────────────────────────────
# E9-IDENT-03 — Emisión de token
# ─────────────────────────────────────────────────────────────
echo "📌 Creando E9-IDENT-03..."
gh issue create \
  --repo "$REPO" \
  --title "[E9-IDENT-03] Capa de emisión de token OAuth con empr_id como claim" \
  --label "e9,must-have,type:técnica" \
  --body "Como sistema Trazalog, necesito emitir un token JWT que contenga el empr_id como claim, para que las tools MCP transporten la identidad de empresa de forma verificable en cada request (TAD-IDENT-01).

> El empr_id se resuelve UNA vez (autenticando al usuario + consultando Memberships de Bonita) y queda horneado en el token firmado.

> ⚠️ **Prerequisito absoluto:** E9-IDENT-02 cerrado (ADR-007 aprobado). El ADR-007 define quién es el Authorization Server (P01) y cómo se consultan los Memberships (P03). NO implementar sin el ADR-007.

## CRITERIOS DE ACEPTACIÓN
1. Componente que autentica credenciales contra Trazalog, resuelve el empr_id desde Bonita, y emite un JWT firmado con el claim empr_id
2. MVP: una empresa por usuario (TAD-IDENT-02). Si ADR-007 definió comportamiento multi-empresa (P02), implementarlo
3. Mecanismo para emitir un **token de prueba para la demo** sin pantalla de login — script o endpoint de servicio que emita un token válido con el empr_id correcto
4. El token es un JWT estándar, firmado, validable por el WSO2 MCP Gateway
5. \`doc/identity/token-issuance.md\` con estructura del token, claims, cómo emitir el token de prueba

## DEFINICIÓN DE LISTO
- [ ] Emisión de token JWT con claim empr_id funcional
- [ ] Script/endpoint de token de prueba para la demo
- [ ] doc/identity/token-issuance.md
- [ ] Tests de emisión y contenido del claim
- [ ] Commit en develop-v3

**Ref:** MCP_ARCHITECTURE.md#6.7 — TAD-IDENT-01, TAD-IDENT-04
**Sprint:** Sprint 2 | **Story Points:** 8 | **Dependencias:** E9-IDENT-02"

echo "   ✅ E9-IDENT-03 creado"

# ─────────────────────────────────────────────────────────────
# E9-IDENT-04 — Pantalla de login OAuth (Sprint 2 — pieza de riesgo)
# ─────────────────────────────────────────────────────────────
echo "📌 Creando E9-IDENT-04..."
gh issue create \
  --repo "$REPO" \
  --title "[E9-IDENT-04] Pantalla de login de Trazalog compatible con OAuth 2.1 + PKCE" \
  --label "e9,must-have,type:técnica" \
  --body "Como usuario, necesito una pantalla de login propia de Trazalog dentro del flujo OAuth, para autenticarme al agregar el connector en Claude sin entregarle mis credenciales al agente de IA (TAD-IDENT-04).

> ⚠️ **Sprint 2 — pieza de riesgo.** El objetivo es la demo con flujo OAuth completo. E9-IDENT-04 es la tarea más impredecible: su esfuerzo depende de qué tan reutilizable sea el login actual, y eso solo se sabe al terminar E9-IDENT-01. Es el primer candidato del plan de corte: si la investigación revela que el login no es reutilizable, se difiere a Sprint 3 y la demo usa el token de prueba de E9-IDENT-03.

## CRITERIOS DE ACEPTACIÓN
1. Pantalla de login de Trazalog que funciona dentro de un flujo OAuth 2.1 (authorization code + PKCE)
2. El usuario ingresa credenciales en Trazalog — Claude nunca las ve
3. Al autenticar, dispara la emisión del token con claim empr_id (reusa E9-IDENT-03)
4. Grado de reutilización del login actual según lo definido en ADR-007 (P01)
5. Flujo completo de alta del connector probado end-to-end desde Claude.ai

## DEFINICIÓN DE LISTO
- [ ] Pantalla de login compatible con OAuth 2.1 + PKCE
- [ ] Flujo de alta del connector probado desde Claude.ai
- [ ] doc/identity/oauth-login-flow.md
- [ ] Commit en develop-v3
- [ ] Reviewed por PM

**Ref:** MCP_ARCHITECTURE.md#6.7 — TAD-IDENT-04
**Sprint:** Sprint 2 (pieza de riesgo, primer candidato de corte) | **Story Points:** 5 | **Dependencias:** E9-IDENT-03"

echo "   ✅ E9-IDENT-04 creado"

# ─────────────────────────────────────────────────────────────
# E9-IDENT-05 — Validación en el Gateway
# ─────────────────────────────────────────────────────────────
echo "📌 Creando E9-IDENT-05..."
gh issue create \
  --repo "$REPO" \
  --title "[E9-IDENT-05] Validación de token e inyección de empr_id en el WSO2 MCP Gateway" \
  --label "e9,must-have,type:técnica" \
  --body "Como WSO2 MCP Gateway, necesito validar criptográficamente el token JWT, extraer el claim empr_id e inyectarlo en las llamadas downstream, para enforzar el aislamiento multi-tenant en un único punto (TAD-IDENT-03).

> Centralizar el enforcement en el gateway evita que cada DataService reimplemente la lógica de aislamiento. Es una capacidad estándar de mediación de WSO2.

## CRITERIOS DE ACEPTACIÓN
1. El gateway valida el JWT: firma, expiración, emisor
2. Extrae el claim empr_id del token validado
3. Inyecta el empr_id como header (ej: X-Empr-Id) o parámetro en la llamada downstream
4. **Caso de seguridad:** si el token es inválido, expirado o sin claim empr_id, el gateway RECHAZA el request (401/403) — no lo deja pasar
5. Artefactos de mediación versionados en git; pasos de consola documentados
6. \`doc/identity/gateway-token-validation.md\` con configuración, artefactos, casos de error
7. **Probado:** un token de empresa A no puede acceder a datos de empresa B

## DEFINICIÓN DE LISTO
- [ ] Gateway valida JWT y rechaza tokens inválidos/expirados/sin claim
- [ ] empr_id extraído del claim e inyectado downstream
- [ ] Artefactos de mediación en git
- [ ] doc/identity/gateway-token-validation.md
- [ ] Prueba de aislamiento A↔B pasada
- [ ] Commit en develop-v3

**Ref:** MCP_ARCHITECTURE.md#6.4 — TAD-IDENT-03
**Sprint:** Sprint 2 | **Story Points:** 5 | **Dependencias:** E9-IDENT-03"

echo "   ✅ E9-IDENT-05 creado"

# ─────────────────────────────────────────────────────────────
# E9-IDENT-06 — Corregir DataServices (condicional)
# ─────────────────────────────────────────────────────────────
echo "📌 Creando E9-IDENT-06..."
gh issue create \
  --repo "$REPO" \
  --title "[E9-IDENT-06] Corregir DataServices que no filtran por empresa" \
  --label "e9,must-have,type:técnica" \
  --body "Como sistema multi-tenant, necesito que todos los DataServices expuestos como tools MCP filtren por empr_id, para que ningún cliente pueda ver datos de otro.

> ⚠️ **Story condicional.** Se ejecuta solo si la investigación E9-IDENT-01 detecta DataServices sin filtro por empresa (decisión P04). Si la auditoría no encuentra ninguno, este issue se cierra como 'no aplica'. Story points a re-estimar después de E9-IDENT-01.

## CRITERIOS DE ACEPTACIÓN
1. Leer la sección de auditoría de doc/identity/auth-research-2026.md
2. Para cada DataService de la lista usado por las tools del MVP (Equipos, OTs): agregar filtro por empr_id / id_empresa; el empr_id se recibe como parámetro inyectable
3. DataServices fuera del scope del MVP: documentados como deuda técnica, no corregidos en este sprint
4. Tests Hurl que verifican el filtrado

## DEFINICIÓN DE LISTO
- [ ] DataServices del MVP (Equipos, OTs) filtran por empr_id
- [ ] DataServices fuera de scope documentados como deuda técnica
- [ ] Tests Hurl del filtrado
- [ ] Commit en develop-v3

**Ref:** MCP_ARCHITECTURE.md#6.5 — TAD-IDENT-P04
**Sprint:** Sprint 2 (condicional) | **Story Points:** 3 (a re-estimar) | **Dependencias:** E9-IDENT-01, E9-IDENT-02"

echo "   ✅ E9-IDENT-06 creado"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Épica E9 creada — 6 issues"
echo ""
echo "  E9-IDENT-01  Investigación auth + multi-tenancy   [S2 / 5 SP / BLOQUEANTE]"
echo "  E9-IDENT-02  Cerrar decisiones P01-P04            [S2 / 2 SP]"
echo "  E9-IDENT-03  Emisión de token con claim empr_id   [S2 / 8 SP]"
echo "  E9-IDENT-04  Pantalla login OAuth + PKCE          [S2 / 5 SP / riesgo]"
echo "  E9-IDENT-05  Validación + inyección en gateway    [S2 / 5 SP]"
echo "  E9-IDENT-06  Corregir DataServices sin filtro     [S2 / 3 SP / condicional]"
echo ""
echo "Sprint 2 recibe: E9-IDENT-01, 02, 03, 04, 05, 06 (28 SP de identidad)"
echo "E9-IDENT-04 es el primer candidato del plan de corte si la investigacion lo justifica"
echo ""
echo "⚠️  Recordá asignar el campo 'Sprint' en el Project board"
echo "    (vista tabla) y mover los issues a 'Sprint Ready'."
echo "═══════════════════════════════════════════════════════════"
