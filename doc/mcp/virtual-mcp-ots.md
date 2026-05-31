# Virtual MCP Server — Órdenes de Trabajo [E2-MCP-02]

**API fuente:** `doc/api/ot.yaml` (publicada en E1-API-10)  
**Annotations standard:** `doc/mcp/tool-annotations-standard.md`  
**Estado:** Pendiente configuración en consola WSO2

---

## 1. Nombre del Virtual MCP Server

```
trazalog-ots
```

Nombre visible en el MCP Hub. Incluye la tool `create_ot` — el demo tool
central del Sprint 2 MCP MVP.

---

## 2. Tools del server

| Tool name | `operationId` fuente | `readOnlyHint` | `destructiveHint` | `idempotentHint` | `openWorldHint` | Descripción para el agente |
|---|---|---|---|---|---|---|
| `create_ot` | `create_ot` | ❌ `false` | ❌ `false` | ❌ `false` | ✅ `true` | Crea una Orden de Trabajo correctiva para un equipo con falla. Inicia el proceso de mantenimiento en el sistema BPM. Requiere el ID del equipo y una descripción de la falla. |
| `get_ots` | `get_ots` | ✅ `true` | ❌ `false` | ✅ `true` | ❌ `false` | Lista las Órdenes de Trabajo abiertas de la empresa (excluye cerradas y anuladas). Usar para verificar OTs existentes antes de crear una nueva. |
| `get_ot` | `get_ot` | ✅ `true` | ❌ `false` | ✅ `true` | ❌ `false` | Obtiene el detalle completo de una OT: estado, equipo, mantenedor asignado, fechas. Usar para confirmar que la OT recién creada se registró correctamente. |

**Justificación de annotations:**

- **`create_ot`:** `readOnlyHint=false` (INSERT en BD + inicio de proceso BPM). `openWorldHint=true` porque instancia un proceso en Bonita BPM — efecto externo real. `destructiveHint=false` porque crea datos nuevos sin destruir existentes y el proceso BPM puede cancelarse. `idempotentHint=false` porque cada invocación crea una OT distinta con un `id_solicitud` diferente.

- **`get_ots` / `get_ot`:** SELECT puro, sin efectos laterales → `readOnlyHint=true`, `openWorldHint=false`, `idempotentHint=true`.

---

## 3. Comportamiento del agente según annotations

| Situación | Comportamiento esperado del cliente MCP |
|---|---|
| Usuario: "¿qué OTs están abiertas?" | Invoca `get_ots` directamente, sin pedir confirmación |
| Usuario: "Muéstrame la OT 1842" | Invoca `get_ot` directamente, sin pedir confirmación |
| Usuario: "Crear una OT para el compresor COMP-001" | **Puede** mostrar los detalles al usuario antes de ejecutar (`openWorldHint=true`). Claude generalmente pregunta "¿Confirma crear la OT?" antes de invocar `create_ot` |
| Agente autónomo detecta falla | `create_ot` requiere aprobación humana explícita en flujos agenticos bien implementados |

---

## 4. Pasos de configuración en WSO2 API Manager 4.6.0

### 4.1 Prerequisito

La API `Ordenes de Trabajo 1.0` debe estar publicada siguiendo
`doc/api/openapi-publish-procedure.md §3`. Estado: `Published`.

### 4.2 Habilitar AI en la API

1. Ir a `https://localhost:9443/publisher`
2. Abrir la API **Ordenes de Trabajo** (versión 1.0)
3. Menú lateral → **`AI`**
4. **`Enable AI Capabilities`** → activar
5. **`API Type`** → `MCP`
6. **`MCP Server Mode`** → `Virtual MCP Server`
7. Click **`Save`**

### 4.3 Configurar el Virtual MCP Server

1. **`AI`** → **`MCP Server Configuration`**:
   - **Server Name:** `trazalog-ots`
   - **Server Description:** `Gestión de Órdenes de Trabajo correctivas en Asset Planner. Permite crear OTs para equipos con fallas y consultar el estado de las OTs existentes.`
2. Click **`Save`**

### 4.4 Configurar tools por operación

#### Tool `create_ot` — ⚠️ revisar con atención

1. **`AI`** → **`MCP Tool Configurations`** → operación `POST /mcp/ot`
2. Verificar:
   - **Tool Name:** `create_ot`
   - **Description:** *(pre-llenada desde el yaml — verificar que dice "Crea una OT correctiva...")*
3. Annotations:

| Annotation | Valor | Razón |
|---|---|---|
| `readOnlyHint` | ☐ **false** | INSERT en BD + inicia proceso BPM |
| `destructiveHint` | ☐ **false** | Crea datos nuevos, BPM proceso es cancelable |
| `idempotentHint` | ☐ **false** | Cada call crea una OT nueva con ID distinto |
| `openWorldHint` | ☑ **true** | Instancia proceso en Bonita BPM (efecto externo) |

4. Click **`Save`**

#### Tool `get_ots`

1. Operación `GET /mcp/ot`
2. Annotations:

| Annotation | Valor |
|---|---|
| `readOnlyHint` | ☑ **true** |
| `destructiveHint` | ☐ false |
| `idempotentHint` | ☑ **true** |
| `openWorldHint` | ☐ false |

3. Click **`Save`**

#### Tool `get_ot`

1. Operación `GET /mcp/ot/{id_solicitud}`
2. Annotations:

| Annotation | Valor |
|---|---|
| `readOnlyHint` | ☑ **true** |
| `destructiveHint` | ☐ false |
| `idempotentHint` | ☑ **true** |
| `openWorldHint` | ☐ false |

3. Click **`Save`**

### 4.5 Publicar el Virtual MCP Server

1. Click **`Publish`**
2. El server `trazalog-ots` aparece en el MCP Hub
3. Configuración para Claude Desktop:

```json
{
  "mcpServers": {
    "trazalog-ots": {
      "url": "https://localhost:8243/ordenes-trabajo/1.0/mcp",
      "headers": {
        "Authorization": "Bearer <JWT_DNATO>"
      }
    }
  }
}
```

---

## 5. Test de humo desde cliente MCP

### Flujo demo completo (combina trazalog-equipos + trazalog-ots)

```
# 1. Buscar el equipo (desde trazalog-equipos)
Prompt: "Listar equipos disponibles"
→ get_equipos (sin confirmación, readOnlyHint=true)
→ Devuelve lista con id_equipo="10" para COMP-001

# 2. Ver OTs existentes (sin confirmación)
Prompt: "¿Hay OTs abiertas para el compresor?"
→ get_ots (sin confirmación, readOnlyHint=true)
→ Devuelve lista filtrada por empresa (o vacía si no hay)

# 3. Crear OT (con confirmación del usuario por openWorldHint=true)
Prompt: "Abrir una OT para COMP-001, hay un ruido extraño en el rodamiento"
→ Claude muestra: "Voy a crear una OT con estos datos:
    - Equipo: COMP-001 (id: 10)
    - Descripción: Ruido extraño en rodamiento
    ¿Confirmas?"
→ Usuario: "Sí"
→ create_ot con { equipo_id: "10", descripcion: "Ruido extraño en rodamiento" }
→ Devuelve: { ot_id: "1842", case_id: "5301", estado: "S" }

# 4. Confirmar la OT creada (sin confirmación)
Prompt: "Confirmá que la OT se creó"
→ get_ot con id_solicitud="1842"
→ Devuelve detalle con estado="S", equipo="COMP-001"
```

### Verificaciones de aislamiento

```bash
# OTs de empresa A con token empresa A → OTs de A
curl -k -H "Authorization: Bearer $JWT_EMPRESA_A" \
     https://localhost:8243/ordenes-trabajo/1.0/mcp/ot

# OTs de empresa A con token empresa B → lista vacía
curl -k -H "Authorization: Bearer $JWT_EMPRESA_B" \
     https://localhost:8243/ordenes-trabajo/1.0/mcp/ot
# Expect: { "solicitudes": { "solicitud": [] } }

# create_ot con token empresa A → OT creada en empresa A (no en B)
curl -k -X POST \
     -H "Authorization: Bearer $JWT_EMPRESA_A" \
     -H "Content-Type: application/json" \
     -d '{"equipo_id":"10","descripcion":"Test aislamiento"}' \
     https://localhost:8243/ordenes-trabajo/1.0/mcp/ot
```

---

## 6. Aislamiento multi-empresa

Misma garantía que en `trazalog-equipos`:

- El JWT Bearer determina la empresa — no existe parámetro de empresa en la interfaz del agente
- `create_ot` inserta en la empresa del JWT, no en ninguna empresa pasada por el agente
- `get_ots` y `get_ot` solo devuelven datos de la empresa del JWT

Ver implementación en E9-IDENT-05 (gateway) y E9-IDENT-06 (DataService).

---

## 7. Nota sobre el rollback

Si `create_ot` falla después del INSERT (Bonita no disponible):

- La solicitud en la BD se elimina automáticamente (Opción A, aprobada en ADR-003)
- El agente recibe un error HTTP 500 desde el gateway
- La OT no queda en estado inconsistente
- El agente puede reintentar si el usuario lo solicita
