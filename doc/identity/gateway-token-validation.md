# Gateway Token Validation — WSO2 MI MCP [E9-IDENT-05]

**Decisión base:** Sección 6.8 MCP Architecture Doc — Dnato emite JWTs, WSO2 los valida (ADR P01)  
**Fecha:** 2026-05  
**Estado:** MVP implementado

---

## 1. Flujo de validación

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

## 2. Artefactos implementados

| Artefacto | Path en repo | Propósito |
|-----------|-------------|-----------|
| `JwtValidator.xml` | `_backend/api/.../sequences/` | Valida firma RS256, claims, empr_id |
| `EmprIdInjector.xml` | `_backend/api/.../sequences/` | Inyecta X-Empr-Id en la llamada downstream |
| `dnato-public-key.pem` | `resources/registry/conf/` | Clave pública RS256 de Dnato (en registry) |

### Uso en un API MCP (inSequence)

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

## 3. Configuración de la clave pública (paso a paso — PROD)

### 3.1 Obtener la clave de Dnato

Ver procedimiento completo en [`jwt-keys-setup.md`](jwt-keys-setup.md).

Resumen para PROD:
1. Solicitar el PEM al equipo Dnato por canal seguro (no email)
2. Verificar fingerprint SHA256 con Dnato antes de usarla

### 3.2 Cargar en el registry de WSO2 MI

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

### 3.3 Verificar que la clave está cargada

Revisar logs de WSO2 MI después del primer request con JWT válido.
La secuencia `jwtValidator` no loguea la clave (solo errores), pero el script de diagnóstico
en `jwt-keys-setup.md §3` puede usarse para confirmar.

---

## 4. Asociar las sequences a una API MCP nueva

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

## 5. Casos de error y mensajes esperados

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

## 6. Aislamiento multi-empresa (garantía end-to-end)

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

## 7. Procedimiento de rotación de claves (MVP — manual)

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

## 8. Claims del JWT de Dnato (formato esperado)

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

## 9. Ejecutar tests de seguridad

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
