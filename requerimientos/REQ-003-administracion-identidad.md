# REQ-003 · Módulo Administración — Registración e ingreso copiados

## Objetivo

Tercer trabajo de Pablo para el módulo **Administración** (`traz-comp-adm`): copiar dentro del módulo,
tal cual funcionan hoy en DNATO, la registración de una empresa nueva, la activación de la cuenta, el
ingreso con elección de empresa, la salida y la recuperación de contraseña, para que convivan en
paralelo con DNATO. Lo lee Pablo para planificar y programar, y Rodolfo para aprobarlo. **No** cubre
pantallas nuevas ni cambios de comportamiento de la registración (el paso "Elegí tu plan" es
[REQ-010](README.md)), ni la redirección de DNATO al módulo (último paso, con su propio análisis), ni
lo que falta de la base (REQ-004, ver [`README.md`](README.md)).

| Campo | Valor |
|---|---|
| Estado | Borrador: Rodolfo tiene que contestar las dudas de los casos y aprobar el análisis de impacto |
| Se apoya en | [REQ-002](REQ-002-administracion-esqueleto.md) (controlador base del módulo, Portal) y [`doc/v3/administracion/ANALISIS_INICIAL.md`](../doc/v3/administracion/ANALISIS_INICIAL.md) sección C completa (C.1 qué se copia, C.2 lista pública, C.3 convivencia, C.5 cómo se prueba) |
| Entrega de la especificación | Ninguna propia: sale de la regla 2 del replanteo (REQ-001). Cubre RF-01 ("se mantienen como están") de `doc/v3/dnato/01_ESPECIFICACION_FUNCIONAL.md` y la condición de E0 "CP-01, 02, 06 siguen en verde" de `PROMPT_CLI_DNATO_V3_BUILD.md` |
| Casos de uso | Criterio de aceptación: `DNATO-UC-001` a `DNATO-UC-008` (ya existen, **no se duplican**) corridos contra la copia. Casos nuevos solo para lo nuevo: `ADM-UC-010` a `ADM-UC-014` en `doctest/catalogo/adm/` |
| Repos que se tocan | `traz-comp-adm` (el código copiado) y `traz-tools` **solo** en `doctest/` (la variable que elige la dirección de identidad). `traz-comp-dnato` **no se toca** |
| Riesgo | 🔴 **Núcleo de Tools: registración e ingreso (identidad).** Análisis de impacto aprobado por Rodolfo antes de construir. No hay cambios de base de datos. El acceso directo a la base desde el código copiado es la **excepción aprobada** (análisis C.1, decisión 10 del 2026-11-05); las pantallas nuevas no la tienen |

---

## Para qué sirve

Para que el módulo nuevo tenga su propia puerta de entrada sin apagar la de hoy. Mientras DNATO siga en
producción, un usuario o una empresa creados por cualquiera de las dos puertas tienen que funcionar en
la otra, porque las dos escriben en las mismas tablas y en el mismo Bonita. Cuando la copia esté probada,
el último paso del desarrollo será redirigir DNATO a ella (con su análisis de impacto aparte).

## Quién lo usa

- **Visitante**: se registra, activa la cuenta y da de alta su empresa.
- **Usuario**: ingresa, elige empresa, sale y recupera la contraseña.
- **Administrador**: además vuelve al Portal de la empresa después de ingresar.

## Qué tiene que hacer

1. Copiar registración, activación, ingreso, salida y recuperación de contraseña, y que se comporten
   igual que en DNATO → **DNATO-UC-001 a DNATO-UC-008** corridos contra la dirección del módulo.
2. Que DocTest pueda correr DNATO-UC-001 a 008 contra la dirección del módulo, eligiendo la dirección
   base de identidad con una variable de ambiente **[SUPUESTO]** → (sin caso propio: se verifica
   corriendo esos ocho casos, ver "Cómo se revisa"; la forma de la variable está en las dudas de ADM-UC-010).
3. Llenar la lista pública del controlador base con las páginas copiadas, sin dejar ningún método
   abierto de más → **ADM-UC-010**.
4. Sesión compartida, sentido 1: ingresar por la copia y usar Tools y DNATO → **ADM-UC-011**.
5. Sesión compartida, sentido 2: ingresar por DNATO y usar el módulo → **ADM-UC-012**.
6. Que los enlaces de los correos (activar cuenta, restablecer contraseña) lleven a la copia → **ADM-UC-013**.
7. Volver a la pantalla del módulo que se pidió, después de ingresar → **ADM-UC-014**.

## Qué NO hace

- **No redirige DNATO ni lo apaga.** DNATO sigue en producción tal como está; sus direcciones
  (`traz-comp-dnato/main/login`, `main/register`, los enlaces de sus correos, los de la web comercial)
  siguen funcionando y no cambian. La redirección es el último paso del desarrollo, con su propio
  análisis de impacto (análisis C.4).
- **No cambia hacia dónde manda Tools.** El resto de Tools sigue mandando al ingreso de DNATO
  (`application/helpers/login_helper.php`, `Dash::index`) y "Salir" en Tools sigue yendo a
  `DNATO.'main/logout'`. Solo las pantallas **del módulo** mandan a la copia.
- **No cambia el comportamiento.** No suma el paso "Elegí tu plan" (REQ-010), no cambia la política de
  contraseñas, el vencimiento de los enlaces, los mensajes ni los estilos. Los defectos conocidos de
  DNATO (token de un día que se puede reusar, aviso de que el correo no existe, contraseña en el correo
  de bienvenida) se copian igual y quedan para después: corregirlos en la copia haría fallar las
  pruebas DNATO-UC-001 a 008, que son el criterio de aceptación.
- **No pasa por WSO2 lo que hoy va directo a la base** (queda para una tarea posterior, análisis C.1).
- No copia el ingreso del agente (OAuth: `Oauth`, `Oauthlogin`, `seg.oauth_codes`): queda en DNATO
  (análisis D.2).
- No copia el resto de DNATO (usuarios, roles, menús, empresas, cargas masivas, `Main::index`,
  `Main::settings`): eso lo reemplazan las pantallas nuevas de REQ-004 en adelante.
- No toca `traz-comp-formularios`: el formulario de registro (`FORMULARIO_REGISTRO_ID` = 72) se usa
  como lo usa DNATO hoy.
- No crea tablas ni columnas.
- No cambia la configuración general de Tools (`application/config/config.php`, `constants.php`),
  salvo la línea `ADM` que ya agregó REQ-002.

---

## Cómo se arma

### De qué código se parte

- Se copia de la rama `develop` de `traz-comp-dnato` (la que está en DEMO) **más el arreglo de países
  del PR traz-comp-dnato#49** (`fix/registracion-pais-empresa`, issue traz-tools#608), que al escribir
  este requerimiento **todavía no está unido**. Ese arreglo cambia `Register.php` y `User_model.php`: la
  registración detecta como repetida una empresa aunque el país esté guardado con el catálogo real, y
  guarda en la empresa el país de `paises` (por ejemplo `paisesArgentina`), no el de
  `paises_registracion` (`paises_registracionAR`). Las dos listas se unen por
  `paises_registracion.descripcion = paises.valor`. Si al construir #49 sigue sin unir, Pablo aplica su
  cambio en la copia y lo dice en el plan. (El brief lo llama hallazgo **H-090**; ver la duda de
  ADM-UC-013 sobre el número.)
- La lista exacta de qué se copia (controladores, métodos, vistas, estilos, constantes, llamadas a WSO2,
  Bonita y AssetPlanner, accesos directos a la base, correos) es la de **análisis C.1**. No se repite
  acá para que no quede desincronizada.

### Dónde queda dentro del módulo

- Los controladores copiados conservan el **nombre** de DNATO para que las direcciones queden iguales
  después de la raíz: `traz-comp-adm/main/login`, `traz-comp-adm/main/register`,
  `traz-comp-adm/main/complete/token/…`, `traz-comp-adm/register/crearEmpresa`, etc. Así las pruebas
  DNATO-UC-001 a 008 solo cambian la dirección base. Heredan del controlador base del módulo (REQ-002).
- Los modelos y librerías que usa (`User_model`, `Roles`, `Password`, `Sendmail`, `Recaptcha`, `Curl`,
  la regla `password_strong` de `MY_Form_validation`) se copian **dentro del módulo**, con nombres que
  no choquen con los de Tools. Para Bonita se usa la librería `BPM` que Tools ya carga
  (`application/libraries/BPM.php`, tiene `getUser`).
- La base: la conexión `default` de Tools (`application/config/database.php`, base `tools_prod_t`), la
  misma que usa DNATO. No se agrega otra conexión.
- Las constantes que DNATO tiene y Tools no (`DE`, `DS`, `API_CORE`, `REST_CORE_PAISES`,
  `FORMULARIO_REGISTRO_ID`, remitentes `register@` y `forgot@`, etc.) van en un archivo de
  configuración **del módulo**, no en `application/config/constants.php` de Tools.
- **Nada de secretos en el repositorio.** La contraseña por defecto de los usuarios iniciales
  (`REGISTRACION_PASSWORD_DEFAULT`) y la clave secreta de reCAPTCHA se leen de la configuración del
  servidor, sin valor escrito en el código (RNF-05). Ver la duda de ADM-UC-013.
- **Correos:** igual que DNATO, por `CI_Email` con protocolo `sendmail`
  (`/usr/sbin/sendmail -t -i -f register@trazalog.com`, HTML, UTF-8). El envío real lo hace el servidor
  (Postfix → stunnel → proveedor de correo, documentado en
  `traz-comp-dnato/development/PASAJE_PRODUCCION.md` §4): la copia usa **la misma configuración del
  servidor** y no trae usuario ni contraseña de correo. **[SUPUESTO]** Tools y DNATO corren en el mismo
  servidor en DEMO y producción (en DEMO comparten `demo.cloudtrazalog.com`), así que el Postfix ya está.
- PHP 5.6: el código de DNATO ya es 5.6; lo que se adapte, también (`phpcs` con PHPCompatibility).

### El controlador base (REQ-002) con identidad

REQ-002 dejó la lista pública vacía y, sin sesión, mandaba al ingreso de DNATO. Con este requerimiento:

1. **Lista pública** (se entra sin sesión):

   | Controlador | Métodos públicos |
   |---|---|
   | `main` | `login`, `seleccionar_empresa`, `logout`, `forgot`, `reset_password`, `register`, `complete`, `successregister`, `successresetpassword`, `checkLoginUser` |
   | `register` | `register_success`, `guardarFormularioRegistro`, `crearEmpresa`, `guardarEmpresa`, `getEstados`, `getLocalidades`, `registro_completo` |

   Los de `register` no exigen empresa en la sesión, pero **conservan el control propio que tienen en
   DNATO** (usuario recién activado en la sesión), copiado tal cual.
2. **Todo lo demás es privado.** Los métodos auxiliares que en DNATO quedaron públicos por error
   (`procesarRegistro`, `base64url_encode`, `base64url_decode`, `_email_sin_signo_mas`, `_islocal`) son
   `private` o `protected` en la copia. `Main::setdir`, `Main::index` y
   `Main::guardarFormularioRegistro` (este último no funciona en DNATO: nadie escribe `temp_user_id`)
   **no se copian**.
3. **Sin sesión**, las pantallas del módulo mandan al ingreso **copiado** (`traz-comp-adm/main/login`),
   ya no al de DNATO.
4. **Protección de envíos:** la regla de REQ-002 vale también para las páginas públicas: los formularios
   copiados llevan el código de seguridad del módulo como campo oculto (no cambia nada visible). Ver la
   duda de ADM-UC-010.

### Sesión compartida

La copia corre **dentro de Tools**, así que usa la sesión de Tools tal cual (`ci_session`, archivos, sin
vencimiento: `sess_expiration = 0`). DNATO la comparte hoy por cookie y archivos (análisis C.3). Para
que las tres partes (módulo, Tools, DNATO) se entiendan, la copia escribe **exactamente las mismas
claves** que DNATO: todas las columnas de `seg.users` menos `password`, más `empr_id`, `userIdBpm` y
`groupBpm` (y `login_pending`/`login_csrf` en el paso intermedio). Lo único que se agrega es una clave
del módulo para recordar a qué pantalla volver (ADM-UC-014).

### La pantalla a la que se vuelve

Hoy DNATO **siempre** manda al tablero de Tools después de ingresar: `setdir` ignora la dirección pedida
(las líneas que la guardaban están comentadas, `traz-comp-dnato/application/controllers/Main.php:24-31`).
La copia agrega solo esto: cuando el controlador base manda al ingreso por falta de sesión, guarda en
la sesión la dirección **del módulo** que se pidió; al terminar de ingresar (con una empresa o eligiendo
entre varias) vuelve ahí. Si no hay dirección guardada, va al tablero de Tools como hoy. La dirección
nunca se toma de un parámetro del navegador.

### Cómo se elige la dirección en DocTest [SUPUESTO]

Hoy los casos DNATO-UC-001 a 008 usan `DOCTEST_<AMBIENTE>_URL_DNATO` (`doctest/tests/e2e/config/apps.ts`).
Se agrega una variable `DOCTEST_<AMBIENTE>_URL_IDENTIDAD` con la dirección del ingreso a probar (por
ejemplo `https://demo.cloudtrazalog.com/traz-tools/traz-comp-adm/main/login`). Si está vacía, se usa la
de DNATO, así nada cambia para quien no la configure. Solo la usan los recorridos de identidad
(DNATO-UC-001 a 008); el ingreso del agente (DNATO-UC-009) y las pantallas de administración de DNATO
siguen en la dirección de DNATO.

---

## De dónde sale cada dato

| Dato | De dónde | Cómo |
|---|---|---|
| Usuario, contraseña, estado, ban | `seg.users` | **Directo a la base** (excepción aprobada), como `User_model::checkLogin` |
| Empresas del usuario | `seg.memberships_users` ⋈ `core.empresas` | **Directo a la base**, `User_model::getEmpresasDeUsuario` (copiado tal cual, con su criterio de hoy) |
| Enlaces de activación y restablecimiento | `seg.tokens` | **Directo a la base**, `insertToken` / `isTokenValid` |
| Configuración del sitio, niveles | `seg.settings`, `seg.roles` | **Directo a la base** |
| Países, provincias, teléfono por país | `core.tablas` (`paises`, `paises_registracion`) y `REST_CORE_PAISES` | Como DNATO, con el arreglo de #49 |
| Alta del usuario de registro | `API_CORE/usuario/registro` | Ya existe (toolsCOREAPI) |
| Alta en Bonita y AssetPlanner al activar | `API_CORE/usuario/bpm-asset` | Ya existe |
| Alta de empresa, establecimiento y depósito | `API_CORE/empresa`, `REST_CORE/establecimiento`, `REST_CORE/deposito*` | Ya existen |
| Roles y actores de Bonita de la empresa nueva | `REST_BPM` | Ya existe |
| Id del usuario en Bonita al ingresar | `BPM::getUser` | Librería de Tools, ya existe |
| Logo y pie del ingreso | `core.tablas` (`configuraciones_ui`) | Como DNATO |

**No hay DataServices nuevos ni se modifica ninguno existente.**

---

## Pantallas

No hay maqueta nueva: las pantallas son **copia exacta** de las de DNATO (decisión 3 del análisis:
estilos `tz-*` y del registro "tal cual", sin unificar).

| Pantalla | Dirección en el módulo | Vista de DNATO que se copia |
|---|---|---|
| Ingreso ("Bienvenido") | `traz-comp-adm/main/login` | `login.php` |
| "¿Con qué empresa querés ingresar?" | `traz-comp-adm/main/seleccionar_empresa` | `login_empresa.php` |
| Recuperar contraseña | `traz-comp-adm/main/forgot` | `forgot.php`, `reset-pass-info.php` |
| Restablecer contraseña | `traz-comp-adm/main/reset_password/token/…` | `reset_password.php` |
| Registro nuevo usuario | `traz-comp-adm/main/register` | `register.php`, `register-info.php` |
| Establecer contraseña | `traz-comp-adm/main/complete/token/…` | `complete_password.php` |
| Información adicional de registro | `traz-comp-adm/register/register_success` | `formulario_page.php` |
| Completar datos de empresa | `traz-comp-adm/register/crearEmpresa` | `crear_empresa_page.php` |
| Registro completado | `traz-comp-adm/register/registro_completo` | `bienvenida_page.php` |

**`data-testid`:** no se agregan. Los `id`, `name`, textos de botones y mensajes quedan **idénticos** a
los de DNATO, porque las pruebas DNATO-UC-001 a 008 los usan (por ejemplo `#email`, `#password`,
`input[name="reg_razon_social"]`). Cambiar uno solo rompe el criterio de aceptación.

Los mensajes de error son los de DNATO. Los del controlador base son los de REQ-002 ("No tenés permiso
para entrar a esta pantalla.", "Esa página no existe.", "La página venció. Volvé a cargarla e intentá
de nuevo.").

---

## Reglas

1. La copia se comporta igual que DNATO: mismos pasos, mismos mensajes, mismas validaciones y mismas
   tablas. La prueba son DNATO-UC-001 a 008 pasando contra la copia.
2. La copia escribe en la sesión las mismas claves que DNATO, con el mismo contenido.
3. Sin sesión solo se entra a la lista pública; todo otro método del módulo manda al ingreso copiado
   (o responde 401 si es un pedido por AJAX).
4. Ningún método auxiliar queda alcanzable desde el navegador.
5. Todo enlace que arma la copia (en pantallas y correos) apunta a la copia, nunca a DNATO.
6. Después de ingresar se vuelve a la pantalla del módulo pedida, y solo a una del módulo; si no hay,
   al tablero de Tools.
7. Mientras dura la registración, la empresa temporal de DNATO (`REGISTER_TEMP_EMPR_ID` = 9000) no da
   acceso a ninguna pantalla del módulo fuera de la registración: el control de administrador de
   REQ-002 la rechaza como a cualquier empresa de la que no se es administrador.
8. Ningún dato secreto (contraseñas, claves, contraseña por defecto) queda escrito en el repositorio
   ni en el registro (log).

## Registro en el log

Con el formato del repo: `log_message('DEBUG', '#TRAZA | ADM | <Clase> | <metodo>() ...')`. Lo que DNATO
escribe hoy en el log con datos sensibles (los datos del formulario de registro y el enlace de
activación a nivel INFO, `Main.php:1922,1974,2028`; la contraseña en texto plano que viaja a
`/usuario/bpm-asset`, que `REST.php` registra) **no se copia**: se registra el correo y el paso, sin
contraseñas ni enlaces con código. No cambia nada visible para el usuario.

---

## Datos

No hay tablas ni columnas nuevas. Lo único nuevo es una clave de sesión del módulo (por ejemplo
`adm_volver_a`) con la dirección a la que volver (ADM-UC-014).

---

## Decisiones tomadas

- **Copiar, no rehacer** (regla 2 del replanteo, 2026-11-03): mismas pantallas y mismo comportamiento,
  para poder comparar en paralelo con DNATO y redirigir al final sin sorpresas.
- **Acceso directo a la base en lo copiado** (Rodolfo, 2026-11-05, análisis C.1): mismos accesos que
  DNATO. Pasarlos a WSO2 es una tarea posterior.
- **Estilos tal cual, sin unificar** (Rodolfo, 2026-11-04).
- **Tiempo de sesión: el de Tools** (sin límite, Rodolfo, 2026-11-04). La copia corre dentro de Tools y
  lo hereda sin tocar `config.php`. Dejarlo en una constante configurable (análisis C.3) toca la
  configuración general de Tools: va con su análisis aparte (duda en ADM-UC-011).
- **La lista pública vive en el controlador base del módulo** (Rodolfo, 2026-11-10, REQ-002), no en un
  control general de Tools (deuda H-091).
- **Mismos nombres de controlador que DNATO** (`main`, `register`) dentro del módulo: así las
  direcciones solo cambian en la raíz y las pruebas existentes sirven sin reescribirlas.
- **El log no copia datos sensibles**: no cambia el comportamiento para el usuario y evita copiar a
  Tools una fuga que DNATO ya tiene.
- **DNATO no se toca**: ni el código ni sus direcciones (redirección = último paso).

## Cómo se revisa (además de DocTest)

Lo que Rodolfo verifica en el pull request:

- DNATO-UC-001 a 008 en verde **dos veces**: con la variable de identidad apuntando a la copia y sin
  ella (contra DNATO). Las dos corridas en DEMO, con `npm run doctest`.
- ADM-UC-010 a 014 en verde.
- DocTest `regresion` en verde (Tools sigue igual).
- `traz-comp-dnato` sin cambios en el pull request; `application/config/config.php` y `constants.php`
  de Tools sin cambios.
- La descripción del pull request lista **todos** los métodos públicos de `main` y `register` en el
  módulo, igual a la lista pública de arriba.
- Búsqueda de secretos en el diff (contraseñas, claves de reCAPTCHA, credenciales de correo): nada.
- `phpcs` con PHPCompatibility para PHP 5.6 sin errores.

## Dudas abiertas

Están en los casos de uso (campo `dudas`), para contestarlas en un solo lugar.

---

## Casos de prueba de la especificación que cubre

| CP | Qué prueba | Lo cubre |
|---|---|---|
| CP-01 | Ingreso con una sola empresa entra directo (existente) | DNATO-UC-006 corrido contra la copia |
| CP-02 | Ingreso con varias empresas pide elegir (existente) | DNATO-UC-006 corrido contra la copia. La parte "la empresa suspendida no aparece" es nueva: fuera de alcance (E4/E5, estados de membresía y de empresa) |
| CP-03 | Baneado en su única empresa ve el mensaje de suspensión | Fuera de alcance: necesita el estado de la membresía (REQ-004 lo agrega, REQ-007 lo usa) |
| CP-05 | Cambiar de empresa solo entre membresías activas | Fuera de alcance: es el correctivo C-1, que el índice de requerimientos deja para reunión de arquitectura |
| CP-06 | Recuperar contraseña (existente) | DNATO-UC-008 corrido contra la copia, y ADM-UC-013 (el enlace lleva a la copia) |
| CP-110 | Lo que estaba abierto ahora exige sesión y rol | En parte: ADM-UC-010 (en la copia ningún método auxiliar queda abierto). El resto (los de DNATO) no aplica: DNATO no se toca |
| CP-111 | La empresa del navegador se ignora | Ya lo prueba DNATO-UC-006 ("se confirma una empresa que no es del usuario") contra la copia; el resto del módulo lo cubre ADM-UC-001 |
| CP-112 | Protección de envíos; nada por GET cambia estado | ADM-UC-010 (envío sin código en una página pública) |
| CP-113 | Enlace de invitación de un solo uso con vencimiento | Fuera de alcance: invitaciones, REQ-007 (E4). La copia conserva el enlace de hoy (DNATO-UC-002) |
