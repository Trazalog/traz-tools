# PROMPT PARA CLAUDE CODE — Implementación de DocTest (proyecto traz-tools)

> Copiar y pegar en Claude Code CLI, posicionado en `traz-tools`.
> **Prerequisito de Rodolfo:** commitear antes los 3 documentos DocTest en `doc/v3/` (rama feature + PR, o directo si decide tratarlos como docs ancla del sprint).

---

Sos el implementador (CC) del proyecto Trazalog v3 según la metodología v2.

**Antes de empezar, leé en este orden:**
1. `doc/v3/CONTEXT-PACK.md` y `doc/v3/STATE.md` (obligatorio por CLAUDE.md)
2. `doc/v3/TRAZALOG_v3_DOCTEST_01_REQUERIMIENTOS.md` — qué construir
3. `doc/v3/TRAZALOG_v3_DOCTEST_02_CICLO_VIDA_CICD.md` — cómo se integra a CI/CD
4. `doc/v3/TRAZALOG_v3_DOCTEST_03_ARQUITECTURA.md` — diseño técnico y estructura

Estos 3 documentos DocTest son la especificación aprobada: **no re-discutas las decisiones de diseño** (stack, estructura, esquema del catálogo, olas). Donde digan "a definir por CC" o encuentres huecos, aplicá las reglas de escalamiento de la metodología (menor: decidí y documentá en el PR; funcional/negocio: pará y preguntá a Rodolfo; arquitectura: pará y marcá para CW+Rodolfo).

**Misión:** implementar la solución DocTest completa para la Ola 1 (DNATO → MAN piloto → ALM → MCP), analizando el código de `traz-tools`, `traz-prod-assetplanner` y `traz-comp-dnato`.

**Plan de fases — cada fase = 1 o más feature branches `feature/v3-doctest-*` + PR con `Closes #N`. No arranques una fase sin cerrar la anterior (salvo F4-MCP, paralelizable desde F2):**

- **F0 · Infraestructura** (🟢): árbol `doctest/` según Doc 3 §2; Playwright + TS configurado (projects local/staging-v3); Hurl instalado; JSON Schema del catálogo + `validate-catalog.ts`; scripts npm; workflow `doctest-validate.yml`; README. DoD: `npm run test:smoke` corre (vacío) y la validación de catálogo pasa en CI.
- **F1 · DNATO** (🟡): relevamiento de casos de uso de registración y administración de cuenta desde `traz-comp-dnato` (⚠️ PHP 5.6 — los `data-testid` que agregues deben respetar las restricciones del CLAUDE.md de ese repo). Entregá catálogo en `borrador` + `RESUMEN-RELEVAMIENTO-DNATO.md` y **PARÁ: esperá la validación de Rodolfo antes de derivar nada**. Validado el catálogo: fixtures de auth (`storageState`, ver advertencia Doc 3 §4.3), page objects, specs, `.feature`, seeds de empresas de test.
- **F2 · MAN piloto** (🟡): primero SOLO "Alta de Equipos y Componentes" de `traz-prod-assetplanner`, usando el manual MA.007 actual como fuente de intención funcional. Ciclo completo: caso → validación de Rodolfo → test + `.feature` + ayuda regenerada con la plantilla extraída del manual actual (Doc 1 RF-05). Este piloto calibra costo y formato: al cerrarlo, reportá en el PR una estimación del resto de MAN y esperá el OK de Rodolfo para continuar con el módulo completo.
- **F3 · ALM** (🟡): ídem F1/F2 sobre el módulo de almacenes en `traz-tools`, incluyendo el flujo de pedido de materiales (coherente con ADR-012).
- **F4 · MCP** (🟡, paralelizable): suite Hurl completa según Doc 3 §5 contra las tools publicadas del gateway. Verificá el contrato real consultando la configuración WSO2/MI del repo — no asumas tools de memoria.
- **F5 · Integración CI/CD** (🟡): workflows restantes (`doctest-e2e.yml`, `doctest-full-staging.yml`, `doctest-weekly.yml`, `doctest-delta.yml` con claude-code-action, `doctest-smoke-prod.yml` manual), hook pre-push, template de issue `test-gap`, generators restantes (`coverage-report.ts`, `build-ayudas.ts`, `catalog-to-feature.ts`). DoD: criterios de aceptación del Doc 1 §6 verificables.

**Reglas no negociables:**
- Modo conservador del relevamiento (Doc 1 RF-02.3): dudas de intención ⇒ `estado: borrador` + campo `dudas`. Nunca inventes intención de negocio.
- Ningún derivado desde casos `borrador`.
- Metodología git de los CLAUDE.md: feature branch + PR siempre; nunca commit directo a `develop-v3`.
- Actualizá `STATE.md` al cierre de cada tarea (DoD).
- Descripción de PR: qué cambia / por qué / cómo lo verificaste (comandos y resultados reales, no supuestos).
- Los tests apuntan a staging-v3 o local; nunca a producción.
- Si necesitás datos que no existen (URLs de staging de Asset Planner/Dnato, credenciales de empresas de test, secrets de CI), **pará y pedíselos a Rodolfo** — no los inventes ni los hardcodees.

**Primera acción concreta:** leé los 4 documentos del punto de partida, verificá staleness del CONTEXT-PACK (`ls doc/adr/` vs encabezado), creá los issues de GitHub de las fases F0–F5 (uno por fase, label `v3` + `doctest`), abrí la rama `feature/v3-doctest-f0-infra` y empezá F0. Reportá al terminar F0 con el resumen del PR.
