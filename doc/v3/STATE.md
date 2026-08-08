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
**Última actualización:** 2026-08-08 por Claude Code (prueba de humo E2-MCP-13 en DEV + fix case_id)

### Tareas activas

| ID | Descripción | Clase | Estado | Rama / PR |
|---|---|---|---|---|
| — | Prueba de humo de E2-MCP-13 en DEV (VPN+DB reales) + fix bug `case_id` null en `man_get_ot`/`man_get_ots` | 🟡 | **Completada.** 9/9 tools probadas con datos reales (empr_id=1): 7 reads OK, 2 writes OK end-to-end con Bonita real (`man_create_ot` → OT 291/case 30001, `alm_crear_pedido_materiales` → pedido 1481/case 30002, ambos marcados como descartables para limpieza). Bug preexistente encontrado y arreglado: `getOTsByEmpresa`/`getSolicitudServicioById` en `MANDataService.dbs` leían `case_id` del LEFT JOIN a `orden_trabajo` en vez de la tabla base `solicitud_reparacion` — daba `null` en OTs recién creadas (verificado preexistente contra el endpoint original de `toolsMANAPI`, no introducido por la unificación). Fix verificado en vivo contra DEV real (MI local rebuild+redeploy) | `fix/e2-mcp-case-id-null-man-queries` — PR abierto, sin mergear |
| E2-MCP-13 (3.4) | OpenAPI unificada + Virtual MCP Server único + guía de migración (Bloque 3, tarea 3.4) | 🟡 | **Completada.** `doc/api/trazalog-operaciones.yaml` (9 tools, `empr_id` ausente, validada con `openapi-spec-validator`) + `doc/mcp/virtual-mcp-unificado.md` (pasos de consola + migración coordinada + smoke test) | `feature/e2-mcp-13-openapi-unificada` — PR abierto, sin mergear |
| E1-ALM (3.3) | Sumar almacenes a la fachada (Bloque 3, tarea 3.3) | 🔴 | Completada y mergeada | PR #413 |
| E2-MCP-12 | Migrar las 5 tools de mantenimiento a `toolsMCPAPI` (Bloque 3, tarea 3.2) | 🟡 | Completada y mergeada | PR #411 |
| E2-MCP-11 | Verificar ruteo múltiple + esqueleto de la fachada `toolsMCPAPI` (Bloque 3, tarea 3.1) | 🔴 | Completada y mergeada | PR #410 |
| ADR-013 | Unificación MCP: fachada delgada `toolsMCPAPI`, un solo Virtual MCP Server | — | Aprobado y mergeado | PR #408, `sprint-3-prompts.md` en PR #409 |
| E2-MCP-10-RELEV | Relevamiento para unificación de Virtual MCP Servers (Bloque 0) | 🟢 | Completada y mergeada | PR #407 |
| E7-INFRA-01/02 | Sizing VM GCP + scripts instalación nativa WSO2 (ADR-011) | 🟡 | Completada y mergeada — VM funcionando end-to-end | PR #403 y #404 mergeados |
| ADR-012 | Aislamiento y alcance de Almacenes | — | Aprobado y mergeado | PR #405 |
| E1-API-20 | Relevamiento de estado para dimensionar Sprint 3 (3 frentes) | 🟢 | Completada | `docs/e1-api-20-sprint3-relevamiento-estado` — PR pendiente de abrir (Bloque 1 de `sprint-3-prompts.md`, no ejecutado todavía) |

### Próxima acción

**Verificación en DEV de E2-MCP-13 completada** (era el prerequisito pendiente de Tarea 3.5): con VPN + Postgres arriba, se desplegó el `.car` completo en el MI local (incluye `toolsALMAPI`, que antes fallaba por falta de conectividad) y se probaron las 9 tools contra datos reales de `empr_id=1`. Resultado: todo funciona end-to-end, incluida la instanciación real de Bonita en ambos writes. En el camino apareció y se arregló un bug preexistente (`case_id` null en `man_get_ot`/`man_get_ots`, ver fila de arriba). **Próximo paso, en orden estricto (ADR-013): Tarea 3.5** (desplegar la fachada al server GCP, E7-INFRA-05), una vez que Rodolfo:
1. Revise y mergee el fix del `case_id` (`fix/e2-mcp-case-id-null-man-queries`) y la Tarea 3.4 (`feature/e2-mcp-13-openapi-unificada`).
2. Confirme que esta prueba de humo cuenta como la verificación en DEV que pedía el prompt de 3.5.
3. Decida qué hacer con los artefactos de prueba descartables (OT 291, pedido 1481).

En paralelo siguen pendientes: Bloque 1, Bloque 2 (E7-INFRA-03), y las preguntas abiertas de `doc/v3/sprint-3-relevamiento-estado.md`.

### Decisiones recientes (últimas 5)

| Fecha | Decisión | Referencia |
|---|---|---|
| 2026-08-08 | **Prueba de humo de E2-MCP-13 en DEV, a pedido de Rodolfo.** 9/9 tools verificadas con datos reales (empr_id=1) contra el MI local con VPN+Postgres arriba. Encontrado y arreglado (Rodolfo pidió el fix directo: "el arreglo del case_id es simple, lo podrias ejecutar por favor") un bug preexistente en `MANDataService.dbs`: `case_id` se leía del LEFT JOIN a `orden_trabajo` en vez de la tabla base `solicitud_reparacion`, dando `null` en OTs recién creadas | `fix/e2-mcp-case-id-null-man-queries`, `MANDataService.dbs` |
| 2026-08-03 | **Tarea 3.4 completada.** OpenAPI unificada de las 9 tools + doc de Virtual MCP Server único con guía de migración coordinada. Detectada y corregida staleness en `openapi-publish-procedure.md` (describe `X-Empr-Id` en vez del `X-JWT-Assertion` vigente de ADR-009) — no corregida en el doc viejo, solo evitada en el nuevo | `doc/api/trazalog-operaciones.yaml`, `doc/mcp/virtual-mcp-unificado.md` |
| 2026-08-02 | Rodolfo confirmó el nombre real del proceso Bonita para `alm_crear_pedido_materiales`: **"Pedido de Recursos Materiales"** — la etiqueta `"Ped. Materiales"` de `constants.php` (usada como suposición inicial) NO era el nombre real registrado en Bonita. Corregido en `toolsALMAPI.xml` y en el test Hurl | `toolsALMAPI.xml`, `tests/security/mcp-facade-alm-tools.hurl` |
| 2026-07-31 | **Tarea 3.3 (almacenes) completada y mergeada.** `toolsALMAPI.xml` (nuevo, contexto `/tools/alm`) como capa de orquestación que recibe `empr_id` EXPLÍCITO (no derivado de JWT) — decisión de Rodolfo, reusable a futuro por el PHP de v2. `toolsMCPAPI` expone 4 tools `alm_*` como fachada delgada. 3 queries aditivas en `ALMDataService.dbs`. Rollback de 3 niveles | PR #413, `toolsALMAPI.xml`, `toolsMCPAPI.xml`, `ALMDataService.dbs` |
| 2026-07-31 | E2-MCP-12 completada y mergeada: las 5 tools de mantenimiento en `toolsMCPAPI` con prefijo `man_`, ninguna reimplementa lógica | PR #411 |
| 2026-07-31 | E2-MCP-11 mergeado (PR #410): ruteo múltiple a distintos DataServices desde una sola API MI confirmado | PR #410 |

### Bloqueos

- **Antes de ejecutar los pasos de consola de `virtual-mcp-unificado.md`:** confirmar que `apim.jwt.enable=true` está activo en el `deployment.toml` del APIM (debería estarlo ya, si `trazalog-equipos`/`trazalog-ots` funcionan hoy) — sin eso, el backend JWT `X-JWT-Assertion` no se genera y `EmprIdFromHeader` falla con `identity_missing` para toda la API nueva.
- **No confirmado si WSO2 4.6.0 lee `x-mcp-annotations` del OpenAPI** para poblar `readOnlyHint`/`destructiveHint` en `tools/list` — no hay documentación oficial que lo confirme, y `equipos.yaml`/`ot.yaml` (Sprint 2) tampoco la usaban. Verificar en el smoke test de la migración (§4 de `virtual-mcp-unificado.md`); si no aparecen, es un gap preexistente de Sprint 2, no introducido acá.
- Config de identidad (ADR-008/009) y migración de DataServices a PostgreSQL siguen pendientes antes de poder dar de alta al primer cliente sobre la VM de GCP — cubierto por E7-INFRA-03 (Bloque 2, no ejecutado todavía).
- **Nota operativa (de E2-MCP-11, sigue vigente):** el deploy del `.car` de `ToolsAPIProject` es atómico — si `ALMDataService` (o cualquier otro `.dbs`) no puede conectar a su BD al momento del deploy, se revierte el CAR completo.
- La implementación de escritura MCP en Almacenes sigue bloqueada hasta que el PM confirme cómo resolver el aislamiento multi-tenant de `ALMDataService` (ver pregunta abierta #1 del relevamiento de Sprint 3) — posible tema de arquitectura (🔴).
