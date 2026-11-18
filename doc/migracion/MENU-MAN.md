# Menú de Mantenimiento (MAN) en tools

## Objetivo

Dice qué opciones de menú tiene el módulo de Mantenimiento en tools, cómo se le da el menú a una empresa y qué hay cargado hoy en la
base de **desarrollo**. Está escrito para quien tenga que repetirlo en TEST o PRODUCCIÓN, o darle el menú a otra empresa o usuario. No
cubre los permisos finos por pantalla (agregar, editar, borrar): eso es MIG-5 (ver [MIGRACION-ASSETPLANNER.md](MIGRACION-ASSETPLANNER.md)).

## Cómo funciona

- Las opciones salen de `seg.menues` (módulo `MAN`). Cada una tiene su `url`, que es lo que abre el menú.
- Quién ve cada opción lo dice `seg.memberships_menues` (módulo, opción, **grupo** = empresa, **rol**). Con el rol vacío, la opción la
  ve todo usuario del grupo. El usuario y su grupo salen de `seg.memberships_users`. La vista `seg.menues_users_vw` junta todo.
- **Permisos en la URL (E3):** cada pantalla de MAN recibe las acciones en la URL, como en asset (`.../Equipo/index/Add-Edit-Del-Lectura`).
  Si la URL no las trae, la pantalla queda de solo lectura (sin botones de agregar, editar ni borrar). Hasta MIG-5 el menú los trae fijos.
- **La empresa tiene que estar vinculada** con los datos de Mantenimiento: `core.empresas.empr_id_mysql` con el número de empresa de
  `assetv2`. Sin eso, las pantallas dicen "La empresa no está vinculada con Mantenimiento".

## Las opciones (módulo MAN)

| Opción | Texto | URL |
|---|---|---|
| `mantenimiento` | Mantenimiento (padre) | — |
| `equipos` | Equipos | `traz-tools-man/Equipo/index/Add-Edit-Del-Lectura` |
| `bandeja` | Bandeja de Tareas (nueva, 2026-10-30) | `traz-tools-man/Tarea/index/Add-Edit-Del` |
| `componentes` | Componentes | `traz-tools-man/Componente/asigna/Add-Edit-Del` |
| `solicitud_servicio` | Solicitud de Servicio | `traz-tools-man/Sservicio/index/Add-Edit-Del` |
| `informe_servicios` | Informe de Servicios | `traz-tools-man/Ordenservicio/index/Add-Edit-Del` |
| `preventivo` | Preventivo | `traz-tools-man/Preventivo/index/Add-Edit-Del` |
| `parametrizar_predictivo` | Parametrizar Predictivo | `traz-tools-man/Parametro/index/Add-Edit-Del` |
| `backlog` | Backlog | `traz-tools-man/Backlog/index/Add-Edit-Del` |
| `predictivo` | Predictivo | `traz-tools-man/Predictivo/index/Add-Edit-Del` |
| `ordenes_trabajo` | Ordenes de Trabajo | `traz-tools-man/Otrabajo/listOrden/Add-Edit-Del` |
| `plan_mantenimiento` | Plan de Mantenimiento | `traz-tools-man/Calendario/indexot/Add-Edit-Del` |
| `registro_parametros` | Registro de Parametros | `traz-tools-man/Lectura/index/Add-Edit-Del` |
| `administrar_ordenes` | Administrar Ordenes | `traz-tools-man/Envio/index/Add-Edit-Del` |
| `rep_equipo` | Rep Equipo (reporte de disponibilidad de equipos, nuevo 2026-11-02) | `traz-tools-man/Kpi/index/Add-Edit-Del` |
| `rep_informe_servicios` | Rep Informe de Servicios (reporte de solicitudes, preventivos y backlog con su informe, nuevo 2026-11-02) | `traz-tools-man/Reporte/index/Add-Edit-Del` |
| `rep_ordenes_trabajo` | Rep Ordenes de trabajo (listado de órdenes filtrable por equipo, estado y fecha, con Excel; nuevo 2026-11-02) | `traz-tools-man/Reporteorden/index/Add-Edit-Del` |
| `abm_man` | ABM de Mantenimiento (padre, nuevo 2026-10-31) | — |
| `abm_area`, `abm_proceso` | Área, Procesos | `traz-tools-man/Area/index/Add-Edit-Del`, `.../Proceso/...` |
| `abm_grupo`, `abm_sector`, `abm_contratista` | Grupo, Sector, Contratista | `traz-tools-man/Grupo/index/Add-Edit-Del`, `.../Sector/...`, `.../Contratista/...` |
| `abm_tarea_estandar` | Tareas estándar | `traz-tools-man/Tareaestandar/index/Add-Edit-Del` |
| `abm_parametros`, `abm_familia`, `abm_marca` | Parámetros, Familia, Marca | `traz-tools-man/Altparametro/...`, `.../Family/...`, `.../Marca/...` |
| `abm_clientes`, `abm_criticidad` | Clientes, Criticidad | `traz-tools-man/Cliente/...`, `.../Criticidad/...` |
| `abm_sucursales`, `abm_sistemas` | Sucursales, Sistemas | `traz-tools-man/Sucursal/...`, `.../SistemaABM/...` |

## Lo que se cargó en desarrollo (2026-10-30)

Se ejecutó contra la base de tools de desarrollo (PostgreSQL, esquema `seg`), desde una terminal con `psql` y la conexión de desarrollo:

1. **Menú para la empresa de prueba.** Una fila por opción en `seg.memberships_menues` con grupo `Empresa_Test` y rol vacío (las 14 de la
   tabla, `usuario_app` = `migracion-man`). Con eso lo ve todo usuario de `Empresa_Test`, entre ellos `mig.man.a@trazalog.test`.
2. **URLs con permisos** (la columna de arriba) en `seg.menues`.
3. **Opción nueva `bandeja`** en `seg.menues` (orden 105, padre `mantenimiento`): la Bandeja de Tareas de asset ya migrada. El menú
   "Mis Tareas" que ya tenía tools es otra bandeja (la de tools).

Para dar el menú a otra empresa, repetir el punto 1 con su grupo (el nombre de la empresa en `seg.memberships_users`) y vincular la
empresa (`core.empresas.empr_id_mysql`). Esa vinculación toca una tabla central: necesita aprobación del PM.

## Datos de ejemplo

Para ver las pantallas con contenido hay dos scripts en `application/modules/traz-tools-man/tests/` (repositorio del módulo):
`seed_demo_man.py` (equipos con cliente, planes, órdenes, informes y lecturas, todo en la empresa 1 de `assetv2`) y
`seed_demo_bonita.py` (tres solicitudes con su caso real de Bonita). Los dos se borran con `--borrar`.

## ABMs (2026-10-31)

Se cargó el submenú "ABM de Mantenimiento" (13 opciones hijas de `abm_man`, más el padre) en `seg.menues` y `seg.memberships_menues`
(grupo `Empresa_Test`, rol vacío, `usuario_app` = `migracion-man`), con el mismo procedimiento de arriba. Se ejecutó desde una terminal
con `psql` contra la base de tools de desarrollo.

## Empresas nuevas (2026-11-04)

Desde esta fecha, en la base de **desarrollo**, una empresa nueva recibe el menú sola: lo carga `core.configuracion_inicial_empresa_trg`
al crearse la empresa, en un bloque propio. Si en un ambiente faltan las opciones MAN, el error no afecta al resto de los menús.

Regla del menú: si un rol tiene la opción padre y ninguna hija, ve todas las hijas. Si tiene alguna hija, ve solo esas.

| Rol que crea la registración | Grupo equivalente en asset | Qué ve |
|---|---|---|
| Administrador | Admin | Todo: filas `mantenimiento` y `abm_man` |
| Supervisor de Mantenimiento, Planificador de Mantenimiento | Supervisor de Taller | 23 opciones, las de asset más la bandeja y `rep_equipo`. No ven Predictivo, Parametrizar Predictivo, Registro de Parametros ni Administrar Ordenes |
| Solicitante de Mantenimiento | Solicitante | `bandeja`, `equipos`, `solicitud_servicio`, `informe_servicios`, `preventivo`, `backlog` |
| Responsables de Almacén y de Pañol, Solicitante de Almacén | Solicitante | No reciben menú MAN: en asset van a ese grupo solo para no entrar a un menú vacío |

Atención: hasta MIG-5 los permisos van fijos en la URL del menú, así que un Solicitante puede editar lo que en asset solo podía mirar.

**Para repetirlo en TEST o PRODUCCIÓN**, desde una terminal con `psql` conectada a la base de tools de ese ambiente, después de cargar
las opciones MAN en `seg.menues`:

```bash
psql -f _backend/database/scripts/versiones/v2.8.1.5/configuracion_inicial_empresa_trg_func.sql
```

El script parte de la función de **desarrollo**: antes de correrlo, comparala con la de ese ambiente. Solo alcanza a las empresas que se
creen después. Las que ya existen se cargan aparte, como en el punto 1 de arriba.

La unidad industrial por defecto es otro cambio, en la base de Mantenimiento (`assetv2`): ver H49 en
[HALLAZGOS-POST-MIGRACION.md](HALLAZGOS-POST-MIGRACION.md) y `development/sql/asset-empresa-trigger.sql`.
