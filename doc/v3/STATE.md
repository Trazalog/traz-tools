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
**Última actualización:** 2026-07-21 por Claude Code (E7-INFRA-01/02)

### Tareas activas

| ID | Descripción | Clase | Estado | Rama / PR |
|---|---|---|---|---|
| E7-INFRA-01/02 | Sizing VM GCP + scripts instalación nativa WSO2 (ADR-011) | 🟡 | En review | `feature/e7-infra-01-02-gcp-native-deploy` — PR #403 |
| E1-API-20 | Relevamiento de estado para dimensionar Sprint 3 (3 frentes) | 🟢 | Completada | `docs/e1-api-20-sprint3-relevamiento-estado` — PR pendiente de abrir |

### Próxima acción

Rodolfo ya confirmó el sizing (`e2-medium`, ~US$24-25/mes) y aclaró que las VMs del proyecto viven en "Trazalog" en GCP. Falta que confirme la región/VPC exacta donde viven Dnato y PostgreSQL (ver `doc/v3/deployment-gcp.md` §4 paso 1) y que ejecute el checklist de esa sección en su consola de GCP. En paralelo, sigue pendiente que responda las 5 preguntas abiertas de `doc/v3/sprint-3-relevamiento-estado.md` (especialmente el riesgo de seguridad en `ALMDataService` — §2).

### Decisiones recientes (últimas 5)

| Fecha | Decisión | Referencia |
|---|---|---|
| 2026-07-21 | Sizing final de la VM GCP: `e2-medium` (2 vCPU/4GB), no `e2-standard-2`. Rodolfo priorizó costo (~US$24/mes) + volumen real (1-2 usuarios) por sobre el mínimo "de catálogo" de WSO2, con heaps chicos ya validados en su DEV | `doc/v3/deployment-gcp.md`, PR #403 |
| 2026-07-16 | Relevamiento Sprint 3 completo: Mantenimiento con diseño listo para implementar, Almacenes con lógica de negocio ya existente pero gap de seguridad multi-tenant sin resolver, Despliegue GCP arranca de cero en artefactos | `doc/v3/sprint-3-relevamiento-estado.md` |

### Bloqueos

- **Costo real de la VM elegida (~US$50-60/mes) es una excepción parcial a ADR-005** — necesita aprobación explícita de Rodolfo antes de crear la VM (ver `doc/v3/deployment-gcp.md` §1.4).
- Config de identidad (ADR-008/009) y migración de DataServices a PostgreSQL siguen pendientes antes de poder dar de alta al primer cliente sobre esta VM — fuera de alcance de E7-INFRA-01/02.
- La implementación de escritura MCP en Almacenes sigue bloqueada hasta que el PM confirme cómo resolver el aislamiento multi-tenant de `ALMDataService` (ver pregunta abierta #1 del relevamiento) — posible tema de arquitectura (🔴).

