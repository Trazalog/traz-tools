# alm_crear_pedido_materiales — CREA UN PEDIDO REAL e instancia un proceso en Bonita.
# Ver LEEME.md de este directorio. Nunca contra produccion.

POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: tools/call
Mcp-Name: alm_crear_pedido_materiales
Authorization: Bearer {{jwt}}
{
  "jsonrpc": "2.0", "id": 1, "method": "tools/call",
  "params": {
    "name": "alm_crear_pedido_materiales",
    "arguments": {
      "justificacion": "TEST doctest — pedido de prueba automatica, se puede rechazar",
      "articulos": [
        { "arti_id": "{{arti_id_test}}", "cantidad": "1", "depo_id": "{{depo_id_test}}" }
      ]
    }
  }
}

HTTP 200
[Asserts]
jsonpath "$.result.isError" == false
jsonpath "$.result.content[0].type" == "text"
# El status en el cable tiene que ser 200, no 202: con 202 el cliente MCP descarta
# la respuesta y el usuario reintenta, creando un pedido por intento.
jsonpath "$.jsonrpc" == "2.0"

# ── el pedido tiene que aparecer en el listado ───────────────────────────────
POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: tools/call
Mcp-Name: alm_get_pedidos_materiales
Authorization: Bearer {{jwt}}
{
  "jsonrpc": "2.0", "id": 2, "method": "tools/call",
  "params": { "name": "alm_get_pedidos_materiales", "arguments": {} }
}

HTTP 200
[Asserts]
jsonpath "$.result.content[0].text" contains "TEST doctest"
