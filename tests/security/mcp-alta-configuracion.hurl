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
#   ESTA_PROPIO       = un esta_id de la empresa A (alta de depósito que sí se crea)
#   SIN_SIMULADOR     = false contra el simulador; true contra una base real (saltea D)
#
# Sin base de prueba: scripts/dev/simulador-core-ds.py imita los recursos de
# COREDataService que se usan (empresa 42 con establecimiento 7, la 99 con el 1).
# La copia del MI apunta a él en registry/config/tools/apiconfig.xml
# (dataservices_url = http://127.0.0.1:18766/services).
#
# Ejecutar (terminal local, parado en traz-tools):
#   hurl --variable MI_HOST=localhost:8291 --variable VALID_ASSERTION="$A" \
#        --variable MAQUINA_ASSERTION="$M" --variable ESTA_AJENO=1 \
#        --variable ESTA_PROPIO=7 --variable SIN_SIMULADOR=false \
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

POST http://{{MI_HOST}}/tools/mcp/mcp/core/establecimiento
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{"nombre": "Planta Prueba Kuntur"}
HTTP 200

# Un depósito en un establecimiento PROPIO sí se crea.
POST http://{{MI_HOST}}/tools/mcp/mcp/alm/deposito
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
{"nombre": "Pañol Prueba Kuntur", "esta_id": "{{ESTA_PROPIO}}"}
HTTP 200


# ─── D: si el servicio de datos falla, error en el acto (no queda colgado) ───
# Solo contra el simulador de COREDataService (scripts/dev/simulador-core-ds.py),
# que responde 500 a este valor. Contra una base real, este caso se saltea.
POST http://{{MI_HOST}}/tools/mcp/mcp/core/valor
X-JWT-Assertion: {{VALID_ASSERTION}}
Content-Type: application/json
[Options]
skip: {{SIN_SIMULADOR}}
{"lista": "unidades_medida", "valor": "Provocar error"}
HTTP 502
[Asserts]
jsonpath "$.error" == "servicio_de_datos"
duration < 5000
