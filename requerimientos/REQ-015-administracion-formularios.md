# REQ-015 · Módulo Administración — Formularios de la empresa

## Objetivo

Decimoquinto trabajo de Pablo para el módulo **Administración** (`traz-comp-adm`): las **pantallas** para
administrar los formularios dinámicos que usan las pantallas de Tools: **Formularios** del Portal (los
propios y los globales disponibles, el constructor, la vista previa, "Usar como base" y "Dónde se usan") y
**Formularios globales** de la Consola (con el catálogo de puntos de uso). Lo leen Pablo para planificar y
Rodolfo para aprobar el análisis de impacto y para decidir el requerimiento aparte del módulo compartido.
**No** cambia nada dentro de `traz-comp-formularios` (módulo compartido con todo Tools): esos cambios van en
un requerimiento **aparte** con su análisis de impacto, y la sección "Qué NO hace" lista exactamente cuáles
son. Tampoco hace la migración de la empresa plantilla 9000 (va con ese requerimiento aparte o con
[REQ-016](REQ-016-administracion-migracion-completa.md)). Lista completa en [`README.md`](README.md).

| Campo | Valor |
|---|---|
| Estado | **Borrador**: Rodolfo tiene que contestar las dudas de los casos (en especial el DDL real de `frm.*`), aprobar el análisis de impacto y decidir cuándo va el requerimiento aparte de `traz-comp-formularios` |
| Se apoya en | [REQ-002](REQ-002-administracion-esqueleto.md) (controlador base, Portal, Consola), [REQ-004](REQ-004-administracion-base-y-atributos.md) (auditoría; REQ-004 dejó los atributos de `frm.*` para acá), [REQ-008](REQ-008-administracion-consola-empresas.md) (pestaña "Formularios" de la ficha de la empresa); relevamiento [`doc/v3/dnato/FORMULARIOS_DINAMICOS_RELEVAMIENTO.md`](../doc/v3/dnato/FORMULARIOS_DINAMICOS_RELEVAMIENTO.md) y sus decisiones D1 a D3 |
| Entrega de la especificación | **E11b** de `doc/v3/dnato/PROMPT_CLI_DNATO_V3_BUILD.md`, solo la parte de pantallas: constructor (Portal y Consola), listas de opciones, vista previa sin respuesta, usar como base, puntos de uso. CU-70 a 76; CP-120 a 132; RF-120 a 131; R9 |
| Casos de uso | `ADM-UC-250` a `ADM-UC-255` en `doctest/catalogo/adm/` |
| Repos que se tocan | `traz-comp-adm` (pantallas, constructor, vista previa); `traz-tools`: recursos **nuevos** en `ADMDataService.dbs` y un script de base. **No** se toca `traz-comp-formularios` |
| Riesgo | 🔴 Las columnas nuevas optativas en `frm.formularios`, la tabla nueva `seg.formularios_puntos_uso` con su carga inicial y las funciones nuevas en `seg` (lista en "Datos") son **cambio de base aditivo: lo decide el equipo (regla de Rodolfo del 2026-11-10)**. El DDL real de `frm.*` **no está en el repositorio** (duda de ADM-UC-251): hace falta para escribir el script sin adivinar, no para aprobarlo. Sigue en rojo por el **núcleo de Tools**: se escriben `frm.formularios`, `frm.items` y `core.tablas` (listas de opciones y configuración `configuraciones/formulario_<punto>`), que leen las pantallas de almacenes, pañol, tareas estándar y etapas → **análisis de impacto aprobado por Rodolfo** (sección "Análisis de impacto"). Recursos del DataService nuevos (🟡) |

---

## Para qué sirve

- Hoy **no hay ninguna pantalla** para crear o editar formularios: todo se hace con SQL a mano, con
  scripts que se contradicen (relevamiento §6 y §4; el formulario de registro aparece como 24, 1 y 72).
- Para cambiar qué formulario muestra una pantalla de Tools hay que tipear el número del formulario en el
  ABM "Lista de valores" (CU-74, "Hoy").
- Los formularios globales no tienen dónde verse ni mantenerse; el alta de empresa clona uno solo desde la
  empresa plantilla 9000 (relevamiento §4.2).

## Quién lo usa

- **Administrador** de una empresa: Portal → Formularios (los propios de su empresa).
- **Superusuario**: Consola → Formularios globales y puntos de uso; único que usa los tipos avanzados.
- **Usuario** (no administrador): se usa para probar el rechazo.

## Qué tiene que hacer

1. Listado de formularios propios y globales disponibles, con estado, campos, dónde se usa y respuestas;
   activar e inactivar con aviso si está en uso (CU-70, RF-120, RF-128, RF-130) → **ADM-UC-250**.
2. Constructor: cabecera, ítems arrastrables, nombre interno, listas de opciones existentes o nuevas,
   guardar como borrador o publicar; con respuestas, nombre interno y tipo bloqueados (CU-71, RF-122,
   RF-123, RF-128) → **ADM-UC-251**.
3. Vista previa con el mismo dibujo de Tools, sin crear ninguna respuesta (CU-73, RF-124) →
   **ADM-UC-252**.
4. Duplicar y "Usar como base" un global (CU-72, RF-125) → **ADM-UC-253**.
5. "Dónde se usan": elegir, por pantalla de Tools, el formulario propio, global o ninguno (CU-74, RF-126)
   → **ADM-UC-254**.
6. Consola → Formularios globales y puntos de uso, con los tipos avanzados (CU-75, RF-121) →
   **ADM-UC-255**.

## Qué NO hace

### Cambios dentro de `traz-comp-formularios` que harían falta (requerimiento aparte, con análisis de impacto)

Regla del módulo compartido: cambio mínimo y nunca cambiar contratos de retorno. Cada cambio, con el lugar
de hoy y el CP que queda sin cubrir mientras no esté:

| # | Cambio necesario | Dónde está hoy | CP que no se cubre sin él |
|---|---|---|---|
| F-1 | **Opciones empresa → global (R9)**: al dibujar, buscar la lista de la empresa y, si no existe, la global del mismo nombre | `Forms::obtenerValores` busca solo `empresa()."-".$id` (`traz-comp-formularios/models/Forms.php:228-231`) | CP-122 ("obras (global)" **en las pantallas de Tools**), CP-124 parte "eva@ ve Obra A y Obra B (global)" **en Tools**, CU-76 |
| F-2 | **Validación en servidor, sesión obligatoria y protección de envíos** en `Form/*`; `info_id` verificado contra la empresa; `obtenerTodos` filtrado por empresa o quitado (correctivo C-9) | `Form.php:5-10` sin control; `Form::guardar` toma el envío crudo (`Form.php:58-62`); `Forms::listado` sin empresa (`Forms.php:379-386`) | **CP-129** completo |
| F-3 | **`info_id` por secuencia** en vez de `select_max` (correctivo C-10) | `Forms.php:98` | Ninguno directo; es riesgo de respuestas cruzadas |
| F-4 | **Respetar el estado** al dibujar por número: no dibujar cabeceras `inactivo` o dadas de baja en los puntos de uso (R9 "si … está publicado") | `obtenerPlantilla` y `obtenerXEmpresa` no miran la cabecera (`Forms.php:183-191`, `414-418`) | CP-128 en el caso de una pantalla que llega al formulario por número fijo (ver "Cómo se arma": en los puntos de uso se cubre limpiando la configuración) |
| F-5 | **DDL de `frm.*` versionado** en el repositorio (incluida la columna `multiple`, que no figura en ningún script) | Solo en el volcado binario `_backend/database/traz_tools_v1.5.8.5.dmp` (relevamiento §1) | Ninguno directo; bloquea escribir el script de este requerimiento sin adivinar |

### Otros cambios de núcleo que tampoco hace

- **No modifica `FRMDataService.getFormularios`** (decisiones D2 y D3: que los combos de tareas estándar,
  subtareas y etapas muestren también los globales, con "(global)"). Verificado: hoy sigue filtrando solo
  `empr_id = :empr_id` (`FRMDataService.dbs:6`). Sin ese cambio **no se cubre** la parte de CP-130 "el
  combo de tareas estándar … muestra … G-1, G-2 marcados (global)", ni T-8 (que los combos respeten el
  estado).
- **No cambia el disparador de alta de empresa** (`configuracion_inicial_empresa_trg`, que clona "Entrega
  Materiales" desde la 9000) ni la orquestación de alta: **CP-127** (el alta escribe la configuración
  apuntando a los globales, sin copiar) queda fuera. La marca "Global al alta" se guarda, pero nadie la usa
  hasta ese cambio.
- **No hace la migración M-7b / RF-131** (los formularios de la 9000 pasan a globales): mover el `empr_id`
  de la 9000 rompería el clonado del disparador mientras siga existiendo. **CP-132** queda fuera; se hace
  junto con el cambio del disparador (ver la duda de ADM-UC-255).
- **No cambia las pantallas de Tools que leen la configuración** (T-7: `Entrega_Material.php:50`,
  `Order.php:31`, `Herramienta.php:56`): siguen leyendo `configuraciones/formulario_<punto>` como hoy, y por
  eso **ven enseguida** lo que se elige en "Dónde se usan".
- **No permite editar el formulario del autorregistro** (el que usa el registro, hoy número fijo): se ve en
  la Consola en solo lectura (registración = núcleo; duda de ADM-UC-255).
- No cambia cómo se carga una respuesta (CU-76): las pantallas de Tools siguen igual.
- No versiona formularios: alcanza con la "foto" de la definición que guarda cada respuesta (RF-128).

---

## Cómo se arma

### Modelo (lo que ya existe y lo que se agrega)

- **Formulario** = `frm.formularios` (cabecera) + `frm.items` (campos). **Propio** = con el `empr_id` de la
  empresa; **global** = `empr_id` nulo (decisión D1).
- **Estado** (RF-128): columna nueva `estado` (`borrador` / `publicado` / `inactivo`). Todos los formularios
  existentes quedan `publicado` (valor por defecto), así nada cambia para v2. **Baja lógica**: inactivar no
  borra nada; nunca se pone `eliminado` ni se borra una fila (ver la duda de ADM-UC-250).
- **Copiado de**: columna nueva con el formulario de origen de una copia (RF-125).
- **Respuestas** de un formulario = cantidad de `info_id` distintos en `frm.instancias_formularios` con ese
  `form_id` (no se leen los valores).
- **Listas de opciones** = filas de `core.tablas` con el mismo mecanismo de hoy (el disparador
  `core.set_tabla_id_trg` antepone el `empr_id`; relevamiento §1.d). Lista global = sin empresa.
- **Puntos de uso** = tabla nueva `seg.formularios_puntos_uso` con clave (`formulario_entrega_materiales`, …), pantalla, módulo y
  "global al alta". Carga inicial: las cuatro claves de la maqueta `consola-formularios.html`.
- **Dónde se usa** (mecanismo A del relevamiento) = la fila `configuraciones` / `formulario_<punto>` de la
  empresa en `core.tablas`, con el número de formulario en `descripcion` (relevamiento, duda 4).

### Portal → Formularios (CU-70)

- **Mis formularios**: los de la empresa de la **sesión**, con Formulario (nombre y "copiado de …" o
  "creado el …"), Estado, Campos, Dónde se usa, Respuestas, y "Editar", "Vista previa", "Duplicar",
  "Publicar" / "Inactivar" / "Activar".
- **Globales disponibles**: los globales **publicados** (no los borradores ni los inactivos), con
  Formulario, Campos, "Lo usás en" y "Vista previa", "⧉ Usar como base". **Nunca** "Editar" (CP-120).
- **Inactivar** uno en uso: ventana "Está en uso en <punto>: esa pantalla quedará sin formulario hasta que
  elijas otro en "Dónde se usan". Las <N> respuestas cargadas se siguen viendo." con "Cancelar" /
  "Inactivar". Al confirmar, en **la misma operación**: estado `inactivo` y la configuración de esos puntos
  de la empresa queda en "ninguno" (así la pantalla de Tools dice "No se especificó un formulario", como
  hoy cuando no hay; CP-126). Sin esto, como Tools dibuja por número (F-4), seguiría mostrándolo.
- Un formulario de otra empresa no aparece nunca (RF-130, CP-130). Pedir uno ajeno por la dirección da
  "Esa página no existe." (404, REQ-002).

### Constructor (CU-71) — `traz-comp-adm/portal/formulario/<form_id>`

- Cabecera: nombre (obligatorio, **único en su ámbito**: la empresa, o los globales; hasta 45 caracteres,
  el largo de la columna, relevamiento §1.a) y descripción (hasta 300).
- **Paleta** (maqueta `empresa-formulario-editor.html`), con los tipos que hoy dibuja el helper (relevamiento
  §2): Texto corto, Área de texto, Número, Fecha; Lista desplegable, Casillas (varias), Opciones
  excluyentes; Archivo, Imagen (cámara); Título, Comentario. Los avanzados (lista desde servicio / URL:
  `service`, `urlConsultor`, `urlEvaluador`) solo en la Consola, para el superusuario; en el Portal se ve
  "Los tipos avanzados (lista desde servicio / URL) solo los configura Trazalog."
- Por ítem: etiqueta, **nombre interno** (se sugiere de la etiqueta: minúsculas, sin acentos, espacios por
  "_", CP-123; editable), obligatorio, ancho (Completo, Mitad, Un tercio → la clase de columna que guarda
  hoy `columna`), valor por defecto; para listas, la lista de opciones y "Permite varias".
- **Listas** (RF-123): "Elegir una lista existente…" muestra las de la empresa como "<lista> (de tu
  empresa)" y las globales como "<lista> (global)"; "＋ Crear lista nueva" pide nombre y valores (uno por
  línea) y la crea en `core.tablas` de la empresa (en la Consola, global).
- Ordenar arrastrando. "Guardar borrador" y "Publicar".
- **Reglas en el servidor** (CU-71 E1 a E3): nombre repetido en el ámbito → "Ya hay un formulario con ese
  nombre" **[SUPUESTO]**; dos ítems con el mismo nombre interno → "Ya hay un campo con ese nombre" (CP-123);
  publicar sin ningún ítem con nombre (solo títulos y comentarios) → "Agregá al menos un campo" (CP-121).
- **Con respuestas** (CU-71 A2, RF-128): nombre interno y tipo bloqueados con "Este formulario ya tiene
  respuestas"; se puede cambiar etiqueta, orden, obligatorio, ancho, y dar de baja un ítem (queda
  `eliminado` y el dibujo de Tools ya lo oculta, `Forms.php:190`; las respuestas viejas lo conservan). El
  servidor rechaza igual un cambio de nombre interno o tipo aunque la pantalla no lo ofrezca.
- Cada guardado es **una** operación del DataService (cabecera, ítems, listas nuevas y auditoría juntas).

### Vista previa sin respuesta (CU-73, RF-124)

La vista previa **no** usa `nuevoForm` (que crea una respuesta vacía, `form_helper.php:282-290`). El módulo
arma los datos del formulario (cabecera, ítems y opciones) desde sus recursos y llama a la función de
dibujo **existente** `form($data)` del helper (`traz-comp-formularios/helpers/form_helper.php:3-87`), la
misma que usa Tools: **mismo dibujo, sin crear nada y sin cambiar el módulo**. Las opciones se resuelven
con R9 (empresa y, si no hay, global) **solo para la vista previa**; mientras no exista F-1, una lista
global se marca "(global · en Tools todavía se ve vacía)" **[SUPUESTO]** (ver la duda de ADM-UC-252).

### Usar como base y duplicar (CU-72, RF-125)

- "⧉ Usar como base" (sobre un global) y "Duplicar" (sobre un propio): piden el nombre de la copia y crean,
  en **una** operación, cabecera, ítems y **copias** de sus listas de opciones en la empresa, en
  `borrador`, con "copiado de". Abren el constructor, que avisa "Esta copia no sigue los cambios del
  formulario global" (CP-125).
- Si una lista con el mismo nombre ya existe en la empresa, se usa la de la empresa y no se copia
  **[SUPUESTO]** (duda de ADM-UC-253).

### Dónde se usan (CU-74, RF-126)

- Una fila por punto de uso del catálogo: Pantalla, Módulo y un selector con los propios **publicados**,
  los globales **publicados** ("🌐 … (global)") y "Ninguno". Los borradores aparecen deshabilitados con
  "(propio · borrador, publicalo primero)" (maqueta). "Guardar" escribe la fila
  `configuraciones/formulario_<punto>` de la empresa.
- Elegir "Ninguno" avisa "La pantalla quedará sin formulario" y, al confirmar, la fila queda dada de baja
  (`eliminado`) **[SUPUESTO]**: la pantalla de Tools muestra "No se especificó un formulario" y guarda sin
  `info_id`, como hoy (CP-126).
- Debajo, **solo lectura**: procesos (`pro.procesos_forms`), tareas estándar y etapas con su formulario y el
  enlace a su ABM ("Ir a Procesos →", "Ir a Tareas estándar →", "Ir a Etapas →").
- Como las pantallas de Tools leen esa fila directamente, el cambio se ve en la próxima carga de la
  pantalla (CP-126 "la pantalla de entrega directa de Tools dibuja G-1"), sin tocar Tools.

### Consola → Formularios globales (CU-75, RF-121)

- Pestaña **Globales**: Formulario, Estado, Campos, "Empresas que lo usan" (por referencia en su
  configuración), "Copias" (formularios con "copiado de" igual a este), "Al alta de empresa", y "Editar",
  "Vista previa", "Publicar" / "Inactivar". "＋ Nuevo global". El mismo constructor, con los tipos
  avanzados.
- **Inactivar** un global en uso: "Lo usan por referencia <N> empresas en <puntos>: esas pantallas quedarán
  sin formulario hasta que cada empresa elija otro. Las copias no se tocan." y confirmación (CP-131). Al
  confirmar, como en el Portal, la configuración de esas empresas para esos puntos queda en "Ninguno"
  (ver la duda de ADM-UC-255).
- Pestaña **Puntos de uso**: Clave, Pantalla, Módulo, "Global al alta" (selector), "＋ Punto de uso". Leyenda
  "Al dar de alta una empresa se escribe su configuración apuntando a estos globales (por referencia, sin
  copiar)…" **[SUPUESTO]** cambiada mientras no exista el cambio del disparador: "Se va a usar cuando el
  alta de empresa escriba la configuración (todavía clona desde la empresa plantilla)."
- Los formularios propios de cada empresa se ven en la pestaña "Formularios" de la ficha de la empresa
  (REQ-008), en solo lectura **[SUPUESTO]**.

### Auditoría (RF-130)

En la misma operación que el cambio: `formulario.crear`, `formulario.editar`, `formulario.publicar`
(CP-121), `formulario.inactivar`, `formulario.activar`, `formulario.duplicar`, `formulario.copiar` (usar
como base), `formulario.punto_uso` (cambio en "Dónde se usan"), `lista.crear`, `punto_uso.editar`. Salvo
`formulario.publicar`, **[SUPUESTO]**.

---

## De dónde sale cada dato

| Dato | De dónde | Cómo |
|---|---|---|
| Es administrador / superusuario | `ADMDataService GET /usuario/es-admin/…`, `/usuario/es-super/…` | Ya existe (REQ-004) |
| Formularios propios y globales con estado, campos, uso y respuestas | `ADMDataService GET /empresa/{empr_id}/formularios`, `GET /consola/formularios` | **NUEVO** |
| Un formulario con sus ítems (verifica que sea de la empresa o global) | `ADMDataService GET /empresa/{empr_id}/formulario/{form_id}` | **NUEVO** |
| Guardar (cabecera, ítems, listas nuevas, auditoría) | `ADMDataService PUT /formulario` → función nueva | **NUEVO** |
| Cambiar estado (y limpiar la configuración si estaba en uso) | `ADMDataService PUT /formulario/estado` → función nueva | **NUEVO** |
| Copiar (duplicar o usar como base) | `ADMDataService POST /formulario/copia` → función nueva | **NUEVO** |
| Listas de opciones de la empresa y globales, con sus valores | `ADMDataService GET /empresa/{empr_id}/listas`, `GET /lista/{nombre}/empresa/{empr_id}` | **NUEVO** |
| Puntos de uso y la configuración de la empresa | `ADMDataService GET /formularios/puntos-uso`, `GET /empresa/{empr_id}/formularios/uso`, `PUT /empresa/formulario/uso` | **NUEVO** |
| Usos por proceso, tarea estándar y etapa (solo lectura) | `ADMDataService GET /empresa/{empr_id}/formularios/usos-abm` | **NUEVO** (lectura de `pro.*`, `tst.*`, `prd.*`) |
| Editar puntos de uso (Consola) | `ADMDataService PUT /consola/formularios/punto-uso` | **NUEVO** |
| Dibujo de la vista previa | Función `form($data)` de `traz-comp-formularios/helpers/form_helper.php` | Ya existe (no se modifica) |

**Nada va directo a la base.** `FRMDataService` y el modelo `Forms` no se modifican ni se usan para
escribir. La empresa sale de la sesión en el Portal; en la Consola, los recursos de globales trabajan solo
con `empr_id` nulo.

---

## Pantallas

### Menús laterales

- Portal: "📝 Formularios". `data-testid`: `adm-portal-menu-formularios`.
- Consola: "📝 Formularios globales". `data-testid`: `adm-consola-menu-formularios`.

### Portal → Formularios — `traz-comp-adm/portal/formularios`

Maqueta `doc/v3/dnato/mockups/empresa-formularios.html`.

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Título | "Formularios" y "Los formularios dinámicos que usan las pantallas de Tools (entregas, pañol, checklists…). Los tuyos los editás acá; los globales los mantiene Trazalog y podés usarlos tal cual o copiarlos." | `adm-formularios` |
| Nuevo | "＋ Nuevo formulario" | `adm-formularios-nuevo` |
| Pestañas | "Formularios", "Dónde se usan" | `adm-formularios-tab-lista`, `adm-formularios-tab-uso` |
| Mis formularios | Tabla Formulario, Estado, Campos, Dónde se usa, Respuestas; "Editar", "Vista previa", "Duplicar", "Publicar" / "Inactivar" / "Activar" | `adm-formularios-propios`; fila `adm-formulario-<form_id>`; `adm-formulario-editar`, `adm-formulario-vista-previa`, `adm-formulario-duplicar`, `adm-formulario-publicar`, `adm-formulario-inactivar`, `adm-formulario-activar` |
| Globales disponibles | "los mantiene Trazalog · se usan tal cual o como base de una copia propia"; Formulario, Campos, Lo usás en; "Vista previa", "⧉ Usar como base" | `adm-formularios-globales`; `adm-formulario-usar-base` |
| Inactivar | Ventana con el aviso de uso; "Cancelar" / "Inactivar" | `adm-formulario-inactivar-modal`; `adm-inactivar-confirmar` |
| Copia | Ventana "Nombre de la copia", "Cancelar" / "Crear copia" **[SUPUESTO]** | `adm-formulario-copia-modal`; `adm-copia-confirmar` |
| Dónde se usan | "Qué formulario muestra cada pantalla de Tools en tu empresa."; Pantalla, Módulo, selector; "Guardar"; "Elegidos en su propio ABM (solo lectura)" con Dónde, Formulario y enlace | `adm-formularios-uso`; fila `adm-uso-<clave>`; `adm-formularios-uso-guardar`; `adm-formularios-usos-abm` |

### Constructor — `traz-comp-adm/portal/formulario/<form_id>` (y `traz-comp-adm/consola/formulario/<form_id>`)

Maqueta `doc/v3/dnato/mockups/empresa-formulario-editor.html`.

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Encabezado | Nombre, estado, "Vista previa", "Guardar borrador", "Publicar" | `adm-constructor`; `adm-constructor-vista-previa`, `adm-constructor-guardar`, `adm-constructor-publicar` |
| Cabecera | Nombre, Descripción | `adm-constructor-nombre`, `adm-constructor-descripcion` |
| Paleta | "Tipos de campo" agrupados (Texto, Elegir, Adjuntos, Diseño; en la Consola, Avanzados) | `adm-constructor-paleta`; cada tipo `adm-tipo-<tipo>` |
| Campos | "Campos · arrastrá para ordenar", un renglón por ítem con ✎ y ✕, "Soltá acá un tipo de campo" | `adm-constructor-campos`; renglón `adm-campo-<name>` |
| Propiedades | "Campo: <etiqueta>": Tipo, Etiqueta, Nombre interno ("Se genera de la etiqueta. Con respuestas cargadas no se puede cambiar."), Obligatorio, Ancho, Valor por defecto | `adm-campo-props`; `adm-campo-etiqueta`, `adm-campo-nombre`, `adm-campo-obligatorio`, `adm-campo-ancho`, `adm-campo-defecto` |
| Lista de opciones | "Elegir una lista existente…", "＋ Crear lista nueva", "Nombre de la lista", "Valores (uno por línea)", "Permite varias" | `adm-campo-lista`, `adm-campo-lista-nueva`, `adm-campo-lista-nombre`, `adm-campo-lista-valores`, `adm-campo-multiple` |
| Aviso de copia | "Esta copia no sigue los cambios del formulario global" | `adm-constructor-aviso-copia` |
| Aviso con respuestas | "Este formulario ya tiene respuestas" | `adm-constructor-aviso-respuestas` |
| Vista previa | "Vista previa · así se ve en Tools · con las listas de tu empresa (o globales) · no crea ninguna respuesta" | `adm-vista-previa` |

Mensajes:

| Caso | Mensaje | `data-testid` |
|---|---|---|
| Publicar sin campos | "Agregá al menos un campo" (CP-121) | `adm-constructor-error` |
| Nombre interno repetido | "Ya hay un campo con ese nombre" (CP-123) | `adm-constructor-error` |
| Nombre de formulario repetido | "Ya hay un formulario con ese nombre" **[SUPUESTO]** | `adm-constructor-error` |
| Guardado | "Guardamos el formulario." **[SUPUESTO]** | `adm-constructor-ok` |
| Falla | "No pudimos guardar el formulario. Probá de nuevo en un rato." **[SUPUESTO]** | `adm-constructor-error` |

### Consola → Formularios globales — `traz-comp-adm/consola/formularios`

Maqueta `doc/v3/dnato/mockups/consola-formularios.html`.

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Título | "Formularios globales" y "Formularios sin empresa: todas las empresas los ven y pueden usarlos tal cual o copiarlos." | `adm-consola-formularios` |
| Nuevo | "＋ Nuevo global" | `adm-consola-formularios-nuevo` |
| Globales | Formulario, Estado, Campos, Empresas que lo usan, Copias, Al alta de empresa; "Editar", "Vista previa", "Publicar" / "Inactivar" | `adm-globales-tabla`; fila `adm-global-<form_id>` |
| Inactivar | Ventana con la cantidad de empresas; "Cancelar" / "Inactivar" | `adm-global-inactivar-modal`; `adm-global-inactivar-confirmar` |
| Puntos de uso | Clave, Pantalla, Módulo, Global al alta; "＋ Punto de uso" | `adm-puntos-uso`; fila `adm-punto-<clave>`; `adm-puntos-uso-nuevo` |

---

## Reglas

1. El administrador ve y edita solo los formularios de la empresa de la sesión; los globales, solo para ver
   y copiar. Un formulario propio nunca aparece en otra empresa (RF-130).
2. Solo el superusuario crea y edita globales, y solo él usa los tipos avanzados (también en el servidor).
3. Nombre del formulario único en su ámbito; nombre interno único dentro del formulario.
4. No se publica un formulario sin al menos un campo con nombre.
5. Con respuestas cargadas, el nombre interno y el tipo de un ítem no cambian (se controla en el servidor).
6. Inactivar es baja lógica: no se borra nada y las respuestas viejas se siguen viendo; si estaba en uso,
   avisa y deja esos puntos en "Ninguno".
7. Solo los formularios publicados se pueden elegir en "Dónde se usan".
8. La vista previa no crea ninguna respuesta.
9. Usar como base copia cabecera, ítems y listas; la copia no sigue al global.
10. Cada cambio queda en la auditoría con quién (de la sesión).

## Registro en el log

`log_message('DEBUG', '#TRAZA | ADM | <Clase> | <metodo>() ...')`: cada guardado, cambio de estado, copia y
cambio de "Dónde se usan" (formulario, empresa, quién), y cada rechazo.

---

## Datos

**Cambio de base aditivo: lo decide el equipo (regla de Rodolfo del 2026-11-10).** Las dos columnas nuevas
de `frm.formularios` son optativas (una con valor por defecto, la otra acepta vacío) y se quedan en su
tabla; la tabla nueva va en `seg`, como todas las del módulo (regla de Rodolfo del 2026-11-10). Nombres
**[SUPUESTO]**. Antes de escribir el script hace falta el DDL real de `frm.*` de una base real (duda de
ADM-UC-251).

| Tabla | Cambio | Por defecto |
|---|---|---|
| `frm.formularios` | Columna nueva `estado` (`borrador` / `publicado` / `inactivo`) | `publicado` (nada cambia para v2) |
| `frm.formularios` | Columna nueva `copiado_de` (`form_id` de origen) | nulo |
| `seg.formularios_puntos_uso` (nueva) | `clave`, `pantalla`, `modulo`, `form_id_alta` (global al alta, nulo), `orden` | Carga inicial: `formulario_entrega_materiales`, `formulario_salida_herramientas`, `formulario_recepcion_herramientas`, `formulario_checklist_herramientas` (maqueta), sin global al alta |

Funciones nuevas (en `seg`, como las tablas nuevas; además no se mezcla con el esquema `frm` sin DDL): guardar formulario
(cabecera + ítems + listas + auditoría), cambiar estado (con la limpieza de la configuración), copiar,
guardar uso. Ninguna fila existente cambia en una columna existente; vuelta atrás: borrar las columnas, la
tabla y las funciones.

---

## Análisis de impacto — lo aprueba Rodolfo antes de construir

| Qué | Detalle |
|---|---|
| Qué se escribe | `frm.formularios` y `frm.items` (formularios nuevos o editados), `core.tablas` (listas nuevas y la fila `configuraciones/formulario_<punto>` de la empresa) |
| Quién lo lee | Almacenes (entrega de materiales), pañol (salida, recepción, checklist), BPM/procesos, tareas estándar, etapas, residuos, módulos de cliente (relevamiento §3.1). Todos dibujan **por número** con el módulo `traz-comp-formularios`, que no cambia |
| Qué se rompe si se hace mal | Renombrar el nombre interno de un ítem rompe a quien busca respuestas por nombre (`PANDataservice.dbs:220`, `ALMDataService.dbs:555`, entrega de materiales, relevamiento §5.1) → regla 5. Cambiar el nombre de "Entrega Materiales" de la 9000 rompería el clonado del disparador → la 9000 **no** aparece en el Portal ni en la Consola hasta M-7b **[SUPUESTO]** |
| Lo que cambia en Tools sin tocar código | Elegir un formulario en "Dónde se usan" o inactivarlo cambia lo que dibuja la pantalla de Tools en la próxima carga (es lo buscado, CP-126) |
| Formularios sin empresa que existen hoy | La verificación §8.5 del relevamiento (qué formularios sin `empr_id` hay en producción y si son de un cliente) **no se corrió**: hasta correrla, un formulario de un cliente sin empresa aparecería como "global" para todos (duda de ADM-UC-250) |
| Pruebas | ADM-UC-250 a 255 en la copia de DEMO; ALM y PAN de DocTest (`regresion`) en verde, porque usan esos formularios |

---

## Decisiones tomadas

- **El módulo solo hace las pantallas** (decisión de Rodolfo): todo lo que cambia el dibujo, el guardado o
  la validación de respuestas va en un requerimiento aparte sobre `traz-comp-formularios` (F-1 a F-5).
- **La vista previa usa `form($data)`**, que ya existe: mismo dibujo que Tools, sin crear respuestas y sin
  tocar el módulo compartido.
- **Inactivar limpia la configuración de los puntos de uso**: es la única forma, sin tocar el módulo
  compartido, de que la pantalla de Tools deje de mostrar un formulario inactivo.
- **Estado nuevo con valor por defecto `publicado`**: los formularios de hoy siguen exactamente igual.
- **No se toca la 9000 ni el disparador** hasta el requerimiento aparte: moverla rompería el alta de
  empresa de v2.

## Cómo se revisa (además de DocTest)

- DDL real de `frm.*` obtenido de una base real; script de base (aditivo) corrido en una copia de DEMO,
  con su vuelta atrás.
- Verificación §8.5 del relevamiento corrida en producción y revisada por Rodolfo antes de desplegar.
- Después de abrir varias vistas previas, `frm.instancias_formularios` tiene la misma cantidad de filas.
- `git diff` sin cambios en `application/modules/traz-comp-formularios` ni en `FRMDataService.dbs`.
- DocTest `regresion` en verde (ALM, PAN).
- `phpcs` con PHPCompatibility para PHP 5.6 sin errores; `./mvnw clean install` del proyecto de APIs.
- **Aviso para el despliegue:** el script de despliegue sube los DataServices pero no las APIs; este
  requerimiento no agrega APIs.

## Dudas abiertas

Están en los casos de uso (campo `dudas`), para contestarlas en un solo lugar.

---

## Casos de prueba de la especificación que cubre

| CP | Qué prueba | Lo cubre |
|---|---|---|
| CP-120 | Listado: propios y globales, estado, uso, respuestas; globales sin "Editar" | ADM-UC-250 |
| CP-121 | Construir con todos los tipos y publicar; sin campos no se publica | ADM-UC-251 |
| CP-122 | Lista nueva en línea y lista existente | ADM-UC-251 (constructor). "obras (global)" al dibujar **en Tools**: fuera, necesita F-1 |
| CP-123 | Nombre interno sugerido, repetido rechazado, congelado con respuestas | ADM-UC-251 |
| CP-124 | Vista previa sin respuesta y opciones empresa → global | ADM-UC-252 (en la vista previa). En las pantallas de Tools: fuera, necesita F-1 |
| CP-125 | Usar como base copia todo y no sigue al global | ADM-UC-253 |
| CP-126 | Dónde se usa: propio, global o ninguno; Tools lo refleja | ADM-UC-254 |
| CP-127 | El alta escribe la configuración apuntando a los globales | **Fuera de alcance**: necesita cambiar el disparador de alta (núcleo). Acá solo se guarda la marca "Global al alta" (ADM-UC-255) |
| CP-128 | Inactivar en uso avisa; baja lógica; respuestas intactas; baja de ítem | ADM-UC-250 y ADM-UC-251. Pantallas con número fijo: fuera, necesita F-4 |
| CP-129 | Guardar respuesta con sesión, protección, obligatorios en servidor, `info_id` ajeno rechazado | **Fuera de alcance**: necesita F-2 (cambio en `traz-comp-formularios`) |
| CP-130 | Un propio nunca en otra empresa; un global sí; combo de tareas con "(global)" | ADM-UC-250 (pantallas del módulo). El combo de tareas estándar: fuera, necesita D2/D3 en `FRMDataService` |
| CP-131 | Consola: globales, puntos de uso, inactivar global usado avisa cuántas empresas; tipos avanzados solo superusuario | ADM-UC-255 |
| CP-132 | Migración de la 9000 a globales | **Fuera de alcance**: va con el cambio del disparador (ver duda de ADM-UC-255) |
