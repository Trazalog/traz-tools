# REQ-010 · Módulo Administración — Plan y pedidos, y "Elegí tu plan" en el registro

## Objetivo

Décimo trabajo de Pablo para el módulo **Administración** (`traz-comp-adm`): la pantalla **Plan** del
Portal (comparativa de planes, pedir un cambio de plan y cancelarlo), la resolución de esos pedidos por
el superusuario en la Consola, la cancelación automática del pedido cuando el superusuario cambia el
plan directamente, y el paso nuevo **"Elegí tu plan"** en la registración copiada del módulo (REQ-003).
Lo leen Pablo para planificar y Rodolfo para aprobar el análisis de impacto sobre la
registración. **No** cubre la cuota del agente ni su recálculo al cambiar de plan (REQ-011), la vista de
presentación ni "Me interesa" (REQ-012), las tarjetas de Inicio (REQ-013) ni el registro de DNATO, que
no se toca. Lista completa en [`README.md`](README.md).

| Campo | Valor |
|---|---|
| Estado | **Borrador**: Rodolfo tiene que contestar las dudas de los casos, y aprobar el análisis de impacto en la registración |
| Se apoya en | [REQ-002](REQ-002-administracion-esqueleto.md) (controlador base, Portal, Consola), [REQ-003](REQ-003-administracion-identidad.md) (registración copiada), [REQ-004](REQ-004-administracion-base-y-atributos.md) (`seg.pedidos_plan`, columnas de plan en `core.empresas`, auditoría, variables), [REQ-005](REQ-005-administracion-catalogo-y-planes.md) (planes, matriz, precio en variable), [REQ-006](REQ-006-administracion-funcionalidades.md) (R1, "sin activar"), [REQ-007](REQ-007-administracion-usuarios-roles-perfil.md) (lugares usados, botón "Pedir cambio de plan" en Usuarios) y [REQ-008](REQ-008-administracion-consola-empresas.md) (cambio directo de plan, librería `AltaEmpresa`, Registros, "Notificar a infra") |
| Entrega de la especificación | **E7** de `doc/v3/dnato/PROMPT_CLI_DNATO_V3_BUILD.md`: comparativa, pedir, cancelar, resolver, correos; cancelación automática por cambio directo; paso "Elegí tu plan" en el registro (Freemium por defecto, plan pago = pedido con origen registro). CU-42, CU-20, CU-53; CP-27, CP-30 a 33, CP-54 |
| Casos de uso | `ADM-UC-150` a `ADM-UC-154` en `doctest/catalogo/adm/` |
| Repos que se tocan | `traz-comp-adm` (pantalla Plan, ventana de resolución en la Consola, paso nuevo en la registración copiada, correos); `traz-tools`: recursos **nuevos** en `ADMDataService.dbs` y un script de base chico |
| Riesgo | 🔴 Los nombres de columnas de `seg.pedidos_plan` (tabla nueva) y su índice único nuevo (lista en "Datos") son **cambio de base aditivo: lo decide el equipo (regla de Rodolfo del 2026-11-10)**. Sigue en rojo solo por el **núcleo de Tools: registración** — se agrega un paso a la registración copiada del módulo y el alta pasa a dejar plan, funcionalidades y pedido → **análisis de impacto aprobado por Rodolfo** (sección "Análisis de impacto en la registración"). No toca la registración de DNATO, `API_CORE/empresa`, Bonita ni el disparador de alta. Recursos del DataService nuevos (🟡) |

---

## Para qué sirve

- Hoy no existe ninguna forma de que una empresa **pida** otro plan: no hay comparativa, ni pedido, ni
  aviso a Trazalog. Para vender por plan, el administrador tiene que ver qué gana y pedirlo, y Trazalog
  tiene que enterarse y resolverlo en un solo lugar.
- La registración crea todas las empresas igual (Freemium implícito). Con planes, la empresa tiene que
  arrancar con un plan concreto, y si el visitante quiere uno pago, que quede pedido sin frenar el alta
  y sin pedir datos de pago (RF-07, RF-33).
- REQ-007 y REQ-008 dejaron enganches para acá: el botón "Pedir cambio de plan" del tope de usuarios, el
  pedido pendiente en la ficha y en el listado de empresas, y la cancelación del pedido cuando el
  superusuario cambia el plan directamente (CP-27).

## Quién lo usa

- **Administrador** de una empresa: Mi empresa → Plan; pide, ve el estado y cancela.
- **Superusuario**: recibe el correo del pedido, lo ve en la Consola y lo aprueba o rechaza.
- **Visitante**: elige el plan en la registración del módulo.

## Qué tiene que hacer

1. Ver la comparativa de planes con lo que trae cada uno, el plan actual y lo que se gana, también con
   el plan vencido (CU-42, RF-93, RF-26, RF-26b) → **ADM-UC-150**.
2. Pedir un cambio de plan con motivo, ver el estado y cancelarlo; correo al superusuario, evento en
   Registros y aviso a infraestructura (CU-42, RF-30, RF-32, RF-33, RF-08) → **ADM-UC-151**.
3. Resolver un pedido: aprobar (= cambio directo con origen "pedido") o rechazar, con motivo y correo
   (CU-20, RF-31) → **ADM-UC-152**.
4. Cancelar sola el pedido pendiente cuando el superusuario cambia el plan directamente (RF-23, CP-27) →
   **ADM-UC-153**.
5. Elegir el plan al registrarse: Freemium preseleccionado; gratuito se activa, pago queda pedido
   (CU-53, RF-07, RF-08, RF-21) → **ADM-UC-154**.

## Qué NO hace

- **No toca la registración de DNATO** (`traz-comp-dnato/.../Register.php`), que sigue en producción tal
  cual. El paso nuevo va **solo** en la copia del módulo (REQ-003). Las empresas que se sigan
  registrando por DNATO quedan sin plan hasta M-3 (REQ-016); ver "Análisis de impacto".
- **No cobra ni pide datos de pago** (RF-33): aprobar no factura.
- **No recalcula la cuota del agente** al cambiar de plan (RF-86, R6): es REQ-011, que se engancha al
  mismo paso de cambio de plan.
- **No activa sola** lo nuevo que trae el plan aprobado: queda "sin activar" en Funcionalidades (RF-53,
  REQ-006), como en el cambio directo de REQ-008.
- No hace la pantalla "Uso de IA" (REQ-011): su botón "Pedir cambio de plan" lleva a esta pantalla.
- No hace la vista de presentación ni "Me interesa" (REQ-012), ni el aviso del pedido en el Inicio del
  Portal (REQ-013): acá el aviso se ve en Plan.
- No cambia el menú de Tools por el plan vencido: eso ya lo hace el menú resuelto de REQ-009.

---

## Cómo se arma

### Un solo paso para cambiar el plan

REQ-008 dejó el cambio directo de plan como un paso único del modelo (recurso
`ADMDataService PUT /consola/empresa/plan`, ADM-UC-113). Este requerimiento **no crea otro**: lo
amplía para que, **en la misma operación**:

- reciba el **origen** (`consola`, `pedido`, `registro`);
- si la empresa tiene un pedido `pendiente` y el origen es `consola`, lo pase a `cancelado` con motivo
  "resuelto por cambio directo" (CP-27) y deje la auditoría `pedido.cancelar`;
- si el origen es `pedido` o `registro`, deje el pedido en `aprobado`.

Así aprobar un pedido, aprobar un plan pendiente del registro y el cambio directo son el mismo código
(regla del repo: lógica en la API, no en el controlador). REQ-011 le agrega después el recálculo del
período de cuota (R6).

### Comparativa (RF-93)

- **Columnas**: los planes **activos** (REQ-005), en su orden, con ícono, nombre y precio (variable
  `precio_plan_{codigo}`; sin variable, "Consultar"). El plan de la empresa marcado "Tu plan actual".
- **Filas**: tope de usuarios ("hasta N" / "sin límite"), consultas de IA ("N por semana", "N por
  mes", "sin límite", "sin IA" con cuota 0) y las **funcionalidades publicadas del catálogo** agrupadas
  por módulo, incluidas las herramientas de IA bajo "IA (herramientas MCP)". Las opciones raíz sin
  dirección son agrupadores y no son filas (como en REQ-006).
- **Celdas**: "✔" si el plan la trae, "—" si no. En **verde** lo que el plan suma respecto del actual
  (funcionalidad que el actual no trae, o tope / cuota mayores).
- **Pie de cada plan**: "Pedir cambio a <plan>"; en el actual, "Tu plan actual" sin botón; en un plan
  gratuito / de prueba que la empresa ya usó (`core.empresas.uso_plan_gratuito`), "gratuito · ya usado"
  sin botón (RF-26b); con precio "Consultar", el botón "Consultar" (ver la duda de ADM-UC-150).
- **Empresa sin plan** (`plan_id` nulo, todas hasta M-3): ningún plan marcado como actual y todas las
  columnas con su botón **[SUPUESTO]**; ver la duda de ADM-UC-150.
- **Plan vencido** (`estado_plan = vencido`, REQ-008): arriba el aviso rojo "Tu período de prueba
  terminó el <fecha>" con el texto de la maqueta; la comparativa muestra **solo planes no gratuitos** y
  los gratuitos figuran "ya usado" (CP-19, CP-19b). Al entrar al Portal con el plan vencido, se abre
  directamente en Plan (CU-63).

### Pedido (RF-30, RF-32, RF-33)

1. "Pedir cambio a <plan>" abre la ventana "Pedir cambio al plan <ícono> <plan>" con "Ganás: …" (lo
   que suma: tope, consultas de IA y funcionalidades), "Motivo (opcional)", el texto "Los cambios de plan
   los aprueba Trazalog. El cobro se maneja aparte. Si bajás de plan, tus datos se conservan." y
   "Cancelar" / "Enviar pedido".
2. El servidor verifica: que no haya otro pedido pendiente (409 "Ya hay un pedido pendiente"), que el
   plan pedido no sea el actual, que esté activo y que, si es gratuito, la empresa no haya usado uno. La
   base lo garantiza con un índice único (un pendiente por empresa) para que dos pedidos a la vez no
   pasen.
3. Crea la fila en `seg.pedidos_plan` (`pendiente`, origen `portal`, plan actual y pedido, motivo, quién y
   cuándo), auditoría `pedido.crear`, evento `pedido_plan` en `seg.eventos_registro` (REQ-008) y llama a
   "Notificar a infra" (RF-08; no frena nada si falla). Todo menos el correo y la notificación, en una
   operación.
4. Correo a **todos los superusuarios** (marca de REQ-004): "Pedido de cambio de plan · <empresa>"
   **[SUPUESTO]** con empresa, plan actual, plan pedido, motivo y el enlace a la Consola (RF-32).
5. La pantalla muestra el aviso "⏳ Pediste pasar al plan <plan>" y "Trazalog lo está revisando; te
   avisamos por correo." con "Cancelar pedido"; todos los botones de pedir quedan deshabilitados.
6. **Cancelar**: el administrador lo pasa a `cancelado` con motivo "cancelado por el administrador"
   **[SUPUESTO]**; auditoría `pedido.cancelar`; vuelven los botones.

### Resolver un pedido (CU-20, RF-31)

- Se abre desde **Consola → Empresas** (columna "Pedido" "<plan> → <plan> pendiente" y botón
  "Resolver", RF-22), desde la ficha (tarjeta "Pedido pendiente") y desde **Registros** (pestaña
  "Pedidos de plan", botones "Aprobar" / "Rechazar" de REQ-008). Es la misma ventana en los tres lados.
- La ventana "Pedido de cambio de plan · <empresa>" muestra plan actual y plan pedido (con usuarios y
  consultas de IA), "Pedido por <nombre> el <fecha> · motivo: "<motivo>"", **lugares usados** y si caben
  en el plan pedido; el consumo de IA del período, cuando exista REQ-011. "Motivo (opcional)" y "Cerrar"
  / "Rechazar" / "Aprobar".
- **Aprobar**: el paso único de cambio de plan con origen `pedido` (aviso de lugares de REQ-008 si el
  tope es menor; `plan_vence` si el plan vence; `estado_plan = vigente`, que también saca a la empresa
  del plan vencido), pedido `aprobado`, auditoría `pedido.aprobar` y `empresa.cambiar_plan` (origen
  pedido), correo a los administradores "Tu pedido fue aprobado" (CP-31).
- **Rechazar**: la empresa sigue en su plan; pedido `rechazado` con motivo; auditoría `pedido.rechazar`;
  correo a los administradores con el motivo (CP-32). Puede pedir de nuevo.
- **Contador**: "📬 Registros" del menú de la Consola cuenta los pendientes de aprobación **de los dos
  tipos** (altas del registro con plan pago y pedidos del Portal), como la maqueta de Registros ("1
  registro · 1 pedido") y CP-33.
- Un pedido que ya no está `pendiente` (otro superusuario lo resolvió, o el administrador lo canceló)
  responde "Ese pedido ya fue resuelto" **[SUPUESTO]** y no cambia nada.

### "Elegí tu plan" en la registración copiada (CU-53, RF-07)

Hoy, en la copia del módulo (REQ-003): activar la cuenta (`main/complete`) → formulario de registro
(`register/register_success`) → datos de la empresa (`register/crearEmpresa`) → `register/guardarEmpresa`
→ `register/registro_completo`. El paso nuevo va **entre el formulario y los datos de la empresa**
(maqueta: "Registro · paso 3 de 4 · Tu plan"):

1. **Dónde se engancha**: `register/crearEmpresa`, si la sesión de registro todavía no tiene plan
   elegido, redirige a `register/elegirPlan` (nuevo). Así el formulario copiado
   (`formulario_page.php`, que redirige a `crearEmpresa`) **no cambia**.
2. **`register/elegirPlan`**: tarjetas con los planes activos en su orden (ícono, nombre, precio, "Hasta N
   usuarios", módulos que trae, consultas de IA). El **plan base** de REQ-005 (Freemium) va
   preseleccionado con "Recomendado para empezar" y el botón "✔ Seguir con Freemium". Los demás:
   "Pedir <plan>" (o "Consultar" si el precio es "Consultar"). El texto ℹ️ de la maqueta abajo, y "←
   Volver" / "Paso siguiente: datos de la empresa". Con el mismo estilo de las páginas de registro
   copiadas (REQ-003).
3. Guarda en la sesión de registro el plan elegido (`registro_plan_id`) y sigue a `crearEmpresa`. El
   servidor verifica que el plan exista y esté activo; si no, vuelve al paso con "Elegí un plan de la
   lista." **[SUPUESTO]**.
4. **Al terminar bien `guardarEmpresa`** (la librería `AltaEmpresa` de REQ-008, pasos 1 a 3, sin
   cambios), un paso nuevo **"plan inicial"** de la misma librería, que usan el registro y la Consola:
   - **Plan gratuito / de prueba** (Freemium es uno, sin vencimiento): el paso único de cambio de plan
     con origen `registro` y ese plan; `plan_vence` si vence; `uso_plan_gratuito = sí`; todas las
     funcionalidades del plan **activas** en el orden del catálogo (`POST
     /empresa/funcionalidades/desde-plan` de REQ-008, RF-21); evento `alta_registro` con aprobación
     `no_requiere`.
   - **Plan que no es gratuito**: la empresa queda en el **plan base** como en el caso anterior; además
     un pedido `pendiente` con origen `registro` (plan actual = base, plan pedido = el elegido),
     `estado_plan = pendiente` y `plan_pedido_id` (lo que REQ-008 muestra como "Plan pendiente de
     aprobación"), evento `alta_registro` con aprobación `pendiente`, correo a los superusuarios.
   - En los dos: "Notificar a infra" (no frena nada si falla).
5. Si el paso "plan inicial" falla, se revierte el alta igual que cuando falla otro paso de la
   librería, con el mismo mensaje del registro copiado (ver la duda de ADM-UC-154).
6. La Consola (REQ-008) pasa a usar este mismo paso "plan inicial" (origen `consola`, sin pedido) en vez
   de su código propio: no cambia lo que hace, queda un solo código.
7. Con el plan pendiente, el administrador ve en Plan: "Tu plan <plan> está pendiente de aprobación por
   Trazalog" (RF-07) y puede cancelarlo como cualquier pedido.

### Correos

Con el mecanismo copiado en REQ-003, remitente `remitente_correo`. Asuntos: pedido nuevo al
superusuario **[SUPUESTO]** "Pedido de cambio de plan · <empresa>"; aprobado "Tu pedido fue aprobado"
(CP-31); rechazado "No pudimos aprobar tu pedido de plan <plan>" **[SUPUESTO]**; cancelado por cambio
directo "Tu pedido de plan <plan> quedó resuelto" **[SUPUESTO]** (CP-27). Cuerpos **[SUPUESTO]**. Si un
correo falla, el cambio queda hecho y la pantalla lo dice (RNF-08).

### Auditoría

`pedido.crear`, `pedido.cancelar`, `pedido.aprobar`, `pedido.rechazar` (RF-100) y `empresa.cambiar_plan`
con su origen. En la misma operación que el cambio.

---

## De dónde sale cada dato

| Dato | De dónde | Cómo |
|---|---|---|
| Sesión, empresa activa, es administrador / superusuario | Sesión y `ADMDataService /usuario/es-admin/…`, `/usuario/es-super/…` | Ya existe (REQ-004) |
| Planes activos y matriz | `ADMDataService GET /planes`, `GET /planes/matriz` | Ya existe (REQ-005) |
| Precios | `ADMDataService GET /variables` (`precio_plan_{codigo}`) | Ya existe (REQ-004) |
| Plan, estado de plan, vencimiento, uso de gratuito de la empresa | `ADMDataService GET /empresa/{empr_id}/plan` | **NUEVO** |
| Pedido pendiente de la empresa | `ADMDataService GET /empresa/{empr_id}/pedido-pendiente` | **NUEVO** |
| Crear y cancelar pedido | `ADMDataService POST /pedido-plan`, `PUT /pedido-plan/cancelar` (verifica la empresa de la sesión) | **NUEVO** |
| Lugares usados | `ADMDataService GET /empresa/{empr_id}/lugares` | Ya existe (REQ-007) |
| Pedidos pendientes (Consola, contador, Empresas, Registros) | `ADMDataService GET /consola/pedidos-plan` | **NUEVO** |
| Un pedido (ventana de resolución) | `ADMDataService GET /consola/pedido-plan/{pedido_id}` | **NUEVO** |
| Aprobar / rechazar | `ADMDataService PUT /consola/pedido-plan/resolucion` (aprobar llama al paso único de cambio de plan en la misma operación) | **NUEVO** |
| Cambio de plan (con origen y cancelación del pendiente) | `ADMDataService PUT /consola/empresa/plan` | Existe por REQ-008; **se amplía** acá (recurso del módulo, no de v2) |
| Funcionalidades del plan al alta | `ADMDataService POST /empresa/funcionalidades/desde-plan` | Ya existe (REQ-008) |
| Eventos y "Notificar a infra" | `ADMDataService POST /registro` y el servicio de REQ-008 | Ya existe (REQ-008) |
| Correos de superusuarios y administradores | `ADMDataService GET /consola/superusuarios` (**NUEVO**) y `GET /empresa/{empr_id}/administradores` (REQ-005) | — |
| Alta de empresa del registro | Librería `AltaEmpresa` (REQ-008) con los accesos de la copia de REQ-003 | Ya existe (excepción de REQ-003, no se amplía) |

**Nada nuevo va directo a la base.** El paso "plan inicial" usa recursos del DataService aunque corra
dentro de la registración copiada (la excepción de REQ-003 cubre solo lo copiado). Todo `pedido_id` que
llega del navegador se verifica: en el Portal, contra la empresa de la sesión; en la Consola, que exista.

---

## Pantallas

### Portal — menú lateral

Se agrega "📦 Plan" bajo "Plan y consumo". `data-testid`: `adm-portal-menu-plan`.

### Portal → Plan — `traz-comp-adm/portal/plan`

Maqueta `doc/v3/dnato/mockups/empresa-plan.html`.

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Título | "Plan" y "Los cambios de plan los aprueba Trazalog. El cobro se maneja aparte. Si bajás de plan, tus datos se conservan." | `adm-plan` |
| Pedido pendiente | "⏳ Pediste pasar al plan <plan>" y "Trazalog lo está revisando; te avisamos por correo." con "Cancelar pedido" | `adm-plan-pedido`; `adm-plan-cancelar-pedido` |
| Plan pendiente del registro | "Tu plan <plan> está pendiente de aprobación por Trazalog" (RF-07) con "Cancelar pedido" | `adm-plan-pedido` |
| Plan vencido | "⏰ Tu período de prueba terminó el <fecha>" y "Tus usuarios pueden entrar, pero todas las pantallas están fuera de plan hasta que pases a un plan. Los planes gratuitos o de prueba se usan una sola vez. Elegí un plan abajo y Trazalog lo activa al aprobarlo." | `adm-plan-vencido` |
| Comparativa | "Qué incluye" y una columna por plan (ícono, nombre, precio o "Tu plan actual"); filas Usuarios, Consultas de IA y funcionalidades por módulo con "✔" / "—"; lo que se gana, en verde | `adm-plan-comparativa`; columna `adm-plan-col-<codigo>`; fila `adm-plan-fila-<modulo>-<opcion>` |
| Pie de columna | "Tu plan actual", "gratuito · ya usado", "Pedir cambio a <plan>", "Consultar" | `adm-plan-pedir-<codigo>`; `adm-plan-actual`; `adm-plan-ya-usado` |
| Ventana Pedir | "Pedir cambio al plan <ícono> <plan>", "Ganás: …", "Motivo (opcional)" con la ayuda "Lo ve Trazalog al revisar el pedido.", el texto de aprobación y cobro, "Cancelar" / "Enviar pedido" | `adm-plan-pedir-modal`; `adm-plan-motivo`; `adm-plan-enviar` |

Mensajes:

| Caso | Mensaje | `data-testid` |
|---|---|---|
| Pedido enviado **[SUPUESTO]** | "Listo: le mandamos tu pedido a Trazalog." | `adm-plan-ok` |
| Ya hay un pedido (409) | "Ya hay un pedido pendiente" (CP-30) | `adm-plan-error` |
| Plan actual o gratuito ya usado (pedido directo) **[SUPUESTO]** | "Ese plan no se puede pedir." | `adm-plan-error` |
| Pedido cancelado **[SUPUESTO]** | "Cancelamos tu pedido. Podés pedir otro cuando quieras." | `adm-plan-ok` |
| Correo que no salió **[SUPUESTO]** | "Guardamos tu pedido, pero no pudimos avisar por correo. Trazalog lo ve igual en su Consola." | `adm-plan-aviso` |
| Falla del servicio | "No pudimos guardar. Probá de nuevo en un rato." | `adm-plan-error` |

### Consola → Empresas y ficha (agregado a REQ-008)

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Columna Pedido | "<ícono> <plan actual> → <plan pedido> pendiente" | `adm-empresa-pedido` |
| Filtro | "Con pedido pendiente (N)" con datos reales | `adm-empresas-filtro-pedido` |
| Resolver | "Resolver" en la fila con pedido; en la ficha, la tarjeta "Pedido pendiente" con "Resolver" | `adm-empresa-resolver`, `adm-ficha-resolver` |
| Ventana | "Pedido de cambio de plan · <empresa>", "Plan actual" y "Plan pedido" (usuarios, IA), "Pedido por <nombre> el <fecha> · motivo: "<motivo>"", lugares usados y si caben, "Motivo (opcional)", "Cerrar" / "Rechazar" / "Aprobar" | `adm-pedido-resolver`; `adm-pedido-aprobar`, `adm-pedido-rechazar`, `adm-pedido-cerrar` |

### Consola → Registros (agregado a REQ-008)

La pestaña "Pedidos de plan" lista los pedidos con "📨 Pedido de plan", "<plan> → <plan>", motivo y
estado; "Aprobar" / "Rechazar" abren la misma ventana. El contador de "📬 Registros" suma registros y
pedidos pendientes.

Mensajes de la Consola **[SUPUESTO]**: aprobado "<empresa> pasó a <plan>."; rechazado "Rechazamos el
pedido de <empresa>; sigue en <plan actual>."; ya resuelto "Ese pedido ya fue resuelto"; falla "No
pudimos guardar. Probá de nuevo en un rato." (`adm-registros-ok`, `adm-registros-error`).

### Registro → Elegí tu plan — `traz-comp-adm/register/elegirPlan`

Maqueta `doc/v3/dnato/mockups/registro-plan.html`.

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Encabezado | "Registro · paso 3 de 4 · Tu plan", "Elegí cómo arrancar" y "Podés empezar gratis y cambiar de plan cuando quieras desde Mi empresa. Los planes pagos los activa Trazalog; el cobro se maneja aparte." | `adm-registro-plan` |
| Tarjeta | Ícono, nombre, precio ("Gratis" para el gratuito), "👥 Hasta N usuarios" / "Sin límite", lo que trae, consultas de IA; la del plan base con "Recomendado para empezar" | `adm-registro-plan-<codigo>` |
| Botón de la tarjeta | "✔ Seguir con Freemium" (plan base), "Pedir <plan>", "Consultar" | `adm-registro-plan-elegir-<codigo>` |
| Aviso | "ℹ️ Los planes gratuitos o de prueba se activan al instante y se pueden usar una sola vez; si tienen vencimiento, al terminar vas a tener que elegir un plan para seguir. Si elegís otro plan, tu empresa arranca en Freemium mientras Trazalog lo aprueba; te avisamos por correo. No pedimos datos de pago." | `adm-registro-plan-aviso` |
| Navegación | "← Volver" y "Paso siguiente: datos de la empresa" | `adm-registro-plan-volver`, `adm-registro-plan-siguiente` |

Error **[SUPUESTO]**: "Elegí un plan de la lista." (`adm-registro-plan-error`). La página de bienvenida
copiada (`registro_completo`) no cambia.

---

## Reglas

1. Solo el administrador de la empresa activa ve Plan y pide o cancela; la empresa sale de la sesión.
2. La comparativa muestra los planes activos en su orden y las funcionalidades publicadas por módulo;
   lo que suma respecto del plan actual va en verde.
3. Un solo pedido pendiente por empresa (la base lo garantiza); no se pide el plan actual, un plan
   inactivo ni un gratuito ya usado; el servidor lo verifica aunque el pedido llegue directo.
4. Con el plan vencido, la comparativa ofrece solo planes no gratuitos y el Portal abre en Plan.
5. Crear un pedido avisa por correo a los superusuarios, deja un evento en Registros y llama a
   "Notificar a infra"; si el correo o la notificación fallan, el pedido queda igual.
6. Solo el superusuario resuelve; aprobar es el paso único de cambio de plan con origen "pedido";
   rechazar deja el plan como estaba. Un pedido que ya no está pendiente no se resuelve.
7. El cambio directo desde la Consola cancela, en la misma operación, el pedido pendiente con motivo
   "resuelto por cambio directo" y avisa a los administradores.
8. Lo que trae el plan aprobado y la empresa no tenía queda "sin activar".
9. En la registración del módulo, el plan base va preseleccionado; un plan gratuito / de prueba se
   activa al crear la empresa; otro plan deja la empresa en el plan base con un pedido pendiente de
   origen "registro". No se piden datos de pago.
10. Al crear la empresa por el registro, las funcionalidades del plan con que arranca quedan activas en
    el orden del catálogo.
11. El registro de DNATO no cambia.
12. Cada pedido creado, cancelado, aprobado o rechazado queda en la auditoría con quién (de la sesión).

## Registro en el log

`log_message('DEBUG', '#TRAZA | ADM | <Clase> | <metodo>() ...')`. Se registran los rechazos, cada
pedido (empresa, planes, origen, quién), su resolución, la cancelación automática y, en el registro, el
plan elegido y el resultado del paso "plan inicial". Sin datos personales del formulario de registro.

---

## Datos

**Cambio de base aditivo: lo decide el equipo (regla de Rodolfo del 2026-11-10).** La tabla la crea
REQ-004 (en `seg`) con los atributos; acá
se proponen los nombres **[SUPUESTO]** (si el script de REQ-004 no corrió, van en él; si no, en uno
chico con su vuelta atrás).

### Columnas de `seg.pedidos_plan`

| Columna | Qué guarda |
|---|---|
| `pedido_id` | Número del pedido |
| `empr_id` | Empresa |
| `plan_actual_id`, `plan_pedido_id` | Plan al pedir y plan pedido (referencia a `seg.planes`) |
| `motivo` | Motivo del administrador (opcional) |
| `origen` | `portal` / `registro` |
| `estado` | `pendiente` / `aprobado` / `rechazado` / `cancelado` |
| `pedido_por`, `fec_pedido` | Correo de quien pidió y cuándo |
| `resuelto_por`, `fec_resolucion`, `motivo_resolucion` | Quién, cuándo y por qué se resolvió o canceló |

Índice único parcial por `empr_id` donde `estado = 'pendiente'` (un pendiente por empresa).

### Columnas existentes que se usan

`core.empresas.plan_id`, `estado_plan`, `plan_pedido_id`, `plan_vence`, `uso_plan_gratuito` (REQ-004):
se escriben solo desde el paso único de cambio de plan y el paso "plan inicial". `seg.eventos_registro`
(REQ-008): tipos `alta_registro` y `pedido_plan`.

Ninguna fila ni columna existente cambia; no hay carga de datos.

---

## Análisis de impacto en la registración (núcleo) — lo aprueba Rodolfo antes de construir

### Qué cambia

| Lugar | Cambio |
|---|---|
| `traz-comp-adm/controllers/Register.php` (copia de REQ-003) | `crearEmpresa` redirige a `elegirPlan` si la sesión no tiene plan; método nuevo `elegirPlan`; `guardarEmpresa` llama al paso "plan inicial" de `AltaEmpresa` después de los pasos 1 a 3 |
| `traz-comp-adm/libraries/AltaEmpresa.php` (REQ-008) | Paso nuevo "plan inicial"; la Consola lo usa en lugar de su código propio |
| `traz-comp-adm/views/` | Vista nueva del paso; las vistas copiadas no cambian |
| `traz-comp-dnato` | **Nada** |
| `API_CORE/empresa`, `COREDataService`, Bonita, AssetPlanner, disparador `configuracion_inicial_empresa_trg` | **Nada** |

### Quién lo consume

- **La registración del módulo**, que hoy solo se usa para comparar en paralelo con DNATO (REQ-003): la
  web comercial y los correos siguen apuntando a DNATO hasta la redirección (último paso). Por eso el
  cambio **no llega a clientes reales** hasta esa redirección.
- **La Consola** (REQ-008): comparte la librería; con el paso "plan inicial" compartido tiene que hacer
  exactamente lo mismo que antes (ADM-UC-111 en verde).
- **DocTest**: DNATO-UC-001 a 005 corridos contra la copia del módulo (REQ-003) pasan a tener el paso
  de plan (la especificación lo prevé: "UC-002 a 005, a las que se suma el paso de plan: CP-54"). Las
  mismas pruebas contra DNATO no cambian.

### Qué se rompe si falla, y cómo se protege

| Si pasa esto | Efecto | Protección |
|---|---|---|
| `elegirPlan` falla o no hay planes activos | Nadie puede terminar de registrarse en el módulo | Sin planes activos, `crearEmpresa` sigue sin el paso y la empresa arranca en el plan base (si tampoco hay base, sin plan, como hoy) **[SUPUESTO]**; se registra en el log |
| El paso "plan inicial" falla después de crear la empresa | Empresa a medias | Se revierte como cualquier otro paso de `AltaEmpresa` (duda de ADM-UC-154) |
| "Notificar a infra" o el correo fallan | Trazalog no se entera | No frenan el alta; quedan en Registros como "fallida" y se reintentan (REQ-008) |
| Se manipula el plan elegido desde el navegador | Empresa nueva con un plan pago sin aprobar | El servidor solo activa planes gratuitos; cualquier otro queda pedido |
| Mientras DNATO y el módulo conviven | Empresas de DNATO sin plan (`plan_id` nulo) y las del módulo con plan | R1 trata "sin plan" como todo en plan (propuesta de REQ-006); M-3 (REQ-016) las pasa al plan "Completo" |

### Pruebas que se actualizan en este mismo requerimiento

- La página de la registración del módulo en DocTest suma "Elegí tu plan" ("✔ Seguir con Freemium") para
  que DNATO-UC-001 a 005 contra la copia sigan en verde; contra DNATO, sin cambios.
- ADM-UC-154 (plan gratuito y plan pago) y ADM-UC-111 (alta desde la Consola) en verde.

---

## Decisiones tomadas

- **Un solo paso para cambiar el plan** (el de REQ-008, ampliado): aprobar un pedido, aprobar el plan
  del registro y el cambio directo son el mismo código; la cancelación automática del pendiente va
  adentro, en la misma operación (CP-27).
- **Un solo paso de "plan inicial"** en `AltaEmpresa`, para el registro y la Consola.
- **El paso nuevo se engancha en `crearEmpresa`**, no en el formulario copiado: cambia lo mínimo de la
  copia y DNATO no se toca.
- **El plan pago del registro es un pedido más** (origen `registro`): se ve y se resuelve igual que los
  del Portal, y el administrador lo puede cancelar.
- **Un pendiente por empresa lo garantiza la base**: dos pedidos a la vez no pasan.

## Cómo se revisa (además de DocTest)

- Script de base (aditivo) corrido en una copia de DEMO, con su vuelta atrás.
- **Análisis de impacto en la registración aprobado por Rodolfo**; DNATO-UC-001 a 005 en verde contra
  DNATO (sin cambios) y contra la copia del módulo (con el paso nuevo); ADM-UC-111 en verde.
- Dos pedidos simultáneos de la misma empresa: uno pasa y el otro recibe "Ya hay un pedido pendiente".
- Un `pedido_id` de otra empresa responde "no existe" en el Portal.
- `phpcs` con PHPCompatibility para PHP 5.6 sin errores; `./mvnw clean install` del proyecto de APIs.
- **Aviso para el despliegue:** el script de despliegue sube los DataServices pero no las APIs; este
  requerimiento no agrega APIs.

## Dudas abiertas

Están en los casos de uso (campo `dudas`), para contestarlas en un solo lugar.

---

## Casos de prueba de la especificación que cubre

| CP | Qué prueba | Lo cubre |
|---|---|---|
| CP-30 | Pedido: pendiente, botones deshabilitados, 409 con otro, plan actual sin botón, cancelar | ADM-UC-151 (y ADM-UC-150 para "Tu plan actual") |
| CP-33 | Aviso de pedido nuevo: correo al superusuario y contador en la Consola | ADM-UC-151 |
| CP-31 | Aprobar: cambia el plan, lo nuevo "sin activar", correo, auditoría con origen pedido | ADM-UC-152 |
| CP-32 | Rechazar: sigue en su plan, correo con motivo, puede pedir de nuevo | ADM-UC-152 |
| CP-27 | Cambio directo con pedido pendiente lo cancela | ADM-UC-153 |
| CP-54 | Registro con plan: Freemium preseleccionado; plan pago = pedido pendiente con origen registro | ADM-UC-154 |
| CP-19 (parte del Portal) | Plan vencido: Plan con "Tu período de prueba terminó", solo planes no gratuitos | ADM-UC-150. El proceso diario es REQ-008; el menú sombreado, REQ-009; la vista de presentación, REQ-012; el rechazo del agente, REQ-011 |
| CP-19b | Gratuito una sola vez: "ya usado" | ADM-UC-150 (comparativa) y ADM-UC-151 (rechazo del pedido directo) |
