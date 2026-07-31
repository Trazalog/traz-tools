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
**Última actualización:** 2026-07-31 por Claude Code (E1-ALM / tarea 3.3 — DETENIDA)

### Tareas activas

| ID | Descripción | Clase | Estado | Rama / PR |
|---|---|---|---|---|
| E1-ALM (3.3) | Sumar almacenes a `toolsMCPAPI` (Bloque 3, tarea 3.3) | 🔴 | **DETENIDA — parada obligatoria.** Relevado `ALMDataService` + PHP v2 real: el payload/proceso/flujo NO son análogos a `create_ot` como asumía ADR-012. Sin código escrito. Esperando decisión de Rodolfo (ver preguntas abiertas abajo) | Sin rama — no se abrió PR (nada que mostrar todavía) |
| E2-MCP-12 | Migrar las 5 tools de mantenimiento a `toolsMCPAPI` (Bloque 3, tarea 3.2) | 🟡 | Completada y mergeada | PR #411 |
| E2-MCP-11 | Verificar ruteo múltiple + esqueleto de la fachada `toolsMCPAPI` (Bloque 3, tarea 3.1) | 🔴 | Completada y mergeada | PR #410 |
| ADR-013 | Unificación MCP: fachada delgada `toolsMCPAPI`, un solo Virtual MCP Server | — | Aprobado y mergeado | PR #408, `sprint-3-prompts.md` en PR #409 |
| E2-MCP-10-RELEV | Relevamiento para unificación de Virtual MCP Servers (Bloque 0) | 🟢 | Completada y mergeada | PR #407 |
| E7-INFRA-01/02 | Sizing VM GCP + scripts instalación nativa WSO2 (ADR-011) | 🟡 | Completada y mergeada — VM funcionando end-to-end | PR #403 y #404 mergeados |
| ADR-012 | Aislamiento y alcance de Almacenes | — | Aprobado y mergeado | PR #405 |
| E1-API-20 | Relevamiento de estado para dimensionar Sprint 3 (3 frentes) | 🟢 | Completada | `docs/e1-api-20-sprint3-relevamiento-estado` — PR pendiente de abrir (Bloque 1 de `sprint-3-prompts.md`, no ejecutado todavía) |

### Próxima acción

**Tarea 3.3 detenida en el PASO de relevamiento, antes de escribir código** (parada obligatoria 🔴, según lo previsto en `sprint-3-prompts.md`). Al relevar `ALMDataService.dbs` + el PHP v2 real que hoy crea pedidos de materiales (`application/modules/traz-comp-almacenes/models/new/Pedidosmateriales.php` y afines), aparecieron 3 discrepancias con lo que asumía ADR-012 — ver decisión de hoy. **Se necesita que Rodolfo responda antes de seguir**, ver preguntas abiertas en Bloqueos. En paralelo siguen pendientes: Bloque 1, Bloque 2 (E7-INFRA-03), y las preguntas abiertas de `doc/v3/sprint-3-relevamiento-estado.md`.

### Decisiones recientes (últimas 5)

| Fecha | Decisión | Referencia |
|---|---|---|
| 2026-07-31 | **Tarea 3.3 (almacenes) DETENIDA — parada obligatoria.** El PHP real (`Pedidosmateriales.php`, `models/new/`) muestra que "crear pedido" está atado a una OT (`ortr_id`, detalle sourced de `tbl_otinsumos`), no a un payload libre de artículo+cantidad+depósito como asumía ADR-012. El proceso Bonita se identifica por ID numérico (`BPM_PROCESS_ID_PEDIDOS_NORMALES` = `8803232493891311406`, no por nombre como `create_ot`). El PHP no hace rollback (DELETE) explícito si el BPM falla — a diferencia del patrón de `create_ot`. Además, en `ALMDataService.dbs` no existe una query de "listado de pedidos de la empresa" análoga a `mcp/ots`, y la query de stock más completa (`getStock`) exige también `id_user` (encargado de depósito), no solo `empr_id`. Ningún código escrito — se paró antes, tal como indica el prompt | (sin archivo nuevo — hallazgos documentados acá y en el chat con Rodolfo) |
| 2026-07-31 | E2-MCP-12 completada y mergeada: las 5 tools de mantenimiento en `toolsMCPAPI` con prefijo `man_`, ninguna reimplementa lógica | PR #411, `_backend/api/ToolsAPIProject/.../artifacts/apis/toolsMCPAPI.xml` |
| 2026-07-31 | E2-MCP-11 mergeado (PR #410): ruteo múltiple a distintos DataServices desde una sola API MI confirmado (evidencia estática + confirmación de Rodolfo por experiencia propia) | PR #410 |
| 2026-07-31 | ADR-013 aprobado y mergeado: fachada delgada `toolsMCPAPI`, un solo Virtual MCP Server, tools con prefijo de módulo (`man_`, `alm_`) | PR #408, `doc/adr/ADR-013-unificacion-mcp.md` |
| 2026-07-31 | Relevamiento de unificación MCP completado: 1 API WSO2 = 1 Virtual MCP Server (no se pueden combinar varias APIs) | PR #407, `doc/v3/relevamiento-unificacion-mcp.md` |
| 2026-07-30 | ADR-012 aprobado y mergeado: Almacenes reusa el patrón de Mantenimiento, alcance limitado a pedidos (sin operaciones de stock) | PR #405, `doc/adr/ADR-012-almacenes-aislamiento.md` |

### Bloqueos

- **Tarea 3.3 (Almacenes en la fachada) DETENIDA — necesita respuesta de Rodolfo en 4 preguntas concretas antes de escribir código:**
  1. **`crear_pedido_materiales`, ¿qué payload/flujo replica?** El PHP real (`Pedidosmateriales.php`) crea el pedido atado a una OT (`ortr_id`) y saca el detalle de `tbl_otinsumos` (`crearPedidoOT`) — no de un payload libre tipo "artículo + cantidad + depósito" como asumía ADR-012. ¿La tool MCP debe replicar ese flujo (recibe un `ot_id`, no una lista de artículos), o hace falta un flujo distinto para el piloto?
  2. **¿El proceso Bonita se lanza por ID o por nombre?** `create_ot` usa `nombre_proceso` en el JSON hacia `/bpm/proceso/instancia`. El pedido de materiales usa `BPM_PROCESS_ID_PEDIDOS_NORMALES` = `8803232493891311406` (ID numérico) en el PHP. ¿El endpoint WSO2 de instanciación acepta ID además de nombre, o hay que resolver el nombre real de ese proceso en Bonita?
  3. **El PHP no hace rollback (DELETE) del pedido si el BPM falla** — a diferencia de `create_ot`. ¿Se agrega el rollback igual (mejora sobre el comportamiento actual) o se replica el comportamiento real tal cual está hoy (sin rollback)?
  4. **Lecturas: no hay query de "listado de pedidos de la empresa" en `ALMDataService`** (las que existen filtran por origen/tarea, no "todos los de mi empresa" como `mcp/ots`) — ¿hay que escribir una query nueva en el `.dbs` (toca un DataService compartido con el v2 en producción), o hay otra tabla/vista que sí sirva? Y la query de stock más completa (`getStock`) exige también `id_user` (encargado de depósito) además de `empr_id` — el JWT del agente no tiene ese dato hoy. ¿Usar una query sin ese filtro (ej. `getArticulos2`, solo por `empr_id`) alcanza para el piloto?
  Detalle completo del relevamiento en la conversación con Claude Code del 2026-07-31.
- Config de identidad (ADR-008/009) y migración de DataServices a PostgreSQL siguen pendientes antes de poder dar de alta al primer cliente sobre la VM de GCP — cubierto por E7-INFRA-03 (Bloque 2, no ejecutado todavía).
- **Nota operativa (de E2-MCP-11, sigue vigente):** el deploy del `.car` de `ToolsAPIProject` es atómico — si `ALMDataService` (o cualquier otro `.dbs`) no puede conectar a su BD al momento del deploy, se revierte el CAR completo. Relevante para cuando se sumen las DataServices de almacenes (Tarea 3.3) y para el deploy en la VM de GCP.
- La implementación de escritura MCP en Almacenes sigue bloqueada hasta que el PM confirme cómo resolver el aislamiento multi-tenant de `ALMDataService` (ver pregunta abierta #1 del relevamiento de Sprint 3) — posible tema de arquitectura (🔴).

