# Relevamiento de MAN — piloto de Alta de Equipos y Componentes

## Objetivo

Deja registro de cómo arrancó F2 (Mantenimiento / AssetPlanner): qué material previo había, qué se
relevó, **qué está bloqueado y por qué**, y las tres decisiones que hacen falta para seguir. Está
escrito para el PM. **No** es el catálogo —eso son los YAML de esta carpeta— ni el detalle de los
circuitos, que ya está relevado en el repo de asset (§1).

- **Fecha:** 2026-08-25 · **Fase:** DocTest F2 (issue #439)
- **Casos:** 6, todos en `borrador` — **ninguno verificado contra la pantalla real**, por el bloqueo de §3
- **Rama relevada:** `develop` del repo de asset (lo que corre en el DEMO)

---

## 1. Lo primero: acá ya había trabajo hecho, y es bueno

Antes de relevar nada encontré, en la rama `develop-v3` del repo de asset, material que no conviene
duplicar:

| Qué | Dónde | Qué aporta |
|---|---|---|
| **Circuitos funcionales de MAN ↔ ALM ↔ PAN** | `doc/v3/circuitos-man-alm-pan.md` (310 líneas) | El mapa completo de los circuitos, con verificación en la base y diagramas. Excelente |
| **Casos de prueba MAN** | `doc/v3/casos-prueba-man.md` (104 líneas) | Un catálogo `CP-01`…`CP-3x` con precondición, pasos, resultado esperado y si está automatizado |
| **Suite E2E de Playwright** | `tests/e2e/` (6 specs + fixtures + README) | Automatiza parte de esos casos, sobre el requerimiento "asset consume el almacén de tools" |

> ⚠️ **Cuidado con ese material: describe `develop-v3`, y ahí hay una migración que está en stand by.**
> Los `CP-XX` y buena parte del doc de circuitos están escritos sobre el reemplazo del almacén y el
> pañol de asset por los de traz-tools (fases F3/F4/F5 de ese repo), que **quedó detenido hasta
> tener las ayudas**. Por eso este relevamiento se hace **solo sobre `develop`**, que es lo que corre.
> Lo que sí se aprovecha del doc es el **mapa funcional** —los circuitos, el modelo de datos, la
> asimetría entre materiales y herramientas—, que es igual en las dos ramas; lo que se descarta es
> todo lo que hable de leer catálogos por REST contra tools.

Tres cosas que ese material deja establecidas y que **valen para `develop` igual**, porque son del
"qué" funcional y no del "cómo" técnico:

1. **Hay un solo motor de generación de OT** — `Calendario::guardar_agregar()`. Backlog, preventivo,
   predictivo y correctivo son el mismo circuito con distinta tabla de origen.
2. **El pedido de materiales es perezoso**: no nace del plan ni al vencer, sino **al abrir el modal
   de "Ejecutar OT"**. Se dispara a Bonita recién al ejecutarla.
3. **Materiales y herramientas son asimétricos.** Los materiales tienen circuito transaccional
   completo con descuento de stock; las herramientas **solo se declaran y se listan** — no hay
   pedido, ni entrega, ni devolución, ni stock de pañol.

Y un hallazgo funcional que ese doc ya registra y conviene no perder de vista: **el informe de
servicio muestra lo *pedido* rotulado como "Insumos Usados"**, no lo entregado ni lo consumido. Hay
un TODO en el código que lo admite.

---

## 2. Lo que releva este PR

El piloto que pide el issue #439: **el alta de equipos y componentes**. Seis casos:

| Caso | Título |
|---|---|
| MAN-UC-001 | Ver el listado de equipos |
| MAN-UC-002 | **Dar de alta un equipo** (el caso piloto) |
| MAN-UC-003 | Editar un equipo |
| MAN-UC-004 | Dar de baja un equipo |
| MAN-UC-005 | Dar de alta un componente |
| MAN-UC-006 | Asignar componentes a un equipo |

**Una buena noticia sobre las versiones:** el alta de equipos y componentes **no difiere entre
`develop` y `develop-v3`** del repo de asset — verificado con `git diff`. Así que este piloto no
depende de qué rama corra el DEMO, que es la duda que planteaste.

**Dos cosas que aparecieron al leer el código:**

- **Los catálogos se pueden crear desde el propio formulario.** Junto a cada desplegable del alta
  —área, proceso, criticidad, sector, grupo, cliente— hay un botón para agregar una opción nueva sin
  salir de la pantalla. Es distinto de ALM, donde hay que ir al ABM y volver, y vale la pena
  documentarlo en la ayuda.
- **Quedaron llamadas de depuración activas.** `dump()` no es un log: imprime un bloque HTML amarillo
  en la salida. Hay más de 15 llamadas activas en 8 archivos, y **una de ellas está dentro de
  `guardar_componente()`**, que es justo el alta del piloto. Donde la respuesta se consume por AJAX
  esperando JSON, ese HTML la corrompe. → issue **#486**.

---

## 3. Por qué no se puede entrar a AssetPlanner — y no es un dato que falte

La primera lectura fue equivocada y conviene dejarla corregida: pensé que faltaba un usuario de
AssetPlanner. **El circuito de alta existe, tal como estaba diseñado** — el alta de usuario llega a
la tabla `sisusers` de asset. Lo que está roto es la contraseña.

| Punta | Qué hace |
|---|---|
| `COREDataService.dbs`, query `setUserAsset` | `INSERT into sisusers(… usrPassword …) values (… :pass …)` — **guarda lo que llega, sin transformar** |
| `toolsCOREAPI`, recurso `POST /usuario` | manda `json-eval($.usuario.password)` — la contraseña **en texto plano** |
| AssetPlanner, `Apps::sessionStart_()` | busca `usrPassword = md5($pass)` — **compara contra MD5** |

Se guarda en claro y se compara hasheado: **nunca coinciden**.

Lo llamativo es que el mismo `toolsCOREAPI` **lo hace bien en el otro camino**: el recurso
`POST /usuario/bpm-asset` manda `password_md5`. O sea que el MD5 estaba contemplado; falta en el
camino que usa la registración.

**Verificado contra el DEMO** con la empresa creada por el alta real: cinco combinaciones probadas
—el administrador que registró la empresa, y los cinco usuarios por defecto con clave `12345`,
incluido `mantenimiento@…` que es el que tiene los roles de mantenimiento— y **las cinco
rechazadas**.

→ Issue **#489**. Es 🔴: **una empresa que se registra hoy no puede usar Mantenimiento**, y sus
contraseñas quedan en texto plano en la base de asset.

### No es que un deploy haya pisado la versión buena

Se planteó esa hipótesis y **no se sostiene: no existe una versión correcta en el repositorio.**

| Qué se comparó | Resultado |
|---|---|
| `toolsCOREAPI.xml` entre `develop`, `develop-v3` y `master` | **idéntico** — `git diff` sin salida en las tres combinaciones |
| `setUserAsset` de `COREDataService.dbs` entre `develop` y `develop-v3` | **idéntico**, sin `MD5` en ninguna |
| La copia del **proyecto Maven**, que es la que se compila y despliega | **también** manda la contraseña en texto plano, en las tres ramas |

El arreglo hay que hacerlo, no recuperarlo de otra rama.

**De paso apareció otra cosa:** el archivo está **dos veces en el repo** y las copias no coinciden.
`_backend/api/toolsCOREAPI.xml` (el suelto, el de la ruta obvia) está **28 líneas atrás** del que
compila el proyecto Maven — le falta el paso que vincula `empr_id_mysql` en `core.empresas`. O sea
que quien lo abra por la ruta corta lee la versión vieja creyendo que es la que corre → issue
**#490**.

Las otras diferencias del backend entre ramas son las esperables de v3 —las sequences de JWT y los
DataServices de MAN, ALM, TAR y Producción— más una menor: `AssetPlannerDataSource.xml` actualiza el
driver de MySQL y sus parámetros de conexión, pero **las dos ramas apuntan a la misma base**
(`10.142.0.13:3306/assetv2`), así que el DEMO no está escribiendo en otro lado.

Por eso los seis casos de este PR están relevados **del código y del manual legacy**, y cada uno lo
dice en sus dudas. Y por eso DocTest no puede verificar ni testear MAN hasta que esto se corrija:
no es que falte un dato, es que **no existe ninguna credencial que funcione**.

Queda en pie la consecuencia de diseño: cuando se destrabe, **MAN necesita su propia fixture de
sesión**, porque tiene su propio ingreso y el `storageState` de Tools no le sirve.

## 4. Lo que hace falta para seguir

### 4.1 Corregir el hash de la contraseña (#489)

Es lo único que bloquea, y no es una decisión sino un arreglo. Que `setUserAsset` guarde `MD5(:pass)`,
o que `POST /usuario` mande la contraseña hasheada como ya hace `/usuario/bpm-asset`.

Mientras tanto hay un rodeo posible para desbloquear DocTest: **crear a mano un usuario en `sisusers`
con la contraseña ya en MD5**. Sirve para verificar y testear, pero no arregla el problema de fondo
—que ninguna empresa nueva puede entrar—, así que conviene tratarlo como lo que es: un parche para
poder seguir trabajando.

### 4.2 El catálogo de MAN describe `develop` — decidido

Queda cerrado por indicación del PM (2026-08-25): **se releva solo `develop`**, que es lo que corre
en el DEMO. El material de `develop-v3` se usa como mapa funcional, no como descripción del sistema
(ver el aviso de §1).

### 4.3 Qué hacemos con los `CP-XX` y la suite que ya existen

Sigue abierta, pero la respuesta se simplificó con lo anterior: **esos casos prueban la migración que
está en stand by**, así que no describen el sistema que hay que documentar hoy.

**Mi recomendación:** dejarlos donde están, sin migrarlos. Cuando la migración se retome, esa suite es
justamente la que hay que correr para validarla. Lo que sí conviene traer al catálogo de DocTest es
la **casuística funcional que sea independiente de la migración** —el ciclo de la OT, el pedido
perezoso, la asimetría con herramientas—, que vale para las dos versiones.

## 5. Después de que decidas

Con el ingreso destrabado: verificar los seis casos en pantalla, confirmar si el `dump()` rompe el
alta de componentes, agregar la fixture de sesión de MAN y escribir los tests. Después, seguir el
relevamiento hacia los circuitos de `develop` —plan de mantenimiento, backlog, OT, informe de
servicio—, que es donde está el grueso del módulo.
