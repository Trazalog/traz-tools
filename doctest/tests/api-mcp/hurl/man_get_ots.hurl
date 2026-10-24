# man_get_ots — ordenes y solicitudes de trabajo
# Catalogo: pendiente de relevar (H-085)

POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: tools/call
Mcp-Name: man_get_ots
Authorization: Bearer {{jwt}}
{
  "jsonrpc": "2.0", "id": 1, "method": "tools/call",
  "params": { "name": "man_get_ots", "arguments": {} }
}

HTTP 200
[Asserts]
jsonpath "$.jsonrpc" == "2.0"
jsonpath "$.result.isError" == false
jsonpath "$.result.content" count >= 1
jsonpath "$.result.content[0].type" == "text"
jsonpath "$.result.content[0].text" contains "\"solicitudes\""
