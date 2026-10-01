# Análisis de impacto — la clave de Bonita en la registración freemium (H-070)

## Objetivo

Explicar por qué un pedido de materiales no arranca su proceso en las empresas creadas por
la **registración freemium**, contrastando contra `master` (producción), y proponer el
arreglo alineado con producción. **Para aprobación del PM antes de tocar nada** (regla de
sistema productivo, CLAUDE.md). No cubre otros aspectos de la registración.

## Síntoma

`Notapedido::pedidoNormal()` devuelve `{"status":false,"msj":"Error al Inciar Proceso"}`.
El pedido queda creado pero sin caso en Bonita, así que **nadie lo puede aprobar ni
entregar** (bandeja del Responsable vacía). Verificado en vivo el 2026-09-12 con la empresa
de test freemium; en cambio con **Conservas el pedido SÍ arranca** (dato del PM).

## Cómo funciona en master (producción) — la referencia de "cómo debe estar"

El usuario de Bonita se crea con una función **dedicada**, `User_model::crearUsrBPM()`, que
fija la clave a `BPM_USER_PASS`:

```php
// traz-comp-dnato/application/models/User_model.php (master)
function crearUsrBPM($cleanPost){
    $datos["userName"] = $cleanPost['usernick'];
    $datos["password"] = BPM_USER_PASS;          // 'bpm'
    $datos["password_confirm"] = BPM_USER_PASS;
    ...
    $this->rest->callAPI("POST", REST_BPM."/users", $post);
}
```

La clave de Bonita es **independiente** de la clave de login (seg.users). Y tiene que serlo,
porque el sistema actúa como el usuario en Bonita —`BPM::lanzarProceso()` se loguea con
`loggin(userNick(), userPass())` y `userPass()` devuelve `BPM_USER_PASS`— **sin conocer la
clave real** del usuario. Invariante de producción: **todo usuario en Bonita tiene la clave
`BPM_USER_PASS`.**

`master` no tiene el flujo freemium: no existe `Register.php` ni `REGISTRACION_PASSWORD_DEFAULT`.
Los usuarios se crean por el ABM, que usa `crearUsrBPM`.

## Qué hace distinto el freemium (develop) — la divergencia

`Register.php::crearUsuarioDefaultViaApi()` **no llama a `crearUsrBPM`**. Manda todo por el
recurso "todo en uno" del API:

```php
// traz-comp-dnato/application/controllers/Register.php (develop)
$password = REGISTRACION_PASSWORD_DEFAULT;        // '12345'
$payload['usuario']['password'] = $password;
$this->rest->callAPI('POST', API_CORE . '/usuario', $payload);
```

Y `toolsCOREAPI POST /usuario` usa esa misma `usr_password` para crear al usuario en las
**tres** puntas: seg.users (login), sisusers (AssetPlanner) y **Bonita**:

```xml
<!-- toolsCOREAPI.xml, "crear usuario bonita" -->
<arg expression="get-property('usr_password')"/>   <!-- = '12345', NO BPM_USER_PASS -->
```

Resultado: el usuario de Bonita queda con `'12345'`, pero `lanzarProceso` intenta entrar con
`'bpm'` → login falla → "Error al Inciar Proceso". **Rompe el invariante de producción.**

`crearUsrBPM` sigue existiendo en develop (línea 607, con `BPM_USER_PASS`) y el ABM lo usa;
por eso los usuarios creados por ABM —Conservas— funcionan. El freemium es el único camino
que quedó fuera del invariante.

## Alcance (quiénes están afectados)

- **Afectados**: todos los usuarios de empresas creadas por la registración freemium —los 5
  por defecto (`usuario@`, `almacen@`, `panol@`, `produccion@`, `mantenimiento@`) y el
  administrador—, en cualquier ambiente donde el freemium esté desplegado (DEMO hoy).
- **NO afectados**: usuarios creados por el ABM (Conservas y todo lo previo/manual), que
  siguen por `crearUsrBPM`. Producción (master, sin freemium) no está afectada.

## Esto NO lo introdujo un cambio de esta sesión

La divergencia es de la **feature freemium (v2.5)**, no de los artefactos que toqué esta
sesión (vínculo AssetPlanner, empr_id, toolsFault, deploy). Lo confirma el diff master↔develop:
`Register.php`/`REGISTRACION_PASSWORD_DEFAULT` son nuevos de la feature; la creación de Bonita
con `usr_password` en `POST /usuario` ya estaba en master (solo que en master ese recurso no
es el camino de alta de usuarios). Se documenta para no volver a tratarlo como bug nuevo.

## Opciones de arreglo (para decisión del PM)

El invariante a restaurar: **el usuario de Bonita se crea con `BPM_USER_PASS`, nunca con la
clave de la app.** Dónde forzarlo:

**Opción A — el freemium crea el usuario de Bonita como el ABM (patrón de master).**
`Register.php` deja de delegar la creación de Bonita al `POST /usuario` y usa la vía dedicada
con `BPM_USER_PASS` (la que ya usa el ABM). Cambio acotado a dnato (registración). El API no
se toca.
- Pro: es literalmente "volver a como está en master". No toca artefactos WSO2 → **no
  requiere desplegar API** (solo el PHP de dnato, que va con el script).
- Contra: hay que separar en el freemium la creación del usuario de app (con su clave) de la
  de Bonita (con `BPM_USER_PASS`), que hoy el freemium hace en un solo POST.

**Opción B — el `POST /usuario` del API usa `BPM_USER_PASS` para la parte de Bonita.**
Arregla de una a cualquier canal que use ese recurso. Pero el API tendría que conocer
`BPM_USER_PASS` (registry o payload) — es el enfoque que el PM **ya descartó**, y además toca
un artefacto WSO2 (despliegue de API).

**Recomendación: Opción A.** Es la que respeta "así como está en master", tiene el radio de
impacto más chico y no obliga a desplegar artefactos de WSO2.

## Migración (aplica a cualquier opción)

El arreglo es **hacia adelante**: solo los usuarios creados *después* nacen con `'bpm'`. Los
ya creados por freemium con `'12345'` (la empresa de test, y cualquier empresa registrada
mientras estuvo así) **siguen sin poder lanzar pedidos** hasta que se les resetee la clave de
Bonita a `BPM_USER_PASS`. Conservas y las de ABM no se tocan.

## Prueba (sin desplegar al DEMO)

Con la VPN conectada, el entorno de desarrollo está arriba (10.142.0.13 + MI local). Se
prueba ahí: crear un usuario por el flujo corregido, verificar en Bonita que su clave es
`'bpm'` y que un pedido de esa empresa arranca. Un solo despliegue al DEMO recién cuando pase
en dev.

## Estado

**PENDIENTE DE APROBACIÓN DEL PM.** No se modifica nada hasta el OK, y no se elige opción sin
su decisión.
