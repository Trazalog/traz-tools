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
**Última actualización:** 2026-07-31 por Claude Code (E2-MCP-11)

### Tareas activas

| ID | Descripción | Clase | Estado | Rama / PR |
|---|---|---|---|---|
| E2-MCP-11 | Verificar ruteo múltiple + esqueleto de la fachada `toolsMCPAPI` (Bloque 3, tarea 3.1) | 🔴 | **Completada** — ruteo múltiple confirmado, `toolsMCPAPI` creado con `man_get_equipos` end-to-end | `feature/e2-mcp-11-toolsmcpapi-skeleton` — PR abierto, sin mergear |
| ADR-013 | Unificación MCP: fachada delgada `toolsMCPAPI`, un solo Virtual MCP Server | — | **Aprobado y mergeado** (workshop CW+Rodolfo sobre el relevamiento) | PR #408, `sprint-3-prompts.md` actualizado en PR #409 |
| E2-MCP-10-RELEV | Relevamiento para unificación de Virtual MCP Servers (Bloque 0) | 🟢 | Completada y mergeada | PR #407 |
| E7-INFRA-01/02 | Sizing VM GCP + scripts instalación nativa WSO2 (ADR-011) | 🟡 | Completada y mergeada — VM funcionando end-to-end | PR #403 y #404 mergeados |
| ADR-012 | Aislamiento y alcance de Almacenes | — | Aprobado y mergeado | PR #405 |
| E1-API-20 | Relevamiento de estado para dimensionar Sprint 3 (3 frentes) | 🟢 | Completada | `docs/e1-api-20-sprint3-relevamiento-estado` — PR pendiente de abrir (Bloque 1 de `sprint-3-prompts.md`, no ejecutado todavía) |

### Próxima acción

Tarea 3.1 del Bloque 3 completada: el ruteo a múltiples DataServices desde una sola API MI está confirmado (ver decisión de hoy), y `toolsMCPAPI` existe con una tool de punta a punta (`man_get_equipos`) siguiendo el patrón exacto de `toolsMANAPI`. **Próximo paso, en orden estricto (ADR-013): Tarea 3.2** — migrar el resto de las tools de mantenimiento (`man_get_equipo`, `man_get_ots`, `man_get_ot`, `man_create_ot`) a `toolsMCPAPI`, una vez que este PR se revise y mergee. En paralelo siguen pendientes: Bloque 1 (abrir PR de `docs/e1-api-20-sprint3-relevamiento-estado`), Bloque 2 (E7-INFRA-03, identidad en la VM nueva), y que Rodolfo responda las preguntas abiertas de `doc/v3/sprint-3-relevamiento-estado.md`.

### Decisiones recientes (últimas 5)

| Fecha | Decisión | Referencia |
|---|---|---|
| 2026-07-31 | **E2-MCP-11 — ruteo múltiple CONFIRMADO.** Evidencia estática sólida: `toolsMANAPI` ya rutea distintos resources a distintos DataServices (`MANDataService`, `MANEquiposDataService`) con el mismo mecanismo dinámico (`fn:concat($ctx:dataservices_url,'/<DataService>/...')`), ya verificado en producción. Se intentó además una verificación en vivo real (MI local de Rodolfo, `.car` recién buildeado con `toolsMCPAPI`) — el MI arrancó bien, pero el CAR completo falló al deployar por un timeout de conexión de `ALMDataService` a PostgreSQL (sin ruta de red desde este entorno a esa BD) — **no relacionado a `toolsMCPAPI` ni a la pregunta de ruteo**, solo evidencia que el deploy del CApp es atómico (una falla de conexión de cualquier DataService revierte todo el CAR). `toolsMCPAPI` creado con `man_get_equipos` (réplica exacta de `/mcp/equipos` de `toolsMANAPI`, bajo `/mcp/man/equipos`) | `_backend/api/ToolsAPIProject/.../artifacts/apis/toolsMCPAPI.xml`, ADR-013 |
| 2026-07-31 | ADR-013 aprobado y mergeado: fachada delgada `toolsMCPAPI` (resuelve empr_id una vez, rutea a DataServices existentes), un solo Virtual MCP Server, tools con prefijo de módulo (`man_`, `alm_`) | PR #408, `doc/adr/ADR-013-unificacion-mcp.md` |
| 2026-07-31 | Relevamiento de unificación MCP completado: 1 API WSO2 = 1 Virtual MCP Server (no se pueden combinar varias APIs), confirmado contra doc oficial 4.6.0 + evidencia del propio entorno | PR #407, `doc/v3/relevamiento-unificacion-mcp.md` |
| 2026-07-30 | ADR-012 aprobado y mergeado: Almacenes reusa el patrón de Mantenimiento (empr_id del JWT, crear_pedido_materiales con BPM+rollback estilo create_ot), alcance limitado a pedidos (sin operaciones de stock) | PR #405, `doc/adr/ADR-012-almacenes-aislamiento.md` |
| 2026-07-28 | E7-INFRA-01/02 completada en la práctica: VM levantada, APIM+MI corriendo. SELinux + repo JDK corregidos | PR #404, `doc/v3/deployment-gcp.md`, ADR-011 |

### Bloqueos

- **Tarea 3.3 (Almacenes en la fachada) espera que 3.1 (esta) y 3.2 se mergeen primero** — orden estricto de ADR-013.
- Config de identidad (ADR-008/009) y migración de DataServices a PostgreSQL siguen pendientes antes de poder dar de alta al primer cliente sobre la VM de GCP — cubierto por E7-INFRA-03 (Bloque 2 de `sprint-3-prompts.md`, no ejecutado todavía).
- **Nota operativa para cuando se pruebe end-to-end con BD real:** el deploy del `.car` de `ToolsAPIProject` es atómico — si `ALMDataService` (o cualquier otro `.dbs` del proyecto) no puede conectar a su BD al momento del deploy, se revierte el CAR completo, incluida `toolsMCPAPI`. No es un problema de esta tarea, pero vale tenerlo presente para la VM de GCP y para cuando se sumen las DataServices de almacenes (Tarea 3.3).
- La implementación de escritura MCP en Almacenes sigue bloqueada hasta que el PM confirme cómo resolver el aislamiento multi-tenant de `ALMDataService` (ver pregunta abierta #1 del relevamiento de Sprint 3) — posible tema de arquitectura (🔴).

