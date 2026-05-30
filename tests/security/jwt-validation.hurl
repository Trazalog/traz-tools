# E9-IDENT-05 — Tests de seguridad: JWT Validator + EmprId Injector
#
# Pre-requisitos:
#   1. WSO2 MI corriendo con los artefactos de ToolsAPIProject deployados
#   2. Clave pública de prueba cargada en registry conf:identity/dnato-public-key.pem
#   3. Generar variables con: ./generate-test-jwts.sh
#   4. Ejecutar: hurl --variables-file test-env.vars jwt-validation.hurl
#
# Variables requeridas:
#   MI_HOST        = host:port del WSO2 MI (ej: localhost:8280)
#   MCP_RESOURCE   = path del endpoint MCP protegido (ej: /tools/mcp/mantenimiento/solicitudes)
#   VALID_JWT, EXPIRED_JWT, WRONG_KEY_JWT, NO_EMPRID_JWT,
#   EMPRESA_A_JWT, EMPRESA_B_JWT


# ─────────────────────────────────────────────────────────────────
# Caso a: Request sin Authorization header → 401
# ─────────────────────────────────────────────────────────────────
GET http://{{MI_HOST}}{{MCP_RESOURCE}}
HTTP 401
[Asserts]
jsonpath "$.error" == "Unauthorized"
jsonpath "$.message" contains "Missing Authorization header"


# ─────────────────────────────────────────────────────────────────
# Caso b: Authorization header malformado (no Bearer) → 401
# ─────────────────────────────────────────────────────────────────
GET http://{{MI_HOST}}{{MCP_RESOURCE}}
Authorization: Basic dXNlcjpwYXNz
HTTP 401
[Asserts]
jsonpath "$.error" == "Unauthorized"
jsonpath "$.message" contains "Bearer"


# ─────────────────────────────────────────────────────────────────
# Caso b2: Bearer con token malformado (no 3 partes) → 401
# ─────────────────────────────────────────────────────────────────
GET http://{{MI_HOST}}{{MCP_RESOURCE}}
Authorization: Bearer esto.no.es.un.jwt.valido.tiene.mas.partes
HTTP 401
[Asserts]
jsonpath "$.error" == "Unauthorized"
jsonpath "$.message" contains "Malformed JWT"


# ─────────────────────────────────────────────────────────────────
# Caso c: JWT firmado con clave diferente → 401
# ─────────────────────────────────────────────────────────────────
GET http://{{MI_HOST}}{{MCP_RESOURCE}}
Authorization: Bearer {{WRONG_KEY_JWT}}
HTTP 401
[Asserts]
jsonpath "$.error" == "Unauthorized"
jsonpath "$.message" contains "signature"


# ─────────────────────────────────────────────────────────────────
# Caso d: JWT expirado → 401
# ─────────────────────────────────────────────────────────────────
GET http://{{MI_HOST}}{{MCP_RESOURCE}}
Authorization: Bearer {{EXPIRED_JWT}}
HTTP 401
[Asserts]
jsonpath "$.error" == "Unauthorized"
jsonpath "$.message" contains "expired"


# ─────────────────────────────────────────────────────────────────
# Caso e: JWT válido pero sin claim empr_id → 401
# ─────────────────────────────────────────────────────────────────
GET http://{{MI_HOST}}{{MCP_RESOURCE}}
Authorization: Bearer {{NO_EMPRID_JWT}}
HTTP 401
[Asserts]
jsonpath "$.error" == "Unauthorized"
jsonpath "$.message" contains "empr_id"


# ─────────────────────────────────────────────────────────────────
# Caso f: JWT válido → backend recibe header X-Empr-Id correcto
# (endpoint de diagnóstico que devuelve los headers recibidos)
# ─────────────────────────────────────────────────────────────────
GET http://{{MI_HOST}}{{MCP_ECHO_RESOURCE}}
Authorization: Bearer {{VALID_JWT}}
HTTP 200
[Asserts]
jsonpath "$.headers['X-Empr-Id']" == "42"


# ─────────────────────────────────────────────────────────────────
# Caso g: JWT de empresa A no accede a datos de empresa B
# Verifica aislamiento end-to-end: el DataService filtra por empr_id
# ─────────────────────────────────────────────────────────────────
GET http://{{MI_HOST}}{{MCP_DATA_RESOURCE}}
Authorization: Bearer {{EMPRESA_A_JWT}}
HTTP 200
[Asserts]
# Todos los registros devueltos pertenecen a empresa A (empr_id=42)
jsonpath "$[*].empr_id" not contains "99"

GET http://{{MI_HOST}}{{MCP_DATA_RESOURCE}}
Authorization: Bearer {{EMPRESA_B_JWT}}
HTTP 200
[Asserts]
# Todos los registros devueltos pertenecen a empresa B (empr_id=99)
jsonpath "$[*].empr_id" not contains "42"
