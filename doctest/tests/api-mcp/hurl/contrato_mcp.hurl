# Contrato del MCP Server: handshake y catalogo de tools.
# No necesita token: initialize y tools/list no exigen auth en APIM 4.6.0
# (limitacion conocida, no bug — el 401 aparece en el primer tools/call).

# ── initialize ───────────────────────────────────────────────────────────────
POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: initialize
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "{{protocol_version}}",
    "capabilities": {},
    "clientInfo": { "name": "doctest-hurl", "version": "1" }
  }
}

HTTP 200
[Asserts]
jsonpath "$.jsonrpc" == "2.0"
jsonpath "$.result.protocolVersion" == "{{protocol_version}}"
jsonpath "$.result.serverInfo.name" exists
jsonpath "$.result.capabilities.tools" exists

# ── tools/list ───────────────────────────────────────────────────────────────
POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: tools/list
{ "jsonrpc": "2.0", "id": 2, "method": "tools/list" }

HTTP 200
[Asserts]
jsonpath "$.result.tools" count == {{tools_esperadas}}
# Cada tool se publica con nombre, descripcion y esquema de entrada.
jsonpath "$.result.tools[0].name" exists
jsonpath "$.result.tools[0].description" exists
jsonpath "$.result.tools[0].inputSchema" exists
# Las cinco tools que cubre esta suite tienen que estar publicadas.
jsonpath "$.result.tools[?(@.name=='core_get_empresa_actual')]" exists
jsonpath "$.result.tools[?(@.name=='pan_get_herramientas')]" exists
jsonpath "$.result.tools[?(@.name=='pan_get_herramienta')]" exists
jsonpath "$.result.tools[?(@.name=='pan_get_certificaciones')]" exists
jsonpath "$.result.tools[?(@.name=='pan_get_movimientos')]" exists
