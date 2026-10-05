# E2-MCP-11 (ADR-013) — Tests de la fachada toolsMCPAPI, tool man_get_equipos
#
# Este test llama al MI DIRECTAMENTE (:8290), sin pasar por el APIM — mismo
# patrón que mi-fallback.hurl. Simula el header X-JWT-Assertion que en
# producción genera y firma el APIM (ADR-008/ADR-009); EmprIdFromHeader.xml
# todavía no valida esa firma (ver su propio comentario "PROD: validar la
# firma..."), así que alcanza con el shape que arma mint-backend-jwt.py.
#
# Pre-requisitos:
#   1. MI corriendo con el CAR de ToolsAPIProject actualizado (incluye
#      toolsMCPAPI.xml) deployado — ver scripts/dev/setup-mi-b4-car-deploy.sh
#   2. Conectividad real a la BD que usa MANEquiposDataService (para que el
#      Caso C devuelva 200 con datos reales, no solo "no 503")
#
# Variables requeridas:
#   MI_HOST        = host:port del MI (ej: localhost:8290)
#   VALID_ASSERTION = valor de X-JWT-Assertion con empr_id/empr_id_mysql —
#                      generar con: python3 scripts/dev/mint-backend-jwt.py 42 42
#
# Ejecutar:
#   ASSERTION=$(python3 scripts/dev/mint-backend-jwt.py 42 42)
#   hurl --variable MI_HOST=localhost:8290 --variable VALID_ASSERTION="$ASSERTION" \
#        mcp-facade-man-get-equipos.hurl


# ─────────────────────────────────────────────────────────────────
# Caso A: sin X-JWT-Assertion → 503 identity_missing (EmprIdFromHeader,
# fail-closed — nunca sigue sin poder resolver empr_id)
# ─────────────────────────────────────────────────────────────────
GET http://{{MI_HOST}}/tools/mcp/mcp/man/equipos
HTTP 503
[Asserts]
jsonpath "$.error" == "identity_missing"


# ─────────────────────────────────────────────────────────────────
# Caso B: X-JWT-Assertion mal formado (no tiene 3 segmentos) → 503
# identity_missing, igual que el caso sin header (fail-closed)
# ─────────────────────────────────────────────────────────────────
GET http://{{MI_HOST}}/tools/mcp/mcp/man/equipos
X-JWT-Assertion: no-es-un-jwt-valido
HTTP 503
[Asserts]
jsonpath "$.error" == "identity_missing"


# ─────────────────────────────────────────────────────────────────
# Caso C: X-JWT-Assertion con empr_id válido → NO 503 (EmprIdFromHeader
# resolvió empr_id y la fachada ruteó a MANEquiposDataService). Sin BD
# real alcanzable, lo importante es que NO sea 503 — igual criterio que
# mi-fallback.hurl Caso C.
# ─────────────────────────────────────────────────────────────────
GET http://{{MI_HOST}}/tools/mcp/mcp/man/equipos
X-JWT-Assertion: {{VALID_ASSERTION}}
HTTP *
[Asserts]
status != 503
