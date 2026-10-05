# OAuth Discovery Flow — Mapeo de responsabilidades APIM / Dnato

**Contexto:** E2-MCP-EQUIPOS-OTS — integración Claude.ai como cliente MCP  
**Fecha:** 2026-06-30  
**Prerrequisitos:** [dnato-jwt-prereqs.md](dnato-jwt-prereqs.md) · [apim-keymanager-dnato.md](apim-keymanager-dnato.md)  
**Arquitectura de referencia:** TAD-IDENT-04 (Dnato es el AS) · TAD-IDENT-P01 (Dnato con OAuth 2.1 + PKCE)

---

## 1. Roles en la arquitectura OAuth 2.1 + MCP

| Componente | Rol OAuth 2.1 | Qué publica |
|---|---|---|
| **WSO2 APIM 4.6.0** | Resource Server (RS) | Protected Resource Metadata (RFC 9728) |
| **Dnato (traz-comp-dnato)** | Authorization Server (AS) | AS Metadata (RFC 8414) + Dynamic Client Registration (RFC 7591) |
| **Claude.ai** | Client | Inicia el flujo OAuth 2.1 PKCE; descubre los endpoints automáticamente |

Esta separación es inviolable per TAD-IDENT-04: el usuario se autentica contra Trazalog/Dnato, no contra WSO2.

---

## 2. Cadena de discovery completa (RFC 9728 → RFC 8414 → RFC 7591)

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

## 3. Mapeo de endpoints por RFC

### 3.1 RFC 9728 — Protected Resource Metadata (PRM)

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

### 3.2 RFC 8414 — Authorization Server Metadata

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

### 3.3 RFC 7591 — Dynamic Client Registration (DCR)

**Sirve: Dnato** (es el Authorization Server).

La URL la anuncia el AS en su metadata bajo `registration_endpoint`.

**Estado actual:** no existe. Ni el endpoint en Dnato ni el campo en la AS metadata. ❌

---

## 4. Diagnóstico: por qué Claude.ai falla hoy

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

## 5. Gap summary

| # | Gap | Componente | Acción necesaria |
|---|---|---|---|
| G1 | PRM no accesible en path RFC 9728 | APIM | Exponer `/.well-known/oauth-protected-resource/trazalog-equipos/1.0/mcp` |
| G2 | `registration_endpoint` ausente en AS metadata | Dnato | Agregar campo en `authorization_server_metadata()` |
| G3 | Endpoint DCR inexistente | Dnato | Implementar `POST /oauth/register` (RFC 7591) |
| G4 | `authorize()` y `token()` validan `client_id` hardcodeado | Dnato | Compatibilizar con client_id generado por DCR |

---

## 6. Plan de implementación

### 6.1 APIM — exponer PRM en path RFC 9728

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

### 6.2 Dnato — agregar `registration_endpoint` a AS metadata

En `Oauth.php`, método `authorization_server_metadata()`, agregar el campo:

```php
'registration_endpoint' => $base . '/oauth/register',
```

Un cambio de una línea.

### 6.3 Dnato — implementar DCR (`POST /oauth/register`)

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

### 6.4 Ruta en Dnato

Agregar en `application/config/routes.php`:

```php
$route['oauth/register'] = 'oauth/register_client';
```

### 6.5 Lo que NO cambia

- `authorize()` — sin cambios (valida `ALLOWED_CLIENT_ID`, sigue igual)
- `token()` — sin cambios
- `jwks()` — sin cambios
- `authorization_server_metadata()` — solo se agrega `registration_endpoint`
- APIM gateway auth, JWT validation, `deployment.toml` — sin cambios
- Flujo completo JWT → APIM → DataService → MySQL — sin cambios

---

## 7. Flujo esperado post-implementación

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

## 8. Consideraciones para TEST/PROD

- El PRM que APIM sirve en `/.well-known/oauth-protected-resource/...` debe tener las URLs del ambiente correcto (no ngrok). En TEST/PROD, `authorization_servers` apunta a la URL pública de Dnato.
- El `registration_endpoint` en AS metadata usa `DNATO_PUBLIC_URL` (ya gestionado con la variable de entorno existente).
- DCR con fixed `client_id` es válido para Fase 1. Cuando se implemente el Connectors Directory, evolucionar a DCR dinámico con tabla `oauth_clients` en BD (fuera del scope de esta fase).
- APIM en TEST/PROD usará HTTPS en el gateway (8243), no HTTP (8280). Las URLs del PRM deben usar HTTPS.
