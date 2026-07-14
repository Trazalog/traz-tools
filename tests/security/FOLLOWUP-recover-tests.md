# TODO — Casos de test a recuperar tras el merge de PR #388

Durante la resolución de conflictos del PR #388 (`feature/e2-mcp-equipos-ots` →
`develop-v3`) se tomó el lado **feature** en `jwt-validation.hurl` y `ot-mcp.hurl`
(tests apuntando al **APIM Gateway :8243**, mecanismo ADR-008/009). Al hacerlo se
perdieron **2 casos de test** que solo existían en la versión de `develop-v3` (que
apuntaba al **MI :8280**, mecanismo viejo `jwtValidator`).

Ambos casos prueban comportamientos **válidos** que conviene recuperar. **No se pueden
copiar tal cual**: hay que reexpresarlos contra el flujo APIM (host `:8243`, formato de
respuesta 401 del APIM — que difiere del `"message": "Malformed JWT"` que emitía el
`jwtValidator` del MI).

---

## Caso 1 — Token Bearer malformado (no 3 partes) → 401

Origen: `tests/security/jwt-validation.hurl` (versión develop-v3, "Caso b2").

```hurl
# Caso b2: Bearer con token malformado (no 3 partes) → 401
GET http://{{MI_HOST}}{{MCP_RESOURCE}}
Authorization: Bearer esto.no.es.un.jwt.valido.tiene.mas.partes
HTTP 401
[Asserts]
jsonpath "$.error" == "Unauthorized"
jsonpath "$.message" contains "Malformed JWT"
```

**Adaptación pendiente:** apuntar al APIM (`{{APIM_HOST}}` / la ruta publicada), y
ajustar los asserts al cuerpo 401 real del APIM (no emite `"Malformed JWT"`; el APIM
rechaza el token porque no valida contra el JWKS de Dnato).

---

## Caso 2 — Aislamiento cross-tenant en escritura (create_ot empresa B) → OT en empresa B

Origen: `tests/security/ot-mcp.hurl` (versión develop-v3, "Caso 2d").

```hurl
# Caso 2d: POST empresa B — verifica que la OT se crea en empresa B (no en A)
# La OT creada en 2d debe tener id_empresa=99, no 42
POST http://{{MI_HOST}}/tools/man/mcp/ot
Authorization: Bearer {{EMPRESA_B_JWT}}
Content-Type: application/json
{
  "equipo_id": "20",
  "descripcion": "OT de empresa B - aislamiento"
}
HTTP 200
[Captures]
ot_empresa_b_id: jsonpath "$.ot_id"
[Asserts]
jsonpath "$.resultado" == "ok"
```

**Adaptación pendiente:** apuntar al endpoint publicado del APIM; idealmente añadir un
GET de verificación posterior que confirme que la OT creada con `EMPRESA_B_JWT` queda
efectivamente bajo `id_empresa=99` (empresa B) y **no** es visible con `VALID_JWT`
(empresa A) — prueba de aislamiento cross-tenant end-to-end.

---

_Referencia: PR #388, resolución de conflictos. Recuperar en un commit follow-up._
