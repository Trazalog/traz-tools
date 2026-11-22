# AGENTE-CO-04 (ADR-A13) — Recursos de escritura de Tareas para el plan de acción
# (tar_alta_pedido, tar_alta_hito, tar_alta_tarea, tar_baja_pedido, tar_baja_tarea)
#
# PENDIENTE: los recursos esperan la aprobación del PM (anexo A de
# doc/agente/analisis-impacto-plan-accion-kuntur.md). Este archivo NO se corrió
# todavía: no hay un MI de prueba con TARDataService/PRODataService simulados.
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
#   PETR_AJENO   = un petr_id de OTRA empresa
#   HITO_AJENO   = un hito_id de un pedido de OTRA empresa
#
# Ejecutar (terminal local, parado en traz-tools):
#   hurl --variable MI_HOST=localhost:8291 --variable VALID_ASSERTION="$A" \
#        --variable MAQUINA_ASSERTION="$M" --variable PETR_AJENO=1 --variable HITO_AJENO=1 \
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
