# Virtual MCP Server unificado — Trazalog Operaciones [E2-MCP-13]

**API fuente:** `doc/api/trazalog-operaciones.yaml` (nueva, unificada — reemplaza a `EquiposAPI-TrazalogMCP` + `OrdenesdeTrabajoAPI-TrazalogMCP`)
**Backend:** `toolsMCPAPI` (WSO2 MI, context `/tools/mcp`) — fachada delgada, ver `_backend/api/ToolsAPIProject/.../artifacts/apis/toolsMCPAPI.xml`
**Estado:** Pendiente configuración en consola WSO2 (pasos manuales de Rodolfo, esta tarea solo prepara los artefactos)
**Decisión base:** [ADR-013](../adr/ADR-013-unificacion-mcp.md) — un solo Virtual MCP Server con todas las tools, prefijadas por módulo (`man_`, `alm_`)

> ⚠️ **Nota sobre `doc/api/openapi-publish-procedure.md`:** ese documento (Sprint 2) describe la inyección de identidad como un header `X-Empr-Id` seteado por una mediación del APIM. **Eso quedó desactualizado.** El mecanismo vigente (ADR-009, confirmado en `CONTEXT-PACK.md` §3 y en `EmprIdFromHeader.xml`) es distinto: el APIM genera su propio backend JWT (`apim.jwt.enable=true`) y lo manda como header **`X-JWT-Assertion`**; el MI lo decodifica con la sequence `emprIdFromHeader` (ya usada por `toolsMANAPI` y por `toolsMCPAPI`). Los pasos de este documento reflejan el mecanismo vigente — no repliques la mediación de `X-Empr-Id` de `openapi-publish-procedure.md` para esta API nueva.

---

## 1. Tools del server unificado (9)

| Tool | Método | Operación fuente | Módulo | Annotation |
|---|---|---|---|---|
| `man_get_equipos` | GET | `/mcp/man/equipos` | Mantenimiento | `readOnlyHint` |
| `man_get_equipo` | GET | `/mcp/man/equipo/{equi_id}` | Mantenimiento | `readOnlyHint` |
| `man_get_ots` | GET | `/mcp/man/ot` | Mantenimiento | `readOnlyHint` |
| `man_get_ot` | GET | `/mcp/man/ot/{id_solicitud}` | Mantenimiento | `readOnlyHint` |
| `man_create_ot` | POST | `/mcp/man/ot` | Mantenimiento | `destructiveHint` |
| `alm_get_stock` | GET | `/mcp/alm/stock` | Almacenes | `readOnlyHint` |
| `alm_get_pedidos_materiales` | GET | `/mcp/alm/pedidos` | Almacenes | `readOnlyHint` |
| `alm_get_pedido_material` | GET | `/mcp/alm/pedido/{pema_id}` | Almacenes | `readOnlyHint` |
| `alm_crear_pedido_materiales` | POST | `/mcp/alm/pedido` | Almacenes | `destructiveHint` |

**Sobre las annotations:** están declaradas en `trazalog-operaciones.yaml` con la extensión `x-mcp-annotations` (`readOnlyHint`/`destructiveHint` por operación, ver `doc/mcp/tool-annotations-standard.md`). **No confirmado que WSO2 4.6.0 lea esa extensión al generar las tools** — no hay documentación oficial que confirme el nombre exacto del vendor-extension para MCP en 4.6.0, y `equipos.yaml`/`ot.yaml` (Sprint 2) tampoco la usaban. Verificar en el smoke test (§4, paso 2) si `tools/list` devuelve las annotations; si no aparecen, es un gap ya preexistente de Sprint 2 (no introducido por esta tarea), a resolver aparte.

---

## 2. Pasos de configuración en WSO2 API Manager 4.6.0

### 2.1 Prerequisito

Key Manager **Dnato** ya configurado (federado, no Resident KM) — ver `doc/identity/apim-keymanager-dnato.md`. Es el mismo que ya usan `EquiposAPI-TrazalogMCP`/`OrdenesdeTrabajoAPI-TrazalogMCP`, no hay que crear uno nuevo.

### 2.2 Importar la spec

1. Ir a `https://localhost:9443/publisher` (o el host correspondiente si es contra la VM de GCP)
2. **`+ Create API`** → **`Import OpenAPI`**
3. Seleccionar `doc/api/trazalog-operaciones.yaml`
4. Verificar los campos pre-completados:
   - **Name:** `Trazalog MCP Server` — nombre real usado por Rodolfo al publicar (2026-08-08), distinto del sugerido originalmente (`Trazalog Operaciones`)
   - **Version:** `1.0`
   - **Context:** `/trazalog/mcp` — confirmado, no `/trazalog-operaciones`
5. **`Create`**

### 2.3 Configurar el backend (Endpoint)

En **`Develop`** → **`API Configurations`** → **`Endpoints`**:

| Campo | Valor |
|---|---|
| Endpoint type | HTTP/REST Endpoint |
| Production URL | `http://<host-del-MI>:8280/tools/mcp` |
| Sandbox URL | `http://<host-del-MI>:8280/tools/mcp` |

> El APIM proxea al MI, context `/tools/mcp` (`toolsMCPAPI`) — no a `/tools/man` ni `/tools/alm` directamente. `toolsMCPAPI` es la única fachada que expone esta API; internamente delega a `toolsALMAPI` para las tools `alm_*`, pero eso es transparente para el APIM.

### 2.4 Seguridad — OAuth2 con Key Manager Dnato

En **`Develop`** → **`API Configurations`** → **`Runtime`** → **`Application Level Security`**:

1. Marcar **`OAuth2`**. Desmarcar Basic Auth y API Key.
2. **Key Managers:** seleccionar únicamente **`Dnato`**. Des-seleccionar **`Resident Key Manager`**.
3. Confirmar que `apim.jwt.enable=true` está activo en el `deployment.toml` del APIM (configuración global, ya debería estarlo si `trazalog-equipos`/`trazalog-ots` funcionan hoy — no es algo que se configure por API). Si no está activo, es un bloqueante — no seguir sin confirmarlo primero.

No hace falta asociar ninguna mediación/policy de inyección de `empr_id` — a diferencia de lo que describe `openapi-publish-procedure.md` (desactualizado, ver nota al inicio), el backend JWT (`X-JWT-Assertion`) lo genera el APIM automáticamente vía `apim.jwt.enable`, sin policy por API.

### 2.5 Publicar la API

1. **`Publish`** (esquina superior derecha)
2. Estado → `Published`

### 2.6 Generar el Virtual MCP Server único

**Opción A — desde la vista de la API (recomendada):**

1. Abrir la API `Trazalog MCP Server` recién publicada
2. En la pantalla de overview, botón **`Generate MCP Server`**

**Opción B — desde el menú de MCP Servers:**

1. Menú lateral → **`MCP Servers`** → **`Create MCP Server`** → **`Create MCP Server from Existing API`**

**Wizard de creación:**

- **Select an API to create MCP Server from:** `Trazalog MCP Server` (versión 1.0)
- **Select Operations for Tool Generation:** tildar las **9** operaciones (las 5 de mantenimiento + las 4 de almacenes)
- **Next**
- **Name:** `Trazalog MCP Server`
- **Version:** `1.0`
- **Context:** `/trazalog/mcp`
- **Create**

> **Nota 2026-08-08:** los valores de arriba son los reales, confirmados una vez que Rodolfo publicó la API — difieren de la sugerencia original de ADR-013/este documento (`trazalog-operaciones` / `/trazalog-operaciones`). Gateway Type resultante: `Regular`.

### 2.7 Configurar Tools

Menú lateral → **`Tools`**: confirmar que aparecen las 9, con los nombres `man_*`/`alm_*` tal cual (vienen del `operationId` de la spec, no hay que renombrarlas). Editar `Description` solo si alguna no quedó clara — las descripciones ya están escritas semánticamente en la spec para que Claude sepa cuándo usar cada una.

### 2.8 Deploy y publicar el MCP Server

Igual que en Sprint 2 (`virtual-mcp-equipos.md` §2.7-2.8): **`Deployments`** → `Deploy New Revision` → environment `Default` → **`Deploy`**. Después **`Publish`** (Lifecycle).

### 2.9 Endpoint MCP resultante

```
https://<host-del-apim>:8243/trazalog/mcp/1.0/mcp
```

Confirmado en DEV: `https://localhost:8243/trazalog/mcp/1.0/mcp` (MCP playground de Rodolfo, 2026-08-08).

Versión de protocolo MCP: `2025-06-18` (igual que los servers actuales).

---

## 3. Guía de migración coordinada (ADR-013 decisión #5)

**⚠️ Orden estricto — no saltear pasos ni cambiar el orden:**

1. **Crear y publicar** `Trazalog MCP Server` (contexto `/trazalog/mcp` — pasos §2 de este documento). `trazalog-equipos` y `trazalog-ots` **siguen activos** durante todo este proceso — no tocarlos todavía.
2. **Smoke test completo de las 9 tools** contra el server nuevo (ver §4 abajo), incluida la prueba de aislamiento de 2 empresas.
3. **Recién con el smoke test en verde**, reconfigurar Claude.ai:
   - `Settings` → `Integrations` → `MCP Servers`
   - Cambiar (o agregar) la URL a `https://<host-del-apim>:8243/trazalog/mcp/1.0/mcp`
4. **Recién ahí**, despublicar `trazalog-equipos` y `trazalog-ots` (Publisher → cada API → Lifecycle → `Retire` o `Block`, según se prefiera conservar el historial).

**⚠️ Advertencia explícita: NO despublicar `trazalog-equipos`/`trazalog-ots` antes de tener el paso 3 confirmado.** Si algo del server unificado falla después de haberlos despublicado, la demo queda sin ningún MCP Server funcionando — la ventana de convivencia (viejos + nuevo activos en paralelo) es la red de seguridad de esta migración.

---

## 4. Smoke test de las 9 tools

Equivalente al smoke test manual de Sprint 2, ahora respaldado por los tests automatizados de cada tarea (`tests/security/mcp-facade-man-tools.hurl`, `mcp-facade-man-get-equipos.hurl`, `mcp-facade-alm-tools.hurl` — corridos contra el MI directo). Este smoke test es contra el **APIM real** (con JWT de Dnato), no contra el MI directo.

```bash
JWT="<JWT real de Dnato, empresa A>"
JWT_B="<JWT real de Dnato, empresa B — para el paso 2>"
HOST="<host-del-apim>:8243/trazalog/mcp/1.0"

# 1. Handshake MCP
curl -k -X POST https://$HOST/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"smoke-test","version":"1.0"}},"id":1}'

# 2. tools/list — confirmar que aparecen las 9, y si las annotations
#    (readOnlyHint/destructiveHint) están presentes en el schema (ver nota §1)
curl -k -X POST https://$HOST/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}'

# 3-9. tools/call de cada una de las 9 tools, con JWT de empresa A.
#    Para man_create_ot y alm_crear_pedido_materiales: confirmar que el
#    rollback dispara si se fuerza un fallo (ver DoD de las tareas 3.2/3.3).

# 10. Prueba de aislamiento — repetir alguna lectura (ej. man_get_equipos,
#     alm_get_stock) con JWT_B y confirmar que NO aparecen datos de la
#     empresa A, y viceversa.
```

DoD de este smoke test (a marcar por Rodolfo antes de avanzar al paso 3 de la migración):

- [ ] `initialize` y `tools/list` responden correctamente, con las 9 tools
- [ ] Cada una de las 9 tools responde `tools/call` sin error con JWT válido
- [ ] `man_create_ot` y `alm_crear_pedido_materiales` piden confirmación (o al menos están marcadas `destructiveHint` en el schema) y el rollback dispara ante un fallo forzado
- [ ] Aislamiento verificado: JWT empresa A no ve datos de empresa B en ninguna de las 4 tools de lectura de almacenes ni en las de mantenimiento
- [ ] Sin JWT / JWT inválido → 401 en las 9 tools

---

## 5. Después de la migración

- Actualizar este documento (o `STATE.md`) marcando `trazalog-equipos`/`trazalog-ots` como despublicados y la fecha.
- `doc/mcp/virtual-mcp-equipos.md` y `virtual-mcp-ots.md` quedan como registro histórico de Sprint 2 — no se borran, se podría agregar una nota de "reemplazado por virtual-mcp-unificado.md" en cada uno (no hecho en esta tarea, a criterio de Rodolfo).
