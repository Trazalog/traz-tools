# Cómo Claude llama a un MCP server — y cómo implementarlo respetando la arquitectura

> **Para quién es esto:** una sesión futura de Claude Code (probablemente Sonnet) que
> retome la integración del MCP server `trazalog-equipos` con un cliente MCP.
> **Objetivo:** dejar de hacer ensayo-y-error y entender el protocolo *antes* de tocar nada.
>
> **TL;DR de la decisión:**
> 1. **NO** validar la arquitectura contra Claude.ai web. Es el cliente más opaco y exigente.
> 2. Validar el MCP server con **MCP Inspector** o un script con JWT real → prueba la arquitectura sin OAuth/ngrok/proxy.
> 3. El **proxy Python con OAuth fake** (`scripts/dev/mcp-oauth-proxy.py`) es un parche frágil
>    que descarta el OAuth real de WSO2. No es la solución. Usarlo sólo como apunte de qué NO hacer.
> 4. Si en algún momento SÍ se quiere Claude.ai web, el bridge debe ser un reverse proxy
>    de verdad (nginx/Caddy/OpenResty) que rutee al OAuth **real** de WSO2, no que lo finja.

---

## 1. El modelo mental correcto: son DOS protocolos apilados

Conectar un cliente MCP remoto (como Claude) a un server son **dos capas independientes**:

```
┌─────────────────────────────────────────────────────────────┐
│  CAPA 1 — Autorización (OAuth 2.1 + PKCE)                    │
│  Pasa UNA vez. Resultado: un access_token (Bearer).          │
└─────────────────────────────────────────────────────────────┘
                          ↓ Bearer token
┌─────────────────────────────────────────────────────────────┐
│  CAPA 2 — Sesión MCP (JSON-RPC 2.0 sobre Streamable HTTP)    │
│  initialize → notifications/initialized → tools/list → ...   │
└─────────────────────────────────────────────────────────────┘
```

Si confundís las capas (como pasó: meter tools en el `initialize`, fingir OAuth, shimear
versiones en la respuesta), rompés todo. Cada capa tiene reglas estrictas.

---

## 2. CAPA 1 — Autorización (OAuth 2.1)

Cuando el MCP server requiere auth, el cliente sigue el **MCP Authorization spec** (basado
en OAuth 2.1, RFC 9728, RFC 8414, RFC 7591). El flujo que hace Claude:

1. **Probe inicial:** el cliente pega al endpoint MCP sin token. El server responde **401**
   con header `WWW-Authenticate: Bearer resource_metadata="<url>"`.
2. **Protected Resource Metadata (RFC 9728):** el cliente busca
   `GET /.well-known/oauth-protected-resource`. Esto le dice *cuál es el authorization server*.
3. **Authorization Server Metadata (RFC 8414):** el cliente busca
   `GET /.well-known/oauth-authorization-server` en el auth server. Obtiene `authorization_endpoint`,
   `token_endpoint`, `registration_endpoint`, etc.
4. **Dynamic Client Registration (RFC 7591):** si el server lo soporta, el cliente hace
   `POST /register` y obtiene un `client_id`. Si NO, hace falta un client pre-registrado.
5. **Authorization Code + PKCE:** el cliente abre el browser al `authorization_endpoint`,
   el usuario consiente, vuelve con un `code`, el cliente lo canjea en el `token_endpoint`
   por un `access_token`.

> **El punto clave para la arquitectura Trazalog:**
> **WSO2 API Manager ES un authorization server OAuth2/OIDC completo** (el Key Manager, puerto 9443).
> Expone `/oauth2/authorize`, `/oauth2/token`, `/oauth2/register` (DCR), `/.well-known/openid-configuration`.
> **No hace falta inventar un OAuth en Python.** El trabajo real es:
> - Verificar si el **gateway** (8243) expone el 401 + `WWW-Authenticate` + protected-resource-metadata
>   para los MCP servers, apuntando al Key Manager.
> - Que el `client_id` esté registrado en WSO2 (la app `TrazalogDnatoMCP` ya existe, ver ADR-008).

---

## 3. CAPA 2 — Sesión MCP sobre Streamable HTTP

Transporte: **Streamable HTTP** (un solo endpoint, `https://host/.../mcp`). Reglas:

### 3.1 Mensajes
- **Cliente → server:** `POST` con un mensaje JSON-RPC en el body.
- **Header obligatorio:** `Accept: application/json, text/event-stream`.
- La respuesta del `POST` puede ser:
  - `Content-Type: application/json` → una respuesta JSON única, **o**
  - `Content-Type: text/event-stream` → un **stream SSE** (¡no se puede leer con un `read()` bloqueante!).
- **Server → cliente (push):** el cliente puede abrir un `GET` al mismo endpoint con
  `Accept: text/event-stream` para recibir notificaciones server-initiated por SSE.

### 3.2 El handshake (orden EXACTO, no negociable)
```
1. POST initialize           → server responde result {protocolVersion, capabilities, serverInfo}
                               (y PUEDE setear el header Mcp-Session-Id)
2. POST notifications/initialized  (es una notification, sin id → server responde 202, body vacío)
3. POST tools/list           → server responde la lista de tools
4. POST tools/call           → ejecuta una tool (acá viaja el Bearer y se resuelve empr_id)
```

> **Las tools SE DESCUBREN SIEMPRE con `tools/list`. NUNCA van inline en el `initialize`.**
> Esto es igual en TODAS las versiones (2024-11-05, 2025-03-26, 2025-06-18, 2025-11-25).
> (Error cometido antes: inyectar `tools` en la respuesta de `initialize` → Claude la ve
> malformada → "Couldn't reach the server".)

### 3.3 `Mcp-Session-Id` (la fuente de intermitencia)
- Si el server devuelve `Mcp-Session-Id` en la respuesta del `initialize`, el cliente **DEBE**
  mandarlo en **todos** los requests siguientes.
- Si un request llega sin el session-id correcto (o expiró), el server responde **404** y el
  cliente **re-inicializa** desde cero.
- Un proxy que mangle, pierda o duplique este header genera exactamente el síntoma
  "a veces anda, a veces 'Couldn't reach'" + loops de re-initialize.

### 3.4 Negociación de versión (la causa del 404/error con WSO2)
Regla del spec: el cliente manda su `protocolVersion` preferida en `initialize.params`.
**El server DEBE responder con la misma versión si la soporta, o con OTRA que sí soporte.**
El cliente, si soporta la versión que devolvió el server, continúa con esa.

- Claude.ai manda `2025-11-25`.
- WSO2 APIM 4.6.0 soporta `2025-06-18`.
- **Bug de WSO2:** ante una versión que no conoce, **tira error en vez de responder `2025-06-18`.**
  Esto es una violación del spec por parte de WSO2.
- El único shim *legítimo* es reescribir la `protocolVersion` del **request** a `2025-06-18`.
  **NO** se debe shimear la respuesta (mentirle al cliente sobre la versión rompe la negociación).

---

## 4. Qué hace Claude.ai web *específicamente* (y por qué es el peor cliente para validar)

Observado en los logs de esta integración:

- Abre **dos sesiones distintas**: una para la pantalla de **Settings** (clientInfo
  `Anthropic/ClaudeAI`) que hace `initialize` + `notifications/initialized` y **a veces NO llama
  `tools/list`**; y otra de **backend** (clientInfo `claude-ai`) que sí completa hasta `tools/list`.
- Manda `protocolVersion: 2025-11-25`.
- Su Dynamic Client Registration es una caja negra: a veces no llama `/register` y espera un
  Client ID pre-cargado a mano.
- Reusa conexiones HTTP/1.1 keep-alive → muy sensible a cualquier desync de framing del proxy.
- Mensajes de error genéricos ("Couldn't reach the MCP server", "No se pudieron recargar las
  herramientas") que NO distinguen entre fallo de transporte, de auth o de protocolo.

**Conclusión:** Claude.ai web es un *objetivo de demo*, no una *herramienta de validación*.
No se debe usar para probar si la arquitectura MCP está bien.

---

## 5. Por qué el proxy Python actual es la herramienta equivocada

`scripts/dev/mcp-oauth-proxy.py` falla por diseño, no por bugs puntuales:

| Problema | Por qué rompe |
|---|---|
| **Finge OAuth** con `client_id`/`secret` hardcodeados | Descarta el Key Manager de WSO2 = tu seguridad real. |
| **`resp.read()` bloqueante** | Si WSO2 responde SSE (`text/event-stream`), el proxy se cuelga hasta timeout. |
| **No maneja el `GET` SSE** | Cuando Claude abre el stream server→cliente, el proxy lo bloquea. |
| **Re-arma headers a mano** (`Content-Length`, strip manual) | Desync de keep-alive HTTP/1.1 → intermitencia. |
| **No propaga `Mcp-Session-Id`** de forma consistente | Loops de re-initialize / 404. |

Un `BaseHTTPRequestHandler` de la stdlib **no sabe** hacer streaming SSE ni proxying
transparente HTTP/1.1. Es la herramienta equivocada para MCP Streamable HTTP.

---

## 6. Estrategia recomendada (en orden)

### Paso 1 — Validar el MCP server SIN Claude.ai, SIN OAuth, SIN ngrok (PRIORIDAD)
Probar que la arquitectura funciona end-to-end con un cliente MCP honesto:

**Opción A — MCP Inspector (oficial):**
```bash
npx @modelcontextprotocol/inspector
# Transport: Streamable HTTP
# URL: https://localhost:8243/trazalog-equipos/1.0/mcp
# Auth: pegar un JWT real de Dnato a mano como Bearer
```
Si el Inspector lista las tools y `get_equipos` devuelve datos → **la arquitectura está probada.**

**Opción B — script curl con JWT real** (ya documentado en `doc/mcp/virtual-mcp-equipos.md` §4.3):
`initialize` → `tools/list` → `tools/call` con `Authorization: Bearer <JWT_DNATO>`.
El JWT se firma con la clave de `traz-comp-dnato` (ver `project-adr008-blockers-state` memory).

> Esto es lo que respeta la arquitectura: el `empr_id` sale del claim del JWT vía
> `EmprIdInjectorPolicy`. Con un token fake del proxy, `tools/call` nunca iba a aislar bien.

### Paso 2 — (Opcional) Demo con Claude.ai web
Sólo si se quiere mostrar la integración con Claude.ai web. Requiere resolver 3 gaps reales:

1. **OAuth discovery:** que WSO2 exponga el 401 + protected-resource-metadata en el gateway,
   apuntando al Key Manager. Verificar config de APIM 4.6.0; NO fingir en Python.
2. **Hosting público de host único:** ngrok expone un solo puerto. El gateway (8243) y el
   Key Manager (9443) están en puertos distintos. Hace falta un reverse proxy **real**
   (nginx/Caddy/OpenResty) que rutee bajo un solo host:
   - `/oauth2/*`, `/.well-known/*` → `https://localhost:9443` (OAuth real de WSO2)
   - `/trazalog-equipos/*` → `https://localhost:8243` (gateway)
   nginx/Caddy manejan SSE y keep-alive nativamente (a diferencia del Python).
3. **Gap de versión:** el único custom logic necesario es reescribir `protocolVersion`
   del request `initialize` a `2025-06-18` (bug de WSO2). Eso requiere un proxy programable
   (OpenResty/njs o un mitm chico) — pero que SÓLO haga eso y rutee al OAuth real.

### Paso 3 — Camino productivo de verdad
En PROD no hay ngrok ni proxy: el MCP server vive detrás del gateway de WSO2 en un dominio
real, con OAuth real de WSO2, y el agente IA (Claude API, Claude Desktop, etc.) autentica
contra WSO2. La arquitectura de ADR-008 ya contempla esto.

---

## 7. Checklist de verificación pendiente en WSO2 (responder antes de tocar Claude.ai)

- [ ] ¿El gateway (8243) responde **401 + `WWW-Authenticate`** al pegar al MCP endpoint sin token?
- [ ] ¿Expone `/.well-known/oauth-protected-resource` apuntando al Key Manager?
- [ ] ¿WSO2 soporta DCR (`/oauth2/register` / `/client-registration`) o hay que pre-registrar?
- [ ] ¿La app `TrazalogDnatoMCP` (consumerKey `z_CtMHRzWPSgY8aXWYxFuzsOli4a`) sirve como client OAuth?
- [ ] ¿WSO2 devuelve `Mcp-Session-Id` en el `initialize`? (define si el bridge debe propagarlo)
- [ ] ¿Hay forma de configurar/actualizar WSO2 para que negocie `2025-11-25` → `2025-06-18`
      en vez de errorear? (elimina la necesidad de cualquier shim)

---

## 8. Errores cometidos en la sesión anterior (para no repetir)

1. ❌ Inyectar `tools` en la respuesta de `initialize`. → Las tools van por `tools/list`, siempre.
2. ❌ Shimear `protocolVersion` en la **respuesta**. → Sólo se shimea el request; la negociación
   la maneja el protocolo.
3. ❌ Fingir OAuth en Python. → WSO2 ya ES el OAuth server.
4. ❌ Usar un `BaseHTTPRequestHandler` como proxy MCP. → No hace SSE ni keep-alive transparente.
5. ❌ Validar la arquitectura contra Claude.ai web. → Usar MCP Inspector / curl con JWT real.

---

## 9. Validación honesta EJECUTADA — 23-jun-2026 (curl + JWT real, sin proxy)

Se corrió el Paso 1 de la §6 contra `trazalog-equipos` con APIM (9443/8243) y MI (8290) arriba,
JWKS server PHP en 8090 (`scripts/dev/dnato-jwks-server.php`) y JWT firmado por
`scripts/dev/mint-dnato-jwt.py` (empr_id=42). **Sin proxy, sin Claude.ai, sin ngrok.**

### 9.1 Qué FUNCIONA (arquitectura probada hasta el DataService)

| Paso | Resultado |
|---|---|
| `initialize` | ✅ HTTP 200, `protocolVersion: 2025-06-18`, `serverInfo` correcto |
| `tools/list` | ✅ devuelve `get_equipo` + `get_equipos` con `inputSchema` completos |
| Backend MI **sin** `X-Empr-Id` | ✅ HTTP 503 `identity_header_missing` (Fix 3 ADR-008 confirmado) |
| Validación JWT | ✅ no devuelve 401 → el issuer Dnato + JWKS valida bien |

### 9.2 Dato clave: el MCP server de WSO2 4.6.0 es STATELESS

La respuesta de `initialize` **NO** trae header `Mcp-Session-Id` (sólo declara
`Access-Control-Expose-Headers: Mcp-Session-Id`, pero no setea el valor). → No hay manejo de
sesión server-side. El cliente no necesita propagar session-id. Esto **descarta** que la
intermitencia de Claude.ai sea por session-id del lado del server; el problema vive en el bridge.

### 9.3 Qué NO funciona y POR QUÉ (dos causas apiladas)

`tools/call get_equipos` → **"Empty reply from server"** (curl HTTP 000). Causas:

1. **PRIMARIA — No hay BD en DEV.** El backend MI directo con `X-Empr-Id: 42` responde
   **HTTP 500 HTML**: `Error processing GET request for /services/MANEquiposDataService/...`.
   Los DataServices logean `Error in retrieving database metadata`. Sin una BD con datos de
   prueba, `tools/call` **no puede** devolver verde. (Ver kickoff §5.2: usar BD DEV reseteable.)

2. **SECUNDARIA — Bug de WSO2 APIM 4.6.0 en `McpMediator`.** Cuando el backend devuelve un
   no-2xx, `McpMediator.handleMcpResponse` (línea 293) emite un JSON-RPC error `-32600`
   ("Invalid Request") y lo pasa como **status HTTP** al transporte passthru:
   ```
   ERROR McpMediator - Error while handling MCP response: McpException: Invalid Request
   ERROR SourceHandler - Unknown category for status code -32600 (IllegalArgumentException)
   ERROR SourceHandler - ClosedChannelException
   ```
   → el gateway **crashea el socket** en vez de devolver un error MCP limpio. El cliente ve
   "Empty reply" / "Couldn't reach the server" aunque el problema real sea un 500 del backend.

> **Implicancia para Claude.ai:** este bug hace que CUALQUIER error de backend se vea como
> "servidor inalcanzable". Es engañoso. Con un backend que devuelve 200+JSON válido,
> probablemente NO se dispara — hay que probarlo con BD real para confirmar.

### 9.4 Conclusión de la validación

La arquitectura MCP + identidad (ADR-008) está **probada correcta hasta el DataService**.
Los dos blockers para un `tools/call` verde son: **(a) conseguir una BD DEV con datos** y
**(b) el bug `-32600` de WSO2** (mitigable haciendo que el backend nunca devuelva no-2xx crudo,
o reportándolo/parcheándolo). Ninguno es un problema de protocolo MCP, de Claude, ni del proxy.

---

## 10. Continuación 23-jun-2026 — BACKEND COMPLETO ARREGLADO (BD real conectada)

Con la BD `10.142.0.13` accesible por VPN se arregló toda la cadena de datos:

### 10.1 Fix datasource (driver MySQL 8)
`AssetPlannerDataSource` apuntaba a MySQL `assetv2` con `com.mysql.jdbc.Driver` (clase legacy
de Connector/J 5) sobre el jar 8.0.17 → `NullPointerException: charsetName` en MySQL 8.
**Fix:** `com.mysql.cj.jdbc.Driver` + URL `?useSSL=false&allowPublicKeyRetrieval=true&useUnicode=true&characterEncoding=UTF-8`.
(La data NO es postgres 5432; es MySQL DEV legacy. Columna empresa = `id_empresa`. Empresas con
equipos: 8→107, 6→13, 9→1. No existe la empresa 42 que usábamos antes.)

### 10.2 Fix toolsMANAPI (Content-Type en GET sin body)
Los 4 recursos GET (`get_equipo/get_equipos/get_ot/get_ots`) seteaban
`<property name="messageType" value="application/json" scope="axis2"/>` antes del `<call>`.
Eso hace que un **GET sin body** salga con `Content-Type: application/json` → el
`JsonStreamBuilder` del DSS intenta parsear un body vacío → `NullPointerException: charsetName` → 500.
**Comprobado:** GET al DSS con `Content-Type: application/json` → 500; sin él → 200.
**Fix:** antes del `<call>` de cada GET, remover `messageType`, `ContentType` (axis2) y el header
`Content-Type` (transport). El POST `create_ot` NO se toca (su body JSON sí necesita messageType).

### 10.3 RESULTADO backend (probado)
`GET http://localhost:8290/tools/man/mcp/equipos` con `X-Empr-Id: 8` → **200 + 107 equipos reales**,
UTF-8 correcto. **Aislamiento multi-tenant PROBADO:** `X-Empr-Id: 9` devuelve solo su 1 equipo.

### 10.4 ÚNICO blocker restante — bug del McpMediator de APIM 4.6.0 (tools/call)
`tools/call` por el gateway (8243) sigue dando "Empty reply" / `-32600`. **Verificado en logs: el
MI NUNCA es invocado** durante el tools/call → el `McpMediator` falla en `handleMcpResponse`
(`McpException: Invalid Request`, -32600) **antes** de llamar al backend, y crashea el transporte
("Unknown category for status code -32600"). `initialize` y `tools/list` (sin backend) funcionan.
→ Es un **bug/config del producto WSO2 APIM 4.6.0 en el MCP gateway**, NO de nuestro backend
(que ya funciona perfecto por el path HTTP API). Próximo paso: inspeccionar/recrear el MCP server
`trazalog-equipos` en el Publisher (mapeo tool→operación, endpoint backend, business plan) o
escalar a WSO2. Los fixes 10.1 y 10.2 están en el source del repo (sin commitear) y hot-deployados.

---

## 11. RESOLUCIÓN FINAL — demo end-to-end funcionando (24-jun-2026)

**El `tools/call` MCP funciona end-to-end con datos reales y aislamiento multi-tenant.**

### 11.1 El -32600 NO era un bug del producto
El `McpException: Invalid Request` (-32600) del McpMediator se disparaba al traducir las
respuestas de **error** del backend roto (500/404/503). Con el backend devolviendo **200 JSON
limpio**, el McpMediator envuelve la respuesta correctamente como `result.content[].text`.
Lección: arreglar el backend primero; el McpMediator no tenía la culpa.

### 11.2 El empr_id NO se puede extraer en la operation policy
La `EmprIdInjectorPolicy` (in-flow) no tiene acceso al JWT: APIM elimina `Authorization` tras
validar, y el backend JWT (`X-JWT-Assertion`) se agrega recién al despachar al backend — después
de las operation policies. Verificado: ambos headers ausentes dentro de la policy. **La policy fue
detacheada** de las APIs MCP. (Además tenía 3 bugs propios: Nashorn `Java.type` en Rhino,
`function mediator()` nunca invocada, `split("\\.")` literal.)

### 11.3 La arquitectura que SÍ funciona (Opción 1 — backend JWT)
```
Cliente MCP → APIM gateway (8243)
   ├─ valida el JWT de Dnato (Key Manager [[apim.jwt.issuer]] + JWKS en :8090)
   └─ genera y firma el backend JWT → header X-JWT-Assertion (incluye claim empr_id)
→ MI (8290) toolsMANAPI → sequence emprIdFromHeader:
   └─ decodifica X-JWT-Assertion, extrae empr_id, setea jwt_empr_id (fail-closed 503)
→ DataService MANEquiposDataService → MySQL assetv2 (filtra por id_empresa)
→ McpMediator envuelve el 200 JSON como result MCP
```

### 11.4 Config REQUERIDA en el APIM (runtime, NO en el repo — registrar acá)
En `$APIM_HOME/repository/conf/deployment.toml`, habilitar el backend JWT (por default
`apim.jwt.enable=false`). **Requiere reiniciar APIM.**
```toml
[apim.jwt]
enable = true
header = "X-JWT-Assertion"
convert_dialect = false   # mantiene empr_id como claim flat (no namespaced bajo wso2.org/claims)
```
Sin esto, APIM no envía X-JWT-Assertion y el MI responde 503 `identity_missing`.

### 11.5 Seguridad
- El `empr_id` viaja en el X-JWT-Assertion **firmado por APIM**; el cliente no puede falsificarlo
  a través del gateway. Ya NO se confía en un `X-Empr-Id` enviado por el cliente.
- Pendiente PROD: el MI decodifica la assertion **sin validar la firma** (DEV). En PROD validar la
  firma contra el cert del gateway y asegurar que el MI (8290) no sea alcanzable directo por clientes.

### 11.6 Validación honesta — confirmada
Todo probado con `curl + JWT real de Dnato` (mint-dnato-jwt.py), SIN proxy Python, SIN Claude.ai
web, SIN ngrok. La estrategia de §6 (validar con cliente honesto) fue la correcta.
