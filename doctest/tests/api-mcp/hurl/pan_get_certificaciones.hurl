# pan_get_certificaciones — certificaciones y sus vencimientos.
# Catalogo: catalogo/mcp/MCP-UC-001.yaml

POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: tools/call
Mcp-Name: pan_get_certificaciones
Authorization: Bearer {{jwt}}
{
  "jsonrpc": "2.0", "id": 1, "method": "tools/call",
  "params": { "name": "pan_get_certificaciones", "arguments": {} }
}

HTTP 200
[Asserts]
jsonpath "$.jsonrpc" == "2.0"
jsonpath "$.result.content" count >= 1
jsonpath "$.result.content[0].type" == "text"
