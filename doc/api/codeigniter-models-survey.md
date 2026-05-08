# Relevamiento de Modelos CodeIgniter — Asset Planner

**Repo fuente:** `/mnt/win/dev/git/traz-prod-assetplanner/` (rama `develop`)
**Fecha:** 2026-05-08
**Sprint de referencia:** MCP MVP Sprint 2
**Tarea:** E1-API-02

---

## Objetivo

Mapear los modelos PHP (CodeIgniter 3) del módulo Asset Planner a:
1. Los query SQL que exponen (tablas, joins, filtros)
2. La categoría de implementación v3:
   - **DataService SQL puro** → migrar como operación DBS en WSO2 MI
   - **Sequence de mediación** → requiere orquestación multi-paso en WSO2 MI
   - **Python Phase 2** → lógica de negocio compleja, ML o cálculos estadísticos; difieren a la capa Python

---

## Resumen ejecutivo

| Entidad | Modelo | Líneas | Tablas principales | Sprint 2 |
|---------|--------|--------|--------------------|----------|
| Equipos | `Equipos.php` | 1 824 | `equipos`, `sector`, `grupo`, `criticidad` | `get_equipos` ✅ |
| OTs | `Sservicios.php` | 580 | `solicitud_reparacion`, `orden_trabajo` | `get_ots`, `create_ot` ✅ |
| Preventivos | `Preventivos.php` | 838 | `preventivo`, `tareas`, `periodo` | `get_preventivos`, `create_preventivo` ✅ |
| Predictivos | `Predictivos.php` | 297 | `predictivo` | Fase 2 |
| Lecturas | `Lecturas.php` | 212 | `historial_lecturas`, `parametroequipo` | `get_kpis` (insumo) |
| Historial / KPIs | `Kpis.php` | 478 | `orden_trabajo`, `historial_lecturas` | `get_kpis` ✅ |
| Consumo materiales | `Ordeninsumos.php` | ~400 | `orden_insumos`, `deta_ordeninsumos`, `articles` | `get_stock_ap` ✅ |
| Backlogs | `Backlogs.php` | 279 | `tbl_back`, `componenteequipo` | Fase 2 |

---

## Detalle por entidad

### 1. Equipos

**Modelo:** `application/models/Equipos.php` (1 824 líneas)

#### Métodos relevantes

| Método | Descripción | Tablas |
|--------|-------------|--------|
| `equipos_List()` | Lista completa con joins de catálogos + última lectura | `equipos`, `sector`, `empresas`, `unidad_industrial`, `criticidad`, `area`, `grupo`, `proceso`, `admcustomers`, `historial_lecturas` |
| `getpencil($id)` | Detalle de un equipo (edición) | `equipos` + catálogos |
| `getdatosfichas($id)` | Datos completos para ficha técnica | ídem |
| `insert_equipo($data)` | Alta de equipo | `equipos` |
| `update_cambio($data, $idequipo)` | Modificación de atributos | `equipos` |
| `update_estado($idequipo)` | Cambio de estado (activo/baja) | `equipos` |
| `baja_equipos($data, $idequipo)` | Baja lógica | `equipos` |
| `getcriti()` | Lookup criticidades | `criticidad` |
| `getgrupos()` | Lookup grupos | `grupo` |
| `getprocesos()` | Lookup procesos | `proceso` |
| `getsector()` | Lookup sectores | `sector` |
| `getunidads()` | Lookup unidades industriales | `unidad_industrial` |
| `getmarcas()` | Lookup marcas | `marcas` |
| `agregar_*()` | INSERTs de entidades relacionadas | varias |

#### Categorización v3

| Operación MCP | Método(s) origen | Categoría | Notas |
|---------------|-----------------|-----------|-------|
| `get_equipos` | `equipos_List()` | **DataService SQL puro** | JOIN estático, sin lógica de negocio |
| `get_equipo/{id}` | `getpencil()` / `getdatosfichas()` | **DataService SQL puro** | Query por PK con joins |
| `create_equipo` | `insert_equipo()` | **DataService SQL puro** | INSERT simple |
| `update_equipo` | `update_cambio()` | **DataService SQL puro** | UPDATE por PK |
| `delete_equipo` | `baja_equipos()` | **DataService SQL puro** | Soft delete |

---

### 2. OTs (Órdenes de Trabajo)

**Modelo:** `application/models/Sservicios.php` (580 líneas)

Las OTs tienen dos tablas centrales:
- `solicitud_reparacion` — solicitud inicial (case BPM)
- `orden_trabajo` — orden técnica generada a partir de la solicitud

#### Métodos relevantes

| Método | Descripción | Tablas |
|--------|-------------|--------|
| `getServiciosList($showConformes)` | Lista de OTs con estado conformidad | `solicitud_reparacion`, `equipos`, `sector`, `grupo`, `orden_trabajo`, `sisusers` |
| `solicitudespaginadas($start, $length, $search, $ordering, $showConformes)` | Lista paginada + subquery última OT por `case_id` | ídem |
| `setservicios($data)` | Alta de solicitud | `solicitud_reparacion` |
| `setCaseId($caseId, $id_solServicio)` | Vincula caso BPM a solicitud | `solicitud_reparacion` |
| `activSolicitudes($data)` | Transición de estado → activa | `solicitud_reparacion` |
| `confSolicitudes($data)` | Transición de estado → conforme | `solicitud_reparacion` |
| `eliminar_solicitud($id, $id_usuario, $motivo)` | Baja lógica de solicitud | `solicitud_reparacion` |
| `eliminar_orden_trabajo($id, $id_usuario, $motivo)` | Baja lógica de OT | `orden_trabajo` |
| `get_SolicTerminadas()` | OTs cerradas (para KPIs) | `solicitud_reparacion`, `orden_trabajo` |

#### Métodos en `Tareas.php` (1 322 líneas) — ciclo de vida OT

| Método | Descripción | Tablas |
|--------|-------------|--------|
| `cambiarEstado($id_solicitud, $estado, $tipo)` | Máquina de estados OT | `orden_trabajo`, `tbl_listarea` |
| `inicioTareas($id_OT)` | Registra timestamp de inicio | `orden_trabajo` |
| `finTareas($id_OT)` | Registra timestamp de fin | `orden_trabajo` |
| `getSubtareas($ot)` | Subtareas/checklist de una OT | `asp_subtareas`, `tareas` |
| `setUltimaLecturaIS($data)` | INSERT lectura al cerrar OT | `historial_lecturas` |
| `terminarTareaStandarenBPM($idTarBonita, $param)` | Completa tarea Bonita | BPM API (externo) |
| `validarCamposObligatorios($idForm, $idOT)` | Valida formularios obligatorios | `frm_formularios_completados`, `frm_instancias_formulario` |

#### Categorización v3

| Operación MCP | Método(s) origen | Categoría | Notas |
|---------------|-----------------|-----------|-------|
| `get_ots` | `getServiciosList()` | **DataService SQL puro** | JOIN multi-tabla, sin cálculos |
| `get_ots` (paginado) | `solicitudespaginadas()` | **DataService SQL puro** | Subquery soportada en DBS |
| `create_ot` | `setservicios()` + `setCaseId()` | **Sequence de mediación** | INSERT solicitud → crear caso BPM → guardar case_id |
| Cambio de estado | `cambiarEstado()` | **Sequence de mediación** | Validación + UPDATE + notificación BPM |
| Cierre con formulario | `finTareas()` + `validarCamposObligatorios()` | **Sequence de mediación** | Multi-paso con validación |

---

### 3. Preventivos

**Modelo:** `application/models/Preventivos.php` (838 líneas)

#### Métodos relevantes

| Método | Descripción | Tablas |
|--------|-------------|--------|
| `preventivos_List()` | Lista completa de PMs | `preventivo`, `equipos`, `grupo`, `tareas`, `componentes`, `periodo` |
| `getInfoPreventivo($id)` | Detalle de un PM | ídem |
| `getPreventivoHerramientas($id)` | Herramientas asignadas al PM | `tbl_preventivoherramientas` |
| `getPreventivoInsumos($id)` | Insumos/materiales del PM | `tbl_preventivoinsumos` |
| `insert_preventivo($data)` | Alta de PM | `preventivo` |
| `update_preventivo($data, $idprev)` | Actualización de PM | `preventivo` |
| `update_editar($data, $idp)` | Edición extendida (con herramientas/insumos) | `preventivo`, `tbl_preventivoherramientas`, `tbl_preventivoinsumos` |
| `getPreventivosPorHora()` | PMs disparados por horas de uso | `preventivo`, `equipos.ultima_lectura` |
| `revisaEstadoPreventivosPorHoras($preventivos)` | Evalúa si umbral de horas fue superado | `historial_lecturas` |
| `getLecturaActual($id_equipo)` | Lectura actual para PM por horas | `historial_lecturas` |

#### Categorización v3

| Operación MCP | Método(s) origen | Categoría | Notas |
|---------------|-----------------|-----------|-------|
| `get_preventivos` | `preventivos_List()` | **DataService SQL puro** | JOIN estático |
| `get_preventivo/{id}` | `getInfoPreventivo()` + `getHerramientas()` + `getInsumos()` | **Sequence de mediación** | 3 queries enlazadas por `id` |
| `create_preventivo` | `insert_preventivo()` | **DataService SQL puro** | INSERT directo |
| `update_preventivo` | `update_editar()` | **Sequence de mediación** | UPDATE + DELETE/INSERT de herramientas e insumos |
| PMs por horas | `getPreventivosPorHora()` + `revisaEstado...()` | **Python Phase 2** | Lógica de evaluación de umbrales con historial de lecturas |

---

### 4. Predictivos

**Modelo:** `application/models/Predictivos.php` (297 líneas)

#### Tablas principales

`predictivo`, `tbl_predictivoherramientas`, `tbl_predictivoinsumos`, `equipos`, `tareas`, `componentes`

#### Métodos relevantes (estructura similar a Preventivos)

| Método | Descripción |
|--------|-------------|
| `predictivos_List()` | Lista completa |
| `getInfoPredictivo($id)` | Detalle de un PdM |
| `getPredictivoHerramientas($id)` | Herramientas |
| `getPredictivoInsumos($id)` | Insumos |
| `insert_predictivo($data)` | Alta |
| `update_predictivo($data, $id)` | Actualización |

#### Categorización v3

| Operación | Categoría | Notas |
|-----------|-----------|-------|
| CRUD básico | **DataService SQL puro** | Misma estructura que Preventivos |
| Análisis predictivo / alarmas | **Python Phase 2** | Requiere modelos de ML; fuera de Sprint 2 |

---

### 5. Lecturas (Sensores / Horómetros)

**Modelo:** `application/models/Lecturas.php` (212 líneas)

#### Tablas principales

`historial_lecturas`, `parametroequipo`, `setupparam`, `parametros`

#### Métodos relevantes

| Método | Descripción | Tablas |
|--------|-------------|--------|
| `getLecturasEquipo($id_equipo)` | Historial de lecturas de un equipo | `historial_lecturas` |
| `getParametros($id_equipo)` | Parámetros configurados para el equipo | `parametroequipo`, `parametros` |
| `getSetupParam($id)` | Configuración de un parámetro | `setupparam` |
| `insert_lectura($data)` | Alta de lectura manual | `historial_lecturas` |
| `update_ultima_lectura($id_equipo, $valor)` | Actualiza campo desnormalizado en equipos | `equipos.ultima_lectura` |

#### Categorización v3

| Operación | Categoría | Notas |
|-----------|-----------|-------|
| `get_lecturas/{equipo}` | **DataService SQL puro** | SELECT + ORDER BY fecha |
| `insert_lectura` | **Sequence de mediación** | INSERT historial + UPDATE `equipos.ultima_lectura` (2 tablas) |
| Alertas por umbral | **Python Phase 2** | Comparación lectura vs límites configurados |

---

### 6. KPIs de Mantenimiento

**Modelo:** `application/models/Kpis.php` (478 líneas)

Los KPIs se calculan principalmente a partir de `orden_trabajo` (tiempos de inicio/fin) y `historial_lecturas`.

#### Métodos relevantes

| Método | Descripción | KPI |
|--------|-------------|-----|
| `getDisponibilidadxFecha($fi, $ff)` | Disponibilidad por período | Disponibilidad % |
| `getDisponibilidadxFechaxEquipo($fi, $ff, $id)` | Disponibilidad por equipo | Disponibilidad % |
| `getMttrxFecha($fi, $ff)` | MTTR global del período | MTTR |
| `getMttrxFechaxEquipo($fi, $ff, $id)` | MTTR por equipo | MTTR |
| `getMttfxFecha($fi, $ff)` | MTTF global | MTTF |
| `getMttfxFechaxEquipo($fi, $ff, $id)` | MTTF por equipo | MTTF |
| `getTiempoTotalReparacion($fi, $ff)` | Tiempo total de reparación | Tiempo total |
| `getTiempoTotalReparacionxEquipo($fi, $ff, $id)` | Por equipo | Tiempo total |
| `getCantidadFallos($fi, $ff)` | Cantidad de fallas en período | Frecuencia fallas |
| `getCantidadFallosxEquipo($fi, $ff, $id)` | Fallas por equipo | Frecuencia fallas |
| `getCantEquiposxEmpresa()` | Total de equipos activos | Inventario |
| `getEstadoEquipo($id)` | Estado actual de un equipo | Estado |
| `estadoEquipoAlta($eq, $fecha, $checkMes)` | Calcula uptime desde fecha de alta | Disponibilidad |
| `estadoEquipoBaja($eq, $fecha, $checkMes)` | Calcula downtime por baja | Disponibilidad |
| `getHistorialLecturas($id, $fi, $ff)` | Historial para gráficos | Tendencias |

#### Tablas involucradas

`orden_trabajo`, `solicitud_reparacion`, `historial_lecturas`, `equipos`

#### Categorización v3

| Operación MCP | Categoría | Notas |
|---------------|-----------|-------|
| `get_kpis` (MTTR, MTTF, Disponibilidad) | **Sequence de mediación** | Los cálculos MTTR/MTTF requieren aritmética sobre fechas que puede hacerse en SQL (DATEDIFF / AVG) pero la lógica de `estadoEquipoAlta/Baja` es iterativa |
| `get_kpis` (Disponibilidad con historial estado) | **Python Phase 2** | `estadoEquipoAlta/Baja` itera sobre cada registro del historial — inviable en DBS puro |
| Lecturas/tendencias | **DataService SQL puro** | SELECT con rango de fechas |

> **Nota:** Para Sprint 2, exponer MTTR/MTTF como queries SQL directas (SUM de tiempos de OTs cerradas en período). La Disponibilidad completa (con historial de estados) queda para Python Phase 2.

---

### 7. Consumo de Materiales (Órdenes de Insumos)

**Modelo:** `application/models/Ordeninsumos.php` (~400 líneas)

Este modelo gestiona las órdenes de pedido de insumos/materiales que se generan al planificar PMs y OTs. Es el origen del dato `get_stock_ap` del Sprint 2.

#### Métodos relevantes

| Método | Descripción | Tablas |
|--------|-------------|--------|
| `getList()` | Lista de órdenes de insumos activas | `orden_insumos` |
| `getcodigo()` | Lookup artículos por código | `articles`, `tbl_lote` |
| `getsolicitante()` | Lookup usuarios solicitantes | `sisusers` |
| `getdescrip($data)` | Búsqueda de artículos por descripción | `articles`, `tbl_lote` |
| `insert_orden($data)` | Alta orden de insumos | `orden_insumos` |
| `insert_detaordeninsumo($data)` | Alta línea de detalle | `deta_ordeninsumos` |
| `getdeposito($data)` | Depósitos disponibles con stock | `abmdeposito`, `tbl_lote` |
| `getlotecant($id)` | Cantidad disponible de un lote | `tbl_lote` |
| `lote($idarticulo, $cant, $iddeposito)` | Reserva/descuenta lote | `tbl_lote` |
| `getsolImps($id)` | Insumos de una orden con detalle | `orden_insumos`, `deta_ordeninsumos`, `tbl_lote`, `articles` |
| `getequiposBycomodato($id)` | Equipos por comodato para una orden | `deta_ordeninsumos`, `tbl_lote`, `articles` |
| `getConsult($id)` | Consulta completa de una orden | `orden_insumos`, `deta_ordeninsumos` |
| `getequipos($id)` | Equipos relacionados a una OT de insumos | `deta_ordeninsumos`, `tbl_lote`, `articles`, `abmdeposito` |
| `total($id)` | Suma total de la orden | `deta_ordeninsumos` |
| `getOT()` | OTs disponibles para asignar insumos | `orden_trabajo` |

#### Tablas principales

`orden_insumos`, `deta_ordeninsumos`, `articles`, `tbl_lote`, `abmdeposito`

#### Relación con `get_stock_ap`

El endpoint `get_stock_ap` del Sprint 2 debe exponer el stock disponible por artículo/depósito. Esto mapea directamente a los queries de `tbl_lote` JOIN `articles` JOIN `abmdeposito`.

#### Categorización v3

| Operación MCP | Método(s) origen | Categoría | Notas |
|---------------|-----------------|-----------|-------|
| `get_stock_ap` | `getlotecant()` / `getdeposito()` | **DataService SQL puro** | SELECT stock por artículo/depósito |
| `get_orden_insumos` | `getList()` / `getConsult()` | **DataService SQL puro** | SELECT con JOINs |
| `create_orden_insumos` | `insert_orden()` + `insert_detaordeninsumo()` | **Sequence de mediación** | INSERT cabecera + líneas |
| Reserva de lote | `lote()` | **Sequence de mediación** | UPDATE stock + validación disponibilidad |

---

### 8. Backlogs

**Modelo:** `application/models/Backlogs.php` (279 líneas)

Gestiona el backlog de tareas de mantenimiento pendientes de planificar. No forma parte del Sprint 2.

#### Tablas principales

`tbl_back`, `componenteequipo`, `componentes`, `sistema`, `tbl_backlogherramientas`, `tbl_backloginsumos`

#### Métodos relevantes

| Método | Descripción |
|--------|-------------|
| `backlog_List()` | Lista completa de backlogs activos |
| `getComponentes($idEquipo)` | Componentes de un equipo para asignar al backlog |
| `insert_backlog($data)` | Alta de ítem de backlog |
| `update_back($data, $id)` | Edición |
| `getBacklogHerramientas($id)` | Herramientas requeridas |
| `getBacklogInsumos($id)` | Insumos requeridos |
| `insertBackHerram($herram)` / `insertBackInsum($insumo)` | Alta herramientas/insumos |
| `deleteHerramBack($id)` / `deleteInsumBack($id)` | Baja herramientas/insumos |

#### Categorización v3

| Operación | Categoría | Notas |
|-----------|-----------|-------|
| CRUD backlog | **DataService SQL puro** | Estructura simple, sin lógica compleja |
| Planificación desde backlog | **Sequence de mediación** | Conversión backlog → PM/OT; fuera de Sprint 2 |

---

## Convenciones del proyecto (WSO2 MI)

Estas convenciones aplican a todos los artefactos nuevos o extendidos en
`_backend/api/ToolsAPIProject/ToolsAPIProject/`.

### Nomenclatura de DataServices

```
<COD.MODULO>DataService.dbs              → hasta 30 operaciones
<COD.MODULO><GrupoFuncional>DataService.dbs  → split cuando supera 30 ops
```

Ejemplos para el módulo MAN:
- `MANDataService.dbs` — existente (KPIs + SolicitudServicio, 24 ops)
- `MANEquiposDataService.dbs` — nuevo (Equipos CRUD + lookups)
- `MANPreventivoDataService.dbs` — nuevo (Preventivos CRUD)
- `MANInsumoDataService.dbs` — nuevo (Stock AP + Órdenes de insumos)

### Datasources

Siempre referenciar un datasource configurado. Para este módulo:
- `AssetPlannerDataSource` → MySQL `assetv2` (host `10.142.0.13:3306`)
- `ToolsDataSource` → PostgreSQL `tools_prod_t` (si se necesita cruzar datos)

### Nomenclatura de queries

| Operación | Prefijo | Ejemplo |
|-----------|---------|---------|
| SELECT (lista o detalle) | `get` | `getEquipos`, `getEquipo` |
| INSERT | `set` | `setEquipo`, `setPreventivo` |
| UPDATE | `update` | `updateEquipo`, `updatePreventivoCase` |
| DELETE (lógico o físico) | `delete` | `deleteEquipo`, `deleteSolicitudServicio` |

### URLs de recursos en DataServices

Usar path params (`/segmento/{param}`) — nunca query strings (`?param=valor`).

```xml
<!-- Correcto -->
<resource method="GET" path="/solicitudes/empresa/{empr_id}">
<resource method="GET" path="/solicitudes/empresa/{empr_id}/sector/{sect_id}">
<resource method="GET" path="/equipos/{equi_id}">

<!-- Incorrecto -->
<resource method="GET" path="/solicitudes?empr_id={empr_id}">
```

### APIs externas (toolsMANAPI.xml)

Todos los endpoints del módulo MAN se exponen bajo `/tools/man` en
`toolsMANAPI.xml`. Las llamadas al DataService se hacen vía `<call>` con
`<endpoint>` apuntando a `http://localhost:9763/services/<DataService>`.

---

## Mapa de implementación v3 — Sprint 2

### Estado actual: MANDataService (24 operaciones existentes)

Archivo: `_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/data-services/MANDataService.dbs`
Datasource: `AssetPlannerDataSource`

| Query ID (existente) | Tipo | Recurso DBS |
|----------------------|------|-------------|
| `getKPIDisponibiidadPorFecha` | GET | `/kpiDisponibilidadxFecha/{id_empresa}/fecinicio/{fi}/fecfin/{ff}/...` |
| `getKPIDisponibiidadPorFechaPorEquipo` | GET | `/kpiDisponibilidadxFechaxEquipo/...` |
| `getKPIMttrporFecha` | GET | `/KpiMttrxFecha/empresa/{id}/fec_inicio/{fi}/fec_fin/{ff}` |
| `getKPIMttrporFechaxEquipo` | GET | `/KpiMttrxFechaxEquipo/...` |
| `getKPIMttfporFecha` | GET | `/KpiMttfxFecha/...` |
| `getKPIMttfporFechaporEquipo` | GET | `/KpiMttfxFechaxEquipo/...` |
| `getTiempoTotal` | GET | `/getTiempoTotal/{fecha_inicio}/{fecha_fin}` |
| `getTiempoTotalReparacion` | GET | `/getTiempoTotalReparacion/{fi}/{ff}/{fi3}/{ff3}/{empr}/{sect}/{grup}` |
| `getTiempoTotalReparacionxEquipo` | GET | `/getTiempoTotalReparacionxEquipo/{fi}/{ff}/{fi3}/{ff3}/{equi}` |
| `getCantidadEquiposxEmpresa` | GET | `/getCantEquiposxEmpresa/{empr_id}` |
| `getCantidadFallosxEquipo` | GET | `/getCantidadFallosxEquipo/{fi}/{ff}/{empr}/{equi}` |
| `getCantidadFallos` | GET | `/getCantidadFallos/{fi}/{ff}/{empr}/{sect}/{grup}` |
| `getEstadoEquipo` | GET | `/getEstadoEquipo/{id_equipo}` |
| `getCantEquiposxEmpresaxSectorxGrupo` | GET | `/getCantEquiposxEmpresaxSectorxGrupo/{empr}/{sect}/{grup}/{fi}/{ff}` |
| `getFechaAltaEquipo` | GET | `/getFechaAltaEquipo/{id_empresa}/{id_equipo}` |
| `getSolicitudServcio` | GET | `/getSolicitudServicioNoConforme/{id_empresa}` |
| `getNotificaciones` | GET | `/getNotificaciones/{user_id}` |
| `setsolicitudServicio` | POST | `/solicitudServicio` |
| `getLastsolicitudServicio` | GET | `/solicitudServicio/ultima/{equi_id}` |
| `putSolicitudServicioCase` | PUT | `/solicitudServicio/caseid` |
| `deleteSolicitudServicio` | DELETE | `/solicitudServicio` |
| `getEquipo` | GET | `/equipo/{equi_id}` |
| `getAdjuntosSolReparacion` | GET | `/solicitudServicio/adjuntos/solicitud/{id_solicitud}` |
| `setAdjuntosSolReparacion` | POST | `/solicitudServicio/adjuntos` |

> **Capacidad restante:** 30 − 24 = **6 operaciones** disponibles antes de requerir split.
> Agregar solo operaciones que no tengan grupo funcional propio (e.g., `getOrdenTrabajo`).

---

### DataServices nuevos a crear (extensión del proyecto)

Todos los archivos van en:
`_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/data-services/`

#### MANEquiposDataService.dbs (nuevo)

Datasource: `AssetPlannerDataSource` | Fuente CI3: `Equipos.php`

| Query ID | Tipo | Recurso DBS | Tablas |
|----------|------|-------------|--------|
| `getEquipos` | GET | `/equipos/empresa/{empr_id}` | `equipos`, `sector`, `grupo`, `criticidad` |
| `getEquipoDetalle` | GET | `/equipos/{equi_id}` | `equipos` + catálogos |
| `setEquipo` | POST | `/equipos` | `equipos` |
| `updateEquipo` | PUT | `/equipos/{equi_id}` | `equipos` |
| `deleteEquipo` | DELETE | `/equipos/{equi_id}` | `equipos` (soft delete) |
| `getCriticidades` | GET | `/equipos/lookup/criticidades` | `criticidad` |
| `getGruposEquipo` | GET | `/equipos/lookup/grupos` | `grupo` |
| `getSectores` | GET | `/equipos/lookup/sectores` | `sector` |
| `getUnidadesIndustriales` | GET | `/equipos/lookup/unidades` | `unidad_industrial` |
| `getMarcas` | GET | `/equipos/lookup/marcas` | `marcas` |
| `getProcesos` | GET | `/equipos/lookup/procesos` | `proceso` |

Total estimado: **11 ops**

#### MANPreventivoDataService.dbs (nuevo)

Datasource: `AssetPlannerDataSource` | Fuente CI3: `Preventivos.php`

| Query ID | Tipo | Recurso DBS | Tablas |
|----------|------|-------------|--------|
| `getPreventivos` | GET | `/preventivos/empresa/{empr_id}` | `preventivo`, `equipos`, `grupo`, `tareas`, `periodo` |
| `getPreventivo` | GET | `/preventivos/{prev_id}` | `preventivo` + detalle |
| `setPreventivo` | POST | `/preventivos` | `preventivo` |
| `updatePreventivo` | PUT | `/preventivos/{prev_id}` | `preventivo` |
| `deletePreventivo` | DELETE | `/preventivos/{prev_id}` | `preventivo` (soft delete) |
| `getPreventivoHerramientas` | GET | `/preventivos/{prev_id}/herramientas` | `tbl_preventivoherramientas` |
| `getPreventivoInsumos` | GET | `/preventivos/{prev_id}/insumos` | `tbl_preventivoinsumos` |
| `setPreventivoHerramienta` | POST | `/preventivos/herramientas` | `tbl_preventivoherramientas` |
| `deletePreventivoHerramienta` | DELETE | `/preventivos/herramientas/{id}` | `tbl_preventivoherramientas` |
| `setPreventivoInsumo` | POST | `/preventivos/insumos` | `tbl_preventivoinsumos` |
| `deletePreventivoInsumo` | DELETE | `/preventivos/insumos/{id}` | `tbl_preventivoinsumos` |

Total estimado: **11 ops**

#### MANInsumoDataService.dbs (nuevo)

Datasource: `AssetPlannerDataSource` | Fuente CI3: `Ordeninsumos.php`

Cubre el stock de insumos/materiales del módulo Asset Planner (`get_stock_ap`).

| Query ID | Tipo | Recurso DBS | Tablas |
|----------|------|-------------|--------|
| `getStockAP` | GET | `/insumos/stock/empresa/{empr_id}` | `tbl_lote`, `articles`, `abmdeposito` |
| `getStockDeposito` | GET | `/insumos/stock/deposito/{dep_id}` | `tbl_lote`, `articles` |
| `getDepositos` | GET | `/insumos/depositos/empresa/{empr_id}` | `abmdeposito` |
| `getArticulos` | GET | `/insumos/articulos` | `articles`, `tbl_lote` |
| `getOrdenesInsumos` | GET | `/insumos/ordenes/empresa/{empr_id}` | `orden_insumos` |
| `getOrdenInsumo` | GET | `/insumos/ordenes/{ord_id}` | `orden_insumos`, `deta_ordeninsumos` |
| `setOrdenInsumo` | POST | `/insumos/ordenes` | `orden_insumos` |
| `setDetalleOrdenInsumo` | POST | `/insumos/ordenes/detalle` | `deta_ordeninsumos` |

Total estimado: **8 ops**

---

### Extensión de toolsMANAPI.xml

Archivo: `_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/apis/toolsMANAPI.xml`

Todos los recursos nuevos se agregan bajo el path base `/tools/man`. Las llamadas internas al DataService usan el endpoint local WSO2 MI.

#### Recursos nuevos — Equipos

```
GET  /tools/man/equipos/empresa/{empr_id}           → MANEquiposDataService/equipos/empresa/{empr_id}
GET  /tools/man/equipos/{equi_id}                   → MANEquiposDataService/equipos/{equi_id}
POST /tools/man/equipos                             → MANEquiposDataService/equipos
PUT  /tools/man/equipos/{equi_id}                   → MANEquiposDataService/equipos/{equi_id}
DELETE /tools/man/equipos/{equi_id}                 → MANEquiposDataService/equipos/{equi_id}
GET  /tools/man/equipos/lookup/criticidades         → MANEquiposDataService/equipos/lookup/criticidades
GET  /tools/man/equipos/lookup/grupos               → MANEquiposDataService/equipos/lookup/grupos
GET  /tools/man/equipos/lookup/sectores             → MANEquiposDataService/equipos/lookup/sectores
```

#### Recursos nuevos — Preventivos

```
GET  /tools/man/preventivos/empresa/{empr_id}       → MANPreventivoDataService/preventivos/empresa/{empr_id}
GET  /tools/man/preventivos/{prev_id}               → MANPreventivoDataService/preventivos/{prev_id}
POST /tools/man/preventivos                         → Sequence: createPreventivoCargadoSequence
PUT  /tools/man/preventivos/{prev_id}               → MANPreventivoDataService/preventivos/{prev_id}
GET  /tools/man/preventivos/{prev_id}/herramientas  → MANPreventivoDataService/preventivos/{prev_id}/herramientas
GET  /tools/man/preventivos/{prev_id}/insumos       → MANPreventivoDataService/preventivos/{prev_id}/insumos
```

#### Recursos nuevos — Stock AP / Insumos

```
GET  /tools/man/insumos/stock/empresa/{empr_id}     → MANInsumoDataService/insumos/stock/empresa/{empr_id}
GET  /tools/man/insumos/stock/deposito/{dep_id}     → MANInsumoDataService/insumos/stock/deposito/{dep_id}
GET  /tools/man/insumos/depositos/empresa/{empr_id} → MANInsumoDataService/insumos/depositos/empresa/{empr_id}
GET  /tools/man/insumos/ordenes/empresa/{empr_id}   → MANInsumoDataService/insumos/ordenes/empresa/{empr_id}
POST /tools/man/insumos/ordenes                     → Sequence: createOrdenInsumoSequence
```

> **Nota:** Los recursos de KPIs y SolicitudServicio ya existen en `toolsMANAPI.xml`. No duplicar — solo agregar los nuevos.

---

### Sequences nuevas a crear

Archivo destino: `_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/sequences/`

| Sequence | Descripción | Complejidad |
|----------|-------------|-------------|
| `createOTSequence` | POST `/tools/man/solicitudes` → INSERT `solicitud_reparacion` → POST Bonita `/process` → UPDATE `case_id` | Alta (BPM + DB) |
| `createPreventivoCargadoSequence` | POST `/tools/man/preventivos` → INSERT `preventivo` + herramientas + insumos | Media (3 INSERTs) |
| `insertLecturaSequence` | INSERT `historial_lecturas` + UPDATE `equipos.ultima_lectura` | Baja (2 tablas) |
| `createOrdenInsumoSequence` | INSERT `orden_insumos` + líneas de `deta_ordeninsumos` | Media (N INSERTs) |

`createOTSequence` reutiliza `bpmAPICallTemplate` de `toolsBPMAPI.xml` (ya implementado).

---

### Diferidos a Python Phase 2

| Funcionalidad | Razón |
|---------------|-------|
| Disponibilidad con historial de estados (`estadoEquipoAlta/Baja`) | Lógica iterativa no expresable en SQL/DBS |
| PMs disparados por horas (`revisaEstadoPreventivosPorHoras`) | Evaluación de umbrales con historial de lecturas |
| Análisis predictivo (Predictivos) | Requiere modelos ML |
| Alertas por límites de parámetros | Comparación dinámica contra `setupparam` |

---

## Notas de campo

- **Base MySQL `assetv2`**: Todos los modelos de esta encuesta usan `AssetPlannerDataSource` (MySQL, host `10.142.0.13:3306`). Credenciales en texto plano en `AssetPlannerDataSource.xml` — ver security flag en `inventory-2026.md`.
- **`historial_lecturas`**: Tabla pivote entre Lecturas, KPIs y cierre de OTs. Requiere atención en índices al migrar.
- **`sisusers`**: Referenciada en múltiples modelos; verificar si existe en `assetv2` o si el join debe cruzar a `tools_prod_t` vía Sequence.
- **Bonita BPM en `createOTSequence`**: Requiere crear caso en Bonita antes de confirmar la solicitud. El manejo de sesión BPM (cookie + refresh en 401) ya está implementado en `bpmAPICallTemplate` de `toolsBPMAPI.xml`.
