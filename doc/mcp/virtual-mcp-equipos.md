# Virtual MCP Server — Equipos [E2-MCP-01]

**API fuente:** `EquiposAPI-TrazalogMCP v1.0` (publicada en E1-API-10)  
**Annotations standard:** `doc/mcp/tool-annotations-standard.md`  
**Estado:** Pendiente configuración en consola WSO2

> **Nota de versión:** Los pasos de configuración corresponden a **WSO2 API Manager 4.6.0**.
> En esta versión el MCP Server se crea como una API independiente (tipo MCP) generada
> desde la API REST existente — no existe la opción "Enable AI Capabilities" descrita
> en documentación de versiones anteriores.

---

## 1. Nombre del Virtual MCP Server

```
trazalog-equipos
```

Nombre visible en el MCP Hub. Los agentes que conecten este server pueden
invocar todas las tools listadas en la sección 2.

---

## 2. Tools del server

| Tool name | `operationId` fuente | `readOnlyHint` | `destructiveHint` | `idempotentHint` | `openWorldHint` | Descripción para el agente |
|---|---|---|---|---|---|---|
| `get_equipos` | `get_equipos` | ✅ `true` | ❌ `false` | ✅ `true` | ❌ `false` | Lista todos los equipos activos de la empresa. Usar para encontrar el `id_equipo` de un equipo antes de crear una OT, o para ver qué equipos están en reparación. |
| `get_equipo` | `get_equipo` | ✅ `true` | ❌ `false` | ✅ `true` | ❌ `false` | Devuelve el detalle técnico completo de un equipo: marca, sector, criticidad, área y proceso. Usar cuando ya se conoce el `equi_id`. |

**Justificación de annotations:**
- Ambas son SELECT puro sin efectos laterales → `readOnlyHint=true`.
- No inician procesos externos → `openWorldHint=false`.
- El mismo equipo devuelve los mismos datos en invocaciones sucesivas → `idempotentHint=true`.

---

## 3. Pasos de configuración en WSO2 API Manager 4.6.0

### 3.1 Prerequisito

La API `EquiposAPI-TrazalogMCP v1.0` debe estar en estado `Published` en el Publisher.
Verificar en `https://localhost:9443/publisher`.

### 3.2 Crear el MCP Server desde la API existente

1. Ir a `https://localhost:9443/publisher`
2. Click en **`Create API`** (botón superior derecho)
3. Seleccionar **`MCP Server`**
4. Seleccionar **`Create MCP Server from Existing API`**
5. En el formulario completar:
   - **Name:** `trazalog-equipos`
   - **Context:** `/trazalog-equipos`
   - **Version:** `1.0`
   - **Existing API:** seleccionar `EquiposAPI-TrazalogMCP` versión `1.0`
6. Click **`Create`**

El Publisher genera automáticamente las tools `get_equipos` y `get_equipo`
a partir de las operaciones `GET /mcp/equipos` y `GET /mcp/equipo/{equi_id}`.

### 3.3 Configurar los tool annotations

Una vez creado el MCP Server, en la pantalla de configuración de tools:

#### Tool `get_equipos` (operación `GET /mcp/equipos`)

| Annotation | Valor |
|---|---|
| `readOnlyHint` | ☑ **true** |
| `destructiveHint` | ☐ false |
| `idempotentHint` | ☑ **true** |
| `openWorldHint` | ☐ false |

**Description** (verificar que esté pre-llenada desde el yaml):
> Lista todos los equipos activos de la empresa. Usar para encontrar el `id_equipo` antes de crear una OT.

#### Tool `get_equipo` (operación `GET /mcp/equipo/{equi_id}`)

| Annotation | Valor |
|---|---|
| `readOnlyHint` | ☑ **true** |
| `destructiveHint` | ☐ false |
| `idempotentHint` | ☑ **true** |
| `openWorldHint` | ☐ false |

**Description:**
> Devuelve el detalle técnico completo de un equipo. Usar cuando ya se conoce el `equi_id`.

Click **`Save`** después de configurar cada tool.

### 3.4 Asignar Business Plan

1. En el menú lateral → **`Business Plans`** (o **`Subscriptions`**)
2. Seleccionar al menos un plan (ej. `Unlimited`)
3. Click **`Save`**

### 3.5 Deploy al Gateway

1. En el menú lateral → **`Deployments`**
2. Click **`Deploy New Revision`**
3. Seleccionar environment **`Default`**, vhost `localhost`
4. Click **`Deploy`**

### 3.6 Publicar

1. Click **`Publish`** en la esquina superior derecha
2. El estado cambia a `Published`
3. El MCP Server `trazalog-equipos` aparece en el MCP Hub

### 3.7 Verificar desde el MCP Hub

1. Ir a `https://localhost:9443/devportal` (o la sección MCP Hub si existe en 4.6.0)
2. Buscar `trazalog-equipos`
3. Confirmar que se listan dos tools: `get_equipos` y `get_equipo`

---

## 4. Test de humo desde cliente MCP

Con Claude Desktop conectado al server:

```
# Prompt de prueba
"Listar los equipos disponibles"
→ Debe invocar get_equipos sin pedir confirmación (readOnlyHint=true)

"Mostrar los datos del equipo COMP-001"
→ Debe invocar get_equipos para buscar el id, luego get_equipo con ese id
  Sin pedir confirmación en ninguno de los pasos (ambos readOnlyHint=true)
```

Configuración para Claude Desktop / VS Code:

```json
{
  "mcpServers": {
    "trazalog-equipos": {
      "url": "https://localhost:8243/trazalog-equipos/1.0/mcp",
      "headers": {
        "Authorization": "Bearer <JWT_DNATO>"
      }
    }
  }
}
```

> **Nota:** La URL exacta del endpoint MCP depende del contexto configurado en el paso 3.2.
> Verificar en el MCP Hub o en la pantalla de Deployments del Publisher.

---

## 5. Aislamiento multi-empresa

El server `trazalog-equipos` **no expone parámetro de empresa**.
El JWT Bearer del cliente determina la empresa:

- Token empresa A → `get_equipos` devuelve solo equipos de empresa A
- Token empresa B → `get_equipos` devuelve solo equipos de empresa B

El gateway extrae `empr_id` del claim JWT y lo inyecta internamente
vía `EmprIdInjectorPolicy` (E9-IDENT-05). El agente nunca lo ve ni lo pasa.
