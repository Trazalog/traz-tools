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

**Sprint actual:** Sprint 3 — Activación early adopter minero
**Objetivo del sprint:** Reemplazar ngrok por un despliegue estable en GCP (ADR-011) y cerrar la deuda técnica pendiente antes de activar al primer cliente early adopter.
**Última actualización:** 2026-07-31 por Claude Code (E2-MCP-12)

### Tareas activas

| ID | Descripción | Clase | Estado | Rama / PR |
|---|---|---|---|---|
| E2-MCP-12 | Migrar las 5 tools de mantenimiento a `toolsMCPAPI` (Bloque 3, tarea 3.2) | 🟡 | **Completada** — las 5 tools (`man_get_equipos`, `man_get_equipo`, `man_get_ots`, `man_get_ot`, `man_create_ot`) en `toolsMCPAPI`, ninguna reimplementa lógica | `feature/e2-mcp-12-toolsmcpapi-mantenimiento` — PR abierto, sin mergear |
| E2-MCP-11 | Verificar ruteo múltiple + esqueleto de la fachada `toolsMCPAPI` (Bloque 3, tarea 3.1) | 🔴 | Completada y mergeada | PR #410 |
| ADR-013 | Unificación MCP: fachada delgada `toolsMCPAPI`, un solo Virtual MCP Server | — | Aprobado y mergeado | PR #408, `sprint-3-prompts.md` en PR #409 |
| E2-MCP-10-RELEV | Relevamiento para unificación de Virtual MCP Servers (Bloque 0) | 🟢 | Completada y mergeada | PR #407 |
| E7-INFRA-01/02 | Sizing VM GCP + scripts instalación nativa WSO2 (ADR-011) | 🟡 | Completada y mergeada — VM funcionando end-to-end | PR #403 y #404 mergeados |
| ADR-012 | Aislamiento y alcance de Almacenes | — | Aprobado y mergeado | PR #405 |
| E1-API-20 | Relevamiento de estado para dimensionar Sprint 3 (3 frentes) | 🟢 | Completada | `docs/e1-api-20-sprint3-relevamiento-estado` — PR pendiente de abrir (Bloque 1 de `sprint-3-prompts.md`, no ejecutado todavía) |

### Próxima acción

Tarea 3.2 del Bloque 3 completada: `toolsMCPAPI` tiene ahora las 5 tools de mantenimiento (`man_get_equipos`, `man_get_equipo`, `man_get_ots`, `man_get_ot`, `man_create_ot`), cada una réplica 1:1 del recurso equivalente en `toolsMANAPI` — mismo DataService, mismo proceso BPM+rollback en `man_create_ot`, sin lógica nueva. **Próximo paso, en orden estricto (ADR-013): Tarea 3.3** — sumar las tools de almacenes (`alm_*`) a la fachada, una vez que este PR se revise y mergee. Es clase 🔴 con puntos de parada obligatoria (proceso Bonita de pedidos, payload real, análogo de `ALMDataService`). En paralelo siguen pendientes: Bloque 1, Bloque 2 (E7-INFRA-03), y las preguntas abiertas de `doc/v3/sprint-3-relevamiento-estado.md`.

### Decisiones recientes (últimas 5)

| Fecha | Decisión | Referencia |
|---|---|---|
| 2026-07-31 | **E2-MCP-12 completada.** Las 5 tools de mantenimiento migradas a `toolsMCPAPI` con prefijo `man_`, rutas `/mcp/man/...`. `man_create_ot` conserva el flujo INSERT→BPM→PUT case_id con rollback (ADR-003 Opción A) sin reimplementarlo — mismo DataService (`MANDataService`), mismo proceso Bonita. Build (`./mvnw clean install`) verificado, `.car` genera `toolsMCPAPI-1.0.0.xml` con las 5 resources. Tests Hurl agregados para las 4 tools nuevas (contrato de identidad fail-closed) | `_backend/api/ToolsAPIProject/.../artifacts/apis/toolsMCPAPI.xml`, `tests/security/mcp-facade-man-tools.hurl` |
| 2026-07-31 | E2-MCP-11 mergeado (PR #410): ruteo múltiple a distintos DataServices desde una sola API MI confirmado (evidencia estática + confirmación de Rodolfo por experiencia propia) | PR #410 |
| 2026-07-31 | ADR-013 aprobado y mergeado: fachada delgada `toolsMCPAPI`, un solo Virtual MCP Server, tools con prefijo de módulo (`man_`, `alm_`) | PR #408, `doc/adr/ADR-013-unificacion-mcp.md` |
| 2026-07-31 | Relevamiento de unificación MCP completado: 1 API WSO2 = 1 Virtual MCP Server (no se pueden combinar varias APIs) | PR #407, `doc/v3/relevamiento-unificacion-mcp.md` |
| 2026-07-30 | ADR-012 aprobado y mergeado: Almacenes reusa el patrón de Mantenimiento, alcance limitado a pedidos (sin operaciones de stock) | PR #405, `doc/adr/ADR-012-almacenes-aislamiento.md` |

### Bloqueos

- **Tarea 3.3 (Almacenes en la fachada) espera que esta tarea (3.2) se mergee primero** — orden estricto de ADR-013. Es clase 🔴, con puntos de parada obligatoria ya anticipados en `sprint-3-prompts.md`.
- Config de identidad (ADR-008/009) y migración de DataServices a PostgreSQL siguen pendientes antes de poder dar de alta al primer cliente sobre la VM de GCP — cubierto por E7-INFRA-03 (Bloque 2, no ejecutado todavía).
- **Nota operativa (de E2-MCP-11, sigue vigente):** el deploy del `.car` de `ToolsAPIProject` es atómico — si `ALMDataService` (o cualquier otro `.dbs`) no puede conectar a su BD al momento del deploy, se revierte el CAR completo. Relevante para cuando se sumen las DataServices de almacenes (Tarea 3.3) y para el deploy en la VM de GCP.
- La implementación de escritura MCP en Almacenes sigue bloqueada hasta que el PM confirme cómo resolver el aislamiento multi-tenant de `ALMDataService` (ver pregunta abierta #1 del relevamiento de Sprint 3) — posible tema de arquitectura (🔴).

