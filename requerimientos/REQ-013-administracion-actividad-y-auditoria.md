# REQ-013 · Módulo Administración — Actividad, auditoría e inicio del Portal, y el tablero del administrador en Tools

## Objetivo

Decimotercer trabajo de Pablo para el módulo **Administración** (`traz-comp-adm`): la pantalla
**Auditoría y uso** de la Consola (quién hizo qué, y cuánto se usa la plataforma), la **Actividad** de la
empresa en el Portal, el contenido del **Inicio** del Portal (que REQ-002 dejó vacío) con sus avisos, el
**registro de accesos por empresa** y las mejoras al **tablero del Administrador de Tools** (punto T-1).
Lo leen Pablo para planificar y Rodolfo para aprobar el análisis de impacto en Tools.
**No** cubre los indicadores de operación del tablero (KPI y su caché, que no cambian), las cargas
masivas ([REQ-014](REQ-014-administracion-cargas-masivas.md)) ni el registro de qué opción del menú usa
cada persona. Lista completa en [`README.md`](README.md).

| Campo | Valor |
|---|---|
| Estado | **Borrador**: Rodolfo tiene que contestar las dudas de los casos, y aprobar el análisis de impacto en Tools |
| Se apoya en | [REQ-002](REQ-002-administracion-esqueleto.md) (controlador base, Portal, Consola, Inicio vacío), [REQ-004](REQ-004-administracion-base-y-atributos.md) (`seg.auditoria`, servicio Contexto, `Dash::index` con Contexto), [REQ-005](REQ-005-administracion-catalogo-y-planes.md) (acciones `plan.*` y aviso de restricción), [REQ-006](REQ-006-administracion-funcionalidades.md) (funcionalidades activas, ícono del plan), [REQ-007](REQ-007-administracion-usuarios-roles-perfil.md) (personas, lugares, invitaciones, "Último acceso"), [REQ-008](REQ-008-administracion-consola-empresas.md) (ficha, Usuarios de la plataforma, "📜 Ver actividad"), [REQ-010](REQ-010-administracion-plan-y-pedidos.md) (plan y pedido pendiente) y [REQ-011](REQ-011-administracion-cuota-agente.md) (cuota en el Contexto) |
| Entrega de la especificación | **E10** de `doc/v3/dnato/PROMPT_CLI_DNATO_V3_BUILD.md`: auditoría y uso en la Consola, Actividad en el Portal, Inicio del Portal (control, sin KPIs). CU-19, CU-30; CP-100, CP-104, CP-106. **Más T-1** de `doc/v3/dnato/02_MODELO_Y_REGLAS.md` §9b y `doc/v3/administracion/ANALISIS_INICIAL.md` E.1, por decisión de Rodolfo |
| Casos de uso | `ADM-UC-210` a `ADM-UC-218` en `doctest/catalogo/adm/` |
| Repos que se tocan | `traz-comp-adm` (Auditoría y uso, Actividad, Inicio, ampliación del Contexto); `traz-tools`: recursos **nuevos** en `ADMDataService.dbs`, un script de base chico, y del núcleo `application/controllers/Dash.php` y `application/views/dashboard/admin_dashboard.php` |
| Riesgo | 🔴 La tabla nueva `seg.accesos` y los índices nuevos en `seg.auditoria` (lista en "Datos") son **cambio de base aditivo: lo decide el equipo (regla de Rodolfo del 2026-11-10)**. Sigue en rojo solo por el **núcleo de Tools**: el tablero del Administrador (`Dash.php`, `admin_dashboard.php`) y el registro del acceso en `Dash::index` → **análisis de impacto aprobado por Rodolfo** (sección "Análisis de impacto en Tools"). Recursos del DataService nuevos (🟡) |

---

## Para qué sirve

- Hoy no hay forma de saber **quién hizo qué** en la administración de una empresa (RF-100: "no existe").
  REQ-004 a REQ-012 ya guardan cada cambio en `seg.auditoria`; falta poder **verlo**, filtrarlo y
  exportarlo.
- El superusuario no sabe **cuánto se usa** la plataforma por empresa (RF-101: hoy solo `last_login`,
  que es de la persona en toda la plataforma, no por empresa).
- El administrador entra al Portal y no ve nada (REQ-002 dejó el Inicio vacío). Necesita ver de un
  vistazo su plan, sus lugares, su cuota de IA y lo que **requiere su atención**.
- El tablero que el administrador ve al entrar a Tools (versión 2.5) muestra datos fijos: suscripción
  "Freemium" para todos, módulos MAN/ALM/HER para todos y una línea de tiempo de relleno (supuestos A5,
  A6 y A7 de `doc/analisis/dashboard-administrador-landing.md` §8). Con el módulo, esos datos existen.

## Quién lo usa

- **Superusuario**: Consola → Auditoría y uso.
- **Administrador** de una empresa: Inicio y Actividad del Portal; la tarjeta de plan y uso en el tablero
  de Tools.
- **Usuario** (no administrador): no ve nada nuevo; se usa para probar el rechazo.

## Qué tiene que hacer

1. Consola → Auditoría: filtrar por empresa, acción, persona y fecha; exportar; llegar filtrado desde
   "📜 Ver actividad" y desde la ficha de la empresa (CU-19, RF-100) → **ADM-UC-210**.
2. Comprobar que cada acción de RF-100 deja su fila y que el consumo de IA no (CP-100) → **ADM-UC-211**.
3. Consola → Uso de la plataforma por empresa y por mes (RF-101) → **ADM-UC-212**.
4. Registrar los accesos por empresa y mostrar "Último acceso" en esta empresa (lo que REQ-007 dejó para
   acá) → **ADM-UC-213**.
5. Portal → Actividad de la empresa, en lenguaje de usuario (CU-30, CU-19) → **ADM-UC-214**.
6. Portal → Inicio: tres tarjetas, pedido pendiente y accesos (CU-30, CP-106) → **ADM-UC-215**.
7. Avisos del Inicio derivados de la actividad de los últimos 30 días (CP-104; los avisos que dejaron
   REQ-005, REQ-006 y REQ-010) → **ADM-UC-216**.
8. Tablero de Tools: tarjeta resumida de plan y uso para administradores (T-1 a) → **ADM-UC-217**.
9. Tablero de Tools: plan, funcionalidades y actividad reales en vez de los datos fijos, y el tablero
   igual que hoy si el servicio no responde (T-1 b) → **ADM-UC-218**.

## Qué NO hace

- **No cambia los indicadores de operación del tablero** (sector B: cajas de KPI, `kpi.cache`,
  `ToolsKPIDataService`, el refresco por cron, `Dash::kpi`, `Dash::kpiMan`, el orden de las cajas).
- **No cambia a quién aterriza en el tablero.** Sigue decidiéndolo `Dashs::esAdminEmpresa()`
  (`application/models/Dashs.php:104`); alinearlo con la definición única de REQ-004 es la duda abierta
  de ADM-UC-032.
- **No pone pantallas de configuración del tablero** (supuesto A8 de `dashboard-administrador-landing.md`
  §4): `application/config/dashboard.php` queda como está y se usa como respaldo.
- **No registra qué opción del menú usa cada persona.** Por eso la columna "Más usado" de Uso de la
  plataforma no se llena en este requerimiento (ver la duda de ADM-UC-212).
- **No permite cambiar ni borrar la auditoría** (RNF-04, G5): todas las pantallas son de solo lectura.
  Tampoco depura lo que tenga más de 5 años (duda de REQ-004, ADM-UC-034).
- **No mete el consumo de IA en la auditoría** (RF-100, RF-82): el consumo sigue en `seg.consumos_mcp`
  (REQ-011) y se ve en Uso de IA y en la columna "IA" de Uso de la plataforma.
- **No agrega acciones nuevas a la auditoría**: muestra las que escriben REQ-004 a REQ-012. Las de
  cargas masivas (REQ-014) y formularios (REQ-015) aparecen solas cuando esos requerimientos las escriban.
- No cambia el indicador de cuota de la barra (REQ-011) ni los botones de la barra (REQ-004).
- No toca las copias del tablero o de la barra que tengan los submódulos.

---

## Cómo se arma

### Consola → Auditoría (CU-19, RF-100)

- Lee `seg.auditoria` (REQ-004: fecha, quién, empresa, acción, entidad, identificador, detalle) por un
  recurso **nuevo**, paginado en el servidor (RNF-12: menos de 2 s), del más nuevo al más viejo.
- **Filtros** (todos en el servidor): empresa ("Todas las empresas" o una), grupo de acción ("Todas las
  acciones" o el prefijo: `plan.*`, `catalogo.*`, `empresa.*`, `registro.*`, `pedido.*`, `miembro.*`,
  `rol.*`, `menu.*`, `funcionalidad.*`, `cuota.*`, `superusuario.*`, `usuario.*`, `perfil.*` y las de
  variables de REQ-004), persona ("🔍 usuario", parte del correo) y rango de fechas **[SUPUESTO]** (la
  maqueta no trae fechas; RF-100 pide filtrar por fecha).
- **Columnas** (maqueta `consola-auditoria.html`): Fecha (dd/mm hh:mm:ss, hora de la zona
  `zona_horaria_cuotas`), Quién (correo), Empresa (nombre o "—" si la acción no es de una empresa, por
  ejemplo un cambio de plan), Acción (el código), Entidad (tipo e identificador), Detalle (resumen del
  JSON de detalle: valor anterior → nuevo, motivo entre comillas).
- **Pie**: "<N> registros · solo lectura, se conservan 5 años · el consumo de IA no está acá (tiene su
  propio registro)".
- **Exportar** ("⬇ CSV"): el listado con los filtros puestos, generado en el servidor, como las
  exportaciones de REQ-008.
- **Llegar filtrado**:
  - "📜 Ver actividad" de Usuarios de la plataforma (REQ-008) abre Auditoría con el filtro de la persona
    (ver la duda de ADM-UC-210 sobre qué filas entran). REQ-008 dejó el botón oculto hasta este
    requerimiento: **acá aparece**.
  - La pestaña "Actividad" de la ficha de la empresa (REQ-008) abre Auditoría con el filtro de la
    empresa. El "Historial de planes" de la ficha sigue con su recurso de REQ-008.

### Consola → Uso de la plataforma (RF-101)

Segunda pestaña ("Uso") de la misma pantalla. Una fila por empresa (no dadas de baja) para el mes
elegido (por defecto el actual):

| Columna | De dónde |
|---|---|
| Empresa, Plan (ícono, nombre, "(prueba)" si es gratuito o de prueba) | `core.empresas`, `seg.planes` |
| Usuarios activos | Personas distintas con al menos un acceso a esa empresa en el mes (`seg.accesos`, ver abajo) **[SUPUESTO]** |
| Accesos | Cantidad de accesos a esa empresa en el mes (`seg.accesos`) |
| IA usadas / cuota | Consultas `ok` del período en curso / cuota + bonificación ("(semana)" si el plan es semanal), de `seg.cuota_periodos` (REQ-011) |
| Más usado | **No se llena** en este requerimiento: no hay registro por opción (ver duda de ADM-UC-212) |

Ordenado por accesos, de mayor a menor **[SUPUESTO]**. Exportable con "⬇ CSV".

### Registro de accesos por empresa (RF-101; "Último acceso" de REQ-007)

- Tabla nueva `seg.accesos`: correo, empresa (`empr_id`), fecha. Una fila **por sesión y por empresa**:
  cuando la persona entra a Tools con una empresa activa, y cada vez que cambia de empresa.
- **Dónde se escribe:** en `Dash::index()` de Tools (núcleo), que ya es el único lugar por donde pasa
  toda persona después del ingreso (DNATO y el ingreso copiado de REQ-003 terminan ahí) y después de
  cambiar de empresa (`perfil.php:159` recarga la página tras `Dash::cambiarDeEmpresa`). `Dash::index`
  ya llama al Contexto desde REQ-004; se agrega **una** llamada al recurso nuevo `POST /acceso`, solo si
  en la sesión no está marcada esa empresa como ya registrada (para que recargar la página no sume
  accesos).
- **Si el recurso falla**, no pasa nada visible: no se registra ese acceso y Tools sigue igual.
- **"Último acceso" en Usuarios del Portal** (REQ-007): pasa a ser el último acceso **a esta empresa**
  (de `seg.accesos`). Si la persona no tiene ninguno todavía (accesos anteriores a este requerimiento),
  se muestra `seg.users.last_login` como hasta ahora, para que nadie aparezca como "nunca"
  **[SUPUESTO]**. En **Usuarios de la plataforma** (Consola, REQ-008) sigue siendo `last_login`, porque
  ahí es de toda la plataforma.
- El agente de IA no cuenta como acceso: lo suyo está en `seg.consumos_mcp`.

### Portal → Actividad de la empresa

- **Misma auditoría**, filtrada por la empresa de la **sesión** (nunca del navegador), con los textos en
  lenguaje de usuario (maqueta `empresa-auditoria.html`). Columnas: Fecha (dd/mm hh:mm), Quién (nombre
  de la persona; **"Trazalog"** si la hizo un superusuario, como en la maqueta), Qué hizo.
- **Qué filas entran**: las de `seg.auditoria` con la empresa de la sesión, más las restricciones del
  **plan que la empresa tiene hoy** (`plan.funcionalidad.quitar` y `plan.editar` que bajan tope o cuota),
  que se guardan sin empresa (ver la duda de ADM-UC-214). No entran `perfil.password` ni las acciones
  de variables o de catálogo **[SUPUESTO]**.
- **Filtros** (maqueta): "Todas las acciones", "Usuarios" (`miembro.*`, `rol.*`), "Menús" (`menu.*`),
  "Plan" (`plan.*`, `pedido.*`, `empresa.cambiar_plan`, `empresa.vencimiento`, `empresa.vencer_plan`,
  `cuota.bonificar`), "Funcionalidades" (`funcionalidad.*`).
- **Textos**: cada acción tiene una frase en el módulo (por ejemplo `miembro.invitar` → "Invitó a <nombre>
  como <rol>", `miembro.banear` → "Baneó a <nombre> · "<motivo>"", `menu.asignar` → "Asignó el menú
  <menú> al rol <rol>", `funcionalidad.interes` → "Marcó "Me interesa" en <funcionalidad> (plan <plan>)",
  `plan.funcionalidad.quitar` → "Quitó <funcionalidad> del plan <plan>"; las de la maqueta salen de ahí,
  las demás **[SUPUESTO]**). Una acción sin frase se muestra con su código, nunca vacía.
- Pie: "Solo lectura · <N> registros en <mes>". Exportar "⬇ CSV" con los mismos textos.

### Portal → Inicio (CU-30)

Pantalla de **control**, no de indicadores (maqueta `inicio-admin.html`). Regla de construcción de la
especificación: se compara con lo que ya muestra el tablero de Tools y se suma **solo lo nuevo**; nada de
KPIs de operación.

- **Encabezado**: "Hola, <nombre>" (ya está de REQ-002) y "Lo que tenés que controlar de <empresa>. Los
  indicadores de operación (KPIs) siguen en el tablero de Tools." Botones "📊 Tablero de Tools" (vuelve
  al tablero) y "👥 Invitar usuario" (abre Usuarios con el formulario de invitar de REQ-007).
- **Tres tarjetas**:
  - **Plan**: "<ícono> <plan>", "<tope> usuarios · <cuota> consultas de IA por <semana / mes>" y "Ver
    planes →" (abre Plan, REQ-010). Con pedido pendiente, debajo: "⏳ Pediste pasar al plan <plan>"
    (texto de REQ-010) **[SUPUESTO]** de ubicación.
  - **Lugares del plan**: "<usados> de <tope>" y debajo "Tope alcanzado" o "Te quedan <K>", más
    "· <N> invitación(es) sin aceptar" si hay (R4, recurso de REQ-007).
  - **Consultas de IA esta semana** (o "este mes"): "<consumidas> de <total>" y "Se renueva el <día>
    <fecha> 00:00" (REQ-011). Ilimitado: "<consumidas> · sin tope". Sin IA: "Tu plan no incluye IA".
- **Requiere tu atención**: los avisos (ver abajo), y al pie "Nada más por ahora. Los avisos salen de la
  actividad de los últimos 30 días." Sin avisos: "No hay nada que requiera tu atención." **[SUPUESTO]**.
- **Accesos**: "👥 Usuarios y accesos", "🗂️ Menús por rol o persona", "🧩 Funcionalidades activas",
  "🗂️ Cargas masivas" (solo cuando exista REQ-014) y "📜 Actividad de la empresa".
- **Empresa sin plan** (todas hasta M-3, REQ-016): la tarjeta Plan dice "Tu empresa todavía no tiene un
  plan asignado" (la misma propuesta de ADM-UC-150), Lugares "<usados> · sin tope" e IA como ilimitado
  (propuesta de ADM-UC-170).

### Avisos (CP-104, CU-30, T-1)

Un solo cálculo en el módulo (en el Contexto ampliado, ver abajo), que usan el Inicio y el tablero:

| Aviso | De dónde sale | Texto | Acción |
|---|---|---|---|
| Funcionalidad quitada del plan (RF-16) | `plan.funcionalidad.quitar` del plan actual de la empresa, últimos 30 días | "⚠️ Se quitó "<funcionalidad>" del plan <plan>" · "Pasó a mostrarse sombreada en el menú de tus usuarios (<fecha>)." | "Ver funcionalidades" |
| Tope o cuota bajados del plan (RF-16) | `plan.editar` restrictivo del plan actual, últimos 30 días | "⚠️ El plan <plan> ahora permite <M> usuarios" / "<M> consultas de IA por <período>" **[SUPUESTO]** | "Ver plan" |
| Invitación sin aceptar | Membresía `invitado` (REQ-007) cuya `miembro.invitar` o `miembro.reenviar` es de los últimos 30 días | "✉️ <nombre> todavía no aceptó la invitación" · "Enviada el <fecha>, vence el <fecha>." (o "venció el <fecha>.") | "Reenviar" (el de REQ-007) |
| Cuota agotada | Período en curso con consumidas ≥ cuota + bonificación (REQ-011) | "🤖 Tu empresa usó las <N> consultas de IA de esta <semana / este mes>" · "Se renueva el <día> <fecha> 00:00." **[SUPUESTO]** | "Ver uso de IA" |
| Vencimiento próximo (T-1) | Plan gratuito / de prueba con `plan_vence` en 7 días o menos (los mismos 7 del aviso de REQ-008) | "⏳ Tu plan <plan> vence el <fecha>" **[SUPUESTO]** | "Ver planes" |
| Plan vencido (T-1) | `estado_plan = vencido` (REQ-008) | "El período de prueba de tu empresa terminó" (texto de R5) | "Ver planes" |
| Tope alcanzado (T-1) | Lugares usados ≥ tope (R4) | "Llegaste al tope de <M> usuarios de tu plan" **[SUPUESTO]** | "Ver planes" |

Los avisos no se descartan a mano: desaparecen solos cuando pasan los 30 días o cuando se resuelve lo que
los generó (la invitación se aceptó, la cuota se renovó) **[SUPUESTO]**. Orden: primero plan vencido,
después lo demás del más nuevo al más viejo **[SUPUESTO]**. En el Inicio, "Tope alcanzado" no se repite
como aviso porque ya lo dice la tarjeta Lugares (ver la duda de ADM-UC-216).

### Contexto ampliado (REQ-004 §4)

El servicio Contexto del módulo ya devuelve empresa, `es_admin`, `es_super`, direcciones, ícono del plan
(REQ-006) y `cuota` (REQ-011). Acá suma, **solo para administradores** y **solo cuando se lo pide en
modo completo** (Inicio y tablero; la barra de Tools sigue pidiendo el modo liviano de siempre):

- `plan`: código, nombre, ícono, gratuito, `estado_plan`, `plan_vence` (o "sin plan").
- `lugares`: usados, tope (o sin tope), invitaciones sin aceptar.
- `pedido`: plan pedido y fecha, si hay uno `pendiente` (REQ-010).
- `avisos`: la lista de arriba, cada uno con tipo, texto, fecha y dirección de su acción.

Para no sumar cuatro llamadas, plan, lugares, pedido y cuota se leen con **un** recurso nuevo
`GET /empresa/{empr_id}/resumen`; las restricciones del plan y las invitaciones, con
`GET /empresa/{empr_id}/avisos`. Si algo falla, el Contexto devuelve lo que pudo y **sin** `plan` ni
`avisos`; quien lo usa decide qué mostrar (el tablero, como hoy).

### Tablero del Administrador de Tools (T-1) — núcleo

Hoy (rama `develop`, versión 2.5) `Dash::dashboard()` (`application/controllers/Dash.php:57-97`) arma el
sector "Suscripción" con datos fijos y la vista `application/views/dashboard/admin_dashboard.php` los
dibuja. Cambia así:

| Hoy | Con este requerimiento | Si el Contexto no responde |
|---|---|---|
| — | **Tarjeta "Tu plan y uso"** nueva, a todo el ancho, debajo del saludo y la empresa **[SUPUESTO]** de ubicación: "<ícono> <plan>"; "Lugares <usados> de <tope>"; "IA <consumidas> de <total> esta semana" con barra y "Se renueva el <día> <fecha>"; "⏳ Pedido pendiente: <plan>" si hay; los avisos críticos (vencimiento próximo, plan vencido, tope alcanzado) y "Ir a Mi empresa →" (abre el Portal) | No aparece |
| A5: `tipo_suscripcion = 'Freemium'` fijo (`Dash.php:88`; el umbral `dashboard_freemium_desde` de `config/dashboard.php:29` ni se usa) | La píldora de la empresa y la caja "Suscripción" muestran el **plan real** ("<ícono> <plan>"); sin plan (hasta M-3), "Sin plan asignado" **[SUPUESTO]** | "Freemium", como hoy |
| A6: módulos fijos MAN/ALM/HER (`config/dashboard.php:32-36`, `Dash.php:89`) | "Módulos habilitados" = los módulos con al menos una funcionalidad **activa** de la empresa (REQ-006), cada uno con "<N> activas" **[SUPUESTO]**; colores de la configuración, gris si el módulo no está ahí | Los tres fijos, como hoy |
| A7: línea de tiempo fija (`config/dashboard.php:39-43`, `Dash.php:90`). **Verificado: la vista no la dibuja** (tiene el estilo `.tz-timeline` en las líneas 60-62, pero ningún elemento que lo use) | "Últimos movimientos de tu cuenta": las 5 últimas filas de la Actividad de la empresa, con los mismos textos, y "Ver toda la actividad →" | No se dibuja, como hoy |
| "Usuarios generados" (A4) y los KPI | Sin cambios | Sin cambios |

- Para **no administradores** nada cambia: no aterrizan en el tablero (`Dash.php:31`) y, si alguno
  llega a `Dash/dashboard` por la dirección (hoy solo se verifica la sesión, `Dash.php:59-62`), la
  tarjeta no aparece porque el Contexto dice `es_admin = no` y el resto se ve como hoy.
- La tarjeta **no se refresca sola**: se dibuja una vez con el tablero (ver "Análisis de impacto").

---

## De dónde sale cada dato

| Dato | De dónde | Cómo |
|---|---|---|
| Es superusuario / administrador | `ADMDataService GET /usuario/es-super/…`, `GET /usuario/es-admin/…` | Ya existe (REQ-004) |
| Auditoría con filtros, paginada | `ADMDataService GET /consola/auditoria` (empresa, grupo de acción, persona, desde, hasta, página) | **NUEVO** |
| Exportar auditoría | El mismo recurso sin paginar (el módulo arma el CSV) | **NUEVO** |
| Actividad de la empresa (con las restricciones de su plan) | `ADMDataService GET /empresa/{empr_id}/actividad` (grupo, página; con `limite` para el tablero) | **NUEVO** |
| Uso de la plataforma por empresa y mes | `ADMDataService GET /consola/uso/{anio_mes}` | **NUEVO** |
| Registrar un acceso | `ADMDataService POST /acceso` | **NUEVO** |
| Último acceso a la empresa por persona | `ADMDataService GET /empresa/{empr_id}/personas` | Existe (REQ-007); **se amplía** con la columna |
| Plan, lugares, pedido pendiente y cuota en una llamada | `ADMDataService GET /empresa/{empr_id}/resumen` | **NUEVO** (junta lo de `/plan`, `/lugares`, `/pedido-pendiente` y `/cuota` de REQ-006, 007, 010 y 011) |
| Restricciones del plan e invitaciones sin aceptar de los últimos 30 días | `ADMDataService GET /empresa/{empr_id}/avisos` | **NUEVO** |
| Funcionalidades activas (tablero) | `ADMDataService GET /empresa/{empr_id}/funcionalidades` | Ya existe (REQ-006) |
| Reenviar invitación (aviso) | Modelo `Membresias` de REQ-007 | Ya existe (REQ-007) |
| Nombres de empresas, planes, personas para los textos | Dentro de los recursos nuevos (`core.empresas`, `seg.planes`, `seg.users`) | — |
| Zona horaria de las fechas | Variable `zona_horaria_cuotas` | Ya existe (REQ-004) |

**Nada va directo a la base.** Los recursos del Portal toman la empresa de la sesión; los de la Consola
verifican que la empresa exista. Ningún recurso cambia ni borra filas de `seg.auditoria`.

---

## Pantallas

### Consola — menú lateral

Se agrega "📜 Auditoría y uso". `data-testid`: `adm-consola-menu-auditoria`.

### Consola → Auditoría y uso — `traz-comp-adm/consola/auditoria`

Maqueta `doc/v3/dnato/mockups/consola-auditoria.html`.

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Título | "Auditoría y uso" y "Quién hizo qué y cuándo; cuánto se usa la plataforma." | `adm-auditoria` |
| Exportar | "⬇ CSV" (de la pestaña abierta) | `adm-auditoria-exportar` |
| Pestañas | "Auditoría", "Uso" | `adm-auditoria-tab-auditoria`, `adm-auditoria-tab-uso` |
| Filtros | Empresa ("Todas las empresas"), acción ("Todas las acciones", "plan.*", "miembro.*", …), "🔍 usuario", Desde / Hasta **[SUPUESTO]** | `adm-auditoria-filtro-empresa`, `adm-auditoria-filtro-accion`, `adm-auditoria-filtro-persona`, `adm-auditoria-filtro-desde`, `adm-auditoria-filtro-hasta` |
| Llegaste filtrado | "Llegaste desde <persona / empresa> · Quitar filtro" **[SUPUESTO]** | `adm-auditoria-llegaste` |
| Tabla | Fecha, Quién, Empresa, Acción, Entidad, Detalle | `adm-auditoria-tabla`; fila `adm-auditoria-fila` |
| Pie | "<N> registros · solo lectura, se conservan 5 años · el consumo de IA no está acá (tiene su propio registro)" y paginado | `adm-auditoria-pie`, `adm-auditoria-paginas` |
| Uso | "Uso por empresa · <mes> <año>", selector de mes **[SUPUESTO]**; columnas Empresa, Plan, Usuarios activos, Accesos, IA usadas / cuota, Más usado | `adm-uso`; `adm-uso-mes`; `adm-uso-tabla`; fila `adm-uso-<empr_id>` |

Mensajes **[SUPUESTO]**:

| Caso | Mensaje | `data-testid` |
|---|---|---|
| Sin resultados | "No hay registros con esos filtros." | `adm-auditoria-vacio` |
| Falla del servicio | "No pudimos cargar la auditoría. Probá de nuevo en un rato." | `adm-auditoria-error` |
| Fechas al revés | "La fecha 'Desde' tiene que ser anterior a 'Hasta'." | `adm-auditoria-error` |

### Cambios en pantallas de REQ-008

| Elemento | Qué cambia | `data-testid` |
|---|---|---|
| Usuarios de la plataforma, "📜 Ver actividad" | Aparece; abre Auditoría con la persona filtrada | `adm-persona-ver-actividad` |
| Ficha de la empresa, pestaña "Actividad" | Aparece; abre Auditoría con la empresa filtrada | `adm-ficha-actividad` |

### Portal — menú lateral

Se agrega "📜 Actividad" bajo "Datos". `data-testid`: `adm-portal-menu-actividad`. "🏠 Inicio" ya
existe (REQ-002).

### Portal → Actividad — `traz-comp-adm/portal/actividad`

Maqueta `doc/v3/dnato/mockups/empresa-auditoria.html`.

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Título | "Actividad", "Quién hizo qué en <empresa>: usuarios, menús, plan, IA. Es la auditoría de la plataforma filtrada por tu empresa." y "⬇ CSV" | `adm-actividad`; `adm-actividad-exportar` |
| Filtros | "Todas las acciones", "Usuarios", "Menús", "Plan", "Funcionalidades" | `adm-actividad-filtro-<filtro>` |
| Tabla | Fecha, Quién, Qué hizo | `adm-actividad-tabla`; fila `adm-actividad-fila` |
| Pie | "Solo lectura · <N> registros en <mes>" y paginado | `adm-actividad-pie` |

Mensajes **[SUPUESTO]**: sin filas "Todavía no hay actividad registrada." (`adm-actividad-vacio`); falla
"No pudimos cargar la actividad. Probá de nuevo en un rato." (`adm-actividad-error`).

### Portal → Inicio — `traz-comp-adm/portal`

Maqueta `doc/v3/dnato/mockups/inicio-admin.html`, dentro del marco de REQ-002.

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Explicación | "Lo que tenés que controlar de <empresa>. Los indicadores de operación (KPIs) siguen en el tablero de Tools." | `adm-inicio` |
| Botones | "📊 Tablero de Tools", "👥 Invitar usuario" | `adm-inicio-tablero`, `adm-inicio-invitar` |
| Tarjeta Plan | Ícono, nombre, tope y cuota, "Ver planes →", pedido pendiente | `adm-inicio-plan`; `adm-inicio-ver-planes`; `adm-inicio-pedido` |
| Tarjeta Lugares | "<usados> de <tope>", "Tope alcanzado" / "Te quedan <K>", invitaciones sin aceptar | `adm-inicio-lugares` |
| Tarjeta IA | "<consumidas> de <total>", renovación | `adm-inicio-ia` |
| Avisos | "Requiere tu atención", un renglón por aviso con su acción, y el pie | `adm-inicio-avisos`; cada aviso `adm-inicio-aviso` (con `data-tipo` = `funcionalidad_quitada`, `plan_restringido`, `invitacion`, `cuota_agotada`, `vence_pronto`, `plan_vencido`); acción `adm-inicio-aviso-accion` |
| Accesos | Los cinco accesos | `adm-inicio-accesos`; cada uno `adm-inicio-acceso-<seccion>` |

Si el resumen no responde, las tarjetas dicen "—" y el aviso "No pudimos cargar los datos de tu plan.
Probá de nuevo en un rato." (`adm-inicio-error`) **[SUPUESTO]**; los accesos se ven igual.

### Tools → tablero del Administrador — `Dash/dashboard` (núcleo)

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Tarjeta de plan y uso | Ver "Tablero del Administrador de Tools" arriba | `adm-tablero-plan` |
| Plan | "<ícono> <plan>" | `adm-tablero-plan-nombre` |
| Lugares | "Lugares <usados> de <tope>" | `adm-tablero-lugares` |
| IA | "IA <consumidas> de <total> <esta semana / este mes>", barra, renovación | `adm-tablero-ia` |
| Pedido | "⏳ Pedido pendiente: <plan>" | `adm-tablero-pedido` |
| Avisos críticos | Un renglón por aviso | `adm-tablero-aviso` (con `data-tipo`) |
| Ir al Portal | "Ir a Mi empresa →" | `adm-tablero-ir-portal` |
| Suscripción | Píldora y caja con el plan real | `adm-tablero-suscripcion` |
| Módulos habilitados | Un cuadro por módulo con funcionalidades activas | `adm-tablero-modulos`; cada uno `adm-tablero-modulo-<modulo>` |
| Últimos movimientos | Cinco renglones y "Ver toda la actividad →" | `adm-tablero-actividad`; `adm-tablero-ver-actividad` |

Los `data-testid` nuevos del tablero llevan el prefijo `adm-` aunque estén en una vista de Tools, porque
los datos los da el módulo **[SUPUESTO]**.

---

## Reglas

1. Auditoría y uso lo ve solo el superusuario; Actividad e Inicio, solo el administrador de la empresa
   activa (controlador base de REQ-002).
2. Todas las pantallas de este requerimiento son de **solo lectura**: no hay ningún recurso ni botón
   para cambiar o borrar auditoría o accesos.
3. El consumo de IA no aparece en la auditoría.
4. La Actividad del Portal muestra solo la empresa de la sesión (más las restricciones de su plan); un
   filtro de empresa que llegue del navegador se ignora.
5. En la Actividad del Portal, lo que hizo un superusuario figura como "Trazalog".
6. Los filtros, el paginado y la exportación se hacen en el servidor; la exportación respeta los filtros.
7. Un acceso se registra una vez por sesión y por empresa; recargar la página no suma.
8. Los avisos salen de los últimos 30 días de actividad y del estado actual (plan, lugares, cuota); se van
   solos cuando se resuelven.
9. El Inicio no muestra indicadores de operación (KPIs).
10. La tarjeta del tablero de Tools la ve solo quien es administrador según el Contexto.
11. Si el Contexto o el resumen no responden, el tablero de Tools se ve **exactamente como hoy**
    (Freemium, MAN/ALM/HER, sin tarjeta nueva) y los KPI funcionan igual.
12. Las fechas se muestran en la zona horaria de `zona_horaria_cuotas`; la base guarda UTC.

## Registro en el log

`log_message('DEBUG', '#TRAZA | ADM | <Clase> | <metodo>() ...')`. Se registran los rechazos, las
exportaciones (quién, filtros y cantidad de filas) y las fallas del Contexto ampliado y del registro de
accesos. En `Dash.php`, con el formato que ya usa (`'#TRAZA | CORE | Dash | dashboard() ...'`).

---

## Datos

**Cambio de base aditivo: lo decide el equipo (regla de Rodolfo del 2026-11-10).** La tabla nueva va en
`seg`, como todas las del módulo. Nombres **[SUPUESTO]**, como en REQ-004.

### Tabla nueva

| Tabla | Columnas | Notas |
|---|---|---|
| `seg.accesos` | `acce_id`, `email`, `empr_id`, `fecha` (UTC) | Solo inserción desde la aplicación (como `seg.consumos_mcp`); índice por (`empr_id`, `fecha`) y por (`email`, `empr_id`) |

### Índices nuevos en `seg.auditoria` (tabla de REQ-004)

Por (`fecha` descendente), (`empr_id`, `fecha`), (`accion`, `fecha`) y (`quien`, `fecha`), para que los
filtros respondan en menos de 2 s (RNF-12). Agregar índices no cambia ninguna fila.

Ninguna fila ni columna existente cambia; no hay carga de datos. Vuelta atrás: borrar la tabla y los
índices.

---

## Análisis de impacto en Tools (núcleo) — lo aprueba Rodolfo antes de construir

Verificado contra la rama `develop` (2026-11-10).

| Qué | Detalle |
|---|---|
| Archivos que cambian | `application/controllers/Dash.php`: en `dashboard()` (líneas 57-97) se pide el Contexto en modo completo y, si responde y es administrador, se reemplazan `tipo_suscripcion` (88), `modulos` (89) y `actividad` (90) y se agrega `resumen` para la tarjeta; en `index()` (18-48), el registro del acceso. `application/views/dashboard/admin_dashboard.php`: la tarjeta nueva, la píldora y la caja "Suscripción" con el plan real, los módulos con su conteo y la lista de últimos movimientos (estilos dentro de `.tzdash`, como el resto) |
| Archivos que **no** cambian | `application/config/dashboard.php` (queda de respaldo), `application/models/Dashs.php` (aterrizaje, KPI, conteo de usuarios), `application/views/layout/Admin.php:497` (el `linkTo` del aterrizaje), el JavaScript de los KPI, `kpi.*` y `ToolsKPIDataService`, `Dash::kpi`, `Dash::kpiMan`, `Dash::cambiarDeEmpresa` |
| Quién lo consume | Los administradores al entrar a Tools (`Dash.php:31`). El registro de accesos, **toda** persona que entra a Tools |
| Qué pasa si el servicio no responde | El Contexto devuelve sin `plan` y el tablero usa los valores de hoy (`'Freemium'`, `dashboard_modulos`, `dashboard_actividad` sin dibujar): se ve **igual que hoy**. Si el módulo no está montado, `Dash.php` no lo llama (mismo control que REQ-004). Si `POST /acceso` falla, no se registra y la página carga igual |
| Tiempo | Hoy `dashboard()` hace: memberships de Bonita, logo de `core.tablas`, `/users/{empr_id}` y, a veces, `/empresa/{empr_id}`. Se suman `resumen`, `avisos`, `funcionalidades` y `actividad` (cuatro lecturas). Se mide en la copia de DEMO; objetivo: no más de 0,5 s por encima de hoy **[SUPUESTO]**. `index()` suma un `POST` por sesión y empresa, no por página |
| Pruebas DocTest a actualizar | **Ninguna existente mira el tablero**: verificado con búsqueda de "tablero", "dashboard", "tzdash" y "Dash/" en `doctest/catalogo` y `doctest/tests` (cero resultados). `LoginPage.ts` (`doctest/tests/e2e/pages/dnato/LoginPage.ts:107,125`) espera que la red quede quieta después del ingreso: por eso la tarjeta **no** se refresca sola. Se agregan ADM-UC-217 y ADM-UC-218 y se corre `regresion` |
| Documentos a actualizar en el mismo pull request de construcción | `doc/analisis/dashboard-administrador-landing.md` §3 y §8: A5, A6 y A7 pasan a resueltos con este requerimiento |
| Vuelta atrás | Revertir `Dash.php` y `admin_dashboard.php`. La configuración de respaldo nunca se tocó |

---

## Decisiones tomadas

- **Una sola auditoría, dos vistas**: la Consola la ve entera con códigos; el Portal, filtrada por la
  empresa de la sesión y en lenguaje de usuario (nota de la maqueta `empresa-auditoria.html`).
- **El acceso se registra en `Dash::index`**: es el único lugar por donde pasa toda persona después del
  ingreso y del cambio de empresa, y `Dash.php` ya se toca en este requerimiento (y en REQ-004).
  Registrarlo en el ingreso obligaría a tocar DNATO y el ingreso copiado.
- **Los avisos se calculan una vez, en el Contexto**, y los usan el Inicio y el tablero: la regla queda
  en un solo lugar (lógica de negocio fuera de los controladores de Tools).
- **Un recurso de resumen** en vez de cuatro llamadas, para no hacer más lento el tablero (técnica
  menor).
- **El tablero de Tools cae a lo de hoy** si algo falla: es la primera pantalla que ven los
  administradores en producción.
- **Los KPI no se tocan** (decisión de Rodolfo; CU-30 "los KPIs de operación siguen en el tablero").

## Cómo se revisa (además de DocTest)

- Script de base (aditivo) corrido en una copia de DEMO, con su vuelta atrás.
- Análisis de impacto en Tools aprobado por Rodolfo; tiempo del tablero medido antes y después en la
  copia de DEMO.
- Búsqueda de recursos que escriban `seg.auditoria` fuera de "agregar": ninguno (resultado en la
  descripción del pull request).
- Con 10.000 filas de auditoría de prueba, cada filtro responde en menos de 2 s.
- DocTest `regresion` en verde.
- `phpcs` con PHPCompatibility para PHP 5.6 sin errores; `./mvnw clean install` del proyecto de APIs.
- **Aviso para el despliegue:** el script de despliegue sube los DataServices pero no las APIs; este
  requerimiento no agrega APIs.

## Dudas abiertas

Están en los casos de uso (campo `dudas`), para contestarlas en un solo lugar.

---

## Casos de prueba de la especificación que cubre

| CP | Qué prueba | Lo cubre |
|---|---|---|
| CP-100 | Cada acción de RF-100 tiene su fila; el consumo de IA no | ADM-UC-211 (y ADM-UC-210 para verlas) |
| CP-104 | Inicio con plan, lugares, IA, sin pedido, y avisos de la auditoría de 30 días | ADM-UC-215 y ADM-UC-216 |
| CP-106 | Inicio del Portal sin KPIs y acceso desde la barra de Tools | ADM-UC-215 (tres tarjetas, avisos, accesos, sin KPIs, "← Ir a Tools"). "🏢 Mi empresa" en la barra: REQ-004 (ADM-UC-030); indicador de cuota: REQ-011 (ADM-UC-175); perfil sin "Usuarios": REQ-007 |
| CP-107 (resto) | "Ver actividad" abre Auditoría filtrada por la persona | ADM-UC-210 |
| CP-101 | Auditoría inmutable | Ya cubierto por REQ-004 (ADM-UC-034); acá se verifica que no hay recursos de cambio |
| RF-101 | Uso de la plataforma | ADM-UC-212 y ADM-UC-213 (sin "Más usado") |
| T-1 (§9b) | Tablero del administrador | ADM-UC-217 y ADM-UC-218 |
