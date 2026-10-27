# man_create_ot — CREA UNA SOLICITUD REAL e instancia un proceso en Bonita.
# Ver LEEME.md de este directorio. Nunca contra produccion.

POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: tools/call
Mcp-Name: man_create_ot
Authorization: Bearer {{jwt}}
{
  "jsonrpc": "2.0", "id": 1, "method": "tools/call",
  "params": {
    "name": "man_create_ot",
    "arguments": {
      "equipo_id": "{{equipo_id_test}}",
      "descripcion": "TEST doctest — solicitud de prueba automatica, se puede rechazar"
    }
  }
}

HTTP 200
[Asserts]
jsonpath "$.result.isError" == false
jsonpath "$.result.content[0].type" == "text"
jsonpath "$.jsonrpc" == "2.0"

# ── la solicitud tiene que aparecer en el listado ────────────────────────────
POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: tools/call
Mcp-Name: man_get_ots
Authorization: Bearer {{jwt}}
{
  "jsonrpc": "2.0", "id": 2, "method": "tools/call",
  "params": { "name": "man_get_ots", "arguments": {} }
}

HTTP 200
[Asserts]
jsonpath "$.result.content[0].text" contains "TEST doctest"
