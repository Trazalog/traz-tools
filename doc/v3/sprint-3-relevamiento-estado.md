# Relevamiento de estado — Sprint 3 [E1-API-20]

**Tarea:** E1-API-20 — Relevamiento de estado para dimensionar el Sprint 3 (activación early adopter minero)
**Clase:** 🟢 (solo lectura + reporte)
**Fecha:** 2026-07-16
**Fuentes usadas:** `doc/api/inventory-2026.md` (Sprint 1), `doc/api/codeigniter-models-survey.md` (Sprint 1), artefactos reales en `_backend/api/ToolsAPIProject/`, `doc/mcp/*`, `doc/infra/*`, `doc/v3/TRAZALOG_v3_MCP_ARCHITECTURE.md`, `doc/v3/TRAZALOG_v3_CICD_STRATEGY.md`, GitHub issues.

> Este documento no repite el contenido de los relevamientos de Sprint 1 — los referencia y agrega el delta de qué se construyó realmente desde entonces (mayo→jul 2026) contrastando contra los artefactos WSO2 reales en git.

---

## 1. Frente Mantenimiento (Asset Planner)

Base: `codeigniter-models-survey.md` (15 modelos relevados) + estado real verificado hoy en `_backend/api/ToolsAPIProject/.../data-services/` y `apis/toolsMANAPI.xml`.

| Operación | Entidad | ¿Ya existe API WSO2? | ¿Ya es tool MCP? | Categoría |
|---|---|---|---|---|
| Listar equipos | Equipos | Sí (`MANEquiposDataService.getEquipos`, creado E1-API-04) | **Sí** — `get_equipos` | DataService SQL puro |
| Detalle de equipo | Equipos | Sí (`MANDataService.getEquipo`) | **Sí** — `get_equipo` | DataService SQL puro |
| Alta/edición/baja de equipo | Equipos | No (solo diseñado en el survey, no creado) | No | DataService SQL puro — falta virtualizar |
| Lookups de equipo (criticidad, grupo, sector, marca, etc.) | Equipos | No | No | DataService SQL puro — falta virtualizar |
| Componentes de equipo | Equipos | No | No | DataService SQL puro — falta virtualizar |
| Lecturas / parámetros de sensor | Equipos | No | No | DataService SQL puro (lectura) / Sequence (alta) |
| Listar OTs correctivas | OTs | Sí (`MANDataService.getSolicitudServcio`, vía `toolsMANAPI /mcp/ot`) | **Sí** — `get_ots` | DataService SQL puro |
| Detalle de OT | OTs | Sí (`toolsMANAPI /mcp/ot/{id}`) | **Sí** — `get_ot` | DataService SQL puro |
| Crear OT correctiva | OTs | Sí (`toolsMANAPI POST /mcp/ot`, orquesta BD + Bonita BPM, con rollback) | **Sí** — `create_ot` | Sequence de mediación |
| OTs programadas / externas (`Otrabajos.php`) | OTs | No — solo diseñado (`MANOrdenTrabajoDataService`, ~15 ops) | No | DataService SQL puro — API no creada |
| Ejecución de OT / asignación RRHH (`Ordenservicios.php`) | OTs | No | No | Mixto: DataService SQL + Sequence de mediación (validación de operarios) |
| Ciclo de vida / máquina de estados (`Tareas.php`) | OTs | No | No | Sequence de mediación |
| Calendario / planificación mensual | Planificación | No | No | Sequence de mediación (agregador de 4 DataServices) |
| Listar/crear preventivos | Preventivos | No — solo diseñado (`MANPreventivoDataService`, ~16 ops) | No | DataService SQL puro — API no creada |
| Predictivos (CRUD) | Predictivos | No | No | DataService SQL puro (CRUD) / Python Phase 2 (análisis de condición) |
| KPIs (Disponibilidad, MTTR, MTTF, fallas) | KPIs | **Sí, ya resuelto** — 6+ queries en `MANDataService.dbs` sobre `historial_lecturas_mem` | No | DataService SQL puro — **a un paso de ser tool MCP**, falta exponer resource en `toolsMANAPI` + generar tool |
| Stock / insumos Asset Planner (`Ordeninsumos.php`) | Stock AP | No — solo diseñado (`MANInsumoDataService`, ~6 ops) | No | DataService SQL puro (consulta) / Sequence (alta orden + reserva de lote) |
| Backlog | Backlog | No | No | Fuera de alcance Sprint 2/3 según survey |

### Qué está "a un paso" (API ya existe, falta virtualizar) vs qué requiere crear la API primero

**A un paso (bajo esfuerzo):**
- **KPIs de mantenimiento** (Disponibilidad, MTTR, MTTF, cantidad de fallas): el DataService ya calcula todo sobre `historial_lecturas_mem`. Falta únicamente: (1) agregar los recursos GET correspondientes a `toolsMANAPI.xml`, (2) publicar/actualizar la OpenAPI spec, (3) regenerar el Virtual MCP Server `trazalog-equipos` (o crear uno nuevo `trazalog-kpis`) con esas operaciones. No requiere nuevo DataService ni nueva lógica SQL.

**Requiere crear la API primero (esfuerzo medio-alto):**
- OTs programadas/externas, preventivos, insumos/stock AP y calendario: el `codeigniter-models-survey.md` ya diseñó los DataServices (`MANOrdenTrabajoDataService`, `MANPreventivoDataService`, `MANInsumoDataService`) y las sequences necesarias con nivel de detalle de query-por-query, pero **ninguno de los tres se creó todavía** — no existen como archivos `.dbs` en el repo. El diseño está completo; falta la implementación.

### Delta vs lo documentado en Sprint 1

Desde `inventory-2026.md` (jul-2026) se construyó: `MANEquiposDataService.dbs` (E1-API-04, solo `getEquipos` — no las ~18 ops que el survey proyectaba) y se extendió `toolsMANAPI.xml` con `/mcp/equipos`, `/mcp/equipo/{id}`, `/mcp/ot`, `/mcp/ot/{id}`. Esto cubrió las 5 tools MCP vigentes hoy.

> **Nota de discrepancia menor:** `doc/mcp/virtual-mcp-ots.md` tiene el header "Estado: Pendiente configuración en consola WSO2", pero `doc/mcp/demo-smoke-test.md` (2026-07-02) confirma las 5 tools funcionando end-to-end con OAuth real, incluyendo `create_ot`/`get_ots`/`get_ot`. El doc de virtual-mcp-ots.md quedó desactualizado — recomendación: actualizar su header en un PR de housekeeping (🟢, no bloquea Sprint 3).

---

## 2. Frente Almacenes (traz-comp-almacenes)

**Repo `traz-comp-almacenes`: NO está clonado localmente.** Se buscó en `/mnt/win/dev/git/` (mismo nivel que `traz-tools`) y no existe; tampoco hay ningún path que lo contenga. No se puede inspeccionar código PHP de ese módulo — todo lo que sigue se basa en el DataService WSO2 (`ALMDataService.dbs`, versionado en **este** repo, `traz-tools`) y en `LOGDataService.dbs` (logística de transporte, mismo módulo funcional).

Decisión de arquitectura vigente (ADR-004, en `TRAZALOG_v3_MCP_ARCHITECTURE.md` §14): la arquitectura dual de almacenes (Asset Planner ALM legacy vs `traz-comp-almacenes`) se mantiene para el MVP — **para inventario se usa `traz-comp-almacenes` / `ALMDataService`, no el almacén legacy de Asset Planner.** Esto es consistente con lo que indica la tarea.

| Operación | ¿Ya existe API WSO2? | ¿Ya es tool MCP? | Categoría |
|---|---|---|---|
| Consultar artículos / catálogo (`getArticulos`, `getArticulo`, `getArticulosXTipo`) | Sí — DataService directo (83 resources en `ALMDataService.dbs`) | No | DataService SQL puro |
| Consultar stock por artículo/depósito/lote (`getStock`, `getStockXArticuloYDeposito`, `getStockValorizado`, `getLote*`) | Sí | No | DataService SQL puro |
| Consultar establecimientos / depósitos | Sí | No | DataService SQL puro |
| Consultar movimientos históricos (`getHistoricoMovimientos`, `getMovimientosInternos`) | Sí | No | DataService SQL puro |
| **Registrar movimiento de stock entre depósitos** (`movimientoStock`, `setMovimientoInterno`) | Sí (escritura) | No | DataService SQL puro, requiere sequence de empr_id (ver riesgo abajo) |
| **Registrar ajuste de inventario** (`crearAjuste`, `crearDetalleAjuste`) | Sí (escritura) | No | DataService SQL puro, ídem |
| **Alta de artículo / lote** (`setArticulo`, `crearLote`, `setRecipiente`) | Sí (escritura) | No | DataService SQL puro, ídem |
| **Pedidos de materiales** (`setPedido`, `setDetallePedido`, `setNuevoPedido`) | Sí (escritura) | No | DataService SQL puro, ídem |
| Movimientos de transporte / logística (entradas, salidas, remitos — `LOGDataService`) | Sí (lectura + escritura, 21 queries) | No | DataService SQL puro |
| Wrapper REST de orquestación sobre `ALMDataService` (`toolsALMAPI`) | **No existe** | — | — |
| OpenAPI spec publicada para almacenes (`alm.yaml`) | **No existe** (`doc/api/` solo tiene `equipos.yaml` y `ot.yaml`) | — | — |

### Lectura vs escritura — distinción crítica pedida

**Lectura:** `ALMDataService` ya cubre con holgura todo lo necesario (artículos, stock, lotes, depósitos, movimientos históricos) — 80+ queries, activo en producción desde 2021, con multi-empresa/depósito/lote ya soportado en el modelo de datos.

**Escritura:** también existe a nivel de DataService (movimiento de stock, ajustes, altas de artículo/lote, pedidos) — **no hay que crear la lógica de negocio desde cero**, ya está implementada y en uso por el frontend PHP hoy. Lo que falta para exponerla como MCP de forma segura es la capa de virtualización (API + OpenAPI + Virtual MCP Server), igual que en Mantenimiento.

### ⚠️ Riesgo de seguridad encontrado (no presente en el inventario de Sprint 1)

`inventory-2026.md` §7 lista los DataServices restringidos para MCP por falta de filtro `empr_id`, y **`ALMDataService` no está en esa lista** — pero eso no significa que esté listo para MCP. Se verificó el código real de `ALMDataService.dbs` y:

- Las queries SÍ filtran correctamente por empresa a nivel SQL (`WHERE ... empr_id = :empr_id`, ya sin el hardcode `empr_id = 1` que tenía `getArticulos2`/`getArticulo` — remediado en E9-IDENT-06).
- **Pero `:empr_id` se recibe como parámetro directo del caller del DataService**, no derivado del JWT. La sequence `EmprIdFromHeader` (ADR-009, la que deriva `empr_id` del `X-JWT-Assertion` firmado por APIM) hoy **solo está referenciada en `toolsMANAPI.xml`** — no hay ninguna API ni sequence sobre `ALMDataService` que la use.
- Esto significa que, si se virtualiza `ALMDataService` directamente (sin pasar por una API/sequence que inyecte `empr_id` desde el JWT igual que en Mantenimiento), se viola la regla de oro del CONTEXT-PACK: *"el `empr_id` NUNCA es un parámetro que el agente pueda pasar."* Un agente MCP podría, en teoría, pasar el `empr_id` de otra empresa.
- **Esto es más grave en escritura que en lectura** — un `movimientoStock` o `crearAjuste` con `empr_id` arbitrario no solo lee datos de otra empresa, los modifica.

Este hallazgo no bloquea el relevamiento (tarea 🟢), pero sí debe bloquear cualquier virtualización directa de `ALMDataService` sin antes envolverla con el mismo patrón `EmprIdFromHeader` que protege a Mantenimiento. Ver sección de preguntas abiertas.

### Backlog relacionado ya existente en GitHub

- `#354` **E9-FUT-01** — Unificación de almacenes: Asset Planner ALM → `traz-comp-almacenes` (should-have, confirma que ADR-004 sigue vigente y la unificación es trabajo futuro, no de Sprint 3)
- `#356` **E9-FUT-03** — MCP Writes — tools de escritura (should-have, **no está en el alcance ya construido**; confirma que las tools de escritura, incluidas las de almacenes, son trabajo pendiente de diseño/implementación, no solo de virtualización)

---

## 3. Frente Despliegue Google Cloud

**Alcance: documental únicamente** (sin acceso a la infra real de GCP).

### Qué ya existe en el repo

| Artefacto | Ubicación | Alcance |
|---|---|---|
| Guía de instalación WSO2 APIM 4.6.0 | `doc/infra/wso2-install.md` | Solo **DEV, workstation local del PM**. Modo all-in-one, BD H2 embebida (no persistente, no apta para TEST/PROD). No cubre instalación en VM. |
| Setup de túnel ngrok | `doc/infra/ngrok-setup.md`, `scripts/dev/setup-ngrok.sh` | Workaround actual para exponer el gateway local a Claude.ai. Confirma explícitamente las limitaciones (URL efímera, 1 túnel, sin dominio fijo) que motivan pasar a una VM estable. |
| Flujo de testing en dos etapas | `doc/infra/testing-workflow.md` | MCP Inspector + Claude.ai/ngrok. No es infra de despliegue, es proceso de QA. |
| Dockerfiles por proyecto WSO2 | `_backend/api/*/*/deployment/docker/Dockerfile` (7 archivos) | **Auto-generados por el Maven Composite Exporter** de cada proyecto WSO2 (copian el `.car` a `carbonapps/` sobre una imagen base). Sirven para empaquetar un solo proyecto como imagen — no son una orquestación de stack completo. |
| Estrategia de deployment (diseño, no implementación) | `doc/v3/TRAZALOG_v3_CICD_STRATEGY.md` §4.4 y §11 | Define el stack objetivo: Docker + docker-compose (containerización), Ansible (config management, sin agentes), SigNoz (observabilidad), GitHub Actions (`v3-deploy-staging.yml`). Define el roadmap: ítem 10 "Setup VM staging-v3 en GCP (vía Ansible)", ítem 11 "workflow v3-deploy-staging.yml", ítem 12 "Setup SigNoz en staging-v3" — **todos listados como trabajo futuro, no ejecutado.** |

### Qué falta para levantar el stack completo en una VM

- **docker-compose.yml** (o equivalente) que orqueste WSO2 APIM + MI + BD (Postgres) — no existe ningún archivo `docker-compose*` en el repo.
- **Playbooks Ansible** — no existe ningún directorio ni archivo Ansible en el repo (`*.yml` bajo un path `ansible/`, `playbook*.yml`, `inventory.ini`, etc. — ninguno encontrado).
- **Workflows de CI/CD** — no existe `.github/workflows/` en el repo (directorio inexistente). El `v3-deploy-staging.yml` mencionado en la estrategia todavía no se creó.
- **Configuración de WSO2 para TEST/PROD** — `wso2-install.md` documenta explícitamente que la sección `[database.*]` con PostgreSQL "queda pendiente" (referencia a E0-INF-05) y que el certificado self-signed debe reemplazarse en TEST/PROD.
- **SigNoz** — mencionado solo como decisión de stack en la estrategia; cero artefactos de configuración en el repo.

### Conclusión del frente

Hoy el despliegue de WSO2 APIM+MI existe únicamente como procedimiento manual documentado para una workstation de desarrollador, más un túnel ngrok efímero para exponerlo a Claude.ai. No hay ningún artefacto reutilizable (IaC, contenedor orquestado, pipeline) para levantar el stack en una VM de Google Cloud — es un frente que arranca desde cero en términos de artefactos, aunque la decisión de stack tecnológico (Docker/Ansible/SigNoz/GitHub Actions) ya está tomada y documentada.

---

## 4. Resumen para el PM

| Frente | Qué ya existe | Qué falta | Esfuerzo estimado |
|---|---|---|---|
| **Mantenimiento** | 5 tools MCP funcionando end-to-end (verificado con OAuth real, `demo-smoke-test.md`). Diseño completo y detallado (query por query) para OTs programadas, preventivos, insumos/stock AP y calendario — ya está en `codeigniter-models-survey.md`, listo para implementar. KPIs ya calculados en el DataService, solo falta exponer. | Crear 3 DataServices nuevos (`MANOrdenTrabajoDataService`, `MANPreventivoDataService`, `MANInsumoDataService`) + sus sequences + extender `toolsMANAPI.xml` + nuevos Virtual MCP Servers. Exponer KPIs (bajo esfuerzo, casi gratis). | **Medio** — el diseño ya está resuelto, es implementación siguiendo un patrón ya probado (mismo que Equipos/OTs) |
| **Almacenes** | El DataService `ALMDataService` es el más completo del proyecto: lectura y escritura ya implementadas y en producción desde 2021 (artículos, stock, lotes, movimientos, ajustes, pedidos). No hay que diseñar la lógica de negocio. | Crear la capa de virtualización (OpenAPI spec + API/sequence wrapper que inyecte `empr_id` desde el JWT igual que en Mantenimiento — **ver riesgo de seguridad §2**) + Virtual MCP Server. La escritura requiere más cuidado que en Mantenimiento porque son operaciones más sensibles (modifican stock) y porque hoy `empr_id` llega como parámetro directo, no derivado del JWT. | **Medio-Grande** — no por falta de lógica de negocio, sino por el trabajo de seguridad/aislamiento multi-tenant que hay que resolver antes de exponer escritura como MCP |
| **Despliegue GCP** | La decisión de stack (Docker/Ansible/SigNoz/GitHub Actions) ya está tomada y documentada en la estrategia CI/CD. Existe un procedimiento probado de instalación de WSO2 APIM (aunque solo para DEV local). | Todo el trabajo de IaC: docker-compose, playbooks Ansible, workflow de CI/CD, configuración PostgreSQL para TEST/PROD, setup de SigNoz, y la VM de GCP en sí (fuera del alcance de este repo). | **Grande** — arranca de cero en artefactos, aunque no en decisiones de arquitectura |

---

## 5. Preguntas abiertas para el PM

1. **Riesgo de seguridad en almacenes (§2):** antes de virtualizar `ALMDataService` como MCP, ¿corresponde tratarlo igual que ADR-009 (empr_id derivado del `X-JWT-Assertion` vía una sequence tipo `EmprIdFromHeader`)? Esto no estaba señalado en `inventory-2026.md` §7 (que solo lista DataServices *sin* filtro de empresa) — `ALMDataService` sí filtra, pero confía en un parámetro que el caller controla. Clasifico esto como posible tema de arquitectura/seguridad (🔴) que requeriría confirmación antes de empezar a implementar cualquier tool MCP de escritura en almacenes.
2. **Repo `traz-comp-almacenes` no accesible:** no se pudo clonar ni inspeccionar localmente. Si hay lógica de negocio en PHP relevante (validaciones, reglas de negocio antes de escribir en `ALMDataService`) que no esté reflejada en el DataService mismo, este relevamiento no la cubre. ¿PM puede confirmar si esa lógica existe y si hay que migrarla a WSO2 (mismo patrón que ADR-003) antes de exponer escritura?
3. **Priorización entre frentes:** dado que Mantenimiento tiene diseño completo y probado, Almacenes tiene lógica de negocio lista pero un gap de seguridad a resolver, y Despliegue arranca de cero en artefactos — ¿cuál es el orden de prioridad real para Sprint 3? El documento no asume un orden.
4. **`doc/mcp/virtual-mcp-ots.md` desactualizado** (ver nota en §1) — ¿lo actualizo en un PR de housekeeping aparte, o se deja así porque no bloquea nada?
5. **Alcance de "escritura" en almacenes para el early adopter:** ¿el early adopter necesita las 4 operaciones de escritura relevadas (movimiento entre depósitos, ajuste, alta de artículo/lote, pedidos) o un subconjunto más chico para el piloto? Esto cambia bastante el esfuerzo de Sprint 3 si se puede acotar a, por ejemplo, solo `movimientoStock` + `crearAjuste`.

---

*Generado a partir de análisis estático de los artefactos versionados en git (WSO2 MI, docs de Sprint 1 y Sprint 2) y de `gh issue list`. No refleja necesariamente el estado desplegado en el server WSO2 si hubo cambios sin commitear.*
