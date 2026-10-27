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
- **Consecuencia junto con B-02:** en el DEMO **ninguna** tarea puede llegar a una bandeja; los casos TAR-UC-016/017/018 (bandeja, iniciar, finalizar) quedan bloqueados.
- **Tests:** `TAR-CP-011-01/011-03` (y los de bandeja se saltean con ese motivo).

#### B-04 · Otra empresa ve y **borra** tareas planificadas por URL (HIP-TAR-02 confirmada) — H-094 · #581
- **Qué pasa:** con la sesión de la empresa 2, `GET traz-comp-tareasestandar/tarea/planificar/PETR/<origen de la empresa 1>` devuelve las tareas de la empresa 1, y `DELETE traz-comp-tareasestandar/Tarea/eliminarPlanificada/<tapl_id de la empresa 1>` **la elimina** ("Se elimino la tarea planificada correctamente").
- **Evidencia:** verificado sobre `tapl_id 55` (dato de prueba). `TARDataService` `getTareasPlanificadas` y `deleteTareaPlanificada` no reciben `empr_id`. Mismo patrón que H-037 (ALM).
- **Tests:** `TAR-CP-X-01`, `TAR-CP-014-05`.
- **Bloqueante para exponer TAR por MCP** (brecha B-07 del spec).

### P2

#### B-05 · Editar una tarea estándar falla siempre que no tenga formulario y receta — H-095 · #582
- **Qué pasa:** "Guardar" en la edición devuelve "Algo salio mal". El backend responde `DATABASE_ERR`: `updateTarea` hace `CAST(:form_id as integer)` y `CAST(:rece_id as integer)` con texto vacío.
- **Evidencia:** `TARDataService.dbs` query `updateTarea`; el alta (`setTarea`) sí contempla el vacío con `case when ... = '' then null`. Reproducido por pantalla y por request directo.
- **Tests:** `TAR-CP-019-04`.

#### B-06 · El rollback del alta de pedido no elimina nada y responde basura (HIP-TAR-07 confirmada) — H-096 · #583
- **Qué pasa:** cuando el insert del pedido falla, `eliminarPedidoTrabajo($petr_id)` ignora el parámetro (lee GET/POST, vacíos), "borra" el pedido vacío y llama a Bonita para eliminar el caso con id vacío. Lo que vuelve al navegador es ese error de Bonita, no el motivo real.
- **Evidencia:** `Pedidotrabajo.php:255-271` y `352-406`; respuesta capturada: `"Error al invocar al BPM ... Can't convert non numeric ID to long"`.
- **Tests:** `TAR-CP-002-01`, `TAR-CP-002-07`.

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

### Fuera de TAR, encontrado de paso

#### B-11 · DNATO: asignar un rol de trabajo a un usuario falla ("Fallo asignación de roles.") — H-101 · #588
- **Qué pasa:** como administrador de `DocTest Empresa SA`, en Gestión de Usuarios → Cambio de Rol, agregar "Planificador de Tareas DocTest Empresa SA" a `produccion@` y Guardar responde `400 {"success":false,"message":"Fallo asignación de roles."}` (con y sin perfil elegido). Por eso ningún usuario de test tiene los menús de TAR (`@TAR-menu`).
- **Evidencia:** `POST traz-comp-dnato//main/changeLevelRolUserObject` → 400. No se investigó la causa (es otro repo).

---

## 4. Hipótesis del spec: estado después de la corrida

| HIP | Resultado |
|---|---|
| HIP-TAR-01 (hito con 0 en el id) | ⏳ no ejecutable: requiere pedidos (B-01). Confirmada **en código** (`Tarea::planificar()`), sin verificar en pantalla |
| HIP-TAR-02 (aislamiento) | ✅ **confirmada** — B-04 |
| HIP-TAR-03 (KPI) | ⏳ no ejecutable: requiere tareas finalizadas (B-02/B-03) |
| HIP-TAR-04 (hora real de inicio) | ⏳ no ejecutable: requiere bandeja. Confirmada **en código** (`notificacion_estandar.php:97-99`, `HH:MM` = mes) |
| HIP-TAR-05 (fecha real de fin) | ⏳ no ejecutable: requiere bandeja |
| HIP-TAR-06 (reasigna siempre) | ✔️ descartada en lo observable: asignar sin fecha no rompe la respuesta (`TAR-CP-011-05` pasa) |
| HIP-TAR-07 (rollback del alta) | ✅ **confirmada** — B-06 |
| HIP-TAR-08 (eliminar pedido deja tareas) | ⏳ no ejecutable: requiere pedidos |
| HIP-TAR-09 (alta sin feedback) | ⏳ no ejecutable hasta B-01 (hoy el alta falla antes) |
| HIP-TAR-10 (paginado) | ✅ **confirmada** — B-07 |
| HIP-TAR-12/13 (bandeja) | ⏳ no ejecutables: requieren bandeja. HIP-TAR-12 confirmada **en código** (`Tsttareas.php:43`) |
| HIP-TAR-16 (ids duplicados en plantillas) | ✔️ **descartada**: editar la plantilla precarga su nombre y no toca el formulario de tareas |
| HIP-TAR-18 (HH12) | ⏳ parcial: el DataService devuelve `HH12` sin AM/PM (visto: `31-12-3000+12:00:00`); el corrimiento al reasignar no se pudo medir sin caso |
| Resto (11, 14, 15, 17, 19-24) | ⏳ no ejecutadas en esta tanda |

## 5. Observaciones sin confirmar

- **Eliminar una subtarea es intermitente** (`TAR-CP-020-01`, en `@quarantine`): pasó en 2 de 4 corridas; en las otras quedaron las 3 subtareas en la vista. En el código, `eliminarSubtarea()` (`views/tareas/subtareas.php:99-118`) hace `$('tr#' + id).remove()` sobre **toda la página**, y las filas de tareas estándar también usan su id numérico como `id`: si un `suta_id` coincide con un `tare_id`, la fila equivocada sale de la vista. No se pudo atribuir la intermitencia a esa causa: queda a investigar antes de registrarlo como bug.
- **Resultados descartados por inestables**: guardar una tarea estándar sin duración pareció aceptarse en la primera corrida y no se reprodujo en las tres siguientes (`TAR-CP-019-02` pasa). No se reporta.
- **Hallazgo de código** (sin verificar en pantalla por B-02/B-03): `tarea_generica.php:50-60` muestra "Inicializar tarea" solo si el estado es `creada`; una tarea que llega a la bandeja está en `planificada`, así que el paso de iniciar se saltaría y nunca se registraría el inicio real. Se verifica con `TAR-CP-016-03/017-01` cuando B-02/B-03 estén resueltos.

## 5-bis. Resultado de la corrida final (2026-10-27, 57 tests, ~19 min)

| Resultado | Cantidad | Qué son |
|---|---|---|
| ✅ pasan | 21 | Validaciones del alta de pedido, catálogo de tareas, planificación (fecha pasada, 10:00), asignación sin fecha, usuarios asignables de la propia empresa |
| ❌ fallan | 22 | Los bugs de §3 y sus consecuencias en cascada (los tests de pedidos que necesitan un pedido creado). Después de esta corrida los bugs quedaron marcados con `test.fail()` y los bloqueados se saltean con motivo |
| ⏭️ saltean | 14 | Bloqueados por B-01 (sin pedidos: hitos, Trabajo Terminado, HIP-TAR-01/08) y por B-02/B-03 (sin caso: bandeja, iniciar, finalizar) |

Fallas de entorno vistas y no atribuidas al sistema: timeouts esperando el shell de Tools con la sesión de la empresa 2 (`TAR-CP-001-05`, `001-08`, `016-06`) y un `ERR_NETWORK_CHANGED` de la VPN en una corrida anterior.

## 6. Decisiones tomadas durante la prueba (sin el PM, a pedido suyo)

| Decisión | Por qué |
|---|---|
| Las pantallas se abren con `linkTo()` (lo mismo que hace el menú) y el test `@TAR-menu` marca la falta del menú | La asignación del rol de planificador falla en DNATO (B-11) |
| El ciclo de la tarea se probó sobre un origen sintético (`PETR/987654321`) dentro de la empresa de test | Sin pedidos no hay hitos (B-01); el componente de planificación es el mismo para cualquier origen. Los tests que necesitan el pedido real se saltean con el motivo escrito |
| No se cargó `pro.procesos` | No hay API ni pantalla, y la base del DEMO no es alcanzable. Queda el SQL listo (`seeds/tar/pro-procesos-empresas-test.sql`) |
| Datos de prueba solo en las empresas de test, con sufijo de corrida; la única escritura cruzada fue borrar desde la empresa 2 una tarea **de prueba** de la empresa 1 | Era la forma de confirmar HIP-TAR-02 sin tocar datos de otros |
| El catálogo queda en `borrador` y los specs **no** se declaran como `derivados` | Regla R1 de DocTest: un borrador no tiene derivados. Los specs existen para la corrida pedida por el PM; se declaran al validar |
| Perfil `Operario` propuesto en el schema para TAR-UC-016/017/018 | Duda D-01; el validador no acepta perfiles fuera del vocabulario |
| Hallazgos desde H-091 | Una copia local tiene H-090 sin commitear |
