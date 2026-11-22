# Caso de uso: AGE-UC-007 (calificar una respuesta de Quirqui). Catálogo: catalogo/age/AGE-UC-007.yaml
# El panel manda 👍/👎 y, con 👎, un motivo rápido y un comentario opcionales:
#   "No era eso" -> no_entendio, "Dato equivocado" -> respuesta_incorrecta, "No se entiende" -> otro.

# --- Una respuesta para calificar --------------------------------------------
POST {{base}}/consulta
Authorization: Bearer {{jwt_usuario}}
Content-Type: application/json
{ "pregunta": "¿Qué se hace en esta pantalla?", "pantalla": "traz-comp-almacenes/Articulo" }
HTTP 200
[Captures]
interaccion: jsonpath "$.interaccion_id"

# --- 👍 ---------------------------------------------------------------------
POST {{base}}/feedback
Authorization: Bearer {{jwt_usuario}}
Content-Type: application/json
{ "interaccion_id": "{{interaccion}}", "util": true }
HTTP 200
[Asserts]
jsonpath "$.feedback_id" isInteger

# --- Cambia de opinión: 👎 con motivo rápido y comentario ---------------------
POST {{base}}/feedback
Authorization: Bearer {{jwt_usuario}}
Content-Type: application/json
{ "interaccion_id": "{{interaccion}}", "util": false, "motivo": "respuesta_incorrecta", "comentario": "el stock no coincide" }
HTTP 200
[Asserts]
jsonpath "$.feedback_id" isInteger

# --- "No se entiende": motivo otro, con el texto del botón como comentario ---
POST {{base}}/feedback
Authorization: Bearer {{jwt_usuario}}
Content-Type: application/json
{ "interaccion_id": "{{interaccion}}", "util": false, "motivo": "otro", "comentario": "No se entiende" }
HTTP 200

# --- Un motivo que no está en la lista no se graba ---------------------------
POST {{base}}/feedback
Authorization: Bearer {{jwt_usuario}}
Content-Type: application/json
{ "interaccion_id": "{{interaccion}}", "util": false, "motivo": "inventado" }
HTTP 422

# --- Aislamiento: otra empresa no puede calificar esa respuesta --------------
POST {{base}}/feedback
Authorization: Bearer {{jwt_otra}}
Content-Type: application/json
{ "interaccion_id": "{{interaccion}}", "util": true }
HTTP 404
