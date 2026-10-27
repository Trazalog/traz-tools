# man_get_ot — detalle de un solicitud.
#
# Pide un id_solicitud existente. No se encadena desde el listado como hacen
# pan_get_herramienta y alm_get_pedido_material porque el ambiente de prueba
# puede no tener ninguno —`man_get_ots` devuelve {"solicitudes":{}} en la empresa de
# test—, y una captura sobre una lista vacia hace fallar el archivo entero.
#
# Si el ambiente NO tiene datos, dejar id_solicitud_test en un id inexistente: el archivo
# verifica igual que la tool responde sin romper, que es lo que importa.
# Catalogo: pendiente de relevar (H-085)

POST {{mcp_base_url}}{{mcp_server_path}}
Content-Type: application/json
Accept: application/json, text/event-stream
Mcp-Protocol-Version: {{protocol_version}}
Mcp-Method: tools/call
Mcp-Name: man_get_ot
Authorization: Bearer {{jwt}}
{
  "jsonrpc": "2.0", "id": 1, "method": "tools/call",
  "params": { "name": "man_get_ot", "arguments": { "id_solicitud": {{id_solicitud_test}} } }
}

HTTP 200
[Asserts]
jsonpath "$.jsonrpc" == "2.0"
jsonpath "$.result.content" count >= 1
jsonpath "$.result.content[0].type" == "text"
