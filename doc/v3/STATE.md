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
**Última actualización:** 2026-07-28 por Claude Code (E7-INFRA-01/02)

### Tareas activas

| ID | Descripción | Clase | Estado | Rama / PR |
|---|---|---|---|---|
| E7-INFRA-01/02 | Sizing VM GCP + scripts instalación nativa WSO2 (ADR-011) | 🟡 | **Completada** — VM creada, APIM+MI arriba, reverse proxy con TLS funcionando | PR #403 (mergeado) — fixes post-merge en `fix/e7-infra-01-02-post-merge-followups` (pendiente de abrir PR) |
| E1-API-20 | Relevamiento de estado para dimensionar Sprint 3 (3 frentes) | 🟢 | Completada | `docs/e1-api-20-sprint3-relevamiento-estado` — PR pendiente de abrir |

### Próxima acción

E7-INFRA-01/02 completada: la VM en `us-east1-b` tiene WSO2 APIM 4.6.0 + MI 4.5.0 corriendo nativamente sobre Rocky Linux 9, con Caddy sirviendo TLS en `mcp.cloudtrazalog.com`. Falta abrir PR de `fix/e7-infra-01-02-post-merge-followups` → `develop-v3` con todos los fixes encontrados durante la ejecución real (ver decisiones recientes) y, antes de dar de alta al primer cliente, resolver lo que quedó explícitamente fuera de esta tarea: identidad (ADR-008/009) y migración de DataServices a PostgreSQL (ver Bloqueos). En paralelo, sigue pendiente que Rodolfo responda las 5 preguntas abiertas de `doc/v3/sprint-3-relevamiento-estado.md` (especialmente el riesgo de seguridad en `ALMDataService` — §2).

### Decisiones recientes (últimas 5)

| Fecha | Decisión | Referencia |
|---|---|---|
| 2026-07-28 | E7-INFRA-01/02 completada en la práctica: VM levantada, APIM+MI corriendo. Aparecieron y se corrigieron 2 problemas reales no cubiertos por el checklist original: (1) registro interno del APIM se dejó en H2 embebida en vez de PostgreSQL, decisión explícita de Rodolfo (acota ADR-011 punto 6, nota agregada al ADR); (2) SELinux (Enforcing por defecto en Rocky/GCP) bloqueaba la ejecución de los binarios tras el `mv` desde el temp de descompresión — se agregó `restorecon -R` a `install-apim.sh`/`install-mi.sh` | `doc/v3/deployment-gcp.md`, ADR-011, `fix/e7-infra-01-02-post-merge-followups` |
| 2026-07-27 | PR #403 mergeado a `develop-v3`. Durante la ejecución del checklist apareció un 404 real en el repo RPM de Adoptium para JDK 21 (`rocky/9` no existe, solo `rocky/8`) — corregido a `rhel/9` (Rocky 9 es compatible 1:1 con RHEL 9) | `doc/v3/deployment-gcp.md`, PR #403 |
| 2026-07-24 | Corregido el SO de la VM GCP: `Rocky Linux 9` (no Ubuntu, error de la v1 del doc). Ya estaba decidido en IDR-001 (`TRAZALOG_v3_MCP_ARCHITECTURE.md` §9-10) por incompatibilidad de CentOS 7/glibc con JDK 21 — no es una decisión nueva | `doc/v3/deployment-gcp.md`, PR #403 |
| 2026-07-21 | Sizing final de la VM GCP: `e2-medium` (2 vCPU/4GB), no `e2-standard-2`. Rodolfo priorizó costo (~US$24/mes) + volumen real (1-2 usuarios) por sobre el mínimo "de catálogo" de WSO2, con heaps chicos ya validados en su DEV | `doc/v3/deployment-gcp.md`, PR #403 |
| 2026-07-16 | Relevamiento Sprint 3 completo: Mantenimiento con diseño listo para implementar, Almacenes con lógica de negocio ya existente pero gap de seguridad multi-tenant sin resolver, Despliegue GCP arranca de cero en artefactos | `doc/v3/sprint-3-relevamiento-estado.md` |

### Bloqueos

- Config de identidad (ADR-008/009) y migración de DataServices a PostgreSQL siguen pendientes antes de poder dar de alta al primer cliente sobre esta VM — fuera de alcance de E7-INFRA-01/02.
- La implementación de escritura MCP en Almacenes sigue bloqueada hasta que el PM confirme cómo resolver el aislamiento multi-tenant de `ALMDataService` (ver pregunta abierta #1 del relevamiento) — posible tema de arquitectura (🔴).

