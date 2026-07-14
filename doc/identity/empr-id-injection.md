# Inyección de empr_id via mediación del APIM (ADR-008)

**Tarea:** E9-IDENT-05 (reorientada)
**Decisión base:** [ADR-008](../v3/TRAZALOG_v3_MCP_ARCHITECTURE.md) — el APIM extrae `empr_id`
del JWT validado y lo inyecta como `X-Empr-Id`; el MI lo lee del header (no del JWT).
**Artefactos:** `doc/identity/apim-empr-id-injector-policy.xml` (in-sequence del APIM) y
`_backend/.../sequences/EmprIdFromHeader.xml` (sequence del MI).

---

## 1. Diagrama del flujo nuevo

```
┌──────────────────────────────────────────────────────────────────────────┐
│ FLUJO ADR-008 — Inyección de empr_id                                      │
└──────────────────────────────────────────────────────────────────────────┘

  Agente MCP (Claude, etc.)
       │
       │  Authorization: Bearer <JWT Dnato — firmado RS256>
       │    payload: { iss, aud, exp, empr_id: 42, sub, ... }
       ▼
  APIM Gateway (:8243)
       │
       ├─ [Key Manager Dnato]
       │    ① Valida firma JWT contra JWKS de Dnato
       │    ② Valida exp > ahora
       │    ③ Valida iss == "trazalog-dnato"
       │    ④ Valida aud contiene "trazalog-mcp"
       │    ⑤ Si cualquier check falla → 401 (el MI nunca lo ve)
       │
       ├─ [in-sequence: EmprIdInjectorPolicy]
       │    ⑥ Decodifica payload del JWT (base64url decode de la parte 2)
       │    ⑦ Extrae claim empr_id → "42"
       │    ⑧ Setea header de transporte: X-Empr-Id: 42
       │    ⑨ Si empr_id falta en el JWT → 401 (el MI nunca lo ve)
       │
       ▼
  MI (:8280) — recibe request ya autenticado
       │
       ├─ [sequence: emprIdFromHeader]
       │    ⑩ Lee X-Empr-Id del header de transporte
       │    ⑪ Guarda en property de contexto: jwt_empr_id = "42"
       │    ⑫ Si X-Empr-Id falta o está vacío → 503 identity_header_missing
       │
       ├─ [lógica del endpoint]
       │    ⑬ Construye URL de DataService usando jwt_empr_id
       │        ej: /MANDataService/mcp/equipo/42/10
       │
       ▼
  DataService — filtra por empr_id en SQL
       │    SELECT ... WHERE empr_id = :empr_id
       ▼
  Respuesta filtrada para empresa 42 solamente
```

**Cambio clave vs. flujo anterior:** los pasos ①-⑤ ocurrían en el MI (JwtValidator.xml).
Ahora ocurren en el APIM. Los pasos ⑩-⑪ son nuevos en el MI (EmprIdFromHeader.xml reemplaza a
jwtValidator + emprIdInjector). Los pasos ⑬ en adelante **no cambian** — el MI sigue usando la
property `jwt_empr_id`; solo cambió cómo se la alimenta.

---

## 2. Artefacto del APIM: in-sequence EmprIdInjectorPolicy

Este artefacto se aplica como **in-sequence** (mediation policy) a todas las APIs MCP en el
Publisher. Puede aplicarse como:
- **Policy global** (aplica a todos los recursos de la API automáticamente)
- **Per-resource** (aplica a cada resource/verb individualmente)

Para el MVP se recomienda la configuración **por API** (política aplicada a toda la API), ya que
todas las operaciones MCP requieren el `empr_id`.

### Archivo: `doc/identity/apim-empr-id-injector-policy.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
  EmprIdInjectorPolicy — in-sequence para APIs MCP en el APIM
  Aplica DESPUÉS de que el Key Manager Dnato ya validó el JWT.
  Extrae el claim empr_id y lo inyecta como X-Empr-Id hacia el MI.
  ADR-008, E9-IDENT-05.
-->
<sequence name="EmprIdInjectorPolicy" xmlns="http://ws.apache.org/ns/synapse">

    <!-- Leer el header Authorization (el JWT ya fue validado por el Key Manager) -->
    <property name="apim_auth_header"
              expression="$trp:Authorization"
              scope="default" type="STRING"/>

    <!-- Decodificar payload JWT y extraer empr_id -->
    <script language="js"><![CDATA[
        var Base64     = Java.type("java.util.Base64");
        var JavaString = Java.type("java.lang.String");

        function mediator(mc) {
            try {
                var authHeader = mc.getProperty("apim_auth_header");
                if (!authHeader) {
                    /* El KM ya validó el token — si llegamos aquí es que pasó auth.
                       No debería ocurrir, pero si ocurre es un error de config del APIM. */
                    mc.setProperty("empr_id_error", "Authorization header ausente post-validación");
                    mc.setProperty("empr_id_ok", "false");
                    return true;
                }

                var token = authHeader.toString().trim().substring(7).trim(); // quitar "Bearer "
                var parts = token.split("\\.");
                if (parts.length !== 3) {
                    mc.setProperty("empr_id_error", "JWT malformado post-validación (sin 3 partes)");
                    mc.setProperty("empr_id_ok", "false");
                    return true;
                }

                var decoder      = Base64.getUrlDecoder();
                var payloadJson  = new JavaString(decoder.decode(parts[1]), "UTF-8");
                var payload      = JSON.parse(payloadJson);

                if (!payload.empr_id && payload.empr_id !== 0) {
                    mc.setProperty("empr_id_error", "Claim empr_id ausente en JWT validado");
                    mc.setProperty("empr_id_ok", "false");
                    return true;
                }

                mc.setProperty("empr_id_ok",    "true");
                mc.setProperty("apim_empr_id",  payload.empr_id.toString());

            } catch (e) {
                mc.setProperty("empr_id_ok",    "false");
                mc.setProperty("empr_id_error", "Excepción al extraer empr_id: " + e.message);
            }
            return true;
        }
    ]]></script>

    <!-- Abortar con 401 si empr_id no se pudo extraer -->
    <filter xpath="get-property('empr_id_ok') = 'false'">
        <then>
            <payloadFactory media-type="json">
                <format>{"error":"Unauthorized","message":"$1"}</format>
                <args>
                    <arg evaluator="xml" expression="get-property('empr_id_error')"/>
                </args>
            </payloadFactory>
            <property name="messageType" scope="axis2" type="STRING" value="application/json"/>
            <property name="HTTP_SC"     scope="axis2" type="STRING" value="401"/>
            <respond/>
        </then>
    </filter>

    <!-- Inyectar X-Empr-Id como header de transporte hacia el MI -->
    <header name="X-Empr-Id"
            scope="transport"
            expression="get-property('apim_empr_id')"/>

    <log level="custom" category="DEBUG">
        <property name="text"    value="#TRAZA | APIM | EmprIdInjector | X-Empr-Id inyectado"/>
        <property name="empr_id" expression="get-property('apim_empr_id')"/>
    </log>

</sequence>
```

### Cómo asociar esta policy en el Publisher

**Opción A — Via mediation sequence upload (interface clásica APIM 4.x):**

1. Publisher → API Equipos → **`API Configurations`** → **`Mediation`** (o **`Message Mediation`**)
2. **In Flow** → **Upload** → subir el archivo XML anterior
3. **`Save`** → **`Publish`**
4. Repetir para Ordenes de Trabajo

**Opción B — Via Policy API (APIM 4.6.0 Policies):**

1. Publisher → API Equipos → **`API Policies`** → **`Add Policy`**
2. Seleccionar o crear policy de tipo **`Custom Mediation`** / **`In Sequence`**
3. Subir el XML → aplicar a todos los resources

> En APIM 4.6.0 el panel de mediación puede estar bajo **`Policies`** o bajo
> **`Message Mediation`** según la vista de la API. El XML es el mismo en ambos casos.

---

## 3. Artefacto del MI: EmprIdFromHeader.xml

Esta sequence **reemplaza** la combinación `jwtValidator + emprIdInjector` en los resources MCP
del `toolsMANAPI.xml`. Lee el `X-Empr-Id` inyectado por el APIM y lo convierte en la property
de contexto `jwt_empr_id`, que todo el código downstream ya usa.

**La lógica downstream del MI NO cambia** — los resource sequences siguen leyendo
`get-property('jwt_empr_id')` para construir las URLs de los DataServices.

### Archivo: `_backend/api/ToolsAPIProject/.../sequences/EmprIdFromHeader.xml`

Ver el artefacto en el repo. Versión Sprint 2 (Fix 3 — ADR-008):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<sequence name="emprIdFromHeader" xmlns="http://ws.apache.org/ns/synapse">

    <property name="jwt_empr_id"
              expression="$trp:X-Empr-Id"
              scope="default" type="STRING"/>

    <filter xpath="get-property('jwt_empr_id') = '' or not(boolean(get-property('jwt_empr_id')))">
        <then>
            <!-- WARN explícito: 503 indica falla de configuración del APIM, no del cliente. -->
            <log level="custom" category="WARN">
                <property name="text"  value="#TRAZA | MI | EmprIdFromHeader | X-Empr-Id MISSING — APIM mediation may not be applied. Check Key Manager Dnato and in-sequence association."/>
                <property name="api"   expression="get-property('SYNAPSE_REST_API')"/>
                <property name="path"  expression="get-property('REST_FULL_REQUEST_PATH')"/>
            </log>
            <payloadFactory media-type="json">
                <format>{"error":"identity_header_missing","message":"X-Empr-Id no presente. La mediacion del APIM no se aplico. Verificar configuracion del Key Manager Dnato y la in-sequence EmprIdInjectorPolicy."}</format>
                <args/>
            </payloadFactory>
            <property name="messageType" scope="axis2" type="STRING" value="application/json"/>
            <property name="HTTP_SC"     scope="axis2" type="STRING" value="503"/>
            <respond/>
        </then>
    </filter>

    <log level="custom" category="DEBUG">
        <property name="text"    value="#TRAZA | MCP | EmprIdFromHeader | empr_id cargado desde header APIM"/>
        <property name="empr_id" expression="get-property('jwt_empr_id')"/>
    </log>

</sequence>
```

### Cambios en toolsMANAPI.xml

En cada `<resource>` MCP del `toolsMANAPI.xml`, se reemplaza:

```xml
<!-- ANTES (flujo passthrough — OBSOLETO por ADR-008) -->
<sequence key="jwtValidator"/>
<sequence key="emprIdInjector"/>
```

Por:

```xml
<!-- DESPUÉS (ADR-008: empr_id ya validado e inyectado por el APIM) -->
<sequence key="emprIdFromHeader"/>
```

Los resources afectados en `toolsMANAPI.xml`:
- `/mcp/equipo/{equi_id}` (GET)
- `/mcp/equipos` (GET)
- `/mcp/ot` (POST) — create_ot
- `/mcp/ot` (GET) — list OTs
- `/mcp/ot/{id_solicitud}` (GET) — detalle OT

El resto de la lógica (URL building con `jwt_empr_id`, calls al DataService, fault sequences)
**no cambia**. El nombre de la property `jwt_empr_id` se hereda intencionalmente para no tener
que tocar la lógica downstream.

---

## 4. Tipo del claim empr_id

**Fix ADR-008 Sprint 2 (junio 2026):** `JwtIssuer.php` ahora castea `empr_id` a string
explícitamente (`(string) $empr_id`) antes de incluirlo en el payload del JWT. El tipo es
consistente en todo el flujo:

```
Dnato JWT payload → empr_id: "42" (string)
  → EmprIdInjectorPolicy (.toString() ya era explícito — sin cambios)
  → X-Empr-Id: 42  (header de transporte, siempre string)
  → EmprIdFromHeader → jwt_empr_id = "42" (string en contexto MI)
  → DataService :empr_id = "42" (parámetro string)
```

No hay conversiones implícitas de tipo en el camino. Test verificado en `JwtIssuerTest::testEmprIdIsString()`.

---

## 5. Seguridad del header X-Empr-Id

**El cliente no puede falsificar `X-Empr-Id`:**
- **Fix ADR-008 Sprint 2:** la `EmprIdInjectorPolicy` del APIM ejecuta un **`remove` explícito
  del header `X-Empr-Id` entrante como primer paso**, antes de procesar el token. Aunque
  después el script fallara por algún edge case, el header malicioso ya fue eliminado.
  A continuación sobreescribe el header con el valor del claim del JWT ya validado.
- Si el cliente envía `X-Empr-Id: 999`, el APIM lo descarta incondicionalmente y setea el
  valor correcto del claim del token (test Hurl: `jwt-validation.hurl` Caso h).
- El MI **confía** en `X-Empr-Id` porque solo llega tráfico desde el APIM (no expuesto
  directamente en internet). En DEV/TEST esto se garantiza por configuración de red (el puerto
  8280 del MI no es accesible desde fuera del gateway).
- En PROD, el firewall debe garantizar que el puerto 8280 del MI solo acepta tráfico desde el
  APIM (sin acceso directo desde internet).

---

## 6. Comportamiento ante falla de mediación APIM

Si el MI recibe un request MCP **sin el header `X-Empr-Id`** (porque la in-sequence del APIM
no se aplicó, el KM Dnato no está configurado, o se accede al MI directamente sin pasar por
el APIM), la sequence `emprIdFromHeader` responde con:

```
HTTP 503 Service Unavailable
{
  "error": "identity_header_missing",
  "message": "X-Empr-Id no presente. La mediacion del APIM no se aplico. Verificar configuracion del Key Manager Dnato y la in-sequence EmprIdInjectorPolicy."
}
```

Además escribe un log nivel **WARN** (visible en los logs del MI, no solo DEBUG) con la API
y el path del request para facilitar el diagnóstico.

**Interpretación de un 503 con `identity_header_missing`:**
- El cliente no hizo nada mal.
- El problema es de configuración del APIM: la in-sequence `EmprIdInjectorPolicy` no está
  asociada a la API o el Key Manager Dnato no está configurado correctamente.
- **Acción:** revisar blocker B2 (KM Dnato en Admin) y B3 (in-sequence en Publisher).

**Por qué 503 y no 400/401:**
- `400 Bad Request`: implicaría que el cliente envió algo mal. El cliente no envía `X-Empr-Id`
  (no debería hacerlo). Es engañoso.
- `401 Unauthorized`: implicaría problema de autenticación. El token podría estar bien; el
  problema es de config del APIM. Engañoso.
- `503 Service Unavailable`: dice "el servicio no puede responder por configuración interna".
  Es exactamente lo que pasa.

Test: `tests/security/mi-fallback.hurl` (llama al MI directamente en `:8280`).

---

## 7. Cómo testear el flujo completo

### 7.1 Test de inyección (verificar que X-Empr-Id llega al MI)

Agregar temporalmente un `<log>` en el MI que imprima los headers recibidos, o usar el endpoint
de echo del MI si existe. Verificar que el header `X-Empr-Id` llega con el valor del claim del
JWT.

```bash
JWT=$(php index.php cli issue_test_token <email> 42)  # en el host de Dnato

# Llamar via APIM (el header X-Empr-Id lo agrega el APIM, no el cliente)
curl -k -H "Authorization: Bearer $JWT" \
     https://localhost:8243/equipos/1.0/mcp/equipos

# Verificar en logs del MI que empr_id = 42 y que los datos son de empresa 42
```

### 7.2 Test de aislamiento (empresa A no ve datos de empresa B)

```bash
JWT_A=$(php index.php cli issue_test_token <email_A> 42)
JWT_B=$(php index.php cli issue_test_token <email_B> 99)

# JWT empresa A → debe ver solo equipos con empr_id=42
curl -k -H "Authorization: Bearer $JWT_A" \
     https://localhost:8243/equipos/1.0/mcp/equipos
# Verificar: ningún equipo tiene empr_id != 42

# JWT empresa B → debe ver solo equipos con empr_id=99
curl -k -H "Authorization: Bearer $JWT_B" \
     https://localhost:8243/equipos/1.0/mcp/equipos
# Verificar: ningún equipo tiene empr_id != 99
```

### 7.3 Test de seguridad (token inválido no llega al MI)

```bash
# Sin token → 401 del APIM, el MI no registra ningún log para este request
curl -k https://localhost:8243/equipos/1.0/mcp/equipos

# Token con firma inválida → 401 del APIM
curl -k -H "Authorization: Bearer eyJhbGciOiJSUzI1NiJ9.eyJlbXByX2lkIjo5OX0.INVALIDSIG" \
     https://localhost:8243/equipos/1.0/mcp/equipos
```

Confirmar en los logs del MI que estos requests **no generan ninguna entrada de log**
(el APIM los rechaza antes de que lleguen al MI).

### 7.4 Test anti-spoofing (Fix 1 — defensa en profundidad)

Verificar que enviar `X-Empr-Id` en el request no tiene efecto:

```bash
JWT=$(php index.php cli issue_test_token <email> 42)  # JWT de empresa 42

# Enviar X-Empr-Id: 999 junto con JWT de empresa 42
# Resultado esperado: datos de empresa 42 (la del JWT), no de 999
curl -k -H "Authorization: Bearer $JWT" \
     -H "X-Empr-Id: 999" \
     https://localhost:8243/equipos/1.0/mcp/equipos

# Verificar que ningún equipo tiene empr_id=999
```

Test automatizado: `tests/security/jwt-validation.hurl` Caso h.

### 7.5 Test de fallback 503 (Fix 3 — MI sin header)

```bash
# Llamar al MI directamente sin X-Empr-Id → 503 identity_header_missing
curl http://localhost:8280/tools/man/mcp/equipos
# Esperado: HTTP 503, body {"error":"identity_header_missing",...}
```

Test automatizado: `tests/security/mi-fallback.hurl`.

---

## 8. Relación con los tests Hurl existentes

Los tests en `tests/security/jwt-validation.hurl` apuntaban al MI directamente (`:8280`). Con
ADR-008 los tests de **validación del token** deben apuntar al **APIM** (`:8243`), ya que es el
APIM quien rechaza los tokens inválidos. Ver `tests/security/jwt-validation.hurl` —
la variable `MI_HOST` se reemplaza por `APIM_HOST` (`:8243`). Los casos c, d, e (firma inválida,
expirado, sin empr_id) ahora son rechazados por el APIM, no por el MI.

Los tests en `tests/security/dataservice-isolation.hurl` apuntan a los DataServices
directamente y no pasan por auth — siguen siendo válidos tal cual.
