# REQ-004 · Módulo Administración — Lo que falta de la base y atributos nuevos

## Objetivo

Cuarto trabajo de Pablo para el módulo **Administración** (`traz-comp-adm`): dejar lista la base de
datos que van a usar todas las pantallas siguientes (atributos y entidades nuevas, auditoría, variables
de sistema con historial) y cerrar lo que el esqueleto (REQ-002) dejó afuera: la marca de superusuario,
una sola definición de administrador, el servicio "Contexto del usuario" y los botones "🏢 Mi empresa"
y "🔑 Consola" en la barra superior de Tools. Lo leen Pablo para planificar y Rodolfo para aprobar la
parte de la carga de datos que toca filas existentes y el análisis de impacto. **No** cubre las pantallas que usan esas tablas (planes,
usuarios, menús, cuota, etc.: REQ-005 en adelante, ver [`README.md`](README.md)) ni la registración
copiada ([REQ-003](REQ-003-administracion-identidad.md)).

| Campo | Valor |
|---|---|
| Estado | Borrador: Rodolfo tiene que contestar las dudas de los casos, aprobar la carga de datos sobre tablas existentes (M-2 de las herramientas del agente y M-6; M-7 lo decide el equipo (regla de Rodolfo del 2026-11-10)) y el análisis de impacto de la barra de Tools |
| Se apoya en | [REQ-002](REQ-002-administracion-esqueleto.md) (controlador base, Portal y Consola) y [REQ-003](REQ-003-administracion-identidad.md) (ingreso copiado); análisis [`ANALISIS_INICIAL.md`](../doc/v3/administracion/ANALISIS_INICIAL.md) B.3 (extensiones) y B.4 (criterio membresía → empresa) |
| Entrega de la especificación | **E1** completa de `doc/v3/dnato/PROMPT_CLI_DNATO_V3_BUILD.md` (atributos y entidades, auditoría, variables con historial, migraciones M-1, M-2, M-5, M-6, M-7; CU-22; CP-101, CP-102) **más lo de E0 que REQ-002 no cubrió**: marca de superusuario (R7, C-5), definición única de administrador (R7, D-07), servicio "Contexto del usuario" (`02_MODELO_Y_REGLAS.md` §4) y el botón en la barra de Tools (`mockups/tools-barra-superior.html`, T-3 de §9b) |
| Casos de uso | `ADM-UC-030` a `ADM-UC-035` en `doctest/catalogo/adm/` |
| Repos que se tocan | `traz-comp-adm` (pantalla de variables, servicio Contexto, controlador base); `traz-tools`: script de base nuevo, DataService **nuevo** `ADMDataService.dbs`, y del núcleo `application/controllers/Dash.php` y `application/views/layout/perfil.php` (los botones) |
| Riesgo | 🔴 Las tablas nuevas (todas en `seg`), las columnas optativas nuevas en `core.empresas`, `seg.users` y `seg.menues`, la función y el disparador nuevos son **cambio de base aditivo: lo decide el equipo (regla de Rodolfo del 2026-11-10)**. Sigue en rojo por: (1) **núcleo de Tools**: la barra superior y el tablero (`perfil.php`, `Dash.php`); (2) **carga de datos que cambia o agrega filas en tablas existentes**: M-2 (herramientas del agente como filas nuevas de `seg.menues`, que pueden cambiar el menú de Tools) y M-6 (marca `superusuario` en una fila existente de `seg.users`). Esas dos cosas las aprueba Rodolfo antes de construir, con análisis de impacto. M-7 (filas nuevas en `core.tablas`, sin cambiar las existentes) **lo decide el equipo (regla de Rodolfo del 2026-11-10)**. El DataService es nuevo (🟡); no se modifica ninguno existente |

---

## Para qué sirve

- Que las pantallas que vienen (planes, usuarios, menús, cuota) encuentren la base lista, con **un solo
  script**, en vez de un cambio de base por requerimiento.
- Que "quién es administrador" y "quién es superusuario" se respondan **igual en todos lados**. Hoy hay
  tres definiciones de administrador (correctivo C-5: `seg.users.role = 1`, que recibe todo el que se
  registra; el rol en la membresía; el correo `TOOLS_ADMIN_USER`) y el superusuario es un correo fijo
  en un archivo.
- Que se pueda **llegar** al Portal y a la Consola desde Tools, sin escribir la dirección.
- Que los textos y parámetros administrativos se cambien desde la Consola, con historial y sin tocar
  código (RF-102, RNF-05).
- Que quede rastro de quién hizo cada cambio, sin poder borrarlo (RF-100, RNF-04).

## Quién lo usa

- **Administrador** de una empresa: ve "🏢 Mi empresa" en la barra de Tools.
- **Superusuario**: ve "🔑 Consola" en Tools y en el Portal, y edita las variables de sistema.
- **Usuario** (no administrador): no ve ninguno de los dos botones; se usa para probar el rechazo.

## Qué tiene que hacer

1. Botones "🏢 Mi empresa" y "🔑 Consola" en la barra superior de Tools, con el servicio "Contexto del
   usuario" → **ADM-UC-030**.
2. Superusuario por marca en el usuario (no por correo), con su migración M-6 → **ADM-UC-031**.
3. Una sola definición de administrador, usada por el módulo, el Contexto y el botón → **ADM-UC-032**.
4. Editar variables de sistema, con historial y vuelta atrás (CU-22, migración M-7) → **ADM-UC-033**.
5. Auditoría de solo inserción, con las acciones de este requerimiento → **ADM-UC-034**.
6. Agregar atributos y entidades nuevas, y migrar los datos (M-1, M-2, M-5) sin que v2 note nada →
   **ADM-UC-035**.

## Qué NO hace

- **No hace las pantallas que usan las tablas nuevas.** Planes y catálogo (REQ-005), funcionalidades
  (REQ-006), usuarios y estados de membresía (REQ-007), empresas (REQ-008), menús (REQ-009), pedidos
  (REQ-010), cuota (REQ-011), "Me interesa" (REQ-012), la pantalla de auditoría (REQ-013) y el
  historial de cargas (REQ-014) llegan con sus requerimientos.
- **No carga planes ni pasa empresas a un plan** (M-3 es E12, REQ-016), ni activa funcionalidades por
  empresa (M-4 es E6, REQ-009).
- **No cambia nada en DNATO.** DNATO sigue usando `TOOLS_ADMIN_USER` y `seg.users.role` como hoy; dejar
  de usarlos es parte de la redirección final.
- **No saca `TOOLS_ADMIN_USER` de `constants.php`** (RNF-05): lo siguen leyendo DNATO y Tools.
- **No cambia `getEsAdminXEmailEmpresa` ni `getUsersXGroup`** (el `COREDataService` existente). Su
  alineación al criterio por `nombre` es la tarea B.4c del análisis, después de B.4a y B.4b.
- **De la barra de Tools solo agrega los dos botones.** No agrega el indicador de cuota (REQ-011), no
  saca "Usuarios" del menú del perfil (cuando el Portal tenga Usuarios, REQ-007), no cambia el selector
  de empresa (correctivo C-1, reunión de arquitectura) ni agrega la tarjeta del tablero (T-1).
- No toca las copias de la barra que tienen algunos submódulos (ver la duda de ADM-UC-030).
- No toca `frm.*` (formularios): sus atributos nuevos son de E11b, que va aparte (REQ-015).
- No agrega columna de número de empresa a la membresía (decisión de Rodolfo del 2026-11-04, B.4).

---

## Cómo se arma

### El script de base

Un solo script, versionado en `traz-tools` (por ejemplo
`doc/v3/administracion/sql/REQ-004-base-y-atributos.sql` **[SUPUESTO]** de ubicación), con dos partes:

1. **Estructura (M-1):** solo `ALTER TABLE … ADD COLUMN` con valor por defecto y `CREATE TABLE`. Nada
   de `DROP`, `RENAME`, cambios de tipo ni `NOT NULL` sobre columnas existentes.
2. **Datos (M-2, M-5, M-6, M-7):** solo `INSERT` y `UPDATE` de las columnas **nuevas**. Ninguna fila
   existente cambia en una columna existente.

Se corre primero en una base de prueba (copia de DEMO) y después en DEMO, nunca directo en producción.
Lleva su script de vuelta atrás (borra solo lo que agregó). La parte de estructura es **aditiva y la
decide el equipo** (regla de Rodolfo del 2026-11-10). La parte de datos que toca tablas existentes (M-2
de las herramientas del agente y M-6) la aprueba Rodolfo **antes** de construir; M-5 solo carga
una tabla nueva y M-7 solo agrega filas nuevas en `core.tablas`: esas dos lo decide el equipo (regla de Rodolfo del 2026-11-10).

### El DataService nuevo

`ADMDataService.dbs` en `_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/data-services/`,
con la misma fuente de datos que `COREDataService`. Recursos (URLs en kebab-case, claves JSON en
snake_case):

| Recurso | Qué hace |
|---|---|
| `GET /usuario/es-admin/{email}/empresa/{empr_id}` | Definición única de administrador (ver abajo) |
| `GET /usuario/es-super/{email}` | Lee la marca `superusuario` |
| `GET /variables` | Lista de variables de sistema con grupo, valor, quién y cuándo las cambió por última vez |
| `PUT /variable` | Cambia un valor: guarda historial y auditoría **en la misma operación** |
| `GET /variable/{clave}/historial` | Historial de una variable |
| `POST /auditoria` | Agrega una fila de auditoría (no hay recurso para cambiar ni borrar) |

Quién hizo el cambio sale **siempre de la sesión** (el correo), nunca del navegador. Para que historial,
valor y auditoría no queden a medias, el cambio de variable se hace con **una** función de base
(por ejemplo `seg.cambiar_variable(clave, valor, quien)`) que el recurso llama.

Se despliega como los demás DataServices. **Aviso para el despliegue:** el script de despliegue sube
los DataServices pero no las APIs; este requerimiento no agrega APIs.

### Definición única de administrador (R7 + R8)

`es_admin(email, empr_id)` es verdadero si y solo si existe en `seg.memberships_users` una fila con:

- el correo de la persona (sin distinguir mayúsculas),
- `"group"` igual al `nombre` de la empresa `empr_id` (criterio único de Rodolfo, B.4; **no** por
  `descripcion`),
- rol base Administrador (la misma condición sobre `role` que usa hoy `getEsAdminXEmailEmpresa`),
- y la membresía de esa persona en esa empresa **no** está `baneado` ni `baja` (estado nuevo; después
  de M-5 todas son `activo`).

`seg.users.role` y `TOOLS_ADMIN_USER` **no autorizan** nada en el módulo. Esta definición la usan el
controlador base del módulo (reemplaza al `/usuario/esadmin` de REQ-002), el servicio Contexto y, por
él, el botón "🏢 Mi empresa". `Dashs::esAdminEmpresa` de Tools (el aterrizaje en el tablero) **no** se
cambia en este requerimiento (ver la duda de ADM-UC-032).

### Superusuario por marca (R7, C-5, M-6)

- Columna nueva `seg.users.superusuario` (sí/no, por defecto no).
- M-6: en cada ambiente se marca al usuario cuyo correo es el `TOOLS_ADMIN_USER` **de ese ambiente**.
  El script recibe el correo como parámetro; no queda escrito en el repositorio.
- Desde este requerimiento, el módulo pregunta **solo la marca**. El correo deja de autorizar dentro del
  módulo (en DNATO y Tools sigue igual).
- Quién puede marcar o desmarcar a otros y la regla "tiene que quedar al menos uno" (CP-103) son de la
  Consola → Usuarios (REQ-008). Mientras tanto la marca solo la pone el script.

### Servicio "Contexto del usuario" (§4)

Vive **en el módulo** (por ejemplo un modelo `Contexto` en `traz-comp-adm/models/`), porque lo que
calcula son reglas del módulo. Toma correo y empresa **de la sesión** y devuelve:

| Dato | De dónde | En este requerimiento |
|---|---|---|
| `empr_id`, nombre de la empresa | Sesión y `REST_CORE/empresa/{empr_id}` (ya existe) | Sí |
| `es_admin` | `ADMDataService /usuario/es-admin/…` | Sí |
| `es_super` | `ADMDataService /usuario/es-super/…` | Sí |
| Dirección del Portal y de la Consola | `traz-comp-adm/portal`, `traz-comp-adm/consola` | Sí |
| Ícono del plan, cuota resumida, avisos | Plan (REQ-005) y cuota (REQ-011) | **No**: se agregan con esos requerimientos |

Si algo falla (servicio caído, módulo sin montar), devuelve "no es administrador, no es superusuario":
**los botones no aparecen y Tools sigue funcionando igual**. Nunca muestra un error en la barra.

### Los botones en la barra de Tools (núcleo)

- `application/controllers/Dash.php` `index()`: si el módulo está montado, pide el Contexto y lo pasa a
  la vista. Ninguna otra línea de `Dash.php` cambia.
- `application/views/layout/perfil.php`: a la izquierda del perfil, "🏢 Mi empresa" (si `es_admin`) y
  "🔑 Consola" (si `es_super`). Abren en la **misma pestaña** (maqueta). El resto de la barra queda igual.
- En el Portal, "🔑 Consola" pasa a depender de la marca (antes, del correo).
- **Análisis de impacto obligatorio**, aprobado por Rodolfo antes de construir: qué pantallas dibujan
  esa barra (Tools y las copias en submódulos), qué pasa si el módulo no está o el servicio no responde,
  cuánto agrega al tiempo de carga del tablero, y pruebas de regresión de la barra.

### Variables de sistema (CU-22, RF-102, M-7)

- Viven en `core.tablas` **sin empresa**, como las configuraciones de la interfaz (maqueta
  `consola-config.html`). El historial va en una tabla nueva (ver "Datos").
- Claves de RF-102: `texto_suspension_empresa`, `texto_suspension_miembro`, `contacto_soporte`,
  `validez_invitacion_dias`, `validez_recuperacion_horas`, `precio_plan_{codigo}`,
  `aviso_cuota_porcentaje`, `zona_horaria_cuotas`, `remitente_correo`, `monedas_permitidas`.
- M-7 las carga con los valores de hoy (ver la duda de ADM-UC-033 sobre cuáles hay).
- **Ninguna pantalla existente las lee todavía.** Cargar `validez_recuperacion_horas`, por ejemplo,
  **no** cambia la recuperación de contraseña copiada (REQ-003), que sigue igual que DNATO. Cada
  requerimiento que use una variable lo dice.

### Auditoría (RF-100, RNF-04, G5)

- Tabla nueva de solo inserción. La base **rechaza** modificar o borrar filas con el usuario de base que
  usa WSO2 (sin permiso de modificar ni borrar, y un disparador que lo impide igual).
- En este requerimiento se auditan: el cambio de una variable de sistema y la vuelta atrás. Las demás
  acciones de RF-100 las agrega cada requerimiento.
- Se guarda 5 años; no hay depuración en este requerimiento.

---

## De dónde sale cada dato

| Dato | De dónde | Cómo |
|---|---|---|
| Sesión, empresa activa, correo | Sesión de Tools | Ya existe |
| Nombre de la empresa | `REST_CORE/empresa/{empr_id}` | Ya existe |
| Es administrador | `ADMDataService GET /usuario/es-admin/{email}/empresa/{empr_id}` | **NUEVO** |
| Es superusuario | `ADMDataService GET /usuario/es-super/{email}` | **NUEVO** |
| Variables de sistema | `ADMDataService GET /variables`, `PUT /variable`, `GET /variable/{clave}/historial` | **NUEVO** |
| Auditoría | `ADMDataService POST /auditoria` (y dentro de `PUT /variable`) | **NUEVO** |

**Nada va directo a la base** (la excepción de REQ-003 no aplica acá).

---

## Pantallas

### Barra superior de Tools — `application/views/layout/perfil.php` (núcleo)

Sigue la maqueta `doc/v3/dnato/mockups/tools-barra-superior.html`, solo los botones.

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Mi empresa | "🏢 Mi empresa", solo si es administrador de la empresa activa. Lleva al Portal | `adm-tools-mi-empresa` |
| Consola | "🔑 Consola", solo si es superusuario. Lleva a la Consola | `adm-tools-consola` |

### Consola — menú lateral

Se agrega la opción "⚙️ Variables de sistema" (las demás llegan con sus pantallas). `data-testid`:
`adm-consola-menu-variables`.

### Consola → Variables de sistema — `traz-comp-adm/consola/variables`

Maqueta `doc/v3/dnato/mockups/consola-config.html`.

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Título | "Variables de sistema" y la explicación "Valen para toda la plataforma. Cada cambio guarda historial y se puede volver atrás." (la maqueta nombra la tabla; RNF-09 pide sin tecnicismos: ver duda de ADM-UC-033) | `adm-variables` |
| Tabla | Columnas Grupo, Clave, Valor (editable), Última modificación (quién · cuándo), y "Historial" por fila | `adm-variables-tabla`; cada fila `adm-variable-<clave>` |
| Guardar | "Guardar cambios" | `adm-variables-guardar` |
| Historial | Ventana "Historial · <clave>" con Fecha, Quién, Anterior, Nuevo y "Volver a <valor>" por fila | `adm-variable-historial`; botón `adm-variable-volver` |

Mensajes **[SUPUESTO]** (la maqueta no los trae; tuteo, RNF-09):

| Caso | Mensaje | `data-testid` |
|---|---|---|
| Guardado | "Guardamos los cambios." | `adm-variables-ok` |
| Sin cambios | "No hay cambios para guardar." | `adm-variables-sin-cambios` |
| Vuelta atrás | "Volvimos <clave> a <valor>." | `adm-variables-ok` |
| Falla del servicio | "No pudimos guardar. Probá de nuevo en un rato." | `adm-variables-error` |

---

## Reglas

1. Administrador = la definición única de arriba. Ninguna otra condición (`role = 1`, correo fijo)
   autoriza en el módulo ni muestra "🏢 Mi empresa".
2. Superusuario = marca en el usuario. El correo `TOOLS_ADMIN_USER` ya no autoriza en el módulo.
3. "🏢 Mi empresa" se ve solo si la persona es administradora de la **empresa activa**; al cambiar de
   empresa, el botón aparece o desaparece según la nueva.
4. "🔑 Consola" se ve solo para superusuarios, en Tools y en el Portal. Un superusuario que además
   administra la empresa activa ve los dos.
5. Si el Contexto no responde, no se ve ningún botón y Tools sigue igual.
6. Solo el superusuario ve y cambia variables de sistema.
7. Cada cambio de variable guarda el valor anterior, el nuevo, quién y cuándo; volver atrás es un cambio
   más (también queda en el historial).
8. La auditoría solo agrega filas; la base rechaza modificar o borrar.
9. El script de base solo **agrega**: ninguna fila existente cambia en una columna existente, y v2
   (Tools, DNATO, AssetPlanner, el agente) funciona igual.
10. Quién hizo el cambio sale de la sesión.

## Registro en el log

`log_message('DEBUG', '#TRAZA | ADM | <Clase> | <metodo>() ...')`. Se registran los rechazos y cada cambio
de variable (clave y quién, sin el valor si la clave es de texto largo).

---

## Datos

**Estructura: cambio de base aditivo, lo decide el equipo (regla de Rodolfo del 2026-11-10).** Todas las
columnas nuevas en tablas existentes son **optativas** (aceptan vacío o tienen valor por defecto), así
que ninguna necesita aprobación. **Carga de datos: M-2 (herramientas del agente) y M-6 tocan tablas
existentes y las aprueba Rodolfo**; M-5 solo llena una tabla nueva y M-7 solo agrega filas nuevas en
`core.tablas`: lo decide el equipo (regla de Rodolfo del 2026-11-10). Nombres de tablas y columnas
propuestos **[SUPUESTO]** (la especificación da los atributos, no los nombres); Pablo puede ajustarlos en
el plan. Todas las tablas nuevas van en el schema `seg` (regla de Rodolfo del 2026-11-10).

### Columnas nuevas en tablas existentes (M-1)

| Tabla | Columna | Qué guarda | Por defecto |
|---|---|---|---|
| `core.empresas` | `plan_id` | Plan de la empresa | nulo (M-3 la llena en REQ-016) |
| `core.empresas` | `estado`, `estado_motivo` | `activa` / `suspendida` y por qué | `activa` |
| `core.empresas` | `estado_plan`, `plan_pedido_id` | `vigente` / `pendiente` / `vencido` y el plan pedido | `vigente` |
| `core.empresas` | `plan_vence` | Fecha de vencimiento del plan | nulo |
| `core.empresas` | `uso_plan_gratuito` | Ya usó un plan gratuito o de prueba | no |
| `core.empresas` | `contacto_admin` | Correo de contacto del administrador para mensajes | nulo |
| `seg.users` | `superusuario` | Marca de superusuario | no |
| `seg.users` | `cambiar_password` | Debe cambiar la contraseña al primer ingreso | no |
| `seg.menues` | `tipo` | `pantalla` / `accion` / `tool_mcp` | `pantalla` |
| `seg.menues` | `texto_presentacion`, `ayuda` | Textos de la vista de presentación y ayuda | nulo |
| `seg.menues` | `publicacion` | `sin_publicar` / `publicada` / `despublicada` | `publicada` |

### Tablas nuevas (M-1)

| Tabla | Qué guarda (atributos de `02_MODELO_Y_REGLAS.md` §2) | La usa |
|---|---|---|
| `seg.membresias_estado` | correo, `"group"`, estado (`invitado` / `activo` / `baneado` / `baja`), motivo, fecha, quién; única por (correo, `"group"`) | REQ-004 (admin), REQ-007 |
| `seg.planes` | código, nombre, ícono, orden, tope de usuarios, cuota, período, día de renovación, base, precio, gratuito, vencimiento, activo | REQ-005 |
| `seg.planes_funcionalidades` | plan × (módulo, opción) | REQ-005 |
| `seg.empresas_funcionalidades` | empresa × (módulo, opción) × activa × orden | REQ-006 |
| `seg.menus_custom`, `seg.menus_custom_items` | menú de empresa; grupos y opciones con etiqueta y orden | REQ-009 |
| `seg.menus_asignaciones` | menú × rol o menú × membresía, fecha | REQ-009 |
| `seg.cuota_periodos` | empresa, inicio, fin, cuota, bonificación, consumidas, avisos enviados; único por empresa e inicio | REQ-011 |
| `seg.consumos_mcp` | empresa, usuario, herramienta, fecha, resultado | REQ-011 |
| `seg.pedidos_plan` | empresa, plan actual, plan pedido, motivo, estado, quién y cuándo pidió y resolvió | REQ-010 |
| `seg.intereses` | empresa, usuario, funcionalidad, fecha | REQ-012 |
| `seg.eventos_registro` | fecha, tipo, empresa, administrador, plan, origen, aprobación, canal, resultado, reintentos | REQ-008 |
| `seg.cargas_resultados` | empresa, usuario, entidad, fecha, filas bien y con error, detalle | REQ-014 |
| `seg.auditoria` | fecha, quién, empresa, acción, entidad, identificador, detalle. **Solo inserción** | REQ-004 y siguientes |
| `seg.variables_historial` | clave, valor anterior, valor nuevo, quién, fecha | REQ-004 |

Más la función `seg.cambiar_variable(…)` y el disparador que impide modificar o borrar `seg.auditoria`.

### Carga de datos

| Paso | Qué hace |
|---|---|
| M-2 | Toda opción actual de `seg.menues` queda `publicada`, tipo `pantalla` (ya lo dan los valores por defecto). Las opciones del módulo `MCP` (herramientas del agente) se cargan como tipo `tool_mcp` (ver duda en ADM-UC-035) |
| M-5 | Una fila `activo` en `seg.membresias_estado` por cada (correo, `"group"`) que exista. Se **listan** para Rodolfo las membresías cuyo `"group"` no coincide con ningún `nombre` de empresa (la medición de B.4) |
| M-6 | Marca `superusuario` al usuario con el correo `TOOLS_ADMIN_USER` del ambiente |
| M-7 | Filas de las variables de RF-102 en `core.tablas` sin empresa, con sus valores de hoy |

---

## Decisiones tomadas

- **D-07 de la especificación:** superusuario = marca en el usuario; administrador = rol Administrador en
  la empresa activa. Cierra las tres definiciones que conviven hoy (C-5).
- **Criterio membresía → empresa por `nombre`** (Rodolfo, 2026-11-04, B.4), sin columna de número de
  empresa en la membresía. Por eso M-5 no "guarda `empr_id`" como dice la especificación: solo carga el
  estado y lista las que no resuelven.
- **DataService nuevo, no modificar `COREDataService`**: los recursos existentes los consume v2;
  agregarlos aparte no los toca (compatibilidad v2). Modificar uno existente sería núcleo.
- **El Contexto vive en el módulo** y la barra de Tools solo lo llama: la regla queda en un solo lugar
  (lógica de negocio fuera de los controladores de Tools).
- **Si el Contexto falla, Tools sigue igual**: la barra es de todas las pantallas de producción.
- **Un solo script para todas las entidades de E1**: la base queda lista para REQ-005 en adelante, en
  vez de un cambio por requerimiento (ver la duda de ADM-UC-035).
- **Cambios de base aditivos los decide el equipo** (Rodolfo, 2026-11-10): tablas nuevas, columnas
  optativas, índices y funciones nuevas no necesitan su aprobación. Sí la necesitan cambiar o borrar algo
  existente, columnas obligatorias sin valor por defecto y cargas que cambian filas existentes.
- **Todas las tablas nuevas van en `seg`** (Rodolfo, 2026-11-10), como las actuales del módulo.
- **Las variables se cargan pero nadie las lee todavía**: así el ingreso copiado (REQ-003) no cambia
  y cada requerimiento que use una lo hace explícito.

## Cómo se revisa (además de DocTest)

- El script de base corrido en una copia de DEMO y con su vuelta atrás probada; la carga de M-2 (herramientas
  del agente) y M-6 aprobada por Rodolfo antes de correrla (M-7 lo decide el equipo (regla de Rodolfo del 2026-11-10)).
- **Búsqueda de usos de las tablas tocadas** (`core.empresas`, `seg.users`, `seg.menues`, `core.tablas`)
  en DataServices, funciones, disparadores, DNATO, Tools y AssetPlanner: ningún `INSERT` sin lista de
  columnas ni `SELECT *` que se rompa con columnas nuevas. El resultado va en la descripción del pull
  request.
- Análisis de impacto de la barra de Tools aprobado por Rodolfo.
- DocTest `regresion` en verde, y DNATO-UC-001 a 008 en verde (el ingreso no cambió).
- El menú de Tools de un usuario de prueba es el mismo antes y después de M-2.
- `phpcs` con PHPCompatibility para PHP 5.6 sin errores; `./mvnw clean install` del proyecto de APIs.

## Dudas abiertas

Están en los casos de uso (campo `dudas`), para contestarlas en un solo lugar.

---

## Casos de prueba de la especificación que cubre

| CP | Qué prueba | Lo cubre |
|---|---|---|
| CP-101 | Auditoría inmutable | ADM-UC-034 |
| CP-102 | Variables con historial y vuelta atrás | ADM-UC-033 |
| CP-108 | La Consola solo la ve y la abre el superusuario; marca y logo en el Portal | ADM-UC-030 y ADM-UC-031 (botón en Tools y en el Portal, por marca). El logo de la empresa en el Portal: fuera de alcance (REQ-002 muestra la inicial; el logo llega con la ficha de empresa, REQ-008) |
| CP-106 | Inicio del Portal y acceso desde Tools | En parte: ADM-UC-030 ("🏢 Mi empresa" para el administrador y no para el usuario). El indicador de cuota (REQ-011), el menú del perfil sin "Usuarios" (REQ-007) y las tarjetas de Inicio (REQ-013): fuera de alcance |
| CP-103 | No se desmarca el último superusuario; ban global | Fuera de alcance: Consola → Usuarios (REQ-008). Acá solo se crea la marca |
| CP-110, CP-111, CP-112 | Correctivos de acceso | Ya cubiertos por REQ-002 (ADM-UC-001 a 003) |
| CP-01, CP-02, CP-06 | Ingreso y recuperación siguen en verde | REQ-003 (DNATO-UC-006 y 008 contra la copia); acá solo se verifica que sigan en verde |
