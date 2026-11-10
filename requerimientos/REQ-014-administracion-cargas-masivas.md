# REQ-014 · Módulo Administración — Cargas masivas

## Objetivo

Decimocuarto trabajo de Pablo para el módulo **Administración** (`traz-comp-adm`): la pantalla **Cargas
masivas** del Portal, con el mismo circuito que la carga masiva de DNATO (entidad → plantilla → archivo →
resultado) y la misma regla: **la carga es todo o nada**. Más lo nuevo de la especificación: el
procedimiento **nunca** viene del navegador, la carga de **usuarios** respeta el tope del plan y cada carga
queda en un **historial**. Lo leen Pablo para planificar (su primera tarea es revisar los procedimientos
contra la base de DEMO) y Rodolfo para recibir esa revisión y decidir sobre la invitación. **No** cambia
los procedimientos `sta.*` en la base ni la carga de DNATO, que sigue andando en paralelo; tampoco hace los formularios
([REQ-015](REQ-015-administracion-formularios.md)). Lista completa en [`README.md`](README.md).

| Campo | Valor |
|---|---|
| Estado | **Borrador**: Rodolfo tiene que contestar las dudas de los casos. Antes de construir, Pablo le avisa las diferencias entre los procedimientos del repositorio y los de la base de DEMO (primera tarea) |
| Se apoya en | [REQ-002](REQ-002-administracion-esqueleto.md) (controlador base, Portal), [REQ-004](REQ-004-administracion-base-y-atributos.md) (`seg.cargas_resultados`, auditoría), [REQ-007](REQ-007-administracion-usuarios-roles-perfil.md) (modelo `Membresias`, invitar, lugares y tope) y [REQ-013](REQ-013-administracion-actividad-y-auditoria.md) (acceso "Cargas masivas" del Inicio) |
| Entrega de la especificación | **E11** de `doc/v3/dnato/PROMPT_CLI_DNATO_V3_BUILD.md`: cargas masivas en la nueva UI; procedimiento validado contra el catálogo; tope; historial. CU-43; CP-77; RF-110, RNF-03 |
| Casos de uso | `ADM-UC-230` a `ADM-UC-234` en `doctest/catalogo/adm/` |
| Repos que se tocan | `traz-comp-adm` (pantalla, conversión de la planilla, carga de usuarios); `traz-tools`: recursos **nuevos** en `ADMDataService.dbs` (sobre `ToolsDataSource` y `AssetPlannerDataSource`) y una función nueva de base |
| Riesgo | 🔴 La función nueva `seg.ejecutar_carga(…)`, que envuelve a `sta.ejecutar_carga_masiva` sin cambiarla (lista en "Datos"), es **cambio de base aditivo: lo decide el equipo (regla de Rodolfo del 2026-11-10)**. Sigue en rojo por dos cosas: (1) ejecuta los **procedimientos existentes** de carga de Tools (`sta.*`) y de AssetPlanner (MariaDB `assetv2`) **sin modificarlos**, ahora desde el DataService → **análisis de impacto aprobado por Rodolfo** (sección "Análisis de impacto"); (2) la **revisión de procedimientos** de la primera tarea: si el de la base de DEMO carga fila por fila en vez de todo o nada, Pablo para y lo consulta con Rodolfo, que decide (cambiar un procedimiento existente necesita su aprobación). Los recursos del DataService son nuevos (🟡); `COREDataService` no se toca |

---

## Para qué sirve

- Hoy la carga masiva de DNATO funciona (DNATO-UC-026 y 027, validados), pero tiene tres agujeros
  (relevamiento A-21, `DNATO_v2_RELEVAMIENTO.md` §4.1 "Detalle de la carga masiva"):
  1. El **nombre del procedimiento llega del navegador** (`traz-comp-dnato/application/controllers/Bulkload.php:189`):
     cualquiera con sesión puede ejecutar cualquier función `sta.*` con esa firma.
  2. **No verifica que sea administrador**, solo que haya sesión (`Bulkload.php:29-31`, hallazgo H-029).
  3. El resultado se **pierde** al cerrar la sesión (tabla temporal `temp_log_messages`): no queda rastro
     de quién cargó qué.
- La especificación pide además poder **cargar usuarios** desde una planilla sin pasar el tope del plan
  (RF-72, CP-77).

## Quién lo usa

- **Administrador** de una empresa: Portal → Cargas masivas.
- **Usuario** (no administrador): se usa para probar el rechazo.

## Qué tiene que hacer

1. Ver las entidades que se pueden cargar y bajar la plantilla de cada una (DNATO-UC-026, RF-110) →
   **ADM-UC-230**.
2. Cargar una planilla en una entidad de Tools (PostgreSQL), ver el resultado por fila y guardarlo en el
   historial (DNATO-UC-027, RF-110) → **ADM-UC-231**.
3. Cargar una planilla en una entidad de Mantenimiento (AssetPlanner), con sus dos frenos de hoy: empresa
   sin vínculo y carga anterior sin terminar → **ADM-UC-232**.
4. Cargar usuarios respetando el tope del plan (CP-77, RF-72) → **ADM-UC-233**.
5. Rechazar un procedimiento que no está en el catálogo, y a quien no es administrador (CP-77, RF-110) →
   **ADM-UC-234**.

## Qué NO hace

- **No cambia ningún procedimiento de carga en la base** (`sta.ejecutar_carga_masiva`, `sta.bulkload_*`,
  `sta.calcula_*`, `sta.insert_log_message`) ni los de AssetPlanner. Lo único que hace con ellos es la
  revisión de la primera tarea: **versionar en el repositorio la versión que está en la base**. La función
  nueva que los envuelve tampoco cambia lo que hacen con una fila con error.
- **No toca `COREDataService`**: sus recursos `GET /entidades_negocio` y `POST /carga_masiva/archivo`
  (`COREDataService.dbs:1166-1180`) los sigue usando DNATO. Los del módulo son nuevos.
- **No agrega filas a `sta.entidades_negocio`.** La entidad "Usuarios" es **del módulo** (no tiene
  procedimiento): si se agregara a esa tabla, la pantalla de DNATO la ofrecería e intentaría ejecutar un
  procedimiento que no existe.
- **No cambia la carga de DNATO**: sigue andando igual, con sus agujeros, hasta la redirección final
  (REQ-016).
- **No pasa la invitación a una API** (lo que REQ-007 dejó para decidir acá): la carga de usuarios usa el
  mismo modelo `Membresias` del módulo, una invitación por fila (con la regla todo o nada). Ver "Decisiones tomadas" y la duda de ADM-UC-233.
- No deshace una carga que terminó bien (DNATO-UC-027: "una carga que terminó bien no se puede deshacer").
- No limpia la tabla de paso (staging) de AssetPlanner cuando quedó una carga a medias: avisa, como hoy.

---

## Cómo se arma

### Primera tarea de Pablo: revisar los procedimientos contra la base de DEMO

Antes de construir nada:

1. Bajar de la base de **DEMO** (solo lectura) la definición de `sta.ejecutar_carga_masiva`, de cada
   procedimiento que figura en `sta.entidades_negocio` (`sta.bulkload_*`) y de lo que ellos llamen
   (`sta.calcula_*`, `sta.insert_log_message` y cualquier otra función que aparezca).
2. Compararla con la que está en el repositorio (por ejemplo `bulkload_articulos.sql`, que el relevamiento
   cita en `DNATO_v2_RELEVAMIENTO.md` §4.1).
3. **La que vale es la de la base.** Versionar en el repositorio la versión de la base, en un commit propio
   y antes del código del módulo.
4. **Avisarle a Rodolfo las diferencias antes de construir**: qué procedimiento, qué cambia entre las dos
   versiones y, de cada uno, si en la base carga **todo o nada** o **fila por fila**.
5. Si alguno de la base carga fila por fila (las buenas entran y las malas se cuentan), **Pablo para y lo
   consulta con Rodolfo**: no lo cambia por su cuenta, porque cambiar un procedimiento existente necesita su
   aprobación. La regla de este requerimiento es todo o nada (DNATO-UC-027, validado en DEMO).

### Entidades (catálogo)

- Salen de `sta.entidades_negocio` (nombre, plantilla, motor `postgresql` / `mariadb`) por un recurso
  **nuevo** que **no** devuelve el nombre del procedimiento al navegador.
- Se suma la entidad **"Usuarios"**, propia del módulo, con una plantilla del módulo (columnas Correo,
  Nombre, Apellido, Rol **[SUPUESTO]**, las del formulario de invitar de REQ-007).
- Si el servicio no responde, la pantalla **no** muestra una lista "de prueba" (DNATO lo hace,
  `Bulkload.php:58-106`, con nombres de procedimiento que ni coinciden): muestra "No pudimos cargar las
  entidades. Probá de nuevo en un rato." y no deja procesar.
- La plantilla se baja de la dirección de `template` (como `Bulkload::descargarTemplate`,
  `Bulkload.php:732-810`), elegida por el **nombre** de la entidad, no por su posición en la lista.

### El archivo

- Solo `.xlsx` o `.xls` (como `Bulkload.php:208-214`). Se convierte a CSV en el servidor con la misma
  lógica de DNATO (`Bulkload.php:249, 352-620`), copiada al módulo sin cambiar lo que hace.
- Se guarda con nombre único en la carpeta de paso de cada ambiente, la misma que usa DNATO
  (`BULKLOAD_STAGING_DIR`, `traz-comp-dnato/application/config/constants.php:208`), porque los
  procedimientos de PostgreSQL leen el archivo con `COPY … FROM <archivo>` y el servidor de base tiene que
  poder leerlo (ver la duda de ADM-UC-231). Se borra al terminar.

### Entidades de Tools (PostgreSQL) — sin el procedimiento del navegador

1. El navegador manda **solo el nombre de la entidad** y el archivo.
2. El módulo llama a un recurso **nuevo** del DataService con entidad, ruta del archivo, empresa y correo
   (los dos últimos de la **sesión**).
3. El recurso llama a una función de base **nueva**, `seg.ejecutar_carga(entidad, archivo, empr_id,
   email)`, que en **una sola sesión de base**:
   - busca el procedimiento en `sta.entidades_negocio` por el nombre de la entidad con motor `postgresql`;
     si no está, devuelve "entidad desconocida" **sin ejecutar nada**;
   - llama a `sta.ejecutar_carga_masiva(procedimiento, archivo, empr_id)` tal cual está en la base,
     **sin cambiar** lo que hace con una fila con error (todo o nada, según la revisión de la primera
     tarea): la función no carga por su cuenta ni reintenta filas sueltas;
   - lee `temp_log_messages` (que solo existe en esa sesión de base) para armar el detalle por fila;
   - guarda la fila en `seg.cargas_resultados` (empresa, usuario, entidad, fecha, filas ok y con error,
     detalle);
   - limpia `temp_log_messages` y devuelve el resumen y el detalle.

   Tiene que ser una función porque la tabla de mensajes es **temporal de la sesión de base**: si la carga y
   la lectura fueran dos pedidos al DataService, podrían caer en conexiones distintas y el detalle se
   perdería.

### Entidades de Mantenimiento (AssetPlanner, MariaDB)

Mismo comportamiento que hoy (`traz-comp-dnato/application/models/Bulkloads.php:730-1065`), pero por el
DataService con `AssetPlannerDataSource` (ya existe en el proyecto de APIs) en vez de la conexión directa:

1. **Vínculo**: se traduce la empresa con `core.empresas.empr_id_mysql`. **Si está vacío, la carga se
   cancela** sin tocar nada, con el mensaje de la tabla de pantallas (hoy `Bulkloads.php:1060-1063`: "la
   carga se haría sobre otra empresa, así que se cancela").
2. **Carga anterior sin terminar**: si la tabla de paso de esa entidad tiene filas sin procesar, se cancela
   y se dice cuántas (hoy `Bulkloads.php:775-784`). No se borran solas.
3. Se insertan las filas en la tabla de paso (columnas mapeadas por el encabezado, como `:745-757`) y se
   llama al procedimiento con el `empr_id_mysql`.
4. El módulo guarda el resultado en `seg.cargas_resultados` por un recurso nuevo (no hay sesión de base
   compartida con MariaDB).

El nombre del procedimiento de MariaDB también sale del catálogo por el nombre de la entidad, nunca del
navegador.

### Solicitantes de transporte

Después de la carga, DNATO crea una empresa por cada solicitante con `POST API_CORE/empresa` y actualiza
`log.solicitantes_transporte.empr_id` (`Bulkloads.php:263-320`). El módulo **copia ese paso tal cual**
(ver la duda de ADM-UC-231).

### Usuarios (entidad del módulo, CP-77)

1. Se leen las filas de la planilla (Correo, Nombre, Apellido, Rol).
2. Se validan **todas antes de crear nada**: correo con formato válido, sin repetidos en la planilla, rol
   que exista en la empresa (`REST_BPM /roles`, como REQ-007), que no sea ya miembro, y que **todas** las
   filas entren en los lugares libres del plan (R4, RF-72). Cada fila que falla queda "con error" con su
   motivo; las que no entran en el tope, con "tope del plan".
3. **Todo o nada** (regla de Rodolfo del 2026-11-10): si una sola fila tiene error, **no se invita a
   nadie** y el resultado lista todas las filas con error.
4. Si todas están bien, se procesan **en orden**, cada una con la operación **invitar** del modelo
   `Membresias` de REQ-007 (la misma del Portal y de la Consola): correo nuevo, ya usuario, de baja; enlace
   con vencimiento; auditoría `miembro.invitar`. `Membresias` igual rechaza (409) si en el medio otro
   ocupó el último lugar.
5. Si una invitación falla a mitad de camino (servicio caído, 409 del tope), **se deshacen las anteriores**
   con la misma compensación de REQ-007 (quitar el rol, anular el enlace, dejar la membresía como estaba),
   y el resultado dice que no se cargó ninguna. Los correos de invitación se mandan **recién al final**,
   cuando todas quedaron hechas, para no avisarle a nadie de una invitación que se deshizo
   **[SUPUESTO]** (ver la duda de ADM-UC-233).
6. El resultado va a `seg.cargas_resultados` con entidad "Usuarios".

Antes de procesar, la pantalla avisa: "ℹ️ Si la planilla crea usuarios, se respeta el tope de tu plan
(<usados> de <tope> hoy): si no entran todos, no se carga ninguno." **[SUPUESTO]** (la maqueta dice "los
que no entren quedan rechazados en el resultado", que es carga parcial: ver la duda de ADM-UC-233).

### Historial

- Lista de las cargas de la **empresa de la sesión**, de la más nueva a la más vieja: Fecha, Quién,
  Entidad, Ok, Error (con "tope" si hubo rechazos por tope).
- Tocar una fila abre su resultado (detalle guardado) **[SUPUESTO]**; "⬇ CSV" baja ese detalle.
- Solo lectura: no hay borrar.

### Auditoría

La carga no deja fila propia en `seg.auditoria` (tiene su historial, como el consumo de IA tiene el
suyo); cada usuario invitado por la carga sí deja su `miembro.invitar` (ver la duda de ADM-UC-231).

---

## De dónde sale cada dato

| Dato | De dónde | Cómo |
|---|---|---|
| Es administrador | `ADMDataService GET /usuario/es-admin/…` | Ya existe (REQ-004) |
| Entidades (sin procedimiento) | `ADMDataService GET /cargas/entidades` (`sta.entidades_negocio`: nombre, plantilla, motor) | **NUEVO** |
| Ejecutar una carga de Tools | `ADMDataService POST /carga` → `seg.ejecutar_carga(…)` | **NUEVO** |
| Vínculo con AssetPlanner | `ADMDataService GET /empresa/{empr_id}/vinculo-asset` (`core.empresas.empr_id_mysql`) | **NUEVO** |
| Filas pendientes en la tabla de paso | `ADMDataService GET /carga-asset/{entidad}/pendientes` (sobre `AssetPlannerDataSource`) | **NUEVO** |
| Insertar en la tabla de paso y llamar al procedimiento | `ADMDataService POST /carga-asset` (pedido en lote; procedimiento resuelto por la entidad) | **NUEVO** |
| Guardar el resultado de una carga del módulo (AssetPlanner, Usuarios) | `ADMDataService POST /carga/resultado` | **NUEVO** |
| Historial y un resultado | `ADMDataService GET /empresa/{empr_id}/cargas`, `GET /empresa/{empr_id}/carga/{carga_id}` | **NUEVO** |
| Invitar cada usuario | Modelo `Membresias` de REQ-007 (`API_CORE /usuario`, `/rol/asignar`, recursos de REQ-007) | Ya existe (REQ-007) |
| Lugares y tope | `ADMDataService GET /empresa/{empr_id}/lugares` | Ya existe (REQ-007) |
| Roles de la empresa | `REST_BPM /roles` | Ya existe |
| Empresa por solicitante | `API_CORE POST /empresa` | Ya existe (no se modifica) |

**Nada va directo a la base** (RNF-03: "la carga masiva mantiene su mecanismo de procedimientos pero
invocado desde un servicio"). La empresa y el correo salen siempre de la sesión.

---

## Pantallas

### Portal — menú lateral

Se agrega "🗂️ Cargas masivas" bajo "Datos". `data-testid`: `adm-portal-menu-cargas`. El acceso del Inicio
(REQ-013) aparece desde este requerimiento.

### Portal → Cargas masivas — `traz-comp-adm/portal/cargas`

Maqueta `doc/v3/dnato/mockups/empresa-cargas.html`.

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Título | "Cargas masivas" y "Cargá artículos, herramientas, lotes, etapas o solicitantes desde una planilla. Mismo circuito de hoy, con historial." | `adm-cargas` |
| Nueva carga | "Entidad" (las del catálogo y "Usuarios"; las de Mantenimiento dicen "(AssetPlanner)") | `adm-cargas-entidad` |
| Plantilla | "⬇ Descargar plantilla <entidad>.xlsx" | `adm-cargas-plantilla` |
| Archivo | "Arrastrá el .xlsx o hacé clic para elegirlo" | `adm-cargas-archivo` |
| Aviso del tope | "ℹ️ Si la planilla crea usuarios, se respeta el tope de tu plan (<usados> de <tope> hoy): si no entran todos, no se carga ninguno." **[SUPUESTO]** (solo con "Usuarios") | `adm-cargas-aviso-tope` |
| Procesar | "Procesar carga" | `adm-cargas-procesar` |
| Historial | "Historial de cargas": Fecha, Quién, Entidad, Ok, Error | `adm-cargas-historial`; fila `adm-carga-<carga_id>` |
| Resultado | "Resultado · <entidad> · <fecha>", "<N> ok · <M> con error", "⬇ CSV"; tabla Fila, Nivel, Mensaje | `adm-cargas-resultado`; `adm-cargas-resultado-exportar` |

La leyenda de la maqueta "Las entidades salen del catálogo sta.entidades_negocio; el procedimiento nunca
viene del navegador." es una nota para el programador y **no** va en la pantalla (RNF-09, sin
tecnicismos).

Mensajes (los de DNATO-UC-027 en tuteo; los demás **[SUPUESTO]**):

| Caso | Mensaje | `data-testid` |
|---|---|---|
| Sin entidad | "Elegí qué vas a cargar." | `adm-cargas-error` |
| Sin archivo | "Elegí el archivo que vas a cargar." | `adm-cargas-error` |
| Formato | "Formato de archivo no válido. Solo se permiten archivos Excel (.xlsx, .xls)" | `adm-cargas-error` |
| Entidad desconocida | "Esa entidad no se puede cargar." (no se ejecuta nada) | `adm-cargas-error` |
| Sin vínculo con AssetPlanner | "Tu empresa no está vinculada con Mantenimiento, así que cancelamos la carga para no cargar los datos en otra empresa. Pedile a soporte que complete el vínculo." | `adm-cargas-error` |
| Carga anterior sin terminar | "Quedaron <N> filas sin procesar de una carga anterior de <entidad>. Pedile a soporte que las revise antes de volver a cargar." | `adm-cargas-error` |
| Terminó bien (todas las filas) | "Listo: se cargaron <N> filas." | `adm-cargas-ok` |
| Alguna fila con error (todo o nada) | "No se cargó ninguna fila: <M> con error. Corregí la planilla y volvé a cargarla." | `adm-cargas-error` |
| Falla del servicio | "No pudimos procesar la carga. Probá de nuevo en un rato." | `adm-cargas-error` |
| Sin entidades | "No pudimos cargar las entidades. Probá de nuevo en un rato." | `adm-cargas-error` |
| Fila rechazada por tope (en el resultado) | "Tope del plan: no hay lugar para <correo>." | — |

---

## Reglas

1. Solo el administrador de la empresa activa entra y carga.
2. El navegador manda el **nombre de la entidad**, nunca un procedimiento; una entidad que no está en el
   catálogo se rechaza sin ejecutar nada.
3. Solo `.xlsx` y `.xls`.
4. Los datos van siempre a la empresa de la sesión.
5. Para Mantenimiento, sin `empr_id_mysql` la carga se cancela; con filas pendientes en la tabla de paso,
   también.
6. La carga de usuarios respeta el tope: si las filas no entran todas en los lugares libres, no se carga
   ninguna y las que sobran figuran con "tope del plan".
7. La carga de usuarios usa la misma operación de invitar del Portal y la Consola.
8. Cada carga, buena o con errores, queda en el historial con quién, cuándo, entidad, filas ok y con
   error, y el detalle.
9. Una carga que terminó no se deshace ni se borra del historial.
10. **La carga es todo o nada**, en las tres clases de entidad (Tools, Mantenimiento y Usuarios): si una
    fila tiene error, no se carga ninguna (Rodolfo, 2026-11-10; DNATO-UC-027).
11. La función nueva no cambia lo que hace el procedimiento de la base con una fila con error. Si un
    procedimiento de la base carga fila por fila, no se cambia sin la aprobación de Rodolfo.

## Registro en el log

`log_message('DEBUG', '#TRAZA | ADM | <Clase> | <metodo>() ...')`: cada carga (entidad, quién, filas ok y
con error) y cada rechazo (entidad desconocida, sin vínculo, pendientes), sin datos de las filas.

---

## Datos

**Cambio de base aditivo: lo decide el equipo (regla de Rodolfo del 2026-11-10).** La función nueva va en
`seg`; envuelve un procedimiento de `sta` sin cambiarlo (el procedimiento queda en `sta`, donde está).

| Objeto | Qué es |
|---|---|
| `seg.ejecutar_carga(entidad, archivo, empr_id, email)` | Función **nueva** que busca el procedimiento por la entidad, llama a `sta.ejecutar_carga_masiva` sin cambiarla, lee `temp_log_messages`, guarda en `seg.cargas_resultados` y limpia. Nombre **[SUPUESTO]** |
| `seg.cargas_resultados` | Tabla de REQ-004 (empresa, usuario, entidad, fecha, filas ok, filas con error, detalle). Se usa tal cual; el detalle es una lista de (fila, nivel, mensaje) |

Ninguna tabla ni procedimiento existente cambia en la base. En el repositorio sí se **versiona** la
definición de la base de los procedimientos `sta.*` que difieran (primera tarea). No hay carga de datos.
Vuelta atrás: borrar la función.

---

## Análisis de impacto — lo aprueba Rodolfo antes de construir

| Qué | Detalle |
|---|---|
| Qué cambia | Los procedimientos de carga de Tools y de AssetPlanner se **llaman** desde recursos nuevos del DataService (antes, desde DNATO con conexión directa). Ninguno se modifica |
| Quién más los usa | DNATO (`Bulkload`), por su conexión directa y por `COREDataService POST /carga_masiva/archivo`: **no cambia** |
| Qué se rompe si falla | Una carga a medias en AssetPlanner deja filas en la tabla de paso: la próxima carga de esa entidad (de DNATO o del módulo) se cancela hasta que soporte las limpie, **igual que hoy** |
| Lugar del archivo | El servidor de base tiene que poder leer el archivo (`COPY … FROM`). Hoy funciona con la carpeta de DNATO; con PostgreSQL en otra máquina (infraestructura nueva) dejaría de funcionar también en DNATO. Ver la duda de ADM-UC-231 |
| Procedimientos del repositorio contra los de la base | La primera tarea de Pablo: los de la base de DEMO son los que valen, se versionan en el repositorio y las diferencias se le avisan a Rodolfo antes de construir. Si alguno de la base carga fila por fila, se para y decide Rodolfo |
| Pruebas | ADM-UC-230 a 234 en la copia de DEMO, y DNATO-UC-026 y 027 en verde (la carga de DNATO no cambió) |

---

## Decisiones tomadas

- **La carga es todo o nada** (Rodolfo, 2026-11-10): lo validado en DNATO-UC-027 es lo correcto. Manda
  sobre la especificación, que dice "la carga parcial por fila se mantiene" (RF-110, nota de la maqueta) y
  espera "se crean 2, … 2 rechazados" en CP-77. Vale también para la carga de usuarios.
- **Los procedimientos que valen son los de la base de DEMO** (Rodolfo, 2026-11-10): el repositorio puede
  estar atrasado (el relevamiento cita un `bulkload_articulos.sql` que carga fila por fila, y DNATO-UC-027
  se validó todo o nada en DEMO). Por eso la primera tarea los compara y versiona la versión de la base.
- **Cambios de base aditivos los decide el equipo** (Rodolfo, 2026-11-10): la función nueva no necesita su
  aprobación; cambiar un procedimiento existente, sí.
- **El procedimiento sale del catálogo por la entidad, dentro de la base**: así ni la pantalla ni el
  módulo pueden pedir otro (corrige el riesgo 1 del relevamiento, S11 de la maqueta).
- **Una función de base nueva envuelve la carga de Tools**, porque el detalle por fila vive en una tabla
  temporal de la sesión de base y el DataService no garantiza la misma sesión entre dos pedidos.
- **"Usuarios" es una entidad del módulo**, no de `sta.entidades_negocio`: crear un usuario necesita Bonita
  y AssetPlanner (API existente), que un procedimiento de base no puede llamar, y agregarla al catálogo
  haría que DNATO la ofrezca sin poder cargarla.
- **La invitación sigue en el modelo `Membresias` del módulo** (respuesta a la duda de REQ-007,
  ADM-UC-091), con la propuesta de pasarla a una API en un requerimiento aparte. Por qué: la operación
  necesita datos de la sesión de Bonita que hoy aporta el PHP (`Main.php:985-997`), y una API nueva en
  `_backend/api/` es núcleo con su propio análisis de impacto. Con el modelo, Portal, Consola y carga
  masiva ya invocan **el mismo código**. A confirmar por Rodolfo (duda de ADM-UC-233).
- **La lista "de prueba" de DNATO no se copia**: si el servicio no responde, no se carga.

## Cómo se revisa (además de DocTest)

- La revisión de procedimientos (primera tarea) hecha y avisada a Rodolfo antes de construir: en la
  descripción del pull request, qué procedimientos diferían, qué se versionó y que todos cargan todo o nada.
- Script de base (aditivo) corrido en una copia de DEMO, con su vuelta atrás.
- Una planilla con una sola fila mala no carga ninguna: en una entidad de Tools, en una de Mantenimiento y
  en Usuarios.
- Prueba directa al recurso con un nombre de procedimiento (`sta.cualquier_cosa`) en el campo de entidad:
  se rechaza sin ejecutar nada.
- DNATO-UC-026 y 027 en verde.
- `phpcs` con PHPCompatibility para PHP 5.6 sin errores; `./mvnw clean install` del proyecto de APIs.
- **Aviso para el despliegue:** el script de despliegue sube los DataServices pero no las APIs; este
  requerimiento no agrega APIs.

## Dudas abiertas

Están en los casos de uso (campo `dudas`), para contestarlas en un solo lugar.

---

## Casos de prueba de la especificación que cubre

| CP | Qué prueba | Lo cubre |
|---|---|---|
| CP-77 (tope) | Con 3 de 5 lugares, una planilla de 4 usuarios crea 2 y rechaza 2 por "tope del plan"; queda en el historial | ADM-UC-233, **con el resultado cambiado por la regla todo o nada** (Rodolfo, 2026-11-10): no se crea ninguno, las 2 que no entran figuran con "tope del plan" y la carga queda en el historial con 0 ok. Plan cargado a mano en la base de prueba, porque M-3 es REQ-016 |
| CP-77 (procedimiento) | Un procedimiento que no está en el catálogo se rechaza sin ejecutar nada | ADM-UC-234 |
| RF-110 (historial) | El resultado de cada carga se conserva y se consulta | ADM-UC-231 |
| RF-110 ("la carga parcial por fila se mantiene") | Carga parcial | **No se cubre**: la reemplaza la regla todo o nada de Rodolfo (2026-11-10), probada en ADM-UC-231, 232 y 233 |
| DNATO-UC-026, 027 | El circuito de hoy en la nueva UI | ADM-UC-230, 231 y 232 |
