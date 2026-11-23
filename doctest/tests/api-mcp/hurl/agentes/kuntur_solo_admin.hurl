# Caso de uso: AGE-UC-008 (Kuntur no está disponible para quien no es administrador, R1).
# Catálogo: catalogo/age/AGE-UC-008.yaml
# "Administrador" = nivel 1 de Dnato (claim role = "1"), decisión del PM del 2026-11-22.
# Para un no administrador Kuntur NO EXISTE: misma respuesta que un agente inexistente (404),
# para que no se pueda distinguir "no existe" de "no es para vos".

# --- Un usuario común no recibe a Kuntur en la lista -------------------------
GET {{base}}/agentes
Authorization: Bearer {{jwt_usuario}}
HTTP 200
[Asserts]
jsonpath "$.agentes[?(@.clave == 'quirqui')]" exists
jsonpath "$.agentes[?(@.clave == 'kuntur')]" not exists
jsonpath "$.agentes[?(@.clave == 'faustino')]" not exists

# --- Ni puede consultarlo ----------------------------------------------------
POST {{base}}/consulta
Authorization: Bearer {{jwt_usuario}}
Content-Type: application/json
{ "pregunta": "hola", "agente": "kuntur" }
HTTP 404

# --- Igual que un agente que no existe ---------------------------------------
POST {{base}}/consulta
Authorization: Bearer {{jwt_usuario}}
Content-Type: application/json
{ "pregunta": "hola", "agente": "nadie" }
HTTP 404

# --- Ni entrar a sus pantallas de configuración y avisos ---------------------
GET {{base}}/kuntur/configuracion
Authorization: Bearer {{jwt_usuario}}
HTTP 404

GET {{base}}/kuntur/avisos
Authorization: Bearer {{jwt_usuario}}
HTTP 404

# --- El administrador sí lo recibe, sin el prompt ni las herramientas --------
GET {{base}}/agentes
Authorization: Bearer {{jwt_admin}}
HTTP 200
[Asserts]
jsonpath "$.agentes[?(@.clave == 'kuntur')].nombre" contains "Kuntur"
jsonpath "$.agentes[?(@.clave == 'kuntur')].rol" contains "coach"
jsonpath "$.agentes[0].prompt" not exists
jsonpath "$.agentes[0].tools_permitidas" not exists

GET {{base}}/kuntur/configuracion
Authorization: Bearer {{jwt_admin}}
HTTP 200
