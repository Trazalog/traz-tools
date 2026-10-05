# Demo end-to-end MCP — Smoke test Sprint 2 (E2-MCP-09)

**Fecha:** 2026-07-02
**Entorno:** DEV local (workstation PM) + Claude.ai Web (conector MCP remoto)
**Alcance:** validar las 5 tools MCP desde Claude.ai con flujo **OAuth 2.1 + PKCE real**
(vía Dnato como Authorization Server), **no** con MCP Inspector ni con la Messages API.

---

## 1. Resumen

Se probaron las **5 tools** expuestas por los dos MCP servers virtuales sobre WSO2 API
Manager 4.6.0, invocadas desde el cliente de conectores de Claude.ai Web:

| MCP Server | Context path | Tools |
|---|---|---|
| `trazalog-equipos` | `/trazalog-equipos/1.0/mcp` | `get_equipos`, `get_equipo` |
| `trazalog-ots` | `/trazalog-ots/1.0/mcp` | `get_ots`, `get_ot`, `create_ot` |

**Flujo de autenticación (real, no bypass):**

```
Claude.ai → discovery RFC 9728 (PRM) → Dnato OAuth 2.1 (authorize/login/token, PKCE S256)
          → JWT RS256 (iss=Dnato, empr_id + empr_id_mysql) → APIM gateway (X-JWT-Assertion)
          → MI (EmprIdFromHeader) → DataService → MySQL/PostgreSQL
```

El cliente de Claude negocia `protocolVersion` (ver §4 y limitaciones); el gateway valida
firma RS256 e `iss` vía JWKS de Dnato antes de enrutar la llamada al backend.

**Resultado:** las 5 tools ejecutan end-to-end y devuelven datos reales de la empresa del
token. Aislamiento multi-tenant confirmado (§3).

---

## 2. Evidencia por tool

Empresa del token de prueba: **Empresa_Test** (`empr_id=1`, `empr_id_mysql=1`,
usuario `admin@gmail.com`).

### 2.1 `get_equipos` — lista de equipos de la empresa

**Prompt:** «listá mis equipos»

**Respuesta (4 equipos):**

| Código | Descripción | Estado |
|---|---|---|
| BOMB-001 | Bomba centrífuga Grundfos CM10 | RE (en reparación) |
| COMP-001 | Compresor de aire Atlas Copco GA37 | AC (activo) |
| GEN-001 | Generador Sullair 750kVA | AC (activo) |
| GHOR-001 | Grúa horquilla Caterpillar GP25N | AC (activo) |

### 2.2 `get_equipo` — detalle de un equipo

**Prompt:** «mostrame el detalle del equipo BOMB-001»
(previo `get_equipos` para resolver `id_equipo=131`)

**Respuesta:** datos técnicos completos de BOMB-001 — marca Grundfos, área/proceso/sector,
criticidad Media, estado RE. Si el `id_equipo` no pertenece a la empresa del token, la
respuesta es la estructura vacía `{ "equipo": {} }` sin código de error (aislamiento).

### 2.3 `get_ots` — órdenes / solicitudes de trabajo de la empresa

**Prompt:** «listá mis órdenes de trabajo»

**Respuesta:** solicitudes de reparación de la empresa, con estado, ubicación y causa
(ej. solicitud estado `S`, ubicación «Sala de bombas Circuito 2»). Filtra por
`id_empresa` del token; soporta filtro opcional `?estado=`.

### 2.4 `get_ot` — detalle de una orden

**Prompt:** «mostrame la OT <id>»

**Respuesta:** detalle de la solicitud/orden identificada, restringida a la empresa del
token.

### 2.5 `create_ot` — crear orden de trabajo

**Prompt:** «creá una OT para BOMB-001 por vibración excesiva»

**Flujo interno (ADR-008):** paso 1 valida el equipo (GET interno), paso 2 arma el payload,
paso 3 dispara el proceso BPM en Bonita. El `empr_id` se deriva del backend JWT
(`X-JWT-Assertion`), no de un header cliente.

> Ver limitaciones §5 respecto al mapeo `sub` (JWT) → `sisusers.usrId` en el alta.

---

## 3. Aislamiento multi-tenant (E2-MCP-09b)

Se validó que dos sesiones con **usuarios de empresas distintas** ven **conjuntos de datos
disjuntos**, sin cruce, usando el mismo MCP server y el mismo endpoint.

| Empresa | Usuario | `empr_id` / `empr_id_mysql` | `get_equipos` |
|---|---|---|---|
| Empresa_Test | `admin@gmail.com` | 1 / 1 | **4 equipos**: BOMB-001, COMP-001, GEN-001, GHOR-001 |
| MinTest_SJ | `admin@mintest-sj.local` | 187 / 17 | **3 equipos**: BOMB-SJ-001, COMP-SJ-001, MOTO-SJ-001 |

**Confirmado:**
- La sesión de MinTest_SJ **nunca** devuelve equipos de Empresa_Test, ni viceversa.
- El filtrado ocurre en el DataService a partir del `empr_id`/`id_empresa` derivado del
  JWT (no de parámetros del cliente), de modo que el aislamiento no depende del prompt
  ni es evadible desde el agente.
- Cada usuario resuelve **exactamente una empresa** (TAD-IDENT-02): la membresía Bonita
  con formato `{empr_id}-{grupo}` determina el tenant en el login OAuth.

---

## 4. Hallazgo de arquitectura: inyección de `empr_id` vía X-JWT-Assertion

ADR-008 preveía una **`EmprIdInjectorPolicy`** (policy custom del gateway) para propagar
el `empr_id` al backend. Durante la integración end-to-end se resolvió, en su lugar, con el
**backend JWT que genera WSO2 APIM tras validar el token** (`X-JWT-Assertion`,
`convert_dialect=false`):

- APIM valida el JWT de Dnato (firma RS256 + issuer vía JWKS) y **re-emite** un JWT firmado
  por el gateway con los claims originales (`empr_id`, `empr_id_mysql`) en el header
  `X-JWT-Assertion`.
- El MI (`EmprIdFromHeader.xml`) lee `empr_id` de ese header y lo usa para el filtrado en
  el DataService — sin necesidad de una policy de mediación custom.

Ventaja: menos superficie custom en el gateway y reutilización del mecanismo estándar de
APIM. **Este cambio de enfoque se formaliza en ADR-009 (pendiente de redacción).**

---

## 5. Limitaciones conocidas (backlog Sprint 3)

- **Mapeo `sub` (JWT) → `sisusers.usrId` en `create_ot`.** El alta de OT necesita el
  `usrId` del sistema legacy (assetv2) para el solicitante; hoy el JWT lleva `sub`
  (usernick) pero falta el mapeo resuelto server-side. Definir la traducción canónica.
- **Hardening de validación de firma en PROD.** En DEV el JWKS de Dnato se sirve local y
  la verificación de hostname está relajada. En PROD: JWKS por HTTPS con cadena válida,
  rotación de `kid`, y validación estricta de `aud`/`iss`.
- **RFC 8252 loopback `redirect_uri` para Claude Code CLI.** El flujo actual usa el
  `redirect_uri` de Claude.ai Web (`https://claude.ai/api/mcp/auth_callback`). Para
  soportar Claude Code CLI hay que habilitar redirect a `http://127.0.0.1:<port>/...`
  (loopback) en la whitelist de clientes OAuth de Dnato.

---

## Referencias

- [`doc/mcp/virtual-mcp-equipos.md`](virtual-mcp-equipos.md) — Virtual MCP Server de equipos.
- [`doc/mcp/virtual-mcp-ots.md`](virtual-mcp-ots.md) — Virtual MCP Server de OTs.
- [`doc/mcp/COMO-CLAUDE-LLAMA-UN-MCP.md`](COMO-CLAUDE-LLAMA-UN-MCP.md) — Flujo de invocación MCP.
- `doc/v3/TRAZALOG_v3_MCP_ARCHITECTURE.md` — Arquitectura MCP y TAD-IDENT-02.
- ADR-008 (inyección `empr_id`), ADR-009 (pendiente — X-JWT-Assertion).
