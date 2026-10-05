# Prerequisitos JWT de Dnato para federación con APIM (ADR-008)

**Tarea:** E9-IDENT-05 (reorientada) / prerequisito de ADR-008
**Fecha:** 2026-06-10
**Repo investigado:** `traz-comp-dnato` — branch `develop-v3`
**Decisión base:** [ADR-008](../v3/TRAZALOG_v3_MCP_ARCHITECTURE.md) — el APIM valida el JWT de Dnato como Key Manager federado. El MI NO valida.

---

## 0. TL;DR

**Dnato YA está casi listo para federar con el APIM.** Firma JWT con **RS256**, expone un
endpoint **JWKS** estándar, e incluye todos los claims necesarios (`iss`, `aud`, `exp`, `iat`,
`empr_id`). No hay que implementar la emisión de tokens desde cero — ya existe.

Quedan **3 ajustes menores / decisiones** antes de configurar el Key Manager (ninguno es
bloqueante de código nuevo en Dnato, son decisiones de valores + verificación de red):

1. Decidir si `iss` se mantiene como string opaco (`trazalog-dnato`) o migra a URL.
2. Confirmar la estrategia de `aud` (`trazalog-mcp` actual vs. identificador del APIM).
3. Garantizar que el APIM resuelve por red el endpoint JWKS de Dnato (DNS/host + TLS).

---

## 1. Estado actual de Dnato (verificado en código)

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

### 1.1 Claims que emite Dnato hoy

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

### 1.2 Respuesta JWKS actual

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

### 1.3 Cómo obtener un JWT real para pruebas

Dnato ya provee un comando CLI (no expuesto por HTTP) que emite un JWT firmado real:

```bash
# En el host de Dnato:
php index.php cli issue_test_token <email> [empr_id]
# → imprime el JWT a stdout, listo para usar en curl/Hurl
```

(`application/controllers/Cli.php:29`). Esto reemplaza la necesidad de los JWT estáticos
auto-firmados de `generate-test-jwts.sh` una vez que el APIM valida contra el JWKS real.

---

## 2. Gap analysis para federación con APIM

| # | Requisito ADR-008 | Estado | Acción |
|---|---|---|---|
| 1 | Firmar con algoritmo asimétrico (RS256) | ✅ Cumple | Ninguna |
| 2 | Exponer JWKS endpoint | ✅ Cumple | Ninguna (solo verificar accesibilidad de red, ver §3) |
| 3 | Claims `iss`, `aud`, `exp`, `iat` | ✅ Cumple | Ninguna |
| 4 | Claim custom `empr_id` como string | ✅ Cumple (fix Sprint 2) | `(string) $empr_id` en `JwtIssuer.php` — aplicado |
| 5 | `iss` = URL de Dnato (recomendación ADR) | ⚠️ Es string opaco | **Decisión** — ver §2.1 |
| 6 | `aud` = identificador del APIM (recomendación ADR) | ⚠️ Es `trazalog-mcp` | **Decisión** — ver §2.2 |
| 7 | Claim de consumer key (`azp`/`consumerKey`) para validación de suscripción | ❌ No presente | **Diferir** — ver §2.3 |

### 2.1 Decisión: `iss` string opaco vs URL

El ADR-008 recomienda `iss = URL base de Dnato`. Hoy es `trazalog-dnato` (string opaco).

- **WSO2 NO exige que `iss` sea una URL.** En la config del Key Manager externo, el "Issuer"
  es un string que debe coincidir exactamente con el claim `iss` del token. `trazalog-dnato`
  funciona siempre que se configure idéntico en el APIM.
- **Recomendación:** mantener `trazalog-dnato` para el MVP (cambiar el issuer obliga a re-emitir
  todos los tokens y a sincronizar con el validador). Migrar a URL (`https://<dnato-host>`) solo
  si una integración futura lo exige. **No bloquea ADR-008.**

### 2.2 Decisión: valor de `aud`

El ADR recomienda `aud = identificador del APIM`. Hoy es `trazalog-mcp`.

- WSO2 permite configurar los "audiences" permitidos en el Key Manager. `trazalog-mcp` es un
  audience lógico válido para todo el tráfico MCP.
- **Recomendación:** mantener `trazalog-mcp` como audience del tráfico MCP. Es semánticamente
  claro y no obliga a acoplar el token a un identificador interno del APIM. Documentar este
  valor en la config del Key Manager (ver [apim-keymanager-dnato.md](apim-keymanager-dnato.md)).
  **No bloquea ADR-008.**

### 2.3 Validación de suscripción (`azp`/`consumerKey`) — DIFERIR a monetización

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

## 3. Accesibilidad de red del JWKS (única verificación operativa pendiente)

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

## 4. Lista de cambios necesarios en Dnato

**Para el MVP / ADR-008: NINGÚN cambio de código bloqueante.** Dnato está listo.

Tareas opcionales / de seguimiento (no bloquean la demo):

| Tarea | Tipo | Prioridad | Cuándo |
|---|---|---|---|
| Fijar `empr_id` como string en el payload (consistencia) | Código menor | — | **Aplicada en Sprint 2** (junio 2026) |
| Verificar accesibilidad de red del JWKS desde el APIM | Operativo | **Alta** | Antes de configurar el KM |
| Migrar `iss` a URL | Decisión + código | Baja | Solo si lo exige una integración futura |
| Agregar claim `azp`/`consumerKey` para validación de suscripción | Código | Media | Diferido a fase de monetización |

---

## 5. Conclusión

ADR-008 **no está bloqueado por Dnato**. El riesgo registrado en la Sección 12 del doc de
arquitectura ("Dnato debe exponer JWKS + firmar con RS256 antes de avanzar") **ya está
mitigado**: ambas cosas existen. El trabajo restante para Sprint 2 se concentra en el **lado
APIM** (configurar el Key Manager federado + mediación de inyección de `empr_id`), no en Dnato.

Próximos documentos:
- [apim-keymanager-dnato.md](apim-keymanager-dnato.md) — configuración del Key Manager.
- [empr-id-injection.md](empr-id-injection.md) — inyección de `X-Empr-Id` en el APIM.
- [../api/openapi-publish-procedure.md](../api/openapi-publish-procedure.md) — publicación de las APIs.
