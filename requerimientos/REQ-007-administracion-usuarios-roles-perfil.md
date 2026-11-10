# REQ-007 · Módulo Administración — Usuarios, roles y perfil en el Portal

## Objetivo

Séptimo trabajo de Pablo para el módulo **Administración** (`traz-comp-adm`): las tres pantallas con las
que el administrador maneja a la gente de su empresa (**Usuarios**: invitar, alta directa, banear, dar de
baja, cambiar rol, con el tope del plan; **Roles y accesos**: a qué funcionalidades entra cada rol) y la
pantalla **Mi perfil** de cualquier persona (datos, foto, teléfono y contraseña), más el servicio
"Estado de membresía" que usan el ingreso copiado y el módulo. Lo leen Pablo para planificar y Rodolfo
para aprobar el cambio de base y el análisis de impacto. **No** cubre la Consola → Usuarios del
superusuario (ban global, marcar superusuarios: [REQ-008](REQ-008-administracion-consola-empresas.md)),
los menús ([REQ-009](REQ-009-administracion-menus.md)), la carga masiva de usuarios (REQ-014) ni que
Tools corte las sesiones abiertas de un baneado (derivación H-091). Lista completa en
[`README.md`](README.md).

| Campo | Valor |
|---|---|
| Estado | **Borrador**: Rodolfo tiene que contestar las dudas de los casos, y aprobar el análisis de impacto sobre el menú y la barra de Tools |
| Se apoya en | [REQ-002](REQ-002-administracion-esqueleto.md) (controlador base, Portal), [REQ-003](REQ-003-administracion-identidad.md) (ingreso copiado, `Password`, correo), [REQ-004](REQ-004-administracion-base-y-atributos.md) (`seg.membresias_estado`, `seg.users.cambiar_password`, auditoría, variables, definición única de administrador, `ADMDataService.dbs`), [REQ-005](REQ-005-administracion-catalogo-y-planes.md) (`seg.planes.tope_usuarios`) y [REQ-006](REQ-006-administracion-funcionalidades.md) (funcionalidades activas, R2) |
| Entrega de la especificación | **E4** de `doc/v3/dnato/PROMPT_CLI_DNATO_V3_BUILD.md`: Portal → Usuarios, Roles y accesos, Perfil; estados de membresía; invitar; alta directa; banear; baja; cambio de rol en línea; tope; servicio "Estado de membresía"; mensajes RF-03. CU-35 a 40, 52; CP-03, 70 a 76, 78, 79, 105, 113 |
| Casos de uso | `ADM-UC-090` a `ADM-UC-098` en `doctest/catalogo/adm/` |
| Repos que se tocan | `traz-comp-adm` (tres pantallas, página de aceptar invitación, modelo `Membresias`, ajustes al ingreso copiado); `traz-tools`: recursos **nuevos** en `ADMDataService.dbs`, script de base chico y, del núcleo, `application/views/layout/perfil.php` (dos enlaces) |
| Riesgo | 🔴 Las columnas nuevas en `seg.tokens` y `seg.users` (lista en "Datos") son todas optativas: **cambio de base aditivo, lo decide el equipo (regla de Rodolfo del 2026-11-10)**. Sigue en rojo por el **núcleo de Tools**: (1) Roles y accesos escribe en `seg.memberships_menues`, de donde sale hoy el menú de Tools en todas las pantallas de producción; (2) se escriben `seg.users` y `seg.memberships_users` desde el módulo (por la API existente y por recursos nuevos); (3) en la barra de Tools se saca "Usuarios" del menú del perfil y "Perfil" pasa a abrir el del módulo → **análisis de impacto aprobado por Rodolfo**. Las APIs `API_CORE/usuario`, `/rol/asignar` y `/rol/desasignar` se **llaman** como están: no se modifican |

---

## Para qué sirve

- Hoy el administrador maneja usuarios en DNATO con pantallas que tienen problemas serios: la baja
  **borra el usuario** de todas sus empresas (A-04), el baneo es **global** (A-08), los endpoints que
  asignan roles no piden sesión (C-2), se puede pedir por número a un usuario de otra empresa (C-6) y no
  hay tope de usuarios.
- Al agregar un rol a alguien que ya tiene roles, la pantalla de DNATO **reenvía todos los roles** y el
  primero repetido hace fallar el lote entero (`traz-comp-dnato/application/controllers/Main.php:947-1022`:
  recorre `dataRole`, llama `/rol/asignar` por cada uno y, al primer error, deshace los que ya asignó).
  La pantalla nueva **manda solo el cambio**.
- Para vender por plan hace falta que el tope de usuarios se respete **en el servidor**.
- "Menú por rol" de DNATO (A-19) toma la opción del campo equivocado, corta el rol con `explode('-')` y
  pisa todas las opciones del rol al editar. Roles y accesos lo reemplaza sin esos defectos.
- La persona no puede cambiar su contraseña con seguridad (hoy no se pide la actual, ID-08) ni elegir su
  foto.

## Quién lo usa

- **Administrador** de una empresa: Mi empresa → Usuarios y Roles y accesos.
- **Usuario** (cualquier persona con sesión y membresía activa): Mi perfil; también es quien recibe el
  baneo o la baja.
- **Visitante**: la persona invitada que todavía no activó su cuenta.
- **Supervisor**, **Mantenedor**, **Planificador** (perfiles de operación): roles con los que se prueban
  los accesos y los cambios de rol.

## Qué tiene que hacer

1. Listado de personas de la empresa con estado, lugares usados del plan y tope (RF-70, RF-72, R4) →
   **ADM-UC-090**.
2. Invitar a una persona: nueva, que ya es usuaria, que estaba de baja, que ya es miembro; reenviar
   (CU-35, RF-71) → **ADM-UC-091**.
3. Aceptar la invitación con el enlace (un solo uso, con vencimiento) (CU-35, G8) → **ADM-UC-092**.
4. Crear con contraseña inicial y obligar a cambiarla al primer ingreso (CU-39, RF-76) →
   **ADM-UC-093**.
5. Banear y reactivar en la empresa, con el servicio "Estado de membresía" y el mensaje en el ingreso
   (CU-36, RF-73, RF-03) → **ADM-UC-094**.
6. Dar de baja de la empresa sin borrar al usuario (CU-37, RF-74) → **ADM-UC-095**.
7. Cambiar el rol de una persona en línea, mandando solo el cambio, con compensación si falla Bonita
   (CU-38, RF-75) → **ADM-UC-096**.
8. Roles y accesos: por rol, una casilla por funcionalidad activa (CU-40, RF-77) → **ADM-UC-097**.
9. Mi perfil: datos, teléfono por país, foto (subir, cámara, avatar) y contraseña con reglas en vivo
   (CU-52, RF-111) → **ADM-UC-098**.

## Qué NO hace

- **No reimplementa el alta de usuario.** La creación de un usuario es **siempre** `POST API_CORE/usuario`
  (toolsCOREAPI), la misma operación que usan el alta de DNATO y la Consola; la membresía es **siempre**
  `POST API_CORE/rol/asignar` y `/rol/desasignar`. El módulo nunca escribe en `seg.users_business`, en
  Bonita ni en AssetPlanner por su cuenta (regla del repo: "la lógica de negocio va en las APIs").
- **No modifica toolsCOREAPI** ni ningún recurso existente de `COREDataService`.
- **No corta las sesiones abiertas en Tools.** Un baneado deja de entrar al módulo y al ingreso copiado
  en el próximo pedido; en las pantallas de Tools sigue hasta que Tools tenga el chequeo central (punto
  T-5, deuda **H-091**, ver la duda de ADM-UC-094). El rechazo del agente (`sin_acceso`) es de la cuota
  (REQ-011) y del frente MCP.
- **No cambia DNATO.** DNATO no conoce `seg.membresias_estado` ni `cambiar_password`: quien entre por el
  ingreso de DNATO no ve el baneo ni la obligación de cambiar la contraseña hasta la redirección final
  (ver la duda de ADM-UC-094).
- **No hace la Consola → Usuarios** (ban global, superusuarios, todas las empresas): REQ-008.
- **No asigna menús** si REQ-009 todavía no está construido (ver la duda de ADM-UC-091): la columna
  "Menú" muestra "Predeterminado" y el selector no aparece.
- No crea roles: los roles son los de Bonita que se crean al dar de alta la empresa (D-09).
- No muestra consultas de IA por persona (columna "IA esta semana"): llega con REQ-011; hasta entonces
  muestra "—".
- No hace la carga masiva de usuarios ni su tope (REQ-014), aunque usa la misma cuenta de lugares.
- No cambia la recuperación de contraseña ni el registro copiados (REQ-003).

---

## Cómo se arma

### Persona, membresía y estado

- **Persona de la empresa** = un correo con al menos una fila en `seg.memberships_users` con `"group"` =
  nombre de la empresa de la sesión (criterio B.4), **o** una fila en `seg.membresias_estado` de esa
  empresa (para las que están de baja y ya no tienen rol).
- **Estado** = el de `seg.membresias_estado`; si no hay fila (membresías que DNATO sigue creando en
  paralelo después de M-5), cuenta como `activo` **[SUPUESTO]**.
- **Roles de la persona** = sus filas de `seg.memberships_users` en la empresa. Puede tener más de uno
  (la clave es grupo + rol + correo); el estado es uno solo (`02_MODELO_Y_REGLAS.md` §2).
- **Lugares usados (R4)** = personas en estado distinto de `baja`. **Tope** = `seg.planes.tope_usuarios`
  del plan de la empresa (`core.empresas.plan_id`). Mientras `plan_id` sea nulo (hasta M-3, REQ-016) o
  el tope sea nulo, **no hay tope**.
- **Roles de la empresa** (para elegir al invitar y en Roles y accesos): los roles de Bonita de la
  empresa, por `REST_BPM` (la misma fuente que DNATO, `traz-comp-dnato/application/models/Roles.php:55-98`),
  mostrados con el nombre base ("Supervisor", sin el nombre de la empresa). Es la respuesta a la duda de
  REQ-009 (ADM-UC-131): Menús usa esta misma lista.

### Un solo modelo para todo cambio de membresía

Todo lo que cambia una membresía pasa por **un modelo del módulo** (por ejemplo `Membresias`) y por
ningún otro lado. Cada operación:

1. Toma empresa y quién hace el cambio **de la sesión**; el correo de la persona viene del navegador y se
   **verifica** que sea persona de esa empresa (G2, CP-76). Si no, "no existe".
2. Verifica las reglas en el servidor (tope, último administrador, uno mismo), aunque la pantalla no
   ofrezca el botón.
3. Llama a las operaciones existentes (`API_CORE/usuario`, `/rol/asignar`, `/rol/desasignar`) **solo con
   el cambio**, y a los recursos nuevos de `ADMDataService` para estado, token y auditoría.
4. Si un paso falla, deshace los anteriores (G9) y la pantalla dice qué pasó.

Con los datos que pide `/rol/asignar` hoy (`traz-comp-dnato/application/controllers/Main.php:985-997`):
correo, grupo, rol, `group_id` y `role_id` de Bonita, sesión de Bonita, `empr_id` y `role_base` (para el
acceso a AssetPlanner). El módulo **aporta** esos datos; la decisión de qué grupo de AssetPlanner le toca
sigue en la API.

### Invitar (RF-71)

| Situación | Qué hace |
|---|---|
| Correo nuevo | `POST API_CORE/usuario` con nombre, correo, `status = pending`, `banned_users = unban`, `business` = nombre de la empresa y una contraseña **al azar que nadie conoce** (la API la exige; la persona pone la suya al aceptar). Después `/rol/asignar` con el rol elegido, estado `invitado` y enlace |
| Ya es usuario de otra empresa | **Solo** `/rol/asignar`, estado `invitado` y enlace (no se crea usuario: la API rechaza el duplicado) |
| Estaba de baja en esta empresa | Se reutiliza: `/rol/asignar`, estado `baja` → `invitado`, enlace |
| Ya es miembro | No hace nada: "Ya es miembro (estado: <estado>)" con la acción que corresponde (Reactivar si está baneado; Reenviar si está invitado) |
| Tope alcanzado | El servidor rechaza (409) con el mensaje de RF-72, antes de llamar a nada |

- Menú opcional: si REQ-009 está construido, se guarda la asignación por persona con su recurso
  (`PUT /menu/asignacion`).
- **Enlace:** fila en `seg.tokens` de tipo `invitacion`, con código **no predecible**
  (`openssl_random_pseudo_bytes`, disponible en PHP 5.6), vencimiento = hoy + variable
  `validez_invitacion_dias` (REQ-004) y marca de uso. Solo se guarda el código **cifrado** (hash)
  **[SUPUESTO]**; en el correo va el código en claro. Reenviar invalida el anterior y manda uno nuevo.
- **Correo:** con el mecanismo copiado en REQ-003 (`CI_Email` + `sendmail`), remitente de la variable
  `remitente_correo`. Si falla, la invitación **queda hecha** y la pantalla muestra el enlace para
  copiar (RNF-08, CP-22).

### Aceptar la invitación

Página **pública** nueva del módulo, `traz-comp-adm/invitacion/aceptar/<código>` (se agrega a la lista
pública del controlador base). No se usa el `main/complete` copiado porque ese, al activar, vuelve a dar
de alta al usuario en Bonita y AssetPlanner (`/usuario/bpm-asset`), y su enlace tiene la regla vieja
(vale el mismo día y se puede reusar) que REQ-003 copia tal cual (ver la duda de ADM-UC-092).

- Código inexistente, usado o vencido → mensaje y nada más.
- Persona **nueva**: define su contraseña con las reglas de `password_strong` (las de hoy, mínimo 10),
  queda `status = approved`, la membresía pasa a `activo`, el código queda usado y entra a Tools con esa
  empresa.
- Persona que **ya tenía usuario**: confirma con su contraseña **[SUPUESTO]** y la membresía pasa a
  `activo` (ver la duda de ADM-UC-091).

### Alta directa con contraseña inicial (RF-76)

Desde el mismo formulario de invitar ("Crear con contraseña inicial"): `POST API_CORE/usuario` con la
contraseña que escribe el administrador (mismas reglas), `status = approved`, después `/rol/asignar`,
estado `activo` y `seg.users.cambiar_password = sí` (columna de REQ-004). No manda correo. Solo para
correos nuevos (si ya es usuario no se le cambia la contraseña: se invita).

El **ingreso copiado** (REQ-003) suma un paso: si `cambiar_password` es sí, después de la contraseña
correcta muestra "Cambiá tu contraseña" y no deja seguir hasta cambiarla; al cambiarla, la marca vuelve
a no.

### Banear, reactivar y dar de baja (RF-73, RF-74)

- **Banear:** estado `baneado` con motivo opcional. No toca Bonita ni `seg.memberships_users`: conserva
  el lugar y los roles. **Reactivar:** vuelve a `activo`.
- **Baja:** `/rol/desasignar` por **cada** rol de la persona en la empresa (Bonita y tabla), estado
  `baja`, y se quita su menú por persona si lo tenía. **No se borra el usuario** ni se toca
  `seg.users_business` **[SUPUESTO]**. Si un `/rol/desasignar` falla, se vuelven a asignar los que ya se
  quitaron.
- **No se ofrece ni se acepta** banear o dar de baja a uno mismo, ni al último administrador activo de la
  empresa. Como quien usa el Portal es administrador, "el último administrador" es él mismo; la regla
  importa sobre todo en la Consola (REQ-008), que usa el mismo modelo.

### Servicio "Estado de membresía" (§4)

`ADMDataService GET /membresia/estado/{email}/empresa/{empr_id}` → `activo`, `invitado`, `baneado`,
`baja`, `empresa_suspendida` o `plan_vencido`, más el correo de un administrador activo de la empresa
(para el mensaje). Lee `seg.membresias_estado` y `core.empresas.estado` / `estado_plan` (columnas de
REQ-004; suspender y vencer los hace REQ-008).

Lo usan:

1. **El controlador base del módulo**, en cada pedido: si la persona no está `activo` en la empresa de
   la sesión, cierra la sesión y manda al ingreso con el mensaje (no aplica a las páginas públicas).
2. **El ingreso copiado** (REQ-003): las empresas en estado `baneado`, `baja` o `invitado` no se ofrecen
   para elegir (RF-03). Si no queda ninguna y la razón es un baneo o una baja, muestra el texto de la
   variable `texto_suspension_miembro` (CP-03); si no, el mensaje de hoy ("Tu usuario no tiene ninguna
   empresa asignada…").

Tools lo usará con la derivación T-5 (fuera de alcance).

### Cambiar el rol en línea (RF-75)

- **Cambiar** un rol por otro: `/rol/desasignar` del viejo y `/rol/asignar` del nuevo. Si el segundo
  falla, se vuelve a asignar el viejo (compensación, CP-79). `/rol/asignar` ya deshace su propia fila si
  falla Bonita (`toolsCOREAPI.xml:1011-1031`).
- **Agregar** un rol: un solo `/rol/asignar`, solo de ese rol. Si ya lo tiene, no se llama: "Ya tiene
  ese rol".
- **Quitar** un rol (si le queda al menos otro): un solo `/rol/desasignar`. Quitar el único rol es una
  baja y lleva a esa acción.
- Sacarle el rol Administrador al último administrador (uno mismo) se rechaza con el mismo mensaje del
  baneo.

### Roles y accesos (RF-77) — escribe `seg.memberships_menues` (núcleo)

- Una fila por rol de la empresa; al elegir uno, una casilla por cada funcionalidad **activa** de la
  empresa (REQ-006), de tipo pantalla, acción o herramienta de IA (la maqueta muestra "IA: consultar
  equipos").
- La casilla marcada = el rol tiene acceso según R2 de REQ-006, **incluida** la regla de hoy para las
  hijas: si el rol tiene asignado el padre y ninguna hermana, tiene acceso a todas las hijas.
- **Guardar manda solo lo que cambió:** por cada casilla marcada, una fila (grupo = nombre de la empresa,
  rol = "<rol base> <empresa>", módulo, opción); por cada desmarcada, `eliminado = 1` en su fila, como
  hace hoy DNATO (`traz-comp-dnato/application/models/Mmenu.php:247-262`). Si la desmarcada era una hija
  con acceso solo por el padre, se escriben explícitas las hermanas que siguen marcadas, para que Tools
  (que muestra todas las hijas cuando no hay ninguna asignada, `menu_helper.php:122-125`) deje de
  mostrarla. Ver la duda de ADM-UC-097.
- El rol **Administrador** se muestra y **no se edita**.
- Todo en una sola operación del DataService (cambio + auditoría `rol.accesos`).

### Mi perfil (RF-111)

- Página del módulo `traz-comp-adm/perfil` con un permiso nuevo del controlador base: **miembro**
  (sesión con membresía `activo` en la empresa de la sesión), además de `administrador` y
  `superusuario` de REQ-002. Usa el marco del Portal; quien no es administrador ve en el menú lateral
  solo "Mi perfil" **[SUPUESTO]**.
- **Datos:** nombre, apellido, teléfono con la validación por país del registro copiado (REQ-003),
  idioma y zona horaria (columnas nuevas). El correo no se cambia.
- **Foto:** subir archivo, tomar con la cámara (`getUserMedia`, que el navegador solo permite en
  `https`) o elegir un avatar de un set con licencia libre **guardado en el módulo**, sin servidores de
  afuera (recomendación DiceBear, licencias MIT o CC0 según el estilo). Vista previa recortada a
  cuadrado; "Quitar". Se guarda en `seg.users.image` / `image_name` (columnas que ya existen y usa
  `Main::updateuser` de DNATO, `Main.php:611-660`) **[SUPUESTO]** de formato: el mismo que hoy.
- **Contraseña:** actual, nueva y repetir; las reglas de `password_strong` se ponen en verde al
  cumplirse y el botón se habilita con todo en verde. El servidor verifica la actual y las reglas otra
  vez. El cifrado y la verificación los hace la librería `Password` copiada en REQ-003, la misma de hoy
  (ver la duda de ADM-UC-098 sobre cómo se lee el valor cifrado).
- **Mis empresas:** tabla con empresa, rol, plan y estado (de la persona de la sesión).

### Lo que cambia en la barra de Tools (núcleo)

En `application/views/layout/perfil.php` (la misma vista que tocó REQ-004 para "🏢 Mi empresa"):

- Se saca "Usuarios" del menú del perfil (`perfil.php:115`, lleva a `DNATO.main/users`): lo reemplaza
  Mi empresa → Usuarios (CP-106, T-3).
- "Perfil" / "Editar" (hoy `login_helper.php` `editar()` → DNATO) pasa a abrir `traz-comp-adm/perfil`
  **si el módulo está montado**; si no, queda como hoy.

Análisis de impacto obligatorio, aprobado por Rodolfo antes de construir: las copias de la barra en
submódulos (`traz-comp-pan` y otras, ver la duda de ADM-UC-030), qué pasa si el módulo no está, y la
prueba de regresión de la barra.

### Auditoría

En la misma operación que el cambio (`seg.auditoria`, REQ-004): `miembro.invitar`, `miembro.reenviar`,
`miembro.activar` (al aceptar), `miembro.alta_directa`, `miembro.banear`, `miembro.reactivar`,
`miembro.baja`, `miembro.rol` (agregar, quitar o cambiar, con anterior y nuevo), `miembro.menu`,
`rol.accesos` (rol, funcionalidades marcadas y desmarcadas), `perfil.password` (sin valores). Nombres de
CP-73, CP-75 y CP-78; los demás **[SUPUESTO]**. Cuando el cambio pasa por una API existente (que no
audita), el modelo escribe la auditoría **después** de que la API respondió bien.

---

## De dónde sale cada dato

| Dato | De dónde | Cómo |
|---|---|---|
| Sesión, empresa, correo, es administrador | Sesión y `ADMDataService GET /usuario/es-admin/…` | Ya existe (REQ-004) |
| Personas de la empresa con roles, estado, menú, último acceso (`seg.users.last_login`), lugares y tope | `ADMDataService GET /empresa/{empr_id}/personas` (paginado en el servidor, búsqueda y filtros) | **NUEVO** (lo pide también REQ-009) |
| Una persona de la empresa (verifica pertenencia) | `ADMDataService GET /empresa/{empr_id}/persona/{email}` | **NUEVO** |
| Lugares usados y tope | `ADMDataService GET /empresa/{empr_id}/lugares` | **NUEVO** |
| Roles de la empresa | `REST_BPM /roles` (Bonita, por WSO2), como `Roles::getBpmRoles` | Ya existe |
| Crear usuario | `API_CORE POST /usuario` | Ya existe (no se modifica) |
| Asignar / quitar rol | `API_CORE POST /rol/asignar`, `POST /rol/desasignar` | Ya existe (no se modifica) |
| Cambiar estado (invitado, activo, baneado, baja) | `ADMDataService PUT /membresia/estado` (con auditoría) | **NUEVO** |
| Estado de membresía (servicio §4) | `ADMDataService GET /membresia/estado/{email}/empresa/{empr_id}` | **NUEVO** |
| Enlace de invitación: crear, leer, marcar usado | `ADMDataService POST /invitacion`, `GET /invitacion/{hash}`, `PUT /invitacion/usada` | **NUEVO** (sobre `seg.tokens`) |
| Activar al aceptar (contraseña y `status`) | `ADMDataService PUT /usuario/activar` | **NUEVO** |
| Marca "cambiar contraseña" | `ADMDataService PUT /usuario/cambiar-password` | **NUEVO** |
| Accesos por rol | `ADMDataService GET /empresa/{empr_id}/rol/{rol}/accesos`, `PUT /rol/accesos` | **NUEVO** |
| Funcionalidades activas | `ADMDataService GET /empresa/{empr_id}/funcionalidades` | Ya existe (REQ-006) |
| Asignación de menú por persona | `ADMDataService PUT /menu/asignacion` | Ya existe si REQ-009 está construido |
| Perfil: leer y guardar datos y foto | `ADMDataService GET /usuario/{email}/perfil`, `PUT /usuario/perfil` | **NUEVO** |
| Contraseña: valor cifrado actual y guardar la nueva | `ADMDataService GET /usuario/{email}/password`, `PUT /usuario/password` | **NUEVO** (ver duda de ADM-UC-098) |
| Mis empresas | `ADMDataService GET /usuario/{email}/empresas` | **NUEVO** |
| Validez, remitente, textos | `ADMDataService GET /variables` | Ya existe (REQ-004) |
| Auditoría | Dentro de cada recurso que escribe, o `POST /auditoria` después de una API existente | Ya existe (REQ-004) |

**Nada va directo a la base** (la excepción de REQ-003 sigue valiendo solo para el ingreso copiado; el
paso nuevo de "Cambiá tu contraseña" y el filtro por estado usan los recursos de arriba). El `{email}` de
los recursos de perfil y contraseña sale **siempre de la sesión**.

---

## Pantallas

Maquetas `doc/v3/dnato/mockups/empresa-usuarios.html`, `empresa-roles.html` y `perfil.html`, dentro del
marco del Portal de REQ-002.

### Portal — menú lateral

| Opción | `data-testid` |
|---|---|
| "👥 Usuarios" | `adm-portal-menu-usuarios` |
| "🎭 Roles y accesos" | `adm-portal-menu-roles` |
| "Mi perfil" (en el menú del nombre de la persona, arriba a la derecha) | `adm-portal-menu-perfil` |

### Portal → Usuarios — `traz-comp-adm/portal/usuarios`

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Título y lugares | "Usuarios", "N de M lugares usados" y "en el plan <ícono> <plan> · los invitados ocupan lugar, los baneados también, los dados de baja no." Sin tope: "N lugares usados" **[SUPUESTO]** | `adm-usuarios`; `adm-usuarios-lugares` |
| Invitar | "✉️ Invitar" (solo con lugares libres) | `adm-usuarios-invitar` |
| Tope alcanzado | En lugar de "Invitar": "🚫 Llegaste al tope de M usuarios del plan X" y "Para invitar a alguien más, dá de baja a un usuario o pedí un cambio de plan.", con "Pedir cambio de plan" | `adm-usuarios-tope`; `adm-usuarios-pedir-plan` |
| Búsqueda y filtros | "🔍 Buscar por nombre o correo", "Todos los roles", "Todos los estados" (Activo, Invitado, Baneado) | `adm-usuarios-buscar`, `adm-usuarios-filtro-rol`, `adm-usuarios-filtro-estado` |
| Tabla | Usuario (nombre, correo, "· vos"), Rol (selector en línea), Menú, Estado ("Activo", "Invitado · vence <fecha>", "Baneado · <fecha>"), Último acceso, IA esta semana, acciones | `adm-usuarios-tabla`; fila `adm-usuario-<email>`; `adm-usuario-rol`, `adm-usuario-menu` |
| Acciones de la fila | "Banear", "Baja", "Reactivar", "Reenviar invitación"; en la propia, "sos vos" sin botones | `adm-usuario-banear`, `adm-usuario-baja`, `adm-usuario-reactivar`, `adm-usuario-reenviar`, `adm-usuario-vos` |
| Pie | "N lugares usados: A activos · I invitado(s) · B baneado(s) (los baneados ocupan lugar; los dados de baja no)" | `adm-usuarios-resumen` |
| Ventana Banear | "Banear a <nombre>", "<Nombre> no va a poder entrar a <empresa>, ni desde la web ni desde la IA, hasta que lo reactives. Conserva su lugar en el plan y sigue pudiendo usar otras empresas donde esté activo.", "Motivo (opcional)", "Cancelar" / "Banear" | `adm-banear`; `adm-banear-motivo`, `adm-banear-confirmar`, `adm-banear-cancelar` |
| Ventana Baja **[SUPUESTO]** | "Dar de baja a <nombre>", "Deja de ser parte de <empresa> y libera su lugar. Su usuario no se borra y lo podés volver a invitar.", "Cancelar" / "Dar de baja" | `adm-baja`; `adm-baja-confirmar` |
| Formulario Invitar | Correo, Nombre, Apellido **[SUPUESTO]**, Rol (roles de la empresa), Menú (opcional, si REQ-009 está), "Invitar"; casilla "Crear con contraseña inicial" que muestra Contraseña y Repetir con las reglas en vivo, y el botón "Crear" | `adm-invitar-form`; `adm-invitar-correo`, `adm-invitar-rol`, `adm-invitar-menu`, `adm-invitar-enviar`, `adm-invitar-con-password`, `adm-invitar-crear` |

Mensajes:

| Caso | Mensaje | `data-testid` |
|---|---|---|
| Invitación mandada **[SUPUESTO]** | "Le mandamos la invitación a <correo>. Vence el <fecha>." | `adm-usuarios-ok` |
| Correo que no salió **[SUPUESTO]** | "La invitación quedó hecha, pero no pudimos mandar el correo. Copiá este enlace y mandáselo vos: <enlace>" | `adm-usuarios-enlace` |
| Ya es miembro | "Ya es miembro (estado: <estado>)" con "Reactivar" o "Reenviar invitación" | `adm-usuarios-ya-miembro` |
| Tope (también 409 del servidor) | "Llegaste al tope de M usuarios del plan X. Para invitar a alguien más, dá de baja a un usuario o pedí un cambio de plan" | `adm-usuarios-tope` |
| Uno mismo o último administrador | "Sos la única administradora: nombrá otra antes" (CP-74; ver la duda de ADM-UC-094 sobre el género) | `adm-usuarios-error` |
| Ya tiene ese rol **[SUPUESTO]** | "Ya tiene ese rol." | `adm-usuarios-error` |
| Cambio de rol que no se pudo hacer **[SUPUESTO]** | "No pudimos cambiar el rol; quedó como estaba. Probá de nuevo en un rato." | `adm-usuarios-error` |
| Creado con contraseña **[SUPUESTO]** | "Listo. Pasale la contraseña a <nombre>: la va a tener que cambiar al entrar." | `adm-usuarios-ok` |
| Falla del servicio | "No pudimos guardar. Probá de nuevo en un rato." | `adm-usuarios-error` |

### Aceptar la invitación — `traz-comp-adm/invitacion/aceptar/<código>` (pública)

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Título **[SUPUESTO]** | "Te invitaron a <empresa>" | `adm-invitacion` |
| Contraseña | Nueva y Repetir, con las reglas en vivo; "Activar mi cuenta" | `adm-invitacion-password`, `adm-invitacion-activar` |
| Ya tenía usuario **[SUPUESTO]** | Su contraseña y "Aceptar la invitación" | `adm-invitacion-aceptar` |
| Vencido | "El enlace venció: pedile a tu administrador que lo reenvíe" (CP-113) | `adm-invitacion-vencida` |
| Usado o inexistente **[SUPUESTO]** | "Este enlace ya no sirve. Si ya activaste tu cuenta, ingresá con tu contraseña." | `adm-invitacion-invalida` |

### Ingreso copiado — pasos que se agregan

| Caso | Mensaje | `data-testid` |
|---|---|---|
| Baneado o de baja en su única empresa | "Tu acceso a <empresa> está suspendido. Comunicate con el administrador de tu empresa: <correo>" (variable `texto_suspension_miembro`, CP-03) | `adm-ingreso-suspendido` |
| Debe cambiar la contraseña **[SUPUESTO]** | "Cambiá tu contraseña" con Nueva, Repetir y las reglas en vivo; "Cambiar y entrar" | `adm-ingreso-cambiar-password` |

### Portal → Roles y accesos — `traz-comp-adm/portal/roles`

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Título | "Roles y accesos" y "A qué pantallas accede cada rol de tu empresa. Como hoy: o la tiene en el menú o no la ve." (la maqueta agrega "Reemplaza a 'Menú por rol'": ver duda de ADM-UC-097) | `adm-roles` |
| Lista de roles | "🔒 Administrador · todo · no se edita" y cada rol con "🎭 <rol>" y "N persona(s)"; nota "Los roles son los de tu empresa en Bonita (se crean al darla de alta). En esta versión no se crean roles nuevos desde acá." | `adm-roles-lista`; `adm-rol-<rol>` |
| Detalle del rol | "<rol>", "N persona(s) · <nombres> · menú: <menú>", "Guardar" | `adm-rol-detalle`; `adm-rol-guardar` |
| Casillas | Columnas "Funcionalidad activa" y "Módulo"; una casilla por funcionalidad | `adm-rol-casilla-<modulo>-<opcion>` |
| Pie | "Solo funcionalidades activas del plan. Sin casilla = no aparece en el menú ni se puede abrir por URL." | `adm-rol-pie` |

Mensajes: "Guardado ✓" (`adm-guardado`); sin cambios **[SUPUESTO]** "No hay cambios para guardar."
(`adm-rol-sin-cambios`); falla "No pudimos guardar. Probá de nuevo en un rato." (`adm-rol-error`).

### Mi perfil — `traz-comp-adm/perfil`

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Título | "Mi perfil" y "Tus datos, tu foto y tu contraseña." | `adm-perfil` |
| Foto | Vista previa ("vista previa · se recorta a cuadrado"), "📁 Subir foto", "📷 Tomar foto", "Quitar", "O elegí un avatar" | `adm-perfil-foto`; `adm-perfil-subir`, `adm-perfil-camara`, `adm-perfil-quitar`, `adm-perfil-avatar-<n>` |
| Datos | Nombre, Apellido, Correo ("Es tu usuario; no se cambia desde acá."), Teléfono con país ("Se valida por país, como en el registro."), Idioma, Zona horaria, "Guardar" | `adm-perfil-datos`; `adm-perfil-guardar` |
| Contraseña | Actual, Nueva, Repetir, "Cambiar contraseña"; "Tiene que cumplir": "Al menos 10 caracteres", "Una mayúscula y una minúscula", "Un número", "Un símbolo", "Las dos coinciden"; "El botón se habilita cuando todo está en verde." | `adm-perfil-password`; `adm-perfil-regla-<n>`; `adm-perfil-cambiar` |
| Mis empresas | Empresa, Rol, Plan, Estado | `adm-perfil-empresas` |

Mensajes **[SUPUESTO]** (salvo los de CP-105): datos guardados "Guardamos tus datos." (`adm-perfil-ok`);
contraseña cambiada "Cambiamos tu contraseña." (`adm-perfil-ok`); actual incorrecta "La contraseña
actual no es correcta." (`adm-perfil-error`); teléfono inválido "Revisá el teléfono: no es válido para
<país>." (`adm-perfil-error`); foto muy grande "La foto tiene que pesar menos de 2 MB."
(`adm-perfil-error`); sin cámara "No pudimos usar la cámara. Podés subir una foto o elegir un avatar."
(`adm-perfil-sin-camara`).

---

## Reglas

1. Solo el administrador de la empresa activa ve y usa Usuarios y Roles y accesos; Mi perfil lo usa
   cualquier persona con membresía `activo` en la empresa de la sesión.
2. Todo correo, rol o persona que llega del navegador se verifica contra la empresa de la sesión; si no
   es de ella, "no existe" (G2, CP-76).
3. Lugares usados = personas en estado distinto de `baja`; invitados y baneados ocupan lugar (R4).
4. Con el tope alcanzado, el servidor rechaza invitar, crear con contraseña y volver a invitar a alguien
   de baja (409, mensaje de RF-72). Reactivar a un baneado no suma lugar.
5. La creación de un usuario es siempre `API_CORE/usuario`; la membresía es siempre `/rol/asignar` y
   `/rol/desasignar`. Se manda **solo el cambio**: nunca se reenvían los roles que la persona ya tiene.
6. Si un paso de una operación falla, se deshacen los anteriores y la pantalla lo dice.
7. El enlace de invitación es no predecible, de un solo uso y vence según `validez_invitacion_dias`;
   reenviar invalida el anterior.
8. No se banea, no se da de baja ni se le quita el rol Administrador a uno mismo ni al último
   administrador activo; el servidor lo rechaza aunque el pedido llegue directo.
9. Banear conserva lugar y roles; la baja quita los roles (Bonita y tabla) y libera el lugar; ninguna
   borra el usuario.
10. Un baneado o dado de baja no puede elegir esa empresa en el ingreso copiado ni usar el módulo.
11. Quien se creó con contraseña inicial no pasa del ingreso copiado sin cambiarla.
12. Roles y accesos solo ofrece funcionalidades activas; el rol Administrador no se edita; guardar
    escribe solo lo que cambió.
13. Cambiar la contraseña exige la actual correcta y las reglas de `password_strong`, también en el
    servidor.
14. Cada cambio queda en la auditoría con quién (de la sesión) y qué.

## Registro en el log

`log_message('DEBUG', '#TRAZA | ADM | <Clase> | <metodo>() ...')`. Se registran los rechazos y cada
operación de membresía (empresa, persona, acción, quién, resultado de cada llamada a la API). **Nunca**
contraseñas, códigos de invitación ni el enlace: hoy `REST.php` registra los envíos completos
(`DNATO_v2_RELEVAMIENTO.md` §7.1); el modelo no tiene que pasar la contraseña por un camino que la
registre (ver la duda de ADM-UC-093).

---

## Datos

**Cambio de base aditivo: lo decide el equipo (regla de Rodolfo del 2026-11-10).** Todas las columnas
nuevas son optativas (aceptan vacío) y no hay tablas nuevas. Si el script de REQ-004 no corrió todavía,
va dentro de él; si no, en uno chico con su vuelta atrás. Nombres **[SUPUESTO]**; Pablo puede ajustarlos en
el plan.

### Columnas nuevas en tablas existentes

| Tabla | Columna | Qué guarda | Por defecto |
|---|---|---|---|
| `seg.tokens` | `tipo` | `invitacion` (las filas de hoy quedan nulas = las de DNATO) | nulo |
| `seg.tokens` | `vence` | Fecha y hora de vencimiento | nulo |
| `seg.tokens` | `usado` | Fecha y hora en que se usó | nulo |
| `seg.tokens` | `empr_id` | Empresa de la invitación | nulo |
| `seg.users` | `idioma` | Idioma de la persona | nulo (= español) |
| `seg.users` | `zona_horaria` | Zona horaria | nulo (= `America/Argentina/San_Juan`) |

DNATO lee `seg.tokens` por código y fecha de creación (`isTokenValid`, `User_model.php:111-138`): las
columnas nuevas no cambian lo que lee. Las invitaciones guardan el código cifrado, así que nunca
coinciden con un código de DNATO **[SUPUESTO]**.

### Tablas existentes que se escriben (sin cambiar su estructura)

| Tabla | Qué se escribe | Por dónde |
|---|---|---|
| `seg.users`, `seg.users_business`, Bonita, AssetPlanner | Alta de usuario | `API_CORE/usuario` (existente) |
| `seg.memberships_users`, Bonita | Asignar y quitar roles | `API_CORE/rol/asignar` y `/rol/desasignar` (existentes) |
| `seg.users` | `password`, `status`, `cambiar_password`, nombre, apellido, teléfono, foto, idioma, zona horaria | Recursos **nuevos** de `ADMDataService` |
| `seg.memberships_menues` | Filas nuevas y `eliminado` | Recurso **nuevo** de `ADMDataService` (núcleo: menú de Tools) |
| `seg.membresias_estado`, `seg.auditoria` | Estado y auditoría | Tablas de REQ-004 |

---

## Decisiones tomadas

- **Una sola operación de alta de usuario para todos los canales** (CLAUDE.md, "la lógica de negocio va
  en las APIs"): el módulo llama a `API_CORE/usuario` y `/rol/asignar` como DNATO y la registración; no
  escribe usuarios por su cuenta. Lo nuevo (estado, enlace, auditoría) va por recursos nuevos.
- **Mandar solo el cambio** de roles: corrige el defecto de `changeLevelRolUserObject` sin tocar la API.
- **El estado vive en `seg.membresias_estado`** (REQ-004), no en `seg.memberships_users`, así v2 no nota
  nada; banear no toca Bonita, la baja sí (RF-74).
- **Página propia para aceptar la invitación**: el `main/complete` copiado vuelve a dar de alta en Bonita
  y su enlace se puede reusar; REQ-003 lo copia tal cual para que pasen DNATO-UC-001 a 008.
- **Roles de Bonita como lista de roles de la empresa**, con el nombre base: es la que usa DNATO y la que
  da los datos que pide `/rol/asignar` (contesta la duda de REQ-009).
- **Roles y accesos sigue en `seg.memberships_menues`** con `eliminado` (D-04), como DNATO, para que el
  menú de Tools siga saliendo de ahí.

## Cómo se revisa (además de DocTest)

- Script de base (aditivo) corrido en una copia de DEMO, con su vuelta atrás.
- **Análisis de impacto aprobado por Rodolfo** sobre (a) `seg.memberships_menues`: menú de Tools de un
  Supervisor de prueba antes y después de desmarcar una hija que solo tenía por el padre; (b) la barra
  de Tools sin "Usuarios" y con "Perfil" al módulo, con y sin el módulo montado.
- DocTest `regresion` en verde; DNATO-UC-001 a 008 contra el ingreso copiado, en verde.
- Un correo de otra empresa responde "no existe" en todos los recursos y acciones.
- El log no tiene contraseñas, códigos ni enlaces de invitación.
- `phpcs` con PHPCompatibility para PHP 5.6 sin errores; `./mvnw clean install` del proyecto de APIs.
- **Aviso para el despliegue:** el script de despliegue sube los DataServices pero no las APIs; este
  requerimiento no agrega ni cambia APIs.

## Dudas abiertas

Están en los casos de uso (campo `dudas`), para contestarlas en un solo lugar.

---

## Casos de prueba de la especificación que cubre

| CP | Qué prueba | Lo cubre |
|---|---|---|
| CP-70 | Invitar con lugares disponibles; enlace de un solo uso que vence en 7 días | ADM-UC-091 (invitar) y ADM-UC-092 (enlace) |
| CP-71 | Tope alcanzado: mensaje y rechazo en el servidor (409) | ADM-UC-090 (mensaje) y ADM-UC-091 (rechazo directo). Con plan cargado a mano en la base de prueba (M-3 es REQ-016) |
| CP-72 | Invitado y baneado ocupan lugar; baja no | ADM-UC-090 y ADM-UC-095 |
| CP-73 | Banear corta web y agente | ADM-UC-094 en el módulo y el ingreso copiado. El corte en Tools: derivación T-5 (H-091). El rechazo del agente: REQ-011 y frente MCP. Fuera de alcance |
| CP-74 | Ni a uno mismo ni al último administrador | ADM-UC-094 y ADM-UC-095 |
| CP-75 | Reactivar baneado | ADM-UC-094 |
| CP-76 | Alta directa obliga a cambiar la contraseña; pedido por id de otra empresa rechazado | ADM-UC-093 |
| CP-78 | Accesos por rol: casilla sí/no sobre activas; Administrador no editable | ADM-UC-097. "La dirección de MAN.ot responde 403" en Tools: derivación T-5 (fuera de alcance); en el módulo lo da REQ-006 |
| CP-79 | Cambiar rol con compensación de Bonita | ADM-UC-096 |
| CP-03 | Baneado en su única empresa ve el mensaje de suspensión | ADM-UC-094 (ingreso copiado). En el ingreso de DNATO: fuera de alcance hasta la redirección |
| CP-105 | Perfil: reglas en vivo, pide la actual, foto, teléfono | ADM-UC-098 |
| CP-113 | Enlace de invitación de un solo uso y con vencimiento | ADM-UC-092 |
| CP-22 (parte de usuarios) | Correo que falla: enlace para copiar | ADM-UC-091. La parte del alta de empresa: REQ-008 |
| CP-106 (parte) | El menú del perfil de Tools no tiene "Usuarios" | Se revisa en el pull request (análisis de impacto de la barra); el resto de CP-106 es de REQ-004 y REQ-013 |
| CP-77 | Carga masiva respeta el tope | Fuera de alcance: REQ-014 (usa la misma cuenta de lugares) |
