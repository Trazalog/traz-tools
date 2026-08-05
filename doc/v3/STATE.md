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
**Última actualización:** 2026-08-05 por Claude Code (mejora de documentación MCP)

### Tareas activas

| ID | Descripción | Clase | Estado | Rama / PR |
|---|---|---|---|---|
| — | Mejora de calidad de documentación MCP (a pedido de Rodolfo, fuera de la numeración de `sprint-3-prompts.md`) | 🟢 | **Completada.** Cada doc de esta familia ahora dice su Objetivo arriba de todo. Nuevo `doc/infra/wso2-redeploy-artifacts.md` + `scripts/dev/rebuild-and-deploy-mi.sh` (no existía forma documentada de recompilar+redesplegar el `.car` al MI) | `docs/mejorar-calidad-doc-mcp-redeploy` — PR abierto, sin mergear |
| E2-MCP-13 (3.4) | OpenAPI unificada + Virtual MCP Server único + guía de migración (Bloque 3, tarea 3.4) | 🟡 | Completada y mergeada | PR #414 |
| E1-ALM (3.3) | Sumar almacenes a la fachada (Bloque 3, tarea 3.3) | 🔴 | Completada y mergeada | PR #413 |
| E2-MCP-12 | Migrar las 5 tools de mantenimiento a `toolsMCPAPI` (Bloque 3, tarea 3.2) | 🟡 | Completada y mergeada | PR #411 |
| E2-MCP-11 | Verificar ruteo múltiple + esqueleto de la fachada `toolsMCPAPI` (Bloque 3, tarea 3.1) | 🔴 | Completada y mergeada | PR #410 |
| ADR-013 | Unificación MCP: fachada delgada `toolsMCPAPI`, un solo Virtual MCP Server | — | Aprobado y mergeado | PR #408, `sprint-3-prompts.md` en PR #409 |
| E2-MCP-10-RELEV | Relevamiento para unificación de Virtual MCP Servers (Bloque 0) | 🟢 | Completada y mergeada | PR #407 |
| E7-INFRA-01/02 | Sizing VM GCP + scripts instalación nativa WSO2 (ADR-011) | 🟡 | Completada y mergeada — VM funcionando end-to-end | PR #403 y #404 mergeados |
| ADR-012 | Aislamiento y alcance de Almacenes | — | Aprobado y mergeado | PR #405 |
| E1-API-20 | Relevamiento de estado para dimensionar Sprint 3 (3 frentes) | 🟢 | Completada | `docs/e1-api-20-sprint3-relevamiento-estado` — PR pendiente de abrir (Bloque 1 de `sprint-3-prompts.md`, no ejecutado todavía) |

### Próxima acción

**Tarea 3.5 pausada antes de arrancar:** el prompt exige "E2-MCP-13 mergeado **y verificado por Rodolfo en DEV**" — mergeado sí, verificado todavía no confirmado. Al preguntarle, Rodolfo pidió primero mejorar la documentación (ver decisión de hoy) en vez de responder directamente — probablemente porque, sin `wso2-redeploy-artifacts.md`, no tenía un camino claro para llevar los cambios de `toolsMCPAPI`/`toolsALMAPI` (mergeados en 3.1-3.3) a su MI local y poder hacer esa verificación. Con el script y el doc nuevos, el próximo paso es que Rodolfo:
1. Corra `./scripts/dev/rebuild-and-deploy-mi.sh` para llevar los cambios de las tareas 3.1-3.3 a su MI local.
2. Ejecute los pasos de consola de `virtual-mcp-unificado.md` (publicar la API, generar `trazalog-operaciones`, smoke test de las 9 tools + aislamiento 2 empresas).
3. Recién con eso en verde, confirmar y retomar la Tarea 3.5 (desplegar a GCP).

En paralelo siguen pendientes: Bloque 1, Bloque 2 (E7-INFRA-03), y las preguntas abiertas de `doc/v3/sprint-3-relevamiento-estado.md`.

### Decisiones recientes (últimas 5)

| Fecha | Decisión | Referencia |
|---|---|---|
| 2026-08-05 | **Mejora de documentación MCP, a pedido de Rodolfo.** Cada doc de esta familia (`virtual-mcp-unificado.md`, `openapi-publish-procedure.md`) ahora tiene una sección `## Objetivo` explícita arriba de todo — antes arrancaban directo en metadata técnica sin decir para qué servía el documento ni a quién estaba dirigido. Se creó `doc/infra/wso2-redeploy-artifacts.md` (no existía ningún doc que explicara cómo redesplegar artefactos del MI vs. de la API en el APIM — son mecanismos distintos y la confusión era real) + `scripts/dev/rebuild-and-deploy-mi.sh` (no existía un script que compilara Y desplegara — el único que había, `setup-mi-b4-car-deploy.sh`, asume el `.car` ya compilado). Script probado en vivo en este entorno (build+deploy+restart del MI, confirmado que funciona) | `doc/infra/wso2-redeploy-artifacts.md`, `scripts/dev/rebuild-and-deploy-mi.sh`, `doc/mcp/virtual-mcp-unificado.md`, `doc/api/openapi-publish-procedure.md` |
| 2026-08-03 | **Tarea 3.4 completada y mergeada.** OpenAPI unificada de las 9 tools + doc de Virtual MCP Server único con guía de migración coordinada. Detectada staleness en `openapi-publish-procedure.md` (describe `X-Empr-Id` en vez del `X-JWT-Assertion` vigente de ADR-009) | PR #414, `doc/api/trazalog-operaciones.yaml`, `doc/mcp/virtual-mcp-unificado.md` |
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
