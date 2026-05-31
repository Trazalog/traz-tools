# Virtual MCP Server — Equipos [E2-MCP-01]

**API fuente:** `doc/api/equipos.yaml` (publicada en E1-API-10)  
**Annotations standard:** `doc/mcp/tool-annotations-standard.md`  
**Estado:** Pendiente configuración en consola WSO2

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
- Ambas son SELECT puro sobre MySQL assetv2 sin efectos laterales → `readOnlyHint=true`.
- No inician procesos externos → `openWorldHint=false`.
- El mismo equipo devuelve los mismos datos en invocaciones sucesivas → `idempotentHint=true`.

---

## 3. Pasos de configuración en WSO2 API Manager 4.6.0

### 3.1 Prerequisito

La API `Equipos 1.0` debe estar publicada siguiendo `doc/api/openapi-publish-procedure.md §2`.
Verificar que aparece como `Published` en el Publisher.

### 3.2 Habilitar AI en la API

1. Ir a `https://localhost:9443/publisher`
2. Abrir la API **Equipos** (versión 1.0)
3. En el menú lateral izquierdo → click en **`AI`**
4. Click en **`Enable AI Capabilities`** (toggle)
5. En **`API Type`** → seleccionar **`MCP`**
6. En **`MCP Server Mode`** → seleccionar **`Virtual MCP Server`**
7. Click **`Save`**

### 3.3 Configurar el Virtual MCP Server

1. En la pestaña **`AI`** → sección **`MCP Server Configuration`**:
   - **Server Name:** `trazalog-equipos`
   - **Server Description:** `Acceso al catálogo de equipos industriales de Asset Planner. Consultar antes de crear una Orden de Trabajo.`
2. Click **`Save`**

### 3.4 Configurar tools por operación

#### Tool `get_equipos`

1. En **`AI`** → **`MCP Tool Configurations`** → operación `GET /mcp/equipos`
2. Verificar campos pre-llenados desde el OpenAPI spec:
   - **Tool Name:** `get_equipos`
   - **Description:** *(pre-llenada desde operationId/description del yaml)*
3. Configurar annotations:

| Annotation | Valor |
|---|---|
| `readOnlyHint` | ☑ **true** |
| `destructiveHint` | ☐ false |
| `idempotentHint` | ☑ **true** |
| `openWorldHint` | ☐ false |

4. Click **`Save`**

#### Tool `get_equipo`

1. Operación `GET /mcp/equipo/{equi_id}`
2. Verificar:
   - **Tool Name:** `get_equipo`
3. Annotations:

| Annotation | Valor |
|---|---|
| `readOnlyHint` | ☑ **true** |
| `destructiveHint` | ☐ false |
| `idempotentHint` | ☑ **true** |
| `openWorldHint` | ☐ false |

4. Click **`Save`**

### 3.5 Publicar el Virtual MCP Server

1. Click **`Publish`** en la esquina superior derecha
2. El estado de la API cambia a `Published`
3. El Virtual MCP Server `trazalog-equipos` aparece en el **MCP Hub**

### 3.6 Verificar desde el MCP Hub

1. Ir a `https://localhost:9443/mcp-hub`
2. Buscar `trazalog-equipos`
3. Confirmar que se listan dos tools: `get_equipos` y `get_equipo`
4. Copiar la configuración del server para Claude Desktop o VS Code:

```json
{
  "mcpServers": {
    "trazalog-equipos": {
      "url": "https://localhost:8243/equipos/1.0/mcp",
      "headers": {
        "Authorization": "Bearer <JWT_DNATO>"
      }
    }
  }
}
```

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

---

## 5. Aislamiento multi-empresa

El server `trazalog-equipos` **no expone parámetro de empresa**.
El JWT Bearer del cliente determina la empresa:

- Token empresa A → `get_equipos` devuelve solo equipos de empresa A
- Token empresa B → `get_equipos` devuelve solo equipos de empresa B

El gateway extrae `empr_id` del claim JWT y lo inyecta internamente
(E9-IDENT-05). El agente nunca lo ve ni lo pasa.
