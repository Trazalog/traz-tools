# Virtual MCP Server — Órdenes de Trabajo [E2-MCP-02]

**API fuente:** `OrdenesdeTrabajoAPI-TrazalogMCP v1.0` (publicada en E1-API-10)
**Estado:** Pendiente configuración en consola WSO2

> **Nota de versión (APIM 4.6.0):** El Publisher expone MCP Servers como un tipo de
> API independiente. Los tool annotations (`readOnlyHint`, etc.) **no tienen campos
> editables en la UI** — se definen en la OpenAPI spec o vía REST API, no en el Publisher.

---

## 1. Tools del server

| Tool name | Operación fuente | Descripción para el agente |
|---|---|---|
| `create_ot` | `POST /mcp/ot` | Crea una Orden de Trabajo correctiva para un equipo con falla. Inicia el proceso de mantenimiento en el BPM. Requiere el ID del equipo y una descripción de la falla. |
| `get_ots` | `GET /mcp/ot` | Lista las Órdenes de Trabajo abiertas de la empresa. Usar para verificar OTs existentes antes de crear una nueva. |
| `get_ot` | `GET /mcp/ot/{id_solicitud}` | Obtiene el detalle completo de una OT: estado, equipo, mantenedor asignado, fechas. |

---

## 2. Pasos de configuración en WSO2 API Manager 4.6.0

### 2.1 Prerequisito

`OrdenesdeTrabajoAPI-TrazalogMCP v1.0` en estado **Published** en el Publisher.

### 2.2 Crear el MCP Server

**Opción A — desde la vista de la API existente (recomendada):**

1. Ir a `https://localhost:9443/publisher`
2. Abrir la API `OrdenesdeTrabajoAPI-TrazalogMCP`
3. En la pantalla de overview buscar el botón **`Generate MCP Server`**
4. Seguir el wizard (ver paso 2.3)

**Opción B — desde el menú de MCP Servers:**

1. Ir a `https://localhost:9443/publisher`
2. En el menú superior o lateral → **`MCP Servers`**
3. Click **`Create MCP Server`**
4. Seleccionar **`Create MCP Server from Existing API`**
5. Seguir el wizard (ver paso 2.3)

### 2.3 Wizard de creación

**Paso 1 — Seleccionar API y operaciones:**

- **Select an API to create MCP Server from:** `OrdenesdeTrabajoAPI-TrazalogMCP` (versión 1.0)
- **Select Operations for Tool Generation:** tildar las tres operaciones:
  - `POST /mcp/ot`
  - `GET /mcp/ot`
  - `GET /mcp/ot/{id_solicitud}`
- Click **`Next`**

**Paso 2 — Datos básicos del MCP Server:**

| Campo | Valor |
|---|---|
| **Name** | `trazalog-ots` |
| **Version** | `1.0` |
| **Context** | `/trazalog-ots` |
| **Display Name** | `Órdenes de Trabajo Trazalog` *(opcional)* |

- Click **`Create`** (o **`Create & Publish`** si querés omitir pasos manuales)

### 2.4 Configurar Tools

Después de la creación, ir al menú lateral → **`Tools`**:

- Tools generadas automáticamente: `create_ot`, `get_ots`, `get_ot`
- Para cada tool podés editar:
  - **Tool Name** — dejar como está
  - **Description** — editar si la descripción generada no refleja bien el comportamiento

Las descriptions importantes a verificar:

| Tool | Description esperada |
|---|---|
| `create_ot` | Debe mencionar que **crea** una OT e **inicia un proceso BPM** |
| `get_ots` | Debe mencionar que **lista** OTs abiertas de la empresa |
| `get_ot` | Debe mencionar que obtiene el **detalle** de una OT por ID |

Los campos de annotations (`readOnlyHint`, `destructiveHint`, etc.) **no están
disponibles en la UI** de APIM 4.6.0. Sus valores provienen de la spec OpenAPI.

### 2.5 Configurar Endpoint

Menú lateral → **`Endpoints`**:

- **Production Endpoint:** `http://localhost:8290/tools/man`
- *(Sandbox opcional)*
- Click **`Save`**

### 2.6 Configurar Subscriptions / Business Plans

Menú lateral → **`Subscriptions`**:

- En la sección **Business Plans** → seleccionar `Unlimited` (u otro plan disponible)
- Click **`Save`**

### 2.7 Deploy al Gateway

Menú lateral → **`Deployments`**:

1. Click **`Deploy New Revision`**
2. Seleccionar environment: **`Default`** / vhost `localhost`
3. Click **`Deploy`**

### 2.8 Publicar

1. Click **`Publish`** (esquina superior derecha o sección Lifecycle)
2. Estado cambia a **`Published`**

---

## 3. Verificar

La URL del endpoint MCP será:
```
https://localhost:8243/trazalog-ots/1.0/mcp
```

Test rápido:
```bash
curl -k -H "Authorization: Bearer <JWT_DNATO>" \
  https://localhost:8243/trazalog-ots/1.0/mcp/ot
```

---

## 4. Flujo demo completo

```
1. Buscar equipo → get_equipos (desde trazalog-equipos)
2. Ver OTs abiertas → get_ots (sin confirmación)
3. Crear OT → create_ot (Claude confirma antes por openWorldHint)
4. Verificar OT → get_ot
```

---

## 5. Aislamiento multi-empresa

El JWT Bearer del cliente determina la empresa.
- `create_ot` inserta en la empresa del JWT
- `get_ots` y `get_ot` solo devuelven datos de la empresa del JWT

Ver E9-IDENT-05 (gateway) y E9-IDENT-06 (DataService).

---

## 6. Rollback de create_ot

Si falla después del INSERT (Bonita no disponible):
- La solicitud se elimina automáticamente de la BD (ADR-003, Opción A)
- El agente recibe HTTP 500
- La OT no queda en estado inconsistente
