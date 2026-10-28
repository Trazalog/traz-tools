# 🐞 Módulo TAR — Bugs detectados por DocTest, priorizados

## Objetivo

Lista de los bugs del módulo de Tareas (TAR) **confirmados en vivo** contra el DEMO el 2026-10-27 con la suite DocTest de TAR, ordenados por prioridad, con la evidencia y el test que los reproduce. Está escrito para el agente (o developer) que los va a corregir y para el PM que prioriza. Se lee antes de tocar el módulo. **No** cubre la especificación funcional del módulo ([`TAR-spec-modulo-tareas.md`](TAR-spec-modulo-tareas.md)) ni las propuestas de agente/KPI (§10 de ese spec), ni corrige nada: solo diagnostica.

| Campo | Valor |
|---|---|
| Entorno | DEMO de v2 (`demo.cloudtrazalog.com`), código de `develop` (`traz-comp-bpm` 4095a93f, `traz-comp-tareasestandar` c941a607) |
| Empresas | `DocTest Empresa SA` (empr_id 27) y `DocTest Empresa 2608242245` (empr_id 28, para aislamiento) |
| Suite | `doctest/tests/e2e/specs/tar/` — se corre con `npm run test:module -- tar` parado en `doctest/` |
| Datos | `npm run seed:tar` + `doctest/tests/e2e/seeds/tar/pro-procesos-empresas-test.sql` (este último **no** está aplicado: ver B-01) |
| Fecha | 2026-10-27 |

---

## 1. Cómo usar este documento (para quien corrige)

1. Tomá los bugs **en el orden de prioridad**. P1 bloquea el uso del módulo o filtra datos entre empresas.
2. Cada bug dice qué test lo reproduce. **Dónde se ejecuta:** terminal local con VPN, parado en `traz-tools/doctest/`:
   ```bash
   DOCTEST_ENV=demo node scripts/pw.mjs --project demo --retries 0 -g "TAR-CP-009-10"
   ```
   (reemplazá el id por el del test). Los tests de bugs confirmados llevan `test.fail(true, 'H-NNN ...')`: hoy figuran en verde como "fallo esperado". **Cuando el bug se corrige, el test se pone rojo**: ahí se saca la marca `test.fail()` en el mismo PR del arreglo y se verifica que pase.
3. La regla del `CLAUDE.md` aplica: casi todo esto es **core productivo** (DataServices, `traz-comp-bpm`, constants). Antes de cambiar, comparar contra `master` y escribir el análisis de impacto para el PM.
4. Al corregir: actualizar el estado del hallazgo `H-NNN` en `doc/hallazgos/REGISTRO.md`.

## 2. Prioridades

| Prioridad | Criterio |
|---|---|
| **P1** | El módulo no se puede usar, o hay fuga/pérdida de datos entre empresas |
| **P2** | Datos incorrectos o una operación principal falla, con rodeo posible |
| **P3** | Validación faltante o comportamiento confuso, sin pérdida de datos |
| **P4** | Cosmético |

---

## 3. Bugs confirmados

### P1

#### B-01 · Una empresa nueva no puede crear pedidos de trabajo — H-091 · #578
- **Qué pasa:** en `DocTest Empresa SA`, "Guardar" en el alta de pedido no crea nada. La empresa no tiene fila en `pro.procesos` (ni `PROCESO-STANDAR`): el formulario no trae `FormId`, el insert falla y la respuesta que llega al navegador **no es la del alta** sino un error de Bonita ("Can't convert non numeric ID to long") de la limpieza (ver B-06).
- **Causa confirmada en el DDL:** `pro.pedidos_trabajo.estado` es `NOT NULL` y se toma de `pro.procesos.esin_id`; sin proceso va nulo y el INSERT falla. Además, en el DDL del repo la PK de `pro.procesos` es solo `proc_id`, así que dos empresas no podrían tener cada una su `PROCESO-STANDAR` (ver el aviso del SQL de seed).
- **Por qué importa:** la registración freemium crea empresas sin proceso de pedidos, y no hay pantalla ni API para cargarlo. Todo el módulo (hitos, tareas, bandeja, indicadores) depende de tener pedidos.
- **Evidencia:** `Pedidotrabajo::guardarPedidoTrabajo()` (`traz-comp-bpm/controllers/Pedidotrabajo.php:193-274`) usa `procesos($proccessname)` y cae en `PRO_STD` sin validar que exista; `PRODataService` no tiene ningún INSERT a `pro.procesos`.
- **Tests:** `TAR-CP-002-01`, `prepara los datos de la corrida` (ciclo).
- **Dirección (no decidida):** que el alta de empresa cree `PROCESO-STANDAR`, o que el alta de pedido avise "la empresa no tiene configurado el proceso de pedidos". Es decisión funcional (duda agregada en TAR-UC-002).

#### B-02 · Ninguna tarea planificada llega a la bandeja: `TAREAS_DEFAULT_PROC` no está definida en el DEMO — H-092 · #579
- **Qué pasa:** una tarea libre se guarda con `proc_id = "TAREAS_DEFAULT_PROC"` (el **nombre** de la constante, que PHP deja como texto porque no está definida). Al planificarla y asignarla, la pantalla dice "Usuario asignado a la tarea correctamente." pero **no se lanza el caso** (`case_id` queda nulo) y la tarea nunca aparece en la bandeja del responsable.
- **Evidencia:** `traz-comp-tareasestandar/views/tareas/planificacion_tareas.php:11` (`'<?php echo TAREAS_DEFAULT_PROC ?>'`); `develop` sí la define (`application/config/constants.php:113`), así que el `constants.php` desplegado en el DEMO difiere del repo. Verificado: tarea `tapl_id 55`, planificada y asignada, quedó sin caso.
- **Tests:** `TAR-CP-009-10`, `TAR-CP-011-01/011-03`.
- **Antes de corregir:** comparar el `constants.php` del DEMO contra `develop`/`master` (es configuración de despliegue, no código).

#### B-03 · Las tareas estándar no pueden lanzar el proceso de tarea (TST001) — H-093 · #580
- **Qué pasa:** el selector "Proceso Asociado" del alta de tarea estándar solo ofrece "Reparacion Neumaticos" (con valor vacío) y "Fabricación". No ofrece `TST001`. Una tarea estándar sin proceso, al planificarla y asignarla, **no lanza caso** (`lanzarProceso()` retorna en silencio si `proc_id == ""`) y tampoco llega a la bandeja; el usuario ve "Usuario asignado... correctamente".
- **Evidencia:** `views/tareas/form.php` (`selectFromCore('proc_id', ..., 'procesos')` lee `core.tablas`), `models/Tareas.php:257-260`.
- **Causa raíz del selector:** se arma con `selectFromCore('proc_id', ..., 'procesos')` → `COREDataService` `GET /tablas/procesos` (`getTabla`), que **no filtra empresa**: las opciones son globales y no hay forma de ofrecer `TST001` solo a una empresa.
- **Consecuencia junto con B-02:** en el DEMO **ninguna** tarea puede llegar a una bandeja; los casos TAR-UC-016/017/018 (bandeja, iniciar, finalizar) quedan bloqueados.
- **Tests:** `TAR-CP-011-01/011-03` (y los de bandeja se saltean con ese motivo).

#### B-04 · Otra empresa ve y **borra** tareas planificadas por URL (HIP-TAR-02 confirmada) — H-094 · #581
- **Qué pasa:** con la sesión de la empresa 2, `GET traz-comp-tareasestandar/tarea/planificar/PETR/<origen de la empresa 1>` devuelve las tareas de la empresa 1, y `DELETE traz-comp-tareasestandar/Tarea/eliminarPlanificada/<tapl_id de la empresa 1>` **la elimina** ("Se elimino la tarea planificada correctamente").
- **Evidencia:** verificado sobre `tapl_id 55` (dato de prueba). `TARDataService` `getTareasPlanificadas` y `deleteTareaPlanificada` no reciben `empr_id`. Mismo patrón que H-037 (ALM).
- **Tests:** `TAR-CP-X-01`, `TAR-CP-014-05`.
- **Bloqueante para exponer TAR por MCP** (brecha B-07 del spec).

#### B-15 · La tarea planificada llega vacía a la bandeja y no se puede ejecutar — H-105 · #593
- **Qué pasa:** una tarea con proceso TST001 lanza su caso y queda `planificada`, pero en la bandeja del responsable se ve `Tarea Planificada | case: 71020 Sin Descripción Estado: Origen: ID: Nro de Pedido: Asignado: Fecha:`. Al abrirla no hay cabecera, subtareas ni formulario: solo "Tomar tarea / Cerrar / Hecho". No se puede ejecutar ni finalizar con el checklist.
- **Causa probable:** `Tsttareas::map()`, `desplegarCabecera()` y `desplegarVista()` leen con `Tareas::obtenerXCaseId()` → `TARDataService` `getTareaPlanificadaXCaseId`: `WHERE tp.case_id = :case_id` con el parámetro `STRING` y sin cast contra una columna entera (las demás queries castean). No se pudo ver el error del DataService del DEMO.
- **Tests:** `TAR-CP-016-01/016-02`, `TAR-CP-016-03/017-01/017-02`, `TAR-CP-018-02`, `TAR-CP-018-01/018-03`.
- **Bloquea** verificar HIP-TAR-04, 05, 12 y 13 en pantalla.

### P2

#### B-16 · Reasignar no saca la tarea de la bandeja del responsable anterior — H-106 · #594
- **Qué pasa:** después de reasignar una tarea con caso, sigue en la bandeja del responsable original (caso 71021).
- **Evidencia:** `Tareas::guardarPlanificada()` reasigna con `ObtenerActividades` + `setUsuario`; ver HIP-TAR-06.
- **Tests:** `TAR-CP-011-04`.

#### B-05 · Editar una tarea estándar falla siempre que no tenga formulario y receta — H-095 · #582
- **Qué pasa:** "Guardar" en la edición devuelve "Algo salio mal". El backend responde `DATABASE_ERR`: `updateTarea` hace `CAST(:form_id as integer)` y `CAST(:rece_id as integer)` con texto vacío.
- **Evidencia:** `TARDataService.dbs` query `updateTarea`; el alta (`setTarea`) sí contempla el vacío con `case when ... = '' then null`. Reproducido por pantalla y por request directo.
- **Tests:** `TAR-CP-019-04`.

#### B-06 · El rollback del alta de pedido no elimina nada y responde basura (HIP-TAR-07 confirmada) — H-096 · #583
- **Qué pasa:** cuando el insert del pedido falla, `eliminarPedidoTrabajo($petr_id)` ignora el parámetro (lee GET/POST, vacíos), "borra" el pedido vacío y llama a Bonita para eliminar el caso con id vacío. Lo que vuelve al navegador es ese error de Bonita, no el motivo real.
- **Evidencia:** `Pedidotrabajo.php:255-271` y `352-406`; respuesta capturada: `"Error al invocar al BPM ... Can't convert non numeric ID to long"`.
- **Tests:** `TAR-CP-002-01`, `TAR-CP-002-07`.

#### B-14 · El calendario muestra a las 03:00 las tareas de las 15:00 (HIP-TAR-18 confirmada) — H-104 · #591
- **Qué pasa:** una tarea planificada a las 15:00 llega al calendario como `dia_inicio: "2026-10-29T03:00:00"`: toda tarea de la tarde se ve 12 horas antes.
- **Evidencia:** `TARDataService` formatea `fec_inicio`/`fec_fin` con `to_char(..., 'YYYY-MM-DD+HH12:MI:SS')` sin AM/PM (`getTareasEventos`, `getTareasPlanificadas`, también `getKpiBasico`).
- **Tests:** `TAR-CP-010-04`.

### P3

#### B-07 · El paginado de pedidos informa mal los contadores (HIP-TAR-10 confirmada) — H-097 · #584
- **Qué pasa:** con la empresa sin pedidos (o una búsqueda sin resultados) la respuesta es `recordsTotal: 1`, `recordsFiltered: 1`, `data: false`. `recordsTotal` es además la cantidad de la página, no el total.
- **Evidencia:** `Pedidotrabajo::paginado()` líneas 576-590; respuesta capturada en la empresa 28.
- **Tests:** `TAR-CP-001-05`, `TAR-CP-001-06`.

#### B-08 · Se acepta una duración estándar imposible (`99:99`) — H-098 · #585
- **Qué pasa:** la máscara `99:99` acepta minutos > 59 y la tarea se guarda. El fin de la tarea se calcula con esos minutos.
- **Evidencia:** `views/tareas/form.php` (inputmask sin rango). Duda D-21 sigue abierta para el rango, pero 99 minutos no es HH:MM.
- **Tests:** `TAR-CP-019-03`.

### P4

#### B-09 · Pulsar la pestaña "Calendario" ya activa borra las tareas de la vista — H-099 · #586
- **Qué pasa:** `copiarTareas()` copia la lista de "Planificación Tareas" (vacía hasta que se la visita) encima de la del Calendario: queda "No hay Tareas Planificadas" aunque el hito tenga tareas. Recargando el hito vuelven (no se pierden datos).
- **Evidencia:** `views/tareas/planificacion.php:52-61`.
- **Tests:** `TAR-CP-009-09`.

#### B-10 · El selector de una plantilla sigue ofreciendo las tareas ya asociadas — H-100 · #587
- **Qué pasa:** después de asociar tareas a una plantilla, "Asociar Tarea" las sigue ofreciendo.
- **Evidencia:** `views/tareas/plantillas.php` `actualizarTareasSelect()` trae todas las tareas sin excluir las asociadas.
- **Tests:** `TAR-CP-021-01`.

#### B-12 · La opción de menú "Pedidos Trabajo" del módulo TAR abre el proceso de un cliente — H-102 · #590
- **Qué pasa:** en DNATO → Gestión de Menues, la opción `pedidotrabajo` del módulo TAR genera el menú `linkTo("traz-comp-bpm/Pedidotrabajo?proccessname=YUDI-NEUMATICOS")`. Una empresa que la asigna queda trabajando con el proceso de Yudica (`proccessname` queda en sesión y condiciona alta, detalle y cabecera).
- **Evidencia:** menú del planificador de la empresa 27 después de asignarle las opciones de TAR (2026-10-27). Las opciones `pedidotrabajo_metal` y `pedidotrabajo-prueba` sugieren una opción por cliente.
- **Tests:** `@TAR-menu el planificador ve los menús del módulo de Tareas` (navega por ese menú).

#### B-13 · Indicadores de tareas no tiene opción de menú asignable — H-103
- **Qué pasa:** el módulo TAR de Gestión de Menues ofrece `formulas`, `pedidotrabajo*`, `planificacion_tareas*`, `tareas*` y `tareas_std*`, pero ninguna para `traz-comp-tareasestandar/Reportes/indicadores`. La pantalla existe y responde por URL.
- **Tests:** `@TAR-menu los indicadores de tareas tienen opción de menú` (con `test.fail()`).

### Fuera de TAR, encontrado de paso

#### B-11 · DNATO: asignar un rol de trabajo a un usuario falla ("Fallo asignación de roles.") — H-101 · #588
- **Qué pasa:** como administrador de `DocTest Empresa SA`, en Gestión de Usuarios → Cambio de Rol, agregar "Planificador de Tareas DocTest Empresa SA" a `produccion@` y Guardar responde `400 {"success":false,"message":"Fallo asignación de roles."}` (con y sin perfil elegido). Era la razón por la que ningún usuario de test tenía los menús de TAR.
- **Causa encontrada:** la pantalla reenvía en `dataRole[]` **todos** los roles de la tabla, incluidos los que el usuario ya tiene. `Main::changeLevelRolUserObject()` (`traz-comp-dnato/application/controllers/Main.php:947-1022`) llama a `POST /rol/asignar` por cada uno; el primero (ya asignado) falla y se deshace todo. Cualquier usuario que ya tenga un rol no puede recibir otro desde la pantalla.
- **Rodeo verificado:** la misma API con **solo** el rol nuevo responde `200 "Roles Bpm asignados con exito."`. Así se le asignó "Planificador de Tareas" al planificador de test; quedó en `npm run seed:tar`.
- **Evidencia:** payload capturado de la pantalla (roles 1303 + 1306 → 400) vs. solo 1306 → 200.

---

## 4. Hipótesis del spec: estado después de la corrida

| HIP | Resultado |
|---|---|
| HIP-TAR-01 (hito con 0 en el id) | ⏳ no ejecutable: requiere pedidos (B-01). Confirmada **en código** (`Tarea::planificar()`), sin verificar en pantalla |
| HIP-TAR-02 (aislamiento) | ✅ **confirmada** — B-04 |
| HIP-TAR-03 (KPI) | ⏳ no ejecutable: requiere tareas finalizadas (B-02/B-03) |
| HIP-TAR-04 (hora real de inicio) | ⏳ no ejecutable: requiere bandeja. Confirmada **en código** (`notificacion_estandar.php:97-99`, `HH:MM` = mes) |
| HIP-TAR-05 (fecha real de fin) | ⏳ no ejecutable: requiere bandeja |
| HIP-TAR-06 (reasigna siempre) | parcial: asignar sin fecha no rompe la respuesta (`TAR-CP-011-05` pasa), pero reasignar con caso no saca la tarea de la bandeja anterior (B-16) |
| HIP-TAR-07 (rollback del alta) | ✅ **confirmada** — B-06 |
| HIP-TAR-08 (eliminar pedido deja tareas) | ⏳ no ejecutable: requiere pedidos |
| HIP-TAR-09 (alta sin feedback) | ⏳ no ejecutable hasta B-01 (hoy el alta falla antes) |
| HIP-TAR-10 (paginado) | ✅ **confirmada** — B-07 |
| HIP-TAR-12/13 (bandeja) | ⏳ la bandeja ya se alcanza (tareas TST001 por API), pero la tarjeta y la cabecera llegan vacías por B-15, que tapa a estas dos. HIP-TAR-12 confirmada **en código** (`Tsttareas.php:43`) |
| HIP-TAR-16 (ids duplicados en plantillas) | ✔️ **descartada**: editar la plantilla precarga su nombre y no toca el formulario de tareas |
| HIP-TAR-18 (HH12) | ✅ **confirmada** — B-14: el calendario muestra a las 03:00 una tarea de las 15:00. El corrimiento de la hora guardada al reasignar no se pudo medir sin caso |
| Resto (11, 14, 15, 17, 19-24) | ⏳ no ejecutadas en esta tanda |

## 5. Observaciones sin confirmar

- **Eliminar una subtarea es intermitente** (`TAR-CP-020-01`, en `@quarantine`): pasó en 2 de 4 corridas; en las otras quedaron las 3 subtareas en la vista. En el código, `eliminarSubtarea()` (`views/tareas/subtareas.php:99-118`) hace `$('tr#' + id).remove()` sobre **toda la página**, y las filas de tareas estándar también usan su id numérico como `id`: si un `suta_id` coincide con un `tare_id`, la fila equivocada sale de la vista. No se pudo atribuir la intermitencia a esa causa: queda a investigar antes de registrarlo como bug.
- **Una tarea libre de la corrida desaparece del origen** durante la suite completa (pasó en tres corridas, entre `TAR-CP-011-05` y `TAR-CP-014-05`), pero la secuencia reproducida aislada (crear → asignar sin fecha → abrir el modal de usuarios → GET de la empresa 2) no la borra. La única limpieza masiva del código (`delTareasSinOrigen`) solo la llama `Etapa.php` de Producción, que la suite no usa. Sin causa: `TAR-CP-014-05` pasó a usar su propia tarea.
- **`TAR-CP-010-01` en `@quarantine`**: a veces el clic sobre el día de FullCalendar no dispara `dateClick` y el modal de hora no abre (pasó en una corrida y en el probe aislado, falló en tres). Es del banco de pruebas, no del sistema: la planificación queda cubierta por `TAR-CP-010-04`, que planifica, asigna y lee el evento.
- **Resultados descartados por inestables**: guardar una tarea estándar sin duración pareció aceptarse en la primera corrida y no se reprodujo en las tres siguientes (`TAR-CP-019-02` pasa). No se reporta.
- **Hallazgo de código** (sin verificar en pantalla por B-02/B-03): `tarea_generica.php:50-60` muestra "Inicializar tarea" solo si el estado es `creada`; una tarea que llega a la bandeja está en `planificada`, así que el paso de iniciar se saltaría y nunca se registraría el inicio real. Se verifica con `TAR-CP-016-03/017-01` cuando B-02/B-03 estén resueltos.

## 5-bis. Corridas

**Corrida con menús reales y marcas de bugs** (2026-10-27, 23:24, `--grep @tar --grep-invert @quarantine`, ~12 min): 33 resultados esperados (21 pasan + los bugs marcados con `test.fail()` que fallan como se espera), 21 salteados por bloqueo con el motivo escrito y 3 inesperados, ya resueltos: `TAR-CP-010-04` era HIP-TAR-18 (pasó a B-14), `TAR-CP-014-05` pasó a usar su propia tarea (ver §5) y `TAR-CP-010-01` (modal de hora intermitente) tiene reintento del clic.

**Primera corrida completa** (2026-10-27, 22:54, 57 tests, ~19 min), antes de marcar los bugs:

| Resultado | Cantidad | Qué son |
|---|---|---|
| ✅ pasan | 21 | Validaciones del alta de pedido, catálogo de tareas, planificación (fecha pasada, 10:00), asignación sin fecha, usuarios asignables de la propia empresa |
| ❌ fallan | 22 | Los bugs de §3 y sus consecuencias en cascada (los tests de pedidos que necesitan un pedido creado). Después de esta corrida los bugs quedaron marcados con `test.fail()` y los bloqueados se saltean con motivo |
| ⏭️ saltean | 14 | Bloqueados por B-01 (sin pedidos: hitos, Trabajo Terminado, HIP-TAR-01/08) y por B-02/B-03 (sin caso: bandeja, iniciar, finalizar) |

Fallas de entorno vistas y no atribuidas al sistema: timeouts esperando el shell de Tools con la sesión de la empresa 2 (`TAR-CP-001-05`, `001-08`, `016-06`) y un `ERR_NETWORK_CHANGED` de la VPN en una corrida anterior.

## 6. Decisiones tomadas durante la prueba (sin el PM, a pedido suyo)

Lo que queda abierto **no tiene vía sin el PM** por reglas del proyecto, no por falta de intento:

| Pendiente | Por qué no lo puede cerrar el agente |
|---|---|
| Cargar `PROCESO-STANDAR` (destraba pedidos, hitos, HIP-TAR-01/08, Trabajo Terminado) | No existe API ni pantalla que escriba `pro.procesos` (búsqueda en todo `_backend` y `application`) y la base del DEMO no es alcanzable desde la VPN. Es una escritura de BD: 🔴 en la clasificación de riesgo del `CLAUDE.md` |
| Corregir #579, #580, #593 (las tareas libres y la vista de la bandeja) | Requiere corregir `constants.php` del DEMO o el catálogo global `core.tablas` `procesos`: es corregir bugs (el pedido dice que lo hace otro agente) y tocar core productivo (análisis de impacto + aprobación del PM) |
| Validar el catálogo | Es el gate humano de DocTest: solo el PM pasa un caso a `validado` |
| Mergear el PR #589 | `CLAUDE.md`: no se mergea sin confirmación explícita del PM |


| Decisión | Por qué |
|---|---|
| Los menús de TAR se asignaron al rol que el planificador ya tiene ("Responsable de Producción DocTest Empresa SA") desde DNATO → Gestión de Menues, con el administrador de la empresa de test: `tareas_grupo`, `tareas`, `pedidotrabajo`, `planificacion_tareas`, `tareas_std`. Los tests navegan por el menú real; si falta un ítem, caen a `linkTo()` y lo anotan | La asignación del rol "Planificador de Tareas" falla en DNATO (B-11). Es la vía oficial y solo toca la empresa de test. Responde la duda **D-04**: los menús son Tareas → ABM Tareas, Pedidos Trabajo y Planificación Tareas |
| El rol "Planificador de Tareas" se asignó **por la API de DNATO** mandando solo el rol nuevo (rodeo de #588), y el paso quedó en `npm run seed:tar` | Es la vía que habilitó el PM (APIs para seed y usuarios); el endpoint solo agrega roles, no quita ninguno |
| No se creó un usuario planificador nuevo | El alta de usuario de DNATO (`main/adduser`) solo pide empresa y perfil (Admin/Author); el rol de trabajo se asigna después con "Cambio de Rol", que es lo que falla (#588). Un usuario nuevo quedaría igual que `produccion@` |
| Las tareas estándar del ciclo se crean **por la API de la aplicación** (`Tarea/guardar`) con `proc_id=TST001`, solo para la empresa de test | El selector no lo ofrece (B-03) y sin proceso nada llega a la bandeja. El alta de empresa ya mapea el actor de "TST001 - Tarea Planificada" al grupo de cada empresa (`toolsCOREAPI.xml:398-401`), así que el proceso existe. Con esto se destrabó el ciclo de bandeja y aparecieron B-15 y B-16. B-03 sigue cubierto por `TAR-CP-019-07` |
| Si el clic en un día no dispara el `dateClick` de FullCalendar, el page object llama al mismo manejador de la vista (`clickCalendario(info)`) | Falla de banco de pruebas intermitente; es lo que FullCalendar invoca |
| Se descartó correr el ciclo en otra empresa del DEMO | La otra empresa habilitada para DocTest (Novu, usuario de MAN) tampoco tiene proceso de pedidos, clientes, tipos de trabajo ni menús de TAR (verificado en modo lectura). No se crearon datos en empresas que no son de test |
| **No** se agregó `TST001` a la Lista de Valores `procesos` para destrabar la bandeja | `getTabla` no filtra empresa: el valor aparecería en el selector de **todas** las empresas del DEMO (B-03) |
| El ciclo de la tarea se probó sobre un origen sintético (`PETR/987654321`) dentro de la empresa de test | Sin pedidos no hay hitos (B-01); el componente de planificación es el mismo para cualquier origen. Los tests que necesitan el pedido real se saltean con el motivo escrito |
| No se cargó `pro.procesos` | No hay API ni pantalla, y la base del DEMO no es alcanzable. Queda el SQL listo (`seeds/tar/pro-procesos-empresas-test.sql`) |
| Datos de prueba solo en las empresas de test, con sufijo de corrida; la única escritura cruzada fue borrar desde la empresa 2 una tarea **de prueba** de la empresa 1 | Era la forma de confirmar HIP-TAR-02 sin tocar datos de otros |
| El catálogo queda en `borrador` y los specs **no** se declaran como `derivados` | Regla R1 de DocTest: un borrador no tiene derivados. Los specs existen para la corrida pedida por el PM; se declaran al validar |
| Perfil `Operario` propuesto en el schema para TAR-UC-016/017/018 | Duda D-01; el validador no acepta perfiles fuera del vocabulario |
| Hallazgos desde H-091 | Una copia local tiene H-090 sin commitear |
