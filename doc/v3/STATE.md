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
| E7-INFRA-01/02 | Sizing VM GCP + scripts instalación nativa WSO2 (ADR-011) | 🟡 | En review | `feature/e7-infra-01-02-gcp-native-deploy` — PR pendiente de apertura |
| E1-API-20 | Relevamiento de estado para dimensionar Sprint 3 (3 frentes) | 🟢 | Completada | `docs/e1-api-20-sprint3-relevamiento-estado` — PR pendiente de abrir |

### Próxima acción

Rodolfo revisa el PR de E7-INFRA-01/02: confirma el gasto mensual implicado por `e2-standard-2` (tensión con ADR-005, ver `doc/v3/deployment-gcp.md` §1.4) y la región/VPC donde ya viven Dnato y PostgreSQL. Si aprueba, ejecuta el checklist de la §4 de ese documento en su consola de GCP. En paralelo, sigue pendiente que responda las 5 preguntas abiertas de `doc/v3/sprint-3-relevamiento-estado.md` (especialmente el riesgo de seguridad en `ALMDataService` — §2).

### Decisiones recientes (últimas 5)

| Fecha | Decisión | Referencia |
|---|---|---|
| 2026-07-21 | Sizing de la VM GCP: `e2-standard-2` (2 vCPU/8GB) — `e2-micro`/`e2-small` insuficientes por RAM, `e2-medium` empata justo con el mínimo oficial del APIM sin margen para el MI | `doc/v3/deployment-gcp.md`, PR E7-INFRA-01/02 |
| 2026-07-16 | Relevamiento Sprint 3 completo: Mantenimiento con diseño listo para implementar, Almacenes con lógica de negocio ya existente pero gap de seguridad multi-tenant sin resolver, Despliegue GCP arranca de cero en artefactos | `doc/v3/sprint-3-relevamiento-estado.md` |

### Bloqueos

- **Costo real de la VM elegida (~US$50-60/mes) es una excepción parcial a ADR-005** — necesita aprobación explícita de Rodolfo antes de crear la VM (ver `doc/v3/deployment-gcp.md` §1.4).
- Config de identidad (ADR-008/009) y migración de DataServices a PostgreSQL siguen pendientes antes de poder dar de alta al primer cliente sobre esta VM — fuera de alcance de E7-INFRA-01/02.
- La implementación de escritura MCP en Almacenes sigue bloqueada hasta que el PM confirme cómo resolver el aislamiento multi-tenant de `ALMDataService` (ver pregunta abierta #1 del relevamiento) — posible tema de arquitectura (🔴).

