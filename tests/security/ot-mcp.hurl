# E1-API-05 — Tests del Virtual MCP Server OTs (ADR-008)
#
# ADR-008: auth validada por el APIM Gateway (Key Manager Dnato).
# Los tests apuntan al APIM (:8243), no al MI directo (:8280).
#
# Pre-requisitos:
#   1. APIM corriendo con APIs OTs publicadas + Key Manager Dnato + EmprIdInjectorPolicy
#   2. MI corriendo con EmprIdFromHeader.xml deployado (CAR actualizado)
#   3. Bonita BPM corriendo con proceso "Proceso de Mantenimiento AssetPlanner SIM"
#   4. assetv2: equipo id=10 pertenece a empresa A (id_empresa=42)
#   5. JWT reales de Dnato: php index.php cli issue_test_token <email> <empr_id>
#
# Variables requeridas:
#   APIM_HOST     = host:port APIM gateway (ej: localhost:8243)
#   VALID_JWT     = JWT válido empresa A (empr_id=42) — del CLI de Dnato
#   EXPIRED_JWT   = JWT expirado (generate-test-jwts.sh)
#   WRONG_KEY_JWT = JWT firmado con clave diferente (generate-test-jwts.sh)
#   EMPRESA_B_JWT = JWT válido empresa B (empr_id=99) — del CLI de Dnato


# ─────────────────────────────────────────────────────────────────
# GET /ordenes-trabajo/1.0/mcp/ot — lista de OTs de la empresa
# ─────────────────────────────────────────────────────────────────

# Caso 1a: JWT válido → devuelve lista de OTs de empresa A
GET https://{{APIM_HOST}}/ordenes-trabajo/1.0/mcp/ot
Authorization: Bearer {{VALID_JWT}}
HTTP 200
[Asserts]
jsonpath "$.solicitudes" exists
# Todas las OTs pertenecen a empresa A
jsonpath "$.solicitudes.solicitud[*].id_empresa" not contains "99"

# Caso 1b: Sin JWT → 401 (rechaza el APIM)
GET https://{{APIM_HOST}}/ordenes-trabajo/1.0/mcp/ot
HTTP 401

# Caso 1c: JWT expirado → 401
GET https://{{APIM_HOST}}/ordenes-trabajo/1.0/mcp/ot
Authorization: Bearer {{EXPIRED_JWT}}
HTTP 401

# Caso 1d: JWT empresa B → devuelve OTs de empresa B, no de empresa A
GET https://{{APIM_HOST}}/ordenes-trabajo/1.0/mcp/ot
Authorization: Bearer {{EMPRESA_B_JWT}}
HTTP 200
[Asserts]
jsonpath "$.solicitudes.solicitud[*].id_empresa" not contains "42"


# ─────────────────────────────────────────────────────────────────
# POST /ordenes-trabajo/1.0/mcp/ot — create_ot (demo tool)
# ─────────────────────────────────────────────────────────────────

# Caso 2a: POST válido → OT creada con empr_id del JWT (no del payload)
POST https://{{APIM_HOST}}/ordenes-trabajo/1.0/mcp/ot
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

# Caso 2b: POST sin JWT → 401 del APIM (sin INSERT en DB)
POST https://{{APIM_HOST}}/ordenes-trabajo/1.0/mcp/ot
Content-Type: application/json
{ "equipo_id": "10", "descripcion": "test sin auth" }
HTTP 401

# Caso 2c: JWT con clave incorrecta → 401
POST https://{{APIM_HOST}}/ordenes-trabajo/1.0/mcp/ot
Authorization: Bearer {{WRONG_KEY_JWT}}
Content-Type: application/json
{ "equipo_id": "10", "descripcion": "test clave incorrecta" }
HTTP 401

# Caso 2d: POST empresa B — verifica que OT se crea en empresa B (no en A)
POST https://{{APIM_HOST}}/ordenes-trabajo/1.0/mcp/ot
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
# GET /ordenes-trabajo/1.0/mcp/ot/{id} — detalle de OT
# ─────────────────────────────────────────────────────────────────

# Caso 3a: GET detalle de la OT creada en 2a — empresa A puede verla
GET https://{{APIM_HOST}}/ordenes-trabajo/1.0/mcp/ot/{{created_ot_id}}
Authorization: Bearer {{VALID_JWT}}
HTTP 200
[Asserts]
jsonpath "$.solicitudes.solicitud[0].id_solicitud" == {{created_ot_id}}
jsonpath "$.solicitudes.solicitud[0].id_empresa" == "42"
jsonpath "$.solicitudes.solicitud[0].case_id" == {{created_case_id}}
jsonpath "$.solicitudes.solicitud[0].estado" == "S"

# Caso 3b: empresa B intenta ver OT de empresa A → lista vacía (aislamiento SQL)
GET https://{{APIM_HOST}}/ordenes-trabajo/1.0/mcp/ot/{{created_ot_id}}
Authorization: Bearer {{EMPRESA_B_JWT}}
HTTP 200
[Asserts]
# DataService filtra por empr_id del JWT — devuelve vacío si no pertenece a empresa B
jsonpath "$.solicitudes.solicitud" isEmpty

# Caso 3c: Sin JWT → 401
GET https://{{APIM_HOST}}/ordenes-trabajo/1.0/mcp/ot/{{created_ot_id}}
HTTP 401

# Caso 3d: empresa B puede ver su propia OT (creada en 2d)
GET https://{{APIM_HOST}}/ordenes-trabajo/1.0/mcp/ot/{{ot_empresa_b_id}}
Authorization: Bearer {{EMPRESA_B_JWT}}
HTTP 200
[Asserts]
jsonpath "$.solicitudes.solicitud[0].id_solicitud" == {{ot_empresa_b_id}}
jsonpath "$.solicitudes.solicitud[0].id_empresa" == "99"
