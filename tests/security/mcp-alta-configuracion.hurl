# AGENTE-CO-09 (ADR-A12) — Herramientas de alta de configuración en toolsMCPAPI
# (core_alta_establecimiento, alm_alta_deposito, core_alta_valor)
#
# Mismo patrón que mcp-facade-alm-tools.hurl: llama al MI DIRECTAMENTE,
# simulando X-JWT-Assertion. Cubre lo que no se puede romper:
#   - sin identidad, 503;
#   - con token de máquina, 403 ANTES de tocar nada (ADR-A10, ADR-A12);
#   - parámetros inválidos, 400 sin llamar al servicio de datos;
#   - un depósito en un establecimiento de OTRA empresa, 400.
# Los casos que graban de verdad (C) necesitan la base de Tools conectada: se
# corren contra un MI de prueba, NUNCA contra el de DEV ni el del PM.
#
# Variables requeridas:
#   MI_HOST           = host:port del MI de prueba (ej: localhost:8291)
#   VALID_ASSERTION   = empresa A: python3 scripts/dev/mint-backend-jwt.py 42 42
#   MAQUINA_ASSERTION = empresa A con token de máquina: el mismo payload con
#                       "token_tipo": "maquina" (ver EmprIdFromHeader.xml)
#   ESTA_AJENO        = un esta_id de OTRA empresa (para el caso del depósito)
#
# Ejecutar (terminal local, parado en traz-tools):
#   hurl --variable MI_HOST=localhost:8291 --variable VALID_ASSERTION="$A" \
#        --variable MAQUINA_ASSERTION="$M" --variable ESTA_AJENO=1 \
#        tests/security/mcp-alta-configuracion.hurl


# ─── Sin identidad → 503 ─────────────────────────────────────────
POST http://{{MI_HOST}}/tools/mcp/mcp/core/establecimiento
Content-Type: application/json
{"nombre": "Planta Norte"}
HTTP 503
[Asserts]
jsonpath "$.error" == "identity_missing"


# ─── Token de máquina → 403, en las tres ─────────────────────────
POST http://{{MI_HOST}}/tools/mcp/mcp/core/establecimiento
X-JWT-Assertion: {{MAQUINA_ASSERTION}}
Content-Type: application/json
{"nombre": "Planta Norte"}
HTTP 403
[Asserts]
jsonpath "$.error" == "forbidden"

POST http://{{MI_HOST}}/tools/mcp/mcp/alm/deposito
X-JWT-Assertion: {{MAQUINA_ASSERTION}}
Content-Type: application/json
{"nombre": "Pañol", "esta_id": "1"}
HTTP 403

POST http://{{MI_HOST}}/tools/mcp/mcp/core/valor
X-JWT-Assertion: {{MAQUINA_ASSERTION}}
Content-Type: application/json
{"lista": "unidades_medida", "valor": "Litro"}
HTTP 403


# ─── Parámetros inválidos → 400 ──────────────────────────────────
POST http://{{MI_HOST}}/tools/mcp/mcp/core/establecimiento
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{"calle": "sin nombre"}
HTTP 400
[Asserts]
jsonpath "$.error" == "parametro_invalido"

POST http://{{MI_HOST}}/tools/mcp/mcp/core/valor
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{"lista": "sectores", "valor": "Planta"}
HTTP 400
[Asserts]
jsonpath "$.message" contains "unidades_medida"


# ─── Depósito en un establecimiento ajeno → 400 ──────────────────
POST http://{{MI_HOST}}/tools/mcp/mcp/alm/deposito
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{"nombre": "Pañol", "esta_id": "{{ESTA_AJENO}}"}
HTTP 400
[Asserts]
jsonpath "$.message" contains "no es de esta empresa"


# ─── C: alta real y que el valor no se repita (base de prueba) ───
POST http://{{MI_HOST}}/tools/mcp/mcp/core/valor
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{"lista": "unidades_medida", "valor": "Prueba Kuntur"}
HTTP 200

POST http://{{MI_HOST}}/tools/mcp/mcp/core/valor
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{"lista": "unidades_medida", "valor": "prueba kuntur"}
HTTP 200
[Asserts]
jsonpath "$.respuesta.existente" == true
