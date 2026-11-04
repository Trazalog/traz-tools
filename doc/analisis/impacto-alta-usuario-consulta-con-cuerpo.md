# Impacto: la consulta de usuario duplicado del alta de usuarios

## Objetivo

Análisis de impacto, para que el PM apruebe o rechace un cambio de dos líneas en `toolsCOREAPI`. Hay que leerlo
antes de tocar `POST /tools/core/usuario`. No cubre el menú de Mantenimiento en empresas nuevas (H46) ni el
comportamiento del integrador del servidor de desarrollo.

**Estado:** aprobado por el PM el 2026-11-04, a condición de no romper en EI 6. Aplicado y probado en local con MI 4.5. Sin probar en EI 6: no hay uno disponible.

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

El PM confirma que en producción, con **dnato `v2.5.0.12`** y **tools `v2.5.1.16`**, crear empresa funciona. Se toma
como cierto. Comparación de esos tags contra lo desplegado en local (2026-11-04):

| Pieza | Diferencia con el tag | ¿Afecta el alta? |
|---|---|---|
| `toolsCOREAPI.xml` | Solo agrega `GET /empresa/{empr_id}`. `POST /usuario` y `POST /empresa` son iguales | No |
| `COREDataService.dbs`, `toolsbpmAPI.xml` | Ninguna | No |
| Plantillas, secuencias y recursos | Solo agrega `manAltaConDetalleTemplate` (Mantenimiento) | No |
| dnato, código | Solo `Oauthlogin.php`, que el alta no usa | No |
| dnato, `constants.php` local | Direcciones de la máquina local y `$wso2_base` | No: solo dicen a dónde conectarse |

**Conclusión: el código es el mismo; cambia el motor que lo ejecuta.**

- Producción v2 usa **WSO2 EI 6.x**, según `doc/adr/ADR-011-gcp-deployment.md:18`.
- Local usa **MI 4.5**. El integrador de desarrollo rechaza igual un GET con cuerpo: prueba de solo lectura del
  2026-11-04, `current_params: {}`.
- **Sin verificar:** que EI 6 descarte el cuerpo del GET. Es la explicación que encaja con todo lo anterior, pero no se
  probó en producción.
- El mismo ADR define que v3 corre sobre MI 4.x, así que esta falla aparecería al pasar producción a v3.
- En `toolsCOREAPI.xml`, las otras dos consultas GET que siguen a un POST (líneas 933-939 y 1120-1126) ya usan
  `NO_ENTITY_BODY`. Ese código también está en el tag de producción y corre en EI 6.

## Corrección de la causa

La causa no es el cuerpo sino el encabezado `Content-Type: application/json`. Pruebas directas al servicio de datos local:

| Pedido | Resultado |
|---|---|
| Con cuerpo, sin `Content-Type` | 200 |
| Sin cuerpo, con `Content-Type` | Sin respuesta |

Ya estaba documentado en `sequences/toolsAssetUserEmpresa.xml` (verificado el 2026-09-11): con ese encabezado, el
servicio de datos busca los parámetros en un JSON y no en la dirección.

## El cambio aplicado

En `toolsCOREAPI.xml`, alrededor del `call` de `check_duplicado_url`, el mismo bloque de `toolsAssetUserEmpresa.xml`:

```xml
<header name="Content-Type" scope="transport" action="remove"/>
<property name="HTTP_METHOD" value="GET" scope="axis2" type="STRING"/>
<property name="NO_ENTITY_BODY" value="true" scope="axis2" type="BOOLEAN"/>
<call> ... GET {uri.var.check_duplicado_url} ... </call>
<property name="NO_ENTITY_BODY" action="remove" scope="axis2"/>
```

**Por qué no debería romper en EI 6:** ese bloque está en el tag `v2.5.1.16`, y `toolsAssetUserEmpresa` corre desde
`POST /rol/asignar`, que el alta de empresa llama con `empr_id` y `role_base`. Según el PM, esa alta funciona en
producción.

## Qué lo consume

| Llamador | Efecto |
|---|---|
| dnato `Register.php:1244`, usuarios iniciales del alta de empresa | Ya consulta duplicados antes, en PHP. Sin cambio de conducta |
| dnato `User_model.php:1120`, alta de usuario desde la pantalla | Si la consulta volvía sin dato, seguía de largo. Ahora un correo repetido devuelve "El usuario ya existe", que es lo que el API pretendía |

Los datos del usuario ya están guardados en propiedades antes de ese `call`, y los pasos siguientes arman su propio
cuerpo: ninguno lee el cuerpo original.

## Riesgos

- **Producción:** usa la misma instrucción que ya corre en EI 6 en este archivo. Si EI 6 descarta el cuerpo, la consulta no cambia.
- **Correo repetido:** en ambientes donde la consulta fallaba, ahora se ve el error correcto. Hay que probarlo.
- **Puede haber otra falla después:** este arreglo destraba el primer error, no garantiza que el alta termine.

## Resultado de las pruebas

Local, MI 4.5, 2026-11-04: `@preparar-entorno` pasó y creó las empresas 197 y 198, vinculadas con Mantenimiento (26 y
27), sin errores en el registro del integrador. `POST /usuario` con un correo repetido devuelve "El usuario ya existe".
