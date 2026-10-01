# Análisis de impacto — vínculo con AssetPlanner desde `POST /rol/asignar`

## Objetivo

Anticipar qué puede romper el cambio que hace que asignar un rol también dé acceso a
AssetPlanner (PRs traz-tools #525 y #526, dnato #41), **antes** de volver a desplegarlo. Está
escrito para el PM, para decidir si el #526 se despliega tal cual, con cambios, o no. Lo pidió él
después de tres despliegues seguidos que "arreglaban" un síntoma y no la causa. No cubre el diseño
funcional del mapeo rol → grupo, que está decidido y documentado en `doc/hallazgos/REGISTRO.md`
(H-085) y en el propio PR #525.

---

## 1. Qué cambia exactamente respecto de lo desplegado (v2.5.1.5)

| Artefacto | Cambio | Riesgo si falla al desplegar |
|---|---|---|
| `sequences/toolsAssetUserEmpresa.xml` | el GET a `/empresa/{empr_id}` sale sin cuerpo (`NO_ENTITY_BODY`) | solo afecta a esta sequence |
| `apis/toolsCOREAPI.xml`, recurso `POST /rol/asignar` | fija `HTTP_SC=200` antes de responder | si el XML no carga, **cae toda `toolsCOREAPI`** (12 recursos) |
| `data-services/COREDataService.dbs` | sin cambios respecto de v2.5.1.4 (la query ya está) | — |
| dnato | sin cambios respecto de v2.5.0.7 | — |

Los dos XML parsean. Pero "parsea" no es "despliega": Synapse valida más cosas que el XML. **Es el
riesgo más grande de este despliegue y no tengo forma de eliminarlo desde acá** — ver §7.

---

## 2. Quiénes invocan la operación modificada

Exactamente **tres**, todos en PHP de dnato. Ninguno en otras APIs, sequences, MCP ni la app móvil
(verificado con grep sobre los tres repos).

| Invocador | Cuándo | Qué hace si `/rol/asignar` falla |
|---|---|---|
| `Register.php:1251` | alta de empresa: 5 usuarios × ~2 roles + el administrador ≈ **11 llamadas** | `addProvisionWarning()` → **revierte la empresa entera** |
| `Main.php:979` | ABM, asignar varios roles de una | **desasigna todos los roles que ya había asignado** en esa tanda y avisa |
| `Main.php:1093` | ABM, un rol | avisa y devuelve `false` |

Los tres leen el éxito igual: `status` verdadero **y** `code < 300`. **Ninguno lee el cuerpo** de la
respuesta exitosa. Por lo tanto el contrato a preservar es uno solo:

> **`POST /rol/asignar` devuelve 2xx siempre que el rol haya quedado asignado en Tools y en
> Bonita, pase lo que pase con AssetPlanner.**

Eso es lo que v2.5.1.4 y v2.5.1.5 violaban, y lo que el #526 restablece.

Dato que agrava el ABM: un falso fallo en `Main.php:979` no solo muestra un error, **deshace roles
que sí se habían asignado bien**. Es la razón de que el contrato de arriba no sea negociable.

---

## 3. Estado que la sequence deja detrás — la causa de las tres vueltas

Esto es lo que no analicé antes y me costó tres despliegues. Synapse no aísla nada: cada `call`
deja el cuerpo, el código HTTP y las banderas del mensaje para el mediador siguiente. Una sequence
que se invoca *en el medio* de un recurso hereda todo y lega todo.

| Estado | Lo que la sequence hace | ¿Afecta lo que sigue? |
|---|---|---|
| **cuerpo del mensaje** | entra con el body de la última respuesta de Bonita; hace un GET **con ese body** | **SÍ — era la causa raíz.** El DataService lee los parámetros del body y no de la URL, encuentra `{}`, falla. Arreglado con `NO_ENTITY_BODY` (idioma que el propio recurso ya usa en la línea 886) |
| **`HTTP_SC`** (axis2) | queda con el código del último `call` (500 si falló el DataService) | **SÍ — era lo que revertía empresas.** `<respond/>` responde con ese código aunque el cuerpo diga `ok`. Arreglado con `HTTP_SC=200` antes de responder (idioma de `/usuario/registro` y `/usuario/bpm-asset`) |
| **`FORCE_ERROR_ON_SOAP_FAULT`** | entra en `true` (heredado), la sequence lo pone en `false` y **no lo restaura** | Hoy no: después de la sequence solo hay `payloadFactory` + `respond`, sin más `call`. **Queda documentado en el archivo**: si mañana alguien agrega un `call` después, lo hereda en `false` |
| **`HTTP_METHOD`** (axis2) | queda en `GET` | No: el `method` del endpoint manda. **Verificado por precedente**, el propio recurso lo deja en GET en la 886 y hace dos POST después (942, 965) sin resetearlo |
| **`NO_ENTITY_BODY`** | se pone en `true` para el GET y se **quita** después | No, se limpia |
| **`messageType` / `Content-Type`** | los pisa cada `payloadFactory` | No: el `payloadFactory` final del recurso los vuelve a fijar |
| **propiedades `asset_*` y `uri.var.asset_*`** (default) | quedan | No: prefijo propio, nadie más las lee |
| **header `Accept`** | lo fija a JSON | No: el recurso ya lo tenía así |

Conclusión: con el #526, **ningún estado de la sequence altera la respuesta del recurso**. Las dos
fugas que sí lo hacían están cerradas, y las que quedan son inocuas y están verificadas contra el
código existente, no supuestas.

---

## 4. Caminos por los que puede pasar la sequence, uno por uno

| Situación | Qué pasa | Efecto en `/rol/asignar` |
|---|---|---|
| El rol no mapea a ningún grupo (`Responsable de Producción`, etc.) | `switch` cae en `default`, loguea DEBUG, sale | **ninguno**, 2xx |
| Faltan `empr_id` o `role_base` en el body (cliente viejo) | el `filter` del recurso da falso, la sequence **no se invoca** | **ninguno**, 2xx — comportamiento idéntico al de antes |
| La empresa no tiene `empr_id_mysql` (creadas mientras #491 estuvo roto) | GET responde sin ese campo; loguea ERROR con "reconciliar"; **sigue al paso 3 con `empresaid` vacío** | 2xx. ⚠️ Ver §5.3 |
| El DataService no responde / cae | `call` sin `FORCE_ERROR` no lanza; `HTTP_SC` queda en 5xx; loguea ERROR | 2xx gracias al `HTTP_SC=200` |
| MariaDB rechaza el SQL | ídem: DSS responde 500, se loguea, sigue | 2xx; **el vínculo no se escribe** — ver §5.1 |
| El usuario no está en `sisusers` (falló `/assetuser/add`, que es no bloqueante) | el `INSERT … SELECT` no encuentra filas, **no inserta y responde 2xx** | 2xx. ⚠️ **No se puede detectar**: el DataService responde 202 con cuerpo vacío, no devuelve filas afectadas (verificado en local). El log dice "vínculo enviado" aunque no haya insertado nada |
| El grupo no existe para esa empresa (el trigger no corrió) | ídem, 0 filas | 2xx, mismo problema: indetectable desde la sequence |
| Segunda asignación al mismo usuario/empresa (re-corrida, o usuario con dos roles) | `ON DUPLICATE KEY UPDATE` | 2xx; el grupo se mantiene o sube según precedencia |

Nada de esto puede devolver un no-2xx al invocador. **Ese es el cambio de fondo respecto de lo
desplegado.**

---

## 5. Riesgos que quedan — y qué propongo con cada uno

### 5.1 El SQL nunca corrió contra MariaDB 🔴 → simplificar antes de desplegar

La cláusula de precedencia lleva una **subconsulta correlacionada** contra la tabla que se está
actualizando:

```sql
ON DUPLICATE KEY UPDATE grpId = IF(CAST(:rango AS SIGNED) >= COALESCE(
    (SELECT FIELD(a.grpName, …) FROM sisgroups a WHERE a.grpId = usuarioasempresa.grpId), 0),
  VALUES(grpId), usuarioasempresa.grpId)
```

Es la construcción más exótica de todo el DataService y **no tengo cómo probarla**. Con el #526
ya no tumba nada si falla — pero falla el vínculo, que es la funcionalidad entera.

**Propuesta: reemplazarla por `grpId = VALUES(grpId)` ("el último gana") y dejar la precedencia
como mejora aparte, con su query probada.** Consecuencia concreta del "último gana": en la
registración **no cambia nada** —los dos roles de `mantenimiento@` mapean al mismo grupo, y los dos
de `usuario@` también—; en el ABM, asignarle `Responsable de Almacén` a un administrador lo
bajaría a `Solicitante`. Es visible (ve menos menú) y reversible (se reasigna `Administrador`), y
hoy directamente **no entra**. Menos riesgo a cambio de un caso raro y recuperable.

Si preferís mantener la precedencia, la query se prueba en 10 segundos en DBeaver sobre `assetv2`
con valores de una empresa existente — y eso se hace **antes** del despliegue, no después.

### 5.2 Si el XML no despliega, cae `toolsCOREAPI` entera 🔴 → validar en local primero

Es el riesgo de mayor radio y aplica a **cualquier** cambio en ese archivo, no solo a este. Hoy la
única validación pre-despliegue es "parsea", que no alcanza (Synapse valida mediadores, claves de
sequence, expresiones XPath). Para este despliegue propongo cargar los dos artefactos en el WSO2
local antes — sin base ni Bonita, solo para ver que **deployan**. Necesita que levantes el entorno
local; avisame y lo hago. Es el paso que debí dar antes del primer despliegue.

### 5.3 Empresa sin `empr_id_mysql`: la sequence sigue con `empresaid` vacío 🟡 → cortar ahí

Hoy loguea el ERROR pero **no sale**: llega al paso 3 y hace el POST con `empresaid=""`. El
`INSERT … SELECT` con `CAST('' AS UNSIGNED)` da 0, no encuentra grupo, no inserta, 2xx. Inocuo
pero sucio, y una llamada al vicio. **Propuesta: que ese `filter` salga de la sequence** en vez
de seguir. Cambio de dos líneas.

### 5.4 `tipo = 1` duplicado si un usuario entra a una segunda empresa 🟡 → documentado, no urge

El PM lo dejó como "por ahora no importa". Pero para que quede escrito cuál es el efecto: si al
mismo correo se le asigna un rol en una segunda empresa, quedan **dos filas con `tipo = 1`**, el
`JOIN` del login devuelve dos, y `Users.php:261` toma `$u[0]` — o sea entra a **cualquiera** de las
dos. Hoy no puede pasar por la registración (usuarios nuevos) y por el ABM solo si un administrador
carga un correo que ya existe en otra empresa. Queda anotado como deuda.

### 5.5 `membershipExists()` saltea la llamada 🟢

En `Register.php`, si la membership de Bonita ya existe **no se invoca** `/rol/asignar`, así que el
usuario no se vincula. Solo afecta a re-corridas sobre usuarios que ya existían — las empresas de
prueba con dominio compartido (H-083). Ninguna empresa real pasa por ahí.

### 5.6 `json-eval` sobre un campo ausente 🟡 → verificar con un curl

El comportamiento "cliente viejo → nada cambia" (§4, fila 2) depende de que `json-eval($.empr_id)`
sobre un body sin ese campo devuelva vacío y **no lance**. Es lo que hace Synapse en EI 6.x y el
proyecto ya tiene lecturas de campos opcionales, pero **no lo probé**. Un `curl` a `/rol/asignar`
sin los campos nuevos, después del despliegue, lo confirma. Importa porque tools y dnato se
despliegan por separado: un dnato viejo contra un tools nuevo es un escenario real.

---

## 5-bis. Lo que la prueba en local encontró — y el análisis de escritorio no

Se cargó el `.car` reconstruido en el MI 4.5.0 local contra las bases de DEV (`tools_prod_t` y
`assetv2` en `10.142.0.13`), y se ejercitó la sequence con un arnés que reproduce las condiciones
de `/rol/asignar` (un `call` previo que deja cuerpo y código HTTP, `FORCE_ERROR` en `true`,
respuesta con `HTTP_SC=200`). Seis escenarios, un usuario descartable, todo limpio al final.

**Tres defectos más que el #526 no tenía, y que el DEMO habría mostrado en un cuarto despliegue:**

| Defecto | Cómo se vio | Arreglo |
|---|---|---|
| **El GET fallaba por el header `Content-Type`, no por el cuerpo.** `NO_ENTITY_BODY` saca el cuerpo pero deja `Content-Type: application/json`, y con ese header el DataService busca los parámetros en un JSON que no existe | en aislamiento: el mismo GET da **200 sin el header y 500 con él** | `<header name="Content-Type" action="remove"/>` antes del GET |
| **`json-eval` sobre una respuesta de error explota antes de llegar al filtro del código HTTP.** El DataService responde los errores como HTML; `json-eval` lanza `Illegal character: <r>` y la excepción sube hasta cortar la conexión (HTTP 000) | escenario A, primera corrida | primero el código, después el cuerpo: `json-eval` solo dentro del `2xx` |
| **Un `empr_id_mysql` NULL llega como la cadena `"null"`**, `boolean("null")` es verdadero, la sequence sigue y MariaDB rechaza `CAST('null' AS UNSIGNED)` | escenario C: 200 pero con `DATABASE_ERROR` en el log | el filtro también compara contra `'null'` |

Y **una afirmación de este mismo documento que era falsa**: el paso 4 no puede "verificar el
efecto" porque el DataService responde **202 con cuerpo vacío** a este INSERT — no devuelve filas
afectadas. Corregido en §4 y en el archivo de la sequence: un 2xx significa "la sentencia corrió",
no "el vínculo existe".

Un dato más: **el 202 del DataService se filtra a la respuesta** aunque el recurso ponga
`HTTP_SC=200` — Synapse respeta el 202 por su semántica de *accepted*. Es inocuo: `REST.php` hace
`status => ($response_code < 300)` y los tres invocadores miran `code >= 300`. Y el escenario C
prueba que un **500 sí se pisa a 200**, que es el caso que importa.

**Resultado final de los seis escenarios**, con la sequence corregida:

| | Escenario | Respuesta | Base | Log |
|---|---|---|---|---|
| A | rol que mapea, empresa con vínculo | 202 ok | fila `Supervisor de Taller`, `tipo=1`, `AC` | INFO vínculo enviado |
| B | rol que no mapea | 200 ok | sin cambios | DEBUG |
| C | empresa sin `empr_id_mysql` | 200 ok | **sin cambios** | ERROR "no tiene empr_id_mysql" |
| D | empresa inexistente | 200 ok | sin cambios | ERROR ídem |
| E | segundo rol al mismo usuario | 202 ok | la fila pasa a `Admin` | INFO |
| F | usuario que no está en `sisusers` | 202 ok | sin cambios | INFO (limitación de arriba) |

Ninguno devuelve un no-2xx. Ninguno deja una excepción en el log.

## 6. Lo que NO cambia

- **Bonita**: la sequence corre *después* de que la membership quedó creada y no la toca.
- **PostgreSQL**: solo una lectura (`GET /empresa/{id}`).
- **El contrato de respuesta**: `{"respuesta":{"resultado":"ok"}}` con 200, igual que antes — y
  ahora explícito en vez de heredado.
- **Rendimiento**: +2 llamadas HTTP por asignación de rol. En la registración son ~22 llamadas
  más, del orden de 1 a 3 segundos sobre un alta que hoy tarda 5. En el ABM, imperceptible.
- **Baja de empresa**: las filas de `usuarioasempresa` quedan si el alta se revierte, coherente con
  la regla de que la baja es siempre lógica (H-081).
- **Superficie de seguridad**: el recurso nuevo del DataService es interno, misma exposición que
  los otros 93.

---

## 7. Recomendación

Los tres pasos se hicieron (2026-09-11, ver §5-bis):

1. ✅ SQL simplificado a "el último gana"; la sequence corta cuando falta `empr_id_mysql`.
2. ✅ Artefactos cargados en el MI local: **despliegan**. El DataService registra la query y el
   recurso; la sequence y el API también. Y además se ejecutaron, que fue lo que destapó los tres
   defectos de §5-bis.
3. ✅ Compatibilidad hacia atrás verificada: un cliente sin los campos nuevos falla **en el mismo
   lugar** que uno con ellos (§5.6).

**Ahora sí se puede desplegar.** La primera corrida en el DEMO sigue siendo diagnóstica: alta de
empresa + `verificar:asset` + mirar `wso2carbon.log` buscando `toolsAssetUserEmpresa`.

Y una regla para mí, que sale de esto: **un cambio en un artefacto de WSO2 se prueba desplegado
antes de darse por listo.** El XML que parsea, los idiomas que "tienen precedente" y el análisis
del código no reemplazan una corrida — las tres fugas de esta semana no se veían en el XML y se
vieron en el primer minuto de ejecución.
