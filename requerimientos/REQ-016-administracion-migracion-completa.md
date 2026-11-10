# REQ-016 · Módulo Administración — Migración completa

## Objetivo

Decimosexto trabajo de Pablo para el módulo **Administración** (`traz-comp-adm`): cerrar la migración de
datos de DNATO v3. Pasa **todas las empresas actuales al plan "Completo"** (M-3, para que nadie pierda nada),
junta en **un solo orden de ejecución por ambiente** las migraciones que REQ-004 a REQ-015 dejaron
repartidas (M-1 a M-7, M-4) y corre la **verificación final** (M-8, CP-M1) con un informe que dice si el
ambiente quedó listo. Lo leen Pablo para planificar y Rodolfo para aprobar los scripts y decidir el corte.
**No** hace el corte final (redirigir DNATO al módulo y apagarlo): se propone como requerimiento aparte con
su propio análisis de impacto (ver "Qué NO hace" y la duda de ADM-UC-272). Tampoco la migración de
formularios M-7b ([REQ-015](REQ-015-administracion-formularios.md)). Lista completa en
[`README.md`](README.md).

| Campo | Valor |
|---|---|
| Estado | **Borrador**: Rodolfo tiene que contestar las dudas de los casos (cuota del plan "Completo", ambientes, corte final) y aprobar los scripts |
| Se apoya en | [REQ-004](REQ-004-administracion-base-y-atributos.md) (M-1, M-2, M-5, M-6, M-7 y columnas `plan_id`, `estado_plan`, `plan_vence`, `uso_plan_gratuito`), [REQ-005](REQ-005-administracion-catalogo-y-planes.md) (`seg.planes`, `seg.planes_funcionalidades`, plan base), [REQ-008](REQ-008-administracion-consola-empresas.md) (columnas y variables nuevas), [REQ-009](REQ-009-administracion-menus.md) (M-4, comparación M-8, variable `menu_resuelto_en_tools`), [REQ-010](REQ-010-administracion-plan-y-pedidos.md) (plan base en el registro), [REQ-011](REQ-011-administracion-cuota-agente.md) (cuota), [REQ-013](REQ-013-administracion-actividad-y-auditoria.md), [REQ-014](REQ-014-administracion-cargas-masivas.md) y [REQ-015](REQ-015-administracion-formularios.md) (objetos de base nuevos) |
| Entrega de la especificación | **E12** de `doc/v3/dnato/PROMPT_CLI_DNATO_V3_BUILD.md`: migración completa (M-3 plan "Completo" y M-8 verificación) + corte según CI/CD. CP-M1; `02_MODELO_Y_REGLAS.md` §8 |
| Casos de uso | `ADM-UC-270` a `ADM-UC-272` en `doctest/catalogo/adm/` |
| Repos que se tocan | `traz-tools`: scripts de base de M-3, el orden de ejecución y el script de verificación (en `doc/v3/administracion/sql/` **[SUPUESTO]**, la carpeta que propuso REQ-004). `traz-comp-adm`: nada nuevo, salvo que la verificación use el servicio "Menú resuelto" de REQ-009 |
| Riesgo | 🔴 **Migración de datos; Rodolfo aprueba cada script antes de correrlo**: M-3 escribe `plan_id`, `estado_plan`, `plan_vence` y `uso_plan_gratuito` (columnas nuevas de REQ-004) en **todas** las empresas y crea filas en `seg.planes` y `seg.planes_funcionalidades` (lista en "Datos"). Se corre en todos los ambientes, producción incluida. Toca datos de `core.empresas` (núcleo, aunque solo columnas nuevas) → **análisis de impacto aprobado por Rodolfo** |

---

## Para qué sirve

- Desde REQ-004, `core.empresas.plan_id` es nulo en todas las empresas que ya existen, y cada requerimiento
  tuvo que decidir qué hacer "mientras no haya plan" (REQ-006 a REQ-013: "sin plan = todo, sin tope,
  ilimitado"). M-3 les da un plan **real** que dice exactamente eso, así esa excepción deja de hacer falta
  para las empresas existentes.
- Las migraciones quedaron en siete requerimientos distintos. Para correrlas en otro ambiente (producción,
  una copia nueva) hace falta **un orden único**, que se pueda repetir sin romper nada.
- Antes de cambiar a nadie de sistema hay que **probar** que nadie pierde nada: el menú de cada usuario es el
  mismo (CP-M1) y cada empresa quedó con plan, estados y funcionalidades.

## Quién lo usa

- **Superusuario**: corre (o pide correr) los scripts en cada ambiente y lee el informe de verificación.
- **Administrador** de una empresa existente: ve su empresa en el plan "Completo", sin perder nada.
- **Usuario** y los perfiles de operación (**Supervisor**, **Mantenedor**, etc.): siguen viendo el mismo
  menú.

## Qué tiene que hacer

1. Crear el plan "Completo" y pasar a él todas las empresas actuales; dejar el plan base (Freemium) para
   las nuevas (M-3) → **ADM-UC-270**.
2. Correr todas las migraciones en un ambiente, en un orden único y repetible (M-1, M-2, M-5, M-6, M-7,
   M-4, M-3) → **ADM-UC-271**.
3. Verificación final por ambiente: menú v2 = menú v3 por usuario (M-8, CP-M1) y el informe de que el
   ambiente quedó listo → **ADM-UC-272**.

## Qué NO hace

- **No hace el corte final** (redirigir las direcciones de DNATO al módulo y apagar DNATO). La decisión de
  Rodolfo dice que es "el último paso, con su propio análisis de impacto". Se propone como **requerimiento
  aparte** (duda de ADM-UC-272) porque toca mucho núcleo: el inventario está en "Lo que el corte final
  tiene que resolver".
- **No hace M-7b** (formularios de la empresa 9000 a globales): REQ-015 la dejó para el requerimiento
  aparte de `traz-comp-formularios` y del disparador de alta, porque moverla rompe el clonado de v2.
- **No hace el corte de v3 de CI/CD** (unir `develop-v3` con `develop`, `TRAZALOG_v3_CICD_STRATEGY.md` §8):
  es otra cosa, del proyecto entero.
- **No cambia ninguna columna existente** ni ninguna fila de v2 en una columna existente: M-3 solo llena
  columnas nuevas.
- **No enciende `menu_resuelto_en_tools`** en ningún ambiente: eso lo autoriza Rodolfo con el informe de
  ADM-UC-272 (REQ-009, regla 18).
- No saca la regla vieja del menú (`menu()` de `menu_helper.php`), ni `TOOLS_ADMIN_USER`, ni el uso de
  `seg.users.role`: todo eso es del corte final.
- No cambia los planes de las empresas que **ya** tienen plan (las creadas por el módulo o por el registro
  copiado con "Elegí tu plan", REQ-010).

---

## Cómo se arma

### Qué dejaron los requerimientos anteriores (M-1 a M-8)

| Paso (§8) | Qué es | Dónde quedó | En este requerimiento |
|---|---|---|---|
| M-1 | Atributos y entidades nuevas | REQ-004 (script principal) y los scripts chicos de REQ-005, REQ-008, REQ-009, REQ-011, REQ-013, REQ-014 y REQ-015 | Se ordenan en la secuencia única |
| M-2 | Catálogo publicado; herramientas del agente como `tool_mcp` | REQ-004 (la carga de herramientas quedó en duda: REQ-005 propuso un script con la lista del frente del agente) | Se ordena; si la lista del agente no está, el informe lo marca |
| M-3 | Plan "Completo" para las empresas actuales; plan base para las nuevas | Todos los requerimientos lo dejaron para acá | **Se hace acá** |
| M-4 | Funcionalidades activas por empresa | REQ-009 (adelantada: hacía falta para el menú) | Se ordena; el informe verifica que toda empresa tenga |
| M-5 | Membresías en `activo` y lista de las que no resuelven empresa | REQ-004 | Se ordena; el informe repite la lista |
| M-6 | Marca de superusuario | REQ-004 | Se ordena; el informe verifica que haya al menos uno |
| M-7 | Variables de sistema | REQ-004 (más las que agregaron REQ-008 y `menu_resuelto_en_tools` de REQ-009) | Se ordena; el informe verifica que estén todas |
| M-7b | Formularios de la 9000 | REQ-015: requerimiento aparte | **Fuera** |
| M-8 | Menú v2 = menú v3 por usuario | REQ-009 (adelantada: comparación en una copia de DEMO antes de encender) | **Se corre acá** en cada ambiente, como verificación final |
| M-9 | Corte | — | **Fuera** (requerimiento aparte) |

### M-3 — Plan "Completo" y plan base (ADM-UC-270)

1. **Plan "Completo"** en `seg.planes` (REQ-005), si no existe ya uno con ese código: todas las
   funcionalidades **publicadas** del catálogo en `seg.planes_funcionalidades` (herramientas del agente
   incluidas), **usuarios ilimitados** (tope nulo), cuota de IA **ilimitada** (nula, ver la duda de
   ADM-UC-270), no gratuito, sin vencimiento, sin precio público **[SUPUESTO]**, no se ofrece en la
   comparativa de Plan (REQ-010) ni en "Elegí tu plan" **[SUPUESTO]**.
2. **Plan base** (Freemium: 5 usuarios · MAN, ALM, PAN · 30 consultas por semana, §8): si el superusuario
   ya lo creó en la Consola (REQ-005) se usa ese; si no, el script lo crea y lo marca base. Es el que
   reciben las empresas **nuevas** del registro (REQ-010).
3. **Empresas actuales**: toda empresa con `plan_id` nulo (también las dadas de baja **[SUPUESTO]**, para
   que al recuperarlas tengan plan) pasa a "Completo": `plan_id`, `estado_plan = vigente`, `plan_vence`
   nulo, `uso_plan_gratuito = no`. Auditoría `empresa.cambiar_plan` por empresa con origen `migracion` y
   quién = el usuario del script.
4. **No** se recalcula la cuota (ilimitado: nada que abrir), **no** se mandan correos y **no** se activan
   funcionalidades (eso es M-4; con "Completo" todo lo que la empresa tiene activo sigue visible).
5. **Repetible**: correrlo dos veces no cambia nada la segunda (solo toca `plan_id` nulo). Sirve para las
   empresas que se registren por **DNATO** mientras convive con el módulo, que nacen sin plan (ver la duda
   de ADM-UC-270).
6. **Vuelta atrás**: vuelve a nulo `plan_id` (y las otras tres columnas) solo de las empresas que tienen la
   auditoría de origen `migracion` y siguen en "Completo"; no borra el plan si alguna empresa lo eligió
   después.

### Orden único de ejecución (ADM-UC-271)

Un documento de ejecución con la lista de scripts **en este orden**, cada uno con el requerimiento que lo
aprobó, dónde se corre (terminal con acceso a la base del ambiente, como el refresco de indicadores de
`doc/infra/kpi-cron-refresh.md`) y su vuelta atrás:

1. Estructura (M-1): REQ-004, REQ-005, REQ-008, REQ-009, REQ-011, REQ-013, REQ-014, REQ-015, en ese orden.
2. Datos de REQ-004: M-2, M-5, M-6 (con el correo del superusuario **de ese ambiente** como parámetro), M-7.
3. M-4 (REQ-009).
4. M-3 (este requerimiento).
5. Verificación (ADM-UC-272).

Reglas del orden:

- **Cada script se puede correr de nuevo** sin duplicar ni romper (crea solo lo que falta, carga solo lo
  que no está). Si un ambiente ya tiene parte (por ejemplo DEMO, donde se fueron corriendo de a uno), el
  orden completo se puede correr igual.
- **Se para en el primer error** y dice cuál; no sigue con el siguiente.
- Deja un registro de qué corrió, cuándo y con qué resultado (ver la duda de ADM-UC-271 sobre dónde).
- Siempre primero en una **copia** del ambiente, después en el ambiente. Producción, con respaldo de la
  base tomado antes y la ventana que fije Rodolfo.

### Verificación final (M-8, CP-M1) — ADM-UC-272

Un script **de solo lectura** que arma un informe por ambiente:

| Verificación | Pasa si | Sale de |
|---|---|---|
| **Menú v2 = menú v3** (CP-M1) | Para cada usuario con membresía activa de cada empresa, las opciones que hoy ve en Tools (`getMenuByUserPermission` más las hijas de la regla "todos los hijos") son las mismas que las `visible` del menú resuelto **predeterminado**; 0 diferencias sin justificar | La comparación de REQ-009, sin cambios |
| Diferencias justificadas | Cada una dice el motivo: regla "todos los hijos", opción despublicada, membresía sin empresa (CP-M1) | Ídem |
| Plan | Toda empresa tiene `plan_id` | `core.empresas` |
| Membresías | Toda (correo, `"group"`) tiene estado; lista de los `"group"` que no resuelven empresa (M-5) | `seg.membresias_estado`, `seg.memberships_users` |
| Funcionalidades | Toda empresa activa tiene al menos una funcionalidad activa (M-4) o figura en la lista | `seg.empresas_funcionalidades` |
| Superusuario | Hay al menos uno (M-6) | `seg.users.superusuario` |
| Variables | Están todas las de RF-102 y las agregadas por REQ-008 y REQ-009 (M-7) | `core.tablas` |
| Herramientas del agente | Cada herramienta del agente está en el catálogo como `tool_mcp` (M-2) | `seg.menues` y la lista del frente del agente |

El informe termina con **"Ambiente listo"** o **"Ambiente no listo"** y la lista de lo que falta. Con
"Ambiente listo", Rodolfo puede autorizar encender `menu_resuelto_en_tools` en ese ambiente (REQ-009) y,
más adelante, el corte final.

### Lo que el corte final tiene que resolver (insumo para su requerimiento)

Verificado contra el código de `develop` (2026-11-10), para que el requerimiento del corte no empiece de
cero:

- **Direcciones de DNATO en Tools**: la constante `DNATO` (`application/config/constants.php:93`) se usa
  en `application/controllers/Dash.php`, `application/controllers/Login.php`,
  `application/helpers/login_helper.php` y `application/helpers/sesion_helper.php` (`main/login`,
  `main/logout`, `main/users`, `main/changeuser`, `main/setdir`), más los submódulos (a relevar).
- **El agente de IA**: el token (JWT) lo sigue emitiendo DNATO (ADR-008, REQ-011): apagar DNATO exige
  mover el servidor de identidad del agente, que es identidad (workshop 🔴).
- **Lo que convive hasta el corte**: el ingreso, la registración y la carga masiva de DNATO; su "Menú por
  rol"; `TOOLS_ADMIN_USER` y `seg.users.role`; la regla vieja `menu()` de `menu_helper.php` (REQ-009); las
  empresas que nacen sin plan por el registro de DNATO (M-3 repetible).
- **Pendientes de otros requerimientos aparte**: el control central de Tools (H-091, T-5), el cambio de
  `traz-comp-formularios` y del disparador de alta (REQ-015: F-1 a F-5, CP-127, M-7b), el freno de cuota en
  WSO2 (REQ-011, frente del agente).

---

## De dónde sale cada dato

| Dato | De dónde | Cómo |
|---|---|---|
| Planes y su contenido | `seg.planes`, `seg.planes_funcionalidades` (REQ-005) | Script de M-3 |
| Catálogo publicado | `seg.menues` (`publicacion`, `tipo`, REQ-004) | Script de M-3 |
| Empresas sin plan | `core.empresas.plan_id` nulo | Script de M-3 |
| Auditoría de la migración | `seg.auditoria` (REQ-004) | Dentro del script de M-3 |
| Menú v2 y menú v3 por usuario | Comparación de REQ-009 (consultas de solo lectura y el recurso del menú resuelto) | Ya existe (REQ-009) |
| Resto de las verificaciones | Consultas de solo lectura sobre las tablas de la tabla de arriba | Script de verificación **NUEVO** |

Los scripts de migración van **directo a la base**, como todos los de REQ-004 y REQ-009 (son scripts de
despliegue, no pantallas): los corre quien despliega, con su vuelta atrás. El módulo no gana pantallas.

---

## Pantallas

Ninguna nueva. Lo que se ve después de M-3 sale de pantallas que ya existen:

| Dónde | Qué se ve después de M-3 | `data-testid` (de su requerimiento) |
|---|---|---|
| Portal → cabecera | "<ícono> Plan Completo" (REQ-006) | `adm-portal-empresa` |
| Portal → Inicio | Tarjeta Plan "Completo", Lugares "<usados> · sin tope", IA "sin tope" (REQ-013) | `adm-inicio-plan`, `adm-inicio-lugares`, `adm-inicio-ia` |
| Portal → Plan | La empresa en "Completo" (REQ-010) | `adm-plan`, `adm-plan-actual` |
| Consola → Empresas | Columna Plan "Completo" (REQ-008) | `adm-empresas-tabla` |
| Tools → tablero | Suscripción "Completo" (REQ-013) | `adm-tablero-suscripcion` |

El informe de verificación es un archivo de texto o una salida de terminal **[SUPUESTO]**, no una pantalla.

---

## Reglas

1. M-3 solo toca empresas con `plan_id` nulo; las que ya tienen plan no cambian.
2. Con el plan "Completo", ninguna empresa existente pierde una funcionalidad, un lugar ni consultas de IA.
3. M-3 no manda correos ni avisos.
4. Cada empresa pasada a "Completo" deja su fila de auditoría con origen `migracion`.
5. Todos los scripts se pueden correr de nuevo sin efecto la segunda vez.
6. El orden se corta en el primer error.
7. Siempre primero en una copia del ambiente.
8. La verificación es de solo lectura.
9. Sin "Ambiente listo" no se enciende `menu_resuelto_en_tools` ni se hace el corte.

## Registro

Cada script deja en su salida qué hizo (cuántas empresas pasó a "Completo", cuántas filas cargó) y el
informe de verificación se guarda con fecha y ambiente.

---

## Datos

**🔴 Rodolfo aprueba cada script antes de correrlo.** No hay tablas ni columnas nuevas.

| Tabla | Qué escribe M-3 |
|---|---|
| `seg.planes` | El plan "Completo" (y el base, si no existe) |
| `seg.planes_funcionalidades` | Todas las funcionalidades publicadas, para "Completo"; MAN, ALM y PAN para el base (si lo crea el script) |
| `core.empresas` | `plan_id`, `estado_plan`, `plan_vence`, `uso_plan_gratuito` (columnas nuevas de REQ-004) de las empresas con `plan_id` nulo |
| `seg.auditoria` | Una fila `empresa.cambiar_plan` por empresa, origen `migracion` |

---

## Análisis de impacto — lo aprueba Rodolfo antes de correr en producción

| Qué | Detalle |
|---|---|
| Qué cambia | Columnas nuevas de `core.empresas` en todas las empresas existentes; filas nuevas de planes y auditoría |
| Quién lo lee | Las pantallas y servicios del módulo (REQ-006 a REQ-015), el servicio "Consumir cuota" (REQ-011, ilimitado → siempre `ok` si pasa los pasos 1 a 3), el tablero de Tools (REQ-013). **v2 no lee esas columnas** (verificado por la búsqueda de usos que exige REQ-004) |
| Qué se rompe si sale mal | Un plan "Completo" al que le falte una funcionalidad dejaría esa opción "de otro plan" (sombreada) para todas las empresas el día que se encienda el menú nuevo → la verificación M-8 lo detecta antes de encender |
| Cómo se protege | Copia primero; repetible; vuelta atrás por la auditoría de origen `migracion`; respaldo de la base antes de producción |
| Pruebas | ADM-UC-270 a 272 en la copia de DEMO; DocTest `regresion` en verde después de M-3 |

---

## Decisiones tomadas

- **"Completo" = sin límites** (§8: "nadie pierde nada el día del cambio"), con la cuota a confirmar.
- **M-3 solo toca `plan_id` nulo**, así es repetible y no pisa lo que eligió una empresa nueva.
- **La verificación reusa la comparación de REQ-009**: un solo código para comparar menús.
- **El corte final se propone aparte**: toca identidad (el token del agente) y todas las direcciones de
  ingreso de Tools.

## Cómo se revisa (además de DocTest)

- Cada script aprobado por Rodolfo, corrido en una copia de DEMO, con su vuelta atrás probada.
- El orden completo corrido dos veces seguidas en la misma copia: la segunda no cambia nada.
- Informe de verificación de la copia de DEMO con "Ambiente listo" (o la lista de lo que falta, revisada
  por Rodolfo).
- DocTest `regresion` en verde después de M-3.

## Dudas abiertas

Están en los casos de uso (campo `dudas`), para contestarlas en un solo lugar.

---

## Casos de prueba de la especificación que cubre

| CP | Qué prueba | Lo cubre |
|---|---|---|
| CP-M1 | Menú v2 = menú v3 por usuario; diferencias justificadas con motivo | ADM-UC-272 (en cada ambiente; la comparación es la de REQ-009, ADM-UC-135) |
| M-3 (§8) | Todas las empresas actuales en "Completo"; nadie pierde nada | ADM-UC-270 |
| M-1 a M-7 (§8) | Migraciones en orden, repetibles | ADM-UC-271 |
| M-7b, CP-132 | Formularios de la 9000 a globales | Fuera de alcance (REQ-015: requerimiento aparte) |
| M-9 | Corte | Fuera de alcance (requerimiento aparte propuesto) |
