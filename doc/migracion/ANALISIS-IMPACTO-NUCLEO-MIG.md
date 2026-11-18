# Análisis de impacto: cambios del núcleo en el segundo tramo de la migración de AssetPlanner

## Objetivo

Lista, uno por uno, los cambios del núcleo que trae el segundo tramo de la migración de AssetPlanner a
Mantenimiento (MAN), comparados con producción (`master`). Es para que el PM los apruebe antes de unir los PR a
`develop-v3`, como pide la regla del núcleo de `CLAUDE.md`. No cubre cómo se migró cada pantalla: eso está en
[MIGRACION-ASSETPLANNER.md](MIGRACION-ASSETPLANNER.md). Tampoco cubre la unificación posterior con `develop`.

**Fecha:** 2026-11-16 · **Estado:** aprobado por el PM el 2026-11-16 (ver punto 5). Los PR siguen sin unir.

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
| 9 | `MANDataService.dbs`: 23 consultas sin parámetros repetidos (agregado el 2026-11-18, después del despliegue de `v3.0` en DEMO) | Integrador | 🟡 | Aprobado por el PM el 2026-11-18; va en `v3.0.0.1` |
| 10 | `MANDataService.dbs`: el registro del caso de la solicitud no falla si ya existe, y `equipos.numero_serie` pasa a texto (2026-11-18) | Solicitud de servicio, alta de equipo | 🟡 | Aprobado por el PM el 2026-11-18; va en `v3.0.0.2`. El script de la columna se aplica a mano (paso 10) |

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
- **Decisión del PM (2026-11-16):** en DEMO y en producción se aplica `v2.8.1.7`, no `v2.8.1.5`. Los roles de
  Residuos van: Residuos corre en una instancia propia, instalada en el cliente, y por eso no están en `master`.
- **Dónde está:** la carpeta `v2.8.1.7/` se trajo de `develop-v3.5` (2026-11-17) con dos de sus scripts, los
  que necesita el alta de empresa. El tercero de esa versión, `hitos_numero_por_pedido.sql`, **no** se trajo:
  necesita un cambio del servicio de Tareas (`TARDataService`, `setHito`) que está solo en `develop-v3.5`.
  Análisis de esa versión: [`doc/analisis/impacto-alta-empresa-pedidos-trabajo.md`](../analisis/impacto-alta-empresa-pedidos-trabajo.md).

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
- **Ojo en cada servidor:** `constants.php` se edita en el servidor y el script de despliegue lo restaura desde
  el respaldo, así que estas líneas van a mano en DEMO y producción, sin pisar los valores propios de cada
  ambiente. **Corrección del 2026-11-18:** este punto decía "dos líneas" y son tres, más una que tiene que estar.
  En DEMO faltaban `MAN` y `REST_MAN`, y Mantenimiento no funcionaba:
  - `define('MAN', 'traz-tools-man/');`, junto a `#COMPONENTE MANTENIMIENTO`. Ya está en `master`, pero el
    `constants.php` de DEMO no la tenía. Sin ella las pantallas de MAN llaman a `/traz-tools/MANEquipo/...` y
    dan error de ajax;
  - `define('REST_MAN', HOST.'/services/MANDataService');`, después de la línea que define `HOST`. Sin ella
    las pantallas de MAN no traen datos;
  - `define('MAN_DIAS_LANZAMIENTO', 7);`;
  - la fila de Mantenimiento en la lista de procesos de la bandeja, la que empieza con
    `BPM_PROCESS_ID_MANTENIMIENTO =>`.
  - Para revisar qué tiene un servidor, parado en su htdocs:
    `grep -n "define('MAN'\|REST_MAN\|MAN_DIAS\|BPM_PROCESS_ID_MANTENIMIENTO =>" traz-tools/application/config/constants.php`

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
- **Decisión del PM (2026-11-16):** se prueba directamente en el integrador de DEMO, al hacer el pasaje (paso 3
  del despliegue). Si lo rechaza, no se sigue con los pasos siguientes.

### 2.8 Pañol — `traz-comp-pan`, `models/Orders.php`

- **Qué cambia:** al asociar un vale a una orden y al listar las órdenes sin cerrar, manda el número de empresa
  y de usuario de asset (`man_empresa()` y `man_usuario()`) en vez del de Tools. Asset los numera distinto, y
  con el de Tools el vale no aparecía en la orden.
- **Qué podría romper:** usa el helper `man` del módulo `traz-tools-man`. Si se mueve el puntero de
  `traz-comp-pan` en `develop` antes de que llegue MAN, esas dos funciones fallan. En este PR el puntero se
  mueve solo en la rama que va a `develop-v3`.

### 2.9 Consultas sin parámetros repetidos — `MANDataService.dbs` (2026-11-18)

- **Qué pasó en DEMO:** con `v3.0` desplegada, dar de alta un equipo devolvía "Error al guardar equipo". El
  integrador de DEMO (EI 6.5) respondía `Error in 'SQLQuery.processPreNormalQuery': null`
  (NullPointerException) **antes** de ejecutar la sentencia. Se investigó en el servidor solo con lecturas: el
  EI 6.5 rechaza cualquier consulta que use el mismo parámetro con nombre (`:id_empresa`, `:buscar`...) más
  de una vez, en GET y en POST. Las mismas consultas sin repeticiones funcionan. El MI local lo acepta, y por
  eso no se vio en desarrollo.
- **Qué cambia:** 23 consultas nuevas de MAN que repetían parámetros. Cada parámetro repetido se liga una sola
  vez en una tabla derivada, `(SELECT :id_empresa AS p_id_empresa) param`, y el resto de la consulta usa
  `param.p_id_empresa`. Es la forma que ya usan los servicios de datos de producción. En los `UPDATE` la
  derivada va primera (`UPDATE (SELECT ...) param CROSS JOIN tabla ...`), así la pueden usar los `ON` que
  siguen. Los parámetros que aparecen una sola vez quedan igual; por ejemplo, `LIMIT :inicio, :cantidad`.
- **Consultas:** altas y cambios de equipo, orden de trabajo, preventivo, predictivo y backlog; asociación de
  componente; asignación de la orden del plan; listados de equipos, órdenes, solicitudes, tareas activas y
  componentes del backlog; lecturas vecinas; y los 4 reportes.
- **Qué no cambia:** lo que devuelve cada consulta, los recursos, sus rutas y los parámetros que reciben.
  También queda igual el control de que el equipo, el sector, el grupo y los demás datos sean de la misma
  empresa.
- **Cómo se verificó:** en una MariaDB 10.6 local con el esquema de asset (`asp_full_after_clean_v223.sql`,
  completado con las columnas nuevas), cada consulta nueva contra la original, con los mismos valores. En los
  49 casos dan el mismo resultado, y las altas y cambios afectan las mismas filas. No se pudo probar en un
  EI 6.5: la prueba de verdad es DEMO después de desplegar `v3.0.0.1`. La MariaDB de DEMO es la 10.1; la
  sintaxis que se usa existe desde mucho antes.
- **Control nuevo:** `scripts/ci/dbs-sin-parametros-repetidos.py`, que corre en cada PR que toca un `.dbs`
  (`.github/workflows/dbs-validate.yml`). Deja pasar 3 consultas que ya estaban así en `master` y no se tocan
  acá (H54).

### 2.10 Registro del caso de la solicitud — `MANDataService.dbs`, `setCaseEmpresaAssetMan` (2026-11-18)

- **Qué pasó en DEMO:** al generar una solicitud de servicio, la API respondía "no se pudo registrar el caso;
  se borraron el caso y la solicitud". El servicio de datos devolvía `Duplicate entry '<caso>' for key
  'PRIMARY'` en `case_empresa`.
- **Por qué:** la base de asset de DEMO tiene el disparador `solicitud_servicio_case_empreas_au_trg`
  (`AFTER UPDATE` en `solicitud_reparacion`), que registra el caso en `case_empresa` cuando se le pone el
  `case_id` a la solicitud. Después la API intenta registrarlo de nuevo y falla. **La base de asset de
  producción no tiene ese disparador** (consultado por el PM el 2026-11-18): ahí el registro lo tiene que hacer
  la API. La base de desarrollo no se pudo consultar (sin VPN).
- **Qué cambia:** la consulta que registra el caso pasa a `INSERT ... ON DUPLICATE KEY UPDATE empr_id =
  VALUES(empr_id)`. Si el caso no está, lo agrega; si ya lo agregó el disparador, deja la empresa que manda la
  API y no falla. Funciona igual con disparador y sin él.
- **Cómo se verificó:** en la MariaDB local, la misma fila dos veces (la segunda no cambia nada) y con otra
  empresa (queda la que manda la API). No se tocó el disparador de DEMO ni nada de producción.

## 3. Pasos de despliegue (cuando se unifique con `develop` y se pase a DEMO)

No hacer ninguno de estos pasos antes de que el PM apruebe este análisis.

**Arreglo `v3.0.0.1` (2026-11-18):** se despliega con la metodología de siempre: tag `v3.0.0.1` en `develop` y
`sh traz-tools/scripts/deploy/deploytools.sh v3.0.0.1 traz-tools` desde el htdocs del servidor de DEMO. Los
pasos 2 a 8 ya se hicieron con `v3.0` y no se repiten. Lo que hay que verificar es que `constants.php` siga
teniendo las líneas del paso 2, porque el script lo restaura desde el respaldo.

| # | Qué | Dónde se ejecuta |
|---|---|---|
| 1 | Código de Tools y de los módulos | Servidor de DEMO, con el script de despliegue habitual |
| 2 | Revisar y agregar las líneas de `constants.php` que falten: `MAN`, `REST_MAN`, `MAN_DIAS_LANZAMIENTO` y la fila de Mantenimiento de la bandeja (punto 2.5) | Servidor de DEMO, editando el archivo a mano |
| 3 | Desplegar el `.car` con `MANDataService` y `toolsMANAPI`. Es la primera prueba en un EI 6: si lo rechaza, parar | Integrador de DEMO |
| 4 | Aplicar, en este orden, `v2.8.1.7/pedidos_sin_formulario.sql` y `v2.8.1.7/configuracion_inicial_empresa_trg_func.sql`. **No** aplicar `v2.8.1.5` | Base PostgreSQL de DEMO, con un cliente de PostgreSQL |
| 5 | Aplicar `asset-empresa-trigger.sql` | Base MariaDB de asset de DEMO, con un cliente de MySQL |
| 6 | Aplicar `kpi-mantenimiento.sql` | Base MariaDB de asset de DEMO |
| 7 | Cargar las opciones de menú de MAN | Base PostgreSQL de DEMO; ver [MENU-MAN.md](MENU-MAN.md) |
| 8 | Tarea programada que lanza las órdenes preventivas pendientes | Servidor de DEMO; ver `doc/infra/man-lanzamiento-cron.md` |
| 9 | Prueba completa de DocTest contra DEMO | Máquina local, desde `doctest/`: `node scripts/doctest.mjs full --entorno demo` |
| 10 | Pasar el número de serie del equipo a texto: `_backend/database/scripts/assetplanner/equipos-numero-serie-texto.sql` (H53). **Va también en producción**, en la base de asset, antes de habilitar Mantenimiento: sin esto, un número de serie con letras hace fallar el alta del equipo | Base MariaDB de asset de cada instalación, con un cliente de MySQL |

## 4. Qué no se probó

- Nada de esto corrió en DEMO ni en el integrador de producción (EI 6.x). La prueba completa del 2026-11-05
  (204 pruebas, 0 fallas) usó el MI 4.5 local y las bases de desarrollo.
- Todavía no se unificó con `develop`.
- Errores conocidos de MAN que siguen abiertos: H-122 (un plan recién creado no se puede editar) y E14
  (mantenimiento autónomo apagado).

## 5. Decisiones del PM (2026-11-16)

1. ✅ Aprobados los cambios 1, 2 y 4 a 8.
2. ✅ El alta de empresa se despliega con `v2.8.1.7`, no con `v2.8.1.5`. Los roles de Residuos van, porque
   Residuos usa una instancia propia en el cliente.
3. ✅ El `.car` se prueba en el integrador de DEMO, durante el pasaje.

Aprobar el análisis no es aprobar la unión de los PR: eso lo confirma el PM aparte.
