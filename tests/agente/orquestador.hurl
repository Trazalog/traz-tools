# =============================================================================
# Tests de integracion del orquestador del Agente Minero
# =============================================================================
# Verifican el contrato HTTP que consume el chat de Tools: identidad, formato de
# respuesta y aislamiento. No dependen de OpenRouter -- las consultas pueden
# fallar por falta de API key y el test igual valida lo que le importa: que el
# servicio responda con la forma correcta y no filtre datos.
#
# Correr con el orquestador levantado (./agente/dev.sh):
#
#   hurl --variable base=http://127.0.0.1:8099 \
#        --variable jwt=<token> --test tests/agente/orquestador.hurl
#
# El token de prueba se arma con scripts/dev/mint-dnato-jwt.py, o a mano: para
# estos tests alcanza un JWT sin firma valida, porque el orquestador solo lee
# los claims (la firma la valida el APIM antes, ADR-009).
# =============================================================================

# --- El servicio esta vivo y dice como esta configurado ---------------------
GET {{base}}/salud
HTTP 200
[Asserts]
jsonpath "$.estado" exists
jsonpath "$.modelo" exists
jsonpath "$.mcp_modo" isString
# Los bloques del prompt sin definir tienen que ser visibles: es lo que evita
# salir a produccion con los textos de ejemplo puestos.
jsonpath "$.prompt_bloques_sin_definir" exists


# --- Sin token no se responde nada ------------------------------------------
POST {{base}}/consulta
Content-Type: application/json
{ "pregunta": "hola" }
HTTP 401


# --- Un token con formato invalido tampoco --------------------------------
POST {{base}}/consulta
Authorization: Bearer esto-no-es-un-jwt
Content-Type: application/json
{ "pregunta": "hola" }
HTTP 401


# --- Un token sin empr_id se rechaza con 403, no con 500 -------------------
# eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJ4In0 = {"alg":"RS256"}.{"sub":"x"}
POST {{base}}/consulta
Authorization: Bearer eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJ4In0.firma
Content-Type: application/json
{ "pregunta": "hola" }
HTTP 403


# --- Una pregunta vacia se rechaza antes de gastar un token ----------------
POST {{base}}/consulta
Authorization: Bearer {{jwt}}
Content-Type: application/json
{ "pregunta": "" }
HTTP 422


# --- El contrato de una consulta -------------------------------------------
# Puede fallar el LLM y el status sigue siendo 200: el usuario recibe un
# mensaje entendible en vez de un error tecnico. Lo que se verifica aca es la
# FORMA de la respuesta, que es de lo que depende la UI del chat.
POST {{base}}/consulta
Authorization: Bearer {{jwt}}
Content-Type: application/json
{ "pregunta": "¿Cada cuánto se cambian las muelas de una chancadora?" }
HTTP 200
[Asserts]
jsonpath "$.interaccion_id" matches /^[0-9a-f-]{36}$/
jsonpath "$.respuesta" isString
jsonpath "$.respuesta" not == ""
jsonpath "$.fragmentos" isCollection
jsonpath "$.tools_llamadas" isCollection
jsonpath "$.latencia_ms" isInteger
[Captures]
interaccion: jsonpath "$.interaccion_id"


# --- Calificar la respuesta anterior ---------------------------------------
POST {{base}}/feedback
Authorization: Bearer {{jwt}}
Content-Type: application/json
{ "interaccion_id": "{{interaccion}}", "util": true }
HTTP 200
[Asserts]
jsonpath "$.feedback_id" isInteger


# --- Cambiar de opinion actualiza, no duplica ------------------------------
POST {{base}}/feedback
Authorization: Bearer {{jwt}}
Content-Type: application/json
{ "interaccion_id": "{{interaccion}}", "util": false, "motivo": "incompleta", "comentario": "faltaba el torque" }
HTTP 200


# --- AISLAMIENTO: no se puede calificar la interaccion de otra empresa -----
# Mismo interaccion_id, token de OTRA empresa (empr_id 900999). Tiene que dar
# 404: para esa empresa, esa interaccion no existe.
# {"alg":"RS256"}.{"sub":"otro","empr_id":"900999"}
POST {{base}}/feedback
Authorization: Bearer eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJvdHJvIiwiZW1wcl9pZCI6IjkwMDk5OSJ9.firma
Content-Type: application/json
{ "interaccion_id": "{{interaccion}}", "util": true }
HTTP 404


# --- El panel de feedback responde con la forma que espera la vista -------
GET {{base}}/admin/feedback
Authorization: Bearer {{jwt}}
HTTP 200
[Asserts]
jsonpath "$.resumen" isCollection
jsonpath "$.detalle" isCollection
