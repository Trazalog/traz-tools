# EmprIdFromHeader — Test de fallback 503 ante X-Empr-Id ausente (ADR-008)
#
# Este test llama al MI DIRECTAMENTE (:8280), sin pasar por el APIM.
# Propósito: verificar que el Fix 3 (WARN+503) funciona correctamente.
# En producción el puerto 8280 no es accesible desde internet; en DEV se
# usa para diagnosticar la ventana de inconsistencia entre B4 y B3.
#
# Cuándo ejecutar este test:
#   - Después de deployar el CAR con EmprIdFromHeader.xml (blocker B4)
#   - Antes de asociar la in-sequence al APIM (blocker B3)
#   - También útil como diagnóstico si el flujo APIM→MI falla con 503
#
# Variables requeridas:
#   MI_HOST = host:port del MI (ej: localhost:8280)
#
# Ejecutar:
#   hurl --variable MI_HOST=localhost:8280 mi-fallback.hurl


# ─────────────────────────────────────────────────────────────────
# Caso A: Request al MI sin X-Empr-Id → 503 identity_header_missing
# (simula lo que pasaría si el APIM no aplicó la in-sequence)
# ─────────────────────────────────────────────────────────────────
GET http://{{MI_HOST}}/tools/man/mcp/equipos
HTTP 503
[Asserts]
jsonpath "$.error" == "identity_header_missing"
jsonpath "$.message" contains "EmprIdInjectorPolicy"


# ─────────────────────────────────────────────────────────────────
# Caso B: Request al MI con X-Empr-Id vacío → 503 identity_header_missing
# ─────────────────────────────────────────────────────────────────
GET http://{{MI_HOST}}/tools/man/mcp/equipos
X-Empr-Id:
HTTP 503
[Asserts]
jsonpath "$.error" == "identity_header_missing"


# ─────────────────────────────────────────────────────────────────
# Caso C: Request al MI con X-Empr-Id presente → Fix 3 no se dispara
# (En DEV sin BD el DataService devuelve 404; lo importante es que NO sea 503)
# ─────────────────────────────────────────────────────────────────
GET http://{{MI_HOST}}/tools/man/mcp/equipos
X-Empr-Id: 42
HTTP *
[Asserts]
status != 503
