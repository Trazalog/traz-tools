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
   - **DataService SQL puro** → operación DBS en WSO2 MI
   - **Sequence de mediación** → orquestación multi-paso en WSO2 MI
   - **Python Phase 2** → lógica iterativa, ML o cálculos estadísticos

---

## Convenciones del proyecto (WSO2 MI)

Todos los artefactos nuevos o extendidos viven en:
`_backend/api/ToolsAPIProject/ToolsAPIProject/`

### Nomenclatura de DataServices

```
<COD.MODULO>DataService.dbs                     → hasta 30 operaciones
<COD.MODULO><GrupoFuncional>DataService.dbs     → split cuando supera 30 ops
```

### Datasources

Siempre referenciar un datasource configurado:
- `AssetPlannerDataSource` → MySQL `assetv2` (host `10.142.0.13:3306`) — **módulo MAN**
- `ToolsDataSource` → PostgreSQL `tools_prod_t` — si se cruzan datos con Tools

### Nomenclatura de queries

| Operación | Prefijo | Ejemplo |
|-----------|---------|---------|
| SELECT (lista o detalle) | `get` | `getEquipos`, `getEquipo` |
| INSERT | `set` | `setEquipo`, `setOrdenTrabajo` |
| UPDATE | `update` | `updateEquipo`, `updateOrdenTrabajoCaseId` |
| DELETE (lógico o físico) | `delete` | `deleteEquipo` |

### URLs de recursos en DataServices

Path params solamente (`/segmento/{param}`), nunca query strings.

```xml
<!-- Correcto -->
<resource method="GET" path="/solicitudes/empresa/{empr_id}">
<resource method="GET" path="/equipos/{equi_id}">

<!-- Incorrecto -->
<resource method="GET" path="/solicitudes?empr_id={empr_id}">
```

### APIs externas

Todos los endpoints del módulo MAN se exponen bajo `/tools/man` en `toolsMANAPI.xml`.

---

## Resumen de modelos relevados

> **Excluido:** subdirectorio `traz-comp-almacen/` — se usarán las APIs y DataServices de Tools (ALMDataService) en su lugar.

| # | Modelo | Líneas | Grupo funcional | Sprint 2 |
|---|--------|--------|-----------------|----------|
| 1 | `Equipos.php` | 1 824 | Equipos | `get_equipos` ✅ |
| 2 | `Sservicios.php` | 580 | OTs correctivas | `get_ots`, `create_ot` ✅ |
| 3 | `Otrabajos.php` | 1 579 | OTs programadas | `get_ots` (ampliado) ✅ |
| 4 | `Ordenservicios.php` | 770 | OTs — ejecución | Fase 2 (RRHH) |
| 5 | `Tareas.php` | 1 322 | OTs — ciclo de vida | Sequences |
| 6 | `Calendarios.php` | 1 263 | Planificación | `get_ots`, `get_preventivos` ✅ (parcial) |
| 7 | `Preventivos.php` | 838 | Preventivos | `get_preventivos`, `create_preventivo` ✅ |
| 8 | `Predictivos.php` | 297 | Predictivos | Fase 2 |
| 9 | `Lecturas.php` | 212 | Lecturas / Sensores | `get_kpis` (insumo) |
| 10 | `Kpis.php` | 478 | KPIs | `get_kpis` ✅ |
| 11 | `Backlogs.php` | 279 | Backlog | Fase 2 |
| 12 | `Componentes.php` | 284 | Componentes de equipos | Catálogo |
| 13 | `Herramientas.php` | 143 | Herramientas (catálogo) | Catálogo |
| 14 | `Ordeninsumos.php` | 379 | Insumos / Stock AP | `get_stock_ap` ✅ |
| 15 | Catálogos simples | < 130 c/u | Lookups | Catálogo |

---

## Detalle por entidad

### 1. Equipos

**Modelo:** `Equipos.php` (1 824 líneas)

#### Métodos relevantes

| Método | Descripción | Tablas |
|--------|-------------|--------|
| `equipos_List()` | Lista completa con joins de catálogos + última lectura | `equipos`, `sector`, `empresas`, `unidad_industrial`, `criticidad`, `area`, `grupo`, `proceso`, `admcustomers`, `historial_lecturas` |
| `getpencil($id)` | Detalle de equipo para edición | `equipos` + catálogos |
| `getdatosfichas($id)` | Datos para ficha técnica | ídem |
| `insert_equipo($data)` | Alta | `equipos` |
| `update_cambio($data, $idequipo)` | Modificación | `equipos` |
| `update_estado($idequipo)` | Cambio de estado | `equipos` |
| `baja_equipos($data, $idequipo)` | Baja lógica | `equipos` |
| `getcriti()` / `getgrupos()` / `getsector()` / `getunidads()` / `getmarcas()` / `getprocesos()` | Lookups de catálogos | varias |

#### Categorización v3 → `MANEquiposDataService`

| Query ID | Operación MCP | Tipo |
|----------|---------------|------|
| `getEquipos` | `get_equipos` | DataService SQL puro |
| `getEquipo` | GET `/equipos/{id}` | DataService SQL puro |
| `setEquipo` | create equipo | DataService SQL puro |
| `updateEquipo` | update equipo | DataService SQL puro |
| `deleteEquipo` | baja equipo | DataService SQL puro |
| `getCriticidades`, `getGruposEquipo`, `getSectores`, etc. | lookups | DataService SQL puro |

---

### 2. OTs correctivas — Sservicios

**Modelo:** `Sservicios.php` (580 líneas)

Gestiona solicitudes de reparación (`solicitud_reparacion`) originadas por el usuario. La OT técnica (`orden_trabajo`) se crea al aceptar la solicitud en Bonita BPM.

#### Métodos relevantes

| Método | Descripción | Tablas |
|--------|-------------|--------|
| `getServiciosList($showConformes)` | Lista de solicitudes con estado | `solicitud_reparacion`, `equipos`, `sector`, `grupo`, `orden_trabajo`, `sisusers` |
| `solicitudespaginadas($start, $length, $search, $ordering, $showConformes)` | Lista paginada + última OT por `case_id` | ídem |
| `setservicios($data)` | Alta de solicitud | `solicitud_reparacion` |
| `setCaseId($caseId, $id_solServicio)` | Vincula caso BPM | `solicitud_reparacion` |
| `activSolicitudes($data)` / `confSolicitudes($data)` | Transiciones de estado | `solicitud_reparacion` |
| `eliminar_solicitud($id, $usuario, $motivo)` / `eliminar_orden_trabajo(...)` | Bajas lógicas | `solicitud_reparacion`, `orden_trabajo` |
| `get_SolicTerminadas()` | OTs cerradas (insumo KPIs) | `solicitud_reparacion`, `orden_trabajo` |

#### Categorización v3 → extender `MANDataService` + `MANOrdenTrabajoDataService`

| Query ID | Operación MCP | Tipo | DataService |
|----------|---------------|------|-------------|
| `getSolicitudesServicio` | `get_ots` correctivas | DataService SQL puro | MANDataService (ya existe: `getSolicitudServcio`) |
| `setsolicitudServicio` | `create_ot` paso 1 | DataService SQL puro | MANDataService (ya existe) |
| `updateSolicitudServicioCaseId` | `create_ot` paso 3 | DataService SQL puro | MANDataService (ya existe: `putSolicitudServicioCase`) |
| `deleteSolicitudServicio` | baja solicitud | DataService SQL puro | MANDataService (ya existe) |
| `getOrdenTrabajo` | `get_ots` detalle OT | DataService SQL puro | MANOrdenTrabajoDataService (nuevo) |

---

### 3. OTs programadas — Otrabajos

**Modelo:** `Otrabajos.php` (1 579 líneas, 84 métodos)

Gestiona OTs programadas, correctivas externas y órdenes de pedido de equipos. Usa la misma tabla `orden_trabajo` que Sservicios pero filtrada por `tipo` (via `tbl_tipoordentrabajo`). Es el modelo más completo del módulo.

#### Métodos relevantes

| Método | Descripción | Tablas |
|--------|-------------|--------|
| `otrabajos_List($ot, $tipo)` | Lista OTs por tipo | `orden_trabajo`, `tbl_tipoordentrabajo`, `tareas`, `equipos`, `sisusers`, `usuarioasempresa` |
| `filtrarListado($data, $tipo)` | Búsqueda filtrada por tipo | ídem |
| `guardar_agregar($data)` | Alta de OT programada | `orden_trabajo` |
| `getpencil($id)` | Detalle de una OT | `orden_trabajo` + joins |
| `update_edita($id, $data)` | Edición de OT | `orden_trabajo` |
| `eliminacion($data)` | Baja lógica | `orden_trabajo` |
| `getOTHerramientas($id)` / `getOTInsumos($id)` | Herramientas e insumos asignados | `tbl_otherramientas`, `tbl_otinsumos` |
| `insertOTHerram($herram)` / `deleteHerramOT($id)` | ABM herramientas OT | `tbl_otherramientas` |
| `insertOTInsum($insumo)` / `deleteInsumOT($id)` | ABM insumos OT | `tbl_otinsumos` |
| `setCaseidenOTNueva($case_id, $id)` | Vincula BPM | `orden_trabajo` |
| `cambiarEstado($id, $estado, $tipo)` | Máquina de estados | `orden_trabajo` |
| `kpiCantTipoOrdenTrabajo()` | KPI: OTs por tipo | `orden_trabajo`, `tbl_tipoordentrabajo` |
| `getViewDataOt($idOt)` | Vista unificada de una OT (cualquier tipo) | `orden_trabajo`, `tbl_tipoordentrabajo` |
| `getViewDataSolServicio($idOt)` | Vista OT correctiva con solicitud | `orden_trabajo`, `solicitud_reparacion` |
| `getViewDataPreventivo($idOt)` | Vista OT de preventivo | `orden_trabajo`, `preventivo` |
| `getViewDataBacklog($idOt)` | Vista OT de backlog | `orden_trabajo`, `tbl_back` |
| `getViewDataPredictivo($idOt)` | Vista OT de predictivo | `orden_trabajo`, `predictivo` |
| `setotrabajos($data)` | Alta OT externa (con pedido) | `orden_trabajo`, `orden_pedido` |
| `insert_pedido($data)` / `get_pedido($id)` | ABM pedidos asociados a OT | `orden_pedido` |

#### Tabla `tbl_tipoordentrabajo` — tipos de OT

| tipo | Descripción |
|------|-------------|
| 1 | Correctiva (solicitud_reparacion) |
| 2 | Programada / Preventivo |
| 3 | Externa / con proveedor |
| ... | (verificar catálogo completo) |

#### Categorización v3 → `MANOrdenTrabajoDataService` (nuevo)

| Query ID | Operación MCP | Tipo |
|----------|---------------|------|
| `getOrdenesTrabajo` | `get_ots` (con filtro tipo) | DataService SQL puro |
| `getOrdenTrabajo` | GET `/ordenes-trabajo/{id}` | DataService SQL puro |
| `setOrdenTrabajo` | create OT programada | DataService SQL puro |
| `updateOrdenTrabajo` | update OT | DataService SQL puro |
| `deleteOrdenTrabajo` | baja OT | DataService SQL puro |
| `updateOrdenTrabajoCaseId` | vincula BPM | DataService SQL puro |
| `updateOrdenTrabajoEstado` | cambio de estado | DataService SQL puro |
| `getOrdenTrabajoHerramientas` | herramientas de la OT | DataService SQL puro |
| `getOrdenTrabajoInsumos` | insumos de la OT | DataService SQL puro |
| `setOrdenTrabajoHerramienta` / `deleteOrdenTrabajoHerramienta` | ABM herramientas | DataService SQL puro |
| `setOrdenTrabajoInsumo` / `deleteOrdenTrabajoInsumo` | ABM insumos | DataService SQL puro |
| `getTiposOrdenTrabajo` | catálogo de tipos | DataService SQL puro |
| `kpiCantOrdenesPorTipo` | KPI por tipo de OT | DataService SQL puro |
| `getViewOrdenTrabajo` | vista unificada (cualquier tipo) | DataService SQL puro |

**Total estimado: ~15 ops → propio DataService justificado.**

---

### 4. OTs — Ejecución de servicio (Ordenservicios)

**Modelo:** `Ordenservicios.php` (770 líneas, 34 métodos)

Capa de ejecución: registra la orden de servicio efectiva (`orden_servicio`) con comprobante y asignación de RRHH (`asignausuario`). Se vincula a `orden_trabajo` por `id_ot`.

#### Métodos relevantes

| Método | Descripción | Tablas |
|--------|-------------|--------|
| `getOrdServiciosList()` | Lista de órdenes de servicio | `orden_servicio`, `orden_trabajo`, `asignausuario`, `tareas`, `equipos` |
| `setOrdenServicios($data)` | Alta de orden de servicio | `orden_servicio` |
| `getRRHHOrdenTrabajo($idOT)` | Recursos humanos asignados | `asignausuario` |
| `getResponsableOT($idOT)` | Responsable de la OT | `asignausuario` |
| `getLecturasOrden($id_ot)` | Lecturas registradas durante la OT | `historial_lecturas` |
| `getTareasOrden($id_ot)` | Tareas realizadas en la OT | `tbl_listarea` |
| `getHerramOrdenes($id_ot)` | Herramientas utilizadas | `tbl_otherramientas` |
| `getInsumosPorOT($id_ot)` | Insumos consumidos | `tbl_otinsumos`, `tbl_lote`, `articles` |
| `borrarHerramOrden($id_ot)` / `borrarRecursosOrden($id_ot)` | Limpieza de recursos | tablas relacionadas |
| `borrarOrden($id_ot)` | Baja de orden de servicio | `orden_servicio` |
| `setEstados($data)` | Cambio de estado | `orden_servicio` |
| `guardarEvidencia($data)` / `getEvidenciasOrden($id)` | Evidencias fotográficas | `evidencias_orden` (a confirmar) |
| `validaOperarios($data)` | Validación de operarios disponibles | `sisusers` |

#### Categorización v3

| Operación | Tipo | DataService |
|-----------|------|-------------|
| `getOrdenesServicio` / `getOrdenServicio` | DataService SQL puro | `MANOrdenTrabajoDataService` (misma familia) |
| `setOrdenServicio` | DataService SQL puro | `MANOrdenTrabajoDataService` |
| `getRRHH` / asignación de operarios | **Sequence de mediación** | Valida disponibilidad + INSERT en `asignausuario` |
| Evidencias | DataService SQL puro | `MANOrdenTrabajoDataService` |

> Con estas adiciones, `MANOrdenTrabajoDataService` podría superar 30 ops. Evaluar split en `MANEjecucionDataService` para todo lo de `orden_servicio` + `asignausuario`.

---

### 5. OTs — Ciclo de vida (Tareas)

**Modelo:** `Tareas.php` (1 322 líneas)

Máquina de estados del ciclo de vida de todas las OTs. No genera un DataService propio — sus operaciones alimentan Sequences.

#### Métodos relevantes

| Método | Descripción | Tablas |
|--------|-------------|--------|
| `cambiarEstado($id, $estado, $tipo)` | Transición de estado OT | `orden_trabajo`, `tbl_listarea` |
| `inicioTareas($id_OT)` / `finTareas($id_OT)` | Timestamps inicio/fin | `orden_trabajo` |
| `getSubtareas($ot)` | Checklist de subtareas | `asp_subtareas`, `tareas` |
| `setUltimaLecturaIS($data)` | INSERT lectura al cerrar OT | `historial_lecturas` |
| `terminarTareaStandarenBPM($idTarBonita, $param)` | Completa tarea en Bonita | BPM API |
| `validarCamposObligatorios($idForm, $idOT)` | Validación de formularios | `frm_formularios_completados`, `frm_instancias_formulario` |

#### Categorización v3 → Sequences

Todos los métodos de Tareas que implican estado se implementan como **Sequences de mediación** en WSO2 MI (no como DataService), ya que combinan DB + BPM + validaciones.

---

### 6. Planificación (Calendarios)

**Modelo:** `Calendarios.php` (1 263 líneas, 48 métodos)

Tablero de planificación mensual. Agrega todas las entidades de trabajo (OTs, Preventivos, Predictivos, Backlogs, Solicitudes) filtrando por mes/año para la vista de calendario del planificador.

#### Métodos relevantes

| Método | Descripción | Tablas |
|--------|-------------|--------|
| `getot($data)` | OTs del mes filtradas | `orden_trabajo`, `tbl_tipoordentrabajo`, `equipos` |
| `getPreventivos($month, $year)` | Preventivos del mes | `preventivo`, `equipos`, `tareas` |
| `getPreventivosHoras($mes, $year)` | Preventivos por horas del mes | `preventivo`, `equipos`, `historial_lecturas` |
| `getpredlist($month, $year)` | Predictivos del mes | `predictivo`, `equipos`, `tareas`, `sector` |
| `getbacklog($month, $year)` | Backlogs del mes | `tbl_back`, `equipos`, `tareas` |
| `getsservicio($month, $year)` | Solicitudes correctivas del mes | `solicitud_reparacion`, `equipos`, `sector` |
| `getServicioTareas($data, $month, $year)` | Tareas de servicio programadas | varias |
| `guardar_agregar($data)` | Crea OT desde planificador | `orden_trabajo` |
| `setCaseidenOT($case_id, $id)` | Vincula BPM en planificación | `orden_trabajo` |
| `cambiarEstado($id, $estado, $tipo)` | Cambio de estado desde calendario | `orden_trabajo` |
| `setVisit($data)` | Registra visita programada | `orden_trabajo` (a confirmar) |
| `setOTbatch($data)` | Alta batch de OTs | `orden_trabajo` |
| `getDataOt($idOt)` | Datos completos de OT para vista | `orden_trabajo`, `tbl_tipoordentrabajo`, `equipos`, `sisusers` |
| `getCompEquipoOT($numtipo, $id_solicitud, $idOt)` | Componente del equipo en OT | `componenteequipo`, `componentes` |
| `updateDiaProgramacion($id, $diaNuevo)` / `updateDuraciones($id, $nueva)` | Ajustes de scheduling | `orden_trabajo` |

#### Categorización v3

Los queries de Calendarios son **vistas de lectura** (SELECT multi-entidad por mes). Se implementan como:
- Queries GET en los DataServices respectivos (ya cubiertos) más un parámetro de mes/año
- Un **endpoint agregador** en `toolsMANAPI.xml` que llama en secuencia a los DataServices relevantes y compone la respuesta del calendario

| Operación | Tipo | Nota |
|-----------|------|------|
| `getCalendarioMes($mes, $year)` | **Sequence de mediación** | Agrega OTs + Preventivos + Predictivos + Backlogs en una sola respuesta |
| `setOTdesdeCalendario` | DataService SQL puro | reutiliza `setOrdenTrabajo` de `MANOrdenTrabajoDataService` |
| `updateScheduling` | DataService SQL puro | UPDATE fecha/duración en `orden_trabajo` |

---

### 7. Preventivos

**Modelo:** `Preventivos.php` (838 líneas)

#### Métodos relevantes

| Método | Descripción | Tablas |
|--------|-------------|--------|
| `preventivos_List()` | Lista completa de PMs | `preventivo`, `equipos`, `grupo`, `tareas`, `componentes`, `periodo` |
| `getInfoPreventivo($id)` | Detalle de un PM | ídem |
| `getPreventivoHerramientas($id)` / `getPreventivoInsumos($id)` | Recursos del PM | `tbl_preventivoherramientas`, `tbl_preventivoinsumos` |
| `insert_preventivo($data)` | Alta | `preventivo` |
| `update_preventivo($data, $idprev)` / `update_editar($data, $idp)` | Edición | `preventivo` + recursos |
| `getPreventivosPorHora()` | PMs por horas de uso | `preventivo`, `equipos.ultima_lectura` |
| `revisaEstadoPreventivosPorHoras($preventivos)` | Evalúa umbral de horas | `historial_lecturas` |

#### Categorización v3 → `MANPreventivoDataService` (nuevo)

| Query ID | Operación MCP | Tipo |
|----------|---------------|------|
| `getPreventivos` | `get_preventivos` | DataService SQL puro |
| `getPreventivo` | GET `/preventivos/{id}` | DataService SQL puro |
| `setPreventivo` | `create_preventivo` paso 1 | DataService SQL puro |
| `updatePreventivo` | update preventivo | DataService SQL puro |
| `deletePreventivo` | baja preventivo | DataService SQL puro |
| `getPreventivoHerramientas` / `getPreventivoInsumos` | recursos | DataService SQL puro |
| `setPreventivoHerramienta` / `deletePreventivoHerramienta` | ABM herramientas | DataService SQL puro |
| `setPreventivoInsumo` / `deletePreventivoInsumo` | ABM insumos | DataService SQL puro |
| PMs por horas | `revisaEstadoPreventivosPorHoras` | **Python Phase 2** |

---

### 8. Predictivos

**Modelo:** `Predictivos.php` (297 líneas)

Estructura análoga a Preventivos. Tablas: `predictivo`, `tbl_predictivoherramientas`, `tbl_predictivoinsumos`.

#### Categorización v3

CRUD básico → `MANPreventivoDataService` (puede coexistir con preventivos, son ~10 ops adicionales).
Análisis de condición y umbrales → **Python Phase 2**.

---

### 9. Lecturas / Sensores

**Modelo:** `Lecturas.php` (212 líneas)

Tablas: `historial_lecturas`, `parametroequipo`, `setupparam`, `parametros`.

| Método | Descripción |
|--------|-------------|
| `getLecturasEquipo($id_equipo)` | Historial de lecturas |
| `getParametros($id_equipo)` | Parámetros configurados |
| `insert_lectura($data)` | Alta de lectura manual |
| `update_ultima_lectura($id_equipo, $valor)` | Actualiza `equipos.ultima_lectura` |

**Categorización v3:**
- `getLecturas` → `MANEquiposDataService` (está relacionado con equipos)
- `insertLectura` → **Sequence** (INSERT historial + UPDATE `equipos.ultima_lectura`)
- Alertas por umbral → **Python Phase 2**

---

### 10. KPIs de Mantenimiento

**Modelo:** `Kpis.php` (478 líneas)

KPIs calculados sobre `orden_trabajo` e `historial_lecturas`.

| Método clave | KPI | Tablas |
|--------------|-----|--------|
| `getDisponibilidadxFecha($fi, $ff)` | Disponibilidad % | `orden_trabajo`, `solicitud_reparacion` |
| `getMttrxFecha($fi, $ff)` / `...xEquipo` | MTTR | `orden_trabajo` |
| `getMttfxFecha($fi, $ff)` / `...xEquipo` | MTTF | `orden_trabajo` |
| `getCantidadFallos(...)` / `...xEquipo` | Frecuencia fallas | `orden_trabajo` |
| `estadoEquipoAlta(...)` / `estadoEquipoBaja(...)` | Disponibilidad con historial | iterativo — Python Phase 2 |
| `getHistorialLecturas($id, $fi, $ff)` | Tendencias de sensores | `historial_lecturas` |

**Categorización v3:**
- MTTR, MTTF, Fallas, Lecturas → **MANDataService** (ya tiene 15 queries KPI; agregar los faltantes dentro del límite de 30)
- Disponibilidad con historial de estados → **Python Phase 2**

---

### 11. Insumos y Stock AP

**Modelo:** `Ordeninsumos.php` (379 líneas)

Tablas: `orden_insumos`, `deta_ordeninsumos`, `articles`, `tbl_lote`, `abmdeposito`.

| Método | Descripción |
|--------|-------------|
| `getList()` | Lista de órdenes de insumos |
| `getdeposito($data)` | Depósitos con stock disponible |
| `getlotecant($id)` | Stock de un lote |
| `getdescrip($data)` | Búsqueda de artículos |
| `insert_orden($data)` / `insert_detaordeninsumo($data)` | Alta orden + líneas |
| `lote($idarticulo, $cant, $iddeposito)` | Reserva de lote (descuenta stock) |
| `getsolImps($id)` | Insumos de una orden con detalle |

**Categorización v3 → `MANInsumoDataService` (nuevo):**
- `getStockAP`, `getDepositos`, `getArticulos`, `getOrdenesInsumos` → DataService SQL puro
- Alta de orden (`setOrdenInsumo` + líneas) → **Sequence de mediación**
- Reserva de lote → **Sequence de mediación** (validación + UPDATE)

---

### 12. Backlog

**Modelo:** `Backlogs.php` (279 líneas)

Tablas: `tbl_back`, `componenteequipo`, `componentes`, `sistema`, `tbl_backlogherramientas`, `tbl_backloginsumos`.

CRUD simple. Fuera de Sprint 2. → `MANOrdenTrabajoDataService` (relacionado al ciclo de vida de OTs) o `MANPreventivoDataService`.

---

### 13. Componentes de equipos

**Modelo:** `Componentes.php` (284 líneas, 17 métodos)

Gestiona la jerarquía de componentes de un equipo (sistemas → componentes → sub-componentes).

Tablas: `componentes`, `componenteequipo`, `sistema`, `marcas`, `equipos`.

| Método | Descripción |
|--------|-------------|
| `componentes_List()` | Lista ABM de componentes |
| `traerequipo()` / `getequipo($id)` | Equipos para asignar componente |
| `agregar_componente($insert)` | Alta componente-equipo |
| `updatecomp($id, $update)` | Edición |
| `bajaComponente($idcomp)` | Baja |
| `getsistema()` | Lookup sistemas |

**Categorización v3:** CRUD básico → `MANEquiposDataService` (~6 ops adicionales, dentro del límite).

---

### 14. Herramientas (catálogo)

**Modelo:** `Herramientas.php` (143 líneas, 9 métodos)

Catálogo master de herramientas referenciadas en Preventivos y OTs.
Tablas: `herramientas`, `marcas`, `abmdeposito`.

| Método | Descripción |
|--------|-------------|
| `listar_herramientas()` | Lista ABM |
| `agregar_herramientas($data)` | Alta |
| `update_editar($data, $id)` | Edición |
| `eliminacion($data)` | Baja |
| `existeHerramienta($codigo)` | Validación duplicado |

**Categorización v3:** → `MANEquiposDataService` (catálogo de soporte, ~5 ops).

---

### 15. Catálogos simples

Los siguientes modelos son ABM de tablas de referencia (< 130 líneas, sin lógica compleja):

| Modelo | Tabla(s) | DataService destino |
|--------|----------|---------------------|
| `Empresas.php` | `admcustomers` / `empresas` | `MANEquiposDataService` |
| `Sectores.php` | `sector` | `MANEquiposDataService` |
| `Grupos.php` / `Groups.php` | `grupo` | `MANEquiposDataService` |
| `Criticidades.php` | `criticidad` | `MANEquiposDataService` |
| `Marcas.php` | `marcas` | `MANEquiposDataService` |
| `Procesos.php` | `proceso` | `MANEquiposDataService` |
| `Areas.php` | `area` | `MANEquiposDataService` |
| `Proveedores.php` | `proveedores` | `MANOrdenTrabajoDataService` |
| `Contratistas.php` | `contratistas` | `MANOrdenTrabajoDataService` |
| `Parametros.php` | `setupparam`, `parametros` | `MANEquiposDataService` |

---

## Mapa de implementación v3 — Sprint 2

### Estado actual: MANDataService.dbs (24 ops existentes)

Archivo: `.../data-services/MANDataService.dbs` | Datasource: `AssetPlannerDataSource`

| Query ID existente | Método HTTP | Recurso DBS |
|--------------------|-------------|-------------|
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

**Capacidad restante:** 30 − 24 = **6 ops** antes de split.

---

### DataServices nuevos a crear

Todos en `.../src/main/wso2mi/artifacts/data-services/`

#### MANEquiposDataService.dbs

Datasource: `AssetPlannerDataSource` | Fuente CI3: `Equipos.php`, `Componentes.php`, `Herramientas.php`, catálogos

| Query ID | HTTP | Recurso DBS | Tablas clave |
|----------|------|-------------|--------------|
| `getEquipos` | GET | `/equipos/empresa/{empr_id}` | `equipos`, `sector`, `grupo`, `criticidad` |
| `getEquipo` | GET | `/equipos/{equi_id}` | `equipos` + catálogos |
| `setEquipo` | POST | `/equipos` | `equipos` |
| `updateEquipo` | PUT | `/equipos/{equi_id}` | `equipos` |
| `deleteEquipo` | DELETE | `/equipos/{equi_id}` | `equipos` |
| `getCriticidades` | GET | `/equipos/lookup/criticidades` | `criticidad` |
| `getGruposEquipo` | GET | `/equipos/lookup/grupos` | `grupo` |
| `getSectores` | GET | `/equipos/lookup/sectores` | `sector` |
| `getUnidadesIndustriales` | GET | `/equipos/lookup/unidades` | `unidad_industrial` |
| `getMarcas` | GET | `/equipos/lookup/marcas` | `marcas` |
| `getProcesos` | GET | `/equipos/lookup/procesos` | `proceso` |
| `getAreas` | GET | `/equipos/lookup/areas` | `area` |
| `getComponentesEquipo` | GET | `/equipos/{equi_id}/componentes` | `componenteequipo`, `componentes` |
| `setComponenteEquipo` | POST | `/equipos/componentes` | `componenteequipo` |
| `deleteComponenteEquipo` | DELETE | `/equipos/componentes/{id}` | `componenteequipo` |
| `getLecturasEquipo` | GET | `/equipos/{equi_id}/lecturas/desde/{fi}/hasta/{ff}` | `historial_lecturas` |
| `getParametrosEquipo` | GET | `/equipos/{equi_id}/parametros` | `parametroequipo`, `parametros` |
| `getHerramientas` | GET | `/equipos/lookup/herramientas` | `herramientas` |
| `setHerramienta` | POST | `/equipos/herramientas` | `herramientas` |
| `updateHerramienta` | PUT | `/equipos/herramientas/{id}` | `herramientas` |

**Total estimado: ~20 ops**

#### MANOrdenTrabajoDataService.dbs

Datasource: `AssetPlannerDataSource` | Fuente CI3: `Otrabajos.php`, `Ordenservicios.php`, `Backlogs.php`

| Query ID | HTTP | Recurso DBS | Tablas clave |
|----------|------|-------------|--------------|
| `getOrdenesTrabajo` | GET | `/ordenes-trabajo/empresa/{empr_id}` | `orden_trabajo`, `tbl_tipoordentrabajo`, `equipos` |
| `getOrdenesTrabajoPorTipo` | GET | `/ordenes-trabajo/empresa/{empr_id}/tipo/{tipo_id}` | ídem |
| `getOrdenTrabajo` | GET | `/ordenes-trabajo/{id_orden}` | `orden_trabajo` + joins |
| `setOrdenTrabajo` | POST | `/ordenes-trabajo` | `orden_trabajo` |
| `updateOrdenTrabajo` | PUT | `/ordenes-trabajo/{id_orden}` | `orden_trabajo` |
| `updateOrdenTrabajoEstado` | PUT | `/ordenes-trabajo/{id_orden}/estado` | `orden_trabajo` |
| `updateOrdenTrabajoCaseId` | PUT | `/ordenes-trabajo/{id_orden}/caseid` | `orden_trabajo` |
| `deleteOrdenTrabajo` | DELETE | `/ordenes-trabajo/{id_orden}` | `orden_trabajo` |
| `getOrdenTrabajoHerramientas` | GET | `/ordenes-trabajo/{id}/herramientas` | `tbl_otherramientas` |
| `getOrdenTrabajoInsumos` | GET | `/ordenes-trabajo/{id}/insumos` | `tbl_otinsumos`, `articles` |
| `setOrdenTrabajoHerramienta` | POST | `/ordenes-trabajo/herramientas` | `tbl_otherramientas` |
| `deleteOrdenTrabajoHerramienta` | DELETE | `/ordenes-trabajo/herramientas/{id}` | `tbl_otherramientas` |
| `setOrdenTrabajoInsumo` | POST | `/ordenes-trabajo/insumos` | `tbl_otinsumos` |
| `deleteOrdenTrabajoInsumo` | DELETE | `/ordenes-trabajo/insumos/{id}` | `tbl_otinsumos` |
| `getTiposOrdenTrabajo` | GET | `/ordenes-trabajo/lookup/tipos` | `tbl_tipoordentrabajo` |
| `getOrdenesServicio` | GET | `/ordenes-servicio/empresa/{empr_id}` | `orden_servicio`, `asignausuario` |
| `getOrdenServicio` | GET | `/ordenes-servicio/{id_orden}` | `orden_servicio` |
| `setOrdenServicio` | POST | `/ordenes-servicio` | `orden_servicio` |
| `getProveedores` | GET | `/ordenes-trabajo/lookup/proveedores` | `proveedores` |
| `getContratistas` | GET | `/ordenes-trabajo/lookup/contratistas` | `contratistas` |

**Total estimado: ~20 ops** ✓ dentro del límite.

> Si `orden_servicio` + RRHH crece, evaluar split en `MANEjecucionDataService`.

#### MANPreventivoDataService.dbs

Datasource: `AssetPlannerDataSource` | Fuente CI3: `Preventivos.php`, `Predictivos.php`

| Query ID | HTTP | Recurso DBS | Tablas clave |
|----------|------|-------------|--------------|
| `getPreventivos` | GET | `/preventivos/empresa/{empr_id}` | `preventivo`, `equipos`, `grupo`, `tareas`, `periodo` |
| `getPreventivo` | GET | `/preventivos/{prev_id}` | `preventivo` + detalle |
| `setPreventivo` | POST | `/preventivos` | `preventivo` |
| `updatePreventivo` | PUT | `/preventivos/{prev_id}` | `preventivo` |
| `deletePreventivo` | DELETE | `/preventivos/{prev_id}` | `preventivo` |
| `getPreventivoHerramientas` | GET | `/preventivos/{prev_id}/herramientas` | `tbl_preventivoherramientas` |
| `getPreventivoInsumos` | GET | `/preventivos/{prev_id}/insumos` | `tbl_preventivoinsumos` |
| `setPreventivoHerramienta` | POST | `/preventivos/herramientas` | `tbl_preventivoherramientas` |
| `deletePreventivoHerramienta` | DELETE | `/preventivos/herramientas/{id}` | `tbl_preventivoherramientas` |
| `setPreventivoInsumo` | POST | `/preventivos/insumos` | `tbl_preventivoinsumos` |
| `deletePreventivoInsumo` | DELETE | `/preventivos/insumos/{id}` | `tbl_preventivoinsumos` |
| `getPredictivos` | GET | `/predictivos/empresa/{empr_id}` | `predictivo`, `equipos` |
| `getPredictivo` | GET | `/predictivos/{pred_id}` | `predictivo` |
| `setPredictivo` | POST | `/predictivos` | `predictivo` |
| `updatePredictivo` | PUT | `/predictivos/{pred_id}` | `predictivo` |

**Total estimado: ~15 ops**

#### MANInsumoDataService.dbs

Datasource: `AssetPlannerDataSource` | Fuente CI3: `Ordeninsumos.php`

| Query ID | HTTP | Recurso DBS | Tablas clave |
|----------|------|-------------|--------------|
| `getStockAP` | GET | `/insumos/stock/empresa/{empr_id}` | `tbl_lote`, `articles`, `abmdeposito` |
| `getStockDeposito` | GET | `/insumos/stock/deposito/{dep_id}` | `tbl_lote`, `articles` |
| `getDepositos` | GET | `/insumos/depositos/empresa/{empr_id}` | `abmdeposito` |
| `getArticulos` | GET | `/insumos/articulos` | `articles`, `tbl_lote` |
| `getOrdenesInsumos` | GET | `/insumos/ordenes/empresa/{empr_id}` | `orden_insumos` |
| `getOrdenInsumo` | GET | `/insumos/ordenes/{ord_id}` | `orden_insumos`, `deta_ordeninsumos` |
| `setOrdenInsumo` | POST | `/insumos/ordenes` | `orden_insumos` |
| `setDetalleOrdenInsumo` | POST | `/insumos/ordenes/detalle` | `deta_ordeninsumos` |

**Total estimado: ~8 ops**

---

### Sequences nuevas a crear

Archivo destino: `.../src/main/wso2mi/artifacts/sequences/`

| Sequence | Recurso en toolsMANAPI | Descripción | Complejidad |
|----------|----------------------|-------------|-------------|
| `createOTCorrectivaSequence` | POST `/tools/man/solicitudes` | INSERT `solicitud_reparacion` → POST Bonita → UPDATE `case_id` | Alta (BPM + 2 DBs) |
| `createOTProgramadaSequence` | POST `/tools/man/ordenes-trabajo` | INSERT `orden_trabajo` (tipo programada) → POST Bonita → UPDATE `case_id` | Alta |
| `createPreventivoCargadoSequence` | POST `/tools/man/preventivos` | INSERT `preventivo` + herramientas + insumos | Media (3 INSERTs) |
| `insertLecturaSequence` | POST `/tools/man/equipos/{id}/lecturas` | INSERT `historial_lecturas` + UPDATE `equipos.ultima_lectura` | Baja (2 tablas) |
| `createOrdenInsumoSequence` | POST `/tools/man/insumos/ordenes` | INSERT cabecera + N líneas de detalle | Media |
| `getCalendarioMesSequence` | GET `/tools/man/calendario/mes/{mes}/year/{year}` | Agrega OTs + Preventivos + Predictivos + Backlogs del mes | Media (4 calls DBS) |

`createOTCorrectivaSequence` y `createOTProgramadaSequence` reutilizan `bpmAPICallTemplate` de `toolsBPMAPI.xml`.

---

### Extensión de toolsMANAPI.xml

Nuevos recursos a agregar bajo `/tools/man`:

```
# Equipos
GET  /tools/man/equipos/empresa/{empr_id}
GET  /tools/man/equipos/{equi_id}
POST /tools/man/equipos
PUT  /tools/man/equipos/{equi_id}
DELETE /tools/man/equipos/{equi_id}
GET  /tools/man/equipos/{equi_id}/componentes
GET  /tools/man/equipos/{equi_id}/lecturas/desde/{fi}/hasta/{ff}
GET  /tools/man/equipos/lookup/{tipo}          → criticidades, grupos, sectores, herramientas

# OTs
GET  /tools/man/ordenes-trabajo/empresa/{empr_id}
GET  /tools/man/ordenes-trabajo/empresa/{empr_id}/tipo/{tipo_id}
GET  /tools/man/ordenes-trabajo/{id_orden}
POST /tools/man/ordenes-trabajo                → createOTProgramadaSequence
PUT  /tools/man/ordenes-trabajo/{id_orden}/estado
GET  /tools/man/ordenes-servicio/empresa/{empr_id}

# Preventivos
GET  /tools/man/preventivos/empresa/{empr_id}
GET  /tools/man/preventivos/{prev_id}
POST /tools/man/preventivos                    → createPreventivoCargadoSequence
PUT  /tools/man/preventivos/{prev_id}
GET  /tools/man/preventivos/{prev_id}/herramientas
GET  /tools/man/preventivos/{prev_id}/insumos

# Stock AP / Insumos
GET  /tools/man/insumos/stock/empresa/{empr_id}
GET  /tools/man/insumos/stock/deposito/{dep_id}
GET  /tools/man/insumos/ordenes/empresa/{empr_id}
POST /tools/man/insumos/ordenes                → createOrdenInsumoSequence

# Calendario / Planificación
GET  /tools/man/calendario/mes/{mes}/year/{year}  → getCalendarioMesSequence
```

---

### Diferidos a Python Phase 2

| Funcionalidad | Modelo origen | Razón |
|---------------|--------------|-------|
| Disponibilidad con historial de estados | `Kpis.php`: `estadoEquipoAlta/Baja` | Lógica iterativa sobre historial de registros |
| PMs disparados por horas | `Preventivos.php`: `revisaEstadoPreventivosPorHoras` | Evaluación de umbrales con historial |
| Análisis predictivo / condición | `Predictivos.php` | Requiere modelos ML |
| Alertas por límites de parámetros | `Lecturas.php`: `setupparam` | Comparación dinámica contra umbrales configurados |

---

## Notas de campo

- **Base MySQL `assetv2`**: Todos los modelos usan `AssetPlannerDataSource` (host `10.142.0.13:3306`). Credenciales en texto plano en el XML del datasource — ver security flag en `inventory-2026.md`.
- **`orden_trabajo` es la tabla central**: todas las vistas de OT (correctiva, programada, preventivo, predictivo, backlog) filtran esta tabla por `tipo` via `tbl_tipoordentrabajo`. El `MANOrdenTrabajoDataService` debe exponer siempre el parámetro `tipo` para que el frontend filtre correctamente.
- **`historial_lecturas`**: tabla pivote entre Lecturas, KPIs y cierre de OTs. Verificar índices en `(id_equipo, fecha)` antes de migrar.
- **`sisusers`**: referenciada en múltiples modelos; confirmar si existe en `assetv2` o requiere JOIN cross-DB a `tools_prod_t`.
- **Bonita BPM**: `createOTCorrectivaSequence` y `createOTProgramadaSequence` requieren crear el caso en Bonita. El manejo de sesión (cookie + refresh en 401) ya está implementado en `bpmAPICallTemplate` de `toolsBPMAPI.xml`.
- **`Calendarios.php` duplica lógica de otros modelos**: los métodos `guardar_agregar`, `setCaseidenOT`, `cambiarEstado` son duplicados funcionales de `Otrabajos.php`. En v3 el calendario llama a los mismos endpoints de `toolsMANAPI.xml` que el resto del sistema.
