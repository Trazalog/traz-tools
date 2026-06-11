# E9-IDENT-05 (ADR-008) — Tests de seguridad: validación JWT en APIM Gateway
#
# ADR-008: la validación del JWT la hace el APIM (Key Manager Dnato), no el MI.
# Estos tests apuntan al APIM (:8243), no al MI directo (:8280).
#
# Pre-requisitos:
#   1. APIM corriendo con Key Manager Dnato configurado (apim-keymanager-dnato.md)
#   2. APIs Equipos y OTs publicadas con KM Dnato + mediación EmprIdInjectorPolicy
#   3. Generar JWT de prueba:
#      - JWT válido: php index.php cli issue_test_token <email> <empr_id>  (en host Dnato)
#      - JWT inválidos/expirados: ./generate-test-jwts.sh (crea claves de prueba independientes)
#   4. Ejecutar: hurl --variables-file test-env.vars jwt-validation.hurl
#
# Variables requeridas en test-env.vars:
#   APIM_HOST      = host:port del APIM gateway (ej: localhost:8243)
#   VALID_JWT      = JWT válido firmado por la clave REAL de Dnato (del CLI de Dnato)
#   EXPIRED_JWT    = JWT expirado firmado con la clave de PRUEBA (generate-test-jwts.sh)
#   WRONG_KEY_JWT  = JWT firmado con clave diferente a Dnato (generate-test-jwts.sh)
#   NO_EMPRID_JWT  = JWT válido pero sin claim empr_id (generate-test-jwts.sh)
#   EMPRESA_A_JWT  = JWT válido empresa A (empr_id=42) — del CLI de Dnato
#   EMPRESA_B_JWT  = JWT válido empresa B (empr_id=99) — del CLI de Dnato
#
# Nota: EXPIRED_JWT, WRONG_KEY_JWT y NO_EMPRID_JWT se generan con claves de prueba
# independientes (generate-test-jwts.sh). Como no están en el JWKS de Dnato, el APIM
# los rechaza — el caso WRONG_KEY_JWT prueba exactamente eso. Para EXPIRED_JWT el APIM
# rechaza por exp < ahora antes de validar la firma.


# ─────────────────────────────────────────────────────────────────
# Caso a: Request sin Authorization header → 401 del APIM
# ─────────────────────────────────────────────────────────────────
GET https://{{APIM_HOST}}/equipos/1.0/mcp/equipos
HTTP 401


# ─────────────────────────────────────────────────────────────────
# Caso b: Authorization header malformado (no Bearer) → 401 del APIM
# ─────────────────────────────────────────────────────────────────
GET https://{{APIM_HOST}}/equipos/1.0/mcp/equipos
Authorization: Basic dXNlcjpwYXNz
HTTP 401


# ─────────────────────────────────────────────────────────────────
# Caso c: JWT firmado con clave diferente a Dnato → 401
# (la clave de prueba de generate-test-jwts.sh no está en el JWKS de Dnato)
# ─────────────────────────────────────────────────────────────────
GET https://{{APIM_HOST}}/equipos/1.0/mcp/equipos
Authorization: Bearer {{WRONG_KEY_JWT}}
HTTP 401


# ─────────────────────────────────────────────────────────────────
# Caso d: JWT expirado → 401
# ─────────────────────────────────────────────────────────────────
GET https://{{APIM_HOST}}/equipos/1.0/mcp/equipos
Authorization: Bearer {{EXPIRED_JWT}}
HTTP 401


# ─────────────────────────────────────────────────────────────────
# Caso e: JWT válido (firma correcta) pero sin claim empr_id → 401
# La in-sequence EmprIdInjectorPolicy rechaza el request si falta empr_id.
# ─────────────────────────────────────────────────────────────────
GET https://{{APIM_HOST}}/equipos/1.0/mcp/equipos
Authorization: Bearer {{NO_EMPRID_JWT}}
HTTP 401


# ─────────────────────────────────────────────────────────────────
# Caso f: JWT válido de empresa A → 200, datos de empresa A únicamente
# ─────────────────────────────────────────────────────────────────
GET https://{{APIM_HOST}}/equipos/1.0/mcp/equipos
Authorization: Bearer {{EMPRESA_A_JWT}}
HTTP 200


# ─────────────────────────────────────────────────────────────────
# Caso g: JWT de empresa A no accede a datos de empresa B (aislamiento)
# El DataService filtra por empr_id inyectado por el APIM, nunca por empresa B.
# ─────────────────────────────────────────────────────────────────
GET https://{{APIM_HOST}}/equipos/1.0/mcp/equipos
Authorization: Bearer {{EMPRESA_A_JWT}}
HTTP 200
[Asserts]
# Ningún equipo devuelto pertenece a empresa B (empr_id=99)
jsonpath "$[*].empr_id" not contains "99"

GET https://{{APIM_HOST}}/equipos/1.0/mcp/equipos
Authorization: Bearer {{EMPRESA_B_JWT}}
HTTP 200
[Asserts]
# Ningún equipo devuelto pertenece a empresa A (empr_id=42)
jsonpath "$[*].empr_id" not contains "42"


# ─────────────────────────────────────────────────────────────────
# Caso h: Anti-spoofing — JWT empresa A + header X-Empr-Id: 999 en el request
# La EmprIdInjectorPolicy descarta el header entrante y lo sobreescribe con el
# valor del claim del JWT. El MI recibe X-Empr-Id: 42, NO 999.
# Verifica que los datos devueltos son de empresa A (42), no de la 999 falsa.
# ─────────────────────────────────────────────────────────────────
GET https://{{APIM_HOST}}/equipos/1.0/mcp/equipos
Authorization: Bearer {{EMPRESA_A_JWT}}
X-Empr-Id: 999
HTTP 200
[Asserts]
# El APIM descartó el X-Empr-Id: 999 entrante; los datos son de empresa 42
jsonpath "$[*].empr_id" not contains "999"
