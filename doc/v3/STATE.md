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

**Sprint actual:** Sprint 3 — Activación early adopter minero (dimensionamiento)
**Objetivo del sprint:** Relevar estado real de los 3 frentes (Mantenimiento, Almacenes, Despliegue GCP) para que el PM priorice con datos reales antes de arrancar implementación.
**Última actualización:** 2026-07-16 por Claude Code (E1-API-20)

### Tareas activas

| ID | Descripción | Clase | Estado | Rama / PR |
|---|---|---|---|---|
| E1-API-20 | Relevamiento de estado para dimensionar Sprint 3 (3 frentes) | 🟢 | Completada | `docs/e1-api-20-sprint3-relevamiento-estado` — PR pendiente de abrir |

### Próxima acción

Rodolfo revisa `doc/v3/sprint-3-relevamiento-estado.md` y responde las 5 preguntas abiertas de la sección 5 (especialmente el riesgo de seguridad en `ALMDataService` — §2 del doc) antes de asignar trabajo de implementación del Sprint 3.

### Decisiones recientes (últimas 5)

| Fecha | Decisión | Referencia |
|---|---|---|
| 2026-07-16 | Relevamiento Sprint 3 completo: Mantenimiento con diseño listo para implementar, Almacenes con lógica de negocio ya existente pero gap de seguridad multi-tenant sin resolver, Despliegue GCP arranca de cero en artefactos | `doc/v3/sprint-3-relevamiento-estado.md` |

### Bloqueos

- Ninguno para el relevamiento en sí. La implementación de escritura MCP en Almacenes queda bloqueada hasta que el PM confirme cómo resolver el aislamiento multi-tenant de `ALMDataService` (ver pregunta abierta #1 del relevamiento) — posible tema de arquitectura (🔴).

