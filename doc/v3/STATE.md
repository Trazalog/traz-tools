# STATE.md — Estado vivo del proyecto Trazalog v3

> **Este archivo vive en `traz-tools/doc/v3/STATE.md`.** Es el ÚNICO documento de estado del proyecto — reemplaza kickoffs-como-estado, backlog xlsx, y resúmenes pegados al chat.
>
> **Por qué solo en traz-tools y no duplicado en traz-comp-dnato:** el estado de un proyecto con dos repos necesita una sola fuente para no repetir el problema de desincronización que motivó esta metodología (dos copias = deriva garantizada). Se eligió `traz-tools` como master porque concentra más volumen de trabajo (WSO2/APIs/MCP) y es donde vive el Project board de GitHub. `traz-comp-dnato/CLAUDE.md` tiene una línea que apunta acá (ver bloque E4).
>
> **Reglas de actualización:**
> - Claude Code actualiza este archivo al final de CADA tarea (🟢🟡🔴), como parte de su Definition of Done. No es opcional.
> - Claude Web lo lee al inicio de cada sesión, antes de asumir cualquier estado.
> - Rodolfo + Claude Web lo revisan juntos en el ritual semanal (ver CICD_STRATEGY §5-bis.7) para corregir cualquier deriva.
> - Formato: mantener SIEMPRE la estructura de secciones. No agregar prosa larga — es un tablero, no una bitácora.

---

## 🟢 EJEMPLO DE REFERENCIA (Sprint 3 ficticio — borrar en el primer uso real)

**Sprint actual:** Sprint 3 — Tools de OTs extendidas + hardening de PROD
**Objetivo del sprint:** Agregar `update_ot` y `list_overdue_preventives`, y cerrar la deuda técnica de trazabilidad (`sub`→`usrId`) antes de activar al primer cliente early adopter.
**Última actualización:** 2026-07-20 por Claude Code (E1-API-15)

### Tareas activas

| ID | Descripción | Clase | Estado | Rama / PR |
|---|---|---|---|---|
| E1-API-15 | Tool `update_ot` (cambiar estado/mantenedor) | 🟡 | En review | `feature/e1-api-15-update-ot` — PR #410 |
| E9-IDENT-12 | Mapear `sub` del JWT → `sisusers.usrId` en `create_ot` | 🔴 | Workshop pendiente con Rodolfo | — |
| E7-CICD-10 | Agregar `.gitignore` de `.phpunit.result.cache` en Dnato | 🟢 | Mergeado | `chore/gitignore-phpunit` — PR #9XX (ficticio) ✅ |
| E1-API-16 | Tool `list_overdue_preventives` | 🟡 | No iniciada, siguiente en cola | — |

### Próxima acción

Rodolfo revisa el PR #410 (`update_ot`) — diff + descripción funcional, ~5 min. Si aprueba, mergea y Claude Code arranca E1-API-16.

### Decisiones recientes (últimas 5)

| Fecha | Decisión | Referencia |
|---|---|---|
| 2026-07-18 | `update_ot` NO permite cambiar `empr_id` bajo ninguna circunstancia — el campo ni se acepta como parámetro | PR #410, coherente con ADR-009 |
| 2026-07-15 | El mapeo `sub`→`usrId` se hace vía tabla puente en Dnato, no en el MI | Pendiente ADR-010 (a redactar en el workshop) |
| 2026-07-10 | Cierre metodología v2 — CONTEXT-PACK + STATE + ciclo de 4 pasos | Sección 5-bis CICD_STRATEGY.md |
| 2026-07-13 | Sprint 2 cerrado — 21 issues, demo E2E verificada | `doc/mcp/demo-smoke-test.md` |
| 2026-07-13 | ADR-009: X-JWT-Assertion reemplaza EmprIdInjectorPolicy | `doc/adr/ADR-009-backend-jwt-assertion.md` |

### Bloqueos

- **E9-IDENT-12** bloqueada: requiere workshop de arquitectura (clase 🔴) antes de que Claude Code pueda implementar. Agendar con Rodolfo.

---

## 📋 PLANTILLA VACÍA (usar desde acá para el estado real)

**Sprint actual:**
**Objetivo del sprint:**
**Última actualización:** \[fecha] por \[CW / CC — ID de tarea]

### Tareas activas

| ID | Descripción | Clase | Estado | Rama / PR |
|---|---|---|---|---|
| | | | | |

### Próxima acción



### Decisiones recientes (últimas 5)

| Fecha | Decisión | Referencia |
|---|---|---|
| | | |

### Bloqueos


