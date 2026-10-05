# E2-MCP-12 (ADR-013) — Tests de las tools de mantenimiento en toolsMCPAPI
# (man_get_equipo, man_get_ots, man_get_ot, man_create_ot)
#
# Mismo patrón que mcp-facade-man-get-equipos.hurl (E2-MCP-11): llama al MI
# DIRECTAMENTE (:8290), simulando X-JWT-Assertion con
# scripts/dev/mint-backend-jwt.py. Cubre el contrato de identidad
# (fail-closed sin empr_id) para las 4 tools nuevas — el smoke test
# funcional completo (con BD y BPM reales) se hace en la migración
# coordinada de la Tarea 3.4.
#
# Pre-requisitos:
#   1. MI corriendo con el CAR de ToolsAPIProject actualizado (toolsMCPAPI
#      con las 5 tools de mantenimiento) deployado
#   2. Para los Casos C (respuesta real, no solo "no 503"): conectividad a
#      la BD de MANDataService/MANEquiposDataService y, para man_create_ot,
#      a Bonita BPM
#
# Variables requeridas:
#   MI_HOST         = host:port del MI (ej: localhost:8290)
#   VALID_ASSERTION = generar con: python3 scripts/dev/mint-backend-jwt.py 42 42
#
# Ejecutar:
#   ASSERTION=$(python3 scripts/dev/mint-backend-jwt.py 42 42)
#   hurl --variable MI_HOST=localhost:8290 --variable VALID_ASSERTION="$ASSERTION" \
#        mcp-facade-man-tools.hurl


# ─────────────────────────────────────────────────────────────────
# man_get_equipo — GET /tools/mcp/mcp/man/equipo/{equi_id}
# ─────────────────────────────────────────────────────────────────

# Caso A: sin X-JWT-Assertion → 503 identity_missing
GET http://{{MI_HOST}}/tools/mcp/mcp/man/equipo/10
HTTP 503
[Asserts]
jsonpath "$.error" == "identity_missing"

# Caso C: X-JWT-Assertion válido → NO 503 (empr_id resuelto, ruteó a MANDataService)
GET http://{{MI_HOST}}/tools/mcp/mcp/man/equipo/10
X-JWT-Assertion: {{VALID_ASSERTION}}
HTTP *
[Asserts]
status != 503


# ─────────────────────────────────────────────────────────────────
# man_get_ots — GET /tools/mcp/mcp/man/ot
# ─────────────────────────────────────────────────────────────────

# Caso A: sin X-JWT-Assertion → 503 identity_missing
GET http://{{MI_HOST}}/tools/mcp/mcp/man/ot
HTTP 503
[Asserts]
jsonpath "$.error" == "identity_missing"

# Caso C: X-JWT-Assertion válido → NO 503
GET http://{{MI_HOST}}/tools/mcp/mcp/man/ot
X-JWT-Assertion: {{VALID_ASSERTION}}
HTTP *
[Asserts]
status != 503


# ─────────────────────────────────────────────────────────────────
# man_get_ot — GET /tools/mcp/mcp/man/ot/{id_solicitud}
# ─────────────────────────────────────────────────────────────────

# Caso A: sin X-JWT-Assertion → 503 identity_missing
GET http://{{MI_HOST}}/tools/mcp/mcp/man/ot/1
HTTP 503
[Asserts]
jsonpath "$.error" == "identity_missing"

# Caso C: X-JWT-Assertion válido → NO 503
GET http://{{MI_HOST}}/tools/mcp/mcp/man/ot/1
X-JWT-Assertion: {{VALID_ASSERTION}}
HTTP *
[Asserts]
status != 503


# ─────────────────────────────────────────────────────────────────
# man_create_ot — POST /tools/mcp/mcp/man/ot
# El flujo completo (INSERT + BPM + rollback) requiere Bonita + BD reales
# (ver ot-mcp.hurl para el smoke test funcional completo, vía APIM). Acá
# solo se cubre el contrato de identidad de la fachada.
# ─────────────────────────────────────────────────────────────────

# Caso A: sin X-JWT-Assertion → 503 identity_missing (NO debe llegar a
# insertar nada en MANDataService — el fail-closed corta antes del INSERT)
POST http://{{MI_HOST}}/tools/mcp/mcp/man/ot
Content-Type: application/json
{ "equipo_id": "10", "descripcion": "test sin auth" }
HTTP 503
[Asserts]
jsonpath "$.error" == "identity_missing"

# Caso C: X-JWT-Assertion válido → NO 503 (empr_id resuelto, arrancó el
# flujo INSERT→BPM→PUT case_id; el resultado final depende de BD/Bonita
# reales, no evaluados acá)
POST http://{{MI_HOST}}/tools/mcp/mcp/man/ot
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{ "equipo_id": "10", "descripcion": "test con auth" }
HTTP *
[Asserts]
status != 503
