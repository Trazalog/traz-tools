# Traspaso — frente "Migración AssetPlanner a traz-tools" (REQ-ASSET-ALM)

## Objetivo

Volcado de estado de este frente, para que quien lo retome —yo mismo en otra sesión, u otra persona—
sepa qué quedó hecho, qué quedó a medias y con qué exactitud, y qué se decidió que no está escrito en
ningún otro archivo del repo. **No** es documentación del sistema: para eso están
`doc/migracion/assetplanner-a-traz-tools-man.md` (plan de migración, en este repo) y, del lado de
AssetPlanner, `doc/v3/circuitos-man-alm-pan.md`, `doc/v3/setup-cliente-alm-pan.md`,
`doc/v3/casos-prueba-man.md` y `doc/v3/STATE.md`.

| | |
|---|---|
| **Trabajo ejecutado** | 2026-08-12 a 2026-08-19, en la sesión `a9ab4de1-c943-4b3b-a1d5-5d892e35373b` |
| **Este volcado** | escrito el 2026-08-31, reconstruyendo esa sesión desde su transcript |
| **Repos** | `Trazalog/traz-prod-assetplanner` (el grueso) y `Trazalog/traz-tools` (DataServices) |
| **Rama de integración** | `develop-v3` en ambos repos |
| **Estado de los PRs** | los 15 de asset (#322–#336) y los 10 de tools (#424–#431, #444) **mergeados** |

> **Aviso sobre la fuente.** El trabajo lo hizo la sesión del 12 al 19 de agosto; esta sesión solo la
> reconstruyó. Todo lo que dice "verificado hoy" se comprobó el 31/08 contra el working tree y los
> remotos; el resto sale del transcript de esa sesión, que quedó copiado en
> `~/.claude/projects/-mnt-win-dev-git-traz-tools/transcript-sesion-assetplanner-2026-08.txt` junto a
> un resumen narrativo (`reconstruccion-sesion-assetplanner-2026-08.md`). La sesión original se
> reabre con `claude --resume a9ab4de1-c943-4b3b-a1d5-5d892e35373b`.

---

# 1. Lo que quedó terminado

## 1.1 El relevamiento del fork abandonado y el plan de migración

Pedido original: entender hasta dónde llegó la migración que Rogelio Sanchez arrancó en 2024 y armar
un plan. Los hallazgos que importan:

- **El fork nunca se integró.** El submódulo `application/modules/traz-tools-man` de este repo apunta
  a `02cca436` — "First commit", un README de una línea. **Verificado: sigue apuntando ahí.** El
  trabajo real vive en la rama `rnsanchez` del repo `traz-tools-man`, que ningún repo referencia.
- **El módulo no arrancaba.** Rogelio hizo el `sed` de `$this->db` → `$this->assetDB` solo en los
  models: 62 queries de los controllers pegaban contra PostgreSQL, 89 accesos leían una clave de
  sesión que el host nunca escribe, y 23 vistas referenciadas no existían (incluido el calendario).
  El método fue **convertir por método, no por archivo**, así que ningún archivo quedó enteramente en
  un estado ni en el otro.
- **La divergencia es chica**: de 43 archivos migrados, solo 15 cambiaron en 20 meses. Rescatar el
  fork es mejor negocio que re-migrar.
- Se detuvo por **jQuery**, no por el dominio: subió de jQuery 2 a 3 sin adaptar, parcheó con
  jquery-migrate, eso rompió AdminLTE, quitó el parche, y quedaron 11 callbacks y 48 autocompletes
  rotos.

**Entregable:** `doc/migracion/assetplanner-a-traz-tools-man.md` (599 líneas, PR #424), con estado,
método de Rogelio y sus fallas, riesgos, plan de pruebas y estrategia de cutover en etapas. Se
actualizó después (PR #425) para incluir herramientas junto a almacenes y el cutover de dos
velocidades.

## 1.2 REQ-ASSET-ALM — fases F0 a F6, todas mergeadas

El 13/08 entró un requerimiento de cliente que invirtió el orden del plan: asset sigue vivo, pero su
almacén y su pañol se reemplazan **ya** por los de tools.

Antes de tocar nada se corrió una **verificación read-only contra la base productiva**: almacén
operativo en **cero absoluto** (0 notas de pedido, remitos, órdenes de insumos, lotes, envíos).
Herramientas y artículos casi todos de empresas de prueba; el único cliente real con datos es
**Caleras San Juan** (2 herramientas, 32 artículos, 10 referencias históricas en
`tbl_otherramientas`). Con eso el reemplazo quedó sin migración masiva de datos.

| Fase | Qué | Repo | PR |
|---|---|---|---|
| F0 | Metodología: `CLAUDE.md` + `doc/v3/CONTEXT-PACK.md` + `doc/v3/STATE.md`, `develop-v3` creada desde `develop` | asset | #322 |
| F1 | Sincronizar `ALMDataService` EI←MI, `getEmpresaByMysqlId` en CORE (ambas copias), migración SQL de `empr_id_mysql` | tools | #425, #426, #427 |
| F2 | Checklist de setup por cliente, 8 pasos autocontenidos | asset | #324 |
| F3 | Almacén → REST: helper `tools_helper.php` y 9 lectores de `articles` | asset | #325 |
| F4 | Herramientas → `PANDataService`: 10 lectores | asset | #326, #329 |
| F5 | Ejecutar-OT: los pedidos nacen y viven en tools | asset #327; tools #428–#431 |
| F6 | Prueba en pantalla con Playwright + documento con capturas | asset | #331, #332 |

Dos resultados que conviene no perder:

- **El fix de aislamiento, demostrado con datos reales**: la empresa 87 reportaba 7.534 de stock y con
  el fix reporta **4.532** — 3.002 unidades eran de otras empresas. Afectaba a `getArticulos`,
  `getArticulos2` y `getArticulo` en **ambas** copias del DataService.
- **El flujo F5 probado end-to-end con Bonita real**: OT 935 → pedido 1486 en el Postgres de tools →
  detalle con `resto` puesto por el trigger `tgrupdateresto` → case Bonita 30010 → estado
  `Solicitado` y `case_id` persistidos y releídos.

## 1.3 El relevamiento funcional de los circuitos MAN ↔ ALM ↔ PAN

Pedido del PM porque no es experto funcional del módulo. Se relevó siguiendo el código con tres
agentes en paralelo, más verificación contra la base de DEV. **Entregable:**
`doc/v3/circuitos-man-alm-pan.md` en asset (PR #333), con 5 diagramas Mermaid.

Los tres hallazgos que respondieron la pregunta de fondo:

1. **Un solo motor.** Backlog, preventivo y predictivo generan la OT por el mismo método
   (`Calendario::guardar_agregar`, `application/controllers/Calendario.php:133`). La única diferencia
   es de qué tabla copian herramientas e insumos. El Plan de Mantenimiento engancha con ALM y PAN
   **exactamente igual** que el backlog.
2. **El pedido nace de la OT, no del plan, y es perezoso.** Se crea al *abrir* el modal de Ejecutar OT
   (`crearPedidoOT`, lee `tbl_otinsumos`) y se dispara a Bonita recién al *ejecutar*. En generación en
   serie: N OTs, cero pedidos.
3. **La asimetría ALM/PAN**: los materiales tenían circuito transaccional completo (pedido → aprobación
   → entrega que descuenta `alm_lotes` y actualiza `resto`); las herramientas terminaban su recorrido
   como una fila `(otId, herrId, cantidad)` — sin pedido, sin estados, sin Bonita, sin stock.

Y dos cosas laterales que valen: **el informe mostraba lo PEDIDO rotulado como "usado"** (hay un TODO
en el código admitiéndolo: `// TODO: BORRAR INSUMOS!! ... ver donde mierda guarda`), y
**`articles` y `abmdeposito` son VIEWs** sobre `alm_articulos` / `alm_depositos` — el catálogo de
insumos de mantenimiento *es* el del almacén, por eso la migración de catálogo fue "cambiar de dónde
se lee el mismo dato". `asignaherramientas` es tabla muerta: sin lectores ni escritores.

## 1.4 Las dos mejoras funcionales que salieron de ese relevamiento

**M1 — consumo real en el informe (asset PR #334).** Las 3 vistas del informe (crear, revisar,
conformidad) muestran **Pedido / Entregado / Pendiente** en vez de solo "Cantidad".
`entregado = cantidad − resto`, dato que ya viajaba en el pedido de tools → **no tocó tools**.
Verificado con datos reales: pedido 958 (15/15) y 1486 (0/13). De paso se corrigieron las claves rotas
de la vista de edición (`nroOT`/`codigo`/`solicitante`, que mostraban columnas vacías).

**M2 — herramientas disponibles + vale contra pañol (asset PR #335).** Todas las listas de
herramientas del módulo (preventivo, predictivo, backlog, OT e informe) filtran a las **disponibles**:
estado `ACTIVO` y del **pañol asignado** (`PANO` del setup), ordenadas por nombre. Al guardar el
informe se crea el **vale de salida real** contra `PANDataService` y cada herramienta pasa a
`TRANSITO`. Probado end-to-end contra DEV: salida creada, herramienta en `TRANSITO` en la base,
después restaurada.

Con M2 la asimetría quedó **cerrada de un solo lado**: la herramienta sale del pañol, pero no vuelve.
Ver §2.2. El análisis de buenas prácticas posterior concluyó además que **el vale quedó en el lugar
equivocado del circuito** — ver `doc/v3/integracion-assetplanner-panol.md` §8.6.

## 1.5 El paquete de pruebas

- `doc/v3/casos-prueba-man.md` — 25 casos (CP-01…CP-63) con precondición, pasos, resultado esperado y
  si están automatizados, más matriz de trazabilidad casos ↔ circuitos ↔ tests.
- `tests/e2e/` con Playwright: `01-menu`, `02-catalogos-tools`, `03-planes-pantalla`, `04-pedido-ot`,
  `05-informe-consumo` (M1), `06-herramientas-panol` (M2), `fixtures.js`, `playwright.config.js`,
  `README.md` con la sección de regresión (cómo correrla, esbozo de workflow de GitHub Actions,
  prerrequisitos y guía para developers).
- `doc/v3/pruebas-f6-resultados.md` — la prueba en pantalla de F3/F4/F5, 8 capturas.
- `doc/v3/pruebas-regresion-resultados.md` — corrida de la regresión: **4 passed / 0 failed /
  1 skipped**, 2 capturas.

**Cómo se levantó el entorno**, porque no es obvio y hará falta repetirlo: PHP 7.3 de XAMPP
(`/opt/lampp/bin/php`) con el servidor embebido apuntando a un clon del repo, contra la base
`assetv2` de DEV por VPN. **Servir con URLs limpias** (emulando `mod_rewrite`); si se sirve con
`index.php` explícito, el JS de la app duplica el prefijo y todo falla con 404 — eso produjo dos
falsos positivos que hubo que rectificar. Usuario de prueba y credencial: `doc/v3/pruebas-f6-resultados.md` §1.

## 1.6 El incidente del `ALMDataService` y su fix

El 19/08 el PM desplegó los DataServices y **se cayó el módulo ALM de v2**. Causa: en F1, al
sincronizar EI ← MI, el resource `GET /articulos/{empr_id}` quedó **declarado dos veces** (uno →
`getArticulos`, otro → `getArticulos2`). El **EI 6.5 rechaza un `.dbs` con dos resources de igual
method+path y tira abajo el servicio entero** — no fue un endpoint, fue todo `ALMDataService`.

Alcance verificado en su momento: es el único archivo con contratos rotos; `COREDataService` (ambas
copias) y la copia MI de ALM fueron puramente aditivas. **El MCP no se vio afectado**: invoca sus
propios endpoints (`/mcp/stock/{empr_id}`, `/mcp/depositos/`, `/mcp/vencimientos/`, `/pedidos/*`),
nunca `/articulos/{empr_id}`.

Fix quirúrgico (PR #444): quitar el resource duplicado en ambas copias, 10 líneas.

De ahí salió la regla que hoy está en el `CLAUDE.md` del proyecto: *todo objeto existente debe
mantener compatibilidad con v2; toda modificación es aditiva*.

---

# 2. Lo que quedó a medio hacer

## 2.1 🔴 El `STATE.md` de asset quedó congelado el 2026-08-15

`doc/v3/STATE.md` del repo de asset dice "Última actualización: 2026-08-15" y está desfasado respecto
de la realidad:

- La tabla de fases marca F1–F6 como **"Completada, en PR"** y M1/M2 como **"En PR"**. Las once están
  mergeadas.
- La sección **"Próxima acción"** pide mergear #425 y #426 — hechos el 14/08 — y numera 1, 2, **4**,
  5, 6 (falta el 3).
- No registra nada posterior al 15/08: ni el relevamiento de circuitos (#333), ni M1/M2 (#334/#335),
  ni el paquete de pruebas (#336), ni el incidente del duplicado y su fix (#444).

Es el primer archivo a tocar cuando se retome, porque es el que cualquiera lee para saber dónde está
el frente y hoy miente.

## 2.2 La devolución de herramientas al pañol nunca se implementó

M2 cerró la ida (la herramienta sale del pañol y pasa a `TRANSITO`) pero **no la vuelta**: una
herramienta usada en un informe no vuelve a estar disponible nunca.

Estado exacto:

- **Del lado de tools ya está todo**: `PANDataservice.dbs` expone
  `POST /panol/entrada/herramientas`, `POST /panol/entrada/herramientas/detalle` y
  `PUT /herramientas/estado`. Son los simétricos de los que usa el vale de salida.
- **Del lado de asset falta la función**: `application/helpers/tools_helper.php` termina en
  `tools_pan_write()` (línea 488); la última función de negocio es `tools_crear_vale_salida()`
  (línea 427). No existe ninguna `tools_devolver_herramientas()`.
- **Dónde engancharla**: el punto natural es el cierre del ciclo de la OT —
  `Tarea::prestarConformidad()` (`application/controllers/Tarea.php:392`) o
  `Tarea::verificarInforme()` (`:239`) — simétrico a como `Ordenservicios::setOrdenServicios()` llama
  hoy a `tools_crear_vale_salida()`. Falta decidir cuál de los dos cierres marca la devolución: es
  una decisión funcional, no técnica. Ver la propuesta en
  `doc/v3/integracion-assetplanner-panol.md` §8.2 (la respuesta recomendada es que la devolución la
  registre siempre el pañolero en Tools, y que la OT no cierre con vales abiertos).

## 2.3 Los casos de escritura del vale no corren en la regresión

`tests/e2e/06-herramientas-panol` deja CP-53 y CP-54 (crear el vale) detrás del flag
`E2E_ESCRITURA=1`, porque crean datos reales. Se validaron **a mano por API** durante el desarrollo de
M2 (crear salida → detalle → marcar `TRANSITO` → verificar en la base → restaurar), pero como test
automatizado nunca corrieron. Mientras sigan así, la regresión no cubre el tramo de escritura de M2 —
que es justamente el más riesgoso.

## 2.4 Una verificación visual quedó pedida y sin respuesta

El autocomplete de insumos desplegando la lista en pantalla nunca se capturó: el servidor embebido
single-thread era demasiado lento para que Playwright agarrara el momento. Está confirmado por
endpoint (311 artículos, 26 herramientas) y el widget existe, pero falta la confirmación visual.
Quedó pedido al PM y sin responder: **Preventivo → Agregar → pestaña Insumos → tipear "Ajo"**. Si
anda, se cierra ese punto en `doc/v3/pruebas-f6-resultados.md`.

## 2.5 El checklist de F2 nunca se ejecutó para un cliente real

`doc/v3/setup-cliente-alm-pan.md` se ejecutó solo para la **empresa de prueba 1 en DEV**
(`DEPO=2000`, `PANO=10`, `ESTA=6`, catálogo de 311 artículos y 27 herramientas). Para el cliente del
requerimiento falta todo: crear establecimiento + "Depósito \<empresa\>" + "Pañol \<empresa\>",
resolver y guardar los IDs en `core.tablas`, y cargar el catálogo.

En particular para **Caleras San Juan**: sus 32 artículos y 2 herramientas hay que cargarlos a mano
(minutos de trabajo), y sus **10 referencias históricas** en `tbl_otherramientas` hoy se resuelven con
un fallback textual `(herramienta N no disponible en tools)`. Se eligió esa opción por ser la de
menor riesgo, pero el remapeo quedó como alternativa abierta.

## 2.6 La migración SQL de `empr_id_mysql` solo se aplicó en DEV

`scripts/sql/2026-08-core-empresas-empr-id-mysql.sql` (este repo) es idempotente y crea el índice
único parcial. Se verificó en DEV que no hay duplicados, así que la unicidad no puede fallar.
**Falta aplicarlo a mano en TEST y en PROD.**

## 2.7 La unificación EI↔MI quedó a mitad de camino

> **Actualización (2026-10-01):** el PR #545 adoptó la unificación que `develop` ya había hecho —
> se borraron las 31 copias duplicadas de `_backend/api/` y queda una sola copia por artefacto en los
> proyectos Maven. Lo que sigue abajo es el estado en el que lo dejó la sesión de agosto.

F1 sincronizó `ALMDataService`, pero al hacerlo apareció que **la copia EI de `COREDataService` está
más desactualizada de lo que se creía**: no tiene `getEmpresaById` ni `updateEmpresaAssetId` — el
flujo de registración freemium vive solo en la copia MI. Además quedaron **3 queries con el join a
`alm_lotes` por revisar caso por caso** (el mismo patrón que causó la fuga de stock entre empresas).
Se anotó como deuda y no se tocó, para no ampliar el alcance de un PR que ya era riesgoso.

## 2.8 El plan de migración del núcleo (el trabajo grande) no arrancó

Todo lo hecho es REQ-ASSET-ALM, que era la **Etapa 5 adelantada**. Las Etapas 0 a 4 y 6 del
`doc/migracion/assetplanner-a-traz-tools-man.md` siguen sin empezar: rescatar el fork de `rnsanchez`,
corregir los 62 queries que pegan al motor equivocado, los 89 accesos de sesión, las 23 vistas
faltantes, y la reimplementación del Plan de Mantenimiento (extraer `guardar_agregar()` a una library
testeable, reemplazar los magic numbers de periodicidad por RRULE, y pasar a FullCalendar 6.x sin
jQuery ni Moment). El submódulo sigue apuntando al README vacío.

---

# 3. Decisiones técnicas tomadas acá que no están en ningún documento del repo

## 3.1 Contra qué WSO2 pega asset: se resolvió de facto, nunca se decidió

La pregunta "¿contra qué instancia de WSO2 va a pegar el asset de producción?" se planteó el 13/08 y
**nunca se respondió**. La implementación la resolvió sola: `application/config/constants.php:200`
define `HOST_TOOLS` como `HOST` — es decir, asset llama a los DataServices de tools **en el mismo
host al que ya llamaba**, con un comentario que dice "si tools pasa a otro host/MI, ajustar solo
`HOST_TOOLS`".

Funciona hoy porque ambos comparten el EI, pero es una decisión de topología tomada por omisión. El
día que tools se mude a su propio MI —que es el plan— esto se rompe en silencio y hay que acordarse
de esa línea. No está en el CONTEXT-PACK ni en el checklist de setup.

## 3.2 El vale de salida degrada en silencio si tools no responde

`tools_crear_vale_salida()` está pensada para **no romper el guardado del informe**: si tools está
caído, loguea el error y sigue. La consecuencia práctica es que el informe queda guardado con su vale
local (`tbl_valesalida`) pero **sin** la salida en el pañol de tools y **sin** la herramienta en
`TRANSITO` — o sea, la herramienta sigue apareciendo como disponible aunque se haya usado, y no hay
ningún registro visible de la discrepancia.

Se eligió esa degradación a propósito (mejor un informe guardado que un error en la cara del usuario),
pero **nadie decidió qué hacer con las salidas que se pierden**. No hay reintento, ni cola, ni
reconciliación. Está solo en el cuerpo del PR #335.

## 3.3 Los planes filtran herramientas por la disponibilidad de *hoy*

M2 filtra "todas las listas del módulo" por indicación del PM. El efecto colateral que eso tiene sobre
los **planes** es contraintuitivo y no está escrito: al armar un preventivo que se va a ejecutar
dentro de tres meses, solo se ofrecen las herramientas disponibles **ahora**. Una herramienta prestada
hoy no se puede declarar en un plan futuro.

Se marcó como revisable ("es un cambio de una línea si preferís que los planes muestren todas y solo
el informe filtre") y el PM no volvió sobre el tema. Vive solo en el resumen del PR #335. El análisis
de buenas prácticas posterior recomienda revertirlo: ver
`doc/v3/integracion-assetplanner-panol.md` §8.1 y la duda D2.

## 3.4 `getArticulos2` quedó huérfana en vez de borrarse

El fix #444 quitó el resource duplicado, con lo cual la query `getArticulos2` **quedó sin ningún
resource que la invoque** en ambas copias. Se decidió dejarla (quitar el resource es reversible;
borrar la query, no) en lugar de limpiarla. Es deuda muerta a la espera de que alguien decida si se
elimina o si se le devuelve un path propio.

## 3.5 Se modificaron datos de DEV que quedaron así

Para poder probar en pantalla se creó en `assetv2` de DEV un **grupo "Administrador" propio de la
empresa 1** (grupo 85, 198 permisos copiados, `grpDash="Otrabajo"`) y se le asignó el usuario de
prueba. **Eso quedó permanente y a pedido del PM.**

También quedaron en DEV, como datos de prueba: la config `1-ASSETDEPO/PANO/ESTA` de la empresa 1, los
pedidos 1485 y 1486, y los casos Bonita 30009 y 30010.

Detalle que salió de ahí y conviene recordar: **`grpDash` es el controlador que se carga dentro del
escritorio**, no el nombre del tablero. Ponerle `"Dash"` (el layout completo) cuelga la pantalla por
recursión; todos los grupos admin reales usan `"Otrabajo"`.

## 3.6 El doble login temporal se aceptó sin registrarlo

Durante el interinato, los usuarios del cliente operan con **dos logins**: el propio de asset
(tabla `sisusers`) y el de Dnato para tools, donde ven las pantallas de almacén y atienden la bandeja
de Bonita. Se planteó como trade-off a confirmar, el PM lo dio por aceptado en la práctica, y nunca
quedó escrito como decisión ni con fecha de vencimiento.

## 3.7 El nombre de un servicio DSS lo define el atributo `name`, no el archivo

`PANDataservice.dbs` publica `/services/PANDataService`. Costó dos redespliegues al pedo y un bug que
habría hecho fallar todo F4 en runtime. Está anotado como nota al pie en el STATE de asset, pero no en
ninguna guía de integración donde alguien lo vaya a buscar antes de escribir la próxima constante.

---

# 4. Temas de otros frentes que aparecieron y no se atendieron

## 4.1 🔴 Tres bugs que están hoy en producción de AssetPlanner

Los encontró el relevamiento del fork, **no los introdujo la migración**, y se documentaron sin
tocarlos porque corregirlos rompía el freeze:

1. **Fuga de aislamiento multi-tenant**: `... AND estadoprev = 'M' OR estadoprev = 'C' OR ...` sin
   paréntesis anula el filtro por empresa (`Equipos.php:830-832`). Misma clase de bug que ya había
   aparecido en las tools MCP y en `getArticulos`.
2. **~15 queries armadas por concatenación** con datos de `$_POST`.
3. **`setOTenSerie()` tiene un `while` sin límite ni transacción**: si la frecuencia queda en 0, crea
   OTs y lanza procesos Bonita hasta el timeout.

Quedaron como punto 6.4 de las decisiones a workshop del plan de migración. Nadie los movió.

## 4.2 La v2.5 retiró dos endpoints que este frente había restaurado

Con la v2.5 se aceptó como excepción retirar `GET /articulos` y `GET /articulos/obtener/{arti_id}` del
`ALMDataService`, por leer sin filtrar `empr_id`. Ya no están en ninguna de las dos copias.

Vale tenerlo presente porque es exactamente el cambio que en agosto tumbó el ALM de v2 —esta vez con
la verificación previa de que nadie los invoca, pero la excepción vive solo en el mensaje del tag
`v2.5` y en el cuerpo del PR #494.

## 4.3 El model de pedidos de *tools* tampoco es REST

Comparando para escribir F5 apareció que `traz-comp-almacenes` de tools pega **directo a Postgres**
para los pedidos, y que su `getInsumosOT` quedó apuntando a una tabla de asset. Es incoherente con la
arquitectura declarada (nada de SQL directo desde PHP) y con lo que acaba de hacer asset. Va a la
lista de deuda de la unificación; no se tocó.

## 4.4 No existe staging del frontend PHP

`doc/infra/ambientes.md` solo cubre el stack WSO2. No hay un Apache/PHP con réplica de `assetv2`
(harían falta dos empresas mínimo, para poder probar aislamiento). Es prerrequisito de la Etapa 0 del
plan de migración **y** del enganche de la regresión Playwright al CI/CD: hoy la suite se corre a mano
contra DEV con VPN, desde un servidor embebido single-thread que es lento y frágil.

## 4.5 La deuda de jQuery del fork es el gate real del go-live

Los 11 callbacks y 48 autocompletes rotos que dejó el intento de 2024 pertenecen al plan de migración
grande, no a REQ-ASSET-ALM. Pero mientras no se saneen, la migración del núcleo entrega datos que la
pantalla no puede operar. Es el gate del piloto con el cliente, y nadie le puso fecha.

---

# 5. Por dónde empezar cuando se retome

1. **Actualizar `doc/v3/STATE.md` de asset** (§2.1). Es media hora y es lo que evita que el próximo
   que llegue trabaje sobre un tablero falso.
2. **Resolver las dudas D1–D9** de `doc/v3/integracion-assetplanner-panol.md` con el Product Owner, y
   decidir si se adopta el esquema de tres capas del §8 de ese documento. De eso depende si la
   devolución de herramientas (§2.2) se implementa tal cual o si el circuito se reordena.
3. **Ejecutar el checklist de F2 para el cliente real** (§2.5) — es lo único que separa al
   requerimiento de estar efectivamente en uso.
4. **Aplicar la migración SQL en TEST** (§2.6).
5. Recién después, el **plan de migración del núcleo** (§2.8), que es un frente de meses y necesita
   antes el staging PHP (§4.4) y una decisión sobre la deuda de jQuery (§4.5).

Para reconstruir cualquier detalle: el transcript completo y el resumen narrativo están en
`~/.claude/projects/-mnt-win-dev-git-traz-tools/`, y la sesión original se reabre con
`claude --resume a9ab4de1-c943-4b3b-a1d5-5d892e35373b`.
