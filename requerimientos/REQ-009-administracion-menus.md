# REQ-009 · Módulo Administración — Menús por rol o por persona

## Objetivo

Noveno trabajo de Pablo para el módulo **Administración** (`traz-comp-adm`): la pantalla del Portal
donde el administrador arma menús con las funcionalidades activas de su empresa y los asigna a roles o
a personas, el servicio "Menú resuelto" (regla R3) que dice qué menú le toca a cada uno, la carga
inicial de funcionalidades activas de las empresas que ya existen (M-4) y **el menú lateral de Tools
dibujado con ese servicio** (punto T-2), encendido por una variable de sistema. Lo leen Pablo para
planificar y Rodolfo para aprobar el script y el análisis de impacto en Tools. **No** cubre la vista de
presentación que abre una opción sombreada (REQ-012) ni el control de acceso por pantalla en Tools
(T-5, deuda H-091). Lista completa en [`README.md`](README.md).

| Campo | Valor |
|---|---|
| Estado | **Borrador**: Rodolfo tiene que contestar las dudas de los casos, aprobar el script de M-4 y el análisis de impacto en Tools |
| Se apoya en | [REQ-002](REQ-002-administracion-esqueleto.md) (controlador base, Portal), [REQ-004](REQ-004-administracion-base-y-atributos.md) (tablas `seg.menus_custom`, `seg.menus_custom_items`, `seg.menus_asignaciones`, estado de membresía, auditoría), [REQ-005](REQ-005-administracion-catalogo-y-planes.md) (catálogo y planes) y [REQ-006](REQ-006-administracion-funcionalidades.md) (R1, R2, Funcionalidades) |
| Entrega de la especificación | **E6** de `doc/v3/dnato/PROMPT_CLI_DNATO_V3_BUILD.md`: menús custom, asignación en las dos direcciones, "Ver como…", servicio "Menú resuelto" (R3: jerarquía + estado `visible` / `otro_plan` por ítem), migración M-4. CU-32, CU-33; CP-51, CP-60 a 69. Más el punto **T-2** de `02_MODELO_Y_REGLAS.md` §9b (menú operativo de Tools con el menú resuelto) y su parte de **T-10** (pruebas del menú), por decisión de Rodolfo |
| Casos de uso | `ADM-UC-130` a `ADM-UC-135` en `doctest/catalogo/adm/` |
| Repos que se tocan | `traz-comp-adm` (pantalla de Menús, aviso en Funcionalidades, modelo y servicio "Menú resuelto"); `traz-tools`: recursos **nuevos** en `ADMDataService.dbs`, el script de M-4, la comparación M-8, **y el núcleo**: `application/controllers/Dash.php`, `application/models/Dashs.php` y `application/helpers/menu_helper.php` (ver "Análisis de impacto en Tools"); prueba DocTest nueva del menú lateral |
| Riesgo | 🔴 **Cambio de base de datos; Rodolfo aprueba el script antes de construir**: carga de datos M-4 (filas nuevas en `seg.empresas_funcionalidades` para todas las empresas), nombres de columnas de las tablas de menús y una variable nueva en `core.tablas`. No toca ninguna fila ni columna existente. 🔴 **Núcleo de Tools**: el menú lateral de **todas** las pantallas de producción pasa a salir del servicio nuevo cuando se enciende la variable → **análisis de impacto aprobado por Rodolfo antes de construir** (sección "Análisis de impacto en Tools"). Recursos del DataService nuevos (🟡); `COREDataService` no se modifica |

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
  para probar la resolución con "Ver como…", el servicio y el menú lateral de Tools.
- **Superusuario**: enciende o apaga en cada ambiente el menú nuevo de Tools (Consola → Variables de
  sistema, REQ-004) y corre la comparación M-8 antes de encenderlo.

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
6. Que Tools dibuje su menú lateral con el servicio "Menú resuelto" (T-2, RF-64, RF-65), sin la regla
   "si ningún hijo está habilitado se muestran todos", encendido por una variable de sistema por
   ambiente, con vuelta al menú de hoy si el servicio no responde, y con la comparación M-8 antes de
   encender → **ADM-UC-135**.

## Qué NO hace

- **No controla el acceso por pantalla en Tools.** Que una opción no esté en el menú no impide abrirla
  escribiendo la dirección (igual que hoy): eso es el chequeo central T-5 (deuda H-091).
- **No cambia la barra superior de Tools** (T-3): botones de REQ-004, perfil de REQ-007, indicador de
  cuota de REQ-011.
- **No cambia los menús propios de los submódulos** (`ddpe-tools-pro` arma una copia del menú viejo, ver
  "Análisis de impacto en Tools"): siguen como hoy.
- **No borra la regla vieja del código.** `menu()` de `menu_helper.php` queda intacta como respaldo y
  para cuando la variable está apagada; se quita cuando la variable quede encendida en todos los
  ambientes (corte final, REQ-016).
- No hace la vista de presentación que abre una opción de otro plan (REQ-012): el servicio devuelve su
  dirección, la página llega con REQ-012. Hasta entonces la opción sombreada en Tools no se puede tocar.
- No cambia el menú de un miembro desde Usuarios (RF-75) ni el menú opcional al invitar (RF-71): es
  REQ-007, que usa esta misma asignación.
- No modifica `seg.memberships_menues` ("Roles y accesos", REQ-007) ni el "Menú por rol" de DNATO, que
  sigue andando en paralelo.
- No hace la verificación **final** "menú v2 = menú v3 por usuario" del corte (M-8, CP-M1, E12):
  REQ-016 la corre en todos los ambientes con la comparación que se construye acá. Acá la comparación
  es la condición para encender la variable en cada ambiente.
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
5. **Reemplaza** la regla de dibujo actual "si ningún hijo está habilitado se muestran todos"
   (`menu_helper.php:122-125`). En Tools rige cuando la variable `menu_resuelto_en_tools` está encendida
   (función 6). Ojo: lo que desaparece es la regla **de dibujo**; el **acceso del rol** a una hija que
   hoy solo tiene asignado el padre lo sigue dando R2 con la herencia (ver "M-4" más abajo), así nadie
   pierde opciones.

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
  tabla existente. Con la variable apagada Tools no lee la tabla nueva, así que su menú **no puede
  cambiar**; antes de encenderla, la comparación M-8 prueba que tampoco cambia con el menú nuevo.

**Versión única sobre las hijas (cierra la contradicción con REQ-006):** M-4 **no** agrega filas a
`seg.memberships_menues`, ni las hijas ni nada. Lo que hace falta para que nadie pierda opciones son dos
cosas, y ninguna escribe esa tabla:

1. **Funcionalidad activa (R1):** M-4 activa en `seg.empresas_funcionalidades` la raíz asignada y todas
   sus hijas publicadas.
2. **Acceso del rol (R2):** el rol tiene acceso a una hija si la tiene asignada **o** si tiene asignada
   la raíz y **ninguna** hermana asignada. Esta herencia es **permanente** (no "hasta M-4"), vive en el
   recurso de R2 del DataService y es la misma que ya usa "Roles y accesos" de REQ-007. Así también
   funcionan las empresas que se sigan dando de alta por DNATO, que asigna solo la raíz.

Lo que hay que corregir en REQ-006 está en la duda de ADM-UC-134.
- Lista para Rodolfo los `"group"` de `seg.memberships_menues` que no coinciden con ningún `nombre` de
  empresa (no se cargan).
- Si ya existe la fila de una empresa y funcionalidad, no la pisa (se puede correr dos veces).
- Lleva su vuelta atrás (borra lo que cargó, identificado por fecha y usuario del script).

### Auditoría

Acciones: `menu.crear`, `menu.editar`, `menu.duplicar`, `menu.baja`, `menu.asignar`,
`menu.quitar_asignacion` (RF-100: menú alta, cambio, asignación). En la misma operación que el cambio.
Encender o apagar la variable `menu_resuelto_en_tools` queda en la auditoría de variables de REQ-004.

### Menú lateral de Tools con el menú resuelto (T-2, función 6) — núcleo

Hoy (rama `develop`): `Dash::index` (`application/controllers/Dash.php:26-27`) pide
`Dashs::obtenerMenu()` (`application/models/Dashs.php:22-29`, que llama a
`REST_CORE/menuitems/porEmail/{email}/porGrupo/{group}` → consulta `getMenuByUserPermission` de
`COREDataService.dbs:8`) y lo dibuja con `menu()` de `application/helpers/menu_helper.php:10-144`. El
HTML queda en `$menu` y lo imprime `application/views/layout/Admin.php:173`. Las pantallas se cargan
dentro de `#content` con `linkTo(...)`, así que el menú lateral **se arma una sola vez por carga de
página** y es el mismo para todas las pantallas.

Cómo queda:

1. **Variable de sistema** `menu_resuelto_en_tools` (fila en `core.tablas` sin empresa, como las de
   REQ-004, con su historial), valores `si` / `no`, **`no` por defecto**. Cada ambiente tiene su base,
   así que se enciende **por ambiente** desde Consola → Variables de sistema, sin desplegar nada.
2. `Dash::index` lee la variable **[SUPUESTO]** con el mismo `Tablas->obtenerTabla(...)` que ya usa para
   el pie y el logo (`Dash.php:34-41`). Si no es `si`, o no se puede leer: **todo como hoy**
   (`obtenerMenu()` + `menu()`), sin ningún otro cambio.
3. Si es `si`: un método nuevo `Dashs::obtenerMenuResuelto()` llama por `wso2()` al recurso
   `ADMDataService GET /menu-resuelto/{email}/empresa/{empr_id}` con correo y empresa **de la sesión**,
   con un tiempo máximo de espera corto **[SUPUESTO: 3 segundos]**. Tools llama al DataService
   directamente, no al módulo, para no depender de que el submódulo `traz-comp-adm` esté instalado.
4. Se dibuja con una función **nueva** `menu_resuelto($json)` en `menu_helper.php` (la función `menu()`
   no se toca). Misma estructura de HTML que hoy (`ul.sidebar-menu`, `li.treeview`, `treeview-menu`,
   `onclick='linkTo("<url>")'`) para que el despliegue de grupos y la navegación sigan andando igual:
   - grupo = un `li.treeview` con su ícono y etiqueta; opción `visible` = un enlace a su `url`;
   - opción `otro_plan` = misma posición, sombreada y en cursiva, con el ícono del plan y el título
     "Incluido en el plan <plan>" **[SUPUESTO]**; **no navega** hasta REQ-012 (después abre
     `url_presentacion`);
   - plan vencido: R1 pone todo como de otro plan, así que todo sale sombreado (T-2). El cartel de plan
     vencido es de REQ-010 / REQ-012;
   - **sin** la regla "si ningún hijo está habilitado se muestran todos": se dibuja exactamente lo que
     devuelve el servicio;
   - etiquetas e íconos se **escapan** antes de dibujar (`html_escape`): las etiquetas las escribe el
     administrador y el menú se ve en todas las pantallas;
   - los estilos del sombreado van en el mismo HTML que devuelve la función (un bloque `<style>` chico),
     para **no tocar** `layout/Admin.php` **[decisión técnica menor]**.
5. **Vuelta al menú de hoy (respaldo):** si el servicio no responde a tiempo, responde con error, o
   devuelve una respuesta que no se puede leer **o sin ninguna opción** **[SUPUESTO]**, se dibuja el menú
   de hoy (`obtenerMenu()` + `menu()`) y se registra en el log con el motivo. La persona nunca se queda
   sin menú por una falla del servicio.
6. **Cuándo se ve un cambio:** como el menú se arma al cargar la página, un menú asignado o cambiado se
   ve en Tools al recargar la página o al volver a ingresar (igual que hoy con "Menú por rol").

### Comparación M-8 antes de encender

Un script de consulta (solo lectura) que, para cada usuario con membresía activa de cada empresa, compara
las opciones que hoy ve en Tools (lo que devuelve `getMenuByUserPermission` como habilitado, **más** las
hijas que hoy se muestran por la regla "todos los hijos") contra las opciones `visible` del menú resuelto
**predeterminado** (sin menús custom), y lista las diferencias por usuario: "falta en el nuevo" y "sobra
en el nuevo". Se corre en una **copia de DEMO**; con **cero** diferencias sin explicar, Rodolfo autoriza
encender la variable en ese ambiente. REQ-016 lo vuelve a correr en el corte final (CP-M1).

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
| Menú lateral de Tools, variable encendida o apagada | `COREDataService` (`getTabla`, por `Tablas->obtenerTabla`) | Ya existe (no se modifica) |
| Menú lateral de Tools con la variable encendida | `ADMDataService GET /menu-resuelto/{email}/empresa/{empr_id}` (el mismo de arriba) | **NUEVO** (de este requerimiento) |
| Menú lateral de Tools con la variable apagada o como respaldo | `COREDataService GET /menuitems/porEmail/{email}/porGrupo/{group}` (`getMenuByUserPermission`) | Ya existe (no se modifica) |
| Comparación M-8 | Consulta de solo lectura sobre `seg.menues`, `seg.menues_users_vw`, `seg.memberships_menues`, `seg.memberships_users` y el recurso de R3 | Script del requerimiento |

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

### Tools — menú lateral con la variable encendida (núcleo)

Maqueta: la barra lateral de `doc/v3/dnato/mockups/vista-esfumada.html` (grupos Mantenimiento,
Almacenes, Procesos, Producción; "🔁 Ajustes de stock 🥈" sombreada en su lugar).

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Menú | La lista lateral de siempre (`ul.sidebar-menu`) | `adm-tools-menu` (con `data-origen` = `resuelto` o `respaldo`) |
| Grupo | Ícono y etiqueta del grupo | `adm-tools-menu-grupo-<n>` |
| Opción visible | Ícono y etiqueta; al hacer clic abre la pantalla como hoy | `adm-tools-menu-opcion-<modulo>-<opcion>` |
| Opción de otro plan | Sombreada, en cursiva, con el ícono del plan (por ejemplo "🥈") y el título "Incluido en el plan <plan>" **[SUPUESTO]**; no navega hasta REQ-012 | `adm-tools-menu-otro-plan` (además del de la opción) |

Con la variable apagada, o en el respaldo, el menú es el de hoy: sin `data-testid` nuevos salvo
`adm-tools-menu` con `data-origen="respaldo"` cuando fue por falla **[SUPUESTO]**. No hay mensajes a la
persona: el respaldo es silencioso y queda en el log.

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
    antes y después. No escribe `seg.memberships_menues`: el acceso de un rol a las hijas de una raíz
    asignada lo da R2 con la herencia permanente.
14. El menú lateral de Tools sale del menú resuelto **solo** si la variable `menu_resuelto_en_tools` del
    ambiente vale `si`; por defecto vale `no` y Tools dibuja el menú de hoy.
15. Con la variable encendida, Tools dibuja exactamente lo que devuelve el servicio (sin la regla "todos
    los hijos"), con correo y empresa de la sesión; lo de otro plan queda sombreado en su lugar.
16. Si el servicio no responde a tiempo, falla o devuelve un menú sin opciones, Tools dibuja el menú de
    hoy y lo registra; nadie se queda sin menú.
17. Las etiquetas que escribe el administrador se escapan antes de dibujarse en Tools.
18. La variable se enciende en un ambiente solo después de correr M-4 y la comparación M-8 en una copia
    de ese ambiente sin diferencias sin explicar, con el OK de Rodolfo.

## Registro en el log

`log_message('DEBUG', '#TRAZA | ADM | <Clase> | <metodo>() ...')`. Se registran los rechazos y cada alta,
cambio, baja y asignación de menú (empresa, menú, rol o persona, quién). El servicio "Menú resuelto" no
registra cada consulta. En Tools: `#TRAZA | CORE | Dash | index()` registra si el menú salió del menú
resuelto o del respaldo, y en el respaldo el motivo (sin respuesta, error, vacío) y cuánto tardó.

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
| M-4 | Filas `activa` en `seg.empresas_funcionalidades` por empresa, según lo que hoy tienen asignado sus roles en `seg.memberships_menues` (con las hijas de las opciones raíz), en el orden del catálogo. Lista los `"group"` sin empresa. **No** escribe `seg.memberships_menues` |

### Variable nueva (fila en `core.tablas` sin empresa, con historial de REQ-004)

| Clave | Valor inicial | Para qué |
|---|---|---|
| `menu_resuelto_en_tools` | `no` | Encender por ambiente el menú lateral de Tools con el menú resuelto (T-2) |

Ninguna fila ni columna existente cambia.

---

## Análisis de impacto en Tools (núcleo) — lo aprueba Rodolfo antes de construir

Verificado contra el código de `traz-tools`, rama `develop` (y los submódulos de la copia local; Pablo
lo confirma en su plan contra cada ambiente).

### Qué archivos cambian

| Archivo | Hoy | Cambio |
|---|---|---|
| `application/controllers/Dash.php` (`index()`, líneas 26-27) | Arma `$data['menu'] = menu($this->Dashs->obtenerMenu())` | Lee la variable; si es `si`, pide el menú resuelto y lo dibuja con `menu_resuelto()`; si falla o la variable no es `si`, lo de hoy |
| `application/models/Dashs.php` (líneas 22-29) | `obtenerMenu()` | Se **agrega** `obtenerMenuResuelto()`; `obtenerMenu()` no cambia |
| `application/helpers/menu_helper.php` (líneas 10-144) | `menu()` con la regla "todos los hijos" (122-125) | Se **agrega** `menu_resuelto()`; `menu()` no cambia |
| `application/views/layout/Admin.php:173` | `echo $menu` | **Sin cambios** |
| `_backend/.../data-services/COREDataService.dbs:8` y recurso `/menuitems/porEmail/{email}/porGrupo/{group}` (:642) | Fuente del menú | **Sin cambios**: sigue para la variable apagada, el respaldo y los submódulos |
| `_backend/.../data-services/ADMDataService.dbs` | — | Recurso nuevo `/menu-resuelto/...` (ya listado arriba) |
| `core.tablas` | — | Fila nueva `menu_resuelto_en_tools` = `no` |
| `doctest/tests/e2e/specs/adm/` | No hay prueba del menú lateral | Prueba nueva del menú lateral (ADM-UC-135), con la variable apagada y encendida |

### Quién lo consume

- **Todas las pantallas de Tools y todos los usuarios**: el menú lateral se arma solo en `Dash::index` y
  las pantallas se cargan adentro con `linkTo`. Si el menú falla, falla para todos.
- **Copias en submódulos** (verificado con grep en `application/modules/`):
  - `ddpe-tools-pro/controllers/Dash.php:24-25` y `models/Dashs.php:22-26` arman **su propio** menú con
    `menu()` y el mismo recurso de `COREDataService`: **no cambian** (siguen con el menú de hoy). Ver la
    duda de ADM-UC-135.
  - `traz-comp-pan/helpers/menu_helper.php` es una copia vieja del helper; su `Dash` tiene la llamada
    comentada (`controllers/Dash.php:24-25`), igual que `traz-comp-codigos`. `traz-comp-formularios` y
    `traz-prod-trazasoft` dejan el menú vacío, `traz-comp-tareasestandar` lo lee de un `menu.json`,
    `traz-comp-almacenes` carga el helper sin usarlo. **Ninguno cambia.** Como en HMVC un módulo con su
    propio `menu_helper.php` carga el suyo, ningún submódulo debe llamar a `menu_resuelto()`.
- **DNATO** (aplicación aparte) tiene su propia barra: no cambia. **AssetPlanner** y **el agente** no
  usan este menú.
- **DocTest**: ninguna prueba lee hoy el menú lateral (grep en `doctest/tests/e2e/`); navegan con
  `linkTo` (`pages/alm/AlmacenesPage.ts:45-75`, `pages/alm/FlujoAlmacen.ts`). La suite `regresion`
  tiene que seguir en verde con la variable encendida.

### Qué se rompe si falla, y cómo se protege

| Si pasa esto | Efecto | Protección |
|---|---|---|
| El servicio no responde, tarda o falla | Sin menú lateral: nadie puede navegar Tools | Tiempo máximo corto y **respaldo al menú de hoy** (regla 16) |
| R3 calcula mal (hijas por la regla del padre, comodín `TODOS` de `seg.menues_users_vw`, empresas sin M-4) | Personas que pierden opciones y no pueden trabajar | **Comparación M-8** en una copia de DEMO con cero diferencias sin explicar antes de encender; la variable se apaga sin desplegar |
| Se enciende en un ambiente sin M-4 | Todo "sin activar": menú vacío | Regla 18 (M-4 primero) y respaldo por menú vacío (regla 16) |
| Una etiqueta con código | Código que corre en todas las pantallas | Se escapan etiquetas e íconos (regla 17) |
| El tablero carga más lento | Peor experiencia en cada ingreso | Se mide el tiempo de `Dash::index` antes y después en la copia de DEMO; Rodolfo decide si es aceptable |
| Hay que volver atrás | — | Poner la variable en `no` desde Consola → Variables (queda en el historial); ningún despliegue |

### Pruebas que se actualizan en este mismo requerimiento (T-10)

- Prueba DocTest nueva del menú lateral de Tools (ADM-UC-135): variable apagada = menú de hoy; encendida
  = menú resuelto (predeterminado, por rol, por persona, sombreado); respaldo con el servicio caído.
- La barra **lateral** es la única que cambia acá; las pruebas de la barra **superior** van con quien la
  toca (REQ-004, REQ-007, REQ-011).
- Suite `regresion` de DocTest en verde con la variable encendida en la copia de DEMO.

---

## Decisiones tomadas

- **El menú operativo de Tools entra en este requerimiento** (Rodolfo, 2026-11-10): Tools dibuja con el
  servicio "Menú resuelto", sin la regla "todos los hijos" y sin `getMenuByUserPermission` como fuente
  cuando la variable está encendida. Como es núcleo, va con análisis de impacto, variable por ambiente
  apagada por defecto, respaldo al menú de hoy y comparación M-8 antes de encender.
- **Tools llama al DataService, no al módulo**: así el menú no depende de que `traz-comp-adm` esté
  instalado en ese ambiente, y la regla sigue en un solo lugar.
- **Funciones nuevas al lado de las viejas** (`menu_resuelto()`, `obtenerMenuResuelto()`): la vuelta
  atrás es apagar la variable, sin desplegar.
- **La herencia padre → hijas es parte de R2, para siempre**: M-4 no escribe `seg.memberships_menues`
  (compatibilidad con v2 y con las altas de DNATO, que asignan solo la raíz).
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
- **Análisis de impacto en Tools aprobado por Rodolfo** antes de construir; comparación M-8 corrida en la
  copia de DEMO, con la lista de diferencias (o "cero") en la descripción del pull request.
- Con la variable encendida en la copia de DEMO: ADM-UC-135 y la suite `regresion` en verde; con el
  recurso del menú resuelto apagado a propósito, el menú de hoy aparece (respaldo).
- Tiempo de carga de `Dash::index` antes y después, en la descripción del pull request.
- `phpcs` con PHPCompatibility para PHP 5.6 sin errores; `./mvnw clean install` del proyecto de APIs.
- **Aviso para el despliegue:** el script de despliegue sube los DataServices pero no las APIs; este
  requerimiento no agrega APIs. La variable se carga en `no` en cada ambiente con el script de base.

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
| CP-67 | Menú resuelto: jerarquía del catálogo y opciones de otro plan en su lugar | ADM-UC-132 contra el servicio y **ADM-UC-135 en la barra lateral de Tools**. "Al hacer clic se abre la vista de presentación": REQ-012 |
| CP-51 | Apagar una funcionalidad la oculta en menús custom con aviso | ADM-UC-133 (aviso, oculta sin borrar, en el servicio y en "Ver como…") |
| CP-14, CP-52 (parte de menús) | Lo que sale del plan queda en el menú como `otro_plan` y reaparece al volver | ADM-UC-133 (la parte de activación ya la cubre ADM-UC-071 de REQ-006) |
| CP-53 (parte de menús) | Las herramientas de IA no están en el panel ni en el menú resuelto | ADM-UC-130 y ADM-UC-132 |
| CP-15 (parte de menús) | Opción de otro plan en su lugar con el ícono del plan más bajo | ADM-UC-132 (en el servicio) |
| CP-M1 | Menú v2 = menú v3 por usuario | En parte: ADM-UC-135 (comparación M-8 en una copia de DEMO, condición para encender la variable) y ADM-UC-134 (M-4 no cambia el menú de hoy). La verificación final del corte en todos los ambientes: REQ-016 |
| T-2 (§9b) | Menú operativo de Tools con el menú resuelto, sin la regla "todos los hijos" | ADM-UC-135 |
| T-10 (§9b, parte del menú) | Pruebas del menú actualizadas en la misma entrega | ADM-UC-135 (prueba nueva del menú lateral) |
