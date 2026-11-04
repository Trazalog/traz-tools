# Impacto: la consulta de usuario duplicado del alta de usuarios

## Objetivo

Análisis de impacto, para que el PM apruebe o rechace un cambio de dos líneas en `toolsCOREAPI`. Hay que leerlo
antes de tocar `POST /tools/core/usuario`. No cubre el menú de Mantenimiento en empresas nuevas (H46) ni el
comportamiento del integrador del servidor de desarrollo.

**Estado:** esperando aprobación del PM. No se modificó nada.

## El problema

Con dnato local contra el integrador local (WSO2 MI 4.5, puerto 8290), el alta de empresa se revierte con
"No se pudo crear en Tools el usuario ...". Es el hallazgo H47.

`POST /usuario` recibe un JSON y, antes de crear el usuario, consulta si ya existe con un GET a
`COREDataService/usuario/duplicado/{email}`. Ese GET sale **con el cuerpo del POST original pegado**. El servicio de
datos no toma el correo de la dirección y responde `cannot find parameter ... email`; después falla también la
respuesta, y los pedidos siguientes llegan como POST a una dirección que solo acepta GET (`EPR ... not found`).

Comprobado el 2026-11-04 con el integrador recién desplegado (migración `ae2e4e82` más el cambio de almacén de `develop`):

| Prueba directa al servicio de datos | Resultado |
|---|---|
| GET sin cuerpo | 200, `{"respuesta":{"existe":"false"}}` |
| GET con un JSON en el cuerpo | "Failed to process the request" |

Las altas de prueba `dt2611040329` y `dt2611040338` fallaron así. La falla no siempre pega en el mismo usuario: en la
primera se creó `usuario@`, en la segunda ninguno.

**Corrección a H47:** el error `armarSession: Cannot get property "0" of null` no es la causa. Ocurre siempre que
PHP manda la sesión de relleno (`dd`): Bonita contesta 401, la plantilla inicia sesión y sigue normalmente.

## Comparación con producción

- `toolsCOREAPI.xml` tiene esa consulta igual en `master` y en la rama de la migración, desde 2026-03.
- **Sin verificar:** por qué no falla en producción. Supuesto propio: el integrador de producción es de otra versión
  y descarta el cuerpo de un GET. No hay acceso para confirmarlo.
- En el mismo archivo, las otras dos consultas GET que siguen a un POST (líneas 933-939 y 1120-1126) ya resuelven esto
  con `NO_ENTITY_BODY`. La de la línea 467 es la que quedó sin hacerlo.

## El cambio propuesto

En `_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/apis/toolsCOREAPI.xml`, el mismo patrón
de la línea 933, alrededor del `call` de las líneas 465-469:

```xml
<property name="NO_ENTITY_BODY" value="true" scope="axis2" type="BOOLEAN"/>
<call> ... GET {uri.var.check_duplicado_url} ... </call>
<property name="NO_ENTITY_BODY" action="remove" scope="axis2"/>
```

## Qué lo consume

| Llamador | Efecto |
|---|---|
| dnato `Register.php:1244`, usuarios iniciales del alta de empresa | Ya consulta duplicados antes, en PHP. Sin cambio de conducta |
| dnato `User_model.php:1120`, alta de usuario desde la pantalla | Si la consulta volvía sin dato, seguía de largo. Ahora un correo repetido devuelve "El usuario ya existe", que es lo que el API pretendía |

Los datos del usuario ya están guardados en propiedades antes de ese `call`, y los pasos siguientes arman su propio
cuerpo: ninguno lee el cuerpo original.

## Riesgos

- **Producción:** si su integrador descarta el cuerpo, el cambio no altera nada.
- **Correo repetido:** en ambientes donde la consulta fallaba, ahora se ve el error correcto. Hay que probarlo.
- **Puede haber otra falla después:** este arreglo destraba el primer error, no garantiza que el alta termine.

## Cómo se prueba

1. Local, con VPN: compilar y desplegar en el integrador local.
2. Alta de empresa completa con `@preparar-entorno`: empresa vinculada y los cinco usuarios creados.
3. Alta de usuario desde la pantalla, con un correo nuevo y con uno repetido.
4. Recién entonces, modo full de DocTest.
