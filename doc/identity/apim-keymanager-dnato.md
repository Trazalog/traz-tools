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

## 3. Registrar Dnato como emisor JWT en `deployment.toml`

> **Nota de implementación:** APIM 4.6.0 incluye conectores para Auth0, Okta, Keycloak, Azure,
> ForgeRock, PingFederate y WSO2 IS, pero **no tiene un conector genérico para IdPs custom**.
> La Admin UI y la Admin REST API no permiten registrar un KM externo sin un conector instalado.
> El mecanismo correcto para IdPs custom que solo emiten JWTs es `[[apim.jwt.issuer]]` en
> `deployment.toml`. Este mecanismo registra el emisor en la capa de validación del gateway
> (XML `<TokenIssuers>`) y NO en la lista de Key Managers de la Admin UI — lo cual es
> correcto para el flujo ADR-008.

### 3.1 Configuración en `deployment.toml`

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

### 3.2 Reiniciar el APIM

```bash
$APIM_HOME/bin/api-manager.sh restart
```

### 3.3 Verificar que la configuración se aplicó

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

### 3.4 Comportamiento del gateway con `[[apim.jwt.issuer]]`

- El gateway valida **firma RS256** contra el JWKS y valida que `iss` = `trazalog-dnato`.
- Un JWT con firma inválida o `iss` desconocido → **HTTP 401** (Invalid Credentials).
- Un JWT válido de Dnato en una API con subscription validation habilitada → **HTTP 403**
  (Resource forbidden, código 900908). Ver §4.1.
- La **restricción por-API** (que solo las APIs MCP acepten tokens Dnato) se configura en
  el Publisher: asociar cada API MCP a este issuer (ver §5).
- Las APIs legacy con tokens opacos del Resident KM **no se ven afectadas**: el gateway
  valida el tipo de token antes de buscar el emisor JWT.

---

## 4. Decisiones de configuración importantes

### 4.1 Subscription validation con `[[apim.jwt.issuer]]` — implementación real

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

### 4.2 Coexistencia con el Resident Key Manager (APIs legacy)

Las APIs legacy con tokens opacos del Resident KM no se ven afectadas. El mecanismo
`[[apim.jwt.issuer]]` solo actúa cuando llega un JWT con `iss = trazalog-dnato`; los
tokens opacos tienen un formato diferente y siguen el flujo de introspección del Resident KM.

> El `deployment.toml` de DEV (`$APIM_HOME/repository/conf/deployment.toml`) tiene la
> configuración activa en la sección `[[apim.jwt.issuer]]`. En TEST/PROD, cambiar
> `jwks.url` a la URL real de Dnato antes del deploy.

---

## 5. Configurar las APIs MCP en el Publisher para Dnato

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

## 7. Configuración en deployment.toml

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
