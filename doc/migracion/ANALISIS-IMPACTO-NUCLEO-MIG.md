# Análisis de impacto: cambios del núcleo en el segundo tramo de la migración de AssetPlanner

## Objetivo

Lista, uno por uno, los cambios del núcleo que trae el segundo tramo de la migración de AssetPlanner a
Mantenimiento (MAN), comparados con producción (`master`). Es para que el PM los apruebe antes de unir los PR a
`develop-v3`, como pide la regla del núcleo de `CLAUDE.md`. No cubre cómo se migró cada pantalla: eso está en
[MIGRACION-ASSETPLANNER.md](MIGRACION-ASSETPLANNER.md). Tampoco cubre la unificación posterior con `develop`.

**Fecha:** 2026-11-16 · **Estado:** esperando aprobación del PM.

**PR involucrados:**

- Trazalog/traz-tools-man#8: pantallas de MAN, 31 cambios, va a `develop-v3`.
- Trazalog/traz-comp-pan#33: vale de pañol, va a `develop`, porque ese repositorio no tiene `develop-v3`.
- PR de `traz-tools` que trae este documento: servicios del integrador, scripts de base, núcleo y punteros a
  los dos módulos.

## 1. Resumen

Se compararon con `master` todos los archivos del núcleo que cambian. En `develop-v3` esos archivos son
iguales a `master`, salvo una línea de `constants.php` que no tiene que ver con esto. Por eso la diferencia con
producción es exactamente la que se lista acá.

| # | Cambio | Qué toca | Riesgo | Recomendación |
|---|---|---|---|---|
| 1 | `toolsCOREAPI.xml`: la consulta de usuario duplicado sale como GET limpio (H47) | Alta de usuarios | 🟡 | Ya aprobado el 2026-11-04 a condición de no romper en EI 6. Falta probar en EI 6 |
| 2 | `sesion_helper.php`: al vencer la sesión, se redirige al ingreso | Todas las pantallas | 🟢 | Aprobar |
| 3 | Script del alta de empresa `v2.8.1.5` (PostgreSQL) | Registración de empresas | 🔴 | **No aplicarlo.** Usar `v2.8.1.7` |
| 4 | `asset-empresa-trigger.sql` (MariaDB de asset) | Alta de empresa en asset | 🟡 | Aprobar; afecta también al asset de producción |
| 5 | `constants.php`: Mantenimiento en la bandeja y días de anticipación | Bandeja de tareas | 🟢 | Aprobar |
| 6 | Tablero: 4 indicadores de MAN (`dashboard.php`, `Dashs.php`, `dashboard_kpis.js`, `kpi-mantenimiento.sql`) | Tablero del administrador | 🟢 | Aprobar; sin el script de base los recuadros muestran 0 |
| 7 | `MANDataService.dbs` y `toolsMANAPI.xml` | Integrador | 🟡 | Aprobar; solo agregan recursos. Falta probar en EI 6 |
| 8 | `traz-comp-pan`: el vale usa la numeración de empresa de MAN | Pañol | 🟡 | Aprobar; no mover el puntero en `develop` antes de que llegue MAN |

## 2. Cambio por cambio

### 2.1 Consulta de usuario duplicado (H47) — `toolsCOREAPI.xml`

- **Qué cambia:** antes de crear un usuario, `POST /usuario` consulta si ya existe. Esa consulta ahora sale
  como GET sin cuerpo y sin `Content-Type`. Son 6 líneas que solo agregan cosas.
- **Por qué:** en el WSO2 MI 4.x la consulta heredaba el `Content-Type` del POST. El servicio de datos buscaba
  los parámetros en el cuerpo y el alta de usuarios fallaba.
- **Qué lo usa:** todas las altas de usuario de Tools.
- **Estado:** el PM lo aprobó el 2026-11-04 a condición de no romper en EI 6. Está probado en el MI 4.5
  local; en EI 6 no, porque no hay uno disponible. Las propiedades que usa son de Synapse y existen también en
  EI 6, pero eso es un supuesto propio, no una prueba. Detalle en
  [impacto-alta-usuario-consulta-con-cuerpo.md](../analisis/impacto-alta-usuario-consulta-con-cuerpo.md).

### 2.2 Sesión vencida — `application/helpers/sesion_helper.php`

- **Qué cambia:** hoy, cuando vence la sesión, se escribe la dirección del ingreso como texto y se corta.
  Ahora eso pasa solo en las llamadas internas de las pantallas (AJAX), que leen esa dirección y redirigen
  ellas. Si la persona navega directo, la manda al ingreso en vez de dejarle el texto en pantalla.
- **Qué lo usa:** cualquier pantalla de Tools con la sesión vencida.
- **Qué podría romper:** una llamada interna que no se identifique como AJAX (sin el encabezado
  `X-Requested-With`) recibiría la página de ingreso en vez del texto. Las llamadas de Tools usan jQuery, que
  manda ese encabezado. En `application/` no hay llamadas con `fetch()`.
- **Riesgo:** bajo.

### 2.3 Alta de empresa en PostgreSQL — `v2.8.1.5/configuracion_inicial_empresa_trg_func.sql` 🔴

- **Qué cambia:** agrega un bloque que le da el menú de Mantenimiento a los roles de la empresa nueva (H46).
- **El problema:** el script se armó copiando la función de la **base de desarrollo**, no la de `master`.
  Comparado con `master` (`v2.8.1.3`):
  - **le falta el bloque que clona el formulario "Entrega Materiales" de la empresa 9000**, que está en
    producción desde el 2026-09-13. Si se aplica, las empresas nuevas se quedan sin ese formulario y no pueden
    entregar materiales desde el almacén;
  - agrega cuatro roles de Residuos que `master` no tiene. Venían de la base de desarrollo; no sé si
    producción los tiene.
- **La versión buena ya existe:** `v2.8.1.7`, en `develop-v3.5`, del 2026-11-11. Tiene los cuatro bloques:
  formulario de la 9000, menú de MAN, roles de Residuos y proceso estándar de Tareas.
- **Qué hice:** en este PR le agregué al script `v2.8.1.5` un aviso al principio que dice que no se aplique en
  test ni en producción. No borré el archivo.
- **No verificado:** qué versión de la función tiene hoy la base de desarrollo. El encabezado del script dice
  que `v2.8.1.5` se aplicó ahí el 2026-11-04. Si después no se aplicó `v2.8.1.7`, desarrollo no está clonando
  el formulario.
- **Decisión del PM:** confirmar que en DEMO y en producción se aplica `v2.8.1.7` y no `v2.8.1.5`, y si los
  roles de Residuos tienen que estar.

### 2.4 Alta de empresa en asset — `development/sql/asset-empresa-trigger.sql`

- **Qué cambia:** el disparador de MariaDB que corre al dar de alta una empresa en asset ahora le crea además
  una unidad industrial por defecto y cinco períodos (Diario, Mensual, Anual, Horas y Ciclos). Sin la unidad,
  el equipo se guarda pero no aparece en los listados; sin los períodos, no se puede crear un preventivo.
- **Qué lo usa:** `POST /empresa` de `toolsCOREAPI`, que da de alta la empresa en asset. **Es la misma base
  que usa el AssetPlanner de producción.**
- **Qué podría romper:** nada de lo existente. La unidad usa `INSERT IGNORE`; si el número ya está usado, no
  frena el alta. Una empresa nueva en asset arrancaría con esos cinco períodos ya cargados.
- **Se aplica a mano**, con un cliente de MySQL, sobre la base de asset de cada instalación. No lo despliega
  ningún script.

### 2.5 Constantes — `application/config/constants.php`

- **Qué cambia:**
  - agrega el proceso de Mantenimiento a la lista de procesos de la bandeja de tareas. La constante del
    proceso, `BPM_PROCESS_ID_MANTENIMIENTO`, ya está en `master` con el mismo valor;
  - agrega `MAN_DIAS_LANZAMIENTO = 7`, que solo se usa si la configuración `man_dias_lanzamiento` de
    `core.tablas` no tiene un valor válido.
- **Qué podría romper:** nada de lo existente. La bandeja empieza a mostrar las tareas de Mantenimiento.
- **Ojo en cada servidor:** `constants.php` se edita en el servidor. Hay que agregar estas dos líneas a mano
  en DEMO y producción, sin pisar los valores propios de cada ambiente.

### 2.6 Tablero del administrador

- **Qué cambia:** cuatro recuadros nuevos de MAN (MTTR, MTTF, MTBF y confiabilidad) en `dashboard.php` y
  `dashboard_kpis.js`. Además, `Dashs.php` devuelve el valor también con el nombre `valor`, sin sacar el
  anterior.
- **Depende de** `_backend/database/scripts/assetplanner/kpi-mantenimiento.sql`, que se ejecuta en la base de
  asset y agrega cuatro consultas al cálculo de indicadores. Sin ese script los recuadros muestran 0.
- **Qué podría romper:** nada de lo existente.

### 2.7 Servicios del integrador — `MANDataService.dbs` y `toolsMANAPI.xml`

- **Qué cambia:** unas 4.500 líneas que solo agregan recursos para las pantallas de MAN. La única línea que se
  borra en `toolsMANAPI.xml` es un renglón en blanco. Las rutas que usa el MCP (`/tools/man/mcp/*`) no cambian.
- **Riesgo:** el EI 6.5 rechaza un servicio de datos con dos recursos iguales (ver
  `archivo/traspaso-migracion-assetplanner.md`). Todo se probó en el MI 4.5, que es más permisivo.
- **Antes de desplegar en DEMO:** armar el `.car` y desplegarlo en un EI 6 para ver que lo acepte.

### 2.8 Pañol — `traz-comp-pan`, `models/Orders.php`

- **Qué cambia:** al asociar un vale a una orden y al listar las órdenes sin cerrar, manda el número de empresa
  y de usuario de asset (`man_empresa()` y `man_usuario()`) en vez del de Tools. Asset los numera distinto, y
  con el de Tools el vale no aparecía en la orden.
- **Qué podría romper:** usa el helper `man` del módulo `traz-tools-man`. Si se mueve el puntero de
  `traz-comp-pan` en `develop` antes de que llegue MAN, esas dos funciones fallan. En este PR el puntero se
  mueve solo en la rama que va a `develop-v3`.

## 3. Pasos de despliegue (cuando se unifique con `develop` y se pase a DEMO)

No hacer ninguno de estos pasos antes de que el PM apruebe este análisis.

| # | Qué | Dónde se ejecuta |
|---|---|---|
| 1 | Código de Tools y de los módulos | Servidor de DEMO, con el script de despliegue habitual |
| 2 | Agregar las dos líneas de `constants.php` (punto 2.5) | Servidor de DEMO, editando el archivo a mano |
| 3 | Desplegar el `.car` con `MANDataService` y `toolsMANAPI` | Integrador de DEMO |
| 4 | Aplicar `v2.8.1.7` del alta de empresa, **no** `v2.8.1.5` | Base PostgreSQL de DEMO, con un cliente de PostgreSQL |
| 5 | Aplicar `asset-empresa-trigger.sql` | Base MariaDB de asset de DEMO, con un cliente de MySQL |
| 6 | Aplicar `kpi-mantenimiento.sql` | Base MariaDB de asset de DEMO |
| 7 | Cargar las opciones de menú de MAN | Base PostgreSQL de DEMO; ver [MENU-MAN.md](MENU-MAN.md) |
| 8 | Tarea programada que lanza las órdenes preventivas pendientes | Servidor de DEMO; ver `doc/infra/man-lanzamiento-cron.md` |
| 9 | Prueba completa de DocTest contra DEMO | Máquina local, desde `doctest/`: `node scripts/doctest.mjs full --entorno demo` |

## 4. Qué no se probó

- Nada de esto corrió en DEMO ni en el integrador de producción (EI 6.x). La prueba completa del 2026-11-05
  (204 pruebas, 0 fallas) usó el MI 4.5 local y las bases de desarrollo.
- Todavía no se unificó con `develop`.
- Errores conocidos de MAN que siguen abiertos: H-122 (un plan recién creado no se puede editar) y E14
  (mantenimiento autónomo apagado).

## 5. Lo que tiene que decidir el PM

1. Aprobar los cambios 1, 2 y 4 a 8.
2. Confirmar que el alta de empresa se despliega con `v2.8.1.7` y no con `v2.8.1.5`, y decir si los roles de
   Residuos tienen que estar en producción.
3. Elegir dónde se prueba el `.car` en un EI 6 antes de DEMO.
