# E1-API-05 — Tests del Virtual MCP Server OTs
#
# Pre-requisitos:
#   1. WSO2 MI corriendo con ToolsAPIProject deployado
#   2. Bonita BPM corriendo con proceso "Proceso de Mantenimiento AssetPlanner SIM"
#   3. assetv2: equipo id=10 pertenece a empresa A (id_empresa=42)
#   4. Generar tokens con tests/security/generate-test-jwts.sh
#
# Variables requeridas:
#   MI_HOST       = host:port WSO2 MI (ej: localhost:8280)
#   VALID_JWT     = JWT válido empresa A (empr_id=42)
#   EXPIRED_JWT   = JWT expirado
#   WRONG_KEY_JWT = JWT firmado con clave diferente
#   EMPRESA_B_JWT = JWT válido empresa B (empr_id=99)


# ─────────────────────────────────────────────────────────────────
# GET /tools/man/mcp/ot — lista de OTs de la empresa
# ─────────────────────────────────────────────────────────────────

# Caso 1a: JWT válido → devuelve lista de OTs de empresa A
GET http://{{MI_HOST}}/tools/man/mcp/ot
Authorization: Bearer {{VALID_JWT}}
HTTP 200
[Asserts]
jsonpath "$.solicitudes" exists
# Todas las OTs pertenecen a empresa A
jsonpath "$.solicitudes.solicitud[*].id_empresa" not contains "99"

# Caso 1b: Sin JWT → 401
GET http://{{MI_HOST}}/tools/man/mcp/ot
HTTP 401
[Asserts]
jsonpath "$.error" == "Unauthorized"

# Caso 1c: JWT expirado → 401
GET http://{{MI_HOST}}/tools/man/mcp/ot
Authorization: Bearer {{EXPIRED_JWT}}
HTTP 401
[Asserts]
jsonpath "$.message" contains "expired"

# Caso 1d: JWT empresa B → devuelve OTs de empresa B, no de empresa A
GET http://{{MI_HOST}}/tools/man/mcp/ot
Authorization: Bearer {{EMPRESA_B_JWT}}
HTTP 200
[Asserts]
jsonpath "$.solicitudes.solicitud[*].id_empresa" not contains "42"


# ─────────────────────────────────────────────────────────────────
# POST /tools/man/mcp/ot — create_ot (demo tool)
# ─────────────────────────────────────────────────────────────────

# Caso 2a: POST válido → OT creada con empr_id del JWT (no del payload)
POST http://{{MI_HOST}}/tools/man/mcp/ot
Authorization: Bearer {{VALID_JWT}}
Content-Type: application/json
{
  "equipo_id": "10",
  "descripcion": "Ruido inusual en compresor principal - requiere revision"
}
HTTP 200
[Captures]
created_ot_id: jsonpath "$.ot_id"
created_case_id: jsonpath "$.case_id"
[Asserts]
jsonpath "$.resultado" == "ok"
jsonpath "$.ot_id" exists
jsonpath "$.case_id" exists
jsonpath "$.estado" == "S"

# Caso 2b: POST sin JWT → 401 (sin INSERT en DB)
POST http://{{MI_HOST}}/tools/man/mcp/ot
Content-Type: application/json
{ "equipo_id": "10", "descripcion": "test sin auth" }
HTTP 401
[Asserts]
jsonpath "$.error" == "Unauthorized"

# Caso 2c: JWT con clave incorrecta → 401
POST http://{{MI_HOST}}/tools/man/mcp/ot
Authorization: Bearer {{WRONG_KEY_JWT}}
Content-Type: application/json
{ "equipo_id": "10", "descripcion": "test clave incorrecta" }
HTTP 401
[Asserts]
jsonpath "$.message" contains "signature"

# Caso 2d: POST empresa B — verifica que OT se crea en empresa B (no en A)
# La OT creada en 2d debe tener id_empresa=99, no 42
POST http://{{MI_HOST}}/tools/man/mcp/ot
Authorization: Bearer {{EMPRESA_B_JWT}}
Content-Type: application/json
{
  "equipo_id": "20",
  "descripcion": "OT de empresa B - aislamiento"
}
HTTP 200
[Captures]
ot_empresa_b_id: jsonpath "$.ot_id"
[Asserts]
jsonpath "$.resultado" == "ok"


# ─────────────────────────────────────────────────────────────────
# GET /tools/man/mcp/ot/{id} — detalle de OT recién creada
# ─────────────────────────────────────────────────────────────────

# Caso 3a: GET detalle de la OT creada en 2a — empresa A puede verla
GET http://{{MI_HOST}}/tools/man/mcp/ot/{{created_ot_id}}
Authorization: Bearer {{VALID_JWT}}
HTTP 200
[Asserts]
jsonpath "$.solicitudes.solicitud[0].id_solicitud" == {{created_ot_id}}
jsonpath "$.solicitudes.solicitud[0].id_empresa" == "42"
jsonpath "$.solicitudes.solicitud[0].case_id" == {{created_case_id}}
jsonpath "$.solicitudes.solicitud[0].estado" == "S"

# Caso 3b: empresa B intenta ver OT de empresa A → lista vacía (aislamiento SQL)
GET http://{{MI_HOST}}/tools/man/mcp/ot/{{created_ot_id}}
Authorization: Bearer {{EMPRESA_B_JWT}}
HTTP 200
[Asserts]
# getSolicitudServicioById filtra por id_empresa del JWT — devuelve vacío si no pertenece
jsonpath "$.solicitudes.solicitud" isEmpty

# Caso 3c: Sin JWT → 401
GET http://{{MI_HOST}}/tools/man/mcp/ot/{{created_ot_id}}
HTTP 401
[Asserts]
jsonpath "$.error" == "Unauthorized"

# Caso 3d: empresa B puede ver su propia OT (creada en 2d)
GET http://{{MI_HOST}}/tools/man/mcp/ot/{{ot_empresa_b_id}}
Authorization: Bearer {{EMPRESA_B_JWT}}
HTTP 200
[Asserts]
jsonpath "$.solicitudes.solicitud[0].id_solicitud" == {{ot_empresa_b_id}}
jsonpath "$.solicitudes.solicitud[0].id_empresa" == "99"
