# pan_get_herramientas — listado del panol de la empresa del token.
# Catalogo: catalogo/mcp/MCP-UC-001.yaml

# ── sin filtros ──────────────────────────────────────────────────────────────
POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: tools/call
Mcp-Name: pan_get_herramientas
Authorization: Bearer {{jwt}}
{
  "jsonrpc": "2.0", "id": 1, "method": "tools/call",
  "params": { "name": "pan_get_herramientas", "arguments": {} }
}

HTTP 200
[Asserts]
jsonpath "$.jsonrpc" == "2.0"
jsonpath "$.result.content" count >= 1
jsonpath "$.result.content[0].type" == "text"
# El empr_id NO viaja como parametro (ADR-009): lo resuelve el MI desde
# X-JWT-Assertion. Que devuelva datos con argumentos vacios es parte del contrato.
jsonpath "$.result.content[0].text" exists

# ── filtrada por certificacion proxima a vencer ──────────────────────────────
POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: tools/call
Mcp-Name: pan_get_herramientas
Authorization: Bearer {{jwt}}
{
  "jsonrpc": "2.0", "id": 2, "method": "tools/call",
  "params": {
    "name": "pan_get_herramientas",
    "arguments": { "cert_vencer": true, "dias_vencimiento": 30 }
  }
}

HTTP 200
[Asserts]
jsonpath "$.result.content[0].type" == "text"
