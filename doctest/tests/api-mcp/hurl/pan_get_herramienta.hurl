# pan_get_herramienta — detalle de una herramienta.
# El herr_id no se fija a mano: se toma del listado, asi la suite no depende
# de un id que puede no existir en el ambiente.
# Catalogo: catalogo/mcp/MCP-UC-001.yaml

# ── 1. conseguir un herr_id real del panol de esta empresa ───────────────────
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
[Captures]
# El listado viaja como JSON dentro del campo `text`, asi que en el cuerpo crudo
# las comillas van escapadas: primero se extrae el texto con jsonpath y recien
# despues se busca el id.
herr_id: jsonpath "$.result.content[0].text" regex /"herr_id"\s*:\s*"?(\d+)"?/

# ── 2. pedir su detalle ──────────────────────────────────────────────────────
POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: tools/call
Mcp-Name: pan_get_herramienta
Authorization: Bearer {{jwt}}
{
  "jsonrpc": "2.0", "id": 2, "method": "tools/call",
  "params": { "name": "pan_get_herramienta", "arguments": { "herr_id": {{herr_id}} } }
}

HTTP 200
[Asserts]
jsonpath "$.result.content[0].type" == "text"
jsonpath "$.result.content[0].text" contains "{{herr_id}}"

# ── 3. una herramienta que no existe ─────────────────────────────────────────
# No tiene que romper: el protocolo responde, con contenido vacio o un error de tool.
POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: tools/call
Mcp-Name: pan_get_herramienta
Authorization: Bearer {{jwt}}
{
  "jsonrpc": "2.0", "id": 3, "method": "tools/call",
  "params": { "name": "pan_get_herramienta", "arguments": { "herr_id": 999999999 } }
}

HTTP *
[Asserts]
status != 500
