# tests/security — Suite de aislamiento y validación JWT del MCP

Pruebas de seguridad del gateway MCP: validación de firma/claims del JWT y aislamiento
multi-tenant por `empr_id` (ver ADR-008 / ADR-009).

## Archivos versionados

- `generate-test-jwts.sh` — genera las claves de test y los JWT de prueba (ver abajo).
- `jwt-validation.hurl` — casos de validación de firma, `exp`, `iss`, claim `empr_id`.
- `dataservice-isolation.hurl` — aislamiento por empresa a nivel DataService.
- `ot-mcp.hurl` — flujo MCP de órdenes de trabajo.

## Artefactos NO versionados (gitignored)

Estos se **generan localmente** y **no** se commitean (son regenerables y no deben vivir
en el repo — ver `.gitignore`):

- `test-dnato-private.pem`, `test-dnato-public.pem` — par RSA de **test** del issuer
  `trazalog-dnato` (throwaway; **no** es la clave productiva de Dnato).
- `test-other-private.pem` — clave RSA distinta, usada para el caso "firma inválida".
- `test-env.vars` — JWT de prueba (válido, expirado, firma-incorrecta, sin `empr_id`,
  empresa A vs B) exportados como variables de entorno para las `.hurl`.

## Cómo generarlos

```bash
cd tests/security
bash generate-test-jwts.sh      # requiere: openssl, python3, jq
```

Esto crea los `.pem` y el `test-env.vars`. Luego correr las pruebas con
[Hurl](https://hurl.dev):

```bash
hurl --variables-file test-env.vars jwt-validation.hurl
```

> ⚠️ Nunca commitear `*.pem` ni `test-env.vars`. Si `generate-test-jwts.sh` cambia el
> mecanismo de firma, actualizar también `scripts/dev/dnato-jwks-server.py` (publica el
> JWKS que valida estos tokens) y `scripts/dev/mint-dnato-jwt.py`.
