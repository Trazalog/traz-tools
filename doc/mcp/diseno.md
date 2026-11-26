# El conector MCP de Trazalog — diseño

## Objetivo

Qué es: cómo está pensado el conector MCP que deja a los asistentes de IA (Claude y otros) usar los datos de Trazalog: cómo llama un cliente a un servidor MCP, el estándar de anotaciones de cada tool y el servidor MCP virtual único que publica todas las tools. Para quién: quien diseñe o agregue una tool, incluido Claude Code. Cuándo leerlo: antes de crear o cambiar una tool MCP. Qué NO cubre: cómo se publica y se opera ([`publicar-y-operar.md`](publicar-y-operar.md)), cómo se prueba ([`pruebas-y-casos.md`](pruebas-y-casos.md)) ni la identidad ([`identidad-y-seguridad.md`](../identidad/identidad-y-seguridad.md)).

**Partes:** 1. Cómo Claude llama a un MCP · 2. Estándar de anotaciones de las tools · 3. El servidor MCP virtual unificado

---

## Parte 1 — Cómo Claude llama a un MCP

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

### 1. El modelo mental correcto: son DOS protocolos apilados

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

### 2. CAPA 1 — Autorización (OAuth 2.1)

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

### 3. CAPA 2 — Sesión MCP sobre Streamable HTTP

Transporte: **Streamable HTTP** (un solo endpoint, `https://host/.../mcp`). Reglas:

#### 3.1 Mensajes
- **Cliente → server:** `POST` con un mensaje JSON-RPC en el body.
- **Header obligatorio:** `Accept: application/json, text/event-stream`.
- La respuesta del `POST` puede ser:
  - `Content-Type: application/json` → una respuesta JSON única, **o**
  - `Content-Type: text/event-stream` → un **stream SSE** (¡no se puede leer con un `read()` bloqueante!).
- **Server → cliente (push):** el cliente puede abrir un `GET` al mismo endpoint con
  `Accept: text/event-stream` para recibir notificaciones server-initiated por SSE.

#### 3.2 El handshake (orden EXACTO, no negociable)
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

#### 3.3 `Mcp-Session-Id` (la fuente de intermitencia)
- Si el server devuelve `Mcp-Session-Id` en la respuesta del `initialize`, el cliente **DEBE**
  mandarlo en **todos** los requests siguientes.
- Si un request llega sin el session-id correcto (o expiró), el server responde **404** y el
  cliente **re-inicializa** desde cero.
- Un proxy que mangle, pierda o duplique este header genera exactamente el síntoma
  "a veces anda, a veces 'Couldn't reach'" + loops de re-initialize.

#### 3.4 Negociación de versión (la causa del 404/error con WSO2)
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

### 4. Qué hace Claude.ai web *específicamente* (y por qué es el peor cliente para validar)

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

### 5. Por qué el proxy Python actual es la herramienta equivocada

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

### 6. Estrategia recomendada (en orden)

#### Paso 1 — Validar el MCP server SIN Claude.ai, SIN OAuth, SIN ngrok (PRIORIDAD)
Probar que la arquitectura funciona end-to-end con un cliente MCP honesto:

**Opción A — MCP Inspector (oficial):**
```bash
npx @modelcontextprotocol/inspector
# Transport: Streamable HTTP
# URL: https://localhost:8243/trazalog-equipos/1.0/mcp
# Auth: pegar un JWT real de Dnato a mano como Bearer
```
Si el Inspector lista las tools y `get_equipos` devuelve datos → **la arquitectura está probada.**

**Opción B — script curl con JWT real** (ya documentado en `doc/historial/mcp/virtual-mcp-equipos.md` §4.3):
`initialize` → `tools/list` → `tools/call` con `Authorization: Bearer <JWT_DNATO>`.
El JWT se firma con la clave de `traz-comp-dnato` (ver `project-adr008-blockers-state` memory).

> Esto es lo que respeta la arquitectura: el `empr_id` sale del claim del JWT vía
> `EmprIdInjectorPolicy`. Con un token fake del proxy, `tools/call` nunca iba a aislar bien.

#### Paso 2 — (Opcional) Demo con Claude.ai web
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

#### Paso 3 — Camino productivo de verdad
En PROD no hay ngrok ni proxy: el MCP server vive detrás del gateway de WSO2 en un dominio
real, con OAuth real de WSO2, y el agente IA (Claude API, Claude Desktop, etc.) autentica
contra WSO2. La arquitectura de ADR-008 ya contempla esto.

---

### 7. Checklist de verificación pendiente en WSO2 (responder antes de tocar Claude.ai)

- [ ] ¿El gateway (8243) responde **401 + `WWW-Authenticate`** al pegar al MCP endpoint sin token?
- [ ] ¿Expone `/.well-known/oauth-protected-resource` apuntando al Key Manager?
- [ ] ¿WSO2 soporta DCR (`/oauth2/register` / `/client-registration`) o hay que pre-registrar?
- [ ] ¿La app `TrazalogDnatoMCP` (consumerKey `z_CtMHRzWPSgY8aXWYxFuzsOli4a`) sirve como client OAuth?
- [ ] ¿WSO2 devuelve `Mcp-Session-Id` en el `initialize`? (define si el bridge debe propagarlo)
- [ ] ¿Hay forma de configurar/actualizar WSO2 para que negocie `2025-11-25` → `2025-06-18`
      en vez de errorear? (elimina la necesidad de cualquier shim)

---

### 8. Errores cometidos en la sesión anterior (para no repetir)

1. ❌ Inyectar `tools` en la respuesta de `initialize`. → Las tools van por `tools/list`, siempre.
2. ❌ Shimear `protocolVersion` en la **respuesta**. → Sólo se shimea el request; la negociación
   la maneja el protocolo.
3. ❌ Fingir OAuth en Python. → WSO2 ya ES el OAuth server.
4. ❌ Usar un `BaseHTTPRequestHandler` como proxy MCP. → No hace SSE ni keep-alive transparente.
5. ❌ Validar la arquitectura contra Claude.ai web. → Usar MCP Inspector / curl con JWT real.

---

### 9. Validación honesta EJECUTADA — 23-jun-2026 (curl + JWT real, sin proxy)

Se corrió el Paso 1 de la §6 contra `trazalog-equipos` con APIM (9443/8243) y MI (8290) arriba,
JWKS server PHP en 8090 (`scripts/dev/dnato-jwks-server.php`) y JWT firmado por
`scripts/dev/mint-dnato-jwt.py` (empr_id=42). **Sin proxy, sin Claude.ai, sin ngrok.**

#### 9.1 Qué FUNCIONA (arquitectura probada hasta el DataService)

| Paso | Resultado |
|---|---|
| `initialize` | ✅ HTTP 200, `protocolVersion: 2025-06-18`, `serverInfo` correcto |
| `tools/list` | ✅ devuelve `get_equipo` + `get_equipos` con `inputSchema` completos |
| Backend MI **sin** `X-Empr-Id` | ✅ HTTP 503 `identity_header_missing` (Fix 3 ADR-008 confirmado) |
| Validación JWT | ✅ no devuelve 401 → el issuer Dnato + JWKS valida bien |

#### 9.2 Dato clave: el MCP server de WSO2 4.6.0 es STATELESS

La respuesta de `initialize` **NO** trae header `Mcp-Session-Id` (sólo declara
`Access-Control-Expose-Headers: Mcp-Session-Id`, pero no setea el valor). → No hay manejo de
sesión server-side. El cliente no necesita propagar session-id. Esto **descarta** que la
intermitencia de Claude.ai sea por session-id del lado del server; el problema vive en el bridge.

#### 9.3 Qué NO funciona y POR QUÉ (dos causas apiladas)

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

#### 9.4 Conclusión de la validación

La arquitectura MCP + identidad (ADR-008) está **probada correcta hasta el DataService**.
Los dos blockers para un `tools/call` verde son: **(a) conseguir una BD DEV con datos** y
**(b) el bug `-32600` de WSO2** (mitigable haciendo que el backend nunca devuelva no-2xx crudo,
o reportándolo/parcheándolo). Ninguno es un problema de protocolo MCP, de Claude, ni del proxy.

---

### 10. Continuación 23-jun-2026 — BACKEND COMPLETO ARREGLADO (BD real conectada)

Con la BD `10.142.0.13` accesible por VPN se arregló toda la cadena de datos:

#### 10.1 Fix datasource (driver MySQL 8)
`AssetPlannerDataSource` apuntaba a MySQL `assetv2` con `com.mysql.jdbc.Driver` (clase legacy
de Connector/J 5) sobre el jar 8.0.17 → `NullPointerException: charsetName` en MySQL 8.
**Fix:** `com.mysql.cj.jdbc.Driver` + URL `?useSSL=false&allowPublicKeyRetrieval=true&useUnicode=true&characterEncoding=UTF-8`.
(La data NO es postgres 5432; es MySQL DEV legacy. Columna empresa = `id_empresa`. Empresas con
equipos: 8→107, 6→13, 9→1. No existe la empresa 42 que usábamos antes.)

#### 10.2 Fix toolsMANAPI (Content-Type en GET sin body)
Los 4 recursos GET (`get_equipo/get_equipos/get_ot/get_ots`) seteaban
`<property name="messageType" value="application/json" scope="axis2"/>` antes del `<call>`.
Eso hace que un **GET sin body** salga con `Content-Type: application/json` → el
`JsonStreamBuilder` del DSS intenta parsear un body vacío → `NullPointerException: charsetName` → 500.
**Comprobado:** GET al DSS con `Content-Type: application/json` → 500; sin él → 200.
**Fix:** antes del `<call>` de cada GET, remover `messageType`, `ContentType` (axis2) y el header
`Content-Type` (transport). El POST `create_ot` NO se toca (su body JSON sí necesita messageType).

#### 10.3 RESULTADO backend (probado)
`GET http://localhost:8290/tools/man/mcp/equipos` con `X-Empr-Id: 8` → **200 + 107 equipos reales**,
UTF-8 correcto. **Aislamiento multi-tenant PROBADO:** `X-Empr-Id: 9` devuelve solo su 1 equipo.

#### 10.4 ÚNICO blocker restante — bug del McpMediator de APIM 4.6.0 (tools/call)
`tools/call` por el gateway (8243) sigue dando "Empty reply" / `-32600`. **Verificado en logs: el
MI NUNCA es invocado** durante el tools/call → el `McpMediator` falla en `handleMcpResponse`
(`McpException: Invalid Request`, -32600) **antes** de llamar al backend, y crashea el transporte
("Unknown category for status code -32600"). `initialize` y `tools/list` (sin backend) funcionan.
→ Es un **bug/config del producto WSO2 APIM 4.6.0 en el MCP gateway**, NO de nuestro backend
(que ya funciona perfecto por el path HTTP API). Próximo paso: inspeccionar/recrear el MCP server
`trazalog-equipos` en el Publisher (mapeo tool→operación, endpoint backend, business plan) o
escalar a WSO2. Los fixes 10.1 y 10.2 están en el source del repo (sin commitear) y hot-deployados.

---

### 11. RESOLUCIÓN FINAL — demo end-to-end funcionando (24-jun-2026)

**El `tools/call` MCP funciona end-to-end con datos reales y aislamiento multi-tenant.**

#### 11.1 El -32600 NO era un bug del producto
El `McpException: Invalid Request` (-32600) del McpMediator se disparaba al traducir las
respuestas de **error** del backend roto (500/404/503). Con el backend devolviendo **200 JSON
limpio**, el McpMediator envuelve la respuesta correctamente como `result.content[].text`.
Lección: arreglar el backend primero; el McpMediator no tenía la culpa.

#### 11.2 El empr_id NO se puede extraer en la operation policy
La `EmprIdInjectorPolicy` (in-flow) no tiene acceso al JWT: APIM elimina `Authorization` tras
validar, y el backend JWT (`X-JWT-Assertion`) se agrega recién al despachar al backend — después
de las operation policies. Verificado: ambos headers ausentes dentro de la policy. **La policy fue
detacheada** de las APIs MCP. (Además tenía 3 bugs propios: Nashorn `Java.type` en Rhino,
`function mediator()` nunca invocada, `split("\\.")` literal.)

#### 11.3 La arquitectura que SÍ funciona (Opción 1 — backend JWT)
```
Cliente MCP → APIM gateway (8243)
   ├─ valida el JWT de Dnato (Key Manager [[apim.jwt.issuer]] + JWKS en :8090)
   └─ genera y firma el backend JWT → header X-JWT-Assertion (incluye claim empr_id)
→ MI (8290) toolsMANAPI → sequence emprIdFromHeader:
   └─ decodifica X-JWT-Assertion, extrae empr_id, setea jwt_empr_id (fail-closed 503)
→ DataService MANEquiposDataService → MySQL assetv2 (filtra por id_empresa)
→ McpMediator envuelve el 200 JSON como result MCP
```

#### 11.4 Config REQUERIDA en el APIM (runtime, NO en el repo — registrar acá)
En `$APIM_HOME/repository/conf/deployment.toml`, habilitar el backend JWT (por default
`apim.jwt.enable=false`). **Requiere reiniciar APIM.**
```toml
[apim.jwt]
enable = true
header = "X-JWT-Assertion"
convert_dialect = false   # mantiene empr_id como claim flat (no namespaced bajo wso2.org/claims)
```
Sin esto, APIM no envía X-JWT-Assertion y el MI responde 503 `identity_missing`.

#### 11.5 Seguridad
- El `empr_id` viaja en el X-JWT-Assertion **firmado por APIM**; el cliente no puede falsificarlo
  a través del gateway. Ya NO se confía en un `X-Empr-Id` enviado por el cliente.
- Pendiente PROD: el MI decodifica la assertion **sin validar la firma** (DEV). En PROD validar la
  firma contra el cert del gateway y asegurar que el MI (8290) no sea alcanzable directo por clientes.

#### 11.6 Validación honesta — confirmada
Todo probado con `curl + JWT real de Dnato` (mint-dnato-jwt.py), SIN proxy Python, SIN Claude.ai
web, SIN ngrok. La estrategia de §6 (validar con cliente honesto) fue la correcta.

---

## Parte 2 — Estándar de anotaciones de las tools

Estándar obligatorio para todas las tools MCP de Trazalog v3.

**Origen:** sección 10.5 del DDR-004 (MCP Architecture Doc). La omisión de
`readOnlyHint` y `destructiveHint` causa el 30% de los rechazos en el
Connectors Directory de Claude. Este estándar se aplica desde el primer commit.

---

### Las dos annotations obligatorias

#### `readOnlyHint: true`

Indica que la tool **solo lee datos** — no crea, no modifica, no elimina,
no tiene side effects observables en el sistema.

**Cuándo aplicar:** consultas, listados, búsquedas, cálculos de KPIs, reportes.

#### `destructiveHint: true`

Indica que la tool **modifica el estado del sistema** — puede crear registros,
actualizar datos, cancelar operaciones, enviar notificaciones, o desencadenar
procesos que no se pueden deshacer sin intervención explícita.

**Cuándo aplicar:** creaciones, modificaciones, cancelaciones, envíos,
activaciones, cualquier acción que persiste en la base de datos.

> **Regla:** toda tool tiene exactamente una de las dos. Nunca ambas, nunca ninguna.

---

### Árbol de decisión para tools futuras

Ante una tool nueva, responder en orden:

```
1. ¿La tool escribe, modifica o elimina algo en la BD?
   ├── SÍ → destructiveHint: true
   └── NO → continuar

2. ¿La tool envía un mensaje, email, notificación o dispara un proceso externo?
   ├── SÍ → destructiveHint: true
   └── NO → continuar

3. ¿La tool solo lee datos (consulta, listado, búsqueda, cálculo)?
   └── SÍ → readOnlyHint: true
```

Si después de las tres preguntas hay duda, la regla conservadora es `destructiveHint: true`.

---

### Clasificación — Tools Phase 1

| Tool | Annotation | Razón |
|---|---|---|
| `get_equipment` | `readOnlyHint: true` | Consulta catálogo de equipos — solo lectura |
| `get_ot` | `readOnlyHint: true` | Consulta órdenes de trabajo — solo lectura |
| `get_kpis` | `readOnlyHint: true` | Calcula MTBF/MTTR/Disponibilidad — solo lectura |
| `get_stock` | `readOnlyHint: true` | Consulta stock en depósito — solo lectura |
| `get_preventivos` | `readOnlyHint: true` | Lista preventivos vencidos/próximos — solo lectura |
| `create_ot` | `destructiveHint: true` | Crea una OT en la BD — escribe datos |

---

### Implementación en FastMCP (Python — Fase 2+)

Solo para tools que requieran Python (IA/ML, procesamiento no-estructurado — ver ADR-002).

#### Tool de solo lectura

```python
from fastmcp import FastMCP

mcp = FastMCP("trazalog-mcp-server")

@mcp.tool(annotations={"readOnlyHint": True})
def get_equipment(cliente_id: int, estado: str = "activo") -> dict:
    """
    Devuelve el catálogo de equipos de un cliente.
    Filtros opcionales: estado (activo, inactivo, todos).
    """
    # Llama al endpoint REST de WSO2 APIM
    ...
```

#### Tool con side effects

```python
@mcp.tool(annotations={"destructiveHint": True})
def create_ot(
    equipo_id: int,
    descripcion: str,
    tipo: str,
    prioridad: str = "normal"
) -> dict:
    """
    Crea una orden de trabajo correctiva en Asset Planner.
    Tipos válidos: correctiva, mejora. Prioridades: baja, normal, alta, crítica.
    """
    # Llama al endpoint REST de WSO2 APIM — escribe en BD
    ...
```

---

### Implementación en WSO2 Virtual MCP Server

Para tools generadas automáticamente desde OpenAPI specs (modo principal — ADR-002),
las annotations se configuran en la definición del MCP Server en el Publisher de WSO2 APIM.

En el archivo de configuración del Virtual MCP Server (JSON exportable desde el Publisher):

```json
{
  "mcpServer": {
    "tools": [
      {
        "name": "get_equipment",
        "description": "Devuelve el catálogo de equipos de un cliente.",
        "operationId": "getEquipment",
        "annotations": {
          "readOnlyHint": true,
          "destructiveHint": false
        }
      },
      {
        "name": "create_ot",
        "description": "Crea una orden de trabajo correctiva en Asset Planner.",
        "operationId": "createOT",
        "annotations": {
          "readOnlyHint": false,
          "destructiveHint": true
        }
      }
    ]
  }
}
```

Verificar que el campo `annotations` aparezca en el JSON que devuelve `tools/list`
al conectarse con MCP Inspector (Etapa 1 del testing workflow — ver
[`doc/infra/ambientes.md`](../infra/ambientes.md)).

---

### Checklist de compliance antes de hacer PR

- [ ] La tool tiene exactamente una annotation: `readOnlyHint: true` o `destructiveHint: true`
- [ ] La annotation es correcta según el árbol de decisión de este documento
- [ ] MCP Inspector muestra la annotation en el schema de `tools/list`
- [ ] La annotation aparece en la documentación de la tool en el MCP Hub

---

### Referencias

- MCP Specification — Tool Annotations: https://modelcontextprotocol.io/docs/concepts/tools#annotations
- WSO2 MCP Gateway docs: https://apim.docs.wso2.com/en/latest/mcp-gateway/overview/
- Testing workflow: [`doc/infra/ambientes.md`](../infra/ambientes.md)
- Arquitectura MCP Trazalog v3: [`doc/v3/TRAZALOG_v3_MCP_ARCHITECTURE.md`](../v3/TRAZALOG_v3_MCP_ARCHITECTURE.md)

---

## Parte 3 — El servidor MCP virtual unificado

Este documento es el **checklist de consola** para publicar en WSO2 APIM
**un solo** Virtual MCP Server (`trazalog-operaciones`) que reemplaza a los
dos que existían por separado desde Sprint 2 (`trazalog-equipos`,
`trazalog-ots`), sumando además las tools nuevas de Almacenes. Es para vos
(Rodolfo), para ejecutar en la consola del Publisher — Claude Code no tiene
acceso a esa consola y no ejecuta nada de esto.

Cubre, en orden: qué tools va a tener el server (§1), los pasos de consola
para publicarlo (§2), **cómo migrar sin cortar** lo que ya funciona hoy
(§3), y un smoke test de las 9 tools antes de dar el paso final (§4).

**No cubre:** cómo compilar/redesplegar `toolsMCPAPI` en el MI si volvés a
tocar su código — eso es
[`doc/infra/wso2.md`](../infra/wso2.md).
Tampoco cubre el despliegue a la VM de GCP (`doc/v3/deployment-gcp.md`,
Tarea 3.5) — este documento es sobre tu entorno de DEV.

---

**API fuente:** `doc/api/trazalog-operaciones.yaml` (nueva, unificada — reemplaza a `EquiposAPI-TrazalogMCP` + `OrdenesdeTrabajoAPI-TrazalogMCP`)
**Backend:** `toolsMCPAPI` (WSO2 MI, context `/tools/mcp`) — fachada delgada, ver `_backend/api/ToolsAPIProject/.../artifacts/apis/toolsMCPAPI.xml`
**Estado:** Pendiente configuración en consola WSO2 (pasos manuales de Rodolfo, esta tarea solo prepara los artefactos)
**Decisión base:** [ADR-013](../adr/ADR-013-unificacion-mcp.md) — un solo Virtual MCP Server con todas las tools, prefijadas por módulo (`man_`, `alm_`)

> ⚠️ **Nota sobre `doc/mcp/publicar-y-operar.md`:** ese documento (Sprint 2) describe la inyección de identidad como un header `X-Empr-Id` seteado por una mediación del APIM. **Eso quedó desactualizado.** El mecanismo vigente (ADR-009, confirmado en `CONTEXT-PACK.md` §3 y en `EmprIdFromHeader.xml`) es distinto: el APIM genera su propio backend JWT (`apim.jwt.enable=true`) y lo manda como header **`X-JWT-Assertion`**; el MI lo decodifica con la sequence `emprIdFromHeader` (ya usada por `toolsMANAPI` y por `toolsMCPAPI`). Los pasos de este documento reflejan el mecanismo vigente — no repliques la mediación de `X-Empr-Id` de `openapi-publish-procedure.md` para esta API nueva.

---

### 1. Tools del server unificado (9)

| Tool | Método | Operación fuente | Módulo | Annotation |
|---|---|---|---|---|
| `man_get_equipos` | GET | `/mcp/man/equipos` | Mantenimiento | `readOnlyHint` |
| `man_get_equipo` | GET | `/mcp/man/equipo/{equi_id}` | Mantenimiento | `readOnlyHint` |
| `man_get_ots` | GET | `/mcp/man/ot` | Mantenimiento | `readOnlyHint` |
| `man_get_ot` | GET | `/mcp/man/ot/{id_solicitud}` | Mantenimiento | `readOnlyHint` |
| `man_create_ot` | POST | `/mcp/man/ot` | Mantenimiento | `destructiveHint` |
| `alm_get_stock` | GET | `/mcp/alm/stock` | Almacenes | `readOnlyHint` |
| `alm_get_pedidos_materiales` | GET | `/mcp/alm/pedidos` | Almacenes | `readOnlyHint` |
| `alm_get_pedido_material` | GET | `/mcp/alm/pedido/{pema_id}` | Almacenes | `readOnlyHint` |
| `alm_crear_pedido_materiales` | POST | `/mcp/alm/pedido` | Almacenes | `destructiveHint` |

**Sobre las annotations:** están declaradas en `trazalog-operaciones.yaml` con la extensión `x-mcp-annotations` (`readOnlyHint`/`destructiveHint` por operación, ver `doc/mcp/diseno.md`). **No confirmado que WSO2 4.6.0 lea esa extensión al generar las tools** — no hay documentación oficial que confirme el nombre exacto del vendor-extension para MCP en 4.6.0, y `equipos.yaml`/`ot.yaml` (Sprint 2) tampoco la usaban. Verificar en el smoke test (§4, paso 2) si `tools/list` devuelve las annotations; si no aparecen, es un gap ya preexistente de Sprint 2 (no introducido por esta tarea), a resolver aparte.

---

### 2. Pasos de configuración en WSO2 API Manager 4.6.0

#### 2.1 Prerequisito

El emisor JWT **`trazalog-dnato`** ya configurado en `[[apim.jwt.issuer]]` del `deployment.toml` del APIM — ver `doc/identidad/identidad-y-seguridad.md` §3. **No es un Key Manager registrado en el Admin UI** (APIM 4.6.0 no tiene conector genérico para IdPs custom — la Admin UI/REST API no permite crear uno para Dnato). Es la misma configuración global que ya usan `EquiposAPI-TrazalogMCP`/`OrdenesdeTrabajoAPI-TrazalogMCP`, no hay nada nuevo que crear ni seleccionar por-API en el Publisher para esto.

#### 2.2 Importar la spec

1. Ir a `https://localhost:9443/publisher` (o el host correspondiente si es contra la VM de GCP)
2. **`+ Create API`** → **`Import OpenAPI`**
3. Seleccionar `doc/api/trazalog-operaciones.yaml`
4. Verificar los campos pre-completados:
   - **Name:** `Trazalog MCP Server` — nombre real usado por Rodolfo al publicar (2026-08-08), distinto del sugerido originalmente (`Trazalog Operaciones`)
   - **Version:** `1.0`
   - **Context:** `/trazalog/mcp` — confirmado, no `/trazalog-operaciones`
5. **`Create`**

#### 2.3 Configurar el backend (Endpoint)

En **`Develop`** → **`API Configurations`** → **`Endpoints`**:

| Campo | Valor |
|---|---|
| Endpoint type | HTTP/REST Endpoint |
| Production URL | `http://<host-del-MI>:8290/tools/mcp` |
| Sandbox URL | `http://<host-del-MI>:8290/tools/mcp` |

> **Corrección 2026-08-08:** este documento decía puerto `8280`, que es incorrecto — el HTTP passthrough del MI en DEV es el `8290` (confirmado en `doc/infra/wso2.md` y usado toda la sesión). El primer smoke test real contra el gateway (§4) falló con 404 hasta corregir esto — quedaba apuntando a `10.142.0.13:8280`, un host/puerto que no es el MI de DEV.
>
> El APIM proxea al MI, context `/tools/mcp` (`toolsMCPAPI`) — no a `/tools/man` ni `/tools/alm` directamente. `toolsMCPAPI` es la única fachada que expone esta API; internamente delega a `toolsALMAPI` para las tools `alm_*`, pero eso es transparente para el APIM.
>
> **⚠️ Este mismo Endpoint hay que configurarlo DOS VECES:** una vez acá, en la API (`Trazalog MCP Server` / `Trazalog MCP`), y otra vez en el **MCP Server generado** (§2.6) — son artefactos separados en el Publisher, cada uno con su propio `endpointConfig`, y **generar el MCP Server desde la API NO copia el endpoint automáticamente** (confirmado en la práctica: quedó `endpointConfig: null` en el MCP Server hasta configurarlo a mano). Repetir este mismo paso en `MCP Servers` → `Trazalog MCP Server` → `API Configurations` → `Endpoints` después de §2.6.

#### 2.4 Seguridad — OAuth2 con validación de JWT de Dnato

> **Corrección 2026-08-08:** la versión anterior de esta sección decía "seleccionar únicamente
> Dnato como Key Manager, des-seleccionar Resident Key Manager". Eso es **incorrecto** —
> contradice `doc/identidad/identidad-y-seguridad.md` §3, que documenta explícitamente que Dnato
> **no se registra como Key Manager** (no hay conector genérico en APIM 4.6.0 para IdPs custom).
> No va a aparecer un "Dnato" en el selector de Key Managers del Publisher porque nunca se creó
> ahí — la validación de Dnato ocurre en una capa distinta (`[[apim.jwt.issuer]]`, ver §2.1).
> Corregido acá con los pasos reales, verificados en Sprint 2 (`apim-keymanager-dnato.md` §5).

En **`Develop`** → **`API Configurations`** → **`Runtime`** → **`Application Level Security`**:

1. Marcar **`OAuth2`**. Desmarcar Basic Auth y API Key.
2. **Key Managers:** dejar el selector como está por defecto (típicamente solo `Resident Key Manager` marcado). No hay nada de Dnato para seleccionar acá — no tocar este selector.
3. **Desactivar `Enable Subscription Validation`**. Este es el paso que realmente habilita el flujo Dnato: sin `azp` (consumerKey) en el JWT, la subscription validation devuelve 403 aunque la firma sea válida — ver `apim-keymanager-dnato.md` §4.1.
4. Confirmar que `apim.jwt.enable=true` está activo en el `deployment.toml` del APIM (configuración global, ya debería estarlo si `trazalog-equipos`/`trazalog-ots` funcionan hoy — no es algo que se configure por API). Si no está activo, es un bloqueante — no seguir sin confirmarlo primero.

No hace falta asociar ninguna mediación/policy de inyección de `empr_id` — a diferencia de lo que describe `openapi-publish-procedure.md` (desactualizado, ver nota al inicio), el backend JWT (`X-JWT-Assertion`) lo genera el APIM automáticamente vía `apim.jwt.enable`, sin policy por API.

#### 2.5 Publicar la API

1. **`Publish`** (esquina superior derecha)
2. Estado → `Published`

#### 2.6 Generar el Virtual MCP Server único

**Opción A — desde la vista de la API (recomendada):**

1. Abrir la API `Trazalog MCP Server` recién publicada
2. En la pantalla de overview, botón **`Generate MCP Server`**

**Opción B — desde el menú de MCP Servers:**

1. Menú lateral → **`MCP Servers`** → **`Create MCP Server`** → **`Create MCP Server from Existing API`**

**Wizard de creación:**

- **Select an API to create MCP Server from:** `Trazalog MCP Server` (versión 1.0)
- **Select Operations for Tool Generation:** tildar las **9** operaciones (las 5 de mantenimiento + las 4 de almacenes)
- **Next**
- **Name:** `Trazalog MCP Server`
- **Version:** `1.0`
- **Context:** `/trazalog/mcp`
- **Create**

> **Nota 2026-08-08:** los valores de arriba son los reales, confirmados una vez que Rodolfo publicó la API — difieren de la sugerencia original de ADR-013/este documento (`trazalog-operaciones` / `/trazalog-operaciones`). Gateway Type resultante: `Regular`.

#### 2.7 Configurar Tools

Menú lateral → **`Tools`**: confirmar que aparecen las 9, con los nombres `man_*`/`alm_*` tal cual (vienen del `operationId` de la spec, no hay que renombrarlas). Editar `Description` solo si alguna no quedó clara — las descripciones ya están escritas semánticamente en la spec para que Claude sepa cuándo usar cada una.

#### 2.8 Deploy y publicar el MCP Server

Igual que en Sprint 2 (`virtual-mcp-equipos.md` §2.7-2.8): **`Deployments`** → `Deploy New Revision` → environment `Default` → **`Deploy`**. Después **`Publish`** (Lifecycle).

#### 2.8-bis Suscribir la aplicación `TrazalogDnatoMCP` (obligatorio — no está en Sprint 2 porque ahí ya existía)

**Sin este paso, las 9 tools fallan con `900908 Resource forbidden — API Subscription validation failed`**, aunque el JWT sea válido y `apim.jwt.enable` esté bien configurado. Confirmado en el primer smoke test real (§4): `trazalog-equipos`/`trazalog-ots` ya tenían esta suscripción desde Sprint 2 (por eso nunca hizo falta documentarlo), pero el **MCP Server nuevo es un artefacto propio y no hereda las suscripciones de la API fuente ni de ningún otro server**.

1. Ir a `https://localhost:9443/devportal` (o el host correspondiente)
2. Buscar la aplicación **`TrazalogDnatoMCP`** (la misma que usan `trazalog-equipos`/`trazalog-ots` — ver `apim-keymanager-dnato.md` §4.1, `consumerKey = z_CtMHRzWPSgY8aXWYxFuzsOli4a`)
3. **`APIs`** (o **`MCP Servers`**, según cómo lo liste el DevPortal) → buscar **`Trazalog MCP Server`** → **`Subscribe`**
4. Confirmar la suscripción con throttling policy `Unlimited`

> Si se necesita hacer esto por API/consola en vez de UI: `POST /api/am/devportal/v3/subscriptions` con `applicationId` + `apiId` del **MCP Server** (no de la API fuente — son IDs distintos, confirmar con `GET /api/am/publisher/v4/mcp-servers`). Requiere un token OAuth2 con scope `apim:subscribe` (no basic auth) — ver `client-registration/v0.17/register` + `/oauth2/token` grant `password` si hace falta generarlo desde cero.

#### 2.9 Endpoint MCP resultante

```
https://<host-del-apim>:8243/trazalog/mcp/1.0/mcp
```

Confirmado en DEV: `https://localhost:8243/trazalog/mcp/1.0/mcp` (MCP playground de Rodolfo, 2026-08-08).

Versión de protocolo MCP: `2025-06-18` (igual que los servers actuales).

---

### 3. Guía de migración coordinada (ADR-013 decisión #5)

**⚠️ Orden estricto — no saltear pasos ni cambiar el orden:**

1. **Crear y publicar** `Trazalog MCP Server` (contexto `/trazalog/mcp` — pasos §2 de este documento). `trazalog-equipos` y `trazalog-ots` **siguen activos** durante todo este proceso — no tocarlos todavía.
2. **Smoke test completo de las 9 tools** contra el server nuevo (ver §4 abajo), incluida la prueba de aislamiento de 2 empresas.
3. **Recién con el smoke test en verde**, reconfigurar Claude.ai:
   - `Settings` → `Integrations` → `MCP Servers`
   - Cambiar (o agregar) la URL a `https://<host-del-apim>:8243/trazalog/mcp/1.0/mcp`
4. **Recién ahí**, despublicar `trazalog-equipos` y `trazalog-ots` (Publisher → cada API → Lifecycle → `Retire` o `Block`, según se prefiera conservar el historial).

**⚠️ Advertencia explícita: NO despublicar `trazalog-equipos`/`trazalog-ots` antes de tener el paso 3 confirmado.** Si algo del server unificado falla después de haberlos despublicado, la demo queda sin ningún MCP Server funcionando — la ventana de convivencia (viejos + nuevo activos en paralelo) es la red de seguridad de esta migración.

---

### 4. Smoke test de las 9 tools

Equivalente al smoke test manual de Sprint 2, ahora respaldado por los tests automatizados de cada tarea (`tests/security/mcp-facade-man-tools.hurl`, `mcp-facade-man-get-equipos.hurl`, `mcp-facade-alm-tools.hurl` — corridos contra el MI directo). Este smoke test es contra el **APIM real** (con JWT de Dnato), no contra el MI directo.

```bash
JWT="<JWT real de Dnato, empresa A>"
JWT_B="<JWT real de Dnato, empresa B — para el paso 2>"
HOST="<host-del-apim>:8243/trazalog/mcp/1.0"

# 1. Handshake MCP
curl -k -X POST https://$HOST/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"smoke-test","version":"1.0"}},"id":1}'

# 2. tools/list — confirmar que aparecen las 9, y si las annotations
#    (readOnlyHint/destructiveHint) están presentes en el schema (ver nota §1)
curl -k -X POST https://$HOST/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}'

# 3-9. tools/call de cada una de las 9 tools, con JWT de empresa A.
#    Para man_create_ot y alm_crear_pedido_materiales: confirmar que el
#    rollback dispara si se fuerza un fallo (ver DoD de las tareas 3.2/3.3).

# 10. Prueba de aislamiento — repetir alguna lectura (ej. man_get_equipos,
#     alm_get_stock) con JWT_B y confirmar que NO aparecen datos de la
#     empresa A, y viceversa.
```

DoD de este smoke test (a marcar por Rodolfo antes de avanzar al paso 3 de la migración):

- [x] `initialize` y `tools/list` responden correctamente, con las 9 tools — **confirmado 2026-08-08** contra `https://localhost:8243/trazalog/mcp/1.0/mcp`
- [x] Cada una de las 9 tools responde `tools/call` sin error con JWT válido — **confirmado**, ver troubleshooting abajo (dos bloqueos reales encontrados y corregidos en el camino)
- [x] `man_create_ot` y `alm_crear_pedido_materiales` ejecutan y disparan Bonita real — **confirmado** (OT 292/case 30003, pedido 1482/case 30004, ambos marcados como descartables). Rollback ante fallo forzado ya se había validado antes contra el MI directo (mismo código de orquestación, sin cambios) — no se repitió el fallo forzado contra el gateway real
- [ ] `destructiveHint`/`readOnlyHint` en el schema de `tools/list` — **NO aparecen**. Confirma el gap ya flageado en §1: WSO2 4.6.0 no está leyendo `x-mcp-annotations` (o usa un nombre de extensión distinto). Gap preexistente de Sprint 2, no bloqueante — Claude igual sabe cuándo pedir confirmación por la descripción semántica de cada tool
- [x] Aislamiento verificado: JWT empresa B (`empr_id=187`) no ve datos de empresa A en `man_get_equipos` ni `alm_get_stock` — devuelve listas vacías, no cruza datos
- [x] Sin JWT → 401 (`900902 Missing Credentials`)

#### Troubleshooting real encontrado en este smoke test (2026-08-08)

| Síntoma | Causa | Fix aplicado |
|---|---|---|
| `900908 Resource forbidden — API Subscription validation failed` en las 9 tools | La app `TrazalogDnatoMCP` no tenía suscripción al MCP Server nuevo (es un artefacto separado, no hereda suscripciones) | Suscribir la app al MCP Server — ver §2.8-bis (nuevo paso, agregado a este documento) |
| `HTTP Status Code: 404` en `tools/call`, ya con la suscripción resuelta | El `endpointConfig` del MCP Server estaba vacío (`null`) — generarlo desde la API no copia el endpoint. Y el endpoint de la propia API apuntaba a `10.142.0.13:8280` (dato incorrecto de este mismo documento desde la Tarea 3.4) en vez de `localhost:8290` (MI real de DEV) | Configurar el endpoint en AMBOS artefactos (API y MCP Server) apuntando a `localhost:8290/tools/mcp`, y desplegar una revisión nueva de cada uno — ver §2.3 actualizado |

Ambos problemas eran de configuración de la instancia real de Rodolfo (no del código ni de los artefactos MI) — se corrigieron directamente contra su APIM vía REST API para completar este smoke test, y quedan documentados acá para que no se repitan si se vuelve a publicar la API o el MCP Server desde cero.

---

### 5. Después de la migración

- Actualizar este documento (o `STATE.md`) marcando `trazalog-equipos`/`trazalog-ots` como despublicados y la fecha.
- `doc/historial/mcp/virtual-mcp-equipos.md` y `virtual-mcp-ots.md` quedan como registro histórico de Sprint 2 — no se borran, se podría agregar una nota de "reemplazado por virtual-mcp-unificado.md" en cada uno (no hecho en esta tarea, a criterio de Rodolfo).

## De dónde salió este documento

Fusionado el 2026-11-26 (unificación de documentación, `DOC-UNIF-3`) a partir de:

- `doc/mcp/diseno.md`
- `doc/mcp/diseno.md`
- `doc/mcp/diseno.md`

El texto se juntó sin reescribirlo; solo se bajaron niveles de título y se ajustaron enlaces. La historia de cada parte está en `git log --follow` de los archivos originales.
