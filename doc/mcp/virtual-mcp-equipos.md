# Virtual MCP Server — Equipos [E2-MCP-01]

**API fuente:** `EquiposAPI-TrazalogMCP v1.0` (publicada en E1-API-10)
**Estado:** Pendiente configuración en consola WSO2

> **Nota de versión (APIM 4.6.0):** El Publisher expone MCP Servers como un tipo de
> API independiente. Los tool annotations (`readOnlyHint`, etc.) **no tienen campos
> editables en la UI** — se definen en la OpenAPI spec o vía REST API, no en el Publisher.

---

## 1. Tools del server

| Tool name | Operación fuente | Descripción para el agente |
|---|---|---|
| `get_equipos` | `GET /mcp/equipos` | Lista todos los equipos activos de la empresa. Usar para encontrar el `id_equipo` antes de crear una OT. |
| `get_equipo` | `GET /mcp/equipo/{equi_id}` | Devuelve el detalle técnico completo de un equipo. Usar cuando ya se conoce el `equi_id`. |

---

## 2. Pasos de configuración en WSO2 API Manager 4.6.0

### 2.1 Prerequisito

`EquiposAPI-TrazalogMCP v1.0` en estado **Published** en el Publisher.

### 2.2 Crear el MCP Server

**Opción A — desde la vista de la API existente (recomendada):**

1. Ir a `https://localhost:9443/publisher`
2. Abrir la API `EquiposAPI-TrazalogMCP`
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

- **Select an API to create MCP Server from:** `EquiposAPI-TrazalogMCP` (versión 1.0)
- **Select Operations for Tool Generation:** tildar ambas operaciones:
  - `GET /mcp/equipos`
  - `GET /mcp/equipo/{equi_id}`
- Click **`Next`**

**Paso 2 — Datos básicos del MCP Server:**

| Campo | Valor |
|---|---|
| **Name** | `trazalog-equipos` |
| **Version** | `1.0` |
| **Context** | `/trazalog-equipos` |
| **Display Name** | `Equipos Trazalog` *(opcional)* |

- Click **`Create`** (o **`Create & Publish`** si querés omitir pasos manuales)

### 2.4 Configurar Tools

Después de la creación, ir al menú lateral → **`Tools`**:

- La lista muestra las tools generadas automáticamente: `get_equipos` y `get_equipo`
- Para cada tool podés editar:
  - **Tool Name** — dejar como está (`get_equipos`, `get_equipo`)
  - **Description** — editar si la descripción generada no es clara

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

Desde el Developer Portal o MCP Hub:

```
https://localhost:9443/devportal
```

Buscar `trazalog-equipos` y confirmar que aparecen dos tools.

La URL del endpoint MCP será:
```
https://localhost:8243/trazalog-equipos/1.0/mcp
```

---

## 4. Test rápido

```bash
curl -k -H "Authorization: Bearer <JWT_DNATO>" \
  https://localhost:8243/trazalog-equipos/1.0/mcp/equipos
```

Debe devolver la lista de equipos de la empresa del JWT.

---

## 5. Aislamiento multi-empresa

El JWT Bearer del cliente determina la empresa.
El gateway extrae `empr_id` del claim JWT vía `EmprIdInjectorPolicy` (E9-IDENT-05).
El agente nunca ve ni pasa el parámetro de empresa.
