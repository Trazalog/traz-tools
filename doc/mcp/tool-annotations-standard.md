# Estándar de Annotations para MCP Tools — Trazalog v3

**Versión:** 1.0  
**Fecha:** 2026-05  
**Aplica a:** Todos los Virtual MCP Servers publicados en WSO2 API Manager 4.6.0

---

## 1. Qué son las annotations

Las annotations son metadatos que el MCP Gateway adjunta a cada tool definition.
Los MCP clients (Claude, ChatGPT, Copilot) las usan para:

- Decidir si confirmar una acción con el usuario antes de ejecutarla
- Detectar tools potencialmente peligrosas o irreversibles
- Optimizar el plan de ejecución del agente

Son **hints** (sugerencias), no restricciones técnicas. El agente puede
ignorarlas, pero los clientes bien implementados las respetan.

---

## 2. Annotations disponibles (MCP spec 2025-11-05)

| Annotation | Tipo | Descripción |
|---|---|---|
| `readOnlyHint` | `boolean` | `true` si la tool no modifica estado. El agente puede invocarla sin confirmación del usuario. |
| `destructiveHint` | `boolean` | `true` si la tool puede causar cambios irreversibles (solo relevante cuando `readOnlyHint=false`). El cliente debe pedir confirmación explícita. |
| `idempotentHint` | `boolean` | `true` si invocarla múltiples veces con los mismos parámetros produce el mismo resultado. |
| `openWorldHint` | `boolean` | `true` si la tool interactúa con sistemas externos fuera de Trazalog (envía emails, inicia procesos BPM, hace pagos). |

---

## 3. Criterios de asignación para Trazalog

### 3.1 `readOnlyHint`

| Valor | Cuándo usar |
|---|---|
| `true` | Operaciones GET o consultas SQL puras que no modifican ninguna tabla |
| `false` | Cualquier operación que inserta, actualiza, elimina o desencadena procesos |

**Regla:** Si hay un DataService con `INSERT`, `UPDATE`, o `DELETE`, o si la sequence llama a un proceso BPM → `readOnlyHint=false`.

### 3.2 `destructiveHint`

| Valor | Cuándo usar |
|---|---|
| `true` | Eliminaciones físicas, envío de comunicaciones externas (emails, WhatsApp), cierres definitivos de proceso, acciones con consecuencias legales |
| `false` | Creación de datos (INSERT), actualizaciones reversibles, inicio de procesos BPM que pueden cancelarse |

**Regla MVP:** Solo `destructiveHint=true` para operaciones DELETE. Crear una OT inicia un proceso BPM pero es cancelable → `destructiveHint=false`.

### 3.3 `idempotentHint`

| Valor | Cuándo usar |
|---|---|
| `true` | GET puro o UPSERT (mismo resultado si se llama múltiples veces) |
| `false` | INSERT que crea una fila nueva por invocación (ej: create_ot crea una OT nueva cada vez) |

### 3.4 `openWorldHint`

| Valor | Cuándo usar |
|---|---|
| `true` | La operación inicia un proceso BPM, envía una notificación, hace una llamada a un sistema externo |
| `false` | La operación solo lee/escribe en la BD de Trazalog sin efectos externos |

**Regla:** Cualquier operación que llame a `bpmAPICallTemplate` o a servicios de Bonita → `openWorldHint=true`.

---

## 4. Tabla de referencia rápida por patrón de operación

| Patrón | `readOnly` | `destructive` | `idempotent` | `openWorld` |
|---|---|---|---|---|
| `get_*` (SELECT puro) | `true` | `false` | `true` | `false` |
| `create_*` (INSERT solo) | `false` | `false` | `false` | `false` |
| `create_*` + BPM | `false` | `false` | `false` | `true` |
| `update_*` (UPDATE reversible) | `false` | `false` | `true` | `false` |
| `delete_*` (DELETE lógico/físico) | `false` | `true` | `true` | `false` |
| `send_*` / `notify_*` | `false` | `true` | `false` | `true` |

---

## 5. Cómo configurar annotations en WSO2 API Manager 4.6.0

Las annotations se configuran por operación en la pestaña **AI** de cada API en el Publisher:

```
Publisher → [API] → AI → MCP Tool Configurations → [Operación]
  ├── Tool Name: (pre-llenado desde operationId del OpenAPI spec)
  ├── Description: (pre-llenado desde description del OpenAPI spec)
  └── Annotations:
        ├── readOnlyHint: ☐ / ☑
        ├── destructiveHint: ☐ / ☑
        ├── idempotentHint: ☐ / ☑
        └── openWorldHint: ☐ / ☑
```

Ver procedimiento completo en cada `doc/mcp/virtual-mcp-<entidad>.md`.

---

## 6. Relación con las descripciones del OpenAPI spec

Las annotations son independientes de las descripciones semánticas en el OpenAPI.
Ambas son necesarias:

| Campo | Fuente | Función |
|---|---|---|
| `description` (operación) | OpenAPI spec | Claude decide **cuándo** invocar la tool |
| Annotations | Consola WSO2 | Claude decide **cómo** invocarla (con/sin confirmación) |

Las descripciones se mantienen en `doc/api/equipos.yaml` y `doc/api/ot.yaml`.
Las annotations se documenta en cada `virtual-mcp-*.md`.

---

## 7. Revisión y actualización

Revisar annotations cuando:
- Se agrega una operación nueva a una API MCP
- Una operación pasa de solo-lectura a incluir escritura
- Una operación se conecta con un sistema externo nuevo
- Se recibe feedback de que el agente no está pidiendo confirmaciones cuando debería

Versión del estándar: `1.0` — actualizar con fecha cuando se modifique.
