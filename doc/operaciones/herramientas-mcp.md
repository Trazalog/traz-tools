# Herramientas de operación y diagnóstico del MCP

## Objetivo

Inventario de los scripts de `scripts/dev/` que sirven para **operar y diagnosticar la capa MCP**:
qué hace cada uno, cuándo usarlo y qué tramo del camino valida. Está escrito para quien tenga que
verificar un despliegue o entender por qué una tool falla, sin haber vivido el diagnóstico original.

**Cuándo leerlo:** antes de tocar nada cuando una tool no responde, y después de cada despliegue
para validar.

**Qué NO cubre:** cómo publicar tools nuevas — eso es
[`../mcp/republicar-mcp-server.md`](../mcp/republicar-mcp-server.md). Ni la instalación de la
infraestructura — [`../v3/deployment-gcp.md`](../v3/deployment-gcp.md).

---

## El camino completo, y qué valida cada script

Entender esto ahorra la mayor parte del tiempo de diagnóstico. Una llamada de Claude atraviesa
**cinco tramos**, y cada script cubre uno o varios:

```
Claude  ──►  Caddy :443  ──►  APIM gateway :8243  ──►  MI :8290  ──►  PostgreSQL / MySQL
                                                          └────────►  Bonita :8080
```

| Script | Tramos que valida | Necesita token |
|---|---|---|
| **`validar-tools-e2e.py`** | **todos** — es el que decide si algo anda | sí |
| `mcp-smoke-tools.py` | Caddy + gateway (sólo el mapeo de tools) | no |
| `smoke-tools-mi.py` | MI + base + Bonita (saltea Caddy y gateway) | no |
| `diag-kpi-mttr.sh` | los 3 niveles de una tool, por separado | no |

---

## 1. Validación — lo que hay que correr después de cada despliegue

### `validar-tools-e2e.py` — **el principal**

Recorre el camino real y prueba las 17 tools con un token real.

```bash
python3 scripts/dev/validar-tools-e2e.py --desde-log
python3 scripts/dev/validar-tools-e2e.py --jwt "$JWT" --escrituras
```

Verifica tres cosas por tool, y la primera es la que más costó aprender:

1. **El status HTTP en el cable.** No el que reporta el `api.log` del APIM: durante el bug del `202`
   ese log decía `statusCode:200` mientras el cliente recibía `202`.
2. JSON-RPC válido, sin `isError: true`.
3. Contenido no vacío.

Manda los headers `Mcp-Method`, `Mcp-Name` y `Mcp-Protocol-Version` **igual que el cliente real** —
sin eso, el rewrite de Caddy no matchea y da un falso negativo.

El token se pasa con `--jwt` o se extrae del `api.log` con `--desde-log` (requiere API Logs en FULL).
**El token emitido por CLI de Dnato no sirve**: queda con `iss=http://localhost/oauth` y el gateway
lo rechaza con `900901`.

> `--escrituras` crea registros reales e instancia procesos en Bonita. Sin ese flag se omiten.

### `mcp-smoke-tools.py` — chequeo rápido, sin token

```bash
python3 scripts/dev/mcp-smoke-tools.py
```

Sirve para una sola cosa, pero la resuelve en segundos: distinguir una tool **bien mapeada** de una
con el `apiOperationMapping` roto.

| Respuesta | Significa |
|---|---|
| `401` | la tool está bien mapeada (el gateway llegó a pedir auth) |
| `500` con `existingAPIOperationMapping is null` | falta la operación de backend → hay que recrear la API |
| `404` en todas | no hay revisión desplegada |

### `smoke-tools-mi.py` — aislar el backend

```bash
python3 scripts/dev/smoke-tools-mi.py --empresa <empr_id_mysql> --empresa-pg <empr_id>
```

Pega al MI directo con un `X-JWT-Assertion` sintético (`EmprIdFromHeader` no valida la firma, sólo
decodifica el payload). **Si acá funciona y por el camino completo no, el problema está en el
gateway o en Caddy** — es la bifurcación más útil del diagnóstico.

> Los dos ids de empresa no son intercambiables: las tools `man_*` filtran por `empr_id_mysql`
> (assetv2) y las `alm_*` por `empr_id` (PostgreSQL). Ambos viajan en el mismo JWT.

---

## 2. Diagnóstico — cuando algo falla

### `capturar-fallo-tool.sh` — ver el error real de una tool

```bash
bash scripts/dev/capturar-fallo-tool.sh
```

Sigue a la vez los logs del APIM y del MI, filtrando por las rutas de las tools y los códigos de
error de WSO2. Se deja corriendo y se reproduce el fallo desde el cliente.

### `ver-access-log.sh` — URL y status reales

```bash
bash scripts/dev/ver-access-log.sh
```

El log de Synapse no dice ni la URL ni el código de respuesta. Además verifica que el CAR desplegado
tenga los fixes esperados.

> **El access log más importante no es el de WSO2 sino el de Caddy**
> (`/var/log/caddy/mcp-access.log`): es el único que muestra **lo que realmente recibe el cliente**.
> Fue el que resolvió el bug del `202`.
>
> ```bash
> sudo tail -5 /var/log/caddy/mcp-access.log | python3 -m json.tool
> ```

### `diag-mcp-mapping.sh` — estado de las tools en la base del APIM

```bash
bash scripts/dev/diag-mcp-mapping.sh
```

Lista tool por tool si tiene `apiOperationMapping`, y compara contra los recursos de la API fuente.
Imprescindible cuando la pantalla `Tools` del Publisher no abre — que es lo que pasa justamente
cuando hay mappings rotos ([wso2/api-manager#5106](https://github.com/wso2/api-manager/issues/5106)).

### `diag-api-revisiones.sh` — working copy vs revisión desplegada

```bash
bash scripts/dev/diag-api-revisiones.sh
```

El Publisher muestra la working copy; el gateway sirve la revisión desplegada. **Pueden diferir**, y
esa diferencia fue la causa de que 8 tools no mapearan durante días.

### `diag-kpi-mttr.sh` — una tool en sus 3 capas

```bash
bash scripts/dev/diag-kpi-mttr.sh 15 2024-01-01 2026-07-31
```

Prueba DataService, fachada MCP en el MI y gateway por separado. El patrón sirve para cualquier tool:
saber en cuál de las tres se corta acota el problema de entrada.

---

## 3. Mantenimiento — operaciones que modifican

### `recrear-api-y-mcp.sh` — recrear la API

```bash
bash scripts/dev/recrear-api-y-mcp.sh              # plan, no toca nada
bash scripts/dev/recrear-api-y-mcp.sh --apply
```

**Es la única forma de que las tools nuevas queden mapeadas.** Agregarle operaciones a una API que ya
tiene un MCP Server generado no funciona por ningún otro camino
([`../mcp/republicar-mcp-server.md`](../mcp/republicar-mcp-server.md) §7).

Destructivo sobre producción: hace backups antes de borrar nada, aborta en cada paso crítico, y no
recrea el MCP Server (eso va por la UI, que es lo único que genera los mappings).

### API Logs — el diagnóstico más potente, y el más sensible

Logging por API, sin reiniciar, con headers y payload completos de los cuatro flujos
(`REQUEST_IN`, `REQUEST_OUT`, `RESPONSE_IN`, `RESPONSE_OUT`):

```bash
curl -k -u admin:admin -X PUT \
  "https://localhost:9443/api/am/devops/v0/tenant-logs/carbon.super/apis/<ID>" \
  -H "Content-Type: application/json" \
  -d '{"logLevel":"FULL"}'
```

> ⚠️ **En FULL escribe los `Authorization` y los `Internal-Key` completos en texto plano.** Apagarlo
> (`{"logLevel":"OFF"}`) apenas termina el diagnóstico.
>
> El `<ID>` sale de `diag-mcp-mapping.sh`. Conviene habilitarlo en el **MCP Server y en la API
> fuente**, para ver los dos saltos.

---

## 4. Qué mirar primero, según el síntoma

| Síntoma | Empezar por |
|---|---|
| «el servidor no responde» en el cliente | `mcp-smoke-tools.py` — si da `500`, es mapping roto |
| Una tool devuelve error pero **el dato se creó igual** | el access log de **Caddy**: mirar el status. Un `202` rompe al cliente |
| Todas las tools dan `404` | no hay revisión desplegada del MCP Server |
| Todas dan `403` / `900908` | falta la suscripción de la aplicación en el DevPortal |
| `900901 Invalid Credentials` | el `iss` del token no coincide con `[[apim.jwt.issuer]]` |
| Las tools `man_*` devuelven vacío y las `alm_*` traen datos | el token tiene `empr_id_mysql` vacío — es dato, no despliegue |
| El backend anda pero el cliente falla | `smoke-tools-mi.py`: si pasa, el problema es gateway o Caddy |
| Ningún log de WSO2 se escribe | config de log4j2 rota o proceso huérfano — comparar contra `http_access` de Tomcat, que no pasa por log4j |

---

## 5. Scripts de otras etapas

Siguen en `scripts/dev/` y no son parte del diagnóstico MCP:

| Script | Para qué |
|---|---|
| `mcp_tools_client.py`, `mcp_escenarios.py` | escenarios encadenados de negocio (13 casos) |
| `verify-mcp-queries.py`, `verify-mcp-isolation.py` | regresión de queries y aislamiento multi-empresa |
| `check-dnato-mcp-auth.sh` | verificador del flujo de auth en Dnato |
| `kpi-*.sql`, `verificar-kpi-*.sql` | diagnóstico de los KPIs de mantenimiento (`../mantenimiento/`) |
| `mcp-oauth-proxy.py`, `mcp-session-shim.py`, `setup-apim-b3-mcp-apis.sh` | de la etapa de ngrok/DEV, previos al despliegue en GCP |
