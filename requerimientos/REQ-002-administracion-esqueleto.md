# REQ-002 · Módulo Administración — Esqueleto con seguridad incluida

## Objetivo

Segundo trabajo de Pablo para el módulo **Administración** (`traz-comp-adm`): armar el módulo vacío
dentro de Tools, con la seguridad funcionando desde el primer día, y las dos pantallas de entrada (el
Portal de la empresa y la Consola) casi sin contenido. Lo lee Pablo para planificar y programar, y
Rodolfo para aprobarlo. **No** cubre la registración ni el ingreso (eso es REQ-003) ni las pantallas
con datos (REQ-004 en adelante, ver [`README.md`](README.md)). La forma de trabajar está en
[`doc/metodologia/GUIA_REQUERIMIENTOS_CLAUDE_DEEPSEEK.md`](../doc/metodologia/GUIA_REQUERIMIENTOS_CLAUDE_DEEPSEEK.md).

| Campo | Valor |
|---|---|
| Estado | Casos validados por Rodolfo el 2026-11-10. Pasa a "Listo para Pablo" cuando se una a `develop` y exista el repositorio `traz-comp-adm` |
| Se apoya en | [REQ-001](REQ-001-administracion-analisis.md) y su resultado, [`doc/v3/administracion/ANALISIS_INICIAL.md`](../doc/v3/administracion/ANALISIS_INICIAL.md) (secciones C.2, F.2 y F.3) |
| Casos de uso | `ADM-UC-001`, `ADM-UC-002` y `ADM-UC-003` en `doctest/catalogo/adm/` |
| Repos que se tocan | `traz-comp-adm` (nuevo, lo crea Rodolfo), `traz-tools` (para montarlo: `.gitmodules` y una constante; y las comparaciones de `TOOLS_ADMIN_USER`) y `traz-comp-dnato` (solo las comparaciones de `TOOLS_ADMIN_USER`) |
| Riesgo | 🟡 Código nuevo. Del núcleo de Tools se **agrega** la constante `ADM` y se cambia cómo se compara `TOOLS_ADMIN_USER` (8 lugares, en Tools y en DNATO). Ese cambio lo pidió Rodolfo el 2026-11-10; con un solo correo en la constante, todo sigue igual |

---

## Para qué sirve

Antes de copiar la registración o hacer pantallas, el módulo tiene que existir y ser seguro: que nadie
entre sin sesión, que cada persona vea solo lo que le corresponde, que la empresa no se pueda cambiar
desde el navegador y que no se puedan falsificar envíos. En DNATO esas cuatro cosas faltan
(correctivos C-2, C-4 y C-6 de la especificación); acá **nacen resueltas**, y todo lo que se construya
después las hereda sin tener que acordarse.

## Quién lo usa

- **Administrador** de una empresa: entra al Portal de la empresa.
- **Superusuario**: entra a la Consola.
- **Usuario** (no administrador): no entra a ninguna de las dos; se usa para probar el rechazo.

## Qué tiene que hacer

1. Montar el módulo dentro de Tools → (sin caso: se verifica en la revisión, ver "Cómo se revisa").
2. Entrar al Portal de la empresa, con todos los controles de acceso → **ADM-UC-001**.
3. Entrar a la Consola, solo superusuarios → **ADM-UC-002**.
4. Rechazar envíos falsificados en todo el módulo → **ADM-UC-003**.

## Qué NO hace

- **No toca el control de sesión del resto de Tools.** El control vive **solo dentro del módulo**.
  Llevarlo a todo Tools queda como deuda técnica (hallazgo **H-091**) para un requerimiento aparte, con
  su análisis de impacto. Decisión de Rodolfo del 2026-11-10, que cambia la decisión 4 del análisis.
- **No cambia la configuración general de Tools** (`application/config/config.php`): ni la protección
  de envíos (`csrf_protection` sigue en `FALSE`), ni los "ganchos" (`enable_hooks` sigue en `FALSE`),
  ni la sesión.
- **No agrega el botón "Mi empresa" en la barra de Tools.** Se entra por la dirección. El botón toca
  la barra de Tools y va en un requerimiento posterior.
- No copia la registración ni el ingreso (REQ-003). Mientras tanto, sin sesión se manda al ingreso de
  DNATO, igual que hace Tools hoy.
- No crea tablas ni columnas. No trae indicadores, planes, usuarios ni menús en el Portal.
- No agrega la marca de superusuario en la base: va en REQ-004.
- De `TOOLS_ADMIN_USER` solo cambia **cómo se compara** (ver "Varios superusuarios"); nada más de esas
  pantallas.

---

## Cómo se arma

### El módulo dentro de Tools

- Repositorio propio `traz-comp-adm`, montado como submódulo en `application/modules/traz-comp-adm`,
  igual que `traz-comp-pan`. Rama base `develop`.
- Carpetas: `controllers/`, `models/`, `views/`, `helpers/`, `config/` (análisis, F.2).
- Constante de prefijo `ADM` = `'traz-comp-adm/'` en `application/config/constants.php` de Tools,
  junto a `PRD`, `PAN`, `ALM`, etc. Es la única constante nueva.
- PHP 5.6: nada de sintaxis de PHP 7 (el control es `phpcs` con PHPCompatibility, ver
  `doc/metodologia/REGLAS-PARA-AGENTES.md`).

### Varios superusuarios (`TOOLS_ADMIN_USER` con varios correos)

Pedido de Rodolfo (2026-11-10): poder tener más de un superusuario, usando **la misma constante**.
`TOOLS_ADMIN_USER` pasa a aceptar varios correos separados por coma, por ejemplo
`'admin@trazalog.com,otro@trazalog.com'`.

Hoy hay **8 lugares** que la comparan por igualdad, y con varios correos dejarían de reconocer al
superusuario. Antes de poner más de un correo, se cambian todos para que usen una función nueva
`es_superusuario($email)`, que separa la lista por coma, quita espacios y compara sin distinguir
mayúsculas:

| Repo | Archivo:línea | Hoy |
|---|---|---|
| traz-tools | `application/models/core/Valores.php:24` | `$data['email'] == TOOLS_ADMIN_USER` |
| traz-tools | `application/models/core/Valores.php:49` | `$usuario['email'] != TOOLS_ADMIN_USER` |
| traz-tools | `application/models/core/Valores.php:71` | `$usuario['email'] != TOOLS_ADMIN_USER` |
| traz-tools | `application/models/core/Valores.php:103` | `$usuario['email'] != TOOLS_ADMIN_USER` |
| traz-tools | `application/views/core/valores/view.php:55` | `$usuario['email'] == TOOLS_ADMIN_USER` |
| traz-comp-dnato | `application/controllers/Empresa.php:34` | `$data['email'] == TOOLS_ADMIN_USER` |
| traz-comp-dnato | `application/controllers/Empresa.php:56` | `$data['email'] == TOOLS_ADMIN_USER` |
| traz-comp-dnato | `application/views/navbar.php:57` | `...userdata['email'] == TOOLS_ADMIN_USER` |

- La función va en un helper de cada repo (Tools: `application/helpers/sesion_helper.php`; DNATO: su
  helper de sesión). El módulo usa la de Tools.
- **Análisis de impacto:** es núcleo (constantes y DNATO). Con **un solo correo** en la constante, la
  función da lo mismo que la comparación de hoy, así que no cambia nada hasta que alguien agregue un
  segundo correo. El riesgo es olvidarse de algún lugar: Pablo vuelve a buscar `TOOLS_ADMIN_USER` en
  **todos** los repositorios (incluidos los submódulos y los disparadores o funciones de la base) y
  lista lo que encuentre en el pull request.
- **Orden de despliegue:** primero Tools y DNATO con la función; recién después se agrega el segundo
  correo en cada ambiente.

### El controlador base del módulo

Todos los controladores del módulo heredan de **un controlador base propio del módulo** (por ejemplo
`ADM_Controller`, en `traz-comp-adm`). Ese controlador hace, **antes** de ejecutar cualquier método:

1. **Sesión:** si no hay `empr_id` en la sesión, manda al ingreso (`DNATO."main/login"`), igual que
   `application/controllers/Dash.php`. Los pedidos por AJAX reciben 401 en vez de la redirección.
2. **Lista pública:** cada controlador puede declarar qué métodos son públicos (sin sesión). En este
   requerimiento la lista está **vacía**; la llena REQ-003 con la registración y el ingreso.
3. **Permiso por pantalla:** cada controlador declara quién puede entrar (`administrador` o
   `superusuario`). Si la persona no cumple, responde 403 con la pantalla "sin permiso".
4. **Protección de envíos:** el código de seguridad se genera una vez por sesión y dura toda la sesión
   (sirve con varias pestañas abiertas). Todo pedido que no sea de lectura (POST, PUT, DELETE) tiene que traer el
   código de seguridad de la sesión; si falta o no coincide, responde 403 y **no ejecuta el método**.
5. **Empresa:** la empresa sale **siempre** de la sesión (`empresa()` de
   `application/helpers/sesion_helper.php`). El controlador base no lee ningún `empr_id` que venga en la
   dirección, en el formulario o en un encabezado.

### De dónde sale cada dato

| Dato | De dónde | Cómo |
|---|---|---|
| Hay sesión y empresa activa | Sesión de Tools (`empr_id`, `email`) | Ya existe |
| Es administrador de la empresa activa | `REST_CORE/usuario/esadmin/porEmail/{email}/empresa/{empr_id}` | Ya existe: lo usa `Dashs::esAdminEmpresa()` en `application/models/Dashs.php:104` |
| Es superusuario | Correo incluido en `TOOLS_ADMIN_USER` (`application/config/constants.php`), que pasa a aceptar **varios correos separados por coma** | Ya existe. Ver "Varios superusuarios" |
| Nombre de la empresa | `REST_CORE/empresa/{empr_id}` | Ya existe (análisis, C.1) |
| Nombre del usuario | Sesión de Tools | Ya existe |

**Nada va directo a la base.** Todo lo que no está en la sesión se lee por servicios de datos de WSO2.

---

## Pantallas

Siguen las maquetas `doc/v3/dnato/mockups/inicio-admin.html` (Portal) y `consola-empresas.html`
(Consola), con el diseño "portal": no usan el menú de Tools. En este requerimiento llevan **solo el
marco**; el contenido llega en REQ-004 en adelante.

### Portal de la empresa — `traz-comp-adm/portal`

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Marco del Portal | Barra superior "Trazalog · Mi empresa" | `adm-portal` |
| Empresa | Inicial y nombre de la empresa activa | `adm-portal-empresa` |
| Menú lateral | Solo "Inicio" (las demás opciones llegan con sus pantallas) | `adm-portal-menu` |
| Saludo | "Hola, <nombre>" | `adm-portal-saludo` |
| Volver | "← Ir a Tools": lleva al tablero de Tools | `adm-ir-a-tools` |
| Consola | "🔑 Consola": **solo** si la persona es superusuario | `adm-ir-a-consola` |

### Consola — `traz-comp-adm/consola`

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Marco de la Consola | Barra superior "Trazalog · Consola", leyenda "solo súper usuarios" | `adm-consola` |
| Volver al Portal | "🏢 Mi empresa" | `adm-ir-a-portal` |
| Volver | "← Ir a Tools" | `adm-ir-a-tools` |

### Pantallas de error del módulo

| Caso | Respuesta | Mensaje | `data-testid` |
|---|---|---|---|
| Sin permiso | 403 | "No tenés permiso para entrar a esta pantalla." | `adm-sin-permiso` |
| La página no existe | 404 | "Esa página no existe." | `adm-no-existe` |
| Envío sin código de seguridad válido | 403 | "La página venció. Volvé a cargarla e intentá de nuevo." | `adm-envio-rechazado` |

---

## Reglas

1. Sin sesión no se entra a ninguna pantalla del módulo, salvo las de la lista pública (vacía en este
   requerimiento).
2. Al Portal entra solo quien es administrador de la **empresa activa** de su sesión.
3. A la Consola entra solo el superusuario.
4. La empresa sale siempre de la sesión; cualquier empresa que venga del navegador se ignora.
5. "Sin permiso" (403) y "no existe" (404) son respuestas distintas.
6. Todo envío que cambia algo exige el código de seguridad; sin él no se ejecuta nada.
7. **Ningún pedido de lectura (GET) cambia datos** en el módulo. Se revisa en el pull request, porque
   el esqueleto todavía no tiene acciones que guarden.
8. **Ningún método del módulo queda sin control.** Los métodos auxiliares son `private` o `protected`;
   no puede haber controladores de prueba.

## Registro en el log

Con el formato del repo: `log_message('DEBUG', '#TRAZA | ADM | <Clase> | <metodo>() ...')`. Cada
rechazo (sin sesión, sin permiso, envío rechazado) se registra con el correo y la dirección pedida, sin
datos sensibles.

---

## Decisiones tomadas

- **El control vive en el módulo, no en Tools** (Rodolfo, 2026-11-10). Hoy Tools no tiene un control
  central: no hay controlador base común (`application/core/` solo tiene `MY_Loader` y `MY_Router`) y
  los ganchos están apagados (`application/config/config.php:106`). Prenderlo afectaría a todas las
  pantallas de producción. Si en el módulo funciona bien, se propaga (H-091).
- **Administrador = el servicio que ya usa el tablero de Tools** (`/usuario/esadmin`), para que Tools y
  el módulo digan lo mismo. No se usa `seg.users.role` (correctivo C-5).
- **Sin sesión se va al ingreso de DNATO**, como el resto de Tools, y después del ingreso se cae en el
  tablero de Tools. Volver a la pantalla pedida queda para REQ-003.
- **Varias empresas:** el Portal muestra siempre la empresa activa de la sesión, sin selector; para ver
  otra, se cambia desde Tools (Rodolfo, 2026-11-10).
- **Superusuario y Portal:** el superusuario entra a la Consola; al Portal solo si además es
  administrador de su empresa activa (Rodolfo, 2026-11-10).
- **Varios superusuarios:** se usa la misma constante `TOOLS_ADMIN_USER`, que pasa a aceptar varios
  correos separados por coma (Rodolfo, 2026-11-10). Ver "Varios superusuarios" en "Cómo se arma".
- **Pruebas en DEMO:** Pablo tiene las credenciales del superusuario de DEMO (es también el
  administrador de la infraestructura); van en su `doctest/.env`, nunca en el repositorio.

## Cómo se revisa (además de DocTest)

Lo que no tiene caso de uso y Rodolfo verifica en el pull request:

- El submódulo está montado y Tools sigue andando igual: DocTest `regresion` en verde.
- `application/config/constants.php` de Tools tiene **solo** la línea nueva de `ADM`.
- Las 8 comparaciones de `TOOLS_ADMIN_USER` usan la función nueva, y con un solo correo en la constante
  todo se comporta igual que hoy (DocTest `regresion` en verde en Tools y en DNATO).
- `application/config/config.php` de Tools **no** cambió.
- La descripción del pull request lista **todos** los métodos públicos de los controladores del módulo,
  con su permiso (regla 8).
- `phpcs` con PHPCompatibility para PHP 5.6 sin errores.

## Dudas abiertas

Están en los casos de uso (campo `dudas`), para contestarlas en un solo lugar.
