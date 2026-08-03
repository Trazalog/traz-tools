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
**Última actualización:** 2026-08-02 por Claude Code (E1-ALM / tarea 3.3)

### Tareas activas

| ID | Descripción | Clase | Estado | Rama / PR |
|---|---|---|---|---|
| E1-ALM (3.3) | Sumar almacenes a la fachada (Bloque 3, tarea 3.3) | 🔴 | **Completada, desbloqueada por Rodolfo.** Creado `toolsALMAPI` nuevo (orquestación INSERT+BPM+rollback, recibe `empr_id` explícito — reusable a futuro por el PHP de v2) + 4 tools `alm_*` en `toolsMCPAPI` como fachada delgada. Build verificado. **No probado en vivo** (sin BD/Bonita conectados en este entorno) | `feature/e1-alm-toolsalmapi-fachada` — PR abierto, sin mergear |
| E2-MCP-12 | Migrar las 5 tools de mantenimiento a `toolsMCPAPI` (Bloque 3, tarea 3.2) | 🟡 | Completada y mergeada | PR #411 |
| E2-MCP-11 | Verificar ruteo múltiple + esqueleto de la fachada `toolsMCPAPI` (Bloque 3, tarea 3.1) | 🔴 | Completada y mergeada | PR #410 |
| ADR-013 | Unificación MCP: fachada delgada `toolsMCPAPI`, un solo Virtual MCP Server | — | Aprobado y mergeado | PR #408, `sprint-3-prompts.md` en PR #409 |
| E2-MCP-10-RELEV | Relevamiento para unificación de Virtual MCP Servers (Bloque 0) | 🟢 | Completada y mergeada | PR #407 |
| E7-INFRA-01/02 | Sizing VM GCP + scripts instalación nativa WSO2 (ADR-011) | 🟡 | Completada y mergeada — VM funcionando end-to-end | PR #403 y #404 mergeados |
| ADR-012 | Aislamiento y alcance de Almacenes | — | Aprobado y mergeado | PR #405 |
| E1-API-20 | Relevamiento de estado para dimensionar Sprint 3 (3 frentes) | 🟢 | Completada | `docs/e1-api-20-sprint3-relevamiento-estado` — PR pendiente de abrir (Bloque 1 de `sprint-3-prompts.md`, no ejecutado todavía) |

### Próxima acción

Tarea 3.3 completada tras la corrección de Rodolfo: el relevamiento inicial había mirado el flujo equivocado (`Pedidosmateriales.php` → `crearPedidoOT`, atado a una OT). El flujo REAL que usa la pantalla actual de "crear pedido" (`Notapedido::crearNotaPedido`) sí es un payload libre de artículos — mucho más cerca de lo que asumía ADR-012. Con eso confirmado, se creó `toolsALMAPI` (nuevo, orquestación reusable a futuro por PHP) + las 4 tools `alm_*` en `toolsMCPAPI`. Rodolfo confirmó el nombre real del proceso Bonita: **"Pedido de Recursos Materiales"** (la etiqueta `"Ped. Materiales"` de `constants.php` NO era el nombre real — corregido). **Falta review de Rodolfo y, antes de mergear, decidir si vale la pena validar en vivo** (requiere VPN + reactivar la VM de Postgres de DEV — ver nota en Bloqueos). **Próximo paso, en orden estricto (ADR-013): Tarea 3.4** (OpenAPI unificada + Virtual MCP Server + migración coordinada), una vez mergeada esta. En paralelo siguen pendientes: Bloque 1, Bloque 2 (E7-INFRA-03), y las preguntas abiertas de `doc/v3/sprint-3-relevamiento-estado.md`.

### Decisiones recientes (últimas 5)

| Fecha | Decisión | Referencia |
|---|---|---|
| 2026-08-02 | Rodolfo confirmó el nombre real del proceso Bonita para `alm_crear_pedido_materiales`: **"Pedido de Recursos Materiales"** — la etiqueta `"Ped. Materiales"` de `constants.php` (usada como suposición inicial) NO era el nombre real registrado en Bonita. Corregido en `toolsALMAPI.xml` y en el test Hurl | `toolsALMAPI.xml`, `tests/security/mcp-facade-alm-tools.hurl` |
| 2026-07-31 | **Tarea 3.3 (almacenes) completada.** Corrección de Rodolfo sobre el relevamiento inicial: el flujo real de "crear pedido" (`Notapedido::crearNotaPedido`) usa un payload libre de artículos (arti_id+cantidad+depo_id), no atado a una OT. Se creó `toolsALMAPI.xml` (nuevo, contexto `/tools/alm`) como capa de orquestación que recibe `empr_id` EXPLÍCITO (no derivado de JWT) — decisión de Rodolfo, para que a futuro el PHP de v2 pueda migrar a llamarla también, en vez de hacer INSERT+BPM a mano sin rollback como hace hoy. `toolsMCPAPI` expone 4 tools `alm_*` como fachada delgada que solo resuelve empr_id del JWT y delega. Se agregaron 3 queries aditivas a `ALMDataService.dbs` (`getPedidosMaterialesEmpresa`, `setCaseIdPedido`, `deletePedido`) — no tocan ninguna query existente, DataService compartido con v2 en producción. Rollback de 3 niveles implementado (falla INSERT detalle / falla BPM / falla update case_id). Build verificado; **sin probar en vivo** (sin BD/Bonita conectados en este entorno — ver nota en Bloqueos) | `_backend/api/ToolsAPIProject/.../artifacts/apis/toolsALMAPI.xml`, `toolsMCPAPI.xml`, `ALMDataService.dbs` |
| 2026-07-31 | E2-MCP-12 completada y mergeada: las 5 tools de mantenimiento en `toolsMCPAPI` con prefijo `man_`, ninguna reimplementa lógica | PR #411, `_backend/api/ToolsAPIProject/.../artifacts/apis/toolsMCPAPI.xml` |
| 2026-07-31 | E2-MCP-11 mergeado (PR #410): ruteo múltiple a distintos DataServices desde una sola API MI confirmado (evidencia estática + confirmación de Rodolfo por experiencia propia) | PR #410 |
| 2026-07-31 | ADR-013 aprobado y mergeado: fachada delgada `toolsMCPAPI`, un solo Virtual MCP Server, tools con prefijo de módulo (`man_`, `alm_`) | PR #408, `doc/adr/ADR-013-unificacion-mcp.md` |
| 2026-07-31 | Relevamiento de unificación MCP completado: 1 API WSO2 = 1 Virtual MCP Server (no se pueden combinar varias APIs) | PR #407, `doc/v3/relevamiento-unificacion-mcp.md` |

### Bloqueos

- **Pendiente de Rodolfo antes de mergear la Tarea 3.3:**
  1. ~~Confirmar el nombre exacto del proceso Bonita~~ **Resuelto: "Pedido de Recursos Materiales"** (confirmado 2026-08-02, corregido en `toolsALMAPI.xml`).
  2. Decidir si vale la pena validar en vivo antes de mergear (requiere levantar la VPN de Trazalog + reactivar la VM de PostgreSQL de DEV, hoy frozen — avisar a Claude Code antes de intentarlo, no asumir que el entorno está listo). Toca un DataService compartido con producción v2 (`ALMDataService.dbs`, cambios aditivos) y agrega un flujo de escritura+BPM nuevo — mayor riesgo que la migración de mantenimiento (que solo replicaba lógica ya probada).
- Config de identidad (ADR-008/009) y migración de DataServices a PostgreSQL siguen pendientes antes de poder dar de alta al primer cliente sobre la VM de GCP — cubierto por E7-INFRA-03 (Bloque 2, no ejecutado todavía).
- **Nota operativa (de E2-MCP-11, sigue vigente):** el deploy del `.car` de `ToolsAPIProject` es atómico — si `ALMDataService` (o cualquier otro `.dbs`) no puede conectar a su BD al momento del deploy, se revierte el CAR completo.
- La implementación de escritura MCP en Almacenes sigue bloqueada hasta que el PM confirme cómo resolver el aislamiento multi-tenant de `ALMDataService` (ver pregunta abierta #1 del relevamiento de Sprint 3) — posible tema de arquitectura (🔴).
