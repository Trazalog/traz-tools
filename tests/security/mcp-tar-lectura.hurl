# AGENTE-TAR-01 — Lectura del módulo de Tareas en toolsMCPAPI
# (tar_get_pedidos, tar_get_pedido, tar_get_tareas, tar_get_atrasadas)
#
# Mismo patrón que mcp-alta-configuracion.hurl: llama al MI DIRECTAMENTE,
# simulando X-JWT-Assertion. Cubre lo que no se puede romper:
#   - sin identidad, 503;
#   - la empresa sale del token: la 42 no ve el pedido 170 de la 99 (404) ni sus tareas;
#   - parámetros inválidos, 400 sin llamar al servicio de datos;
#   - por defecto no vienen los pedidos finalizados;
#   - un error del servicio de datos devuelve 502 enseguida (no deja al cliente colgado).
# Se corre contra una copia del MI que apunta al simulador, NUNCA contra el de DEV ni el del PM.
#
# Variables requeridas:
#   MI_HOST         = host:port de la copia del MI (ej: localhost:8311)
#   EMPRESA_42      = python3 scripts/dev/mint-backend-jwt.py 42 42
#   EMPRESA_99      = python3 scripts/dev/mint-backend-jwt.py 99 99
#
# Sin base: scripts/dev/simulador-tar-ds.py imita PRODataService y TARDataService
# (empresa 42: pedidos 17 en curso y 18 finalizado; empresa 99: pedido 170).
# La copia del MI apunta a él en registry/config/tools/apiconfig.xml
# (dataservices_url = http://127.0.0.1:18777/services).
#
# Ejecutar (terminal local, parado en traz-tools):
#   hurl --test --variable MI_HOST=localhost:8311 \
#        --variable EMPRESA_42="$(python3 scripts/dev/mint-backend-jwt.py 42 42)" \
#        --variable EMPRESA_99="$(python3 scripts/dev/mint-backend-jwt.py 99 99)" \
#        tests/security/mcp-tar-lectura.hurl


# ─── Sin identidad → 503 ─────────────────────────────────────────
GET http://{{MI_HOST}}/tools/mcp/mcp/tar/pedidos
HTTP 503
[Asserts]
jsonpath "$.error" == "identity_missing"


# ─── tar_get_pedidos: sin finalizados por defecto ────────────────
GET http://{{MI_HOST}}/tools/mcp/mcp/tar/pedidos
X-JWT-Assertion: {{EMPRESA_42}}
HTTP 200
[Asserts]
jsonpath "$.total" == 1
jsonpath "$.pedidos.pedido[0].petr_id" == "17"
jsonpath "$.pedidos.pedido[0].estado" == "proc en curso"
jsonpath "$.incluye_finalizados" == false

GET http://{{MI_HOST}}/tools/mcp/mcp/tar/pedidos?todos=true
X-JWT-Assertion: {{EMPRESA_42}}
HTTP 200
[Asserts]
jsonpath "$.total" == 2

# Otra empresa ve solo lo suyo
GET http://{{MI_HOST}}/tools/mcp/mcp/tar/pedidos
X-JWT-Assertion: {{EMPRESA_99}}
HTTP 200
[Asserts]
jsonpath "$.total" == 1
jsonpath "$.pedidos.pedido[0].petr_id" == "170"

GET http://{{MI_HOST}}/tools/mcp/mcp/tar/pedidos?todos=quizas
X-JWT-Assertion: {{EMPRESA_42}}
HTTP 400
[Asserts]
jsonpath "$.error" == "parametro_invalido"


# ─── tar_get_pedido ──────────────────────────────────────────────
GET http://{{MI_HOST}}/tools/mcp/mcp/tar/pedido/17
X-JWT-Assertion: {{EMPRESA_42}}
HTTP 200
[Asserts]
jsonpath "$.pedido.petr_id" == "17"
jsonpath "$.total_hitos" == 2
jsonpath "$.total_tareas" == 3
jsonpath "$.hitos[0].tareas[0].responsable" == "sin asignar"

# El pedido 170 es de la empresa 99: para la 42 no existe
GET http://{{MI_HOST}}/tools/mcp/mcp/tar/pedido/170
X-JWT-Assertion: {{EMPRESA_42}}
HTTP 404
[Asserts]
jsonpath "$.error" == "no_encontrado"

GET http://{{MI_HOST}}/tools/mcp/mcp/tar/pedido/abc
X-JWT-Assertion: {{EMPRESA_42}}
HTTP 400


# ─── tar_get_tareas ──────────────────────────────────────────────
GET http://{{MI_HOST}}/tools/mcp/mcp/tar/tareas
X-JWT-Assertion: {{EMPRESA_42}}
HTTP 200
[Asserts]
jsonpath "$.total" == 3
jsonpath "$.sin_responsable" == 1

GET http://{{MI_HOST}}/tools/mcp/mcp/tar/tareas?hito_id=3&estado=iniciada
X-JWT-Assertion: {{EMPRESA_42}}
HTTP 200
[Asserts]
jsonpath "$.total" == 1
jsonpath "$.tareas.tarea[0].tapl_id" == "11"

# El hito 9 es de la empresa 99: para la 42 viene vacío
GET http://{{MI_HOST}}/tools/mcp/mcp/tar/tareas?hito_id=9
X-JWT-Assertion: {{EMPRESA_42}}
HTTP 200
[Asserts]
jsonpath "$.total" == 0

GET http://{{MI_HOST}}/tools/mcp/mcp/tar/tareas?hito_id=3x
X-JWT-Assertion: {{EMPRESA_42}}
HTTP 400


# ─── tar_get_atrasadas ───────────────────────────────────────────
GET http://{{MI_HOST}}/tools/mcp/mcp/tar/atrasadas
X-JWT-Assertion: {{EMPRESA_42}}
HTTP 200
[Asserts]
jsonpath "$.total" == 1
jsonpath "$.atrasadas.tarea[0].tapl_id" == "11"
jsonpath "$.atrasadas.tarea[0].dias_atraso" >= 2


# ─── Error del servicio de datos → 502 enseguida ─────────────────
GET http://{{MI_HOST}}/tools/mcp/mcp/tar/pedidos?buscar=Provocar%20error
X-JWT-Assertion: {{EMPRESA_42}}
HTTP 502
[Asserts]
jsonpath "$.error" == "servicio_de_datos"
duration < 5000
