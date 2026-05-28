# Inventario de artefactos WSO2 MI — Trazalog Tools v2 (git)

**Tarea:** E1-API-01  
**Fecha:** Mayo 2026  
**Fuente:** análisis estático de `_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/`  
**Nota:** este inventario refleja lo versionado en git, no lo desplegado en WSO2. Son la misma fuente de verdad, pero pueden divergir si hubo cambios en el server sin commit.

---

## 1. Resumen ejecutivo

| Tipo | Cantidad | Archivos |
|---|---|---|
| REST APIs (orchestration) | **4** | `apis/*.xml` |
| DataServices (capa de datos) | **19** | `data-services/*.dbs` |
| Sequences de mediación | **4** | `sequences/*.xml` |
| Templates | **1** | `templates/*.xml` |
| DataSources configurados | **2** | `data-sources/*.xml` |
| **Total artefactos** | **30** | |

**DataSources activos:**
- `ToolsDataSource` → PostgreSQL `tools_prod_t` @ `10.142.0.13:5432` (JNDI: `ToolsDatasourceJNDI`)
- `AssetPlannerDataSource` → MySQL `assetv2` @ `10.142.0.13:3306`
- ~~`produccionDS`~~ → **normalizado a `ToolsDataSource`** en [E1-API-11] (2026-05-28). Era el mismo datasource renombrado por copia entre ambientes. TARDataService y TareasSTD ya usan `ToolsDataSource`.
- `semaresiduosDS` → ⚠️ mismo caso. Base de datos de gestión de residuos, datasource externo al proyecto.

---

## 2. APIs REST

### 2.1 toolsCOREAPI

| Campo | Valor |
|---|---|
| Archivo | `apis/toolsCOREAPI.xml` |
| Context base | `/tools/core` |
| Módulo | CORE — gestión de empresas y usuarios |
| Autenticación | No (usa bpmSession como parámetro de payload) |

**Recursos:**

| Método | URI | Descripción |
|---|---|---|
| POST | `/empresa` | Alta de empresa: crea en PostgreSQL (CORE), MySQL (AssetPlanner) y Bonita BPM. Rollback transaccional si algún paso falla. |
| POST | `/usuario` | Alta de usuario: crea en PostgreSQL, Bonita BPM, AssetPlanner y `users_business`. Verifica duplicado antes de insertar. |
| POST | `/usuario/registro` | Registro libre de usuario (sin password, activa por token). Inserta en tabla `registro`. |
| POST | `/usuario/bpm-asset` | Completa usuario ya existente en BD y lo registra en BPM + AssetPlanner. Útil para el flujo de activación post-registro. |
| POST | `/rol/asignar` | Asigna rol a usuario: lookup en BD → lookup en BPM → inserta membership en BD → crea membership en Bonita. Rollback si falla BPM. |
| POST | `/rol/desasignar` | Des-asigna rol: elimina membership en BPM y en BD. |

**Observaciones:** API completamente funcional. Orquestación multi-sistema con rollback explícito. Usa sequences `toolsCreateRole`, `toolsBpmActorMembership`, `toolsBpmActorGrupo` para creación de roles por empresa. Registra 16 roles predeterminados por empresa (Almacén, Mantenimiento, SMA, etc.).

---

### 2.2 toolsbpmAPI

| Campo | Valor |
|---|---|
| Archivo | `apis/toolsBPMAPI.xml` |
| Context base | `/tools/bpm` |
| Módulo | CORE — proxy/facade sobre Bonita BPM |
| Autenticación | No (usa session como parámetro) |

**Recursos:**

| Método | URI | Descripción |
|---|---|---|
| POST | `/proceso/instancia` | Crea instancia de proceso BPM. Busca proceso por nombre, instancia, guarda case_id en CORE, rollback si falla. |
| DELETE | `/proceso/instancia` | Elimina instancia (caso) BPM por caseid. |
| GET | `/roles/{session}` | Lista roles Bonita paginados (query params `p`, `c`). |
| GET | `/role/porNombre/{session}` | Busca rol por nombre (query param `name`). |
| GET | `/groups/{session}` | Lista grupos Bonita (top 1000, ordenados por displayName). |
| POST | `/memberships` | Crea membership usuario/grupo/rol en Bonita. |
| POST | `/users` | Crea usuario en Bonita y lo habilita (PUT enable). |
| GET | `/users/{usr}/session/{session}` | Busca usuario por username en Bonita. |
| GET | `/memberships/xUserid/{usrid}/session/{session}` | Lista memberships de un usuario en Bonita. |
| DELETE | `/membership` | Elimina membership por user_id/group_id/role_id. |
| POST | `/group` | Crea grupo en Bonita. |
| POST | `/profileMember` | Agrega member a profile Bonita. |
| POST | `/role` | Crea rol en Bonita. |
| POST | `/actor/membership` | Mapea actor BPM a un rol+grupo (orquestación multi-paso). |
| POST | `/actor/rol` | Mapea actor BPM a un rol. |
| POST | `/actor/grupo` | Mapea actor BPM a un grupo. |

**Observaciones:** API completamente funcional. Es un proxy inteligente sobre la API REST de Bonita con gestión de sesión (cookie + X-Bonita-API-Token) vía `bpmAPICallTemplate`. 16 recursos. Toda la lógica de actor mapping está centralizada aquí.

---

### 2.3 toolsLogAPI

| Campo | Valor |
|---|---|
| Archivo | `apis/toolsLogAPI.xml` |
| Context base | `/tools/log` |
| Módulo | Residuos/LOG (traz-tools-resi, módulo SMA) |
| Autenticación | No |

**Recursos:**

| Método | URI | Descripción |
|---|---|---|
| POST | `/solicitudContenedores` | Crea solicitud de contenedores para residuos peligrosos: inserta en semaresiduosDS, procesa batch de tipos de carga, obtiene empresa del solicitante, recupera nicks de usuario/transportista, lanza proceso BPM TERSU-BPM01. Orquestación compleja con rollback. |

**Observaciones:** Un solo endpoint pero con orquestación muy compleja (600+ líneas). Usa semaresiduosDS + LOGDataService + BPM. Archivo de 27k tokens — el más grande del proyecto.

---

### 2.4 toolsMANAPI

| Campo | Valor |
|---|---|
| Archivo | `apis/toolsMANAPI.xml` |
| Context base | `/tools/man` |
| Módulo | Asset Planner / Mantenimiento |
| Autenticación | No (bpmSession como query param) |

**Recursos:**

| Método | URI | Descripción |
|---|---|---|
| POST | `/solicitudServicio?bpmSession={bpmSession}` | Crea solicitud de servicio (OT inicial): inserta en MANDataService, recupera sose_id, procesa batch de adjuntos, lanza proceso BPM "Proceso de Mantenimiento AssetPlanner SIM", guarda case_id. Rollback si falla BPM. |

**Observaciones:** Un solo endpoint, funcional. Es el punto de entrada para el flujo de mantenimiento correctivo. Crea la OT en AssetPlanner (MySQL assetv2) e instancia el proceso Bonita.

---

## 3. DataServices

> Los DataServices exponen endpoints REST directamente a `http://<host>:8280/services/<nombre>/`. Son la capa de datos cruda; las APIs de orquestación (sección 2) los consumen internamente.

### 3.1 ALMDataService

| Campo | Valor |
|---|---|
| BD | PostgreSQL `tools_prod_t` (ToolsDataSource) |
| Queries | 80 |
| Módulo | traz-comp-almacenes |

**Operaciones principales:**

| Nombre | Tipo | Descripción |
|---|---|---|
| getArticulos / getArticulo / getArticuloPorId | SELECT | Catálogo de artículos del almacén |
| getEstablecimiento / getEstablecimeintosXEmpresa | SELECT | Establecimientos por empresa |
| getDepositosEstablecimiento | SELECT | Depósitos por establecimiento |
| getLote | SELECT | Lotes activos |
| getPedido / getDetallePedido / getPedidoXBatch | SELECT | Consulta de pedidos de materiales |
| setPedido / setDetallePedido / setNuevoPedido | INSERT | Creación de pedidos |
| setNotaPedido / setOrigenPedido | INSERT | Notas y origen de pedido |
| movimientoStock | INSERT | Movimiento de stock entre depósitos |
| getContenidoRecipiente | SELECT | Contenido de recipientes |
| getRecipientesDepositoEstablecimiento / getAllRecipientes | SELECT | Recipientes disponibles |
| setRecipiente / setRecipienteConMotrId / updateRecipiente / deleteRecipiente | INSERT/UPDATE/DELETE | CRUD recipientes |
| crearLote / extraerCantidadLote | INSERT/UPDATE | Gestión de lotes |
| crearAjuste / getTiposAjustes | INSERT/SELECT | Ajustes de inventario |
| getPedidosTareas / setPedidoTarea | SELECT/INSERT | Pedidos asociados a tareas |
| setEstablecimiento / delEstablecimiento | INSERT/DELETE | CRUD establecimientos |

**Tablas principales:** `articulos`, `pedido_materiales`, `detalle_pedido`, `nota_pedido`, `movimiento_stock`, `establecimientos`, `depositos`, `recipientes`, `lotes`, `ajustes`

---

### 3.2 COREDataService

| Campo | Valor |
|---|---|
| BD | PostgreSQL `tools_prod_t` (ToolsDataSource) |
| Queries | 89 |
| Módulo | CORE — usuarios, empresa, configuración |

**Operaciones principales:**

| Nombre | Tipo | Descripción |
|---|---|---|
| getMenuByUserPermission | SELECT | Menú filtrado por permisos de usuario |
| setParametro / getParametros | INSERT/SELECT | Parámetros de configuración por empresa |
| setSnapshot / getSnapshot / delSnapshot | INSERT/SELECT/DELETE | Snapshots del sistema |
| getUsers / getUsersXGroup | SELECT | Usuarios del sistema |
| setTabla / getTabla / getTablaXEmpresa | INSERT/SELECT | Tablas de configuración |
| setCliente / updateCliente / deleteCliente / getCliente | CRUD | Gestión de clientes |
| setCaseEmpresa | INSERT | Asocia case BPM a empresa |
| setEstablecimiento / updateEstablecimiento / deleteEstablecimiento / getEstablecimientos | CRUD | Establecimientos |
| setDepositoPorEstablecimiento / deleteDeposito | INSERT/DELETE | Depósitos |
| setTransportista / updateTransportista / deleteTransportista | CRUD | Transportistas |
| getEmpresas | SELECT | Lista de empresas |
| getEnvasesXEmpresa / setEnvase | SELECT/INSERT | Envases por empresa |
| getEquiposXSector | SELECT | Equipos por sector (cross-module a AssetPlanner) |
| getLocalidades / getPaises / getEstados | SELECT | Tablas geográficas |
| validaBPMCaseYEmpr | SELECT | Valida que case BPM pertenece a empresa |
| _post_empresa / _post_empresa_asset / _delete_empresa | INSERT/DELETE | CRUD interno de empresa (dual DB) |
| _post_usuario / _delete_usuario | INSERT/DELETE | CRUD usuario |
| _post_membership / membership/delete | INSERT/DELETE | Memberships |

**Tablas principales:** `usuarios`, `empresas`, `establecimientos`, `depositos`, `clientes`, `transportistas`, `membership`, `parametros`, `tablas`, `snapshots`, `envases`

---

### 3.3 FRMDataService

| Campo | Valor |
|---|---|
| BD | PostgreSQL `tools_prod_t` (ToolsDataSource) |
| Queries | 5 |
| Módulo | traz-comp-formularios |

**Operaciones:** `getFormularios`, `getFormulario`, `getItemsFormulario`, `getvalvalidos`, `getVariablesXOrigen` — todas SELECT, CRUD de definición de formularios dinámicos.

**Tablas principales:** `formularios`, `items_formulario`, `valores_validos`, `variables_formulario`

---

### 3.4 LOGDataService

| Campo | Valor |
|---|---|
| BD | PostgreSQL `tools_prod_t` (ToolsDataSource) |
| Queries | 22 |
| Módulo | Logística de transporte (traz-comp-almacenes / LOG) |

**Operaciones principales:**

| Nombre | Tipo |
|---|---|
| getMovimientosTransporte / getMovimientoTransporte | SELECT |
| getArticulosMovimientoTransporte | SELECT |
| setEntradaXReci / setEntrada | INSERT |
| getCamionEstablecimiento / getLotesCamion | SELECT |
| getTransportistas | SELECT |
| setCamionEstado / getSalidaCamion | UPDATE/SELECT |
| setRemito / setDetalleRemito | INSERT |
| getSotrEmprId / getSolicitudContenedorNicks / getSolicitudRetiroNicks / getOrdenTransporteNicks | SELECT |
| getIngresosMovimientoTransporte / getCantidadIngresosMovimientoTransporte / getSalidasMovimientoTransporte | SELECT |
| updateProveedor | UPDATE |

**Tablas principales:** `movimientos_transporte`, `articulos_movimiento`, `camion`, `transportistas`, `remitos`, `detalle_remito`

---

### 3.5 MANDataService

| Campo | Valor |
|---|---|
| BD | MySQL `assetv2` (AssetPlannerDataSource) |
| Queries | 24 |
| Módulo | Asset Planner — mantenimiento |

**Operaciones principales:**

| Nombre | Tipo | Descripción |
|---|---|---|
| getKPIDisponibiidadPorFecha / getKPIDisponibiidadPorFechaPorEquipo | SELECT | KPI Disponibilidad por período |
| getKPIMttrporFecha / getKPIMttrporFechaxEquipo | SELECT | KPI MTTR por período |
| getKPIMttfporFecha / getKPIMttfporFechaporEquipo | SELECT | KPI MTTF por período |
| getTiempoTotal / getTiempoTotalReparacion / getTiempoTotalReparacionxEquipo | SELECT | Tiempos de mantenimiento |
| getCantidadFallos / getCantidadFallosxEquipo | SELECT | Conteo de fallas |
| getCantidadEquiposxEmpresa / getCantEquiposxEmpresaxSectorxGrupo | SELECT | Cantidad de equipos |
| getEstadoEquipo | SELECT | Estado actual de equipo |
| getFechaAltaEquipo | SELECT | Fecha de alta de equipo |
| getSolicitudServicio / getLastsolicitudServicio | SELECT | Consulta OTs |
| setsolicitudServicio | INSERT | Crear solicitud de servicio (OT) |
| putSolicitudServicioCase | UPDATE | Actualizar case_id BPM en OT |
| deleteSolicitudServicio | DELETE | Eliminar OT |
| getEquipo | SELECT | Datos de equipo individual |
| getNotificaciones | SELECT | Notificaciones de mantenimiento |
| setAdjuntosSolReparacion / getAdjuntosSolReparacion | INSERT/SELECT | Adjuntos de OT |

**Tablas principales (assetv2):** `solicitud_reparacion`, `equipos`, `notificaciones`, `adjuntos_sol_reparacion`

---

### 3.6 PANDataservice

| Campo | Valor |
|---|---|
| BD | PostgreSQL `tools_prod_t` (ToolsDataSource) |
| Queries | 30 |
| Módulo | traz-comp-panol (pañol / tool crib) |

**Operaciones principales:** CRUD completo de pañoles (`panolSet/Get/Update/Delete`), herramientas (`herramientasSet/Get/Update/Delete`), salidas y entradas de herramientas, estados, estanterías, componentes de equipos, asignación de encargados.

**Tablas principales:** `panol`, `herramientas`, `salida_herramientas`, `entrada_herramientas`, `estanterias`, `componentes_equipo`

---

### 3.7 PINGDataService

| Campo | Valor |
|---|---|
| BD | PostgreSQL `tools_prod_t` (ToolsDataSource) |
| Queries | 1 |
| Módulo | CORE — health check |

**Operación:** `getStatus` (SELECT) → retorna `{"respuesta": "ALIVE"}`. Usado para monitoreo.

---

### 3.8 PRDDataService

| Campo | Valor |
|---|---|
| BD | PostgreSQL `tools_prod_t` (ToolsDataSource) |
| Queries | 96 |
| Módulo | traz-prod-trazasoft — Producción |

Superconjunto de operaciones de producción. Incluye toda la operatoria de `ProduccionDataService` más queries adicionales. Ver sección 3.14 para detalle.

---

### 3.9 PRDEtapaDataService

| Campo | Valor |
|---|---|
| BD | PostgreSQL `tools_prod_t` (ToolsDataSource) |
| Queries | 49 |
| Módulo | traz-prod-trazasoft — Etapas de producción |

**Operaciones principales:** Gestión de etapas productivas: `getEtapa`, `getEtapaPorId`, `setEtapaProductiva`, `updateEtapaProductiva`, `deleteEtapa`, `getEtapasProductivas`, `getEtapasEntrada`, `getEtapasSalida`, `etapaEntradaSet/Delete`, `setEstadoEtapa`, gestión de fórmulas (`formulasSet`, `formulasArticulosSet`, `getFormulas`, `getRecetaFormula`), turnos de producción, recipientes.

**Tablas principales:** `etapas_productivas`, `etapa_entrada`, `etapa_salida`, `formulas`, `formula_articulos`, `turnos_produccion`

---

### 3.10 PRDLoteDataService

| Campo | Valor |
|---|---|
| BD | PostgreSQL `tools_prod_t` (ToolsDataSource) |
| Queries | 29 |
| Módulo | traz-prod-trazasoft — Lotes de producción |

**Operaciones principales:** `loteSetV2` (INSERT lote), `ingresarLote`, `cambiarLote`, `getExistencia`, `setRecursoLote`, `getRecursoLoteBatchTipo`, `deleteRecursosLote`, `getLotes`, `getLote2`, `getLoteXCodigo`, `setUserLote/getUserLote/deleteUserLote`, `trazabilidadBatch`, `getLotesEstablecimientoStock`, `verificaEntregaMateriales`, `getLotesxEtapa`.

**Tablas principales:** `lotes`, `recursos_lote`, `lote_usuario`, `existencias`

---

### 3.11 PRDNoConsumiblesDataService

| Campo | Valor |
|---|---|
| BD | PostgreSQL `tools_prod_t` (ToolsDataSource) |
| Queries | 14 |
| Módulo | traz-prod-trazasoft — No consumibles |

**Operaciones:** CRUD completo de no-consumibles, trazabilidad, cambio de estado, asociación a lotes.

---

### 3.12 PRODataService

| Campo | Valor |
|---|---|
| BD | PostgreSQL `tools_prod_t` (ToolsDataSource) |
| Queries | 20 |
| Módulo | traz-comp-bpm — Pedidos de trabajo / Procesos |

**Operaciones principales:** `setPedidoTrabajo` (INSERT), `deletePedidoTrabajo`, `updatePedidoTrabajoCaseId`, `getProcesos`, `getPedidosTrabajo`, `updateEstadoPedido`, `getinfopedidotrabajo`, `getPedidosTrabajoNoFinalizado`, `getPedidosTrabajoPaginados/Finalizados` (SELECT paginado), `setFormTaskPedidoTrabajo`.

**Tablas principales:** `pedido_trabajo`, `procesos`

---

### 3.13 ProduccionDataService

| Campo | Valor |
|---|---|
| BD | PostgreSQL `tools_prod_t` (ToolsDataSource) |
| Queries | 32 |
| Módulo | traz-prod-trazasoft — Producción (subconjunto) |

Subconjunto de PRDDataService. Incluye: `getEstablecimiento`, `getLote`, `getEtapa`, `getArticulos`, `getProveedores`, `setEntrada`, `setNotaPedido`, `setRecursoLote`, `getEtapaProducto`, `getEtapasMateriales`, `getinfoPedMatPorCaseId`.

---

### 3.14 QRDataService

| Campo | Valor |
|---|---|
| BD | PostgreSQL `tools_prod_t` (ToolsDataSource) |
| Queries | 3 |
| Módulo | traz-comp-codigos — Códigos QR |

**Operaciones:** `setToken` (INSERT), `getToken` (SELECT), `getUrls` (SELECT). Manejo de tokens de seguridad para URLs con QR.

---

### 3.15 semaresiduosDS

| Campo | Valor |
|---|---|
| BD | Datasource externo `semaresiduosDS` (⚠️ no en data-sources/) |
| Queries | 159 |
| Módulo | traz-tools-resi — Residuos peligrosos (SMA) |

DataService más grande del proyecto. Cubre toda la operatoria del módulo SMA: transportistas, choferes, vehículos, contenedores, circuitos, zonas, departamentos, puntos críticos, solicitantes de transporte, órdenes de transporte.

---

### 3.16 semaresiduosDS2

| Campo | Valor |
|---|---|
| BD | Datasource externo `semaresiduosDS` (mismo que semaresiduosDS) |
| Queries | 30 |
| Módulo | traz-tools-resi — Residuos (supplemento) |

Complemento de semaresiduosDS: consultores, validaciones de registro, incidencias, órdenes de transporte filtradas.

---

### 3.17 TARDataService

| Campo | Valor |
|---|---|
| BD | PostgreSQL `tools_prod_t` (ToolsDataSource) — normalizado desde `produccionDS` en E1-API-11 |
| Queries | 41 |
| Módulo | traz-comp-tareas-estandar — Tareas planificadas |

**Operaciones principales:** CRUD completo de tareas, subtareas, plantillas de tarea, tareas planificadas, recursos de tareas, hitos, KPI básico, sectores, equipos por sector, estado de tarea, eventos de tarea, `getTareaPlanificadaXCaseId`.

**Tablas principales:** `tareas`, `subtareas`, `plantillas`, `tareas_planificadas`, `recursos_tarea`, `hitos`

---

### 3.18 TareasSTD

| Campo | Valor |
|---|---|
| BD | PostgreSQL `tools_prod_t` (ToolsDataSource) — normalizado desde `produccionDS` en E1-API-11 |
| Queries | 30 |
| Módulo | traz-comp-tareas-estandar — Tareas estándar |

Subconjunto de TARDataService. Mismas tablas. Posible refactoring pendiente — queries duplicados.

---

### 3.19 TrazabilidadDataService

| Campo | Valor |
|---|---|
| BD | PostgreSQL `tools_prod_t` (ToolsDataSource) |
| Queries | 15 |
| Módulo | traz-prod-trazasoft — Trazabilidad de lotes |

**Operaciones:** `loteSet`, `loteSetV2`, `ingresarLote`, `cambiarLote/2`, `getExistencia`, `getBatchidPorRecipiente`, `getMovimientosTransporte`, `getProduccion`, `getProduccionPorRecurso`, `getProductos`, `getAllEtapas`, `getRecursos`.

---

## 4. Sequences de mediación

| Nombre | Tipo | Descripción |
|---|---|---|
| `toolsBpmActorGrupo` | Helper | Mapea actor de proceso BPM a un grupo. Invoca `POST /bpm/actor/grupo`. Usado por toolsCOREAPI durante alta de empresa (actor sin rol, solo grupo). |
| `toolsBpmActorMembership` | Helper | Mapea actor de proceso BPM a un rol+grupo. Invoca `POST /bpm/actor/membership`. Usado masivamente en alta de empresa (16 llamadas). |
| `toolsCreateRole` | Helper | Crea un rol en Bonita BPM con prefijo `{empr_id}-{role_name}`. Invoca `POST /bpm/role`. Usado 16 veces durante alta de empresa. |
| `toolsFault` | Global error handler | Centraliza manejo de errores. Retorna `{"respuesta": {"codigo": "1000", "error":"...", "detalle":"..."}}` con HTTP 404. Captura payload para debug. Usada por todas las APIs y sequences. |

### Template: bpmAPICallTemplate

Template reutilizable para cualquier llamada a Bonita BPM. Parámetros: `recurso`, `session`, `payload`, `method`. Características:
- Gestión de cookie `JSESSIONID` + header `X-Bonita-API-Token`
- **Auto-refresh de sesión en 401**: hace login automático y reintenta la llamada
- Manejo de `AlreadyExistsException` (409 Bonita): recupera el usuario/entidad existente y devuelve 200
- Soporta GET, POST, PUT, DELETE

---

## 5. Gap analysis vs MCP MVP (Sprint 2)

El catálogo MCP MVP para Sprint 2 requiere 6 herramientas MCP: **Equipos, OTs, Preventivos, KPIs, Stock AP, Stock Almacenes**.

### Estado actual de cobertura

| Herramienta MCP | Necesidad | ¿Existe API REST? | ¿Existe DataService? | Cobertura |
|---|---|---|---|---|
| `get_equipos` | Listar/buscar equipos por empresa | ❌ No hay toolsMANAPI para equipos | ✅ `MANDataService.getEquipo` (1 equipo por id) | **Parcial** — solo GET by ID, no list |
| `get_ots` | Listar OTs por equipo/empresa/estado | ❌ No hay endpoint de listado | ✅ `MANDataService.getSolicitudServicio` | **Parcial** — DataService existe, sin API |
| `create_ot` | Crear OT (solicitud de servicio) | ✅ `toolsMANAPI POST /solicitudServicio` | ✅ `MANDataService.setsolicitudServicio` | **Cubierto** ✅ |
| `get_preventivos` | Listar tareas planificadas | ❌ No existe toolsTARAPI | ✅ `TARDataService.getTareasPlanificadas` | **Parcial** — DataService existe, sin API |
| `create_preventivo` | Crear tarea planificada | ❌ No existe toolsTARAPI | ✅ `TARDataService.setTareaPlanificada` | **Parcial** — DataService existe, sin API |
| `get_kpis` | KPI Disponibilidad, MTTR, MTTF | ❌ No existe toolsKPIAPI | ✅ `MANDataService` (6 queries KPI) | **Parcial** — datos listos, sin API |
| `get_stock_ap` | Stock de materiales Asset Planner | ❌ No existe API | ✅ `ALMDataService.extraerCantidadLote`, `getArticulos` | **Parcial** — operaciones existen en DBS |
| `get_stock_almacenes` | Stock en depósitos de almacenes | ❌ No existe toolsALMAPI | ✅ `ALMDataService.movimientoStock`, `getLote`, `getArticulos` (80 queries) | **Parcial** — DBS muy completo, sin API |

### Síntesis del gap

**Lo que existe y funciona:**
- Alta de OT (`toolsMANAPI`) → puede virtualizarse directo como MCP tool `create_ot`
- KPIs en `MANDataService` → datos listos, faltan endpoints REST de orquestación
- ALMDataService → DBS completo para stock, falta API REST encima

**Lo que NO existe y hay que crear desde cero:**
- `toolsMANEquiposAPI` o endpoint GET `/equipos` — no hay forma de listar equipos via REST API; solo hay `getEquipo` by ID en el DBS
- `toolsTARAPI` — ningún endpoint REST sobre tareas planificadas; TARDataService existe pero no tiene API de orquestación
- `toolsKPIAPI` — los 6+ KPIs de MANDataService son accesibles como DataService directo pero sin API REST diseñada para MCP
- `toolsALMAPI` — ALMDataService es el DBS más completo del proyecto (80 queries) pero sin API REST encima

**Datasources pendientes de resolver:**
- ~~`produccionDS`~~ → **resuelto en E1-API-11 (2026-05-28)**: normalizado a `ToolsDataSource` en TARDataService, TareasSTD y ProduccionDataService. Riesgo de deploy eliminado.

---

## 6. Recomendación de priorización para Sprint 2

Ordenado por impacto MCP MVP vs esfuerzo de implementación:

### Prioridad 1 — Virtualización directa (bajo esfuerzo, alto impacto)

**`toolsMANAPI` ya es virtualizable** como MCP tool `create_ot`. El DataService `MANDataService` cubre `getEquipo`, `getSolicitudServicio` y todos los KPIs. Con un API thin de orquestación mínima se puede exponer:

1. **Crear `toolsMANAPI v2`** (extensión del existente): agregar recursos GET para equipos, OTs y KPIs. Estimado: 3-5 días. Cubre `get_equipos` (parcial), `get_ots`, `get_kpis`, `create_ot`.

### Prioridad 2 — Crear API nueva sobre DBS existente (esfuerzo medio)

2. **Crear `toolsALMAPI`**: wrapper REST sobre ALMDataService. El DBS ya tiene todo: artículos, stock, lotes, movimientos. Cubre `get_stock_ap` y `get_stock_almacenes`. Estimado: 4-6 días.

### Prioridad 3 — Crear API nueva + resolver datasource faltante (mayor esfuerzo)

3. **Crear `toolsTARAPI`**: wrapper REST sobre TARDataService. ~~Prerequisito: resolver `produccionDS`~~ → resuelto en E1-API-11. Cubre `get_preventivos` y `create_preventivo`. Estimado: 3-4 días.

### Deuda técnica identificada

| Item | Riesgo | Acción recomendada |
|---|---|---|
| ~~`produccionDS` no versionado en git~~ | ~~Alto~~ → **Resuelto** | Normalizado a `ToolsDataSource` en E1-API-11 (2026-05-28) |
| `semaresiduosDS` (datasource externo) | Medio — mismo problema | Ídem |
| TARDataService y TareasSTD duplicados (70% overlap) | Bajo — confusión | Consolidar en un único DBS en v3 |
| ProduccionDataService y PRDDataService overlap | Bajo | Consolidar en v3 |
| Credentials en texto plano en data-sources XML | **Alto — seguridad** | Migrar a WSO2 Secure Vault antes de v3 production |

---

*Generado automáticamente por análisis estático. Para preguntas sobre la arquitectura, ver `doc/v3/TRAZALOG_v3_MCP_ARCHITECTURE.md`.*
