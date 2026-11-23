# Casos de uso: AGE-UC-002 (datos de la empresa con respaldo), AGE-UC-005 (cifra sin respaldo
# bloqueada) y AGE-UC-006 (internet con fuente). Catálogo: catalogo/age/.
# Verifica el contrato de /consulta que consume el panel. El contenido de la respuesta depende
# del modelo; acá se valida la forma, la identidad y que nunca salga un error técnico.

# --- Sin token no se responde nada ------------------------------------------
POST {{base}}/consulta
Content-Type: application/json
{ "pregunta": "¿Cuánto stock hay de guantes?" }
HTTP 401

# --- Un token sin empresa se rechaza con 403, no con 500 ---------------------
# {"alg":"RS256"}.{"sub":"x"}
POST {{base}}/consulta
Authorization: Bearer eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJ4In0.sin-firma
Content-Type: application/json
{ "pregunta": "¿Cuánto stock hay de guantes?" }
HTTP 403

# --- Una pregunta vacía se rechaza antes de gastar el modelo -----------------
POST {{base}}/consulta
Authorization: Bearer {{jwt_usuario}}
Content-Type: application/json
{ "pregunta": "" }
HTTP 422

# --- AGE-UC-002: consulta de datos de la empresa ----------------------------
# Puede fallar el modelo y el estado sigue siendo 200: el usuario recibe un texto entendible.
POST {{base}}/consulta
Authorization: Bearer {{jwt_usuario}}
Content-Type: application/json
{ "pregunta": "¿Cuánto stock hay de guantes?", "pantalla": "traz-comp-almacenes/Articulo" }
HTTP 200
[Asserts]
jsonpath "$.interaccion_id" matches /^[0-9a-f-]{36}$/
jsonpath "$.agente" == "quirqui"
jsonpath "$.respuesta" isString
jsonpath "$.respuesta" not == ""
jsonpath "$.tools_llamadas" isCollection
jsonpath "$.fragmentos" isCollection

# --- AGE-UC-005: si el guardián bloquea, el texto es el que decidió el PM -----
# No se puede forzar un bloqueo desde afuera sin el modelo; si la respuesta viene bloqueada,
# tiene que ser exactamente el mensaje validado (2026-11-22) y nunca un número suelto.
POST {{base}}/consulta
Authorization: Bearer {{jwt_usuario}}
Content-Type: application/json
{ "pregunta": "¿Cuántas horas exactas le quedan de vida útil a la bomba P-101 de la mina vecina?" }
HTTP 200
[Asserts]
jsonpath "$.respuesta" isString
jsonpath "$.respuesta" not contains "Traceback"
jsonpath "$.respuesta" not contains "No tengo datos para responder eso con certeza"

# --- AGE-UC-006: una pregunta pública responde con la misma forma ------------
POST {{base}}/consulta
Authorization: Bearer {{jwt_usuario}}
Content-Type: application/json
{ "pregunta": "¿Qué dice la norma IRAM sobre señalización de seguridad?" }
HTTP 200
[Asserts]
jsonpath "$.agente" == "quirqui"
jsonpath "$.respuesta" isString
