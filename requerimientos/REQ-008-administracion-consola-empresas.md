# REQ-008 · Módulo Administración — Empresas, registros y usuarios en la Consola

## Objetivo

Octavo trabajo de Pablo para el módulo **Administración** (`traz-comp-adm`): las pantallas de la Consola
con las que el superusuario maneja **todas** las empresas y **todas** las personas de la plataforma:
**Empresas** (listado, alta, ficha editable con logo, cambio directo de plan, suspender, baja lógica),
el proceso diario que **vence los planes gratuitos o de prueba**, **Registros** (altas y avisos a
infraestructura, aprobación de planes pendientes) y **Usuarios de la plataforma** (filtros, exportar,
ban global, marcar superusuarios). Lo leen Pablo para planificar y Rodolfo para aprobar el cambio de
base, el análisis de impacto y el contrato con infraestructura. **No** cubre los pedidos de cambio de
plan ni el paso "Elegí tu plan" del registro (REQ-010), la bonificación y el uso de IA (REQ-011) ni la
pantalla de auditoría (REQ-013). Lista completa en [`README.md`](README.md).

| Campo | Valor |
|---|---|
| Estado | **Borrador**: Rodolfo tiene que contestar las dudas de los casos, aprobar el análisis de impacto (incluidas las filas nuevas en `core.tablas`) y acordar con el especialista de infraestructura el contrato de "Notificar a infra" |
| Se apoya en | [REQ-002](REQ-002-administracion-esqueleto.md) (controlador base, Consola), [REQ-003](REQ-003-administracion-identidad.md) (autorregistro copiado: su orquestación de alta), [REQ-004](REQ-004-administracion-base-y-atributos.md) (columnas de `core.empresas`, `seg.users.superusuario`, `seg.eventos_registro`, auditoría, variables), [REQ-005](REQ-005-administracion-catalogo-y-planes.md) (planes, vencimiento del plan), [REQ-006](REQ-006-administracion-funcionalidades.md) (`seg.empresas_funcionalidades`) y [REQ-007](REQ-007-administracion-usuarios-roles-perfil.md) (modelo `Membresias`, invitar, banear, servicio "Estado de membresía") |
| Entrega de la especificación | **E5** de `doc/v3/dnato/PROMPT_CLI_DNATO_V3_BUILD.md`: Consola → Empresas, Registros y Usuarios; alta reutilizando la orquestación del autorregistro, con manejo de error; cambio directo de plan; suspender / reactivar; vencimiento de planes gratuitos / de prueba; baja lógica; "Notificar a infra"; aprobación de planes pendientes; usuarios con filtros, exportación y actividad. CU-12 a 16, 18, 23, 61; CP-04, 17, 20 a 24, 26, 28, 29, 103, 107 |
| Casos de uso | `ADM-UC-110` a `ADM-UC-119` en `doctest/catalogo/adm/` |
| Repos que se tocan | `traz-comp-adm` (cuatro pantallas, proceso diario, librería de alta de empresa compartida con el registro copiado, logo en el Portal); `traz-tools`: recursos **nuevos** en `ADMDataService.dbs` y un script de base chico |
| Riesgo | 🔴 Las columnas nuevas de `core.empresas` (optativas) y los nombres de columnas de `seg.eventos_registro` (tabla nueva) son **cambio de base aditivo: lo decide el equipo (regla de Rodolfo del 2026-11-10)**. Sigue en rojo por el **núcleo de Tools**: las variables nuevas son filas nuevas en `core.tablas` (schema `core`, lista en "Datos"); se escriben `core.empresas` (estado, plan, datos, logo, `eliminado`) y `seg.users` (`banned_users`, `superusuario`) desde recursos nuevos; el alta llama a `API_CORE/empresa` (toolsCOREAPI, Bonita, AssetPlanner, disparador de alta) **sin modificarla**; el proceso diario necesita una tarea programada en el servidor → **análisis de impacto aprobado por Rodolfo**. "Notificar a infra": contrato a acordar (duda de ADM-UC-117) |

---

## Para qué sirve

- Hoy el superusuario solo puede **listar** empresas (A-11, sin acciones), el alta manual no lee la
  respuesta ni informa errores (A-12), no existe editar (A-13), la baja está rota (A-14) y no hay forma
  de suspender una empresa (A-15).
- Para vender por plan hace falta asignar y cambiar el plan de una empresa, y que los planes de prueba
  **venzan solos**.
- Cada alta y cada pedido de plan tiene que **llegarle a alguien** (hoy nadie se entera) y quedar en un
  reporte.
- La marca de superusuario (REQ-004) necesita una pantalla para darla y sacarla, con la regla "tiene que
  quedar al menos uno" (REQ-004 la dejó para acá). El ban global de hoy lo puede tocar cualquier
  administrador de empresa (A-08): pasa a ser solo del superusuario.

## Quién lo usa

- **Superusuario**: único que entra a estas pantallas.
- **Administrador** de una empresa: recibe la invitación, los correos de cambio de plan y de
  vencimiento, y es a quien se le suspende la empresa; se usa para probar el rechazo a la Consola.
- **Usuario**: es a quien se banea globalmente.

## Qué tiene que hacer

1. Listado de empresas con logo, búsqueda, filtros, acciones en línea y exportar (CU-13, RF-22) →
   **ADM-UC-110**.
2. Dar de alta una empresa con la orquestación del autorregistro, informando el error (CU-12, RF-20,
   RF-21) → **ADM-UC-111**.
3. Ficha de la empresa: ver todo y editar datos y logo; reenviar la invitación del administrador
   (CU-14, RF-25, RF-27) → **ADM-UC-112**.
4. Cambiar el plan de una empresa y su vencimiento (CU-15, RF-23, RF-26, RF-26b) → **ADM-UC-113**.
5. Suspender y reactivar una empresa (CU-16, RF-24, RF-04) → **ADM-UC-114**.
6. Dar de baja una empresa (lógica) y recuperarla (RF-28) → **ADM-UC-115**.
7. Proceso diario: avisar y vencer los planes gratuitos / de prueba (CU-61, RF-26) → **ADM-UC-116**.
8. Registros: altas, suspensiones y avisos a infraestructura; aprobar o rechazar planes pendientes
   (CU-23, RF-08, RF-29) → **ADM-UC-117**.
9. Usuarios de la plataforma: filtros, exportar, acciones por membresía, ver actividad (CU-18, RF-78) →
   **ADM-UC-118**.
10. Marcar y desmarcar superusuarios (no el último) y ban global (CU-18 E1, RF-78) → **ADM-UC-119**.

## Qué NO hace

- **No crea una orquestación nueva de alta de empresa.** Usa la misma del autorregistro: `POST
  API_CORE/empresa` y los pasos posteriores que el registro copiado (REQ-003) hace en PHP (ver "Cómo se
  arma"). No modifica toolsCOREAPI, `COREDataService` ni el disparador `configuracion_inicial_empresa_trg`.
- **No borra empresas.** La baja es siempre lógica (`eliminado`) y reversible.
- **No hace los pedidos de cambio de plan** (crear, cancelar, resolver desde Empresas: CU-20, CU-42) ni
  el paso "Elegí tu plan" del registro: REQ-010. Acá se aprueban o rechazan los **planes pendientes**
  que existan en Registros, y el cambio directo deja la marca para que REQ-010 cancele el pedido
  pendiente (CP-27).
- **No hace lo que cambia en Tools y en el agente por el estado de la empresa**: menú todo sombreado con
  plan vencido (T-2), corte de sesiones en las pantallas de Tools (T-5, H-091), rechazo del agente con
  `sin_acceso` o `plan_vencido` (REQ-011 y frente MCP), logo en el selector de Tools (T-3). Acá se
  guarda el estado y se respeta en el módulo y en el ingreso copiado.
- **No implementa el envío a Telegram ni a correo de infraestructura**: llama al servicio "Notificar a
  infra" con el contrato que se acuerde (§4: "DNATO no implementa el envío, lo llama").
- No bonifica consultas ni muestra uso de IA (REQ-011): esas partes de la ficha y del listado muestran
  "—" o no aparecen.
- No hace la pantalla de Auditoría (REQ-013): "📜 Ver actividad" y "Actividad" de la ficha llevan a ella
  cuando exista.
- No cambia el permiso inicial de los roles que da el disparador (RF-21, "pasa a respetar el plan"): es
  núcleo, ver la duda de ADM-UC-111.

---

## Cómo se arma

### La empresa sobre la que se actúa

En el Portal la empresa sale siempre de la sesión (REQ-002, regla 4). En la Consola el superusuario
actúa sobre **cualquier** empresa: el `empr_id` llega de la pantalla (fila, ficha, filtro), el
controlador base ya verificó que es superusuario, y el modelo verifica que la empresa exista. La empresa
**de la sesión** del superusuario nunca cambia por usar la Consola. Ver la duda de ADM-UC-110.

### Alta de empresa: la misma orquestación que el autorregistro

El autorregistro copiado (REQ-003, `Register::guardarEmpresa`, copia de
`traz-comp-dnato/application/controllers/Register.php:507-698`) hace:

1. Valida duplicados (razón social por país y CUIT, dominio de correo usado por otra empresa).
2. `POST API_CORE/empresa` (`toolsCOREAPI.xml:48-430`): empresa, AssetPlanner, grupo y roles de Bonita,
   mapeos; el disparador de base agrega permisos iniciales de rol, membresía del superadministrador y
   listas.
3. Pasos posteriores en PHP (`postProcesarEmpresa`, `Register.php:938-968`): usuarios por defecto,
   alinear la contraseña de Bonita, rol Administrador al que se registra, establecimiento y depósito
   por defecto, roles y mapeos extra configurables. Si alguno falla, revierte la empresa
   (`Empresas::eliminarEmpresa`) y dice qué falló.

Para que haya **un solo código**, los pasos 1 a 3 se sacan del controlador copiado a una **librería del
módulo** (por ejemplo `AltaEmpresa`) **sin cambiar lo que hacen**; el registro copiado y la Consola la
llaman. DNATO-UC-002 a 005 contra el registro copiado son la prueba de que no cambió nada. La Consola
agrega, después del paso 3 y solo en su camino:

- En vez de "rol Administrador al que se registra": **invita** al correo del primer administrador con el
  modelo `Membresias` de REQ-007 (rol Administrador, estado `invitado`, enlace con vencimiento). Si el
  correo ya es usuario, solo la membresía (CP-21). Si el correo no sale, la pantalla muestra el enlace
  (CP-22).
- Plan (`core.empresas.plan_id`), y si es gratuito / de prueba con vencimiento, `plan_vence` calculado
  (fecha de alta + vencimiento del plan) y `uso_plan_gratuito = sí`.
- Todas las funcionalidades del plan, **activas** en el orden del catálogo, en
  `seg.empresas_funcionalidades` (RF-21).
- Moneda, idioma, contacto del administrador y logo.
- Evento en `seg.eventos_registro` (alta desde la Consola) y "Notificar a infra".
- Auditoría `empresa.crear`.

**Si algo falla** (CP-20): igual que el autorregistro, se revierte la empresa (baja lógica) y la
pantalla muestra la lista de lo que falló y lo que quedó creado, con "Reintentar", que vuelve a mandar el
mismo formulario. Nunca redirige en silencio (corrige A-12).

### Ficha y edición (RF-25, RF-27)

- Datos editables: nombre (ver la duda de ADM-UC-112), descripción para soporte, contacto del administrador
  (`core.empresas.contacto_admin`), moneda (de la variable `monedas_permitidas`), idioma y logo
  (`core.empresas.image` / `imagepath`, los mismos que guarda el alta). Sin logo, la inicial.
- **El logo se ve también en el marco del Portal** (REQ-002 mostraba la inicial; REQ-004 lo dejó para
  acá, CP-108) y en la Consola.
- Resumen: plan con su ícono, si es gratuito y vencimiento; lugares usados / tope (R4, mismo recurso de
  REQ-007); pedido pendiente (de REQ-010; hasta entonces "Ninguno"); IA del período (REQ-011; hasta
  entonces no aparece).
- Pestañas: Resumen; Miembros (abre Usuarios de la plataforma con la empresa filtrada); Menús (los de
  REQ-009, si está); Formularios (REQ-015) y Uso de IA (REQ-011) aparecen cuando existan; Actividad
  (REQ-013).
- **Historial de planes**: filas `empresa.crear` y `empresa.cambiar_plan` de la auditoría de la empresa
  ("se deriva de la auditoría").
- Reenviar la invitación al primer administrador: el mismo "Reenviar" de REQ-007 (si el correo falla,
  enlace para copiar).

### Cambio directo de plan (RF-23, RF-26, RF-26b)

1. El superusuario elige plan (solo planes activos) y motivo opcional.
2. Si el plan nuevo tiene **tope menor** que los lugares usados: aviso "<empresa> usa N lugares y <plan>
   permite M: sobran K. No podrá invitar hasta quedar bajo el tope" (CP-23); se aplica igual.
3. Si el plan nuevo es **gratuito / de prueba** y la empresa ya usó uno (`uso_plan_gratuito`): la opción
   aparece deshabilitada con "Ya usó un plan de prueba" **[SUPUESTO]** (RF-26b).
4. Al confirmar: `plan_id`, `estado_plan = vigente`, `plan_vence` (calculado si el plan vence; nulo si
   no), `uso_plan_gratuito` si corresponde; auditoría `empresa.cambiar_plan` (anterior, nuevo, motivo,
   origen `consola`); correo a los administradores (definición única de REQ-004). Lo que el plan nuevo
   trae y la empresa no tenía queda "sin activar" en Funcionalidades (R1, REQ-006): no se activa solo.
5. **Extender vencimiento**: en la ficha, cambiar `plan_vence` de un plan gratuito / de prueba vigente o
   vencido (RF-26b); si estaba vencido y la fecha nueva es futura, vuelve a `vigente`. Auditoría
   `empresa.vencimiento`.
6. Lo que no se hace acá: cancelar el pedido pendiente (REQ-010 lo engancha a este mismo cambio) y
   recalcular el período de cuota (REQ-011).

### Suspender y reactivar (RF-24, RF-04)

- Suspender: confirmación con motivo opcional; `core.empresas.estado = suspendida` y `estado_motivo`;
  auditoría `empresa.suspender`; evento en Registros y "Notificar a infra". Reactivar: `activa`,
  `empresa.reactivar`.
- Efecto **en este requerimiento**: el servicio "Estado de membresía" de REQ-007 ya devuelve
  `empresa_suspendida`, así que el ingreso copiado no la ofrece y el módulo corta la sesión en el
  próximo pedido, con el texto de la variable `texto_suspension_empresa` ("Tu empresa está
  momentáneamente suspendida. Comunicate con soporte: <contacto_soporte>"). Tools y el agente: fuera de
  alcance (ver "Qué NO hace").

### Baja lógica y recuperación (RF-28)

- "Dar de baja" en la ficha: `core.empresas.eliminado = true` por el recurso **existente**
  `DELETE /empresa` de `COREDataService` (baja lógica, el que ya usa la reversión del registro:
  `Empresas::eliminarEmpresa`, `CORE.dbs:325`), más auditoría `empresa.baja` y motivo.
- Condición de la especificación: **solo si no tiene miembros activos**; si tiene, el mensaje dice
  cuántos y propone suspender (ver la duda de ADM-UC-115).
- "Recuperar": `eliminado = false` por un recurso **nuevo** (no hay uno hoy), auditoría
  `empresa.recuperar`. Las dadas de baja no aparecen en el listado salvo con el filtro "Dadas de baja"
  **[SUPUESTO]**.

### Proceso diario de vencimiento (CU-61, RF-26)

Un proceso del módulo que se corre por línea de comandos (por ejemplo
`php index.php traz-comp-adm/procesos/vencer_planes`), con una tarea programada del servidor, como el
refresco de indicadores que ya corre por cron en DEMO y producción. Cada día, en la zona horaria de la
variable `zona_horaria_cuotas` **[SUPUESTO]**:

1. Empresas con plan gratuito / de prueba y `plan_vence` = hoy + 7 días: correo de aviso a los
   administradores.
2. Empresas con `plan_vence` = hoy (o anterior y todavía `vigente`): `estado_plan = vencido`; correo a
   los administradores; auditoría `empresa.vencer_plan`; evento y "Notificar a infra".
3. Reintenta las notificaciones a infra fallidas (hasta 3, ver Registros).

No manda dos veces el mismo aviso (lo marca en la auditoría). Si un día no corrió, al día siguiente
vence las atrasadas. **No** cambia el plan de la empresa (ver la duda de ADM-UC-116: CP-24 dice "queda
en Free", RF-26 y D-21 dicen "plan vencido").

### Registros y "Notificar a infra" (RF-08, RF-29)

- Cada evento es una fila de `seg.eventos_registro` (REQ-004): alta por registro, alta desde la Consola,
  suspensión, vencimiento, y (con REQ-010) pedido de plan. **El registro copiado** (REQ-003) agrega la
  fila al terminar bien el alta; no cambia nada visible.
- "Notificar a infra": un servicio del módulo que recibe tipo de evento, empresa, administrador, plan,
  si requiere aprobación y el enlace a la Consola, llama al sistema de notificaciones de infraestructura
  y guarda canal, resultado y reintentos en la fila. **Contrato a acordar** con el especialista de
  infraestructura (dirección, autenticación, formato, respuesta). Mientras no esté, el servicio guarda
  el evento con resultado "sin canal configurado" y **no bloquea nada** (ver la duda de ADM-UC-117).
- Si el envío falla: la fila dice "fallida", se reintenta (proceso diario y botón "Reintentar"
  **[SUPUESTO]**) y el alta no se frena.
- **Aprobar un plan pendiente** (estado de plan `pendiente`, con `plan_pedido_id`): es un cambio directo
  de plan con origen "registro" (mismo paso que arriba), más la fila en `aprobada` y correo al
  administrador. **Rechazar**: la empresa sigue en su plan, `estado_plan = vigente`, fila en `rechazada`
  con motivo, correo. Hasta que REQ-010 haga el paso "Elegí tu plan", los pendientes se cargan a mano en
  la base de prueba.

### Usuarios de la plataforma (RF-78)

- Una fila por persona con todas sus membresías (empresa · rol · estado), súper, ban global, último
  acceso; IA del período cuando exista REQ-011.
- Filtros en el servidor: texto, empresa, rol, estado de membresía (activo, invitado sin aceptar,
  baneado, baja), último acceso (cualquiera, hace más de 30 días, nunca), súper usuarios, con ban
  global. Paginado en el servidor (RNF-12: menos de 2 s con 10.000 personas).
- Desde Empresas y desde la ficha se llega con el filtro de empresa puesto ("Llegaste desde …").
- Acciones por membresía (banear, reactivar, reenviar invitación): el **mismo modelo `Membresias`** de
  REQ-007, con la empresa de la fila; valen las mismas reglas (último administrador, tope).
- **Exportar CSV**: el listado con el filtro aplicado, generado en el servidor.
- "📜 Ver actividad": abre Auditoría (REQ-013) filtrada por la persona; hasta entonces no aparece.

### Superusuarios y ban global (CP-103)

- "Súper": marcar o desmarcar `seg.users.superusuario` (REQ-004). Desmarcar al **último** se rechaza:
  "Tiene que quedar al menos un súper usuario". El control se hace **en la base, en la misma operación**
  (para que dos desmarcados a la vez no dejen cero). Auditoría `superusuario.marcar` /
  `superusuario.desmarcar`.
- "Ban global": `seg.users.banned_users = ban` / `unban`, la misma columna que mira hoy el ingreso de
  DNATO (`Main.php:1514`), así que **vale también en DNATO**. Solo el superusuario lo puede cambiar
  (hoy cualquier administrador, A-08). No se puede banear globalmente a un superusuario ni a uno mismo
  **[SUPUESTO]**. Auditoría `usuario.ban_global` / `usuario.quitar_ban_global`.

### Auditoría

En la misma operación que el cambio (o, cuando pasa por una API existente, después de que respondió
bien): `empresa.crear`, `empresa.editar`, `empresa.cambiar_plan`, `empresa.vencimiento`,
`empresa.suspender`, `empresa.reactivar`, `empresa.baja`, `empresa.recuperar`, `empresa.vencer_plan`,
`registro.aprobar`, `registro.rechazar`, `superusuario.marcar`, `superusuario.desmarcar`,
`usuario.ban_global`, `usuario.quitar_ban_global`, más las de membresía de REQ-007. Nombres de CP-04
(`empresa.suspender`), CP-28 (`empresa.editar`) y la maqueta (`empresa.cambiar_plan`); los demás
**[SUPUESTO]**.

---

## De dónde sale cada dato

| Dato | De dónde | Cómo |
|---|---|---|
| Es superusuario | `ADMDataService GET /usuario/es-super/{email}` | Ya existe (REQ-004) |
| Empresas con plan, lugares, estado, pedido, vencimiento, admin sin aceptar (paginado, filtros) | `ADMDataService GET /consola/empresas` | **NUEVO** |
| Exportar empresas / usuarios | `ADMDataService GET /consola/empresas` y `GET /consola/personas` sin paginar (el módulo arma el CSV) | **NUEVO** |
| Ficha de una empresa | `ADMDataService GET /consola/empresa/{empr_id}` | **NUEVO** |
| Editar datos y logo | `ADMDataService PUT /consola/empresa` | **NUEVO** (A-13 no existe) |
| Alta de empresa | `API_CORE POST /empresa` y los pasos del registro copiado (`REST_CORE/establecimiento`, `deposito*`, `REST_BPM`, `API_CORE/usuario`, `/rol/asignar`) | Ya existen (no se modifican) |
| Invitar al primer administrador, reenviar, banear o reactivar una membresía | Modelo `Membresias` de REQ-007 | Ya existe (REQ-007) |
| Funcionalidades del plan, activarlas al alta | `ADMDataService POST /empresa/funcionalidades/desde-plan` | **NUEVO** |
| Cambiar plan, vencimiento | `ADMDataService PUT /consola/empresa/plan`, `PUT /consola/empresa/vencimiento` | **NUEVO** |
| Suspender, reactivar | `ADMDataService PUT /consola/empresa/estado` | **NUEVO** |
| Baja lógica | `COREDataService DELETE /empresa` | Ya existe (no se modifica) |
| Recuperar | `ADMDataService PUT /consola/empresa/recuperar` | **NUEVO** |
| Planes activos | `ADMDataService GET /planes` | Ya existe (REQ-005) |
| Lugares usados | `ADMDataService GET /empresa/{empr_id}/lugares` | Ya existe (REQ-007) |
| Administradores de una empresa (correos) | `ADMDataService GET /empresa/{empr_id}/administradores` | Ya existe (REQ-005) |
| Historial de planes y actividad reciente | `ADMDataService GET /consola/empresa/{empr_id}/auditoria` | **NUEVO** (lectura de `seg.auditoria`) |
| Empresas para vencer y avisar | `ADMDataService GET /consola/planes-por-vencer/{fecha}`, `PUT /consola/empresa/vencer` | **NUEVO** |
| Registros: listar, crear, resultado del aviso, aprobar, rechazar | `ADMDataService GET /consola/registros`, `POST /registro`, `PUT /registro/notificacion`, `PUT /registro/resolucion` | **NUEVO** |
| Personas de la plataforma (paginado, filtros) | `ADMDataService GET /consola/personas` | **NUEVO** |
| Marcar / desmarcar superusuario | `ADMDataService PUT /usuario/superusuario` (rechaza el último en la base) | **NUEVO** |
| Ban global | `ADMDataService PUT /usuario/ban-global` | **NUEVO** (misma columna que `updateUserban` de DNATO) |
| Variables (textos, contacto, monedas, zona horaria) | `ADMDataService GET /variables` | Ya existe (REQ-004) |
| Notificar a infra | Sistema de notificaciones de infraestructura | **Contrato a acordar** |

**Nada va directo a la base**, salvo lo que ya hace así el registro copiado (excepción de REQ-003),
que la librería `AltaEmpresa` conserva tal cual.

---

## Pantallas

Maquetas `doc/v3/dnato/mockups/consola-empresas.html`, `consola-empresa-ficha.html`,
`consola-registros.html` y `consola-usuarios.html`, dentro del marco de la Consola de REQ-002.

### Consola — menú lateral

| Opción | `data-testid` |
|---|---|
| "🏢 Empresas" | `adm-consola-menu-empresas` |
| "📬 Registros", con el número de pendientes | `adm-consola-menu-registros` |
| "👥 Usuarios" | `adm-consola-menu-usuarios` |

### Consola → Empresas — `traz-comp-adm/consola/empresas`

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Título | "Empresas" y "Todas las empresas de la plataforma, su plan y lo que requiere acción." | `adm-empresas` |
| Nueva | "＋ Nueva empresa" | `adm-empresas-nueva` |
| Búsqueda y filtros | "🔍 Nombre o detalle"; "Todas", "Con pedido pendiente (N)", "Plan pendiente de aprobación (N)", "Suspendidas (N)", "Por vencer (N)", "Admin sin aceptar (N)"; "Todos los planes"; "Dadas de baja" **[SUPUESTO]** | `adm-empresas-buscar`, `adm-empresas-filtro-<filtro>`, `adm-empresas-filtro-plan` |
| Exportar | "⬇ Exportar" | `adm-empresas-exportar` |
| Tabla | Empresa (logo o inicial, nombre, descripción), Plan (ícono, nombre, "vence <fecha>"), Usuarios ("N / M", "tope", "admin sin aceptar"), IA (período), Estado ("Activa", "Suspendida · <fecha>", "Plan pendiente de aprobación"), Pedido | `adm-empresas-tabla`; fila `adm-empresa-<empr_id>` |
| Acciones de la fila | "Ficha", "Plan", "👥 Usuarios", "Suspender" / "Reactivar", "Reenviar invitación", "Revisar" (lleva a Registros) | `adm-empresa-ficha`, `adm-empresa-plan`, `adm-empresa-usuarios`, `adm-empresa-suspender`, `adm-empresa-reactivar`, `adm-empresa-reenviar`, `adm-empresa-revisar` |
| Pie | "N empresas (la baja es lógica)" | `adm-empresas-pie` |
| Formulario Nueva empresa | Nombre, Descripción para soporte, País y CUIT **[SUPUESTO]**, Plan, Moneda, Idioma, Fin del plan (opcional, solo planes gratuitos / de prueba), Correo del primer administrador, Logo; "Crear" y "Cancelar" | `adm-empresa-form`; `adm-empresa-crear`, `adm-empresa-cancelar` |
| Resultado con falla | Lista de lo que falló y lo que quedó, y "Reintentar" | `adm-empresa-alta-error`; `adm-empresa-reintentar` |
| Cambiar plan | Ventana: plan actual, selector de plan (los gratuitos ya usados, deshabilitados con el motivo), motivo opcional, el aviso de lugares si corresponde, "Cancelar" / "Cambiar plan" | `adm-empresa-cambiar-plan`; `adm-cambiar-plan-confirmar` |
| Suspender | Ventana "Suspender <empresa>" con motivo opcional, "Cancelar" / "Suspender" **[SUPUESTO]** | `adm-empresa-suspender-modal`; `adm-suspender-confirmar` |

Mensajes:

| Caso | Mensaje | `data-testid` |
|---|---|---|
| Empresa creada **[SUPUESTO]** | "Creamos <empresa> y le mandamos la invitación a <correo>." | `adm-empresas-ok` |
| Correo que no salió | "No pudimos enviar el correo. Copiá este enlace y mandáselo: <enlace>" (CP-22) | `adm-empresas-enlace` |
| Alta que falló **[SUPUESTO]** | "No pudimos completar el alta: <lo que falló>. Revertimos lo creado. Podés reintentar." | `adm-empresa-alta-error` |
| Empresa repetida | Los del registro copiado ("La empresa ya existe para el pais y CUIT indicados.") | `adm-empresa-alta-error` |
| Menos lugares en el plan nuevo | "<empresa> usa N lugares y <plan> permite M: sobran K. No podrá invitar hasta quedar bajo el tope" (CP-23) | `adm-cambiar-plan-aviso` |
| Plan cambiado **[SUPUESTO]** | "<empresa> pasó al plan <plan>. Avisamos por correo a sus administradores." | `adm-empresas-ok` |
| Suspendida / reactivada **[SUPUESTO]** | "Suspendimos <empresa>: nadie puede entrar hasta que la reactives." / "Reactivamos <empresa>." | `adm-empresas-ok` |
| Falla del servicio | "No pudimos guardar. Probá de nuevo en un rato." | `adm-empresas-error` |

Correo de cambio de plan: asunto "Trazalog cambió tu plan <plan>" (el mismo de REQ-005, CP-16); cuerpo
**[SUPUESTO]**.

### Consola → Ficha de empresa — `traz-comp-adm/consola/empresa/<empr_id>`

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Cabecera | Logo o inicial, nombre, "<descripción> · moneda <m> · idioma <i> · alta <fecha> · contacto <correo>", estado | `adm-ficha` |
| Botones | "✎ Editar", "Cambiar plan", "Extender vencimiento" (solo planes gratuitos / de prueba), "👥 Usuarios", "Suspender" / "Reactivar", "Dar de baja" / "Recuperar" **[SUPUESTO]** | `adm-ficha-editar`, `adm-ficha-cambiar-plan`, `adm-ficha-extender`, `adm-ficha-usuarios`, `adm-ficha-suspender`, `adm-ficha-baja`, `adm-ficha-recuperar` |
| Pestañas | "Resumen", "Miembros (N)", "Menús (N)", "Actividad" (y "Formularios", "Uso de IA" cuando existan) | `adm-ficha-tab-<pestaña>` |
| Editar empresa | Logo ("📁 Subir logo", "Quitar", "Sin logo se muestra la inicial. Se ve en el Portal, en Tools y en esta Consola."), Nombre, Descripción para soporte, Contacto del administrador, Moneda, Idioma, "Guardar" / "Cancelar" | `adm-ficha-form`; `adm-ficha-logo`, `adm-ficha-guardar` |
| Tarjetas | Plan ("gratuito · sin vencimiento · desde <fecha>"), Usuarios ("N / M", "tope alcanzado"), Pedido pendiente ("Ninguno") | `adm-ficha-plan`, `adm-ficha-lugares`, `adm-ficha-pedido` |
| Historial | "Historial de planes y auditoría reciente" con Fecha, Quién, Acción, Detalle | `adm-ficha-historial` |

La tarjeta "IA este período", "Otorgar consultas de IA extra" y "Uso de IA · últimos 6 períodos" son de
REQ-011: no aparecen en este requerimiento.

Mensajes **[SUPUESTO]**: "Guardado ✓" (`adm-guardado`); logo inválido "El logo tiene que ser JPG o PNG
de hasta 1 MB." (`adm-ficha-error`); vencimiento extendido "El plan de <empresa> vence ahora el
<fecha>." (`adm-ficha-ok`); baja con miembros activos "<empresa> tiene N personas activas. Para cortar
el acceso sin darla de baja, suspendela." (`adm-ficha-error`); baja hecha "Dimos de baja <empresa>. La
podés recuperar desde Empresas → Dadas de baja." (`adm-ficha-ok`).

### Consola → Registros — `traz-comp-adm/consola/registros`

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Título | "Registros" y "Altas de empresa y pedidos de plan: qué pasó, qué plan, si requiere aprobación y cómo se avisó a infra." | `adm-registros` |
| Exportar | "⬇ Exportar" | `adm-registros-exportar` |
| Tarjetas | "Pendientes de aprobación", "Altas este mes" ("N por registro · M desde la Consola"), "Notificaciones a infra" ("N ok", "M fallida"), "Canales" | `adm-registros-resumen` |
| Pestañas | "Pendientes (N)", "Todos", "Altas", "Pedidos de plan", "Suspensiones" (y "Vencimientos" **[SUPUESTO]**) | `adm-registros-tab-<pestaña>` |
| Filtro por fecha | Desde / hasta (RF-29) **[SUPUESTO]** de diseño | `adm-registros-fechas` |
| Tabla | Fecha, Evento ("🆕 Alta por registro", "🆕 Alta desde la Consola", "📨 Pedido de plan", "⛔ Suspensión"), Empresa, Administrador, Plan ("Pedido: <plan>", "opera en Free mientras tanto"), Estado, Notificación ("Telegram ✓", "Correo ✗ reintento 2/3"), "Aprobar" / "Rechazar" | `adm-registros-tabla`; fila `adm-registro-<id>`; `adm-registro-aprobar`, `adm-registro-rechazar`, `adm-registro-reintentar` |
| Pie | "Cada fila nace de un evento; el envío lo hace el sistema de notificaciones de infra; si falla, se reintenta y el alta no se bloquea." (la maqueta dice "de DNATO": ver duda de ADM-UC-117) | `adm-registros-pie` |
| Ventana Aprobar | "Aprobar plan <plan> · <empresa>", "Registrada <fecha> por <correo>", plan pedido con tope, cuota y precio, "Al aprobar, <empresa> pasa a <plan> y el administrador recibe correo. El cobro se maneja aparte.", "Motivo (opcional)", "Cerrar" / "Rechazar" / "Aprobar" | `adm-registro-resolver`; `adm-resolver-aprobar`, `adm-resolver-rechazar` |

Mensajes **[SUPUESTO]**: aprobado "<empresa> pasó a <plan>." (`adm-registros-ok`); rechazado
"Rechazamos el plan <plan> de <empresa>; sigue en <plan actual>." (`adm-registros-ok`); falla "No
pudimos guardar. Probá de nuevo en un rato." (`adm-registros-error`).

### Consola → Usuarios de la plataforma — `traz-comp-adm/consola/usuarios`

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Título | "Usuarios de la plataforma" y "Todas las personas, en todas las empresas. Filtrá, actuá en cualquiera y exportá." | `adm-personas` |
| Exportar | "⬇ Exportar CSV (filtrado)" | `adm-personas-exportar` |
| Filtros | "🔍 nombre o correo", Empresa, "Todos los roles", Estado ("Activo", "Invitado sin aceptar", "Baneado", "Baja"), Último acceso ("cualquiera", "Hace más de 30 días", "Nunca"), "Súper usuarios (N)", "Con ban global (N)" | `adm-personas-buscar`, `adm-personas-filtro-<filtro>` |
| Llegada filtrada | "🏢 Llegaste desde Empresas › <empresa>: el filtro de empresa ya está aplicado." y "Quitar filtro" | `adm-personas-llegada`; `adm-personas-quitar-filtro` |
| Tabla | Usuario (nombre, correo, teléfono), Empresas y roles (una línea por membresía con estado y "Banear" / "Reactivar" / "Reenviar"), Súper, Ban global, Último acceso, IA período, "📜 Ver actividad" | `adm-personas-tabla`; fila `adm-persona-<email>`; `adm-persona-membresia-<empr_id>`, `adm-persona-super`, `adm-persona-ban-global`, `adm-persona-actividad` |
| Pie | "N personas con el filtro aplicado · M en la plataforma" | `adm-personas-pie` |

Mensajes: último superusuario "Tiene que quedar al menos un súper usuario" (CP-103,
`adm-personas-error`); ban global **[SUPUESTO]** "Ventana: Ban global a <nombre>: no va a poder entrar a
ninguna empresa. ¿Continuar?" (`adm-ban-global`); los de membresía, los de REQ-007.

### Marco del Portal (cambio)

La marca de empresa del Portal (`adm-portal-empresa`, REQ-002) muestra el **logo** si la empresa lo
tiene; si no, la inicial (CP-28, CP-108).

### Correos

Con el mecanismo copiado en REQ-003, remitente `remitente_correo`. Textos **[SUPUESTO]** salvo el asunto
de cambio de plan: aviso 7 días antes ("Tu período de prueba de <plan> termina el <fecha>"), día del
vencimiento ("Tu período de prueba terminó"), aprobación ("Aprobamos tu plan <plan>"), rechazo ("No
pudimos aprobar el plan <plan>"). Si un correo falla, el cambio queda hecho y la pantalla lo dice
(RNF-08).

---

## Reglas

1. Solo el superusuario ve y usa estas pantallas y el proceso diario; cualquier otro recibe "sin
   permiso" (403), también en los envíos directos.
2. En la Consola la empresa sobre la que se actúa viene de la pantalla y se verifica que exista; la
   empresa de la sesión del superusuario no cambia.
3. El alta de empresa usa la misma orquestación que el autorregistro; si falla, se revierte y se informa
   qué falló, con "Reintentar".
4. El primer administrador queda invitado (o solo con la membresía si ya es usuario); su enlace sigue
   las reglas de REQ-007.
5. Al dar de alta, todas las funcionalidades del plan quedan activas en el orden del catálogo.
6. Un plan gratuito / de prueba se usa una sola vez por empresa; el superusuario puede extender el
   vencimiento del que está en curso o vencido.
7. Cambiar a un plan con menos lugares avisa cuántos sobran y se aplica igual; la empresa no puede
   invitar hasta bajar del tope (R4 de REQ-007).
8. Suspender no toca datos y es reversible; una empresa suspendida no se elige en el ingreso copiado y
   su sesión en el módulo se corta en el próximo pedido.
9. La baja de empresa es siempre lógica y reversible; nunca se borra.
10. El proceso diario avisa 7 días antes, vence el día indicado, no repite avisos y recupera los días
    que no corrió.
11. Toda alta, suspensión y vencimiento genera un evento en Registros y llama a "Notificar a infra"; si
    la notificación falla, se reintenta y no bloquea nada.
12. Aprobar un plan pendiente es un cambio directo de plan con origen "registro"; rechazar deja la
    empresa en su plan.
13. Tiene que quedar al menos un superusuario; la base lo garantiza.
14. El ban global solo lo cambia el superusuario y vale en todas las empresas, también en el ingreso de
    DNATO.
15. Las acciones sobre membresías usan el modelo de REQ-007 con las mismas reglas.
16. Listados y exportaciones filtran y paginan en el servidor; exportar respeta el filtro.
17. Cada cambio queda en la auditoría con quién (de la sesión) y qué.

## Registro en el log

`log_message('DEBUG', '#TRAZA | ADM | <Clase> | <metodo>() ...')`. Se registran los rechazos, cada alta
(con cada paso y su resultado), cambio de plan, suspensión, baja, vencimiento, notificación a infra
(evento, canal y resultado, sin el contenido) y cada cambio de superusuario y ban global. Nunca
contraseñas ni enlaces de invitación.

---

## Datos

**Estructura: cambio de base aditivo, lo decide el equipo (regla de Rodolfo del 2026-11-10).** Las dos
columnas nuevas de `core.empresas` son optativas (aceptan vacío) y `seg.eventos_registro` es tabla nueva
de `seg`. **Las filas nuevas en `core.tablas` (variables) son del núcleo y las aprueba Rodolfo** con el
análisis de impacto. Si el script de REQ-004 no corrió todavía, va dentro de él; si no, en uno chico con
su vuelta atrás. Nombres **[SUPUESTO]**.

### Columnas nuevas en tablas existentes

| Tabla | Columna | Qué guarda | Por defecto |
|---|---|---|---|
| `core.empresas` | `moneda` | Moneda de la empresa (de `monedas_permitidas`) | nulo |
| `core.empresas` | `idioma` | Idioma de la empresa | nulo (= español) |

### Nombres de columnas de `seg.eventos_registro` (REQ-004 dio los atributos)

`evento_id`, `fecha`, `tipo` (`alta_registro`, `alta_consola`, `pedido_plan`, `suspension`,
`vencimiento`), `empr_id`, `administrador` (correo), `plan_id`, `plan_pedido_id`, `origen` (`registro`,
`consola`, `proceso`), `aprobacion` (`no_requiere`, `pendiente`, `aprobada`, `rechazada`),
`motivo_resolucion`, `resuelto_por`, `resuelto_en`, `canal`, `resultado` (`ok`, `fallida`,
`sin_canal`), `reintentos`, `detalle_envio`.

### Variables nuevas (filas en `core.tablas` sin empresa, con historial de REQ-004)

| Clave | Valor inicial | Para qué |
|---|---|---|
| `aviso_vencimiento_dias` | `7` | Días de anticipación del aviso de vencimiento (RF-26 dice 7; RNF-05 pide que no quede fijo) |
| `notificacion_infra_url` | vacío | Dirección del servicio de notificaciones de infraestructura, cuando se acuerde el contrato |

Ningún secreto va en estas variables: la credencial del servicio de infraestructura, si la tiene, va en
la configuración del servidor (como en REQ-003).

### Tablas existentes que se escriben (sin cambiar su estructura)

| Tabla | Qué se escribe | Por dónde |
|---|---|---|
| `core.empresas` y todo lo del alta (Bonita, AssetPlanner, establecimiento, depósito, usuarios por defecto) | Alta | `API_CORE/empresa` y los pasos del registro copiado (existentes) |
| `core.empresas` | Datos, logo, plan, estado, vencimiento | Recursos **nuevos** de `ADMDataService` (núcleo: schema `core`) |
| `core.empresas.eliminado` | Baja / recuperar | `COREDataService DELETE /empresa` (existente) / recurso **nuevo** |
| `seg.users` | `superusuario`, `banned_users` | Recursos **nuevos** de `ADMDataService` |
| `seg.empresas_funcionalidades`, `seg.eventos_registro`, `seg.auditoria` | Activación al alta, eventos, auditoría | Tablas de REQ-004 |

---

## Decisiones tomadas

- **Un solo código de alta de empresa**: la orquestación del autorregistro se saca del controlador
  copiado a una librería del módulo, sin cambiar lo que hace, y la usan el registro y la Consola (regla
  del repo: desde todos lados se invoca el mismo código).
- **La baja es lógica y usa el recurso que ya existe** (`DELETE /empresa`, que pone `eliminado`).
- **Aprobar un pendiente = cambio directo de plan**: un solo camino para cambiar el plan (Consola,
  registro y, con REQ-010, pedidos).
- **El ban global queda en la columna de hoy** (`banned_users`): así vale también en DNATO sin tocarlo.
- **"Al menos un superusuario" se controla en la base**: es la única forma de que dos cambios a la vez
  no dejen la plataforma sin superusuario.
- **"Notificar a infra" no frena nada**: un alta nunca falla porque infraestructura no respondió.
- **El proceso diario es del módulo** (línea de comandos) y lo dispara una tarea programada del
  servidor, como el refresco de indicadores que ya existe.

## Cómo se revisa (además de DocTest)

- Script de base corrido en una copia de DEMO, con su vuelta atrás (las filas de `core.tablas`, aprobadas
  por Rodolfo con el análisis de impacto).
- **Análisis de impacto aprobado por Rodolfo**: (a) escribir `core.empresas` desde recursos nuevos (qué
  más lee esas columnas: Tools, DNATO, AssetPlanner, el disparador); (b) la librería `AltaEmpresa`:
  DNATO-UC-002 a 005 contra el registro copiado, en verde, antes y después de sacarla del controlador;
  (c) la tarea programada (quién la instala en cada ambiente y cómo se ve si falló).
- Una empresa dada de alta desde la Consola funciona igual que una del registro: entra su
  administrador, ve Tools y AssetPlanner (como en ADM-UC-111).
- DocTest `regresion` en verde.
- `phpcs` con PHPCompatibility para PHP 5.6 sin errores; `./mvnw clean install` del proyecto de APIs.
- **Aviso para el despliegue:** el script de despliegue sube los DataServices pero no las APIs; este
  requerimiento no agrega ni cambia APIs. La tarea programada del proceso diario se instala aparte en
  cada servidor.

## Dudas abiertas

Están en los casos de uso (campo `dudas`), para contestarlas en un solo lugar.

---

## Casos de prueba de la especificación que cubre

| CP | Qué prueba | Lo cubre |
|---|---|---|
| CP-20 | Alta de empresa: activa el plan, invita al administrador; si falla, dice qué quedó y ofrece reintentar | ADM-UC-111 |
| CP-21 | Alta con correo que ya es usuario solo crea membresía | ADM-UC-111 |
| CP-22 | Correo que falla: enlace para copiar | ADM-UC-111 (alta) y ADM-UC-112 (reenviar); la parte de usuarios es REQ-007 |
| CP-23 | Cambio directo a un plan con menos usuarios | ADM-UC-113 (aviso y aplicación). "eva@ no puede invitar (409)": lo prueba ADM-UC-091 de REQ-007 con el tope nuevo |
| CP-17 | Plan gratuito con vencimiento: fecha calculada al asignar; ajustar o extender | ADM-UC-113 (y ADM-UC-111 al alta). La columna del listado de planes: REQ-005 |
| CP-24 | Aviso 7 días antes y vencimiento | ADM-UC-116 (aviso, vencimiento, correo). "Queda en Free" y "BPM.procesos pasa a de otro plan": ver la duda de ADM-UC-116; el sombreado en Tools es T-2 (fuera de alcance) |
| CP-26 | Listado: filtros y ficha | ADM-UC-110 (filtros) y ADM-UC-112 (ficha). "Con pedido pendiente" se prueba con un pedido cargado a mano (REQ-010); "21 de 30 IA": REQ-011 |
| CP-28 | Editar datos y logo; inicial como sustituto | ADM-UC-112 (ficha, listado y Portal). "Se ve en Tools": T-3, fuera de alcance |
| CP-04 | Empresa suspendida corta sesiones y agente | ADM-UC-114 en el módulo y el ingreso copiado. Tools (T-5) y el agente (`sin_acceso`, REQ-011): fuera de alcance |
| CP-29 | Registros: notificación a infra y aprobación de plan pendiente | ADM-UC-117 (con el pendiente cargado a mano hasta REQ-010; la notificación según el contrato que se acuerde) |
| CP-107 | Usuarios de la plataforma: filtros, exportar, desde Empresas, ver actividad | ADM-UC-118. "Abre Auditoría filtrada": REQ-013 |
| CP-103 | No se desmarca el último superusuario; ban global | ADM-UC-119 |
| CP-27 | Cambio directo cancela el pedido pendiente | Fuera de alcance: pedidos, REQ-010 (engancha el cambio directo de ADM-UC-113) |
| CP-25 | Bonificación | Fuera de alcance: REQ-011 |
