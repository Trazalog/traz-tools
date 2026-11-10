# REQ-015 · Módulo Administración — Formularios de la empresa

## Objetivo

Decimoquinto trabajo de Pablo para el módulo **Administración** (`traz-comp-adm`): las **pantallas** para
administrar los formularios dinámicos que usan las pantallas de Tools: **Formularios** del Portal (los
propios y los globales disponibles, el constructor, la vista previa, "Usar como base" y "Dónde se usan", este
último **solo de lectura**) y
**Formularios globales** de la Consola (con el catálogo de puntos de uso). Lo leen Pablo para planificar y
Rodolfo para aprobar el análisis de impacto. **En este plan de trabajo está prohibido tocar cómo se
muestran, se dibujan o se completan los formularios en Tools** (decisión de Rodolfo del 2026-11-10): acá
solo se hace el ABM para administrarlos y modificarlos dentro del módulo, y `traz-comp-formularios` no se
toca. **"Dónde se usan" solo muestra en qué lugares de Tools se usa cada formulario: no permite cambiarlo**
(decisión de Rodolfo del 2026-11-10: solo vale lo que tiene efecto dentro del módulo). El listado de los combos de Tools (`FRMDataService.getFormularios`), el disparador de alta de empresa
y el pase mínimo de la empresa plantilla 9000 a globales van en
[REQ-017](REQ-017-administracion-formularios-globales.md); la migración completa de formularios no se hace.
Lista completa en [`README.md`](README.md).

| Campo | Valor |
|---|---|
| Estado | **Borrador**: Rodolfo tiene que contestar las dudas de los casos y aprobar el análisis de impacto. Ajustado el 2026-11-10 por las decisiones de Rodolfo (prohibición de tocar el dibujo de formularios en Tools; parte del alcance pasa a REQ-017; "Dónde se usan" solo de lectura) |
| Se apoya en | [REQ-002](REQ-002-administracion-esqueleto.md) (controlador base, Portal, Consola), [REQ-004](REQ-004-administracion-base-y-atributos.md) (auditoría; REQ-004 dejó los atributos de `frm.*` para acá), [REQ-008](REQ-008-administracion-consola-empresas.md) (pestaña "Formularios" de la ficha de la empresa); relevamiento [`doc/v3/dnato/FORMULARIOS_DINAMICOS_RELEVAMIENTO.md`](../doc/v3/dnato/FORMULARIOS_DINAMICOS_RELEVAMIENTO.md) y sus decisiones D1 a D3 |
| Entrega de la especificación | **E11b** de `doc/v3/dnato/PROMPT_CLI_DNATO_V3_BUILD.md`, solo la parte de pantallas: constructor (Portal y Consola), listas de opciones, vista previa sin respuesta, usar como base, puntos de uso. CU-70 a 76; CP-120 a 132 (CP-127, la parte de combos de CP-130 y la parte mínima de CP-132 van en REQ-017); RF-120 a 130; R9 solo en la vista previa |
| Casos de uso | `ADM-UC-250` a `ADM-UC-255` en `doctest/catalogo/adm/` |
| Repos que se tocan | `traz-comp-adm` (pantallas, constructor, vista previa); `traz-tools`: estructura de `frm.*` versionada (primera tarea), recursos **nuevos** en `ADMDataService.dbs` y un script de base. **No** se toca `traz-comp-formularios`, ni `FRMDataService.dbs`, ni el disparador de alta (eso es REQ-017) |
| Riesgo | 🔴 Las columnas nuevas optativas en `frm.formularios`, la tabla nueva `seg.formularios_puntos_uso` con su carga inicial y las funciones nuevas en `seg` (lista en "Datos") son **cambio de base aditivo: lo decide el equipo (regla de Rodolfo del 2026-11-10)**. Las filas **nuevas** de `core.tablas` (solo listas de opciones nuevas) **las decide el equipo (regla de Rodolfo del 2026-11-10)**. **Nunca** se escribe la configuración `configuraciones/formulario_<punto>` (ni filas nuevas ni existentes): "Dónde se usan" solo la lee. La estructura real de `frm.*` **no está en el repositorio**: sacarla es la primera tarea (F-5, sin cambiar nada en la base). Sigue en rojo por el **núcleo de Tools**: se **cambian filas existentes** (formularios e ítems de `frm.*` que ya existen), que leen las pantallas de almacenes, pañol, tareas estándar y etapas → **análisis de impacto aprobado por Rodolfo** (sección "Análisis de impacto"). Recursos del DataService nuevos (🟡) |

---

## Para qué sirve

- Hoy **no hay ninguna pantalla** para crear o editar formularios: todo se hace con SQL a mano, con
  scripts que se contradicen (relevamiento §6 y §4; el formulario de registro aparece como 24, 1 y 72).
- No hay dónde ver qué formulario usa cada pantalla de Tools: hay que buscar el número en el ABM "Lista de
  valores" (CU-74, "Hoy"). Se sigue cambiando ahí: este requerimiento solo lo muestra.
- Los formularios globales no tienen dónde verse ni mantenerse; el alta de empresa clona uno solo desde la
  empresa plantilla 9000 (relevamiento §4.2).

## Quién lo usa

- **Administrador** de una empresa: Portal → Formularios (los propios de su empresa).
- **Superusuario**: Consola → Formularios globales y puntos de uso; único que usa los tipos avanzados.
- **Usuario** (no administrador): se usa para probar el rechazo.

## Qué tiene que hacer

0. **Primera tarea de Pablo (F-5), antes de escribir el script de columnas nuevas:** sacar de la base de
   DEMO la estructura de las tablas `frm.*` con un comando de **solo lectura** (`pg_dump --schema-only`
   limitado a esas tablas, que tiene que traer la columna `frm.items.multiple`, hoy en ningún script) y
   versionarla en el repositorio de Tools. No cambia nada en la base. Hoy esa estructura solo está en el
   volcado binario viejo `_backend/database/traz_tools_v1.5.8.5.dmp` (relevamiento §1). Sin caso propio:
   se revisa en "Cómo se revisa".
1. Listado de formularios propios y globales disponibles, con estado, campos, dónde se usa y respuestas;
   activar e inactivar con aviso de los lugares donde se usa (sin cambiar esos lugares); los inactivos se ven marcados "Inactivo" en el ABM del
   módulo (CU-70, RF-120, RF-128, RF-130) → **ADM-UC-250**.
2. Constructor: cabecera, ítems arrastrables, nombre interno, listas de opciones existentes o nuevas,
   guardar como borrador o publicar; con respuestas, nombre interno y tipo bloqueados (CU-71, RF-122,
   RF-123, RF-128) → **ADM-UC-251**.
3. Vista previa con el mismo dibujo de Tools, sin crear ninguna respuesta (CU-73, RF-124) →
   **ADM-UC-252**.
4. Duplicar y "Usar como base" un global (CU-72, RF-125) → **ADM-UC-253**.
5. "Dónde se usan", **solo de lectura**: ver, por pantalla de Tools, qué formulario usa la empresa (propio,
   global o ninguno), sin poder cambiarlo (CU-74, RF-126 en la parte de mostrar) → **ADM-UC-254**.
6. Consola → Formularios globales y puntos de uso, con los tipos avanzados (CU-75, RF-121) →
   **ADM-UC-255**.

## Qué NO hace

### Prohibido en este plan de trabajo (decisión de Rodolfo del 2026-11-10)

**En este plan de trabajo está prohibido tocar cómo se muestran, se dibujan o se completan los formularios
en Tools.** No es un "requerimiento aparte" pendiente: no se hace. Por eso **no se toca nada dentro de
`traz-comp-formularios`** y quedan **sin hacer** estos cambios que la especificación pedía:

| # | Lo que NO se hace | Cómo queda (igual que hoy) | CP que no se cubre |
|---|---|---|---|
| F-1 | Opciones empresa → global (R9) al dibujar en Tools | **No se toca.** Si la empresa no tiene su lista de opciones, el campo se muestra como hoy: vacío (`Forms::obtenerValores` busca solo `empresa()."-".$id`, `traz-comp-formularios/models/Forms.php:228-231`). R9 se aplica **solo en la vista previa del módulo** | CP-122 y CP-124 en las pantallas de Tools, CU-76 |
| F-2 | Sesión obligatoria, protección de envíos y validación en servidor en `Form/*`; `info_id` verificado contra la empresa; `obtenerTodos` filtrado (correctivo C-9) | `Form.php` y `Forms.php` siguen como están | CP-129 completo |
| F-3 | Número de respuesta (`info_id`) por secuencia en vez de `select_max` (correctivo C-10) | `Forms.php:98` sigue como está | Ninguno directo |
| F-4 | No dibujar en Tools los formularios inactivos (cabecera `inactivo` o dada de baja) | `obtenerPlantilla` y `obtenerXEmpresa` siguen sin mirar la cabecera (`Forms.php:183-191`, `414-418`). Tampoco se limpia la configuración de los puntos de uso al inactivar: un inactivo que está en uso **se sigue dibujando** en Tools | CP-128 en las pantallas de Tools |
| F-6 | Elegir desde el módulo qué formulario usa cada pantalla de Tools ("Dónde se usan" con selector y "Guardar") | La configuración `configuraciones/formulario_<punto>` se sigue cambiando como hoy, en "Lista de valores" de Tools. El módulo **solo la lee** | CP-126 en la parte de elegir |

**Dentro del ABM del módulo**, en cambio, los formularios inactivos **sí** se ven, marcados "Inactivo"
(Portal y Consola); si alguno sigue en uso, "Dónde se usan" lo muestra con "(inactivo)" **[SUPUESTO]**.

F-5 (versionar la estructura de `frm.*`) **sí** se hace: es la tarea 0 de "Qué tiene que hacer".

### Lo que pasa a REQ-017

[REQ-017](REQ-017-administracion-formularios-globales.md) (Formularios globales en Tools) hace, con su
propio análisis de impacto:

- el cambio de `FRMDataService.getFormularios` (decisiones D2 y D3 y punto T-8: que los combos de tareas
  estándar, subtareas y etapas muestren también los globales, con "(global)", y respeten el estado). Hoy
  sigue filtrando solo `empr_id = :empr_id` (`FRMDataService.dbs:6`);
- el cambio del disparador de alta de empresa (`configuracion_inicial_empresa_trg`, que hoy clona
  "Entrega Materiales" desde la 9000): que apunte la configuración a los globales marcados "Global al
  alta" (CP-127);
- el pase a globales de **solo** los formularios de la 9000 que usa el disparador.

**La migración completa de formularios (M-7b / RF-131) no se hace** (decisión de Rodolfo del 2026-11-10):
ni acá ni en REQ-017.

### Otros cambios que tampoco hace

- **No cambia las pantallas de Tools que leen la configuración** (T-7: `Entrega_Material.php:50`,
  `Order.php:31`, `Herramienta.php:56`) **ni la configuración que leen**: siguen leyendo
  `configuraciones/formulario_<punto>` como hoy, y el módulo nunca la escribe (F-6).
- **No toca la 9000**: hasta REQ-017, sus formularios no aparecen en el Portal ni en la Consola
  **[SUPUESTO]**, para que nadie los renombre y rompa el clonado del disparador.
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
  "global al alta". Carga inicial: las cuatro claves de la maqueta `consola-formularios.html`. **Sigue
  haciendo falta** aunque "Dónde se usan" sea de lectura: (a) es la lista de los lugares a mostrar, con el
  nombre de la pantalla y el módulo (`core.tablas` solo tiene la clave), y (b) guarda el "Global al alta"
  que lee el disparador de REQ-017. Escribirla no cambia nada en Tools: el "Global al alta" recién tiene
  efecto con REQ-017, que tiene su propio análisis de impacto.
- **Dónde se usa** (mecanismo A del relevamiento) = la fila `configuraciones` / `formulario_<punto>` de la
  empresa en `core.tablas`, con el número de formulario en `descripcion` (relevamiento, duda 4). **Solo se
  lee.**

### Portal → Formularios (CU-70)

- **Mis formularios**: los de la empresa de la **sesión**, con Formulario (nombre y "copiado de …" o
  "creado el …"), Estado, Campos, Dónde se usa, Respuestas, y "Editar", "Vista previa", "Duplicar",
  "Publicar" / "Inactivar" / "Activar".
- **Globales disponibles**: los globales **publicados** (no los borradores ni los inactivos), con
  Formulario, Campos, "Lo usás en" y "Vista previa", "⧉ Usar como base". **Nunca** "Editar" (CP-120).
- **Inactivar** uno en uso: ventana "Está en uso en <lugares>. Inactivarlo no cambia esas pantallas de
  Tools: lo van a seguir mostrando hasta que se elija otro formulario en "Lista de valores". Las <N>
  respuestas cargadas se siguen viendo." **[SUPUESTO]** (el texto de la maqueta prometía dejar la pantalla
  sin formulario, y eso ya no pasa) con "Cancelar" / "Inactivar". <lugares> sale de "Dónde se usan" (puntos
  de uso, procesos, tareas estándar y etapas). Al confirmar solo cambia el estado a `inactivo`: **no se toca
  la configuración** (F-4 y F-6). Si directamente se impide inactivar uno en uso es duda de ADM-UC-250.
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
con R9 (empresa y, si no hay, global) **solo para la vista previa**; como F-1 no se hace en este plan, una
lista global se marca "(global · en Tools se ve vacía)" **[SUPUESTO]** (ver la duda de ADM-UC-252).

### Usar como base y duplicar (CU-72, RF-125)

- "⧉ Usar como base" (sobre un global) y "Duplicar" (sobre un propio): piden el nombre de la copia y crean,
  en **una** operación, cabecera, ítems y **copias** de sus listas de opciones en la empresa, en
  `borrador`, con "copiado de". Abren el constructor, que avisa "Esta copia no sigue los cambios del
  formulario global" (CP-125).
- Si una lista con el mismo nombre ya existe en la empresa, se usa la de la empresa y no se copia
  **[SUPUESTO]** (duda de ADM-UC-253).

### Dónde se usan, solo de lectura (CU-74, RF-126 en la parte de mostrar)

- **Todo es de lectura** (decisión de Rodolfo del 2026-11-10): cambiar la configuración cambiaría lo que
  dibuja Tools, y eso está prohibido en este plan (F-6). No hay selector, ni "Guardar", ni recurso que
  escriba `configuraciones/formulario_*`. La maqueta muestra selectores: manda la decisión.
- Una fila por punto de uso del catálogo (`seg.formularios_puntos_uso`): Pantalla, Módulo y el formulario
  que tiene hoy la fila `configuraciones/formulario_<punto>` de la empresa, como "<nombre> (propio)" o
  "🌐 <nombre> (global)", con "(inactivo)" si lo está **[SUPUESTO]**. Si la empresa no tiene la fila, o
  está dada de baja, dice "Ninguno" (la pantalla de Tools muestra "No se especificó un formulario").
- Debajo, igual que antes: procesos (`pro.procesos_forms`), tareas estándar y etapas con su formulario y el
  enlace a su ABM ("Ir a Procesos →", "Ir a Tareas estándar →", "Ir a Etapas →").
- Los mismos datos llenan la columna "Dónde se usa" de "Mis formularios", el "Lo usás en" de los globales y
  el aviso de inactivar.

### Consola → Formularios globales (CU-75, RF-121)

- Pestaña **Globales**: Formulario, Estado, Campos, "Empresas que lo usan" (por referencia en su
  configuración), "Copias" (formularios con "copiado de" igual a este), "Al alta de empresa", y "Editar",
  "Vista previa", "Publicar" / "Inactivar". "＋ Nuevo global". El mismo constructor, con los tipos
  avanzados.
- **Inactivar** un global en uso: "Lo usan por referencia <N> empresas en <puntos>. Inactivarlo no cambia
  esas pantallas de Tools: lo van a seguir mostrando. Las copias no se tocan." **[SUPUESTO]** y
  confirmación (CP-131). Al confirmar solo cambia el estado: **no se toca la configuración de ninguna
  empresa** (F-4 y F-6).
- Pestaña **Puntos de uso**: Clave, Pantalla, Módulo, "Global al alta" (selector), "＋ Punto de uso". Leyenda
  "Al dar de alta una empresa se escribe su configuración apuntando a estos globales (por referencia, sin
  copiar)…" **[SUPUESTO]** cambiada mientras no esté construido REQ-017 (que cambia el disparador): "Se
  va a usar cuando el alta de empresa escriba la configuración (todavía clona desde la empresa
  plantilla)."
- Los formularios propios de cada empresa se ven en la pestaña "Formularios" de la ficha de la empresa
  (REQ-008), en solo lectura **[SUPUESTO]**.

### Auditoría (RF-130)

En la misma operación que el cambio: `formulario.crear`, `formulario.editar`, `formulario.publicar`
(CP-121), `formulario.inactivar`, `formulario.activar`, `formulario.duplicar`, `formulario.copiar` (usar
como base), `lista.crear`, `punto_uso.editar`. Salvo
`formulario.publicar`, **[SUPUESTO]**.

---

## De dónde sale cada dato

| Dato | De dónde | Cómo |
|---|---|---|
| Es administrador / superusuario | `ADMDataService GET /usuario/es-admin/…`, `/usuario/es-super/…` | Ya existe (REQ-004) |
| Formularios propios y globales con estado, campos, uso y respuestas | `ADMDataService GET /empresa/{empr_id}/formularios`, `GET /consola/formularios` | **NUEVO** |
| Un formulario con sus ítems (verifica que sea de la empresa o global) | `ADMDataService GET /empresa/{empr_id}/formulario/{form_id}` | **NUEVO** |
| Guardar (cabecera, ítems, listas nuevas, auditoría) | `ADMDataService PUT /formulario` → función nueva | **NUEVO** |
| Cambiar estado (no toca la configuración) | `ADMDataService PUT /formulario/estado` → función nueva | **NUEVO** |
| Copiar (duplicar o usar como base) | `ADMDataService POST /formulario/copia` → función nueva | **NUEVO** |
| Listas de opciones de la empresa y globales, con sus valores | `ADMDataService GET /empresa/{empr_id}/listas`, `GET /lista/{nombre}/empresa/{empr_id}` | **NUEVO** |
| Puntos de uso y la configuración de la empresa (solo lectura) | `ADMDataService GET /formularios/puntos-uso`, `GET /empresa/{empr_id}/formularios/uso` | **NUEVO**. No hay recurso que escriba `configuraciones/formulario_*` |
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
| Dónde se usan (solo lectura) | "Qué formulario muestra cada pantalla de Tools en tu empresa."; Pantalla, Módulo, Formulario (texto, sin selector ni "Guardar"); "Elegidos en su propio ABM (solo lectura)" con Dónde, Formulario y enlace | `adm-formularios-uso`; fila `adm-uso-<clave>`; `adm-formularios-usos-abm` |

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
   avisa dónde, y no cambia la configuración de esos lugares.
7. "Dónde se usan" es solo de lectura: el módulo nunca escribe `configuraciones/formulario_*`.
8. La vista previa no crea ninguna respuesta.
9. Usar como base copia cabecera, ítems y listas; la copia no sigue al global.
10. Cada cambio queda en la auditoría con quién (de la sesión).

## Registro en el log

`log_message('DEBUG', '#TRAZA | ADM | <Clase> | <metodo>() ...')`: cada guardado, cambio de estado y copia
(formulario, empresa, quién), y cada rechazo.

---

## Datos

**Cambio de base aditivo: lo decide el equipo (regla de Rodolfo del 2026-11-10).** Las dos columnas nuevas
de `frm.formularios` son optativas (una con valor por defecto, la otra acepta vacío) y se quedan en su
tabla; la tabla nueva va en `seg`, como todas las del módulo (regla de Rodolfo del 2026-11-10). Nombres
**[SUPUESTO]**. El script se escribe **después** de versionar la estructura real de `frm.*` sacada de DEMO
(tarea 0, F-5). Las filas **nuevas** de `core.tablas` (solo listas de opciones nuevas) las decide el equipo (regla de Rodolfo
del 2026-11-10). La configuración `configuraciones/formulario_*` no se escribe nunca.

| Tabla | Cambio | Por defecto |
|---|---|---|
| `frm.formularios` | Columna nueva `estado` (`borrador` / `publicado` / `inactivo`) | `publicado` (nada cambia para v2) |
| `frm.formularios` | Columna nueva `copiado_de` (`form_id` de origen) | nulo |
| `seg.formularios_puntos_uso` (nueva) | `clave`, `pantalla`, `modulo`, `form_id_alta` (global al alta, nulo), `orden` | Carga inicial: `formulario_entrega_materiales`, `formulario_salida_herramientas`, `formulario_recepcion_herramientas`, `formulario_checklist_herramientas` (maqueta), sin global al alta |

Funciones nuevas (en `seg`, como las tablas nuevas; además no se mezcla con el esquema `frm` sin DDL): guardar formulario
(cabecera + ítems + listas + auditoría), cambiar estado, copiar, guardar punto de uso de la Consola (solo
`seg.formularios_puntos_uso`). Ninguna fila existente cambia en una columna existente; vuelta atrás: borrar las columnas, la
tabla y las funciones.

---

## Análisis de impacto — lo aprueba Rodolfo antes de construir

| Qué | Detalle |
|---|---|
| Qué se escribe | `frm.formularios` y `frm.items` (formularios nuevos o editados), `core.tablas` (solo listas nuevas), `seg.formularios_puntos_uso`. **No** se escribe `configuraciones/formulario_*` |
| Quién lo lee | Almacenes (entrega de materiales), pañol (salida, recepción, checklist), BPM/procesos, tareas estándar, etapas, residuos, módulos de cliente (relevamiento §3.1). Todos dibujan **por número** con el módulo `traz-comp-formularios`, que no cambia |
| Qué se rompe si se hace mal | Renombrar el nombre interno de un ítem rompe a quien busca respuestas por nombre (`PANDataservice.dbs:220`, `ALMDataService.dbs:555`, entrega de materiales, relevamiento §5.1) → regla 5. Cambiar el nombre de "Entrega Materiales" de la 9000 rompería el clonado del disparador → la 9000 **no** aparece en el Portal ni en la Consola hasta REQ-017 **[SUPUESTO]** |
| Lo que cambia en Tools sin tocar código | Solo editar un formulario que ya se usa (sus ítems) cambia lo que dibuja Tools, que es el ABM pedido. "Dónde se usan" no cambia nada (solo lee) e inactivar tampoco: Tools lo sigue dibujando (F-4, F-6). Que los combos de tareas estándar respeten el estado es de REQ-017 |
| Formularios sin empresa que existen hoy | La verificación §8.5 del relevamiento (qué formularios sin `empr_id` hay en producción y si son de un cliente) **no se corrió**: hasta correrla, un formulario de un cliente sin empresa aparecería como "global" para todos en el ABM del módulo (duda de ADM-UC-250). En los combos de Tools recién aparecen con REQ-017 |
| Pruebas | ADM-UC-250 a 255 en la copia de DEMO; ALM y PAN de DocTest (`regresion`) en verde, porque usan esos formularios |

---

## Decisiones tomadas

- **El módulo solo hace el ABM** (decisión de Rodolfo del 2026-11-10): en este plan está prohibido tocar
  cómo se muestran, se dibujan o se completan los formularios en Tools. F-1 a F-4 y F-6 no se hacen; F-5 (versionar
  la estructura de `frm.*`) es la primera tarea, porque no cambia nada en la base.
- **Combos, disparador y pase mínimo de la 9000 van en REQ-017** (decisión de Rodolfo del 2026-11-10):
  tocan un DataService existente, un disparador existente y filas existentes, con su propio análisis de
  impacto. La migración completa (M-7b / RF-131) no se hace.
- **La vista previa usa `form($data)`**, que ya existe: mismo dibujo que Tools, sin crear respuestas y sin
  tocar el módulo compartido.
- **"Dónde se usan" es solo de lectura e inactivar no limpia la configuración** (decisión de Rodolfo del
  2026-11-10): solo vale lo que tiene efecto dentro del módulo, y cambiar `configuraciones/formulario_*`
  cambia lo que muestran las pantallas de Tools. Por eso un inactivo en uso se sigue dibujando, y el aviso
  lo dice.
- **`seg.formularios_puntos_uso` se queda**: es la lista de lugares que muestra "Dónde se usan" y guarda el
  "Global al alta" que usa REQ-017.
- **Estado nuevo con valor por defecto `publicado`**: los formularios de hoy siguen exactamente igual.
- **No se toca la 9000 ni el disparador** en este requerimiento: moverla sin cambiar el disparador
  rompería el alta de empresa de v2; las dos cosas van juntas en REQ-017.

## Cómo se revisa (además de DocTest)

- Estructura real de `frm.*` sacada de DEMO con `pg_dump --schema-only` (solo lectura), versionada en el
  repositorio y con la columna `multiple`, **antes** del script; script de base (aditivo) corrido en una
  copia de DEMO, con su vuelta atrás.
- Verificación §8.5 del relevamiento corrida en producción y revisada por Rodolfo antes de desplegar.
- Después de abrir varias vistas previas, `frm.instancias_formularios` tiene la misma cantidad de filas.
- Después de recorrer ADM-UC-250, 254 y 255 (inactivar en uso incluido), las filas
  `configuraciones/formulario_*` de `core.tablas` están igual que antes (misma consulta antes y después).
- `git diff` sin cambios en `application/modules/traz-comp-formularios`, en `FRMDataService.dbs` ni en el
  disparador `configuracion_inicial_empresa_trg` (los dos últimos son de REQ-017).
- DocTest `regresion` en verde (ALM, PAN).
- `phpcs` con PHPCompatibility para PHP 5.6 sin errores; `./mvnw clean install` del proyecto de APIs.
- **Aviso para el despliegue:** el script de despliegue sube los DataServices pero no las APIs; este
  requerimiento no agrega APIs.

## Dudas abiertas

Están en los casos de uso (campo `dudas`), para contestarlas en un solo lugar.

---

## Casos de prueba de la especificación que cubre

Ajustada el 2026-11-10: "**Prohibido**" = queda fuera por la prohibición del plan de tocar cómo se muestran,
se dibujan o se completan los formularios en Tools, incluido cambiar desde el módulo la configuración que
eligen esas pantallas (no se hace en ningún requerimiento de este plan).

| CP | Qué prueba | Lo cubre |
|---|---|---|
| CP-120 | Listado: propios y globales, estado, uso, respuestas; globales sin "Editar" | ADM-UC-250 |
| CP-121 | Construir con todos los tipos y publicar; sin campos no se publica | ADM-UC-251 |
| CP-122 | Lista nueva en línea y lista existente | **Parcial**: ADM-UC-251 (constructor). "obras (global)" al dibujar **en Tools**: **prohibido** (F-1) |
| CP-123 | Nombre interno sugerido, repetido rechazado, congelado con respuestas | ADM-UC-251 |
| CP-124 | Vista previa sin respuesta y opciones empresa → global | **Parcial**: ADM-UC-252 (en la vista previa del módulo). En las pantallas de Tools: **prohibido** (F-1) |
| CP-125 | Usar como base copia todo y no sigue al global | ADM-UC-253 |
| CP-126 | Dónde se usa: propio, global o ninguno; Tools lo refleja | **Parcial**: ADM-UC-254 muestra, solo para leer, qué formulario usa cada pantalla (propio, global o ninguno). Elegirlo desde el módulo y que Tools lo refleje: **prohibido** (F-6) |
| CP-127 | El alta escribe la configuración apuntando a los globales | **Pasa a REQ-017** (cambio del disparador de alta). Acá solo se guarda la marca "Global al alta" (ADM-UC-255) |
| CP-128 | Inactivar en uso avisa; baja lógica; respuestas intactas; baja de ítem | **Parcial**: ADM-UC-250 (aviso con los lugares, baja lógica, respuestas intactas) y ADM-UC-251 (baja de ítem). Que la pantalla de Tools quede sin formulario o no dibuje el inactivo: **prohibido** (F-4 y F-6) |
| CP-129 | Guardar respuesta con sesión, protección, obligatorios en servidor, `info_id` ajeno rechazado | **Prohibido** completo (F-2) |
| CP-130 | Un propio nunca en otra empresa; un global sí; combo de tareas con "(global)" | **Parcial**: ADM-UC-250 (pantallas del módulo). El combo de tareas estándar con "(global)": **pasa a REQ-017** (D2/D3 en `FRMDataService`) |
| CP-131 | Consola: globales, puntos de uso, inactivar global usado avisa cuántas empresas; tipos avanzados solo superusuario | ADM-UC-255 (el aviso; que esas pantallas queden sin formulario: **prohibido**, F-6) |
| CP-132 | Migración de la 9000 a globales | **Pasa a REQ-017 solo la parte mínima** (los formularios de la 9000 que usa el disparador). El resto (listas a globales, sin empresa asignados a su cliente, informe de pañol: M-7b / RF-131) **no se hace** (decisión de Rodolfo) |
