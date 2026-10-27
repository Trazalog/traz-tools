# man_get_kpi_disponibilidad — porcentaje de tiempo operativo
# Catalogo: pendiente de relevar (H-085)

POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: tools/call
Mcp-Name: man_get_kpi_disponibilidad
Authorization: Bearer {{jwt}}
{
  "jsonrpc": "2.0", "id": 1, "method": "tools/call",
  "params": { "name": "man_get_kpi_disponibilidad", "arguments": { "fec_inicio": "{{fec_inicio}}", "fec_fin": "{{fec_fin}}" } }
}

HTTP 200
[Asserts]
jsonpath "$.jsonrpc" == "2.0"
jsonpath "$.result.isError" == false
jsonpath "$.result.content" count >= 1
jsonpath "$.result.content[0].type" == "text"
jsonpath "$.result.content[0].text" contains "\"respuesta\""

# Las fechas son obligatorias: sin ellas la tool no puede responder.
POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: tools/call
Mcp-Name: man_get_kpi_disponibilidad
Authorization: Bearer {{jwt}}
{
  "jsonrpc": "2.0", "id": 2, "method": "tools/call",
  "params": { "name": "man_get_kpi_disponibilidad", "arguments": {} }
}

HTTP *
[Asserts]
status != 500
