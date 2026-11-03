# REQ-001 · DNATO v3 — Base de seguridad (E0 recortado)

## Objetivo

Primer trabajo de DNATO v3 para Pablo: cerrar los agujeros de seguridad de DNATO que no necesitan un
workshop de arquitectura, antes de construir planes, Portal y Consola encima. Lo escribió Rodolfo con
Claude a partir de la especificación DNATO v3 0.5.2 (`doc/v3/dnato/`). Se lee al armar el plan y en cada
tarea. **No** cubre el resto de la entrega E0 de la especificación (Portal, Consola, servicio
"Contexto", definición única de administrador): eso va en REQ-002 y siguientes (ver
[`README.md`](README.md)). La forma de trabajar está en
[`doc/metodologia/GUIA_REQUERIMIENTOS_CLAUDE_DEEPSEEK.md`](../doc/metodologia/GUIA_REQUERIMIENTOS_CLAUDE_DEEPSEEK.md).

| Campo | Valor |
|---|---|
| Estado | Borrador: esperando que Rodolfo conteste las dudas y valide los casos |
| Fuente | `doc/v3/dnato/` (especificación 0.5.2): `01` §9 (correctivos C-2, C-4, C-6, C-8), `02` §3 (R8) y §9b (impacto en Tools), `03` CP-110 a 112 |
| Repos | Código: `traz-comp-dnato` (y `traz-tools` solo para el DataService de la tarea C-8). Pruebas y casos: `traz-tools/doctest` |
| Riesgo | 🟡 Toca el núcleo productivo (control de acceso de DNATO y un DataService). Cada tarea que lo toque lleva su análisis de impacto en el plan |
| Casos de uso | DNATO-UC-030, 031, 032, 033 |

---

## Para qué sirve

Hoy cualquiera puede, sin iniciar sesión, cambiar roles, borrar membresías o tocar el menú de
cualquier empresa desde una URL de DNATO; un administrador puede operar sobre usuarios de otra
empresa cambiando un número en la dirección; y un mismo usuario puede quedar asociado a una empresa
en DNATO y a otra (o a ninguna) en Tools. Todo lo que trae v3 (planes, topes, baneos) se apoya en que
esto esté cerrado: si no, se saltea con un enlace.

## Quién lo usa

- `Administrador` — administra usuarios, roles y menú de su empresa en DNATO.
- `Usuario` — cualquier usuario sin perfil de administración.
- `Visitante` — alguien sin sesión iniciada.

## Qué tiene que hacer

0. **Análisis de impacto en Tools** (tarea 0 del plan, sin código): recorrer los puntos T-1 a T-10 de
   `doc/v3/dnato/02_MODELO_Y_REGLAS.md` §9b contra el código de `traz-tools` y escribir
   `doc/v3/dnato/IMPACTO_TOOLS.md`. Rodolfo lo revisa junto con el plan. No tiene caso de uso.
1. **Todo lo de DNATO exige sesión y permiso, en un solo lugar** (correctivo C-2, RF-06) →
   DNATO-UC-030.
2. **Nada se puede ejecutar desde otro sitio ni por un simple enlace** (correctivo C-4, RNF-16) →
   DNATO-UC-031.
3. **Un administrador solo opera sobre su propia empresa** (correctivo C-6, RNF-02) → DNATO-UC-032.
4. **Cada usuario queda vinculado a la empresa correcta, con el mismo criterio en todos lados**
   (correctivo C-8, regla R8) → DNATO-UC-033.

## Qué NO hace

- **No toca la identidad:** login, elegir empresa en el login, recuperar contraseña, autorregistro y
  OAuth quedan como están. Esas rutas quedan **afuera** del control central de la tarea 1 (siguen
  siendo públicas).
- **No** arregla el cambio de empresa en Tools (`Dash::cambiarDeEmpresa`, correctivo C-1) ni el
  `redirect_uri` de OAuth (C-3): necesitan workshop 🔴.
- **No** cambia quién es administrador (C-5, ADR-016): se sigue usando la verificación de hoy.
  Unificarla necesita workshop 🔴.
- **No** rota ni saca secretos del repo (C-7): lo hace el especialista de infra. La tarea 1 sí borra
  los controllers y archivos de prueba que mandan correo.
- **No** hace pantallas nuevas, Portal, Consola ni planes.

## Pantallas

No hay pantallas nuevas. Cambia el comportamiento de las que ya existen en DNATO: Lista de usuarios,
Asignar rol, Habilitar/Inhabilitar, Eliminar usuario, Menú por rol, ABM de menú, Empresas y Carga
masiva. Lo único visible para el usuario son los mensajes de rechazo (sección Reglas).

`data-testid`: no hacen falta nuevos para los rechazos. Si una prueba necesita tocar un botón que no
tiene `data-testid`, se agrega en la vista en la misma tarea.

## Reglas

- **R-1 — Control central.** Un único punto (un `MY_Controller` del que hereden los controllers, o un
  hook de CodeIgniter) decide para cada pedido: sin sesión → al ingreso (pantalla) o 401 (pedido de
  datos); con sesión pero sin permiso de administración → 403 con el mensaje "No tenés permiso para
  hacer esto. Si lo necesitás, pedíselo al administrador de tu empresa". Lista explícita de rutas
  públicas: las de login, elegir empresa, recuperar y restablecer contraseña, registro, activación,
  `oauth/*` y `oauthlogin/*`. Todo lo que no esté en la lista exige sesión.
- **R-2 — Endpoints que hoy escriben sin sesión** (relevamiento §1.6): `Main::deleteLevelRolUser`,
  `changeLevelRolUser`, `changeLevelRolUserObject`, `cambiarNivelUsr`, `guardarMembership`,
  `borrarMembership`, `getBPMroles`, `associaterol`; `Menu::addMenuRoles`, `addMenu`, `activeMenu`,
  `activeMenuRole`, `deleteMenu`, `deleteMenuRole`, `getModulo`; `Empresa::guardar`, `obtener`;
  `Rol::guardar`, `obtener`. Todos pasan por R-1. Los rotos o sin uso se borran (`associaterol`,
  `Main::edituser`, `banuser_old`, `Bulkload copy.php`).
- **R-3 — Se borran** los controllers `Email`, `Test`, `Test_formularios` y los archivos de la raíz
  `smtp_probe.php`, `test_smtp_direct.php`, `test_email_simple.php`, `test_email_ci.php`. Después de
  borrarlos, su URL da 404.
- **R-4 — Protección contra envíos falsificados (CSRF)** activa en todo DNATO
  (`csrf_protection = TRUE`), excepto `oauth/token` y `oauth/register`. Todos los formularios y los
  pedidos por AJAX mandan el token. Un envío sin token es rechazado con "La página estaba abierta hace
  mucho. Recargala y probá de nuevo".
- **R-5 — Nada cambia de estado por GET.** `Main::deleteuser` y `Empresa::borrarEmpresa` pasan a
  POST con confirmación. Abrir su dirección en el navegador no borra nada.
- **R-6 — Pertenencia a la empresa.** Toda operación sobre un usuario por id o por correo
  (`changeleveluser`, `deleteuser`, `updateUserban`, `updateUserLevel`, `getUserInfo`) verifica que ese
  usuario tenga membresía en la empresa activa de la sesión. Si no: 404 "Ese usuario no existe en tu
  empresa" (no se dice que existe en otra). El `empr_id` o el `group` que lleguen del navegador se
  ignoran: siempre se usa el de la sesión.
- **R-7 — Un solo criterio membresía → empresa** (R8 de la especificación). El mismo criterio en
  DNATO (`User_model::getEmpresasDeUsuario`, `getEmprIdByGroup`) y en los DataServices
  (`getUsersXGroup`, `getEsAdminXEmailEmpresa` de `COREDataService.dbs`), documentado en
  `doc/v3/dnato/SERVICIOS.md`. Cuál criterio es lo decide Rodolfo (duda del caso DNATO-UC-033). Antes
  de cambiarlo, se mide con `traz-comp-dnato/scripts/sql/verificar-membresias-vs-empresas.sql` cuántos
  usuarios quedarían sin empresa en DEMO, y ese número va en el plan.
- **Compatibilidad v2:** ningún DataService ni API cambia lo que devuelve. Si un recurso necesita otro
  comportamiento, se agrega uno nuevo.
- **PHP 5.6:** nada de sintaxis de PHP 7.

## Datos

No hay tablas nuevas. Si para R-7 se decide guardar el `empr_id` en la membresía (recomendación de la
especificación), es una **columna nueva** en `seg.memberships_users`: migración de base, va con su
script versionado y su análisis de impacto aprobado antes de programarla.

## Decisiones tomadas

- El primer trabajo es solo seguridad: sin esto, todo lo que venga después se puede saltear (`01`
  §1, "Qué hay que arreglar antes").
- Se deja afuera lo que toca identidad (C-1, C-3, C-5): según `CLAUDE.md` necesita workshop previo.
- El análisis de impacto en Tools va como tarea 0 porque la especificación lo exige antes de E0 y
  condiciona cómo se prueban las entregas siguientes.

## Regresión que tiene que seguir en verde

Las pruebas existentes de DNATO, en especial DNATO-UC-001 (registro), 006 (iniciar sesión), 008
(recuperar contraseña), 009 (OAuth del agente), 013 a 019 (usuarios y roles), 022 y 023 (empresas),
025 (menú por rol) y 026-027 (carga masiva). Si una falla porque la prueba hacía algo que ahora está
prohibido a propósito (por ejemplo, un borrado por GET), se corrige la prueba en la misma tarea y se
anota en el pull request.

## Dudas abiertas

Están en el campo `dudas` de cada caso de uso. Las generales:

- ¿Algún sistema llama hoy a los endpoints de R-2 **sin sesión** a propósito (otro servidor, un
  proceso, AssetPlanner)? En el código no aparece ninguno (duda 6 del relevamiento).
- ¿En qué rama de `traz-comp-dnato` trabaja Pablo y cómo llega a DEMO? Hoy la rama activa de v3 es
  `feat/oauth-login-empresas-igual-que-el-web`; la guía dice `develop` porque DEMO despliega desde
  `develop`.
