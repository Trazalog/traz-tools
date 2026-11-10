# REQ-009 · Módulo Administración — Menús por rol o por persona

## Objetivo

Noveno trabajo de Pablo para el módulo **Administración** (`traz-comp-adm`): la pantalla del Portal
donde el administrador arma menús con las funcionalidades activas de su empresa y los asigna a roles o
a personas, el servicio "Menú resuelto" (regla R3) que dice qué menú le toca a cada uno, y la carga
inicial de funcionalidades activas de las empresas que ya existen (M-4). Lo leen Pablo para planificar
y Rodolfo para aprobar el script y la propuesta sobre Tools. **No** cubre que el menú lateral de Tools
use el servicio nuevo (es una derivación en el núcleo de Tools, ver "Qué NO hace" y la duda de
ADM-UC-132), ni la vista de presentación (REQ-012). Lista completa en [`README.md`](README.md).

| Campo | Valor |
|---|---|
| Estado | **Borrador**: Rodolfo tiene que contestar las dudas de los casos, aprobar el script de M-4 y decidir la derivación en Tools |
| Se apoya en | [REQ-002](REQ-002-administracion-esqueleto.md) (controlador base, Portal), [REQ-004](REQ-004-administracion-base-y-atributos.md) (tablas `seg.menus_custom`, `seg.menus_custom_items`, `seg.menus_asignaciones`, estado de membresía, auditoría), [REQ-005](REQ-005-administracion-catalogo-y-planes.md) (catálogo y planes) y [REQ-006](REQ-006-administracion-funcionalidades.md) (R1, R2, Funcionalidades) |
| Entrega de la especificación | **E6** de `doc/v3/dnato/PROMPT_CLI_DNATO_V3_BUILD.md`: menús custom, asignación en las dos direcciones, "Ver como…", servicio "Menú resuelto" (R3: jerarquía + estado `visible` / `otro_plan` por ítem), migración M-4. CU-32, CU-33; CP-51, CP-60 a 69 |
| Casos de uso | `ADM-UC-130` a `ADM-UC-134` en `doctest/catalogo/adm/` |
| Repos que se tocan | `traz-comp-adm` (pantalla de Menús, aviso en Funcionalidades, modelo y servicio "Menú resuelto"); `traz-tools`: recursos **nuevos** en `ADMDataService.dbs` y el script de M-4 |
| Riesgo | 🔴 **Cambio de base de datos; Rodolfo aprueba el script antes de construir**: carga de datos M-4 (filas nuevas en `seg.empresas_funcionalidades` para todas las empresas) y nombres de columnas de las tablas de menús. No toca ninguna fila ni columna existente. **Núcleo de Tools: no se toca en este requerimiento**; que Tools dibuje el menú resuelto queda como derivación con su propio análisis de impacto (duda de ADM-UC-132). Recursos del DataService nuevos (🟡) |

---

## Para qué sirve

- Hoy el menú de Tools sale de "Menú por rol" de DNATO (A-19): una lista de casillas por (empresa, rol)
  con tres defectos conocidos (toma la opción del campo equivocado, corta el rol con `explode('-')` y
  la edición pisa todas las opciones del rol). Y no hay forma de darle a **una persona** un menú propio.
- El administrador quiere que el taller vea "Mi trabajo" y "Repuestos", no la lista técnica de módulos,
  y que una persona puntual vea solo lo suyo.
- Que haya **una sola respuesta** a "qué menú ve esta persona" (R3), la misma que usará Tools para
  dibujarlo, con lo de otro plan **en su lugar**, sombreado, para invitar a subir de plan.

## Quién lo usa

- **Administrador** de una empresa: Mi empresa → Menús.
- **Mantenedor** y **Supervisor** (perfiles de operación): son a quienes se les asignan menús; se usan
  para probar la resolución con "Ver como…" y el servicio.

## Qué tiene que hacer

1. Armar un menú: nuevo, duplicar, editar, borrar; grupos y opciones arrastrando desde lo activo
   (CU-32, RF-60, RF-61) → **ADM-UC-130**.
2. Asignar un menú a roles y a personas, y verlo en las dos direcciones (CU-33, RF-62) →
   **ADM-UC-131**.
3. "Ver como…" y el servicio "Menú resuelto" (R3, RF-63 a RF-65) → **ADM-UC-132**.
4. Apagar en Funcionalidades algo que está en menús: aviso, se oculta sin borrarse y reaparece al
   encender (CU-31 A1, RF-51, RF-52) → **ADM-UC-133**.
5. Cargar las funcionalidades activas de las empresas existentes (M-4) sin que el menú de Tools cambie
   → **ADM-UC-134**.

## Qué NO hace

- **No cambia el menú lateral de Tools.** Tools sigue dibujando con `getMenuByUserPermission` y
  `menu_helper.php`. Hacer que Tools pida el menú resuelto (punto T-2 de `02_MODELO_Y_REGLAS.md` §9b)
  toca el núcleo de Tools (lo que se ve en **todas** las pantallas de producción) y queda como
  **derivación** en un requerimiento aparte, con análisis de impacto aprobado por Rodolfo (propuesta en
  la duda de ADM-UC-132). Mientras tanto, los menús que arma el administrador se ven con "Ver como…" y
  en el servicio, **no en Tools**.
- No hace la vista de presentación que abre una opción de otro plan (REQ-012): el servicio devuelve su
  dirección, la página llega con REQ-012.
- No cambia el menú de un miembro desde Usuarios (RF-75) ni el menú opcional al invitar (RF-71): es
  REQ-007, que usa esta misma asignación.
- No modifica `seg.memberships_menues` ("Roles y accesos", REQ-007) ni el "Menú por rol" de DNATO, que
  sigue andando en paralelo.
- No hace la verificación completa "menú v2 = menú v3 por usuario" (M-8, CP-M1): es E12 (REQ-016). Acá
  M-4 solo garantiza que el menú de Tools no cambia, porque Tools no lee lo que M-4 carga.
- No pone opciones del Portal ni de la Consola en ningún menú (RF-44, R3).
- No agrega cache: cada pedido calcula (RNF-06 pide como máximo 60 s; sin cache se cumple).

---

## Cómo se arma

### Qué es un menú

- **Predeterminado**: automático, uno por empresa, **no se guarda** (se calcula). No se edita ni se
  borra (RF-61).
- **Menú custom**: de una empresa, con nombre único en la empresa y descripción. Árbol de **dos
  niveles**: grupos (etiqueta e ícono) → opciones (una funcionalidad, con etiqueta propia opcional).
- Una opción solo puede ser una funcionalidad **activa, del plan y de tipo pantalla o acción** al
  momento de agregarla (RF-60). Las herramientas de IA (`tool_mcp`) nunca entran (CP-53).
- Una opción que después deja de ser visible (se apaga, sale del plan, se despublica) **se oculta, no se
  borra** (RF-51, RF-52): sigue en la definición y reaparece sola cuando vuelve. En el constructor se ve
  con la marca "oculta" y el motivo **[SUPUESTO]**.
- **Borrar** un menú es baja lógica; sus asignaciones se quitan y esas personas y roles pasan al nivel
  siguiente de la resolución (ver la duda de ADM-UC-130).

### Asignación (RF-62)

- Un menú se asigna a **roles** y/o a **personas** de la empresa. Un rol tiene a lo sumo un menú; una
  persona, también. Sin asignación, el predeterminado.
- Asignar sobre un rol o persona que ya tenía otro menú **lo reemplaza con aviso**.
- Persona = membresía de la empresa (correo + `"group"`), en un estado distinto de `baja`.
- Rol = un rol de la empresa, con el mismo texto que usa `seg.memberships_users.role`.

### R3 — Menú resuelto de una persona

1. **Qué menú**: el asignado a la persona; si no hay, el asignado a su rol; si no, el predeterminado.
2. **Qué opciones**, para cada opción del menú:
   - `visible` si cumple R2 (REQ-006) para esa persona;
   - `otro_plan` si es de otro plan (💎) y de tipo pantalla o acción: va **en su lugar**, con el ícono y
     nombre del plan de menor orden que la trae y la dirección de la vista de presentación;
   - si está sin activar, sin acceso para el rol, sin publicar o es una herramienta de IA: **no va**.
3. **Grupos**: en un menú custom, los grupos del menú en su orden; en el predeterminado, las opciones
   raíz del catálogo (jerarquía módulo → opción) en el orden del catálogo, y dentro de cada una las
   activas en el orden de Funcionalidades (ver la duda de ADM-UC-132 sobre dónde van las de otro plan).
4. Los grupos que quedan vacíos no van.
5. **Reemplaza** la regla actual "si ningún hijo está habilitado se muestran todos"
   (`menu_helper.php:122-125`). En Tools esto rige recién con la derivación.

La regla se calcula **en el DataService** (recurso nuevo), igual que R1 y R2, para que el módulo y
Tools usen la misma. El módulo tiene un modelo (por ejemplo `MenuResuelto`) que la llama con persona y
empresa **de la sesión**, y un servicio de solo lectura para el navegador:
`GET traz-comp-adm/servicios/menu-resuelto` (la persona de la sesión).

Respuesta (JSON, claves en snake_case):

```json
{
  "menu": {"nombre": "Operación", "origen": "rol"},
  "grupos": [
    {"etiqueta": "Mi trabajo", "icono": "fa fa-wrench", "opciones": [
      {"modulo": "MAN", "opcion": "equipos", "etiqueta": "Equipos del taller", "icono": "fa fa-cogs",
       "url": "mantenimiento/equipos", "estado": "visible"},
      {"modulo": "MAN", "opcion": "ot", "etiqueta": "Órdenes de trabajo", "icono": "fa fa-list",
       "url": "mantenimiento/ot", "estado": "otro_plan",
       "plan": {"codigo": "team", "nombre": "Team", "icono": "🥈"},
       "url_presentacion": "traz-comp-adm/presentacion/MAN/ot"}
    ]}
  ]
}
```

`origen` es `persona`, `rol` o `predeterminado`. La dirección de la vista de presentación es
**[SUPUESTO]** hasta REQ-012.

### "Ver como…" (RF-63)

En el constructor, el administrador elige un rol o una persona **de su empresa** y ve el menú resuelto
dibujado como lo dibujaría Tools (barra lateral oscura, opciones de otro plan sombreadas y en cursiva
con el ícono del plan). Llama al mismo recurso del DataService que el servicio, así que muestra
**exactamente** lo mismo (CP-65). El servidor verifica que el rol o la persona sean de la empresa de la
sesión; si no, "sin permiso". Para un rol (sin persona) se usa la asignación del rol y el acceso del rol,
con la membresía tomada como activa.

### Aviso en Funcionalidades (CU-31 A1)

Se agrega a la pantalla de REQ-006: al apagar una funcionalidad que está en uno o más menús custom, antes
de guardar se muestra el aviso con la cantidad y los nombres; "Cancelar" deja el interruptor encendido.

### M-4 — Funcionalidades activas de las empresas existentes

Script de carga, una vez por ambiente, después de REQ-005 (catálogo publicado):

- Para cada empresa y cada funcionalidad publicada que **hoy** algún rol de la empresa tiene asignada en
  `seg.memberships_menues` (por `"group"` = `core.empresas.nombre`, criterio único B.4), crea la fila
  `activa` en `seg.empresas_funcionalidades`, en el orden del catálogo.
- Si lo asignado es una **opción raíz** (como hace hoy el alta de empresa, que solo asigna el nivel 1),
  activa también todas sus hijas publicadas, porque hoy Tools las muestra todas (ver la duda de
  ADM-UC-134).
- Solo **inserta** en una tabla nueva. No toca `seg.memberships_menues`, `seg.menues` ni ninguna otra
  tabla existente; Tools no lee la tabla nueva, así que su menú **no puede cambiar**.
- Lista para Rodolfo los `"group"` de `seg.memberships_menues` que no coinciden con ningún `nombre` de
  empresa (no se cargan).
- Si ya existe la fila de una empresa y funcionalidad, no la pisa (se puede correr dos veces).
- Lleva su vuelta atrás (borra lo que cargó, identificado por fecha y usuario del script).

### Auditoría

Acciones: `menu.crear`, `menu.editar`, `menu.duplicar`, `menu.baja`, `menu.asignar`,
`menu.quitar_asignacion` (RF-100: menú alta, cambio, asignación). En la misma operación que el cambio.

---

## De dónde sale cada dato

| Dato | De dónde | Cómo |
|---|---|---|
| Sesión, empresa activa, correo, es administrador | Sesión y `ADMDataService /usuario/es-admin/…` | Ya existe (REQ-004) |
| Funcionalidades activas del plan (panel) | `ADMDataService GET /empresa/{empr_id}/funcionalidades` | Ya existe (REQ-006) |
| Menús de la empresa, con quién los ve | `ADMDataService GET /empresa/{empr_id}/menus` | **NUEVO** |
| Un menú con su árbol | `ADMDataService GET /menu/{menu_id}` (verifica la empresa) | **NUEVO** |
| Crear, editar (nombre, descripción, árbol), duplicar, borrar | `ADMDataService POST /menu`, `PUT /menu`, `POST /menu/copia`, `PUT /menu/baja` | **NUEVO** |
| Roles y personas de la empresa | `ADMDataService GET /empresa/{empr_id}/roles` y `GET /empresa/{empr_id}/personas` | **NUEVO** (ver la duda de ADM-UC-131) |
| Asignaciones (las dos direcciones) | `ADMDataService GET /empresa/{empr_id}/menus/asignaciones` | **NUEVO** |
| Asignar, quitar | `ADMDataService PUT /menu/asignacion`, `PUT /menu/asignacion/quitar` | **NUEVO** |
| Menú resuelto (R3) | `ADMDataService GET /menu-resuelto/{email}/empresa/{empr_id}` y `GET /menu-resuelto/rol/{rol}/empresa/{empr_id}` | **NUEVO** |
| Menús que usan una funcionalidad (aviso) | `ADMDataService GET /empresa/{empr_id}/menus/con/{modulo}/{opcion}` | **NUEVO** |
| Auditoría | Dentro de cada recurso que escribe | Tabla de REQ-004 |

**Nada va directo a la base.** Todo `menu_id` que llega del navegador se verifica contra la empresa de
la sesión (G2: un menú de otra empresa responde "no existe").

---

## Pantallas

### Portal — menú lateral

Se agrega "🗂️ Menús". `data-testid`: `adm-portal-menu-menus`.

### Portal → Menús — `traz-comp-adm/portal/menus`

Maqueta `doc/v3/dnato/mockups/empresa-menus.html`. Dos pestañas: "Constructor" y "Asignaciones".

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Título | "Menús" y "Armá menús con las funcionalidades activas y asignalos a roles o a personas." | `adm-menus` |
| Botones | "⧉ Duplicar", "＋ Nuevo menú" | `adm-menus-duplicar`, `adm-menus-nuevo` |
| Pestañas | "Constructor", "Asignaciones" | `adm-menus-tab-constructor`, `adm-menus-tab-asignaciones` |
| Mis menús | "Predeterminado" ("Automático · lo ven: <roles> (N personas)") y cada menú custom ("Lo ven: …") | `adm-menus-lista`; ítem `adm-menu-<menu_id>`, `adm-menu-predeterminado` |
| Nombre | Campo con el nombre del menú | `adm-menu-nombre` |
| Ver como | Selector "Ver como… rol <rol>" / "Ver como… <persona>" | `adm-menu-ver-como` |
| Guardar | "Guardar" | `adm-menu-guardar` |
| Lo ven | "Lo ven:" con chips "🎭 <rol>", "👤 <persona> (por rol)", "👤 <persona>" y "＋ Asignar" | `adm-menu-lo-ven`; `adm-menu-asignar` |
| Descripción | Campo "Descripción" | `adm-menu-descripcion` |
| Árbol | Grupos con "⋮⋮", ícono, etiqueta y "✕"; opciones con "⋮⋮", ícono, nombre, "· etiqueta: <etiqueta>", "✎" y "✕"; "Soltá acá una funcionalidad"; "＋ Nuevo grupo" | `adm-menu-arbol`; grupo `adm-menu-grupo-<n>`; opción `adm-menu-opcion-<modulo>-<opcion>`; `adm-menu-nuevo-grupo` |
| Opción oculta | Opción que dejó de ser visible, con la marca "oculta" y el motivo **[SUPUESTO]** | `adm-menu-opcion-oculta` |
| Panel | "Funcionalidades activas", "🔍 Buscar…", agrupadas por módulo; pie "Solo lo activo de tu plan, de tipo pantalla o acción. Las herramientas de IA no entran en menús." y "Lo que trae tu plan →" | `adm-menu-panel`; `adm-menu-panel-buscar`; `adm-menu-panel-plan` |
| Borrar | "🗑 Borrar menú" **[SUPUESTO]** (la maqueta no lo muestra; RF-60 pide la baja) | `adm-menu-borrar` |
| Vista "Ver como" | El menú resuelto dibujado como la barra lateral de Tools, con el origen ("por persona", "por rol", "predeterminado") | `adm-menu-vista-como` |

**Asignaciones → "Por rol / persona"**

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Tabla | Rol / persona, Menú asignado (selector), Resuelto (lo que ve), cambio ("cambió el <fecha>"), "Quitar" en las personas | `adm-asig-por-rol`; fila `adm-asig-rol-<rol>`, `adm-asig-persona-<email>`; `adm-asig-quitar` |
| Asignar a persona | "＋ Asignar a una persona" | `adm-asig-agregar-persona` |
| Leyenda | "Quién ve qué menú. Persona gana a rol; rol gana a predeterminado." | `adm-asig-leyenda` |

**Asignaciones → "Por menú"**

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Tabla | Menú, Roles, Personas (directo), Lo ven en total | `adm-asig-por-menu`; fila `adm-asig-menu-<menu_id>` |

### Portal → Funcionalidades (agregado a REQ-006)

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Aviso al apagar | "\"<funcionalidad>\" está en N menú(s): dejará de verse en él (ellos)" y "El menú \"<menú>\" la oculta mientras esté apagada; si la volvés a encender, reaparece. ¿Continuar?", con "Cancelar" y "Apagar" | `adm-func-aviso-menus`; `adm-func-aviso-apagar`, `adm-func-aviso-cancelar` |

### Mensajes

| Caso | Mensaje | `data-testid` |
|---|---|---|
| Menú sin opciones | "Agregá al menos una opción" | `adm-menu-error` |
| Nombre repetido | "Ya tenés un menú con ese nombre" | `adm-menu-error` |
| Reemplazo de asignación | "El rol <rol> tenía <menú>: se reemplaza" (persona: "<persona> tenía <menú>: se reemplaza") y confirmación | `adm-asig-reemplazo` |
| Guardado | "Guardado ✓" | `adm-guardado` |
| Duplicado | Aparece "<nombre> (copia)" | — |
| Borrar un menú asignado **[SUPUESTO]** | "Lo ven N personas. Si lo borrás, pasan a ver el menú de su rol o el predeterminado. ¿Continuar?" | `adm-menu-borrar-aviso` |
| Funcionalidad que no se puede agregar (pedido directo) **[SUPUESTO]** | "Esa funcionalidad no se puede agregar a un menú." | `adm-menu-error` |
| Falla del servicio | "No pudimos guardar. Probá de nuevo en un rato." | `adm-menu-error` |

---

## Reglas

1. Solo el administrador de la empresa activa ve, arma y asigna menús de su empresa.
2. Nombre de menú único en la empresa; un menú tiene al menos una opción.
3. Solo se agregan funcionalidades activas, del plan y de tipo pantalla o acción; nunca herramientas de
   IA. El servidor lo verifica aunque el pedido llegue directo.
4. Dos niveles: grupo → opción.
5. El predeterminado no se edita ni se borra.
6. Un rol tiene a lo sumo un menú y una persona también; asignar sobre uno existente lo reemplaza con
   aviso.
7. Resolución: persona → rol → predeterminado (R3).
8. En el menú resuelto, lo visible va con estado `visible`; lo de otro plan (pantalla o acción) queda en
   su lugar con estado `otro_plan` y el plan de menor orden; lo sin activar, sin acceso, sin publicar o
   de IA no va; los grupos vacíos no van.
9. "Ver como…" muestra exactamente lo que devuelve el servicio "Menú resuelto".
10. Apagar una funcionalidad que está en menús avisa antes; la opción se oculta en esos menús y no se
    borra; al encenderla reaparece.
11. Todo `menu_id`, rol o persona que llega del navegador se verifica contra la empresa de la sesión.
12. Borrar un menú es baja lógica.
13. M-4 solo inserta en `seg.empresas_funcionalidades`; el menú de Tools de cada usuario es el mismo
    antes y después.

## Registro en el log

`log_message('DEBUG', '#TRAZA | ADM | <Clase> | <metodo>() ...')`. Se registran los rechazos y cada alta,
cambio, baja y asignación de menú (empresa, menú, rol o persona, quién). El servicio "Menú resuelto" no
registra cada consulta.

---

## Datos

**🔴: Rodolfo aprueba el script antes de construir.** Las tablas las crea REQ-004 con los atributos; acá
se proponen los nombres de columnas **[SUPUESTO]** (si el script de REQ-004 no corrió todavía, van en
él; si no, en uno chico con su vuelta atrás).

| Tabla | Columnas propuestas |
|---|---|
| `seg.menus_custom` | `menu_id`, `empr_id`, `nombre` (único por empresa entre los no borrados), `descripcion`, `eliminado`, `fec_alta`, `usuario` |
| `seg.menus_custom_items` | `item_id`, `menu_id`, `padre_id` (nulo = grupo), `etiqueta`, `icono` (grupos), `modulo` y `opcion` (opciones, con referencia a `seg.menues`), `orden` |
| `seg.menus_asignaciones` | `asignacion_id`, `menu_id`, `empr_id`, `rol` **o** `email` (uno de los dos), `fec_alta`, `usuario`; única por (`empr_id`, `rol`) y por (`empr_id`, `email`) |

### Carga de datos

| Paso | Qué hace |
|---|---|
| M-4 | Filas `activa` en `seg.empresas_funcionalidades` por empresa, según lo que hoy tienen asignado sus roles en `seg.memberships_menues` (con las hijas de las opciones raíz), en el orden del catálogo. Lista los `"group"` sin empresa |

Ninguna fila ni columna existente cambia.

---

## Decisiones tomadas

- **Tools no cambia en este requerimiento** (propuesta para Rodolfo en la duda de ADM-UC-132): el menú
  lateral está en todas las pantallas de producción; cambiar su fuente necesita análisis de impacto, la
  comparación M-8 sobre datos reales y una forma de volver atrás. Este requerimiento deja el servicio
  listo y probado con "Ver como…".
- **R3 en el DataService**, como R1 y R2: una sola regla para el módulo y para Tools.
- **El predeterminado no se guarda**: se calcula, así nunca queda desactualizado respecto de
  Funcionalidades.
- **Ocultar, no borrar**: las opciones que dejan de ser visibles quedan en la definición (RF-51, RF-52).
- **M-4 no toca `seg.memberships_menues`**: solo inserta en una tabla nueva que Tools no lee, así v2 no
  nota nada (compatibilidad v2).
- **"Ver como…" y el servicio usan el mismo recurso**: es lo que garantiza CP-65.

## Cómo se revisa (además de DocTest)

- Script de M-4 aprobado por Rodolfo, corrido en una copia de DEMO, con su vuelta atrás y el listado de
  `"group"` sin empresa en la descripción del pull request.
- El menú de Tools de los usuarios DocTest es el mismo antes y después de M-4 (DocTest `regresion` en
  verde).
- Un `menu_id` de otra empresa responde "no existe" en todos los recursos.
- `phpcs` con PHPCompatibility para PHP 5.6 sin errores; `./mvnw clean install` del proyecto de APIs.
- **Aviso para el despliegue:** el script de despliegue sube los DataServices pero no las APIs; este
  requerimiento no agrega APIs.

## Dudas abiertas

Están en los casos de uso (campo `dudas`), para contestarlas en un solo lugar.

---

## Casos de prueba de la especificación que cubre

| CP | Qué prueba | Lo cubre |
|---|---|---|
| CP-60 | Armar menú arrastrando y guardar | ADM-UC-130 |
| CP-61 | El panel solo ofrece funcionalidades visibles; pie "Lo que trae tu plan" | ADM-UC-130 |
| CP-62 | Menú sin opciones no se guarda | ADM-UC-130 |
| CP-63 | Nombre de menú repetido se rechaza | ADM-UC-130 |
| CP-68 | Duplicar menú | ADM-UC-130 |
| CP-66 | Asignar sobre un rol que ya tenía menú reemplaza con aviso | ADM-UC-131 |
| CP-69 | Las dos direcciones | ADM-UC-131 |
| CP-64 | Resolución persona > rol > predeterminado | ADM-UC-132 |
| CP-65 | "Ver como…" = servicio "Menú resuelto" | ADM-UC-132 |
| CP-67 | Menú resuelto: jerarquía del catálogo y opciones de otro plan en su lugar | ADM-UC-132, **contra el servicio**. "Al hacer clic se abre la vista de presentación": REQ-012. Que la barra lateral de Tools lo dibuje: derivación en Tools (fuera de alcance) |
| CP-51 | Apagar una funcionalidad la oculta en menús custom con aviso | ADM-UC-133 (aviso, oculta sin borrar, en el servicio y en "Ver como…") |
| CP-14, CP-52 (parte de menús) | Lo que sale del plan queda en el menú como `otro_plan` y reaparece al volver | ADM-UC-133 (la parte de activación ya la cubre ADM-UC-071 de REQ-006) |
| CP-53 (parte de menús) | Las herramientas de IA no están en el panel ni en el menú resuelto | ADM-UC-130 y ADM-UC-132 |
| CP-15 (parte de menús) | Opción de otro plan en su lugar con el ícono del plan más bajo | ADM-UC-132 (en el servicio) |
| CP-M1 | Menú v2 = menú v3 por usuario | Fuera de alcance: M-8, E12 (REQ-016). ADM-UC-134 solo prueba que M-4 no cambia el menú de Tools |
