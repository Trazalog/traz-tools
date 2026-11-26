# AGENTE-CO-04 (ADR-A13) — Recursos de escritura de Tareas para el plan de acción
# (tar_alta_pedido, tar_alta_hito, tar_alta_tarea, tar_baja_pedido, tar_baja_tarea)
#
# PENDIENTE: los recursos esperan la aprobación del PM (anexo A de
# doc/historial/agente/analisis-impacto-plan-accion-kuntur.md). Corrido 21/21 el 2026-11-22
# en una copia del MI desconectada de DEV, con scripts/dev/simulador-plan-ds.py.
#
# Mismo patrón que mcp-alta-configuracion.hurl: llama al MI DIRECTAMENTE,
# simulando X-JWT-Assertion. Cubre lo que no se puede romper:
#   - sin identidad, 503; con token de máquina, 403 ANTES de tocar nada;
#   - parámetros inválidos, 400 sin llamar al servicio de datos;
#   - un hito en un pedido de OTRA empresa (o que no es del Proceso Estándar), 400;
#   - una tarea en un hito de OTRA empresa, 400.
# Los casos que graban (C) se corren contra un MI de prueba, NUNCA contra DEV ni el del PM.
#
# Variables requeridas:
#   MI_HOST, VALID_ASSERTION, MAQUINA_ASSERTION   (como en mcp-alta-configuracion.hurl)
#   PETR_AJENO             = un petr_id de OTRA empresa (simulador: 170)
#   HITO_AJENO             = un hito_id de un pedido de OTRA empresa (simulador: 909)
#   PETR_OTRO_PROCESO      = un pedido de la empresa que NO es del Proceso Estándar (simulador: 171)
#   SIN_CLIENTES_ASSERTION = una empresa sin clientes activos (simulador: mint-backend-jwt.py 77 77)
#
# Sin base: scripts/dev/simulador-plan-ds.py imita lo que llaman estos recursos
# (empresa 42 con cliente 5, tipo General y establecimiento 3). La copia del MI
# apunta a él en registry/config/tools/apiconfig.xml
# (dataservices_url = http://127.0.0.1:18778/services).
#
# Ejecutar (terminal local, parado en traz-tools):
#   hurl --test --variable MI_HOST=localhost:8301 --variable VALID_ASSERTION="$A" \
#        --variable MAQUINA_ASSERTION="$M" --variable SIN_CLIENTES_ASSERTION="$N" \
#        --variable PETR_AJENO=170 --variable HITO_AJENO=909 --variable PETR_OTRO_PROCESO=171 \
#        tests/security/mcp-plan-accion.hurl


# ─── Sin identidad → 503 ─────────────────────────────────────────
POST http://{{MI_HOST}}/tools/mcp/mcp/tar/pedido
Content-Type: application/json
{"codigo": "K-261123-ABC123", "nombre": "Plan", "semanas": 2, "fec_inicio": "2026-11-23", "fec_entrega": "2026-12-07"}
HTTP 503


# ─── Token de máquina → 403, en las cinco ────────────────────────
POST http://{{MI_HOST}}/tools/mcp/mcp/tar/pedido
X-JWT-Assertion: {{MAQUINA_ASSERTION}}
Content-Type: application/json
{"codigo": "K-261123-ABC123", "nombre": "Plan", "semanas": 2, "fec_inicio": "2026-11-23", "fec_entrega": "2026-12-07"}
HTTP 403

POST http://{{MI_HOST}}/tools/mcp/mcp/tar/hito
X-JWT-Assertion: {{MAQUINA_ASSERTION}}
Content-Type: application/json
{"petr_id": "1", "numero": "H01", "descripcion": "Etapa", "fec_inicio": "2026-11-23", "semanas": 1}
HTTP 403

POST http://{{MI_HOST}}/tools/mcp/mcp/tar/tarea
X-JWT-Assertion: {{MAQUINA_ASSERTION}}
Content-Type: application/json
{"hito_id": "1", "nombre": "Tarea"}
HTTP 403

DELETE http://{{MI_HOST}}/tools/mcp/mcp/tar/pedido
X-JWT-Assertion: {{MAQUINA_ASSERTION}}
Content-Type: application/json
{"petr_id": "1"}
HTTP 403

DELETE http://{{MI_HOST}}/tools/mcp/mcp/tar/tarea
X-JWT-Assertion: {{MAQUINA_ASSERTION}}
Content-Type: application/json
{"tapl_id": "1"}
HTTP 403


# ─── Parámetros inválidos → 400 ──────────────────────────────────
POST http://{{MI_HOST}}/tools/mcp/mcp/tar/pedido
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{"codigo": "x", "nombre": "", "semanas": 99, "fec_inicio": "mañana", "fec_entrega": "2026-12-07"}
HTTP 400
[Asserts]
jsonpath "$.error" == "parametro_invalido"

POST http://{{MI_HOST}}/tools/mcp/mcp/tar/tarea
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{"hito_id": "abc", "nombre": "Tarea"}
HTTP 400


# ─── Otra empresa → 400 ──────────────────────────────────────────
POST http://{{MI_HOST}}/tools/mcp/mcp/tar/hito
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{"petr_id": "{{PETR_AJENO}}", "numero": "H01", "descripcion": "Etapa", "fec_inicio": "2026-11-23", "semanas": 1}
HTTP 400
[Asserts]
jsonpath "$.message" contains "no es de esta empresa"

POST http://{{MI_HOST}}/tools/mcp/mcp/tar/tarea
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{"hito_id": "{{HITO_AJENO}}", "nombre": "Tarea"}
HTTP 400
[Asserts]
jsonpath "$.message" contains "no es de esta empresa"


# ─── Un pedido de la MISMA empresa que no es del Proceso Estándar → 400 ───
# (por ejemplo, un proceso propio de un cliente como el de Yudica: Kuntur nunca lo usa)
POST http://{{MI_HOST}}/tools/mcp/mcp/tar/hito
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{"petr_id": "{{PETR_OTRO_PROCESO}}", "numero": "H01", "descripcion": "Etapa", "fec_inicio": "2026-11-23", "semanas": 1}
HTTP 400
[Asserts]
jsonpath "$.message" contains "Proceso Estandar"


# ─── Una empresa sin clientes activos → 400 con un mensaje que se entiende ───
POST http://{{MI_HOST}}/tools/mcp/mcp/tar/pedido
X-JWT-Assertion: {{SIN_CLIENTES_ASSERTION}}
Content-Type: application/json
{"codigo": "K-261123-SINCLI", "nombre": "Plan", "semanas": 2, "fec_inicio": "2026-11-23", "fec_entrega": "2026-12-07"}
HTTP 400
[Asserts]
jsonpath "$.message" contains "clientes activos"


# ─── C: el recorrido completo que hace el motor al tocar "Aceptar" ───
# Solo contra un MI de prueba con servicios simulados (scripts/dev/simulador-plan-ds.py).
POST http://{{MI_HOST}}/tools/mcp/mcp/tar/pedido
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{"codigo": "K-261123-ABC123", "nombre": "Recuperar disponibilidad", "descripcion": "Plan de Kuntur", "semanas": 4, "fec_inicio": "2026-11-23", "fec_entrega": "2026-12-21"}
HTTP 200
[Captures]
petr_id: jsonpath "$.respuesta.petr_id"
[Asserts]
jsonpath "$.respuesta.petr_id" matches "^[0-9]+$"

POST http://{{MI_HOST}}/tools/mcp/mcp/tar/hito
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{"petr_id": "{{petr_id}}", "numero": "H01", "descripcion": "Ponerse al día con los preventivos", "fec_inicio": "2026-11-23", "semanas": 2}
HTTP 200
[Captures]
hito_id: jsonpath "$.respuesta.hito_id"
[Asserts]
jsonpath "$.respuesta.hito_id" matches "^[0-9]+$"
jsonpath "$.respuesta.nro" == "1"

POST http://{{MI_HOST}}/tools/mcp/mcp/tar/tarea
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{"hito_id": "{{hito_id}}", "nombre": "Hacer los preventivos atrasados", "descripcion": "Responsable sugerido: jefe de taller"}
HTTP 200
[Captures]
tapl_id: jsonpath "$.respuesta.tapl_id"
[Asserts]
jsonpath "$.respuesta.tapl_id" matches "^[0-9]+$"
jsonpath "$.respuesta.hito_id" == "{{hito_id}}"


# ─── D: errores del servicio de datos → 502 enseguida, sin dejar colgado al motor ───
POST http://{{MI_HOST}}/tools/mcp/mcp/tar/pedido
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{"codigo": "K-261123-ERR001", "nombre": "Plan", "descripcion": "Provocar error", "semanas": 2, "fec_inicio": "2026-11-23", "fec_entrega": "2026-12-07"}
HTTP 502
[Asserts]
jsonpath "$.error" == "servicio_de_datos"
duration < 5000

POST http://{{MI_HOST}}/tools/mcp/mcp/tar/tarea
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{"hito_id": "{{hito_id}}", "nombre": "Provocar error"}
HTTP 502
[Asserts]
jsonpath "$.error" == "servicio_de_datos"
duration < 5000

# Si falla el vínculo de la tarea con el hito, la tarea recién creada se da de baja (todo o nada).
POST http://{{MI_HOST}}/tools/mcp/mcp/tar/tarea
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{"hito_id": "{{hito_id}}", "nombre": "Falla origen"}
HTTP 502
[Asserts]
jsonpath "$.message" contains "dada de baja"
duration < 5000


# ─── Deshacer: bajas de la tarea y del pedido creados ───
DELETE http://{{MI_HOST}}/tools/mcp/mcp/tar/tarea
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{"tapl_id": "{{tapl_id}}"}
HTTP 200
[Asserts]
jsonpath "$.respuesta.baja" == true

DELETE http://{{MI_HOST}}/tools/mcp/mcp/tar/pedido
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{"petr_id": "{{petr_id}}"}
HTTP 200
[Asserts]
jsonpath "$.respuesta.baja" == true

DELETE http://{{MI_HOST}}/tools/mcp/mcp/tar/pedido
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{"petr_id": "abc"}
HTTP 400
