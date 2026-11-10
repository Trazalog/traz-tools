# REQ-005 · Módulo Administración — Catálogo y planes en la Consola

## Objetivo

Quinto trabajo de Pablo para el módulo **Administración** (`traz-comp-adm`): las dos pantallas de la
Consola con las que el superusuario arma la oferta de Trazalog. **Catálogo y menú global**: la lista de
todo lo que la suite sabe hacer (opciones de menú y herramientas del agente), su estructura, sus textos
y su publicación. **Planes**: qué trae cada plan, cuántos usuarios permite y cuántas consultas de IA.
Lo leen Pablo para planificar y Rodolfo para aprobarlo. **No** cubre lo que cada empresa activa dentro
de su plan ([REQ-006](REQ-006-administracion-funcionalidades.md)), los menús por rol o persona
([REQ-009](REQ-009-administracion-menus.md)), asignar un plan a una empresa (REQ-008) ni la comparativa
de planes del administrador (REQ-010). Lista completa en [`README.md`](README.md).

| Campo | Valor |
|---|---|
| Estado | **Borrador**: Rodolfo tiene que contestar las dudas de los casos, aprobar la ampliación del control de módulos de `seg.menues` y el análisis de impacto sobre el menú de Tools |
| Se apoya en | [REQ-002](REQ-002-administracion-esqueleto.md) (controlador base, Consola) y [REQ-004](REQ-004-administracion-base-y-atributos.md) (tablas `seg.planes` y `seg.planes_funcionalidades`, columnas nuevas de `seg.menues`, auditoría, marca de superusuario, `ADMDataService.dbs`) |
| Entrega de la especificación | **E2** de `doc/v3/dnato/PROMPT_CLI_DNATO_V3_BUILD.md`: Consola → Catálogo (textos, publicación y estructura del menú global) y Planes (matriz con cuota; gratuito / de prueba y vencimiento; aviso y correo al restringir un plan con suscriptores). CU-10, CU-11, CU-17, CU-24; CP-10 a 13, 16, 18, 40, 42, 43 |
| Casos de uso | `ADM-UC-050` a `ADM-UC-053` en `doctest/catalogo/adm/` |
| Repos que se tocan | `traz-comp-adm` (pantallas y modelos); `traz-tools`: recursos **nuevos** en `ADMDataService.dbs` y un script de base chico (ver "Datos") |
| Riesgo | 🔴 Fijar los nombres de columnas de `seg.planes` (tabla nueva) y una función de base nueva, si Pablo la elige, son **cambio de base aditivo: lo decide el equipo (regla de Rodolfo del 2026-11-10)**. Sigue en rojo por: (1) **cambio a un objeto existente**: se amplía el control de módulos válidos de `seg.menues` para aceptar `MCP` → Rodolfo aprueba ese cambio antes de construir; y (2) **núcleo de Tools**: el Catálogo escribe en `seg.menues`, que es la tabla con la que Tools dibuja hoy el menú de todas las pantallas de producción → análisis de impacto aprobado por Rodolfo. Los recursos del DataService son nuevos (🟡); no se modifica ninguno existente |

---

## Para qué sirve

- Hoy el catálogo de opciones de menú (`seg.menues`) lo edita **cualquier administrador de empresa**
  desde DNATO, aunque es global para todas (A-18 del relevamiento), y tres de sus acciones ni siquiera
  piden sesión. Pasa a manos **solo del superusuario**.
- Hoy no existen los planes. Para vender por plan hace falta decir qué trae cada uno, con cuántos
  usuarios y cuántas consultas de IA, y poder cambiarlo sin tocar código.
- Si un cambio de plan le quita algo a empresas que ya lo pagan, el superusuario tiene que saberlo
  **antes** de confirmar, y los administradores de esas empresas tienen que enterarse.

## Quién lo usa

- **Superusuario**: único que entra a estas dos pantallas.
- **Administrador** de una empresa: no entra; se usa para probar el rechazo (CP-43).

## Qué tiene que hacer

1. Administrar planes: crear, editar, duplicar, dar de baja, marcar el plan base, gratuito / de prueba
   con vencimiento (CU-10) → **ADM-UC-050**.
2. Definir el contenido de los planes en la matriz planes × funcionalidades, con tope de usuarios y
   cuota de IA en la fila, y el aviso al restringir un plan con empresas (CU-11, RF-16) → **ADM-UC-051**.
3. Escribir los textos de una funcionalidad del catálogo, publicarla y despublicarla, y ver cuántas
   empresas dijeron "Me interesa" (CU-17) → **ADM-UC-052**.
4. Administrar la estructura del menú global: opciones nuevas, opción padre, orden (CU-24) →
   **ADM-UC-053**.
5. Rechazar al administrador de empresa en las dos pantallas y en sus envíos (CP-43) → flujos
   alternativos de **ADM-UC-050** y **ADM-UC-052** (lo hace el controlador base de REQ-002).

## Qué NO hace

- **No asigna planes a empresas** ni calcula su fecha de vencimiento (RF-23, RF-26: Consola →
  Empresas, REQ-008). Acá solo se define el vencimiento **del plan** ("vence a los 30 días").
- **No hace que el plan cambie lo que ve cada empresa en Tools.** Lo que se ve según el plan lo calcula
  REQ-006 (Funcionalidades) y lo dibuja el menú resuelto (REQ-009 y su derivación en Tools). Mientras
  tanto, el menú de Tools sigue saliendo como hoy.
- **No muestra el aviso en el Inicio del Portal** de las empresas afectadas por una restricción (CU-30,
  REQ-013). Acá se manda el correo y queda la auditoría, de donde REQ-013 sacará el aviso.
- No hace la vista de presentación ni el botón "Me interesa" (REQ-012). El contador se muestra, pero
  hasta REQ-012 siempre da 0.
- No carga planes ni pasa empresas a un plan (M-3, REQ-016). Hasta entonces `core.empresas.plan_id` es
  nulo en todas, y por eso "empresas que usan este plan" da 0.
- No carga las herramientas del agente en el catálogo: si M-2 de REQ-004 no lo hizo, se cargan con su
  propia aprobación (ver la duda de ADM-UC-053).
- No toca DNATO: su ABM de menú (A-18) y su "Menú por rol" (A-19) siguen andando en paralelo. Que dejen
  de estar disponibles es parte de la redirección final.
- No cambia `getMenuByUserPermission`, `menu_helper.php` ni ningún recurso de `COREDataService`.

---

## Cómo se arma

### Pantallas en la Consola

Dos controladores nuevos del módulo, los dos con permiso `superusuario` en el controlador base de
REQ-002 (con la marca de REQ-004). Se agregan al menú lateral de la Consola "📦 Planes" y
"🧩 Catálogo y menú global", en el orden de la maqueta.

### El catálogo es `seg.menues`

- Una **funcionalidad** es una fila de `seg.menues` (clave: módulo + opción). Lo nuevo (tipo, texto de
  presentación, ayuda, publicación) son las columnas que agregó REQ-004.
- **Nombre** de la funcionalidad = la columna `texto` que ya existe (es lo que Tools muestra en el menú).
  **Ícono** = `url_icono`, elegido de `core.iconos` como hoy. Ver la duda de ADM-UC-052.
- **Publicación y `eliminado` van juntos** mientras Tools siga dibujando el menú con
  `getMenuByUserPermission`, que solo mira `eliminado`: `publicada` ⇒ `eliminado = 0`;
  `sin_publicar` o `despublicada` ⇒ `eliminado = 1`. Así una opción nueva, creada "sin publicar", **no
  aparece** en el menú de Tools por la regla "si ningún hijo está habilitado se muestran todos"
  (`menu_helper.php:122-125`). Ver la duda de ADM-UC-053.
- **Qué opciones son funcionalidades** (columnas de la matriz y filas de Funcionalidades): las que tienen
  dirección (`url`) o son de tipo `tool_mcp`. Las opciones raíz sin dirección (por ejemplo
  `MAN / mantenimiento`) son **agrupadores**: se ven en la estructura, no se venden por plan. Ver la
  duda de ADM-UC-051.
- **Orden**: Tools ordena por `orden` como **texto** ("100" queda antes que "20"). Al guardar el orden,
  el módulo renumera los hermanos con números del mismo largo (por ejemplo 110, 120, 130…), para que el
  orden de texto y el de número coincidan. No se toca la consulta de Tools.

### Planes

- Un plan es una fila de `seg.planes`; lo que trae, filas de `seg.planes_funcionalidades`
  (plan × módulo × opción). Sin herencia: cada plan lista todo lo que trae (RF-12).
- **Plan base**: hay uno solo. Marcar otro le saca la marca al anterior **en la misma operación**.
- **Baja**: lógica (`activo = no`), y **solo** si ninguna empresa lo tiene (`core.empresas.plan_id`).
  Un plan dado de baja no se ofrece en ningún lado, pero sigue en la base para el historial.
- **Duplicar**: copia todos los datos y la matriz, con nombre "<nombre> (copia)", sin la marca de plan
  base y con un código nuevo que pide la pantalla **[SUPUESTO]**.
- **Ilimitado**: tope o cuota nulos. Cuota 0 = "sin IA".
- **Gratuito / de prueba**: sí/no. Solo si es sí se habilita "Vencimiento": "Sin vencimiento" (por
  defecto) o "Vence a los…" cantidad + unidad (días, semanas, meses).
- **Precio**: se guarda en la variable de sistema `precio_plan_{codigo}` de REQ-004 (texto libre o
  "Consultar"), con su historial. Ver la duda de ADM-UC-050.

### Cambios que restringen un plan con empresas (RF-16)

Restringe: quitar una funcionalidad, bajar el tope de usuarios, bajar la cuota de IA (incluye pasar de
ilimitado a un número). Si el plan tiene empresas:

1. Antes de guardar, el módulo pide al DataService cuántas y cuáles empresas afecta (y, si baja el
   tope, cuántos lugares usa cada una: personas con membresía en estado distinto de `baja`, R4).
2. Muestra el aviso y espera "Confirmar y avisar". "Cancelar" deja todo como estaba (la casilla vuelve
   a su estado).
3. Al confirmar: guarda, audita y manda un correo a los administradores de cada empresa afectada
   (definición única de administrador de REQ-004), con el mecanismo de correo que copió REQ-003
   (`CI_Email` + `sendmail`), remitente de la variable `remitente_correo`.
4. Si el correo falla, el cambio **queda hecho** y la pantalla lo dice (RNF-08).

Ampliar (agregar funcionalidad, subir tope o cuota) o cambiar algo de un plan sin empresas: se guarda
y se audita, sin aviso ni correo. Rige en el próximo pedido (RNF-06).

### Auditoría

Cada cambio escribe en `seg.auditoria` (REQ-004) **en la misma operación** que el cambio, con quién (de
la sesión), qué y el valor anterior y nuevo. Acciones: `plan.crear`, `plan.editar`, `plan.duplicar`,
`plan.baja`, `plan.base`, `plan.funcionalidad.agregar`, `plan.funcionalidad.quitar`,
`catalogo.opcion.crear`, `catalogo.opcion.editar`, `catalogo.orden`, `catalogo.textos`,
`catalogo.publicar`, `catalogo.despublicar`. Para que cambio y auditoría no queden a medias, cada
recurso que escribe lo hace en una sola transacción (función de base o pedido en lote del DataService,
a elección de Pablo en el plan; si es función de base nueva, es un cambio aditivo y lo decide el
equipo).

---

## De dónde sale cada dato

| Dato | De dónde | Cómo |
|---|---|---|
| Sesión, correo, es superusuario | Sesión y `ADMDataService GET /usuario/es-super/{email}` | Ya existe (REQ-004) |
| Planes (lista, datos, empresas que lo usan) | `ADMDataService GET /planes` | **NUEVO** |
| Crear, editar, duplicar, dar de baja, marcar base | `ADMDataService POST /plan`, `PUT /plan`, `POST /plan/copia`, `PUT /plan/baja`, `PUT /plan/base` | **NUEVO** |
| Matriz planes × funcionalidades | `ADMDataService GET /planes/matriz` | **NUEVO** |
| Marcar / desmarcar una casilla | `ADMDataService POST /plan/funcionalidad`, `PUT /plan/funcionalidad/quitar` | **NUEVO** |
| Empresas afectadas por una restricción (y lugares usados) | `ADMDataService GET /plan/{plan_id}/empresas-afectadas` | **NUEVO** |
| Administradores de una empresa (para el correo) | `ADMDataService GET /empresa/{empr_id}/administradores` | **NUEVO** (misma definición que `/usuario/es-admin`) |
| Precio del plan | `ADMDataService GET /variables`, `PUT /variable` | Ya existe (REQ-004) |
| Catálogo (lista con estado, planes y contador) | `ADMDataService GET /catalogo` | **NUEVO** |
| Textos, ícono, tipo de una opción | `ADMDataService PUT /catalogo/opcion` | **NUEVO** |
| Publicar / despublicar | `ADMDataService PUT /catalogo/opcion/publicacion` | **NUEVO** |
| Opción nueva | `ADMDataService POST /catalogo/opcion` | **NUEVO** |
| Orden y opción padre | `ADMDataService PUT /catalogo/orden` | **NUEVO** |
| Íconos | `ADMDataService GET /iconos` (`core.iconos`) | **NUEVO** (hoy DNATO lo lee directo, `Mmenu.php:31-36`) |
| "Me interesa" por funcionalidad y por empresa | `ADMDataService GET /catalogo/intereses/{modulo}/{opcion}` (`seg.intereses`) | **NUEVO**; vacío hasta REQ-012 |
| Auditoría | Dentro de cada recurso que escribe | Tabla de REQ-004 |

**Nada va directo a la base.** Las direcciones van en kebab-case y las claves JSON en snake_case.

---

## Pantallas

Siguen las maquetas `doc/v3/dnato/mockups/consola-planes.html` y `consola-catalogo.html`, dentro del
marco de la Consola de REQ-002.

### Consola — menú lateral

| Opción | `data-testid` |
|---|---|
| "📦 Planes" | `adm-consola-menu-planes` |
| "🧩 Catálogo y menú global" | `adm-consola-menu-catalogo` |

### Consola → Planes — `traz-comp-adm/consola/planes`

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Título | "Planes" y "Qué trae cada plan, cuántos usuarios permite y cuántas consultas de IA. Cada casilla se guarda sola. Cada empresa elige después, dentro de su plan, qué activa." | `adm-planes` |
| Nuevo | "＋ Nuevo plan" | `adm-planes-nuevo` |
| Matriz | Una fila por plan activo, por orden. Columnas: Plan (ícono, nombre, orden), "Gratuito / de prueba" ("Sí · sin vencimiento", "Sí · 30 días" o "No"), "Tope usuarios", "Cuota IA · período · renovación", una columna por funcionalidad agrupada por módulo (incluido MCP), y acciones | `adm-planes-matriz`; fila `adm-plan-<codigo>` |
| Casilla | Marca si el plan trae la funcionalidad; se guarda sola | `adm-plan-casilla-<codigo>-<modulo>-<opcion>` |
| Tope y cuota en la fila | Número o "∞"; período (semana / mes) y día de renovación | `adm-plan-tope-<codigo>`, `adm-plan-cuota-<codigo>` |
| Acciones de la fila | "✎" editar, "⧉" duplicar, "🗑" dar de baja | `adm-plan-editar`, `adm-plan-duplicar`, `adm-plan-baja` |
| Funcionalidad sin publicar | Columna atenuada con "⏳", sin casillas, y la nota "funcionalidad sin publicar, se ve atenuada hasta que la publiques en el Catálogo" | `adm-plan-columna-sin-publicar` |
| Formulario | "Nuevo plan / editar plan": Código, Nombre, Ícono, Orden, Tope de usuarios (+ "Ilimitado"), Cuota de IA con período y día (+ "Ilimitado"), Precio ("Texto libre o 'Consultar'"), Plan base ("hoy es <plan>"), "Gratuito / de prueba", Vencimiento ("Sin vencimiento" / "Vence a los…" + cantidad + días/semanas/meses). Botones "Guardar" y "Cancelar" | `adm-plan-form`; `adm-plan-guardar`, `adm-plan-cancelar` |
| Aviso de restricción | Ventana con "Este cambio restringe el plan <plan>: afecta a N empresa(s) (<nombres>)", el detalle y "Cancelar" / "Confirmar y avisar" | `adm-plan-restriccion`; `adm-plan-restriccion-confirmar`, `adm-plan-restriccion-cancelar` |
| Guardado | Aviso breve "Guardado ✓" | `adm-guardado` |

Mensajes:

| Caso | Mensaje | `data-testid` |
|---|---|---|
| Baja de un plan en uso | "Este plan lo usan N empresas: cambialas de plan antes de darlo de baja" (con 1: "Este plan lo usa 1 empresa: cambiala de plan antes de darlo de baja") | `adm-plan-en-uso` |
| Otro plan pasa a ser base | "<anterior> dejó de ser el plan base" | `adm-plan-base-transferida` |
| Restricción que quita una funcionalidad | "\"<funcionalidad>\" dejará de verse en esa(s) empresa(s) (sus datos se conservan). Al confirmar se avisa por correo a sus administradores. ¿Continuar?" | `adm-plan-restriccion` |
| Restricción que baja el tope | "N empresa(s) tiene(n) más de <tope> lugares usados (<empresa>: <lugares>). Se aplicará y no podrán invitar hasta bajar del tope" | `adm-plan-restriccion` |
| Correo que no salió **[SUPUESTO]** | "Guardamos el cambio, pero no pudimos mandar el correo a <empresa>. Avisale por otro medio." | `adm-plan-correo-fallo` |
| Código repetido **[SUPUESTO]** | "Ya hay un plan con ese código." | `adm-plan-error` |
| Tope o cuota inválidos **[SUPUESTO]** | "El tope tiene que ser mayor que 0, o ilimitado." / "La cuota tiene que ser 0 o más, o ilimitada." | `adm-plan-error` |
| Falla del servicio | "No pudimos guardar. Probá de nuevo en un rato." | `adm-plan-error` |

Correo a los administradores (RF-16): asunto "Trazalog cambió tu plan <plan>" (CP-16); cuerpo
**[SUPUESTO]**: qué cambió ("<funcionalidad> ya no está en tu plan" o "el tope de usuarios pasó a N"),
que los datos se conservan y que pueden pedir un cambio desde Mi empresa → Plan.

### Consola → Catálogo y menú global — `traz-comp-adm/consola/catalogo`

Dos pestañas: "Catálogo" y "Estructura del menú".

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Título | "Catálogo y menú global" y su explicación (la maqueta nombra `seg.menues`; RNF-09 pide sin tecnicismos: "Las opciones de menú de la suite y las herramientas de IA…") | `adm-catalogo` |
| Pestañas | "Catálogo", "Estructura del menú" | `adm-catalogo-tab-catalogo`, `adm-catalogo-tab-estructura` |
| Buscar y filtros | "🔍 Buscar"; "Todas (N)", "Sin publicar (N)", "Publicadas (N)", "Despublicadas (N)" | `adm-catalogo-buscar`, `adm-catalogo-filtro-<estado>` |
| Tabla | Módulo / opción, Nombre, Tipo, En planes, Me interesa, Estado | `adm-catalogo-tabla`; fila `adm-catalogo-<modulo>-<opcion>` |
| Ficha | Datos fijos (módulo, opción, dirección, padre); Nombre, Ícono, Tipo, Texto de presentación ("Se lee en la vista previa cuando no está en el plan."), Ayuda; "En planes" (lleva a la columna en Planes); "Me interesa (N): <empresa> ×n, …"; botones "Guardar" y "Publicar" / "Despublicar" | `adm-catalogo-ficha`; `adm-catalogo-guardar`, `adm-catalogo-publicar`, `adm-catalogo-despublicar`, `adm-catalogo-intereses` |
| Estructura | Árbol por módulo (opción raíz → opciones) con "⋮⋮" para arrastrar dentro del módulo, estado y "✎"; leyenda "arrastrá dentro de cada módulo · la clave es módulo + opción, no se mueve entre módulos"; "Guardar orden". El módulo MCP figura con "Herramientas de IA · no entran al menú" | `adm-estructura`; `adm-estructura-guardar-orden`; nodo `adm-estructura-<modulo>-<opcion>` |
| Nueva opción | "＋ Nueva opción": Módulo, Opción (clave), Texto, URL, Opción padre, Ícono ("de core.iconos"), Tipo (pantalla / acción / tool_mcp); botón "Crear (queda sin publicar)" | `adm-catalogo-nueva`; `adm-opcion-form`; `adm-opcion-crear` |

Mensajes **[SUPUESTO]** (la maqueta no los trae; tuteo, RNF-09):

| Caso | Mensaje | `data-testid` |
|---|---|---|
| Guardado | "Guardado ✓" | `adm-guardado` |
| Faltan datos para publicar | "Para publicar completá nombre, ícono, tipo, texto de presentación y ayuda." | `adm-catalogo-error` |
| Publicada | "Publicada. Ya podés sumarla a los planes." | `adm-catalogo-ok` |
| Despublicada | "Despublicada: no se ve en ninguna empresa. Podés volver a publicarla." | `adm-catalogo-ok` |
| Clave repetida | "Ya existe la opción <opción> en el módulo <módulo>." | `adm-opcion-error` |
| Mover a otro módulo | "Una opción no se puede mover a otro módulo." | `adm-estructura-error` |
| Orden guardado | "Guardamos el orden." | `adm-estructura-ok` |
| Falla del servicio | "No pudimos guardar. Probá de nuevo en un rato." | `adm-catalogo-error` |

---

## Reglas

1. Solo el superusuario ve y usa Planes y Catálogo; cualquier otro recibe "sin permiso" (403), también
   en los envíos directos.
2. El código de plan es único y no cambia después de creado (ver la duda de ADM-UC-050).
3. Tope de usuarios mayor que 0 o ilimitado; cuota de IA 0 o más, o ilimitada.
4. Hay exactamente un plan base. Marcar otro transfiere la marca y la pantalla lo avisa.
5. No se da de baja un plan que tenga empresas. La baja es lógica.
6. El vencimiento solo existe en planes gratuitos / de prueba; por defecto "sin vencimiento".
7. Cada casilla de la matriz y cada cambio de tope o cuota se guarda solo y queda auditado.
8. Un cambio que **restringe** un plan con empresas avisa cuántas y cuáles afecta, pide confirmación y
   manda correo a sus administradores. Un cambio que **amplía** solo se audita.
9. Solo las funcionalidades publicadas se pueden marcar en la matriz.
10. Publicar exige nombre, ícono, tipo, texto de presentación y ayuda. Una funcionalidad sin publicar o
    despublicada no se ve en ninguna empresa (ni en el menú de Tools: `eliminado = 1`).
11. Despublicar no borra: se puede volver a publicar y conserva textos y planes.
12. La clave es módulo + opción: no se repite y una opción no se mueve a otro módulo.
13. La opción padre tiene que ser del mismo módulo.
14. Quién hizo cada cambio sale de la sesión.

## Registro en el log

`log_message('DEBUG', '#TRAZA | ADM | <Clase> | <metodo>() ...')`. Se registran los rechazos, cada cambio
de plan y de catálogo (qué y quién) y cada correo de restricción (empresa y resultado del envío, sin el
contenido).

---

## Datos

**Lo aditivo lo decide el equipo (regla de Rodolfo del 2026-11-10); el cambio al control existente de
`seg.menues` lo aprueba Rodolfo antes de construir.** Las tablas ya las crea REQ-004 (en `seg`); acá
solo se ajusta. No hay columnas nuevas en tablas existentes. Si el script de REQ-004 todavía no se corrió, estos ajustes van **dentro** de ese script; si ya
se corrió, van en uno chico con su vuelta atrás.

### Nombres de columnas de `seg.planes` (REQ-004 dio los atributos, no los nombres)

Propuesta **[SUPUESTO]**, Pablo puede ajustarlos en el plan:

| Columna | Qué guarda |
|---|---|
| `plan_id` | Número del plan |
| `codigo` | Código único (por ejemplo `free`, `team`); arma la clave de la variable `precio_plan_{codigo}` |
| `nombre`, `icono`, `orden` | Nombre, ícono (texto corto, por ejemplo un emoji) y orden |
| `tope_usuarios` | Número; nulo = ilimitado |
| `cuota_ia` | Número; 0 = sin IA; nulo = ilimitado |
| `periodo`, `dia_renovacion` | `semana` / `mes`; día (lunes… o 1 a 28 **[SUPUESTO]**) |
| `es_base` | Plan base (uno solo: índice único parcial) |
| `gratuito` | Gratuito / de prueba |
| `vence_cantidad`, `vence_unidad` | Vencimiento; nulos = sin vencimiento; unidad `dias` / `semanas` / `meses` |
| `activo` | Baja lógica |

`seg.planes_funcionalidades`: `plan_id`, `modulo`, `opcion` (única por las tres), con referencia a
`seg.menues`. Si se adopta la propuesta de precio en variable, la columna de precio de REQ-004 no se crea.

### Cambio a un objeto existente

| Objeto | Cambio | Por qué |
|---|---|---|
| Control de módulos válidos de `seg.menues.modulo` (hoy PRD, CORE, ALM, MAN, TAR, PAN, LOG, SEG, TRZ, PRO, FIS, BPM; `DNATO_v2_RELEVAMIENTO.md:350,961`) | Agregar `MCP` | Las herramientas del agente son funcionalidades del módulo `MCP` (RF-15). Ya se hizo igual para `BPM` (`arreglo de menu.sql:12-13`). Solo amplía: ninguna fila existente cambia |

Ninguna columna existente cambia de tipo ni de contenido. La sincronía publicación ↔ `eliminado` solo
afecta a filas **que se publican o despublican desde la Consola** (ver la duda de ADM-UC-053 sobre las
que ya tienen `eliminado = 1`).

---

## Decisiones tomadas

- **El catálogo sigue siendo `seg.menues`** (ADR-015 propuesto, RF-40): no se crea otra tabla de
  funcionalidades, así Tools, DNATO y el módulo hablan de lo mismo.
- **Publicación y `eliminado` juntos**: es la única forma de que una opción "sin publicar" no aparezca
  en el menú actual de Tools sin tocar `getMenuByUserPermission` ni `menu_helper` (núcleo).
- **Renumerar el orden con números del mismo largo**: corrige en los datos el orden alfabético de la
  consulta de Tools, sin modificar la consulta.
- **Restricción con confirmación y correo, ampliación solo auditada** (RF-16): los que pierden algo se
  enteran antes; los que ganan, lo ven como "sin activar" en Funcionalidades (REQ-006).
- **Recursos nuevos en `ADMDataService`**, ninguno en `COREDataService`: los existentes los consume v2.
- **El correo no frena el cambio**: si falla, el cambio queda y la pantalla lo dice (RNF-08).

## Cómo se revisa (además de DocTest)

- Script de base corrido en una copia de DEMO, con su vuelta atrás; la ampliación del control de módulos
  de `seg.menues` (cambio a un objeto existente) aprobada por Rodolfo antes de construir.
- **Análisis de impacto aprobado por Rodolfo** sobre el menú de Tools: con un usuario de prueba, el
  menú de Tools antes y después de (a) crear una opción sin publicar bajo un padre ya habilitado,
  (b) reordenar un módulo, (c) despublicar y volver a publicar una opción. En (a) no tiene que aparecer
  nada nuevo; en (b) cambia solo el orden.
- DocTest `regresion` en verde (el menú de Tools de los usuarios DocTest no cambió).
- El menú de "Menú por rol" y "Menues" de DNATO sigue abriendo y mostrando las mismas opciones.
- `phpcs` con PHPCompatibility para PHP 5.6 sin errores; `./mvnw clean install` del proyecto de APIs.
- **Aviso para el despliegue:** el script de despliegue sube los DataServices pero no las APIs; este
  requerimiento no agrega APIs.

## Dudas abiertas

Están en los casos de uso (campo `dudas`), para contestarlas en un solo lugar.

---

## Casos de prueba de la especificación que cubre

| CP | Qué prueba | Lo cubre |
|---|---|---|
| CP-10 | Crear plan con cuota semanal (aparece en su orden; auditoría `plan.crear`) | ADM-UC-050 |
| CP-11 | No se da de baja un plan en uso | ADM-UC-050 (con empresas en el plan cargadas a mano en la base de prueba, porque M-3 es REQ-016) |
| CP-12 | Marcar otro plan como base transfiere la marca | ADM-UC-050 |
| CP-13 | Casilla de la matriz se guarda sola y audita | ADM-UC-051 |
| CP-16 | Restricción avisa, confirma y notifica; ampliación solo audita | ADM-UC-051 (aviso, confirmación, correo, auditoría). El aviso en el Inicio del Portal: fuera de alcance (REQ-013). "MinTest_SJ la ve como sin activar": REQ-006 |
| CP-17 | Columna "Gratuito / de prueba" y vencimiento del plan | En parte: ADM-UC-050 (campo y columna). La fecha de vencimiento al asignar a una empresa: fuera de alcance (REQ-008) |
| CP-18 | Estructura del menú global: alta, orden, padre; no se mueve de módulo | ADM-UC-053 (alta, orden, padre, rechazo). "Aparece en el menú de MinTest_SJ" depende del menú resuelto: REQ-009 y su derivación en Tools |
| CP-40 | Publicar funcionalidad (aparece como columna de la matriz) | ADM-UC-052. "Para Yudica aparece sombreada en el menú": REQ-009 |
| CP-42 | Contador de "Me interesa" desglosado por empresa | ADM-UC-052 (se muestra; se prueba con datos cargados a mano hasta que REQ-012 haga el botón) |
| CP-43 | El administrador de empresa no puede editar el catálogo | ADM-UC-052 y ADM-UC-050 (flujos alternativos; lo resuelve el controlador base de REQ-002) |
