# Relevamiento de MAN — el módulo de Mantenimiento completo

## Objetivo

Es lo que tenés que leer para validar el catálogo de Mantenimiento: qué se relevó, qué se encontró y
qué preguntas hay que responder para que los casos salgan de `borrador`. Está escrito para el PM.
**No** es el catálogo —eso son los YAML de esta carpeta— ni el detalle de los circuitos, que ya está
relevado en el repo de asset (§1).

**Cómo validar, en concreto.** En una terminal, parado en `traz-tools/doctest/`:

```bash
npm run hoja:validacion -- man
```

Deja `.validacion/man.html`. Se abre en el navegador, se lee caso por caso, se marca la decisión de
cada uno, y el botón **Copiar** arma el texto con todas las decisiones para pegarme acá.

- **Fecha:** 2026-08-25 · **Fase:** DocTest F2 (issue #439)
- **Casos:** 37 — **27 validados**, 9 en borrador, 1 obsoleto
- **Derivados:** el manual de Mantenimiento (10 secciones) y **16 tests E2E en verde**
- **Cobertura:** las 12 pantallas de Mantenimiento y las 4 de Reportes — todo el menú
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

**Todo el menú de Mantenimiento**, no solo el piloto: las 12 pantallas del módulo más las 4 de
Reportes, barridas una por una contra el DEMO. Las 16 responden.

| Caso | Título | Perfil |
|---|---|---|
| MAN-UC-001 a 006 | Equipos y componentes — listar, dar de alta, editar, dar de baja, asignar | Supervisor |
| MAN-UC-007 | Pedir un servicio cuando algo falla | Solicitante |
| MAN-UC-008 | Analizar una solicitud y decidir qué hacer | Supervisor |
| MAN-UC-009 | **Programar una orden desde el plan de mantenimiento** | Planificador |
| MAN-UC-010 | Ver y filtrar las órdenes de trabajo | Planificador |
| MAN-UC-011 | **Ejecutar una orden y pedir los materiales** | Mantenedor |
| MAN-UC-012 | Cargar el informe de servicio | Mantenedor |
| MAN-UC-013 | Verificar el informe y dar la conformidad | Supervisor |
| MAN-UC-014 | Definir un mantenimiento preventivo | Planificador |
| MAN-UC-015 | Anotar trabajo pendiente en el backlog | Supervisor |
| MAN-UC-016 | Definir qué parámetros se le miden a un equipo | Planificador |
| MAN-UC-017 | Registrar la lectura de un parámetro | Mantenedor |
| MAN-UC-018 | Definir un mantenimiento predictivo | Planificador |
| MAN-UC-019 | Trabajar desde la bandeja de tareas | Mantenedor |
| MAN-UC-020 | Consultar los reportes e indicadores | Supervisor |
| MAN-UC-021 | Administrar el envío de órdenes | Planificador |

### Un caso por acción, y un caso por ciclo de vida

Al revisar el listado de equipos apareció que **un caso "ver el listado" esconde todo lo que se puede
hacer desde ahí**. El listado de equipos tiene **once acciones** en su columna Acciones, y el
catálogo original solo cubría cuatro. Se revisó ítem por ítem del menú:

| Listado | Acciones que ofrece | Casos que las cubren |
|---|---|---|
| **Equipos** | Editar · Eliminar · Habilitar · Inhabilitar · Contratista · Mantenimiento Autónomo · Historial de Lecturas · Editar lectura · Asignar Meta · Agregar/Editar/Eliminar Adjunto | UC-003, 004, 022, 023, 024, 025, 026, 027 |
| **Componentes** | Editar asociación · Eliminar asociación | UC-036 |
| **Preventivo** | Editar · Eliminar · Ver Archivo | UC-033 |
| **Predictivo** | Editar · Eliminar · Ver Archivo · Adjuntos | UC-034 |
| **Backlog** | Editar · Eliminar · Ver Archivo · Adjuntos | UC-035 |
| **Informe de Servicios** | Ver Informe · Verificar · selección múltiple | UC-013, UC-037 |
| **Órdenes de trabajo** | Parcial · Total · filtros | UC-010 (con la duda de qué hacen Parcial y Total) |
| **Solicitud de Servicio** | adjuntos | UC-007 |

Y se agregaron **cinco casos de ciclo de vida** —uno por entidad— que no describen una pantalla sino
el recorrido completo: qué le puede pasar a un equipo, a una solicitud, a una orden, a un backlog y a
un plan preventivo a lo largo del tiempo. Son los que contestan *"¿cómo funciona esto?"* en vez de
*"¿dónde aprieto?"*, y ninguna pantalla los responde por sí sola.

> **Los estados están relevados pero sin traducir, y a propósito.** En el código aparecen los códigos
> —la orden de trabajo tiene diez: `AC`, `AN`, `C`, `CE`, `CN`, `IN`, `P`, `RE`, `T`, `TE`; la
> solicitud nueve— y en pantalla se ven nombres como *Solicitada*, *Planificada*, *Terminada* y
> *Conforme*. **No se puede deducir con seguridad cuál código corresponde a cuál nombre**, así que no
> lo inventé: está como duda en cada caso de ciclo de vida. Es la información más pedida del módulo.

### Las preguntas que más importan para alguien sin soporte

De las 63, éstas son las que dejan trabado a alguien que arranca solo:

1. **¿Cuál es la diferencia entre preventivo y predictivo?** (UC-018) Las dos pantallas se parecen
   mucho. Por el código, el preventivo se dispara por tiempo y el predictivo por la lectura de un
   parámetro — pero hay que confirmarlo y decirlo bien.
2. **¿Cuándo uso backlog y cuándo solicitud de servicio?** (UC-015) Los dos terminan en una orden de
   trabajo. Parece ser cuestión de urgencia, pero conviene que lo diga el manual.
3. **¿Qué pasa cuando una lectura se sale del rango configurado?** (UC-016, UC-017) ¿Se genera algo
   solo o alguien tiene que estar mirando? Es la razón de ser del predictivo.
4. **¿Qué estados tiene una orden de trabajo?** (UC-010) Es lo primero que alguien mira y no está
   escrito en ningún lado.
5. **¿Qué mide cada uno de los KPIs?** (UC-020) Es lo que un dueño de PyME va a querer ver, y no hay
   nada documentado.
6. **El informe muestra lo pedido rotulado "Insumos Usados"** (UC-012). El usuario lo va a leer como
   consumo real. ¿Se documenta así o se corrige antes?
7. **¿Para qué sirve "Administrar Ordenes"?** (UC-021) Es la única pantalla que no se pudo
   interpretar ni desde el código ni desde los manuales.

### Dos cosas del código que ordenan todo el módulo

- **Un solo motor de órdenes.** Solicitud aceptada, preventivo vencido, backlog y predictivo
  terminan todos en `Calendario::guardar_agregar()`. Lo único que cambia es de qué tabla se copian
  las herramientas y los insumos. Por eso el **Plan de Mantenimiento** no es una pantalla más: es
  donde se convierte cualquier pendiente en trabajo real.
- **El pedido de materiales es perezoso.** Los planes solo *declaran* qué insumos harán falta; el
  pedido al almacén nace **al abrir la ejecución de la orden**. Es contraintuitivo y hay que
  explicarlo, porque el usuario puede esperar que el pedido ya exista.

## 3. El ingreso, destrabado — y por qué estaba roto

**Desde el 2026-08-26 hay un usuario que funciona** (`supman@novu.com`), que proveyó el PM. Con eso
las seis pantallas del piloto quedaron **verificadas contra el DEMO**, y lo que sigue explica por qué
ninguna credencial de una empresa registrada entra — que sigue siendo un problema abierto.

### Lo verificado en pantalla (2026-08-26)

| Qué | Resultado |
|---|---|
| El menú de AssetPlanner | Mantenimiento, Pañol, **Almacenes**, Compras, 19 ABMs y Reportes. Que tenga Almacenes y Pañol propios **confirma que el DEMO corre `develop`**, la versión anterior a la migración |
| Listado de equipos | Código Equipo, Descripción, Área, Proceso, Sector, Criticidad, Cliente y Estado — más una segunda tabla, **Contratistas Asignados**, que no está en ningún manual |
| Formulario de alta | Los asteriscos están en **Área, Proceso, Criticidad y Sector/Etapa**, no en Código/Marca/Descripción/N° de serie como decía el manual anterior. **Ningún campo declara `required` en el HTML** |
| Los botones de agregar opciones | **Existen y están visibles** (`addarea`, `addproceso`, `addcriti`, `addetapa`, `addgrupo`, `addcliente`). El manual anterior decía que las listas "deben cargarse previamente desde el ABM": quedó desactualizado |
| Garantía | Es una **fecha**, no una cantidad de meses. Y hay además una **Fecha de Lectura Inicial** que el manual anterior no menciona |
| ABM Componentes | Marca, Descripción, Información y Adjunto |
| Asociar componentes | Equipo, Descripción (se completa sola), Componente y Código |

Dos cosas que **no** resultaron ser hallazgos, y conviene dejar dicho para no volver a levantarlas:
`ABM Sistemas` daba 404 porque yo estaba probando la URL equivocada —el controlador es `SistemaABM`—,
y las etiquetas repetidas en la pantalla de asociar componentes eran un error de mi extractor: en la
vista son correctas (*Equipo*, *Descripción*, *Componente*, *Código*).

### Por qué no entra ningún usuario de una empresa registrada



El circuito de alta existe, tal como estaba diseñado: el alta de usuario llega a la tabla `sisusers`
de asset. Lo que está roto es la contraseña.

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

Sigue siendo 🔴 aunque el relevamiento esté destrabado: **una empresa que se registra hoy no puede
usar Mantenimiento.** El usuario prestado sirve para relevar y para escribir los tests, no para
resolver eso.

Queda en pie la consecuencia de diseño: **MAN necesita su propia fixture de sesión**, porque tiene su
propio ingreso y el `storageState` de Tools no le sirve.

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

## 5. El manual: lo que hay y lo que falta

`ayudas/src/man/manual_equipos_y_componentes.html` cubre **equipos y componentes** (UC-001 a UC-006),
con las pantallas dibujadas y verificadas. Es un tercio del módulo.

**Falta el resto, y es donde está el valor para alguien sin soporte**: el circuito completo —pedir un
servicio, planificarlo, ejecutarlo, informarlo, verificarlo—, los preventivos, el predictivo con sus
lecturas, el backlog y los reportes. Eso se escribe cuando los casos estén validados, porque la mitad
de las respuestas que faltan cambian lo que hay que explicar (§2).

**Ningún manual de MAN se publica todavía**: el generador solo arma los que algún caso `validado`
declara como derivado, y lo avisa en cada corrida de `npm run ayudas`.

---

## 6. Después de que valides

`ayudas/src/man/manual_equipos_y_componentes.html` — tres secciones: por qué los equipos van
primero, el alta paso a paso con el formulario dibujado y los campos explicados uno por uno, y los
dos caminos para cargar componentes.

**No se publica**, y eso es a propósito: el generador solo arma los manuales que algún caso
`validado` declara como derivado, así que mientras los casos de MAN estén en `borrador` el manual
queda escrito pero fuera del sitio. `npm run ayudas` lo avisa en cada corrida. Es la misma regla que
ya regía para los tests y los `.feature`, ahora también para las ayudas.

Sale del código de `develop` y del manual de ayuda anterior, que aporta el vocabulario y los pasos
validados. Dos cosas de ahí que quedaron como duda porque **no se pudieron verificar en pantalla**:

- el manual anterior dice que las listas desplegables *"deben cargarse previamente desde el ABM"*,
  pero el formulario tiene un botón para agregar la opción al lado de cada combo. ¿El botón es nuevo
  y el manual quedó viejo, o el botón no funciona?
- los cuatro campos obligatorios salen del manual anterior; el formulario **no declara `required`**
  en el HTML, así que la validación —si existe— está en el JavaScript. Mismo patrón que en DNATO y
  ALM: la vista protege, el servidor no revalida.

---

Con los casos en `validado`: se escribe el manual completo del módulo —el circuito de punta a punta,
los preventivos, el predictivo, el backlog y los reportes—, se agrega la fixture de sesión propia de
MAN y se escriben los tests.

Las siete preguntas de §2 son las que más cambian el manual, así que conviene responderlas aunque el
resto quede para después.
