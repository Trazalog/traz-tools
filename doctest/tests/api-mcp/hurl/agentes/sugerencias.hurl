# Caso de uso: AGE-UC-003 (ver o descartar el siguiente paso que propone Quirqui).
# Catálogo: catalogo/age/AGE-UC-003.yaml
# Valores validados por el PM (2026-11-22): máximo 3 propuestas, certificaciones a 30 días,
# una descartada no se repite por 7 días. Las propuestas las arman reglas sobre las tools.

# --- La pantalla tiene que tener forma de ruta de Tools ----------------------
POST {{base}}/sugerencias
Authorization: Bearer {{jwt_usuario}}
Content-Type: application/json
{ "pantalla": "<script>alert(1)</script>" }
HTTP 422

# --- Forma de la respuesta y tope de 3 ---------------------------------------
POST {{base}}/sugerencias
Authorization: Bearer {{jwt_usuario}}
Content-Type: application/json
{ "pantalla": "traz-comp-almacenes/Articulo" }
HTTP 200
[Asserts]
jsonpath "$.propuestas" isCollection
jsonpath "$.propuestas" count <= 3

# --- Responder una propuesta que no existe para este usuario -----------------
POST {{base}}/sugerencias/respuesta
Authorization: Bearer {{jwt_usuario}}
Content-Type: application/json
{ "propuesta_id": 999999999, "estado": "descartada" }
HTTP 404

# --- Un estado que no es aceptada ni descartada se rechaza -------------------
POST {{base}}/sugerencias/respuesta
Authorization: Bearer {{jwt_usuario}}
Content-Type: application/json
{ "propuesta_id": 1, "estado": "borrada" }
HTTP 422
