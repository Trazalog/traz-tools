# Configuración de Dnato como Key Manager federado en WSO2 APIM 4.6.0

**Tarea:** E9-IDENT-05 (reorientada por ADR-008)
**Decisión base:** [ADR-008](../v3/TRAZALOG_v3_MCP_ARCHITECTURE.md) — el APIM valida JWT de Dnato
como Key Manager federado.
**Prerequisito:** [dnato-jwt-prereqs.md](dnato-jwt-prereqs.md) — confirma que Dnato ya firma
con RS256, ya expone JWKS, y no requiere cambios de código para esta federación.

---

## 1. Contexto y objetivo

Un **Key Manager federado** le dice al APIM: "los tokens emitidos por este emisor (`iss`) son
válidos; verificá la firma contra este JWKS; aceptá este audience (`aud`)". Una vez configurado,
el APIM puede validar tokens de Dnato de la misma manera que valida los suyos propios, **sin
compartir secretos** y sin que el MI (Micro Integrator) tenga que hacer nada de validación.

El **Resident Key Manager** del APIM (el KM interno) sigue activo para las APIs legacy.
Ambos coexisten: las APIs MCP se asocian a **Dnato KM**, las legacy a **Resident KM**.
Ninguna configuración global ni flag en `deployment.toml` afectan la coexistencia.

### Datos de Dnato a tener a mano antes de empezar

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

## 2. Verificar accesibilidad del JWKS desde el APIM

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

## 3. Agregar Dnato como Key Manager en la consola Admin

1. Ir a **`https://localhost:9443/admin`** e iniciar sesión con credenciales de admin.
2. En el menú izquierdo, seleccionar **`Key Managers`**.
3. Hacer click en **`Add Key Manager`**.
4. Completar el formulario con los siguientes valores:

### 3.1 General Details

| Campo | Valor |
|---|---|
| **Name** | `Dnato` |
| **Display Name** | `Dnato — Identity Provider Trazalog` |
| **Description** | `Valida JWTs emitidos por Dnato para tráfico MCP (RS256, JWKS). ADR-008.` |
| **Key Manager Type** | `Custom` (o `Default` según versión — el tipo que no requiere plugin custom) |

> En APIM 4.6.0, para un IdP externo que solo firma JWTs (sin endpoints de intercambio de
> tokens propios en el APIM), usar tipo **`Default`** o **`Resident Key Manager`** configurado
> con los datos de Dnato. Si el portal muestra una lista de tipos (Okta, Auth0, Keycloak…),
> elegir el que corresponda a un IdP genérico/custom. Si solo aparecen los vendors listados y
> ningún "custom/generic", ver la Nota de resolución en §3.4.

### 3.2 Token Endpoint Configuration

Estos campos son requeridos por el formulario pero **no se usan en el flujo de validación de
JWTs directos**. Poner la URL base de Dnato como placeholder para que el formulario acepte:

| Campo | Valor |
|---|---|
| **Well-known URL** | `https://<dnato-host>/.well-known/openid-configuration` *(si existe)* |
| **Issuer** | `trazalog-dnato` *(debe coincidir exactamente con el claim `iss` del JWT)* |
| **Client Registration Endpoint** | `https://<dnato-host>/oauth/register` *(placeholder — no se usa)* |
| **Introspection Endpoint** | `https://<dnato-host>/oauth/introspect` *(placeholder — no se usa)* |
| **Token Endpoint** | `https://<dnato-host>/oauth/token` *(real — `POST /oauth/token` existe en Dnato)* |
| **Revoke Endpoint** | dejar vacío o placeholder |
| **JWKS URL** | `https://<dnato-host>/oauth/.well-known/jwks.json` *(este sí es crítico)* |

### 3.3 Claim Configuration

| Campo | Valor |
|---|---|
| **Consumer Key Claim** | `azp` *(WSO2 default; Dnato no emite este claim en MVP — ver §4.1)* |
| **Scopes Claim** | `scope` *(Dnato no emite `scope` en MVP — no bloqueante)* |
| **Subject Claim** | `sub` |

> **Audience Validation:** si el formulario incluye un campo "Audiences", agregar `trazalog-mcp`.
> El APIM rechazará tokens cuyo claim `aud` no coincida con ninguno de los valores configurados.

### 3.4 Token Handling Method

| Campo | Valor |
|---|---|
| **Token Handling Method** | `JSON Web Token (JWT)` |
| **Enable Subscription Validation** | **DESACTIVADO** (unchecked) — ver §4.1 |

> **Por qué deshabilitar subscription validation:** en el MVP, Dnato no emite el consumer key
> en el claim `azp`/`consumerKey`. La validación de suscripción requiere que el JWT contenga
> ese claim mapeado a una aplicación registrada en el APIM. Sin él, la validación de suscripción
> fallará en el 100% de los requests. Diferir a cuando se implemente monetización (ver §4.1).

### 3.5 Certificate

| Campo | Valor |
|---|---|
| **Tipo** | `JWKS` (usar JWKS URL en lugar de certificado estático) |
| **JWKS URL** | *(ya configurado en §3.2)* |

> No usar certificado PEM estático para el MVP si el JWKS URL está disponible. El JWKS permite
> rotación de claves sin reconfigurar el APIM.

### 3.6 Grant Types permitidos

Habilitar al menos:
- `authorization_code` (flujo real — Dnato implementa OAuth 2.1 con PKCE)
- `refresh_token` (si Dnato lo implementa — actualmente no en el repo, habilitar en Sprint 3+)

No es necesario habilitar `client_credentials` ni otros para el MVP.

### 3.7 Guardar

Click en **`Add`** (o **`Save`**). El Key Manager `Dnato` aparece en la lista con estado activo.

---

## 4. Decisiones de configuración importantes

### 4.1 Subscription validation DESACTIVADA (MVP)

**Por qué:** la validación de suscripción requiere que el JWT contenga el consumer key de
una aplicación OAuth registrada en el APIM (claim `azp` o `consumerKey`), mapeada
vía "Provisioning Out-of-Band OAuth2 Clients". Los JWTs de Dnato no contienen ese claim.

**Impacto en seguridad:** el APIM sigue validando firma (RS256 vs JWKS), `exp`, `iss` y `aud`.
El aislamiento multi-tenant lo garantiza el claim `empr_id` inyectado como `X-Empr-Id`. El
único control que se pierde es el rate-limiting por aplicación y la visibilidad de suscripciones
en el Developer Portal — funcionalidades que corresponden a la fase de monetización, no al MVP.

**Camino de activación (Sprint monetización):**
1. Dnato agrega claim `azp: <client_id>` al JWT.
2. Se registran las aplicaciones cliente como "out-of-band" en el APIM.
3. Se activa `Enable Subscription Validation` en el KM Dnato.
4. Las APIs MCP se suscriben a tiers específicos.

### 4.2 Coexistencia con el Resident Key Manager (APIs legacy)

Las APIs legacy del APIM usan el **Resident Key Manager** (el interno). Este no se toca.
En el Publisher, al configurar cada API:
- **APIs legacy:** el campo Key Managers muestra `Resident Key Manager` seleccionado (default).
- **APIs MCP:** se cambia a **únicamente `Dnato`** (des-seleccionar Resident KM).

Ambos Key Managers están activos simultáneamente a nivel de APIM. El gateway determina cuál
usar por el `iss` del token y la configuración de la API específica.

> No hay ningún `deployment.toml` global que cambiar para esta coexistencia. Es configuración
> por API en el Publisher.

---

## 5. Asociar el Key Manager Dnato a las APIs MCP en el Publisher

Una vez creado el KM Dnato:

1. Ir a `https://localhost:9443/publisher`
2. Seleccionar la API (Equipos 1.0 o Ordenes de Trabajo 1.0)
3. **`Develop`** → **`API Configurations`** → **`Runtime`**
4. En **`Application Level Security`**: marcar **`OAuth2`**
5. En **`Key Managers`**: seleccionar **`Dnato`** y **des-seleccionar `Resident Key Manager`**
6. **`Save`** → **`Publish`**

Repetir para cada API MCP.

---

## 6. Verificar que la validación funciona

### 6.1 Obtener un JWT real de Dnato

```bash
# En el host de Dnato:
JWT=$(php index.php cli issue_test_token <email> [empr_id])
echo $JWT
```

O usar el flujo OAuth completo (authorization code + PKCE) en un cliente de prueba.

### 6.2 Casos de verificación

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

## 7. Configuración en deployment.toml (solo si es necesario)

Para la configuración del Key Manager Dnato **no se requiere tocar `deployment.toml`**.
La configuración se hace completamente desde la consola Admin (§3).

**Configuraciones que explícitamente NO se aplican:**

```toml
# ❌ NO APLICAR — ADR-008 lo prohíbe. Afecta TODAS las APIs del APIM.
# [apim.oauth_config]
# enable_outbound_auth_header = true
```

Si en algún momento se necesita tunear el comportamiento del JWT validation a nivel global
(ej: deshabilitar validación de suscripción globalmente, cambiar el claim de consumer key),
el parámetro correcto y scoped es:

```toml
# Solo si la UI no provee el toggle (versiones más viejas de APIM):
# Aplica SOLO al tenant que lo configura, no es global de la instancia.
[apim.jwt_authentication]
# enable_subscription_validation = false   # default false para External KMs sin consumerKey
# consumer_dialect_uri = "http://wso2.org/claims"
```

En APIM 4.6.0 este parámetro se gestiona vía UI (§3.4), no requiere editar el TOML.

---

## 8. Troubleshooting

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

## Referencias

- WSO2 docs — Key Manager overview: https://apim.docs.wso2.com/en/4.5.0/administer/key-managers/overview/
- WSO2 docs — Custom Key Manager: https://apim.docs.wso2.com/en/4.5.0/administer/key-managers/configure-custom-connector/
- [dnato-jwt-prereqs.md](dnato-jwt-prereqs.md) — Estado de Dnato y decisiones de iss/aud
- [empr-id-injection.md](empr-id-injection.md) — Inyección de X-Empr-Id en la mediación del APIM
- [openapi-publish-procedure.md](../api/openapi-publish-procedure.md) — Publicación de APIs
