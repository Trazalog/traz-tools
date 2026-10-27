# alm_get_pedido_material — detalle de un pedido.
# El pema_id no se fija a mano: se toma del listado.
# Catalogo: pendiente de relevar (H-085)

# ── 1. un pedido real de esta empresa ────────────────────────────────────────
POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: tools/call
Mcp-Name: alm_get_pedidos_materiales
Authorization: Bearer {{jwt}}
{
  "jsonrpc": "2.0", "id": 1, "method": "tools/call",
  "params": { "name": "alm_get_pedidos_materiales", "arguments": {} }
}

HTTP 200
[Captures]
# El listado viaja como JSON dentro del campo `text`: primero se extrae el texto
# y recien despues se busca el id.
pema_id: jsonpath "$.result.content[0].text" regex /"pema_id"\s*:\s*"?(\d+)"?/

# ── 2. su detalle ────────────────────────────────────────────────────────────
POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: tools/call
Mcp-Name: alm_get_pedido_material
Authorization: Bearer {{jwt}}
{
  "jsonrpc": "2.0", "id": 2, "method": "tools/call",
  "params": { "name": "alm_get_pedido_material", "arguments": { "pema_id": {{pema_id}} } }
}

HTTP 200
[Asserts]
jsonpath "$.result.isError" == false
jsonpath "$.result.content[0].type" == "text"
jsonpath "$.result.content[0].text" contains "{{pema_id}}"

# ── 3. un pedido que no existe ───────────────────────────────────────────────
POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: tools/call
Mcp-Name: alm_get_pedido_material
Authorization: Bearer {{jwt}}
{
  "jsonrpc": "2.0", "id": 3, "method": "tools/call",
  "params": { "name": "alm_get_pedido_material", "arguments": { "pema_id": 999999999 } }
}

HTTP *
[Asserts]
status != 500
