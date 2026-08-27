# E9-IDENT-06 — Tests de aislamiento multi-empresa en DataServices
#
# Pre-requisitos:
#   1. WSO2 MI corriendo con ToolsAPIProject deployado
#   2. Base de datos con datos de empresa A (empr_id=42) y empresa B (empr_id=99)
#   3. Equipo id=10 pertenece a empresa A (id_empresa=42)
#   4. Artículo arti_id=5 pertenece a empresa A (empr_id=42)
#   5. empr_id=42 tiene artículos; empr_id=99 NO tiene el artículo id=5
#
# Ejecutar:
#   hurl --variable MI_HOST=localhost:8280 dataservice-isolation.hurl


# ─────────────────────────────────────────────────────────────────
# MANDataService — getEquipoIsolated
# ─────────────────────────────────────────────────────────────────

# Caso 1a: equipo 10 con empresa A → devuelve datos de empresa A
GET http://{{MI_HOST}}/services/MANDataService/mcp/equipo/42/10
HTTP 200
[Asserts]
jsonpath "$.equipo.empr_id" == "42"
jsonpath "$.equipo.id_equipo" == "10"

# Caso 1b: equipo 10 con empresa B → sin resultados (equipo no pertenece a B)
GET http://{{MI_HOST}}/services/MANDataService/mcp/equipo/99/10
HTTP 200
[Asserts]
jsonpath "$.equipo" not exists


# ─────────────────────────────────────────────────────────────────
# MANDataService — getSolicitudServicio (ya tenía filtro, verificación)
# ─────────────────────────────────────────────────────────────────

# Caso 2: OTs de empresa A no incluyen solicitudes de empresa B
GET http://{{MI_HOST}}/services/MANDataService/getSolicitudServicioNoConforme/42
HTTP 200
[Asserts]
jsonpath "$.solicitudes.solicitud[*].id_empresa" not contains "99"


# ─────────────────────────────────────────────────────────────────
# ALMDataService — getArticulos2 (corregido: ya no hardcodeado a empr_id=1)
# ─────────────────────────────────────────────────────────────────

# Caso 3a: empresa A → devuelve artículos de empresa A
GET http://{{MI_HOST}}/services/ALMDataService/articulos/42
HTTP 200
[Asserts]
jsonpath "$.materias.materia" isCollection

# Caso 3b: empresa 2 → devuelve artículos de empresa 2, NO los de empresa 1
# (verifica que el hardcode a empr_id=1 fue eliminado)
GET http://{{MI_HOST}}/services/ALMDataService/articulos/2
HTTP 200
[Asserts]
jsonpath "$.materias.materia[*].empr_id" not contains "1"

# Caso 3c: empresa inexistente → lista vacía (no error, vacío)
GET http://{{MI_HOST}}/services/ALMDataService/articulos/9999
HTTP 200
[Asserts]
jsonpath "$.materias.materia" isEmpty


# ─────────────────────────────────────────────────────────────────
# ALMDataService — getArticulo (corregido: ya no hardcodeado a empr_id=1)
# ─────────────────────────────────────────────────────────────────

# Caso 4a: artículo 5 con empresa A → devuelve el artículo
GET http://{{MI_HOST}}/services/ALMDataService/articulos/obtener/42/5
HTTP 200
[Asserts]
jsonpath "$.articulos.articulo[0].arti_id" == "5"

# Caso 4b: artículo 5 con empresa B → sin resultados (aislamiento funciona)
GET http://{{MI_HOST}}/services/ALMDataService/articulos/obtener/99/5
HTTP 200
[Asserts]
jsonpath "$.articulos.articulo" isEmpty

# Caso 4c: empresa 2 solicitando artículo → NO devuelve datos de empresa 1
# (verifica eliminación del hardcode a empr_id=1)
GET http://{{MI_HOST}}/services/ALMDataService/articulos/obtener/2/5
HTTP 200
[Asserts]
jsonpath "$.articulos.articulo[*].empr_id" not contains "1"
