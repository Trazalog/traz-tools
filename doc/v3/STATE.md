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
**Última actualización:** 2026-07-31 por Claude Code (E2-MCP-10-RELEV)

### Tareas activas

| ID | Descripción | Clase | Estado | Rama / PR |
|---|---|---|---|---|
| E2-MCP-10-RELEV | Relevamiento para unificación de Virtual MCP Servers (Bloque 0) | 🟢 | **Completada** — ver `doc/v3/relevamiento-unificacion-mcp.md` | `docs/e2-mcp-10-relev-unificacion-mcp` — PR abierto, sin mergear |
| E7-INFRA-01/02 | Sizing VM GCP + scripts instalación nativa WSO2 (ADR-011) | 🟡 | **Completada y mergeada** — VM funcionando end-to-end | PR #403 y #404 mergeados |
| ADR-012 | Aislamiento y alcance de Almacenes | — | **Aprobado y mergeado** | PR #405 |
| Sprint 3 kickoff | Kickoff + artefacto de prompts (`sprint-3-prompts.md`) | — | Mergeado | PR #406 |
| E1-API-20 | Relevamiento de estado para dimensionar Sprint 3 (3 frentes) | 🟢 | Completada | `docs/e1-api-20-sprint3-relevamiento-estado` — PR pendiente de abrir (Bloque 1 de `sprint-3-prompts.md`, no ejecutado en esta sesión) |

### Próxima acción

Bloque 0 de `sprint-3-prompts.md` completado: `doc/v3/relevamiento-unificacion-mcp.md` responde las 2 preguntas técnicas para el ADR-013. Hallazgo clave: WSO2 4.6.0 **no permite combinar varias APIs en un solo Virtual MCP Server** (el wizard exige una API fuente única) — la unificación real requiere consolidar las operaciones de mantenimiento + almacenes en **una sola** API de WSO2 con rutas prefijadas por módulo, y generar un único MCP Server desde ahí (Opción A recomendada en el documento). **Próximo paso: CW + Rodolfo cierran el ADR-013 en workshop** usando este relevamiento — recién ahí se desbloquea el Bloque 3 de `sprint-3-prompts.md` (almacenes), que hoy espera esa decisión. En paralelo siguen pendientes: Bloque 1 (abrir PR de `docs/e1-api-20-sprint3-relevamiento-estado`, no ejecutado en esta sesión), Bloque 2 (E7-INFRA-03, identidad en la VM nueva), y que Rodolfo responda las preguntas abiertas de `doc/v3/sprint-3-relevamiento-estado.md`.

### Decisiones recientes (últimas 5)

| Fecha | Decisión | Referencia |
|---|---|---|
| 2026-07-31 | Relevamiento de unificación MCP completado: 1 API WSO2 = 1 Virtual MCP Server (no se pueden combinar varias APIs), confirmado contra doc oficial 4.6.0 + evidencia del propio entorno (equipos/OTs ya comparten backend MI pero tienen APIs y MCP Servers separados). Recomendación técnica: consolidar man+alm en una sola API con rutas prefijadas por módulo | `doc/v3/relevamiento-unificacion-mcp.md` |
| 2026-07-30 | ADR-012 aprobado y mergeado: Almacenes reusa el patrón de Mantenimiento (empr_id del JWT, crear_pedido_materiales con BPM+rollback estilo create_ot), alcance limitado a pedidos (sin operaciones de stock) | PR #405, `doc/adr/ADR-012-almacenes-aislamiento.md` |
| 2026-07-28 | E7-INFRA-01/02 completada en la práctica: VM levantada, APIM+MI corriendo. Se corrigieron 2 problemas reales no cubiertos por el checklist original: (1) registro interno del APIM en H2 embebida en vez de PostgreSQL (decisión explícita de Rodolfo, acota ADR-011 punto 6); (2) SELinux bloqueaba los binarios tras el `mv` del temp de descompresión — se agregó `restorecon -R` a los install scripts | PR #404, `doc/v3/deployment-gcp.md`, ADR-011 |
| 2026-07-27 | PR #403 mergeado a `develop-v3`. 404 real en el repo RPM de Adoptium para JDK 21 (`rocky/9` no existe, solo `rocky/8`) — corregido a `rhel/9` | `doc/v3/deployment-gcp.md`, PR #403 |
| 2026-07-24 | Corregido el SO de la VM GCP: `Rocky Linux 9` (no Ubuntu). Ya estaba decidido en IDR-001 por incompatibilidad de CentOS 7/glibc con JDK 21 | `doc/v3/deployment-gcp.md`, PR #403 |

### Bloqueos

- **Bloque 3 de `sprint-3-prompts.md` (tools MCP de Almacenes) espera el ADR-013** (unificación MCP) — no ejecutar hasta que CW+Rodolfo lo cierren con el relevamiento de `doc/v3/relevamiento-unificacion-mcp.md`.
- Config de identidad (ADR-008/009) y migración de DataServices a PostgreSQL siguen pendientes antes de poder dar de alta al primer cliente sobre la VM de GCP — cubierto por E7-INFRA-03 (Bloque 2 de `sprint-3-prompts.md`, no ejecutado todavía).
- La implementación de escritura MCP en Almacenes sigue bloqueada hasta que el PM confirme cómo resolver el aislamiento multi-tenant de `ALMDataService` (ver pregunta abierta #1 del relevamiento de Sprint 3) — posible tema de arquitectura (🔴).

