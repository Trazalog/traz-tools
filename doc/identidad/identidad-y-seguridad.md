# Identidad y seguridad de Trazalog v3

## Objetivo

Qué es: cómo se identifica a un usuario y a su empresa de punta a punta: descubrimiento OAuth entre el API Manager y Dnato, Dnato como emisor de los permisos (JWT), sus claves, la validación del permiso en el gateway y la inyección del `empr_id` (ADR-008 y ADR-009). Para quién: quien toque login, permisos o aislamiento por empresa. Cuándo leerlo: antes de cambiar cualquier cosa de identidad. Qué NO cubre: las decisiones en sí, que están en [`doc/adr/`](../adr/) y en `TRAZALOG_v3_MCP_ARCHITECTURE.md` §6. ⚠️ Todas las partes vienen de documentos de mayo a julio de 2026 y llevan su aviso de verificación.

**Partes:** 1. Descubrimiento OAuth: qué hace el API Manager y qué hace Dnato · 2. Dnato como Key Manager federado en el API Manager · 3. Requisitos del JWT de Dnato · 4. Clave pública RS256 de Dnato · 5. Validación del permiso en el gateway · 6. Inyección del empr_id desde el API Manager

---

## Parte 1 — Descubrimiento OAuth: qué hace el API Manager y qué hace Dnato

> ⚠️ Sin verificar desde 2026-07-14: se juntó tal cual estaba; antes de seguirlo, contrastarlo con el código y con ADR-008/ADR-009.

**Contexto:** E2-MCP-EQUIPOS-OTS — integración Claude.ai como cliente MCP  
**Fecha:** 2026-06-30  
**Prerrequisitos:** [dnato-jwt-prereqs.md](identidad-y-seguridad.md) · [apim-keymanager-dnato.md](identidad-y-seguridad.md)  
**Arquitectura de referencia:** TAD-IDENT-04 (Dnato es el AS) · TAD-IDENT-P01 (Dnato con OAuth 2.1 + PKCE)

---

### 1. Roles en la arquitectura OAuth 2.1 + MCP

| Componente | Rol OAuth 2.1 | Qué publica |
|---|---|---|
| **WSO2 APIM 4.6.0** | Resource Server (RS) | Protected Resource Metadata (RFC 9728) |
| **Dnato (traz-comp-dnato)** | Authorization Server (AS) | AS Metadata (RFC 8414) + Dynamic Client Registration (RFC 7591) |
| **Claude.ai** | Client | Inicia el flujo OAuth 2.1 PKCE; descubre los endpoints automáticamente |

Esta separación es inviolable per TAD-IDENT-04: el usuario se autentica contra Trazalog/Dnato, no contra WSO2.

---

### 2. Cadena de discovery completa (RFC 9728 → RFC 8414 → RFC 7591)

```
Claude.ai                        APIM (RS)                             Dnato (AS)
   |                                |                                      |
   |── POST /trazalog-equipos/1.0/mcp ──>                                  |
   |<── 401 WWW-Authenticate: Bearer resource_metadata="https://apim/..." ─|
   |                                |                                      |
   |── GET /.well-known/oauth-protected-resource/trazalog-equipos/1.0/mcp ─>|
   |<── 200 PRM JSON ──────────────|                                      |
   |    { "resource": "...",        |                                      |
   |      "authorization_servers": ["https://dnato/traz-comp-dnato/oauth"] }
   |                                |                                      |
   |── GET https://dnato/traz-comp-dnato/oauth/.well-known/oauth-authorization-server ──>
   |<─────────────────────────────────────────── 200 AS metadata JSON ────|
   |    { "authorization_endpoint": "...",                                 |
   |      "token_endpoint": "...",                                         |
   |      "registration_endpoint": "https://dnato/.../oauth/register" }   |
   |                                                                       |
   |── POST https://dnato/.../oauth/register (RFC 7591 DCR) ─────────────>|
   |<─────────────────────────────── 201 { "client_id": "..." } ─────────|
   |                                                                       |
   |── GET https://dnato/.../oauth/authorize?client_id=...&code_challenge=...
   |   (browser del usuario) ─────────────────────────────────────────────>
   |<──────────── redirect con ?code=... ───────────────────────────────__|
   |                                                                       |
   |── POST https://dnato/.../oauth/token ───────────────────────────────>|
   |<──────────── 200 { "access_token": "<JWT Dnato>" } ─────────────────|
   |                                                                       |
   |── POST /trazalog-equipos/1.0/mcp Authorization: Bearer <JWT> ──>    |
   |<── 200 MCP tools/call result ─|                                      |
```

---

### 3. Mapeo de endpoints por RFC

#### 3.1 RFC 9728 — Protected Resource Metadata (PRM)

**Publica: APIM** (es el Resource Server que protege las APIs MCP).

La URL del PRM se construye por RFC 9728 §3.1 (path-based) a partir del URL del recurso:

```
Recurso:       https://<apim-host>/trazalog-equipos/1.0/mcp
URL PRM RFC:   https://<apim-host>/.well-known/oauth-protected-resource/trazalog-equipos/1.0/mcp
Fallback RFC:  https://<apim-host>/.well-known/oauth-protected-resource
```

Contenido esperado:

```json
{
  "resource": "https://<apim-host>/trazalog-equipos/1.0/mcp",
  "authorization_servers": ["https://<dnato-host>/traz-comp-dnato/oauth"]
}
```

**Estado actual:** APIM sirve el PRM en un path distinto al de la RFC:

```
APIM hoy:     /trazalog-equipos/1.0/.well-known/oauth-protected-resource  → 200 ✅ (correcto en contenido)
RFC 9728:     /.well-known/oauth-protected-resource/trazalog-equipos/1.0/mcp  → 404 ❌
RFC fallback: /.well-known/oauth-protected-resource                            → 404 ❌
```

El path que usa APIM hoy (embebido dentro del contexto de la API) no coincide con el path que Claude.ai construye siguiendo RFC 9728. Claude.ai nunca llega al PRM y, sin él, no puede saber que el AS es Dnato.

El header `WWW-Authenticate: Bearer resource_metadata="..."` que APIM emite en el 401 apunta al path correcto, pero Claude.ai prioriza la construcción path-based (RFC 9728 §3.1) sobre el hint del header.

#### 3.2 RFC 8414 — Authorization Server Metadata

**Publica: Dnato** (es el Authorization Server).

La URL se construye a partir del `issuer` que el PRM devolvió:

```
Issuer (de PRM): https://<dnato-host>/traz-comp-dnato/oauth
URL AS metadata: https://<dnato-host>/traz-comp-dnato/oauth/.well-known/oauth-authorization-server
```

**Estado actual:** Dnato **ya sirve este endpoint** correctamente:

```
GET /traz-comp-dnato/oauth/.well-known/oauth-authorization-server → 200 ✅
```

Respuesta actual:
```json
{
  "issuer":                                "https://<dnato-host>/traz-comp-dnato/oauth",
  "authorization_endpoint":               "https://<dnato-host>/traz-comp-dnato/oauth/authorize",
  "token_endpoint":                        "https://<dnato-host>/traz-comp-dnato/oauth/token",
  "jwks_uri":                              "https://<dnato-host>/traz-comp-dnato/oauth/.well-known/jwks.json",
  "response_types_supported":             ["code"],
  "grant_types_supported":                ["authorization_code"],
  "code_challenge_methods_supported":     ["S256"],
  "token_endpoint_auth_methods_supported": ["none"]
}
```

**Gap:** falta `registration_endpoint`. Sin él, Claude.ai no sabe dónde registrarse y no puede obtener un `client_id` para iniciar el flujo OAuth.

#### 3.3 RFC 7591 — Dynamic Client Registration (DCR)

**Sirve: Dnato** (es el Authorization Server).

La URL la anuncia el AS en su metadata bajo `registration_endpoint`.

**Estado actual:** no existe. Ni el endpoint en Dnato ni el campo en la AS metadata. ❌

---

### 4. Diagnóstico: por qué Claude.ai falla hoy

Trazado exacto desde los logs de APIM (2026-06-30 03:41:52):

```
APIM log (todos son "dispatched to main sequence. Invalid URL."):
  GET /.well-known/oauth-protected-resource/trazalog-equipos/1.0/mcp  → 404  ← paso 1 RFC 9728 path-based
  GET /.well-known/oauth-protected-resource                            → 404  ← paso 2 RFC 9728 host-based
  GET /.well-known/oauth-authorization-server                          → 404  ← paso 3 RFC 8414 en RS (fallback)
  POST /register                                                       → 404  ← paso 4 DCR en RS (fallback)
```

**Ninguna de estas URLs llegó a Dnato.** Claude.ai buscó el AS directamente en APIM porque no pudo conseguir el PRM (que lo hubiera redirigido a Dnato). Los pasos 3 y 4 son comportamiento de fallback de Claude.ai cuando los dos primeros fallan.

**Raíz del fallo:** el path-based PRM de RFC 9728 devuelve 404 en APIM. Sin PRM, Claude.ai no descubre que Dnato es el AS, y lo busca todo en el RS (APIM).

**Nota sobre `resource_metadata` en WWW-Authenticate:** el 401 que emite APIM incluye el header correcto con la URL del PRM. Claude.ai lee este header como *hint* pero su implementación de discovery activa la construcción path-based de RFC 9728 independientemente. El resultado observable es que intenta el path-based en APIM antes/en lugar de usar el hint del header.

---

### 5. Gap summary

| # | Gap | Componente | Acción necesaria |
|---|---|---|---|
| G1 | PRM no accesible en path RFC 9728 | APIM | Exponer `/.well-known/oauth-protected-resource/trazalog-equipos/1.0/mcp` |
| G2 | `registration_endpoint` ausente en AS metadata | Dnato | Agregar campo en `authorization_server_metadata()` |
| G3 | Endpoint DCR inexistente | Dnato | Implementar `POST /oauth/register` (RFC 7591) |
| G4 | `authorize()` y `token()` validan `client_id` hardcodeado | Dnato | Compatibilizar con client_id generado por DCR |

---

### 6. Plan de implementación

#### 6.1 APIM — exponer PRM en path RFC 9728

**Opción elegida:** desplegar una nueva API en APIM a través del Admin REST API con:

- Context: `/.well-known`
- Versión: `1.0` (sin versión en URL para que el path quede limpio)
- Resource: `GET /oauth-protected-resource/{path}` (captura el path de la API)
- Resource fallback: `GET /oauth-protected-resource`
- Auth: ninguna (endpoint público de discovery)
- Backend: inline Synapse response (no hay backend real; el JSON del PRM se genera en el mediator)

El contenido del PRM es estático en DEV (hardcodeado en el mediator con las URLs ngrok actuales). En TEST/PROD se parametriza con variables de entorno del APIM.

Alternativa más simple: crear un archivo de secuencia Synapse en `$APIM_HOME/repository/deployment/server/synapse-configs/default/sequences/` que capture las paths `/.well-known/*` antes de que lleguen al main sequence, y devuelva el JSON correspondiente.

**No requiere reiniciar APIM** si se usa hot-deploy de CAR o REST API del Publisher.

#### 6.2 Dnato — agregar `registration_endpoint` a AS metadata

En `Oauth.php`, método `authorization_server_metadata()`, agregar el campo:

```php
'registration_endpoint' => $base . '/oauth/register',
```

Un cambio de una línea.

#### 6.3 Dnato — implementar DCR (`POST /oauth/register`)

Nuevo método `register_client()` en `Oauth.php`. Estrategia: **fixed client_id**.

**Por qué fixed client_id (Fase 1):**
- `authorize()` y `token()` ya validan contra `ALLOWED_CLIENT_ID = 'trazalog-mcp-connector'`.
- DCR devuelve siempre ese mismo valor como `client_id`.
- Claude.ai lo usa en `authorize()` → el código existente lo acepta sin cambios.
- No requiere tabla en BD ni cambio en las validaciones existentes.
- Suficiente para el MVP con Claude.ai como único cliente. Se puede evolucionar a DCR dinámico en la fase de Connectors Directory cuando se soporte múltiples clientes.

Contrato del endpoint (RFC 7591 mínimo para clientes públicos con PKCE):

```
POST /traz-comp-dnato/oauth/register
Content-Type: application/json
Body: { "redirect_uris": ["..."], "token_endpoint_auth_method": "none", ... }

201 Created
Content-Type: application/json
{
  "client_id":                 "trazalog-mcp-connector",
  "client_secret_expires_at":  0,
  "redirect_uris":             [<los que mandó el cliente>],
  "grant_types":               ["authorization_code"],
  "response_types":            ["code"],
  "token_endpoint_auth_method": "none"
}
```

RFC 7591 §3.2 requiere `201 Created` (no `200`). El body refleja los `redirect_uris` del request (pass-through) porque Dnato no los valida en `/register` — los valida al momento del `authorize()`.

**Código PHP 5.6-safe:** ~25 líneas. Solo lectura del body JSON + respuesta JSON. Sin acceso a BD.

#### 6.4 Ruta en Dnato

Agregar en `application/config/routes.php`:

```php
$route['oauth/register'] = 'oauth/register_client';
```

#### 6.5 Lo que NO cambia

- `authorize()` — sin cambios (valida `ALLOWED_CLIENT_ID`, sigue igual)
- `token()` — sin cambios
- `jwks()` — sin cambios
- `authorization_server_metadata()` — solo se agrega `registration_endpoint`
- APIM gateway auth, JWT validation, `deployment.toml` — sin cambios
- Flujo completo JWT → APIM → DataService → MySQL — sin cambios

---

### 7. Flujo esperado post-implementación

```
1. Claude.ai → POST /trazalog-equipos/1.0/mcp
2. APIM → 401 WWW-Authenticate (resource_metadata hint)
3. Claude.ai → GET /.well-known/oauth-protected-resource/trazalog-equipos/1.0/mcp  [G1 resuelto]
4. APIM → 200 PRM { authorization_servers: ["https://dnato/.../oauth"] }
5. Claude.ai → GET https://dnato/.../oauth/.well-known/oauth-authorization-server  [ya funciona]
6. Dnato → 200 AS metadata { ..., registration_endpoint: "https://dnato/.../oauth/register" }  [G2 resuelto]
7. Claude.ai → POST https://dnato/.../oauth/register  [G3 resuelto]
8. Dnato → 201 { client_id: "trazalog-mcp-connector" }
9. Claude.ai → GET https://dnato/.../oauth/authorize?client_id=trazalog-mcp-connector&...  [G4: client_id ya válido]
10. Usuario hace login en Dnato → redirect con code
11. Claude.ai → POST https://dnato/.../oauth/token → JWT
12. Claude.ai → POST /trazalog-equipos/1.0/mcp Authorization: Bearer <JWT>
13. APIM valida JWT contra JWKS de Dnato → 200 MCP response
```

---

### 8. Consideraciones para TEST/PROD

- El PRM que APIM sirve en `/.well-known/oauth-protected-resource/...` debe tener las URLs del ambiente correcto (no ngrok). En TEST/PROD, `authorization_servers` apunta a la URL pública de Dnato.
- El `registration_endpoint` en AS metadata usa `DNATO_PUBLIC_URL` (ya gestionado con la variable de entorno existente).
- DCR con fixed `client_id` es válido para Fase 1. Cuando se implemente el Connectors Directory, evolucionar a DCR dinámico con tabla `oauth_clients` en BD (fuera del scope de esta fase).
- APIM en TEST/PROD usará HTTPS en el gateway (8243), no HTTP (8280). Las URLs del PRM deben usar HTTPS.

---

## Parte 2 — Dnato como Key Manager federado en el API Manager

> ⚠️ Sin verificar desde 2026-07-13: se juntó tal cual estaba; antes de seguirlo, contrastarlo con el código y con ADR-008/ADR-009.

**Tarea:** E9-IDENT-05 (reorientada por ADR-008)
**Decisión base:** [ADR-008](../v3/TRAZALOG_v3_MCP_ARCHITECTURE.md) — el APIM valida JWT de Dnato
como Key Manager federado.
**Prerequisito:** [dnato-jwt-prereqs.md](identidad-y-seguridad.md) — confirma que Dnato ya firma
con RS256, ya expone JWKS, y no requiere cambios de código para esta federación.

---

### 1. Contexto y objetivo

Un **Key Manager federado** le dice al APIM: "los tokens emitidos por este emisor (`iss`) son
válidos; verificá la firma contra este JWKS; aceptá este audience (`aud`)". Una vez configurado,
el APIM puede validar tokens de Dnato de la misma manera que valida los suyos propios, **sin
compartir secretos** y sin que el MI (Micro Integrator) tenga que hacer nada de validación.

El **Resident Key Manager** del APIM (el KM interno) sigue activo para las APIs legacy.
Ambos coexisten: las APIs MCP se asocian a **Dnato KM**, las legacy a **Resident KM**.
Ninguna configuración global ni flag en `deployment.toml` afectan la coexistencia.

#### Datos de Dnato a tener a mano antes de empezar

| Campo | Valor |
|---|---|
| Issuer (`iss`) | `trazalog-dnato` |
| Audience (`aud`) | `trazalog-mcp` |
| JWKS URL | `https://<dnato-host>/oauth/.well-known/jwks.json` |
| `kid` de la clave activa | `dnato-rs256-v1` |
| Algoritmo | RS256 |

> Reemplazar `<dnato-host>` con el hostname real en el entorno de destino (DEV/TEST/PROD).
> Verificar antes que el APIM resuelve el hostname y que el JWKS responde 200 (ver §2).

---

### 2. Verificar accesibilidad del JWKS desde el APIM

**Ejecutar desde el mismo host que corre el APIM** (no desde el browser):

```bash
curl -s https://<dnato-host>/oauth/.well-known/jwks.json | python3 -m json.tool
```

Respuesta esperada:
```json
{
  "keys": [
    {
      "kty": "RSA",
      "use": "sig",
      "alg": "RS256",
      "kid": "dnato-rs256-v1",
      "n": "<modulus base64url>",
      "e": "AQAB"
    }
  ]
}
```

Si el certificado TLS de Dnato es self-signed (entorno DEV), el APIM necesita confiar en él.
Hay dos opciones:

**Opción A — Importar el cert al truststore del APIM:**

```bash
# En el host del APIM
cd $APIM_HOME/repository/resources/security/
# Exportar cert de Dnato:
openssl s_client -connect <dnato-host>:443 -showcerts </dev/null 2>/dev/null \
  | openssl x509 -outform PEM > dnato-cert.pem

# Importar al truststore (client-truststore.jks)
keytool -import -alias dnato-dev \
        -file dnato-cert.pem \
        -keystore client-truststore.jks \
        -storepass wso2carbon -noprompt
# Reiniciar APIM para que tome el cert
```

**Opción B — Usar HTTP en red privada (solo DEV, NUNCA en TEST/PROD):**
Si APIM y Dnato están en la misma red interna y las comunicaciones están dentro del VPC/LAN,
se puede usar `http://` en la JWKS URL. No exponer el endpoint JWKS por HTTP públicamente.

---

### 3. Registrar Dnato como emisor JWT en `deployment.toml`

> **Nota de implementación:** APIM 4.6.0 incluye conectores para Auth0, Okta, Keycloak, Azure,
> ForgeRock, PingFederate y WSO2 IS, pero **no tiene un conector genérico para IdPs custom**.
> La Admin UI y la Admin REST API no permiten registrar un KM externo sin un conector instalado.
> El mecanismo correcto para IdPs custom que solo emiten JWTs es `[[apim.jwt.issuer]]` en
> `deployment.toml`. Este mecanismo registra el emisor en la capa de validación del gateway
> (XML `<TokenIssuers>`) y NO en la lista de Key Managers de la Admin UI — lo cual es
> correcto para el flujo ADR-008.

#### 3.1 Configuración en `deployment.toml`

Agregar al final de `$APIM_HOME/repository/conf/deployment.toml`:

```toml
[[apim.jwt.issuer]]
name = "trazalog-dnato"
consumer_key_claim = "azp"
scopes_claim = "scope"
jwks.url = "https://<dnato-host>/oauth/.well-known/jwks.json"

[[apim.jwt.issuer.claim_mapping]]
remote_claim = "empr_id"
local_claim = "empr_id"
```

| Campo TOML | Valor | Descripción |
|---|---|---|
| `name` | `trazalog-dnato` | Debe coincidir **exactamente** con el claim `iss` del JWT |
| `jwks.url` | URL del endpoint JWKS de Dnato | El gateway fetcha las claves para verificar la firma |
| `consumer_key_claim` | `azp` | Dnato no emite este claim en MVP — no bloqueante |
| `scopes_claim` | `scope` | Dnato no emite `scope` en MVP — no bloqueante |
| `claim_mapping` | `empr_id → empr_id` | Permite que el gateway propague el claim al backend |

> **DEV:** el endpoint JWKS de Dnato no responde en DEV (PHP 8.3 + DB prod). Usar un servidor
> JWKS minimal en puerto 8090:
> ```bash
> php -S localhost:8090 /tmp/jwks-server.php &
> ```
> El archivo `/tmp/jwks-server.php` sirve el JWKS con la clave pública `kid=dnato-rs256-v1`.
> En DEV, la `jwks.url` apunta a `http://localhost:8090/.well-known/jwks.json`.

#### 3.2 Reiniciar el APIM

```bash
$APIM_HOME/bin/api-manager.sh restart
```

#### 3.3 Verificar que la configuración se aplicó

```bash
grep -A 10 "TokenIssuers" $APIM_HOME/repository/conf/api-manager.xml
```

Resultado esperado:
```xml
<TokenIssuers>
  <TokenIssuer issuer ="trazalog-dnato">
    <JWKSConfiguration>
      <URL>http://localhost:8090/.well-known/jwks.json</URL>
    </JWKSConfiguration>
    <ConsumerKeyClaim>azp</ConsumerKeyClaim>
    <ScopesClaim>scope</ScopesClaim>
    <ClaimMappings disable-default-claim-mapping = "false">
      <ClaimMapping>
        <RemoteClaim>empr_id</RemoteClaim>
        <LocalClaim>empr_id</LocalClaim>
      </ClaimMapping>
    </ClaimMappings>
  </TokenIssuer>
</TokenIssuers>
```

#### 3.4 Comportamiento del gateway con `[[apim.jwt.issuer]]`

- El gateway valida **firma RS256** contra el JWKS y valida que `iss` = `trazalog-dnato`.
- Un JWT con firma inválida o `iss` desconocido → **HTTP 401** (Invalid Credentials).
- Un JWT válido de Dnato en una API con subscription validation habilitada → **HTTP 403**
  (Resource forbidden, código 900908). Ver §4.1.
- La **restricción por-API** (que solo las APIs MCP acepten tokens Dnato) se configura en
  el Publisher: asociar cada API MCP a este issuer (ver §5).
- Las APIs legacy con tokens opacos del Resident KM **no se ven afectadas**: el gateway
  valida el tipo de token antes de buscar el emisor JWT.

---

### 4. Decisiones de configuración importantes

#### 4.1 Subscription validation con `[[apim.jwt.issuer]]` — implementación real

Con `[[apim.jwt.issuer]]`, la APIM gateway valida firma + `iss` pero la subscription
validation sigue activa y requiere un `consumerKey` en el claim `azp` del JWT. Sin `azp`,
el gateway devuelve **HTTP 403** código 900908 "Resource forbidden" aunque la firma sea válida.

**No es posible deshabilitar subscription validation por-API** sin un Key Manager registrado
con `enableSubscriptionValidation = false`. El `[[apim.jwt.issuer]]` no tiene esa opción.

**Solución implementada (MVP DEV — 2026-06-15):**

1. Se creó una aplicación APIM "TrazalogDnatoMCP" en el DevPortal.
2. Se generaron OAuth2 keys → `consumerKey = z_CtMHRzWPSgY8aXWYxFuzsOli4a`.
3. La aplicación está suscrita a ambas APIs MCP (Equipos 1.0 y OTs 1.0).
4. Los JWTs de Dnato deben incluir `azp: "z_CtMHRzWPSgY8aXWYxFuzsOli4a"` para pasar la
   subscription validation en DEV.

> **JWT mínimo válido en DEV:**
> ```json
> {
>   "iss": "trazalog-dnato",
>   "aud": "trazalog-mcp",
>   "sub": "<email>",
>   "azp": "z_CtMHRzWPSgY8aXWYxFuzsOli4a",
>   "empr_id": <id>,
>   "exp": <timestamp>,
>   "iat": <timestamp>
> }
> ```

**Camino en TEST/PROD (Sprint monetización):**
1. Crear una aplicación APIM por ambiente (TEST, PROD).
2. Anotar el `consumerKey` generado en ese ambiente.
3. Configurar Dnato para incluir `azp: <consumerKey>` en los JWTs emitidos.
4. Suscribir la aplicación a las APIs MCP del ambiente.
5. (Opcional) Migrar a múltiples aplicaciones por tenant para rate-limiting por empresa.

#### 4.2 Coexistencia con el Resident Key Manager (APIs legacy)

Las APIs legacy con tokens opacos del Resident KM no se ven afectadas. El mecanismo
`[[apim.jwt.issuer]]` solo actúa cuando llega un JWT con `iss = trazalog-dnato`; los
tokens opacos tienen un formato diferente y siguen el flujo de introspección del Resident KM.

> El `deployment.toml` de DEV (`$APIM_HOME/repository/conf/deployment.toml`) tiene la
> configuración activa en la sección `[[apim.jwt.issuer]]`. En TEST/PROD, cambiar
> `jwks.url` a la URL real de Dnato antes del deploy.

---

### 5. Configurar las APIs MCP en el Publisher para Dnato

Una vez aplicada la configuración `[[apim.jwt.issuer]]` (§3) y reiniciado el APIM:

1. Ir a `https://localhost:9443/publisher`
2. Seleccionar la API (Equipos 1.0 o Ordenes de Trabajo 1.0)
3. **`Develop`** → **`API Configurations`** → **`Runtime`**
4. En **`Application Level Security`**:
   - Mantener `OAuth2` marcado
   - Desactivar "Subscription Validation" (evita el 403 por falta de `azp` — ver §4.1)
5. **`Save`** → **`Publish`**

> Con `[[apim.jwt.issuer]]`, el gateway ya acepta tokens Dnato para cualquier API que tenga
> OAuth2 habilitado. La restricción "solo APIs MCP aceptan tokens Dnato" se logra
> indirectamente: las APIs legacy esperan tokens opacos del Resident KM (que tienen formato
> diferente), no JWTs de Dnato.

Repetir para cada API MCP.

---

### 6. Verificar que la validación funciona

#### 6.1 Obtener un JWT real de Dnato

```bash
# En el host de Dnato:
JWT=$(php index.php cli issue_test_token <email> [empr_id])
echo $JWT
```

O usar el flujo OAuth completo (authorization code + PKCE) en un cliente de prueba.

#### 6.2 Casos de verificación

```bash
APIM="https://localhost:8243"
API="/equipos/1.0/mcp/equipos"

# ──────────────────────────────────────────────────────────
# Caso A: JWT válido de Dnato → 200
# ──────────────────────────────────────────────────────────
curl -k -H "Authorization: Bearer $JWT" $APIM$API
# Esperado: HTTP 200 + lista de equipos de la empresa del JWT

# ──────────────────────────────────────────────────────────
# Caso B: Sin token → el APIM devuelve 401 (no llega al MI)
# ──────────────────────────────────────────────────────────
curl -k $APIM$API
# Esperado: HTTP 401, mensaje del APIM (no del MI)
# Verificar en logs del MI: NO debe aparecer este request

# ──────────────────────────────────────────────────────────
# Caso C: Token con firma inválida → 401
# ──────────────────────────────────────────────────────────
INVALID_JWT="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJ0cmF6YWxvZy1kbmF0byIsImF1ZCI6InRyYXphbG9nLW1jcCIsImV4cCI6OTk5OTk5OTk5OSwiZW1wcl9pZCI6NDJ9.INVALIDSIGNATURE"
curl -k -H "Authorization: Bearer $INVALID_JWT" $APIM$API
# Esperado: HTTP 401

# ──────────────────────────────────────────────────────────
# Caso D: Token expirado → 401
# ──────────────────────────────────────────────────────────
# (generar con el script generate-test-jwts.sh — usa la clave privada de Dnato real
#  solo en DEV; ver tests/security/)
curl -k -H "Authorization: Bearer $EXPIRED_JWT" $APIM$API
# Esperado: HTTP 401

# ──────────────────────────────────────────────────────────
# Caso E: JWT válido pero con Resident KM token (token interno de APIM)
# → 401 en APIs MCP (porque el KM Dnato no acepta tokens del Resident KM)
# ──────────────────────────────────────────────────────────
# Esperado: HTTP 401 (o 403 según config)

# ──────────────────────────────────────────────────────────
# Caso F: Verificar que las APIs LEGACY siguen funcionando
# con tokens del Resident KM (OAuth nativo del APIM)
# ──────────────────────────────────────────────────────────
curl -k -H "Authorization: Bearer $RESIDENT_KM_TOKEN" <URL de API legacy>
# Esperado: HTTP 200 — las APIs legacy no se tocan
```

---

### 7. Configuración en deployment.toml

La configuración del emisor Dnato **sí requiere editar `deployment.toml`** (ver §3.1).
Este es el mecanismo oficial de APIM 4.6.0 para registrar emisores JWT custom sin plugin.

**Configuraciones que explícitamente NO se aplican:**

```toml
# ❌ NO APLICAR — ADR-008 lo prohíbe. Afecta TODAS las APIs del APIM globalmente.
# [apim.oauth_config]
# enable_outbound_auth_header = true
```

La sección `[[apim.jwt.issuer]]` (§3.1) es diferente y sí se aplica:
es por-issuer, no global, y no afecta el comportamiento de otras APIs.

---

### 8. Troubleshooting

| Síntoma | Causa probable | Verificación / Fix |
|---|---|---|
| 401 en todos los requests con JWT válido | JWKS no accesible desde el APIM | `curl -s https://<dnato-host>/.well-known/jwks.json` desde el host del APIM |
| 401 con "Issuer mismatch" | El campo Issuer del KM no coincide exactamente con el claim `iss` del JWT | Decodificar el JWT (jwt.io) y comparar con el campo Issuer del KM |
| 401 con "Audience mismatch" | El campo Audiences del KM no incluye `trazalog-mcp` | Agregar `trazalog-mcp` a la lista de audiences del KM |
| 401 por subscription validation | `Enable Subscription Validation` está ON y el JWT no tiene `azp` | Desactivar subscription validation en el KM (§3.4) |
| API legacy da 401 después del cambio | La API legacy tiene el KM Dnato seleccionado por error | En Publisher, verificar que la API legacy tenga SOLO Resident KM seleccionado |
| El KM Dnato no aparece en el Publisher | El KM no está en estado activo o no hay APIs en ese tenant | Verificar en Admin → Key Managers que `Dnato` está activo (toggle ON) |
| TLS error al validar JWKS | Cert self-signed de Dnato no está en el truststore del APIM | Importar el cert como en §2 Opción A |

---

### Referencias

- WSO2 docs — Key Manager overview: https://apim.docs.wso2.com/en/4.5.0/administer/key-managers/overview/
- WSO2 docs — Custom Key Manager: https://apim.docs.wso2.com/en/4.5.0/administer/key-managers/configure-custom-connector/
- [dnato-jwt-prereqs.md](identidad-y-seguridad.md) — Estado de Dnato y decisiones de iss/aud
- [empr-id-injection.md](identidad-y-seguridad.md) — Inyección de X-Empr-Id en la mediación del APIM
- [openapi-publish-procedure.md](../mcp/publicar-y-operar.md) — Publicación de APIs

---

## Parte 3 — Requisitos del JWT de Dnato

> ⚠️ Sin verificar desde 2026-07-13: se juntó tal cual estaba; antes de seguirlo, contrastarlo con el código y con ADR-008/ADR-009.

**Tarea:** E9-IDENT-05 (reorientada) / prerequisito de ADR-008
**Fecha:** 2026-06-10
**Repo investigado:** `traz-comp-dnato` — branch `develop-v3`
**Decisión base:** [ADR-008](../v3/TRAZALOG_v3_MCP_ARCHITECTURE.md) — el APIM valida el JWT de Dnato como Key Manager federado. El MI NO valida.

---

### 0. TL;DR

**Dnato YA está casi listo para federar con el APIM.** Firma JWT con **RS256**, expone un
endpoint **JWKS** estándar, e incluye todos los claims necesarios (`iss`, `aud`, `exp`, `iat`,
`empr_id`). No hay que implementar la emisión de tokens desde cero — ya existe.

Quedan **3 ajustes menores / decisiones** antes de configurar el Key Manager (ninguno es
bloqueante de código nuevo en Dnato, son decisiones de valores + verificación de red):

1. Decidir si `iss` se mantiene como string opaco (`trazalog-dnato`) o migra a URL.
2. Confirmar la estrategia de `aud` (`trazalog-mcp` actual vs. identificador del APIM).
3. Garantizar que el APIM resuelve por red el endpoint JWKS de Dnato (DNS/host + TLS).

---

### 1. Estado actual de Dnato (verificado en código)

| Pregunta | Respuesta | Evidencia en repo |
|---|---|---|
| ¿Dnato firma JWTs hoy? | **Sí.** Flujo OAuth 2.1 (authorization code + PKCE) completo + CLI de test. | `application/libraries/JwtIssuer.php`, `application/controllers/Oauth.php` |
| ¿Con qué algoritmo? | **RS256** (asimétrico, correcto para federación). | `application/config/jwt.php:33` (`jwt_algorithm = 'RS256'`) |
| ¿Existe endpoint JWKS? | **Sí, ya implementado.** | `GET /oauth/.well-known/jwks.json` → `Oauth::jwks()` (`routes.php:63`, `Oauth.php:205`) |
| ¿`iss` (issuer)? | `trazalog-dnato` (string opaco, **no** URL). | `jwt.php:34` |
| ¿`aud` (audience)? | `trazalog-mcp`. | `jwt.php:35` |
| ¿`kid`? | `dnato-rs256-v1` (presente en header JWT y en JWKS). | `jwt.php:39`, `Oauth.php:229` |
| ¿TTL del token? | 3600 s (1 h). | `jwt.php:36` |
| ¿Claim `empr_id`? | **Sí**, resuelto en login desde memberships de Bonita. | `JwtIssuer.php:53`, `Cli.php:58-90` |

#### 1.1 Claims que emite Dnato hoy

```json
{
  "iss":       "trazalog-dnato",
  "aud":       "trazalog-mcp",
  "iat":       1749571200,
  "exp":       1749574800,
  "sub":       "<usernick>",
  "email":     "<email>",
  "empr_id":   "42",
  "role":      "<role>",
  "userIdBpm": "<id Bonita>",
  "groupBpm":  "<empresa sin prefijo numérico>"
}
```

Header: `{ "alg": "RS256", "typ": "JWT", "kid": "dnato-rs256-v1" }`

> **Fix ADR-008 Sprint 2:** `empr_id` se emite ahora como **string** — `JwtIssuer.php:53`
> castea `(string) $empr_id` antes de construir el payload. El tipo es consistente en todo el
> flujo (JWT → header → DataService). Test: `JwtIssuerTest::testEmprIdIsString()`.

#### 1.2 Respuesta JWKS actual

`GET /oauth/.well-known/jwks.json` devuelve (`Oauth.php:225-237`):

```json
{
  "keys": [
    {
      "kty": "RSA",
      "use": "sig",
      "alg": "RS256",
      "kid": "dnato-rs256-v1",
      "n":   "<modulus base64url>",
      "e":   "AQAB"
    }
  ]
}
```

Formato **conforme a RFC 7517** — directamente consumible por el APIM como JWKS URL.

#### 1.3 Cómo obtener un JWT real para pruebas

Dnato ya provee un comando CLI (no expuesto por HTTP) que emite un JWT firmado real:

```bash
# En el host de Dnato:
php index.php cli issue_test_token <email> [empr_id]
# → imprime el JWT a stdout, listo para usar en curl/Hurl
```

(`application/controllers/Cli.php:29`). Esto reemplaza la necesidad de los JWT estáticos
auto-firmados de `generate-test-jwts.sh` una vez que el APIM valida contra el JWKS real.

---

### 2. Gap analysis para federación con APIM

| # | Requisito ADR-008 | Estado | Acción |
|---|---|---|---|
| 1 | Firmar con algoritmo asimétrico (RS256) | ✅ Cumple | Ninguna |
| 2 | Exponer JWKS endpoint | ✅ Cumple | Ninguna (solo verificar accesibilidad de red, ver §3) |
| 3 | Claims `iss`, `aud`, `exp`, `iat` | ✅ Cumple | Ninguna |
| 4 | Claim custom `empr_id` como string | ✅ Cumple (fix Sprint 2) | `(string) $empr_id` en `JwtIssuer.php` — aplicado |
| 5 | `iss` = URL de Dnato (recomendación ADR) | ⚠️ Es string opaco | **Decisión** — ver §2.1 |
| 6 | `aud` = identificador del APIM (recomendación ADR) | ⚠️ Es `trazalog-mcp` | **Decisión** — ver §2.2 |
| 7 | Claim de consumer key (`azp`/`consumerKey`) para validación de suscripción | ❌ No presente | **Diferir** — ver §2.3 |

#### 2.1 Decisión: `iss` string opaco vs URL

El ADR-008 recomienda `iss = URL base de Dnato`. Hoy es `trazalog-dnato` (string opaco).

- **WSO2 NO exige que `iss` sea una URL.** En la config del Key Manager externo, el "Issuer"
  es un string que debe coincidir exactamente con el claim `iss` del token. `trazalog-dnato`
  funciona siempre que se configure idéntico en el APIM.
- **Recomendación:** mantener `trazalog-dnato` para el MVP (cambiar el issuer obliga a re-emitir
  todos los tokens y a sincronizar con el validador). Migrar a URL (`https://<dnato-host>`) solo
  si una integración futura lo exige. **No bloquea ADR-008.**

#### 2.2 Decisión: valor de `aud`

El ADR recomienda `aud = identificador del APIM`. Hoy es `trazalog-mcp`.

- WSO2 permite configurar los "audiences" permitidos en el Key Manager. `trazalog-mcp` es un
  audience lógico válido para todo el tráfico MCP.
- **Recomendación:** mantener `trazalog-mcp` como audience del tráfico MCP. Es semánticamente
  claro y no obliga a acoplar el token a un identificador interno del APIM. Documentar este
  valor en la config del Key Manager (ver [apim-keymanager-dnato.md](identidad-y-seguridad.md)).
  **No bloquea ADR-008.**

#### 2.3 Validación de suscripción (`azp`/`consumerKey`) — DIFERIR a monetización

**Hallazgo importante de la doc WSO2:** por defecto, el APIM **NO valida suscripción** cuando
el JWT viene de un IdP externo. Para activar validación de suscripción (necesaria para tiers,
rate limiting por aplicación y monetización), el JWT debe incluir el **consumer key** de una
OAuth app registrada en el APIM (claim `azp` o `consumerKey`), mapeada vía "Provisioning
Out-of-Band OAuth2 Clients".

- El JWT de Dnato **no incluye** `azp`/`consumerKey` hoy.
- **Para el MVP (ADR-008):** configurar el Key Manager con **validación de suscripción
  DESACTIVADA**. El APIM valida firma + `iss` + `aud` + `exp` y rutea. Esto es suficiente para
  el aislamiento multi-tenant (que depende de `empr_id`, no de la suscripción).
- **Diferido:** cuando se implemente la monetización (Sección 5 del doc de arquitectura),
  Dnato deberá agregar el claim de consumer key y registrarse la app out-of-band. Tarea de
  Sprint posterior, NO bloqueante del MVP.

> Referencia: [JWT Access Tokens — WSO2](https://apim.docs.wso2.com/en/latest/design/api-security/oauth2/access-token-types/jwt-tokens/)

---

### 3. Accesibilidad de red del JWKS (única verificación operativa pendiente)

El APIM debe poder hacer `GET` al JWKS de Dnato **desde el host del APIM** (no desde el browser):

```bash
# Ejecutar desde el host/red del APIM:
curl -s https://<dnato-host>/oauth/.well-known/jwks.json | jq .
```

Checklist:
- [ ] El host de Dnato es resoluble desde el APIM (DNS o `/etc/hosts`).
- [ ] El APIM confía en el certificado TLS de Dnato (importar el cert al truststore del APIM si
      es self-signed; en DEV se puede usar HTTP interno si ambos están en la misma red privada).
- [ ] El endpoint responde 200 con `Content-Type: application/json` y un `keys[]` no vacío.

---

### 4. Lista de cambios necesarios en Dnato

**Para el MVP / ADR-008: NINGÚN cambio de código bloqueante.** Dnato está listo.

Tareas opcionales / de seguimiento (no bloquean la demo):

| Tarea | Tipo | Prioridad | Cuándo |
|---|---|---|---|
| Fijar `empr_id` como string en el payload (consistencia) | Código menor | — | **Aplicada en Sprint 2** (junio 2026) |
| Verificar accesibilidad de red del JWKS desde el APIM | Operativo | **Alta** | Antes de configurar el KM |
| Migrar `iss` a URL | Decisión + código | Baja | Solo si lo exige una integración futura |
| Agregar claim `azp`/`consumerKey` para validación de suscripción | Código | Media | Diferido a fase de monetización |

---

### 5. Conclusión

ADR-008 **no está bloqueado por Dnato**. El riesgo registrado en la Sección 12 del doc de
arquitectura ("Dnato debe exponer JWKS + firmar con RS256 antes de avanzar") **ya está
mitigado**: ambas cosas existen. El trabajo restante para Sprint 2 se concentra en el **lado
APIM** (configurar el Key Manager federado + mediación de inyección de `empr_id`), no en Dnato.

Próximos documentos:
- [apim-keymanager-dnato.md](identidad-y-seguridad.md) — configuración del Key Manager.
- [empr-id-injection.md](identidad-y-seguridad.md) — inyección de `X-Empr-Id` en el APIM.
- [../api/openapi-publish-procedure.md](../mcp/publicar-y-operar.md) — publicación de las APIs.

---

## Parte 4 — Clave pública RS256 de Dnato

> ⚠️ Sin verificar desde 2026-05-30: se juntó tal cual estaba; antes de seguirlo, contrastarlo con el código y con ADR-008/ADR-009.

**Tarea:** E9-IDENT-03  
**Fecha:** 2026-05

---

### Contexto

Dnato es el Identity Provider del ecosistema Trazalog v3. Emite JWTs firmados con RS256
(private key de Dnato) que WSO2 MI valida usando la clave pública correspondiente.
La clave privada **nunca** sale de Dnato. WSO2 MI solo necesita la clave pública.

---

### 1. Obtener la clave pública de Dnato

#### Opción A — Endpoint JWKS (recomendado para Sprint 3+)

Dnato expone un endpoint JWKS (JSON Web Key Set) estándar:

```
GET https://<dnato-host>/.well-known/jwks.json
```

Respuesta esperada:
```json
{
  "keys": [
    {
      "kty": "RSA",
      "kid": "dnato-prod-2026-01",
      "use": "sig",
      "alg": "RS256",
      "n": "<modulus-base64url>",
      "e": "AQAB"
    }
  ]
}
```

Para extraer el PEM desde el JWKS:
```bash
# Instalar jwks-to-pem si es necesario
npm install -g jwks-to-pem

# Exportar clave
curl -s https://<dnato-host>/.well-known/jwks.json | \
  python3 -c "
import json, sys
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPublicNumbers
import base64

jwks = json.load(sys.stdin)
key = jwks['keys'][0]

def b64url_decode(s):
    s += '=' * (-len(s) % 4)
    return base64.urlsafe_b64decode(s)

n = int.from_bytes(b64url_decode(key['n']), 'big')
e = int.from_bytes(b64url_decode(key['e']), 'big')

pub = RSAPublicNumbers(e, n).public_key()
pem = pub.public_key().public_bytes(
    serialization.Encoding.PEM,
    serialization.PublicFormat.SubjectPublicKeyInfo
)
sys.stdout.write(pem.decode())
"
```

#### Opción B — PEM estático (MVP actual)

El equipo de Dnato entrega el archivo PEM por canal seguro (no email).
Formato esperado:

```
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA... (línea ~60 chars)
...
-----END PUBLIC KEY-----
```

---

### 2. Cargar la clave en WSO2 MI (opción B — estático)

#### 2.1 Vía Maven / CAR deploy (recomendado en CI/CD)

1. Reemplazar el placeholder en el repo:

```
_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/resources/registry/conf/dnato-public-key.pem
```

2. Build y deploy del CAR:

```bash
cd _backend/api/ToolsAPIProject/ToolsAPIProject
./mvnw clean install
# Copiar .car a $WSO2MI_HOME/repository/deployment/server/carbonapps/
```

El CAR despliega la clave en el registry de WSO2 MI en:
```
/_system/config/identity/dnato-public-key.pem
```

#### 2.2 Vía consola WSO2 (manual para emergencias)

1. Admin console → Registry → Browse → `/_system/config/identity/`
2. Crear recurso → tipo `text/plain` → nombre `dnato-public-key.pem`
3. Pegar el contenido del PEM (con headers `-----BEGIN/END PUBLIC KEY-----`)
4. Guardar

---

### 3. Verificar la clave cargada

En WSO2 MI con la propiedad de registry en una API de test:

```xml
<property name="test_key"
          expression="get-property('registry','conf:identity/dnato-public-key.pem')"
          scope="default" type="STRING"/>
<log level="custom">
    <property name="key_loaded" expression="get-property('test_key')"/>
</log>
```

La clave debe aparecer completa en los logs de WSO2 MI.

---

### 4. Rotación de claves (procedimiento manual — MVP)

1. Dnato genera nuevo par de claves RS256
2. Dnato comparte la nueva clave pública por canal seguro
3. Actualizar el archivo PEM en el repo (commit en `develop-v3`)
4. Build y deploy del CAR actualizado a staging, validar tests Hurl
5. Deploy a producción en ventana de mantenimiento
6. Verificar que tokens emitidos con la clave nueva funcionan
7. Dnato deja de emitir tokens con la clave vieja

**Sprint 3+:** Migrar a validación JWKS dinámica (opción A) para rotación sin deploy.

---

### 5. Seguridad

- La clave pública **puede** estar en git — no es un secreto
- La clave privada **nunca** debe tocar este repo ni WSO2 MI
- El archivo PEM en el registry de WSO2 es solo de lectura para el Gateway
- En producción, restringir el acceso al registry a admin únicamente

---

## Parte 5 — Validación del permiso en el gateway

> ⚠️ Sin verificar desde 2026-07-13: se juntó tal cual estaba; antes de seguirlo, contrastarlo con el código y con ADR-008/ADR-009.

> **⚠️ FLUJO REEMPLAZADO por ADR-008 (Mayo 2026)**
> Este documento describía la validación JWT en el MI vía `JwtValidator.xml` (patrón passthrough).
> Ese patrón fue descartado. El flujo vigente delega la validación al **APIM Gateway** (Key Manager
> Dnato federado). Ver:
> - [empr-id-injection.md](identidad-y-seguridad.md) — flujo nuevo completo
> - [apim-keymanager-dnato.md](identidad-y-seguridad.md) — configuración del Key Manager
> - [dnato-jwt-prereqs.md](identidad-y-seguridad.md) — estado de Dnato (RS256 + JWKS ya activos)
>
> Se mantiene como **referencia histórica** del diseño original.

**Decisión base:** Sección 6.8 MCP Architecture Doc — Dnato emite JWTs, WSO2 los valida (ADR P01)
**Fecha:** 2026-05
**Estado:** ~~MVP implementado~~ **REEMPLAZADO — ver ADR-008**

---

### 1. Flujo de validación

```
Cliente MCP (agente IA / Claude)
    │
    │  POST /tools/mcp/<recurso>
    │  Authorization: Bearer <JWT firmado por Dnato>
    ▼
WSO2 MI Gateway (port 8280)
    │
    ├─► [jwtValidator sequence]
    │       ├── Extrae Bearer token del header Authorization
    │       ├── Valida formato JWT (3 partes base64url)
    │       ├── Verifica alg == RS256
    │       ├── Verifica exp > ahora (no expirado)
    │       ├── Verifica iss == "trazalog-dnato"
    │       ├── Verifica aud == "trazalog-mcp"
    │       ├── Verifica claim empr_id presente
    │       └── Verifica firma RS256 con clave pública de Dnato
    │                        │
    │              ┌──────────┴──────────┐
    │              │ FALLO               │ OK
    │              ▼                     ▼
    │         401 Unauthorized    Guarda empr_id
    │         (respond + stop)    en context
    │                             │
    ├─► [emprIdInjector sequence]
    │       └── Agrega header X-Empr-Id: <empr_id>
    │
    ▼
DataService / Backend downstream
    │  Recibe X-Empr-Id: 42
    └── SELECT ... WHERE empr_id = :empr_id  ← filtrado garantizado por empr_id
```

---

### 2. Artefactos implementados

| Artefacto | Path en repo | Propósito |
|-----------|-------------|-----------|
| `JwtValidator.xml` | `_backend/api/.../sequences/` | Valida firma RS256, claims, empr_id |
| `EmprIdInjector.xml` | `_backend/api/.../sequences/` | Inyecta X-Empr-Id en la llamada downstream |
| `dnato-public-key.pem` | `resources/registry/conf/` | Clave pública RS256 de Dnato (en registry) |

#### Uso en un API MCP (inSequence)

```xml
<resource methods="GET POST" uri-template="/solicitudes">
    <inSequence>
        <!-- Validar JWT y extraer empr_id (aborta con 401 si falla) -->
        <sequence key="jwtValidator"/>

        <!-- Inyectar empr_id como header para el DataService -->
        <sequence key="emprIdInjector"/>

        <!-- Lógica del endpoint MCP -->
        <!-- ... -->
    </inSequence>
</resource>
```

**Importante:** `jwtValidator` debe ir SIEMPRE antes de `emprIdInjector`.
`emprIdInjector` depende del property `jwt_empr_id` que sólo existe si `jwtValidator` pasó.

---

### 3. Configuración de la clave pública (paso a paso — PROD)

#### 3.1 Obtener la clave de Dnato

Ver procedimiento completo en [`jwt-keys-setup.md`](identidad-y-seguridad.md).

Resumen para PROD:
1. Solicitar el PEM al equipo Dnato por canal seguro (no email)
2. Verificar fingerprint SHA256 con Dnato antes de usarla

#### 3.2 Cargar en el registry de WSO2 MI

**Vía Maven/CAR (recomendado):**

```bash
# 1. Reemplazar placeholder en el repo
cat /path/to/dnato-public-key.pem > \
    _backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/resources/registry/conf/dnato-public-key.pem

# 2. Build del CAR
cd _backend/api/ToolsAPIProject/ToolsAPIProject
./mvnw clean install

# 3. Deploy
cp target/ToolsAPIProject_1.0.0.car \
   $WSO2MI_HOME/repository/deployment/server/carbonapps/
```

El plugin Maven registra el PEM en: `/_system/config/identity/dnato-public-key.pem`

**Vía consola (emergencia):**

```
https://localhost:9443/carbon → Registry → Browse
/_system/config/identity/ → Add Resource
Nombre: dnato-public-key.pem
Media Type: text/plain
Content: [pegar contenido del PEM]
```

#### 3.3 Verificar que la clave está cargada

Revisar logs de WSO2 MI después del primer request con JWT válido.
La secuencia `jwtValidator` no loguea la clave (solo errores), pero el script de diagnóstico
en `jwt-keys-setup.md §3` puede usarse para confirmar.

---

### 4. Asociar las sequences a una API MCP nueva

Cada vez que se crea una API MCP que deba validar JWT:

1. Abrir el XML del nuevo endpoint en:
   ```
   _backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/apis/<NombreAPI>.xml
   ```

2. En cada `<resource>` MCP del API, agregar al inicio de `<inSequence>`:
   ```xml
   <sequence key="jwtValidator"/>
   <sequence key="emprIdInjector"/>
   ```

3. Las APIs no-MCP (v2, internal) NO deben incluir estas sequences.
   El filtrado de tráfico se hace a nivel de qué APIs incluyen las sequences, no a nivel global.

4. Rebuild + redeploy del CAR.

---

### 5. Casos de error y mensajes esperados

| Escenario | HTTP | Mensaje en `$.message` |
|-----------|------|------------------------|
| Sin header Authorization | 401 | `Missing Authorization header` |
| No usa esquema Bearer | 401 | `Authorization header must use Bearer scheme` |
| JWT malformado (≠ 3 partes) | 401 | `Malformed JWT: expected 3 parts...` |
| Algoritmo ≠ RS256 | 401 | `Unsupported algorithm: expected RS256, got <alg>` |
| Token expirado | 401 | `JWT has expired` |
| Issuer incorrecto | 401 | `Invalid issuer: expected trazalog-dnato` |
| Audience incorrecta | 401 | `Invalid audience: expected trazalog-mcp` |
| Falta claim empr_id | 401 | `Missing required claim: empr_id` |
| Firma inválida | 401 | `JWT signature verification failed` |
| Clave pública no configurada | 401 | `Public key not configured in registry...` |
| Token válido | 2xx | Respuesta normal del backend |

---

### 6. Aislamiento multi-empresa (garantía end-to-end)

El gateway **no filtra datos** — solo garantiza que el empr_id correcto llega al backend.
El aislamiento lo implementa el DataService:

```sql
-- Los DataServices usan el parámetro :empr_id inyectado por EmprIdInjector
SELECT * FROM solicitudes
WHERE empr_id = :empr_id        -- parámetro viene del header X-Empr-Id
  AND estado = :estado
```

El header `X-Empr-Id` es de transporte interno (no lo envía el cliente).
WSO2 MI lo sobreescribe en cada request después de validar el JWT.
El cliente no puede falsificarlo porque el gateway ignora cualquier `X-Empr-Id` que
venga en el request original.

---

### 7. Procedimiento de rotación de claves (MVP — manual)

1. Dnato genera nuevo par de claves RS256
2. Dnato comunica por canal seguro:
   - La nueva clave pública (PEM)
   - El `kid` del nuevo key (para tracking)
3. Actualizar `dnato-public-key.pem` en el repo
4. Commit + PR a `develop-v3`
5. Deploy a staging → ejecutar `tests/security/jwt-validation.hurl` con nueva clave
6. Si los 7 casos pasan → deploy a producción en ventana de mantenimiento
7. Confirmar con Dnato que la clave vieja ya no emite tokens
8. Ventana de migración: si se necesita soporte dual de claves, ver Sprint 3+

**Sprint 3+ (sin deploy):** Migrar `JwtValidator.xml` a validación JWKS dinámica.
La clave se fetcha del endpoint Dnato en cada request (con caché).
Cambio de clave en Dnato se propaga automáticamente cuando caduca el caché.

---

### 8. Claims del JWT de Dnato (formato esperado)

```json
{
  "alg": "RS256",
  "typ": "JWT"
}
.
{
  "iss": "trazalog-dnato",
  "aud": "trazalog-mcp",
  "sub": "<user-id>",
  "empr_id": "42",
  "exp": 1748800000,
  "iat": 1748796400
}
```

`empr_id` es string (aunque el valor sea numérico) para consistencia con los DataServices.

---

### 9. Ejecutar tests de seguridad

```bash
# 1. Generar claves y JWTs de prueba
cd tests/security
./generate-test-jwts.sh
# → crea test-dnato-public.pem y test-env.vars

# 2. Cargar test-dnato-public.pem en WSO2 registry
# (mismos pasos que sección 3.2, pero con la clave de test)

# 3. Correr los 7 casos
hurl --variables-file test-env.vars \
     --variable MI_HOST=localhost:8280 \
     --variable MCP_RESOURCE=/tools/mcp/solicitudes \
     --variable MCP_ECHO_RESOURCE=/tools/mcp/echo \
     --variable MCP_DATA_RESOURCE=/tools/mcp/solicitudes \
     jwt-validation.hurl
```

Los 7 casos deben pasar antes de cualquier release que involucre autenticación MCP.

---

## Parte 6 — Inyección del empr_id desde el API Manager

> ⚠️ Sin verificar desde 2026-07-13: se juntó tal cual estaba; antes de seguirlo, contrastarlo con el código y con ADR-008/ADR-009.

**Tarea:** E9-IDENT-05 (reorientada)
**Decisión base:** [ADR-008](../v3/TRAZALOG_v3_MCP_ARCHITECTURE.md) — el APIM extrae `empr_id`
del JWT validado y lo inyecta como `X-Empr-Id`; el MI lo lee del header (no del JWT).
**Artefactos:** `doc/identity/apim-empr-id-injector-policy.xml` (in-sequence del APIM) y
`_backend/.../sequences/EmprIdFromHeader.xml` (sequence del MI).

---

### 1. Diagrama del flujo nuevo

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

### 2. Artefacto del APIM: in-sequence EmprIdInjectorPolicy

Este artefacto se aplica como **in-sequence** (mediation policy) a todas las APIs MCP en el
Publisher. Puede aplicarse como:
- **Policy global** (aplica a todos los recursos de la API automáticamente)
- **Per-resource** (aplica a cada resource/verb individualmente)

Para el MVP se recomienda la configuración **por API** (política aplicada a toda la API), ya que
todas las operaciones MCP requieren el `empr_id`.

#### Archivo: `doc/identity/apim-empr-id-injector-policy.xml`

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

#### Cómo asociar esta policy en el Publisher

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

### 3. Artefacto del MI: EmprIdFromHeader.xml

Esta sequence **reemplaza** la combinación `jwtValidator + emprIdInjector` en los resources MCP
del `toolsMANAPI.xml`. Lee el `X-Empr-Id` inyectado por el APIM y lo convierte en la property
de contexto `jwt_empr_id`, que todo el código downstream ya usa.

**La lógica downstream del MI NO cambia** — los resource sequences siguen leyendo
`get-property('jwt_empr_id')` para construir las URLs de los DataServices.

#### Archivo: `_backend/api/ToolsAPIProject/.../sequences/EmprIdFromHeader.xml`

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

#### Cambios en toolsMANAPI.xml

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

### 4. Tipo del claim empr_id

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

### 5. Seguridad del header X-Empr-Id

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

### 6. Comportamiento ante falla de mediación APIM

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

### 7. Cómo testear el flujo completo

#### 7.1 Test de inyección (verificar que X-Empr-Id llega al MI)

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

#### 7.2 Test de aislamiento (empresa A no ve datos de empresa B)

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

#### 7.3 Test de seguridad (token inválido no llega al MI)

```bash
# Sin token → 401 del APIM, el MI no registra ningún log para este request
curl -k https://localhost:8243/equipos/1.0/mcp/equipos

# Token con firma inválida → 401 del APIM
curl -k -H "Authorization: Bearer eyJhbGciOiJSUzI1NiJ9.eyJlbXByX2lkIjo5OX0.INVALIDSIG" \
     https://localhost:8243/equipos/1.0/mcp/equipos
```

Confirmar en los logs del MI que estos requests **no generan ninguna entrada de log**
(el APIM los rechaza antes de que lleguen al MI).

#### 7.4 Test anti-spoofing (Fix 1 — defensa en profundidad)

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

#### 7.5 Test de fallback 503 (Fix 3 — MI sin header)

```bash
# Llamar al MI directamente sin X-Empr-Id → 503 identity_header_missing
curl http://localhost:8280/tools/man/mcp/equipos
# Esperado: HTTP 503, body {"error":"identity_header_missing",...}
```

Test automatizado: `tests/security/mi-fallback.hurl`.

---

### 8. Relación con los tests Hurl existentes

Los tests en `tests/security/jwt-validation.hurl` apuntaban al MI directamente (`:8280`). Con
ADR-008 los tests de **validación del token** deben apuntar al **APIM** (`:8243`), ya que es el
APIM quien rechaza los tokens inválidos. Ver `tests/security/jwt-validation.hurl` —
la variable `MI_HOST` se reemplaza por `APIM_HOST` (`:8243`). Los casos c, d, e (firma inválida,
expirado, sin empr_id) ahora son rechazados por el APIM, no por el MI.

Los tests en `tests/security/dataservice-isolation.hurl` apuntan a los DataServices
directamente y no pasan por auth — siguen siendo válidos tal cual.

## De dónde salió este documento

Fusionado el 2026-11-26 (unificación de documentación, `DOC-UNIF-3`) a partir de:

- `doc/identidad/identidad-y-seguridad.md`
- `doc/identidad/identidad-y-seguridad.md`
- `doc/identidad/identidad-y-seguridad.md`
- `doc/identidad/identidad-y-seguridad.md`
- `doc/identidad/identidad-y-seguridad.md`
- `doc/identidad/identidad-y-seguridad.md`

El texto se juntó sin reescribirlo; solo se bajaron niveles de título y se ajustaron enlaces. La historia de cada parte está en `git log --follow` de los archivos originales.
