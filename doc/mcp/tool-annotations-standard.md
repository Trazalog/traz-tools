# Tool Annotations Standard — MCP Trazalog v3

Estándar obligatorio para todas las tools MCP de Trazalog v3.

**Origen:** sección 10.5 del DDR-004 (MCP Architecture Doc). La omisión de
`readOnlyHint` y `destructiveHint` causa el 30% de los rechazos en el
Connectors Directory de Claude. Este estándar se aplica desde el primer commit.

---

## Las dos annotations obligatorias

### `readOnlyHint: true`

Indica que la tool **solo lee datos** — no crea, no modifica, no elimina,
no tiene side effects observables en el sistema.

**Cuándo aplicar:** consultas, listados, búsquedas, cálculos de KPIs, reportes.

### `destructiveHint: true`

Indica que la tool **modifica el estado del sistema** — puede crear registros,
actualizar datos, cancelar operaciones, enviar notificaciones, o desencadenar
procesos que no se pueden deshacer sin intervención explícita.

**Cuándo aplicar:** creaciones, modificaciones, cancelaciones, envíos,
activaciones, cualquier acción que persiste en la base de datos.

> **Regla:** toda tool tiene exactamente una de las dos. Nunca ambas, nunca ninguna.

---

## Árbol de decisión para tools futuras

Ante una tool nueva, responder en orden:

```
1. ¿La tool escribe, modifica o elimina algo en la BD?
   ├── SÍ → destructiveHint: true
   └── NO → continuar

2. ¿La tool envía un mensaje, email, notificación o dispara un proceso externo?
   ├── SÍ → destructiveHint: true
   └── NO → continuar

3. ¿La tool solo lee datos (consulta, listado, búsqueda, cálculo)?
   └── SÍ → readOnlyHint: true
```

Si después de las tres preguntas hay duda, la regla conservadora es `destructiveHint: true`.

---

## Clasificación — Tools Phase 1

| Tool | Annotation | Razón |
|---|---|---|
| `get_equipment` | `readOnlyHint: true` | Consulta catálogo de equipos — solo lectura |
| `get_ot` | `readOnlyHint: true` | Consulta órdenes de trabajo — solo lectura |
| `get_kpis` | `readOnlyHint: true` | Calcula MTBF/MTTR/Disponibilidad — solo lectura |
| `get_stock` | `readOnlyHint: true` | Consulta stock en depósito — solo lectura |
| `get_preventivos` | `readOnlyHint: true` | Lista preventivos vencidos/próximos — solo lectura |
| `create_ot` | `destructiveHint: true` | Crea una OT en la BD — escribe datos |

---

## Implementación en FastMCP (Python — Fase 2+)

Solo para tools que requieran Python (IA/ML, procesamiento no-estructurado — ver ADR-002).

### Tool de solo lectura

```python
from fastmcp import FastMCP

mcp = FastMCP("trazalog-mcp-server")

@mcp.tool(annotations={"readOnlyHint": True})
def get_equipment(cliente_id: int, estado: str = "activo") -> dict:
    """
    Devuelve el catálogo de equipos de un cliente.
    Filtros opcionales: estado (activo, inactivo, todos).
    """
    # Llama al endpoint REST de WSO2 APIM
    ...
```

### Tool con side effects

```python
@mcp.tool(annotations={"destructiveHint": True})
def create_ot(
    equipo_id: int,
    descripcion: str,
    tipo: str,
    prioridad: str = "normal"
) -> dict:
    """
    Crea una orden de trabajo correctiva en Asset Planner.
    Tipos válidos: correctiva, mejora. Prioridades: baja, normal, alta, crítica.
    """
    # Llama al endpoint REST de WSO2 APIM — escribe en BD
    ...
```

---

## Implementación en WSO2 Virtual MCP Server

Para tools generadas automáticamente desde OpenAPI specs (modo principal — ADR-002),
las annotations se configuran en la definición del MCP Server en el Publisher de WSO2 APIM.

En el archivo de configuración del Virtual MCP Server (JSON exportable desde el Publisher):

```json
{
  "mcpServer": {
    "tools": [
      {
        "name": "get_equipment",
        "description": "Devuelve el catálogo de equipos de un cliente.",
        "operationId": "getEquipment",
        "annotations": {
          "readOnlyHint": true,
          "destructiveHint": false
        }
      },
      {
        "name": "create_ot",
        "description": "Crea una orden de trabajo correctiva en Asset Planner.",
        "operationId": "createOT",
        "annotations": {
          "readOnlyHint": false,
          "destructiveHint": true
        }
      }
    ]
  }
}
```

Verificar que el campo `annotations` aparezca en el JSON que devuelve `tools/list`
al conectarse con MCP Inspector (Etapa 1 del testing workflow — ver
[`doc/infra/testing-workflow.md`](../infra/testing-workflow.md)).

---

## Checklist de compliance antes de hacer PR

- [ ] La tool tiene exactamente una annotation: `readOnlyHint: true` o `destructiveHint: true`
- [ ] La annotation es correcta según el árbol de decisión de este documento
- [ ] MCP Inspector muestra la annotation en el schema de `tools/list`
- [ ] La annotation aparece en la documentación de la tool en el MCP Hub

---

## Referencias

- MCP Specification — Tool Annotations: https://modelcontextprotocol.io/docs/concepts/tools#annotations
- WSO2 MCP Gateway docs: https://apim.docs.wso2.com/en/latest/mcp-gateway/overview/
- Testing workflow: [`doc/infra/testing-workflow.md`](../infra/testing-workflow.md)
- Arquitectura MCP Trazalog v3: [`doc/v3/TRAZALOG_v3_MCP_ARCHITECTURE.md`](../v3/TRAZALOG_v3_MCP_ARCHITECTURE.md)
