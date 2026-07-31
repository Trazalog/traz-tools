# E2-MCP-13 (ADR-013) — Tests de las tools de almacenes en toolsMCPAPI
# (alm_get_stock, alm_get_pedidos_materiales, alm_get_pedido_material,
# alm_crear_pedido_materiales)
#
# Mismo patrón que mcp-facade-man-tools.hurl: llama al MI DIRECTAMENTE
# (:8290), simulando X-JWT-Assertion con scripts/dev/mint-backend-jwt.py.
# Cubre el contrato de identidad de toolsMCPAPI (fail-closed sin empr_id,
# y que el empr_id del body NUNCA se usa) — el smoke test funcional
# completo (con BD y BPM reales, incluida la verificación de que el
# rollback dispara si Bonita falla) queda para la migración coordinada de
# la Tarea 3.4, con BD y Bonita reales conectados.
#
# Pre-requisitos:
#   1. MI corriendo con el CAR de ToolsAPIProject actualizado (toolsMCPAPI
#      + toolsALMAPI + ALMDataService con las 3 queries nuevas) deployado
#   2. Para los Casos C (respuesta real, no solo "no 503"): conectividad a
#      la BD de ALMDataService y, para alm_crear_pedido_materiales, a
#      Bonita BPM con el proceso "Ped. Materiales" (nombre a confirmar)
#
# Variables requeridas:
#   MI_HOST          = host:port del MI (ej: localhost:8290)
#   VALID_ASSERTION  = empresa A: python3 scripts/dev/mint-backend-jwt.py 42 42
#   OTHER_ASSERTION  = empresa B: python3 scripts/dev/mint-backend-jwt.py 99 99
#
# Ejecutar:
#   A=$(python3 scripts/dev/mint-backend-jwt.py 42 42)
#   B=$(python3 scripts/dev/mint-backend-jwt.py 99 99)
#   hurl --variable MI_HOST=localhost:8290 --variable VALID_ASSERTION="$A" \
#        --variable OTHER_ASSERTION="$B" mcp-facade-alm-tools.hurl


# ─────────────────────────────────────────────────────────────────
# alm_get_stock — GET /tools/mcp/mcp/alm/stock
# ─────────────────────────────────────────────────────────────────

# Caso A: sin X-JWT-Assertion → 503 identity_missing
GET http://{{MI_HOST}}/tools/mcp/mcp/alm/stock
HTTP 503
[Asserts]
jsonpath "$.error" == "identity_missing"

# Caso C: X-JWT-Assertion válido → NO 503 (empr_id resuelto, delegó a toolsALMAPI)
GET http://{{MI_HOST}}/tools/mcp/mcp/alm/stock
X-JWT-Assertion: {{VALID_ASSERTION}}
HTTP *
[Asserts]
status != 503


# ─────────────────────────────────────────────────────────────────
# alm_get_pedidos_materiales — GET /tools/mcp/mcp/alm/pedidos
# ─────────────────────────────────────────────────────────────────

# Caso A: sin X-JWT-Assertion → 503 identity_missing
GET http://{{MI_HOST}}/tools/mcp/mcp/alm/pedidos
HTTP 503
[Asserts]
jsonpath "$.error" == "identity_missing"

# Caso C: X-JWT-Assertion válido → NO 503
GET http://{{MI_HOST}}/tools/mcp/mcp/alm/pedidos
X-JWT-Assertion: {{VALID_ASSERTION}}
HTTP *
[Asserts]
status != 503

# Caso D — aislamiento: empresa A y empresa B piden lo mismo, cada una
# ve solo lo suyo. No verificable sin BD real (no hay forma de comparar
# contenido acá) — se deja documentado como caso a correr en un entorno
# conectado; ver dataservice-isolation.hurl para el patrón de assert real
# ("not contains" el empr_id de la otra empresa).


# ─────────────────────────────────────────────────────────────────
# alm_get_pedido_material — GET /tools/mcp/mcp/alm/pedido/{pema_id}
# ─────────────────────────────────────────────────────────────────

# Caso A: sin X-JWT-Assertion → 503 identity_missing
GET http://{{MI_HOST}}/tools/mcp/mcp/alm/pedido/1
HTTP 503
[Asserts]
jsonpath "$.error" == "identity_missing"

# Caso C: X-JWT-Assertion válido → NO 503
GET http://{{MI_HOST}}/tools/mcp/mcp/alm/pedido/1
X-JWT-Assertion: {{VALID_ASSERTION}}
HTTP *
[Asserts]
status != 503


# ─────────────────────────────────────────────────────────────────
# alm_crear_pedido_materiales — POST /tools/mcp/mcp/alm/pedido
# ─────────────────────────────────────────────────────────────────

# Caso A: sin X-JWT-Assertion → 503 identity_missing. NO debe llegar a
# insertar nada (el fail-closed corta antes de tocar toolsALMAPI).
POST http://{{MI_HOST}}/tools/mcp/mcp/alm/pedido
Content-Type: application/json
{
  "justificacion": "test sin auth",
  "articulos": [{"arti_id": "1", "cantidad": "5", "depo_id": "1"}]
}
HTTP 503
[Asserts]
jsonpath "$.error" == "identity_missing"

# Caso B — aislamiento: el agente manda un empr_id ajeno en el body (999,
# ninguna empresa real de test) además de un X-JWT-Assertion válido de
# empresa 42. La fachada debe IGNORAR el empr_id del body y usar el del
# JWT — no debe fallar de forma distinta a un request sin ese campo
# espurio (si fallara distinto, sería señal de que el body se está
# respetando en vez de pisarlo). Verificación completa (que el pedido
# quedó con empr_id=42 y no 999) requiere inspeccionar la BD real.
POST http://{{MI_HOST}}/tools/mcp/mcp/alm/pedido
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{
  "empr_id": "999",
  "justificacion": "test spoof empr_id",
  "articulos": [{"arti_id": "1", "cantidad": "5", "depo_id": "1"}]
}
HTTP *
[Asserts]
status != 503

# Caso C: X-JWT-Assertion válido, sin spoof → NO 503 (arrancó el flujo
# INSERT header → INSERT detalle → BPM → PUT case_id; el resultado final
# depende de BD/Bonita reales, no evaluados acá)
POST http://{{MI_HOST}}/tools/mcp/mcp/alm/pedido
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{
  "justificacion": "test con auth",
  "articulos": [{"arti_id": "1", "cantidad": "5", "depo_id": "1"}]
}
HTTP *
[Asserts]
status != 503
