# Errores de autorizacion del gateway. No necesita token: justamente prueba su ausencia.

# ── tools/call sin token ─────────────────────────────────────────────────────
# Es el primer punto del protocolo que SI exige credenciales.
POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: tools/call
Mcp-Name: core_get_empresa_actual
{
  "jsonrpc": "2.0", "id": 1, "method": "tools/call",
  "params": { "name": "core_get_empresa_actual", "arguments": {} }
}

HTTP 401
[Asserts]
jsonpath "$.code" == "900902"
jsonpath "$.message" == "Missing Credentials"

# ── tools/call con un token invalido ─────────────────────────────────────────
POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: tools/call
Mcp-Name: core_get_empresa_actual
Authorization: Bearer no-es-un-jwt
{
  "jsonrpc": "2.0", "id": 2, "method": "tools/call",
  "params": { "name": "core_get_empresa_actual", "arguments": {} }
}

HTTP 401
[Asserts]
jsonpath "$.code" exists

# ── tool inexistente, con token valido ───────────────────────────────────────
# Pasa la autorizacion y falla en el ruteo: el error tiene que ser del protocolo,
# no un 500 del gateway.
POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: tools/call
Mcp-Name: tool_que_no_existe
Authorization: Bearer {{jwt}}
{
  "jsonrpc": "2.0", "id": 3, "method": "tools/call",
  "params": { "name": "tool_que_no_existe", "arguments": {} }
}

HTTP *
[Asserts]
status != 500
