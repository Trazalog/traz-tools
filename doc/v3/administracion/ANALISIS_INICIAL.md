# Módulo Administración (`traz-comp-adm`) — Análisis inicial

| Campo | Valor |
|---|---|
| Versión | 0.1 (borrador para aprobación de Rodolfo) |
| Fecha | 2026-11-04 |
| Origen | [REQ-001](<../../requerimientos/REQ-001-administracion-analisis.md>) |
| Naturaleza | Análisis **sin código**. No se programa ni se crea el repositorio |
| Fuentes | Especificación DNATO v3 0.5.2 (`doc/v3/dnato/`), relevamiento de solo lectura (`doc/v3/dnato/DNATO_v2_RELEVAMIENTO.md`), código de `traz-comp-dnato` (rama `feat/oauth-login-empresas-igual-que-el-web`), código de `traz-tools` |
| Convención | Cada afirmación cita su fuente como `ruta:línea`. Los supuestos se marcan **[SUPUESTO]**. Las decisiones que se dejan para Rodolfo se marcan **[DECISIÓN]** |

> El replanteo de Rodolfo (2026-11-03) reemplaza el principio de la especificación "DNATO v3 se
> construye sobre el DNATO actual" (`01_ESPECIFICACION_FUNCIONAL.md:8`) por estas cuatro reglas
> (`REQ-001` §"El replanteo, en cuatro reglas"): (1) mismas tablas más extensiones; (2) registración e
> ingreso copiados tal cual, DNATO en paralelo; (3) impacto en el agente (MCP) estudiado, DNATO queda
> para el agente (opción D1); (4) pantallas 100 % nuevas con datos por DataServices. Este documento
> desarrolla esas cuatro reglas en seis secciones.

---

## A. Inventario de DNATO: qué se reutiliza

Inventario completo de `traz-comp-dnato/application/`. Los nombres de archivo y el conteo se
**verificaron contra el árbol real** de la carpeta hermana; los detalles de comportamiento y las
líneas citadas vienen del relevamiento (`DNATO_v2_RELEVAMIENTO.md`), que relevó esta misma rama
(HEAD `91535a2`).

### A.1 Controllers (`application/controllers/`)

13 controllers + `Bulkload copy.php` (duplicado muerto). Leyenda: **copiar** = tal cual (regla 2) ·
**reutilizar** = se rescata la lógica, pantalla nueva (regla 4) · **descartar** = no entra al módulo.

| Controller | Propuesta | Motivo |
|---|---|---|
| `Main.php` (2104 l.) | **Copiar los métodos de identidad**; descartar el resto | Los métodos de login/registro/recuperación se copian (regla 2). Los métodos de ABM de usuarios/roles/ban (`users`, `adduser`, `changelevel`, `banuser`, `deleteuser`, …) se descartan: pantallas nuevas (regla 4) y hoy tienen los agujeros del relevamiento §1.6 |
| `Register.php` (1663 l.) | **Copiar tal cual** | Registración + alta de empresa freemium (regla 2) |
| `Bulkload.php` (826 l.) | **Reutilizar la lógica, pantalla nueva** | Carga masiva (regla 4); lógica en `Bulkloads` |
| `Oauth.php`, `Oauthlogin.php` | **Quedan en DNATO** | Los usa el agente (sección D). No se copian |
| `Cli.php` | **Queda en DNATO** | `issue_test_token` es de Ops; no es parte del módulo |
| `Empresa.php`, `Menu.php`, `Rol.php` | **Descartar: pantallas nuevas** | ABM de empresas/catálogo/roles pasa a la Consola del súper usuario (RF-20/40; hoy solo lectura o roto, ver relevamiento A-11 a A-19) |
| `Email.php`, `Test.php`, `Test_formularios.php` | **Descartar** | De prueba / sin uso / riesgo de seguridad (relevamiento S4, §8.2) |
| `Bulkload copy.php` | **Descartar** | Misma clase `Bulkload`; no ruteable; muerto (`DNATO_v2_RELEVAMIENTO.md:78`) |

### A.2 Models (`application/models/`)

| Model | Propuesta | Motivo |
|---|---|---|
| `User_model.php` (1177 l.) | **Reutilizar la lógica que llama a WSO2**; migrar lo directo a BD | Mezcla `$this->db` directo (135 usos) con REST/WSO2 (`DNATO_v2_RELEVAMIENTO.md:79`). Los métodos de login/registro que pegan a WSO2 se copian; las consultas directas a `seg.*` migran a DataServices (RNF-03) |
| `Empresas.php`, `Establecimientos.php`, `Roles.php`, `Tablas.php` | **Reutilizar la lógica que llama a WSO2, si sirve** | Ya acceden por WSO2 (`REST_CORE`/`REST_BPM`), no van directo a la base (`DNATO_v2_RELEVAMIENTO.md:325-327`) |
| `Mmenu.php` | **Reutilizar parcialmente** | El ABM de catálogo global pasa a la Consola (RF-40); la query de menú la reemplaza "Menú resuelto" (R3). La lógica residual puede descartarse |
| `Bulkloads.php` (1083 l.) | **Reutilizar** | Carga masiva: dispatcher PG/MariaDB. Se revalida el `stored_procedure` contra catálogo (RF-110) |
| `Bulkload_model.php` | **Descartar** | Muerto (0 llamadas; `DNATO_v2_RELEVAMIENTO.md:370`) |
| `OauthCode_model.php` | **Queda en DNATO** | Lo usa el agente (sección D) |

### A.3 Vistas (`application/views/`, 43 + `errors/` + subdirs `empresas/`, `menu/`, `bulkload/`, `oauth/`)

La clasificación por estilo y su inventario completo está en `DNATO_v2_RELEVAMIENTO.md` §6.3 (tabla
"Inventario de pantallas"). Resumen por grupo:

| Grupo de vistas | Propuesta | Motivo |
|---|---|---|
| Login/registro (estilo `tz-*` y `REG`): `login.php`, `login_empresa.php`, `forgot.php`, `reset_password.php`, `reset-pass-info.php`, `register.php`, `register-info.php`, `complete_password.php`, `formulario_page.php`, `crear_empresa_page.php`, `bienvenida_page.php` | **Copiar tal cual** | Regla 2 |
| Layout interno (`header.php`, `navbar.php`, `container.php`, `footer.php`) | **Descartar (reemplazadas)** | El navbar es estático y el layout es heterogéneo; el módulo vive dentro de Tools y hereda su layout |
| ABM interno (`usersList.php`, `adduser.php`, `banuser.php`, `changelevel*.php`, `changeuser.php`, `profile.php`, `settings.php`, `usuario_externo.php`, `empresas/*`, `menu/*`) | **Descartar: pantallas nuevas** | Regla 4 |
| Carga masiva (`bulkload/index.php`, `bulkload/resultado.php`) | **Reutilizar la lógica, pantalla nueva** | Regla 4 |
| OAuth (`oauth/login_step1.php`, `oauth/login_empresa.php`, `oauth/login_error.php`) | **Quedan en DNATO** | Sección D |
| Muertas/huérfanas (`user.php`, `list_usuarios_externos.php`, `nuevo_rol.php`, `index.php`, `complete.php`, `register_success.php`, `registro_completo.php`, `formulario_registro.php`, `*_old`) | **Descartar** | `DNATO_v2_RELEVAMIENTO.md:1116` |

### A.4 Librerías / helpers / config (solo lo que toca la identidad)

| Pieza | Propuesta | Motivo |
|---|---|---|
| `libraries/Password.php` (PBKDF2 `sha256:1000:salt:hash`) | **Copiar** | Necesario para validar el hash existente de `seg.users`; está acoplado al SP de BD (`DNATO_v2_RELEVAMIENTO.md:1324`) |
| `libraries/BPM.php`, `REST.php`, `Sendmail.php`, `Recaptcha.php` | **Copiar/reutilizar** | Login, alta de empresa y correos los usan |
| `libraries/Userlevel.php` | **Descartar** | Mapea `seg.users.role` 1..4; `role` deja de autorizar (R7) |
| `helpers/sesion_helper.php` | **Descartar** | Tools tiene el propio; `validarSesion()` de DNATO ni siquiera se llama (`DNATO_v2_RELEVAMIENTO.md:82`) |
| `config/constants.php`, `config/config.php`, `config/database.php`, `config/jwt.php`, `config/oauth_clients.php` | **Copiar solo lo de identidad** | `jwt.php`/`oauth_clients.php` quedan en DNATO (agente). `constants.php` se limpia de secretos (RNF-05) |

**Nota sobre "copiar tal cual":** copiar **comportamiento**, no los defectos conocidos. Los
correctivos C-2 (control de acceso central), C-4 (CSRF), C-5 (definición de admin) y C-6 (IDOR) nacen
resueltos en el módulo nuevo (ver sección F), incluso en la registración y el ingreso copiados.

---

## B. Tablas y DataServices

### B.1 Qué tablas lee/escribe hoy DNATO y por qué canal

Fuente: `DNATO_v2_RELEVAMIENTO.md` §2.0 y §2.1 (tabla "Tablas, vistas y funciones"). DNATO accede a
PostgreSQL `seg.*`, `core.*`, `sta.*` **por dos vías**: directa (`$this->db`) y por WSO2 MI.

| Canal | Config | Qué lo usa |
|---|---|---|
| BD directa PostgreSQL (`default`, base `tools_prod_t`) | `dnato/application/config/database.php:76-97` | `User_model`, `Mmenu`, `Roles`, `Tablas::obtener`, `Bulkloads` (dispatcher PG), `OauthCode_model` |
| BD directa MariaDB AssetPlanner (`assetplanner`, `assetv2`) | `database.php:116-133` | Solo `Bulkloads::ejecutarCargaMariaDB` |
| WSO2 Data Service `REST_CORE` = `…/services/COREDataService` | `constants.php:176-177` | `Empresas`, `Establecimientos`, `Tablas::obtenerTabla`, `Bulkloads::obtenerEntidadesNegocio` |
| WSO2 API `API_CORE` = `…/tools/core` (toolsCOREAPI) | `constants.php:98` | Alta de usuario (`/usuario`), alta empresa (`/empresa`), rol (`/rol/asignar`, `/rol/desasignar`) |
| WSO2 API BPM `REST_BPM` = `…/tools/bpm` (Bonita) | `constants.php:97` | `Roles::getBpmGroups/…`, `Empresas::crearRolBpm/mapearActorBpm` |

Tablas relevantes (detalle de columnas en `DNATO_v2_RELEVAMIENTO.md:346-371`):

| Tabla | Rol | Lectura/escritura |
|---|---|---|
| `seg.users` | usuarios + `role` global + ban | L/E directa + alta vía API |
| `seg.memberships_users` (group, role, email) | membresía usuario↔empresa↔rol | L directa; E directa (deprecado) y vía `/rol/asignar` |
| `seg.users_business` (email, busines) | marca "dado de alta para esta empresa" | L/E directa + vía API |
| `seg.roles` | niveles globales 1..8 | L/E |
| `seg.menues` | catálogo de funcionalidades (global) | L/E directa (ABM) |
| `seg.memberships_menues` | permiso rol↔opción | L/E directa |
| `seg.menues_users_vw` (vista) | permiso resuelto (DDL no versionada) | L vía DS |
| `seg.settings` | configuración global | L/E directa |
| `seg.tokens` | invitación / reset | L/E |
| `seg.oauth_codes` | códigos OAuth (agente) | L/E (queda en DNATO) |
| `core.empresas` | empresas (PK `empr_id`) | L directa; E vía `/empresa` |
| `core.tablas` | variables de sistema | L vía DS `GET /tablas/{tabla}` |
| `core.iconos`, `core.encargados_depositos` | íconos; encargados | L/E |
| `prd.establecimientos`, `alm.alm_depositos` | alta de empresa | E vía DS |
| `sta.entidades_negocio` + `sta.*` staging/SP | carga masiva | L/E |
| `seg.insert_usuario_con_hash(...)` (función) | alta de usuario con hash | vía DS `POST /usuario` |

### B.2 DataServices: qué existe y qué falta

- **`COREDataService.dbs`** (en `traz-tools/_backend/api/ToolsAPIProject/…/data-services/COREDataService.dbs`)
  es **la copia vigente**: 95 resources, única con `GET /empresa/{empr_id}`, `PUT /empresa/asset-id`,
  `GET /usuario/esadmin/…`, `POST /assetuser/empresa` (`DNATO_v2_RELEVAMIENTO.md:333`). **Aclaración de
  Rodolfo (2026-11-04):** los servicios de datos viven en el repo de `traz-tools`
  (`_backend/api/ToolsAPIProject/…/artifacts`); las copias que aparecen en `dnato/development/…` (90 y 78
  resources) son **restos viejos de desarrollo**, no son lo desplegado. La fuente de verdad es la copia
  de `traz-tools` (95 resources).
- **`toolsCOREAPI.xml`** (`context /tools/core`) orquesta alta de usuario/empresa/rol contra DS + Bonita +
  AssetPlanner (`DNATO_v2_RELEVAMIENTO.md:326`; `toolsCOREAPI.xml:1`).
- **Recursos que ya sirven tal cual para las pantallas nuevas:** alta/consulta de usuario y empresa,
  asignar/desasignar rol, `GET /tablas/{tabla}`, `GET /empresa/{empr_id}`, establecimiento/depósito por
  defecto, `entidades_negocio` (carga masiva), `getMenuByUserPermission`.
- **Recursos que faltan (los pide la especificación):** plan, membresía con estado, cuota MCP,
  auditoría, catálogo con tipo/publicación, menú custom, funcionalidad activa por empresa, variables de
  sistema con historial, "Consumir cuota", "Menú resuelto", "Estado de membresía", "Funcionalidad
  visible", "Cambiar empresa validado" (`02_MODELO_Y_REGLAS.md` §2 y §4). Todos se **agregan** como
  recursos nuevos, sin tocar lo que v2 usa (compatibilidad v2).

### B.3 Extensiones que pide la especificación (02 §2)

`02_MODELO_Y_REGLAS.md:49-75` define qué atributo nuevo se cuelga de qué entidad existente. Resumen:

- `core.empresas`: plan, estado (activa/suspendida), estado del plan, vencimiento, marca "usó plan gratuito", contacto admin.
- `seg.users`: marca `superusuario`; `role` deja de autorizar (se conserva por compatibilidad).
- `seg.memberships_users`: estado (`invitado/activo/baneado/baja`), motivo, fecha, quién, menú asignado.
- `seg.menues`: tipo (`pantalla/accion/tool_mcp`), texto, ayuda, publicación; módulos `MCP` y `SEG`.
- Nuevas: plan, funcionalidad del plan, funcionalidad activa, menú custom, asignación de menú, período de cuota, consumo MCP, pedido de plan, interés, auditoría, resultado de carga masiva.

### B.4 Criterio membresía → empresa (R8)

**Decisión de Rodolfo (2026-11-04):** el criterio único es
`core.empresas.nombre = seg.memberships_users."group"`, porque es el que ya usa el disparador de alta de
empresa (el "trigger" que arma el menú inicial y los permisos). **No** se compara contra `descripcion` y
**no** se agrega una columna con el número de empresa.

Esto reemplaza el estado actual, donde conviven dos criterios (`DNATO_v2_RELEVAMIENTO.md:379`):

- DNATO (`User_model::getEmpresasDeUsuario`) matchea `group` contra `nombre` **o** `descripcion`.
- Los data services `getUsersXGroup` (`CORE.dbs:97`) y `getEsAdminXEmailEmpresa` (`CORE.dbs:102`, que usa
  traz-tools para decidir admin) matchean **solo contra `descripcion`**.

Quedan tres tareas derivadas de esta decisión (se describen, **no se ejecutan** en este análisis):

**B.4a — Corregir una sola vez las membresías que hoy matchean solo por `descripcion`.**
- El riesgo son las membresías cuyo `"group"` no coincide con ningún `nombre` pero sí con una
  `descripcion`: con el criterio nuevo (solo `nombre`), ese usuario dejaría de ver esa empresa.
- *Propuesta:* renombrar el `"group"` de esas membresías para que valga exactamente el `nombre` de la
  empresa (el valor canónico), una sola vez y por script de solo escritura controlado.
- *Impacto en Bonita (importante):* los roles de Bonita llevan el **nombre de la empresa** en su texto:
  el grupo se llama `<empr_id>-<nombre>` y el rol `<empr_id>-<rolBase> <empresa>`
  (`DNATO_v2_RELEVAMIENTO.md:380`; `dnato/application/models/Empresas.php:145,173`). Si se renombra solo
  `seg.memberships_users."group"` y no el nombre del grupo/rol en Bonita, la sincronización entre la
  tabla y Bonita se rompe (el login resuelve empresas desde la tabla, pero los permisos/menús de Bonita
  quedan con el nombre viejo). Por eso el arreglo debe **tocar las dos puntas a la vez** (tabla y
  Bonita), conservando el prefijo `<empr_id>-`. Es un correctivo de identidad (🔴): se planifica con
  Rodolfo y no se ejecuta acá.
- *Supuesto mío (sentido común):* la cantidad de membresías afectadas es chica (en desarrollo eran 7, y
  todas de cuentas de prueba), pero hay que medirlo en DEMO y en la copia de producción para confirmarlo.

**B.4b — Impedir nombres de empresa repetidos en el alta.**
- Hoy el alta de empresa no garantiza que `nombre` sea único (y el alta manual desde el panel tiene el
  chequeo de duplicado **comentado**; `DNATO_v2_RELEVAMIENTO.md:843`, `Empresa.php:71-74`).
- *Propuesta:* en los dos puntos de alta (autorregistro `Register::guardarEmpresa` y alta desde la
  Consola `Empresa::agregarEmpresa`), antes de crear, verificar que no exista otra empresa **activa** con
  el mismo `nombre` normalizado (sin mayúsculas ni espacios sobrantes). Si existe, rechazar con un
  mensaje claro (o pedir un nombre distinto). Esto hace que `nombre` sirva de clave confiable para el
  criterio de B.4.

**B.4c — Alinear `getUsersXGroup` y `getEsAdminXEmailEmpresa` sin romper lo que devuelven a v2.**
- Estos dos data services hoy matchean por `descripcion`; con la decisión deben matchear por `nombre`.
- *Cómo se alinea sin tocar lo que v2 ya consume:* (1) **primero** se corrige la data (B.4a) y se impide
  repetidos (B.4b); (2) recién después se cambia la condición interna de la consulta de `descripcion` a
  `nombre`, **manteniendo idénticos** el nombre del recurso, la ruta y las columnas que devuelve. Como
  la data ya quedó alineada por `nombre`, el resultado es el mismo conjunto de filas que antes: v2 no
  ve ningún cambio en lo que recibe, solo deja de depender de `descripcion`.

**Medición (solo lectura, la corre Rodolfo).** El script
`dnato/scripts/sql/verificar-membresias-vs-empresas.sql` es de solo lectura. Para esta decisión se
miden, en DEMO y en la copia de producción (nunca contra producción directa):
1. usuarios y membresías que quedarían **sin empresa** usando solo `nombre` (con el listado);
2. cuántas de esas membresías hoy matchean **únicamente por `descripcion`** (son las de B.4a);
3. empresas **activas** con el mismo `nombre` (ignorando mayúsculas y espacios) (son las de B.4b).
El paso a paso y las consultas están en la tarea T-SQL del plan.

---

## C. Registración e ingreso copiados

### C.1 Lista completa de lo que hay que copiar (regla 2)

Para que la registración y el ingreso funcionen igual, se copian:

**Controllers y métodos**
- `Main::register`, `procesarRegistro` (`Main.php:1206-1304`, `1913-2058`), `complete` (`:1344-1435`), `successregister` (`:1307`), `successresetpassword` (`:1326`).
- `Main::login` (`:1452-1551`), `checkLoginUser` (`:64`), `seleccionar_empresa` (`:1560-1654`), `_finalizarLogin` (`:1679-1714`), `logout` (`:1734`), `forgot` (`:1742`), `reset_password` (`:1851`).
- `Register::register_success` (`:23`), `guardarFormularioRegistro` (`:185`), `crearEmpresa` (`:247`), `guardarEmpresa` (`:507`), `getEstados`/`getLocalidades` (`:837`/`:853`), `registro_completo` (`:870`).

**Vistas** (estilos `tz-*` y `REG`): `login.php`, `login_empresa.php`, `forgot.php`, `reset_password.php`,
`reset-pass-info.php`, `register.php`, `register-info.php`, `complete_password.php`, `formulario_page.php`,
`crear_empresa_page.php`, `bienvenida_page.php`.

**Estilos**: los bloques CSS del sistema `tz-*` (login/olvido/reset/selección) y del sistema "registro"
(`.logo-container`, Ubuntu) están embebidos por vista y se copian junto a ellas
(`DNATO_v2_RELEVAMIENTO.md:1056-1059`). **Decisión de Rodolfo (2026-11-04):** se copian **tal cual**,
sin unificar (el login y el registro no se tocan y no tienen maqueta nueva).

**Constantes/config**: `DE`, `DS`, `DNATO` (URLs), `TOOLS_ADMIN_USER`, `REGISTRACION_PASSWORD_DEFAULT`,
`FORMULARIO_REGISTRO_ID` (= 72), `BONITA_URL`, `API_CORE`, `REST_CORE`, `REST_BPM`, `REST_CORE_PAISES`
(`dnato/application/config/constants.php`). Los secretos se sacan a variables/entorno (RNF-05); no se
copian en claro.

**Llamadas a WSO2 / Bonita / AssetPlanner**
- `API_CORE/usuario/registro`, `API_CORE/usuario/bpm-asset`, `API_CORE/empresa` (toolsCOREAPI).
- `REST_CORE/establecimiento`, `REST_CORE/deposito*`, `REST_CORE/assetuser/add`, `REST_CORE/empresa/{id}`.
- `REST_BPM` (Bonita): `BPM::getUser` en login; roles/actores en alta de empresa.
- AssetPlanner: alta de usuario y vínculo `empr_id_mysql` (resuelto vía `REST_CORE/empresa/{id}`).

**Acceso directo a base (excepción aprobada — 2026-11-05).** Los métodos de registración e ingreso
copiados **siguen accediendo directo a la base** (PostgreSQL), igual que hoy en DNATO. Es una excepción
aprobada por Rodolfo a la regla "todos los datos pasan por WSO2", para poder comparar en paralelo con
DNATO (mismas tablas, mismos accesos). Pasarlos a WSO2 queda para una tarea posterior. **Las pantallas
nuevas no tienen esta excepción:** sus datos van por DataServices.

Lista de accesos directos que se copian (los métodos son de `dnato/application/models/User_model.php`,
salvo que se indique; líneas según `DNATO_v2_RELEVAMIENTO.md`):

| Método | Tabla | Operación | Flujo |
|---|---|---|---|
| `User_model::checkLogin` | `seg.users` | SELECT | login |
| `User_model::getEmpresasDeUsuario` | `seg.memberships_users` ⋈ `core.empresas` | SELECT | login + selección de empresa |
| `User_model::gruposSinEmpresa` | `seg.memberships_users` | SELECT (log) | login |
| `User_model::chekEmpresaByEmprId` | `seg.memberships_users`/`core.empresas` | SELECT | selección de empresa |
| `User_model::getUserInfoByEmail` | `seg.users` | SELECT | recuperar contraseña |
| `User_model::isDuplicate` / `existeRazonSocial` / `validarTelefonoPorPais` / `obtenerPaisesRegistracion` | `seg.users` / `core.empresas` / `core.tablas` | SELECT | registro |
| `User_model::insertToken` | `seg.tokens` | INSERT | registro / recuperar |
| `User_model::isTokenValid` | `seg.tokens` | SELECT | activar / restablecer |
| `User_model::updateUserInfo` | `seg.users` | UPDATE | activar cuenta |
| `User_model::updatePassword` | `users` (sin schema `seg.`) | UPDATE | restablecer contraseña |
| `User_model::updatePass` | `seg.users` | UPDATE | cambiar contraseña |
| `User_model::getAllSettings` | `seg.settings` | SELECT | login / cabecera |
| `Roles::obtener` (`models/Roles.php`) | `seg.roles` | SELECT | niveles |
| `Register::crearEmpresa` (`controllers/Register.php:262-266`) | `seg.users` | `$this->db` directo | alta de empresa |

> Nota: la **alta de empresa** en sí (`guardarEmpresa`) y la activación del usuario en Bonita/AssetPlanner
> (`complete` → `/usuario/bpm-asset`) sí van por WSO2; el acceso directo convive con esas llamadas, como
> hoy. Lo que se copia es la **combinación** exacta de accesos directos y llamadas WSO2 que ya usa DNATO.

**Correos**: `CI_Email` protocolo sendmail, plantillas `Sendmail::sendRegister/sendForgot/sendBienvenidaEmpresa`
(`DNATO_v2_RELEVAMIENTO.md:1188-1197`).

**Usuarios por defecto y establecimiento por defecto**: los que crea `guardarEmpresa` con
`REGISTRACION_PASSWORD_DEFAULT` + `Establecimientos::*` + `crearRolBpm`/`mapearActorBpm`
(`Register.php:1019`, `1069-1160`).

### C.2 La excepción pública dentro de Tools

> **Cambio de Rodolfo (2026-11-10), reemplaza la decisión de abajo:** el control **no** se hace para
> todo Tools sino **solo dentro del módulo** (controlador base propio de `traz-comp-adm`, REQ-002).
> Llevarlo a Tools queda como deuda técnica, hallazgo H-091 de `doc/hallazgos/REGISTRO.md`.

Tools exige sesión iniciada (`Dash::index` redirige a `DNATO.main/login` si no hay `empr_id`,
`application/controllers/Dash.php:21,45-48`), pero registración e ingreso son **públicos** (los usa un
visitante sin sesión). **Decisión de Rodolfo (2026-11-04):** la excepción se resuelve con un **control
general de Tools**, no con un control propio del módulo. En concreto: un `MY_Controller`/hook global de
Tools que exija sesión para todo, **salvo** la lista blanca pública `login`, `register`, `forgot`,
`reset_password`, `complete`, `seleccionar_empresa`, `logout` (y los AJAX de
`getEstados`/`getLocalidades`/`guardarFormularioRegistro`). El módulo hereda ese control; no arma el suyo.

Se verifica además que no quede ningún método público sin chequeo (G1), a diferencia del DNATO actual
donde `procesarRegistro`, `base64url_*`, `guardarFormularioRegistro` son ruteables por convención
(`DNATO_v2_RELEVAMIENTO.md:136,168-173`).

### C.3 Convivencia en paralelo

Las dos versiones escriben en las mismas tablas y en Bonita, así que un usuario o empresa creados por
una funcionan en la otra. Puntos a respetar:

- **Sesión compartida por cookie y archivos**: mismo `sess_cookie_name = ci_session`, mismo path `/`,
  mismo host, mismo `save_path` (`DNATO_v2_RELEVAMIENTO.md:513-523`). `sess_expiration` difiere (7200 en
  DNATO, 0 en Tools). **Decisión de Rodolfo (2026-11-04):** se usa el valor de Tools (0 = sin límite), y
  ese tiempo se deja **configurable** en `constants.php` (una constante, no un número suelto en el
  código), para poder cambiarlo por ambiente sin tocar código.
- **Claves de sesión** que arma cada una: DNATO escribe `seg.users` completo (menos `password`) +
  `empr_id` + `userIdBpm` + `groupBpm` (`DNATO_v2_RELEVAMIENTO.md:486-504`). El módulo copiado debe
  escribir las **mismas claves** para que Tools (`empresa()`, `validarSesion()`,
  `Dashs::obtenerMenu`) las lea igual.
- **¿Tools acepta las dos sesiones?** Sí, si el módulo copia las mismas claves: Tools solo lee
  `empr_id`/`groupBpm`/`email` de la sesión (`application/helpers/sesion_helper.php`,
  `application/models/Dashs.php`). **[SUPUESTO]** — se valida en REQ-003 con las pruebas DNATO-UC-001 a 008.

### C.4 Redirección futura (se describe, no se hace)

El día que se decida redirigir, cambian: las URLs de hoy `traz-comp-dnato/main/register` y
`traz-comp-dnato/main/login`, la constante `DNATO` de Tools (`application/config/constants.php:93`), los
enlaces en correos (`complete/token/…`, `reset_password/token/…`) y los de la web comercial.
**Decisión de Rodolfo (2026-11-04):** esto queda como **último paso** del desarrollo, con un **análisis
de impacto** propio que se estudia al final. En este trabajo solo se describe; no se ejecuta (REQ-001
§"Qué NO hace").

### C.5 Cómo se prueba que quedó igual

Las pruebas `DNATO-UC-001` a `DNATO-UC-008` del catálogo DocTest (`traz-tools/doctest/catalogo/dnato/`)
tienen que pasar **contra la copia** igual que pasan contra DNATO: registro (UC-001), alta de empresa
(UC-002 a 005), login con empresa (UC-006), logout (UC-007), recuperar contraseña (UC-008)
(`DNATO_v2_RELEVAMIENTO.md:1272`). Es el criterio de aceptación de REQ-003.

---

## D. Impacto en el agente (MCP)

Hoy el agente depende de DNATO para la **identidad** (decisión ADR-008): DNATO emite el token que
valida el APIM.

### D.1 Qué ata al agente a DNATO

| Pieza | Dónde | Rol |
|---|---|---|
| `Oauth.php`: `authorize`, `token`, `jwks`, `authorization_server_metadata`, `register_client` | `dnato/application/controllers/Oauth.php` | Servidor OAuth 2.1 + PKCE, RS256, JWT con `empr_id` |
| `Oauthlogin.php` (`index`, `credentials`, `empresa`) | `dnato/application/controllers/Oauthlogin.php` | Login OAuth (credenciales + selección de empresa) |
| `JwtIssuer.php` | `dnato/application/libraries/JwtIssuer.php` | Firma el JWT (claims `empr_id`, `empr_id_mysql`, `sub`, `role`, …) |
| Dirección de DNATO como emisor | `dnato/application/config/jwt.php` + `DNATO_ISSUER`/`DNATO_PUBLIC_URL` | `iss` del token y del discovery |
| Config del APIM como administrador de claves ("Key Manager Dnato", RS256 + JWKS) | APIM (fuera de repo) | Valida el JWT |
| `oauth-discovery.xml` (RFC 9728 PRM) | `_backend/api/ApimDiscoveryProject/src/OAuthDiscovery_1.0.0/oauth-discovery.xml` | Publica `authorization_servers` = `trazalog.dnato.oauth.url` (property `trazalog.dnato.oauth.url`, `:21`) |
| `JwtValidator.xml` | `_backend/api/…/sequences/JwtValidator.xml` | **NO se invoca en el flujo MCP** (referencia histórica; `:2-15`). La validación real la hace el APIM vía Key Manager Dnato |
| `EmprIdFromHeader.xml` | `_backend/api/…/sequences/EmprIdFromHeader.xml` | Deriva `empr_id` y `empr_id_mysql` del header `X-JWT-Assertion` (backend JWT que firma el APIM); setea `jwt_empr_id` / `jwt_mysql_empresa_id` (`:19-48`) |
| `toolsCOREAPI.xml`, `toolsMANAPI.xml` (+ `toolsMCPAPI.xml`, `toolsALMAPI.xml`, `toolsPANAPI.xml`) | `_backend/api/ToolsAPIProject/…/apis/` | Consumen `jwt_empr_id`/`jwt_mysql_empresa_id`; nunca aceptan `empr_id` del caller (`toolsMANAPI.xml:3,20`) |

Cadena: cliente MCP → `oauth/authorize`/`token` (DNATO emite JWT con `empr_id`) → APIM valida con JWKS
de DNATO y firma `X-JWT-Assertion` → MI `EmprIdFromHeader` extrae `empr_id` → tools resuelven datos de
esa empresa.

### D.2 Decidido por ahora: D1 — DNATO queda para el agente

No se toca nada de lo anterior. El módulo nuevo puede convivir porque **comparte las mismas tablas**:
un usuario creado por la registración copiada termina en `seg.users`/`seg.memberships_users` igual que
hoy, y por lo tanto puede hacer el flujo OAuth y obtener un JWT con su `empr_id`. **[SUPUESTO a validar
en REQ-003]** que el JWT emitido por DNATO para un usuario creado desde el módulo nuevo funciona contra
el APIM sin cambios (mismas tablas, mismas claims).

**Qué se rompería si el módulo nuevo cambiara el modelo de identidad sin migrar DNATO:**
- Si cambia la resolución membresía→empresa (R8) en los data services pero no en DNATO, el login web
  (DNATO) y el OAuth resolverían empresas distintas.
- Si cambia la definición de admin (R7) sin tocar `getEsAdminXEmailEmpresa` (`CORE.dbs:102`), Tools
  decidiría admin distinto que DNATO.
- Si cambia el emisor del token sin reconfigurar el APIM y los clientes, el agente deja de autenticar.

Por eso la sección B (R8) y la sección E (R7/C-5) se cierran **antes** de tocar identidad en el módulo.

### D.3 Futuro: D2 — mover la identidad del agente al módulo (solo se describe)

Requeriría: cambiar el emisor del token al módulo nuevo (nuevas rutas `oauth/*` dentro de
`traz-comp-adm`), reconfigurar el APIM (Key Manager apuntando al nuevo issuer/JWKS), actualizar
`oauth-discovery.xml` (`authorization_servers` → URL del módulo) y **volver a registrar los clientes
del agente**. No entra en este trabajo.

### D.4 Servicios nuevos que necesita el agente

La especificación agrega al agente el chequeo previo a cada `tools/call`: el servicio **"Consumir
cuota"** (`02_MODELO_Y_REGLAS.md:147`, RF-81). En D1 lo sirve **DNATO** (v3); en D2 lo serviría el módulo
nuevo. El resto de servicios de §4 (Menú resuelto, Estado de membresía, Contexto) los consumen
traz-tools y el Portal, no el agente directamente.

---

## E. Impacto en Tools

### E.1 Puntos T-1 a T-10 (§9b), ajustados al replanteo

`02_MODELO_Y_REGLAS.md:254-265` lista el impacto obligatorio en Tools. Ajustado al replanteo (el
"Portal de la empresa" pasa a ser el **módulo nuevo** dentro de Tools, no una app DNATO aparte):

| # | Punto | Ajuste al replanteo |
|---|---|---|
| T-1 | Tablero del administrador (`Dash::index`) | Igual: tarjeta resumida de plan/uso para administradores. La sirve el módulo nuevo |
| T-2 | Menú operativo (`menu_helper`, `getMenuByUserPermission`) | Igual: "Menú resuelto" (R3). Reemplaza la regla "todos los hijos" (`menu_helper.php:122-125`) |
| T-3 | Barra superior (`perfil.php`) | "🏢 Mi empresa" deja de ser un salto a otro sistema: **abre el Portal (con su diseño propio, "← Ir a Tools" para volver)** en la misma pestaña. "🔑 Consola" (súper usuarios) idem. Se quita "Usuarios" del menú del perfil (`perfil.php:115`) |
| T-4 | Cambio de empresa (`Dash::cambiarDeEmpresa` + 3 copias) | Igual: llama al servicio validado; nunca escribe `empr_id` del POST (correctivo C-1 🔴) |
| T-5 | Chequeo central en cada pedido | Igual: hook/`MY_Controller` con sesión + membresía + funcionalidad visible |
| T-6 | Vista de presentación | La abre el módulo nuevo (ya no "página de DNATO" externa) |
| T-7 | Pantallas que leen `configuraciones/formulario_*` | Igual (servicio "Formulario para un punto de uso", R9) |
| T-8 | Combos de formularios | Igual |
| T-9 | Tope de usuarios en altas de Tools | Igual: toda alta pasa por la orquestación y respeta R4 |
| T-10 | Regresión E2E `doctest` | Igual: specs de menú/navbar se actualizan en la entrega que los toca |

### E.2 Dónde entra el módulo en el menú y quién lo ve

- El **Portal de la empresa** (secciones Inicio, Usuarios, Roles y accesos, Menús, Funcionalidades,
  Formularios, Plan, Uso de IA, Cargas masivas, Actividad) se entra por el botón "🏢 Mi empresa" de la
  barra superior, **visible solo para administradores** de la empresa activa (RF-45).
- La **Consola** (Empresas, Registros, Planes, Catálogo, Formularios globales, Usuarios, Auditoría,
  Variables) se entra por "🔑 Consola", **solo súper usuarios** (RF-46).
- **El Portal y la Consola tienen diseño propio** (layout "portal" de las maquetas): marca Trazalog +
  logo de la empresa (o su inicial), barra lateral clara, y el botón "← Ir a Tools" para volver
  (`mockups/index.html:11`, `mockups/inicio-admin.html:22-46`). Al presionar "Mi empresa", **se sale del
  contexto visual de Tools** y se entra a ese diseño propio, en la misma pestaña. **Decisión de Rodolfo
  (2026-11-04):** se respeta ese diseño de las maquetas; no se toma ninguna decisión que rompa la
  experiencia pensada ahí.
- El menú operativo de Tools **no** contiene opciones del Portal ni de la Consola (R3, RF-44).

### E.3 Todo lo de Tools que hoy apunta a DNATO

Relevado con grep sobre `application/` (lista completa en el grep de este análisis):

| Punto | Ubicación | Qué pasa |
|---|---|---|
| Constante `DNATO` = `http://localhost/traz-comp-dnato/` | `application/config/constants.php:93` | Sigue apuntando a DNATO **mientras DNATO corra en paralelo**. Cuando se redirija (C.4), cambia a la URL del módulo |
| `TOOLS_ADMIN_USER` = `admin@gmail.com` (difiere del de DNATO) | `constants.php:104` | Deja de autorizar (R7/C-5); se usa solo para migrar la marca `superusuario` (M-6) |
| `login()`, `logout()`, `editar()`, `list_usuarios()` | `application/helpers/login_helper.php:5-33` | `login`/`logout`/`editar` se redirigen al módulo al hacer el cutover de ingreso; `list_usuarios` (→ `DNATO.main/users`) **desaparece** (reemplazada por el Portal) |
| `Dash::cambiarDeEmpresa` | `application/controllers/Dash.php:140-148` | Correctivo C-1: validar contra membresías activas (servicio "Cambiar empresa") |
| Redirecciones a `DNATO.main/login` en controllers de módulos (`Stockvalorizado`, `Lote`, `Notificacion`, `Cotizacion`, …) | grep `DNATO.'main/login'` | Siguen apuntando a DNATO mientras corra en paralelo; migran al cutover |
| `sesion_helper.php:554` → `DNATO.main/logout` | `application/helpers/sesion_helper.php` | Ídem |
| Botón "Usuarios" (perfil) → `DNATO.main/users` | `application/modules/traz-comp-pan/views/layout/perfil.php` y copias | Se reemplaza por "🏢 Mi empresa" (T-3) |
| Copias de `cambiarDeEmpresa`/`Dash` en módulos (`ddpe-tools-pro`, `traz-comp-codigos`, `traz-comp-pan`) | `DNATO_v2_RELEVAMIENTO.md:507` | Se corrigen junto con C-1 |

---

## F. Cómo se arma el módulo

### F.1 Nombre y forma (ya decididos)

Submódulo **`traz-comp-adm`** con **repositorio propio**, montado en
`application/modules/traz-comp-adm`, igual que `traz-comp-pan` (decisión 1 de REQ-001; el repositorio lo
crea Rodolfo antes de REQ-002).

### F.2 Estructura de carpetas

Tomando `traz-comp-pan` como referencia (`application/modules/traz-comp-pan/{controllers,models,views,helpers,config}`):

```
application/modules/traz-comp-adm/
├── controllers/          # Identidad (copiada) + Portal + Consola
├── models/               # WSO2 / DataServices (nada directo a BD)
├── views/                # Pantallas nuevas + vistas de identidad copiadas
├── helpers/              # sesion, wso2, login, menu
├── config/               # prefijo y config del módulo
└── (constante de prefijo)
```

Constante de prefijo para cross-module loading, siguiendo el patrón existente en
`application/config/constants.php` (`PRD`, `PAN`, `ALM`, `MAN`, `FRM`, `BPM`): **`ADM`** =
`'traz-comp-adm/'`. **Confirmado por Rodolfo (2026-11-04).**

**Dos layouts dentro del módulo** (según las maquetas): el **Portal de la empresa** y la **Consola**
usan el layout "portal" (marca Trazalog + logo, barra lateral clara, "← Ir a Tools" — ver
`mockups/inicio-admin.html` y las páginas `consola-*.html`), distinto del menú operativo de Tools. Es
diseño propio, **no** una pantalla más dentro del menú de Tools. El módulo trae entonces: las vistas de
identidad copiadas (estilo `tz-*`/`REG`), y el layout "portal" para Portal y Consola.

### F.3 Cómo hereda de Tools sesión, empresa, menú y permisos

El módulo corre **dentro** de Tools, así que hereda por diseño (no reimplementa):

- **Sesión obligatoria**: entra por el control del propio módulo (cambio del 2026-11-10; antes decía
  "el chequeo central de Tools (T-5)"), excepto la lista blanca pública
  de identidad (C.2).
- **Empresa activa**: siempre de la sesión (`empresa()` → `empr_id`), nunca del navegador (G2, RNF-02).
- **Menú operativo**: lo dibuja Tools. El Portal y la Consola tienen su **propia** barra lateral (layout
  "portal"), separada del menú operativo; desaparece el navbar estático de DNATO.
- **Permiso por pantalla**: validación central "Funcionalidad visible" (R2) en cada pedido (RF-94).

Con esto, los correctivos **C-2** (control de acceso central), **C-4** (CSRF) y **C-6** (pertenencia por
id) **nacen resueltos en el módulo nuevo** — no hay que "arreglar" código copiado, sino construir el
esqueleto (REQ-002) con `MY_Controller` + hook + CSRF desde el primer día, y copiar encima solo el
comportamiento de identidad.

### F.4 Orden de construcción propuesto

Se usa `PROMPT_CLI_DNATO_V3_BUILD.md` (entregas E0–E12, `:47-60`) como lista de qué hay que hacer,
repartido en los requerimientos de `requerimientos/README.md:40-45`. Propuesta (los números de REQ se
confirman al escribirlos):

| REQ | Contenido | Se apoya en |
|---|---|---|
| REQ-001 | Este análisis (aprobarlo) | — |
| REQ-002 | Esqueleto `traz-comp-adm`: dentro de Tools, sesión, permiso por pantalla, CSRF, empresa de sesión (C-2/C-4/C-6) | REQ-001 aprobado |
| REQ-003 | Registración e ingreso copiados (C.1) en paralelo; DNATO-UC-001 a 008 en verde | REQ-002 |
| REQ-004+ | Pantallas nuevas en el orden E0→E12: base/control de acceso (E0), atributos y entidades (E1), catálogo y planes (E2), funcionalidades (E3), usuarios/roles/perfil (E4), empresas/registros (E5), menús custom (E6), plan y pedidos + "Elegí tu plan" (E7), cuota MCP (E8), visibilidad (E9), auditoría/uso (E10), cargas masivas (E11), formularios (E11b), migración completa (E12) | REQ-002 y el orden que proponga REQ-001 |

**Nota de alcance:** E8 (cuota MCP) y su enganche en el Gateway son una derivación del frente MCP; E11b
es una derivación con `traz-comp-formularios`. El orden exacto de REQ-004 en adelante y el reparto
"qué hace el módulo vs qué hace Tools vs qué hace el frente MCP" quedan como **[DECISIÓN]** de Rodolfo
al aprobar este análisis.

> **Decisiones de Rodolfo (2026-11-10) sobre esta nota:**
> - **Orden:** el de la especificación, E0→E12, una entrega por requerimiento (REQ-004 = E1 más lo que
>   faltó de E0, hasta REQ-016 = E12). Lista en `requerimientos/README.md`.
> - **E8, cuota del agente:** el módulo hace las pantallas y los servicios de cuota; el freno en el
>   portero de WSO2 es del frente del agente (MCP) y va aparte.
> - **E11b, formularios:** el módulo hace las pantallas; los cambios dentro de `traz-comp-formularios`
>   van en un requerimiento aparte, con análisis de impacto, porque es un módulo compartido.

---

## Decisiones de Rodolfo (2026-11-04 y 2026-11-05) y pendientes

**Decisiones ya tomadas (cierran las dudas del plan):**

1. ✅ **Criterio membresía→empresa (R8):** `core.empresas.nombre = seg.memberships_users."group"` (es el
   que usa el disparador de alta de empresa). Sin comparar `descripcion` ni agregar columna (B.4).
2. ✅ **Tiempo de sesión:** el de Tools (sin límite), dejándolo **configurable** en `constants.php` (C.3).
3. ✅ **Estilos de login/registro:** se copian **tal cual**, sin unificar (C.1).
4. ✅ **Excepción pública de identidad:** ~~control general de Tools~~ → **control solo dentro del
   módulo** (cambio del 2026-11-10; propagarlo a Tools es la deuda H-091) (C.2).
5. ✅ **Prefijo del módulo:** `ADM` confirmado (F.2).
6. ✅ **Portal/Consola:** diseño propio (layout "portal" de las maquetas), respetando las maquetas; al
   presionar "Mi empresa" se sale del contexto visual de Tools (E.2, F.2). Se estudian las maquetas a
   detalle y no se toman decisiones que rompan esa experiencia.
7. ✅ **Redirección futura:** último paso del desarrollo, con análisis de impacto al final (C.4).
8. ✅ **Secretos de configuración:** se dejan para una tarea de infraestructura aparte.
9. ✅ **Servicios de datos:** la fuente de verdad es `traz-tools/_backend/api/ToolsAPIProject/…/artifacts`
   (95 resources); las copias en `dnato/development/…` son restos viejos, no lo desplegado (B.2).
10. ✅ **Acceso directo a base en registración/ingreso (2026-11-05):** los métodos copiados siguen
    accediendo **directo a la base** igual que hoy en DNATO (excepción aprobada a la regla "todo por
    WSO2", para comparar en paralelo). Pasarlos a WSO2 queda para una tarea posterior. **Las pantallas
    nuevas no tienen esta excepción.** Lista de accesos en C.1.

**Supuestos marcados en el cuerpo:**
- C.3 — Tools acepta la sesión del módulo copiado si se copian las mismas claves (a validar en REQ-003).
- D.2 — el JWT de DNATO para un usuario creado desde el módulo funciona contra el APIM sin cambios.
- B.4a — la cantidad de membresías afectadas por el criterio nuevo es chica (en desarrollo eran 7, de
  prueba), pero hay que confirmarlo con la medición.

11. ✅ **Orden y reparto de REQ-004 en adelante (2026-11-10):** orden E0→E12; de E8 y E11b el módulo
    hace las pantallas y lo de WSO2 y `traz-comp-formularios` va aparte (nota de F.4).

12. ✅ **Cambios de base aditivos (2026-11-10):** crear tablas nuevas y agregar columnas **optativas**
    (que aceptan vacío o tienen valor por defecto), índices y funciones nuevas lo decide el equipo, sin
    aprobación de Rodolfo. Siguen necesitando su aprobación: cambiar o borrar algo existente, columnas
    obligatorias en tablas existentes y migraciones que cambian filas existentes.
13. ✅ **Schema de las tablas nuevas (2026-11-10):** todas en `seg`, como las actuales. Las columnas nuevas
    de tablas existentes de otro schema (`core.empresas`, `frm.formularios`) se quedan en su tabla.
14. ✅ **Cargas masivas (2026-11-10):** son **todo o nada**. Los procedimientos que valen son los de la
    base, no los del repositorio; Pablo los compara y versiona antes de construir REQ-014.

15. ✅ **Más cambios de base que decide el equipo (2026-11-10):** llenar una tabla nueva con datos
    existentes, y agregar filas nuevas en `core.tablas` sin cambiar las existentes.
16. ✅ **Formularios (2026-11-10):** en este plan de trabajo está **prohibido tocar cómo se muestran, se
    dibujan o se completan** los formularios en Tools; el módulo hace solo el ABM (REQ-015). Entran
    aparte, en REQ-017 "Formularios globales en Tools": los combos de tareas con los formularios
    globales (cambio a `FRMDataService`), el alta de empresa apuntando a los globales (cambio al
    disparador) y pasar a globales solo los formularios que usa ese disparador. El corte final de DNATO
    pasa a ser REQ-018.

**Pendientes de ejecución (no bloquean la aprobación del análisis):**
- Correr `verificar-membresias-vs-empresas.sql` en DEMO y copia de producción, con las 3 mediciones de
  B.4 (usuarios/membresías sin empresa por `nombre`, cuántas matchean solo por `descripcion`, empresas
  con nombre repetido). Paso a paso en la tarea T-SQL del plan.
- Estudiar a detalle las maquetas del Portal/Consola antes de REQ-002, para respetar el diseño (decisión 6).

## Qué NO hace este documento

- No programa nada ni crea el repositorio del módulo (REQ-002 y siguientes).
- No cambia DNATO: sigue en producción como está.
- No decide: propone. Las decisiones las toma Rodolfo al aprobar este análisis.
