# core_get_empresa_actual — devuelve la empresa del token.
# Es la contraparte del selector de empresa del ingreso OAuth (DNATO-UC-009):
# confirma cual quedo elegida. Catalogo: catalogo/mcp/MCP-UC-002.yaml

POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: tools/call
Mcp-Name: core_get_empresa_actual
Authorization: Bearer {{jwt}}
{
  "jsonrpc": "2.0", "id": 1, "method": "tools/call",
  "params": { "name": "core_get_empresa_actual", "arguments": {} }
}

HTTP 200
[Asserts]
jsonpath "$.jsonrpc" == "2.0"
jsonpath "$.result" exists
jsonpath "$.result.content" count >= 1
jsonpath "$.result.content[0].type" == "text"
# Aislamiento: la empresa que devuelve es la del token, no una elegida por parametro.
jsonpath "$.result.content[0].text" contains "{{empr_id_test}}"
