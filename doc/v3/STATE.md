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
**Última actualización:** 2026-08-08 por Claude Code (Tarea 3.5 — checklist de despliegue MCP a GCP)

### Tareas activas

| ID | Descripción | Clase | Estado | Rama / PR |
|---|---|---|---|---|
| E7-INFRA-05 (3.5) | Desplegar la fachada MCP al server GCP — checklist + artefactos (Bloque 3, tarea 3.5) | 🟡 | **Completada.** `.car` verificado con build limpio contra `develop-v3`. Nueva §6 en `deployment-gcp.md`: checklist de despliegue del CAR al MI de la VM, publicar API+MCP Server en el APIM de la VM (con todos los gotchas encontrados hoy en DEV ya incorporados: endpoint x2 artefactos, puerto 8290 no 8280, suscripción de la app, Key Manager), verificación OAuth end-to-end contra `mcp.cloudtrazalog.com`, aislamiento 2 empresas. Flags explícitamente que el paso de aislamiento depende de E7-INFRA-03 (identidad, Bloque 2), todavía no ejecutado | `feature/e7-infra-05-deploy-mcp-facade-gcp` — PR abierto, sin mergear |
| E2-MCP-13 (3.4) + fixes | OpenAPI unificada + Virtual MCP Server único + smoke test real + fixes de docs (case_id, Key Manager, paths reales) | 🟡 | Completada y mergeada — verificado en DEV con smoke test real end-to-end (9/9 tools, aislamiento, Bonita real) | PR #414, #416, #417, #418, #419 |
| E1-ALM (3.3) | Sumar almacenes a la fachada (Bloque 3, tarea 3.3) | 🔴 | Completada y mergeada | PR #413 |
| E2-MCP-12 | Migrar las 5 tools de mantenimiento a `toolsMCPAPI` (Bloque 3, tarea 3.2) | 🟡 | Completada y mergeada | PR #411 |
| E2-MCP-11 | Verificar ruteo múltiple + esqueleto de la fachada `toolsMCPAPI` (Bloque 3, tarea 3.1) | 🔴 | Completada y mergeada | PR #410 |
| ADR-013 | Unificación MCP: fachada delgada `toolsMCPAPI`, un solo Virtual MCP Server | — | Aprobado y mergeado | PR #408, `sprint-3-prompts.md` en PR #409 |
| E2-MCP-10-RELEV | Relevamiento para unificación de Virtual MCP Servers (Bloque 0) | 🟢 | Completada y mergeada | PR #407 |
| E7-INFRA-01/02 | Sizing VM GCP + scripts instalación nativa WSO2 (ADR-011) | 🟡 | Completada y mergeada — VM funcionando end-to-end | PR #403 y #404 mergeados |
| ADR-012 | Aislamiento y alcance de Almacenes | — | Aprobado y mergeado | PR #405 |
| E1-API-20 | Relevamiento de estado para dimensionar Sprint 3 (3 frentes) | 🟢 | Completada | `docs/e1-api-20-sprint3-relevamiento-estado` — PR pendiente de abrir (Bloque 1 de `sprint-3-prompts.md`, no ejecutado todavía) |

### Próxima acción

**Bloque 3 completo del lado de Claude Code.** Falta la ejecución manual de Rodolfo: correr el checklist de `deployment-gcp.md` §6 en la VM de GCP (desplegar el CAR, publicar API+MCP Server, suscribir la app, verificar OAuth y aislamiento contra `mcp.cloudtrazalog.com`). **Antes de que el paso de aislamiento pueda pasar, hace falta E7-INFRA-03** (config de identidad ADR-008/009 contra el Dnato de ese mismo proyecto GCP — Bloque 2, todavía no ejecutado). Los pasos de deploy del CAR y publicación de API/MCP Server no dependen de eso y se pueden hacer antes o en paralelo.

En paralelo siguen pendientes: Bloque 1 (PR de relevamiento, no abierto todavía), y las preguntas abiertas de `doc/v3/sprint-3-relevamiento-estado.md`.

### Decisiones recientes (últimas 5)

| Fecha | Decisión | Referencia |
|---|---|---|
| 2026-08-08 | **Tarea 3.5 completada (checklist, no ejecución — requiere acceso a la VM que solo tiene Rodolfo).** `deployment-gcp.md` §6 nueva: despliegue del CAR, publicación de API+MCP Server, verificación OAuth y aislamiento contra `mcp.cloudtrazalog.com`. Incorpora todos los gotchas reales encontrados el mismo día en el smoke test de DEV para que no se repitan en GCP. Flagea explícitamente la dependencia con E7-INFRA-03 (identidad) para el paso de aislamiento | `doc/v3/deployment-gcp.md` §6 |
| 2026-08-08 | **Smoke test real del MCP Server (:8243) completado, a pedido de Rodolfo.** 9/9 tools OK, aislamiento OK, escrituras con Bonita real OK. Encontrados y corregidos en vivo 2 bugs de configuración que bloqueaban todo (suscripción faltante de la app `TrazalogDnatoMCP` al MCP Server nuevo, y endpoint mal configurado en API y MCP Server — apuntaba a `10.142.0.13:8280`, dato incorrecto mío desde la Tarea 3.4, corregido a `localhost:8290`). Documentado como paso nuevo (§2.8-bis) y troubleshooting en `virtual-mcp-unificado.md` para que no se repita | `doc/mcp/virtual-mcp-unificado.md` |
| 2026-08-08 | **Paths reales del MCP Server confirmados**: Rodolfo publicó `Trazalog MCP Server`, contexto `/trazalog/mcp`, versión `1.0` — no `trazalog-operaciones`/`/trazalog-operaciones` como sugería ADR-013. Resuelve la pregunta abierta de nombre del ADR. Docs y spec actualizados; tests Hurl no necesitaron cambios (apuntan al MI, capa sin tocar) | `doc/mcp/virtual-mcp-unificado.md`, `doc/api/trazalog-operaciones.yaml`, `doc/adr/ADR-013-unificacion-mcp.md` |
| 2026-08-08 | **Corrección en `virtual-mcp-unificado.md`**: la sección de seguridad OAuth2 (§2.4) decía que había que seleccionar "Dnato" como Key Manager en el Publisher y des-seleccionar Resident KM — instrucción incorrecta escrita en la Tarea 3.4, sin cruzar contra el doc canónico de identidad. Bloqueó a Rodolfo al intentar publicar `trazalog-operaciones` (esa opción no existe: Dnato se valida vía `[[apim.jwt.issuer]]`, no como Key Manager). Corregido con el procedimiento real de `apim-keymanager-dnato.md` §5: no tocar el selector de Key Managers, desactivar `Enable Subscription Validation` | `doc/mcp/virtual-mcp-unificado.md`, `doc/identity/apim-keymanager-dnato.md` |
| 2026-08-08 | **Prueba de humo de E2-MCP-13 en DEV, a pedido de Rodolfo.** 9/9 tools verificadas con datos reales (empr_id=1) contra el MI local con VPN+Postgres arriba. Encontrado y arreglado (Rodolfo pidió el fix directo: "el arreglo del case_id es simple, lo podrias ejecutar por favor") un bug preexistente en `MANDataService.dbs`: `case_id` se leía del LEFT JOIN a `orden_trabajo` en vez de la tabla base `solicitud_reparacion`, dando `null` en OTs recién creadas | `fix/e2-mcp-case-id-null-man-queries`, `MANDataService.dbs` |
| 2026-08-08 | **Doc de Ambientes creado**, a pedido de Rodolfo, tras confundirse con un redirect a ngrok al entrar a Publisher. Documenta cuándo DEV necesita ngrok (testing MCP con Claude.ai, federación Dnato) y cuándo no (trabajo diario), más el estado y acceso de TEST/PROD. Se identificó y corrigió la causa raíz del problema puntual: `hostname` en el `deployment.toml` local quedó pisado con un subdominio ngrok muerto por no haber corrido `--reset` al cerrar sesiones anteriores | `doc/infra/ambientes.md`, `scripts/dev/setup-ngrok.sh` |
| 2026-08-03 | **Tarea 3.4 completada.** OpenAPI unificada de las 9 tools + doc de Virtual MCP Server único con guía de migración coordinada. Detectada y corregida staleness en `openapi-publish-procedure.md` (describe `X-Empr-Id` en vez del `X-JWT-Assertion` vigente de ADR-009) — no corregida en el doc viejo, solo evitada en el nuevo | `doc/api/trazalog-operaciones.yaml`, `doc/mcp/virtual-mcp-unificado.md` |
| 2026-08-02 | Rodolfo confirmó el nombre real del proceso Bonita para `alm_crear_pedido_materiales`: **"Pedido de Recursos Materiales"** — la etiqueta `"Ped. Materiales"` de `constants.php` (usada como suposición inicial) NO era el nombre real registrado en Bonita. Corregido en `toolsALMAPI.xml` y en el test Hurl | `toolsALMAPI.xml`, `tests/security/mcp-facade-alm-tools.hurl` |
| 2026-07-31 | **Tarea 3.3 (almacenes) completada y mergeada.** `toolsALMAPI.xml` (nuevo, contexto `/tools/alm`) como capa de orquestación que recibe `empr_id` EXPLÍCITO (no derivado de JWT) — decisión de Rodolfo, reusable a futuro por el PHP de v2. `toolsMCPAPI` expone 4 tools `alm_*` como fachada delgada. 3 queries aditivas en `ALMDataService.dbs`. Rollback de 3 niveles | PR #413, `toolsALMAPI.xml`, `toolsMCPAPI.xml`, `ALMDataService.dbs` |
| 2026-07-31 | E2-MCP-12 completada y mergeada: las 5 tools de mantenimiento en `toolsMCPAPI` con prefijo `man_`, ninguna reimplementa lógica | PR #411 |
| 2026-07-31 | E2-MCP-11 mergeado (PR #410): ruteo múltiple a distintos DataServices desde una sola API MI confirmado | PR #410 |

### Bloqueos

- **Antes de ejecutar los pasos de consola de `virtual-mcp-unificado.md`:** confirmar que `apim.jwt.enable=true` está activo en el `deployment.toml` del APIM (debería estarlo ya, si `trazalog-equipos`/`trazalog-ots` funcionan hoy) — sin eso, el backend JWT `X-JWT-Assertion` no se genera y `EmprIdFromHeader` falla con `identity_missing` para toda la API nueva.
- **Confirmado (2026-08-08, smoke test real): WSO2 4.6.0 NO lee `x-mcp-annotations` del OpenAPI** — `readOnlyHint`/`destructiveHint` no aparecen en el `inputSchema` de `tools/list`. Gap preexistente de Sprint 2 (`equipos.yaml`/`ot.yaml` tampoco la usaban), no introducido por esta tarea, no bloqueante — Claude igual sabe cuándo pedir confirmación por la descripción semántica de cada tool.
- Config de identidad (ADR-008/009) y migración de DataServices a PostgreSQL siguen pendientes antes de poder dar de alta al primer cliente sobre la VM de GCP — cubierto por E7-INFRA-03 (Bloque 2, no ejecutado todavía).
- **Nota operativa (de E2-MCP-11, sigue vigente):** el deploy del `.car` de `ToolsAPIProject` es atómico — si `ALMDataService` (o cualquier otro `.dbs`) no puede conectar a su BD al momento del deploy, se revierte el CAR completo.
- La implementación de escritura MCP en Almacenes sigue bloqueada hasta que el PM confirme cómo resolver el aislamiento multi-tenant de `ALMDataService` (ver pregunta abierta #1 del relevamiento de Sprint 3) — posible tema de arquitectura (🔴).
