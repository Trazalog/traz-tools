# ADR-012 — Almacenes: aislamiento multi-tenant y alcance de tools MCP

- **Estado:** Aceptado
- **Fecha:** 2026-07-28
- **Contexto de decisión:** Workshop CW + Rodolfo (Sprint 3)
- **Relacionado:** ADR-009 (mecanismo de identidad vigente, X-JWT-Assertion), ADR-003 (mapeo PHP→WSO2)

---

## Contexto

El Sprint 3 incorpora el módulo de Almacenes al conjunto de tools MCP. Hoy hay 0 tools de almacenes. El relevamiento (`doc/v3/sprint-3-relevamiento-estado.md`) detectó un **gap de seguridad**: el `ALMDataService` filtra por empresa a nivel SQL, pero recibe el `empr_id` como **parámetro del caller**, no derivado del JWT. Exponerlo así violaría la regla de oro del proyecto (el `empr_id` nunca lo pone el agente) y, al haber escritura, permitiría a un agente operar sobre datos de otra empresa.

Dos hechos, confirmados por el PM en el workshop, simplifican la decisión:

1. **`ALMDataService` es arquitectónicamente idéntico a `MANDataService`**: hace lectura y escritura directamente contra la BD, sin lógica de negocio en un módulo PHP intermedio. El mismo patrón de identidad aplica sin adaptaciones.
2. **El alcance de escritura del piloto es mínimo y no toca stock**: la única operación de escritura es *crear un pedido de materiales*, que es una solicitud (dispara un flujo BPM), NO un movimiento de inventario. No suma ni resta stock, no hace ajustes.

---

## Decisión

Las tools de Almacenes se exponen reusando **exactamente los mismos patrones ya probados en Mantenimiento** — identidad ADR-009 y orquestación con BPM+rollback estilo `create_ot`. No se introduce ningún mecanismo nuevo.

### Alcance de tools para el piloto

| Tool | Tipo | Análoga a | Notas |
|---|---|---|---|
| `get_stock` (o equivalente: consultar stock/artículos/movimientos) | Lectura | `get_equipos` | Filtrada por `empr_id` del JWT |
| `get_pedidos_materiales` | Lectura | `get_ots` | Lista los pedidos de la empresa |
| `get_pedido_material` | Lectura | `get_ot` | Detalle de un pedido; vacío si es de otra empresa |
| `crear_pedido_materiales` | Escritura | `create_ot` | Dispara proceso BPM en Bonita con el mismo patrón de sequence + rollback. NO toca stock |

**Fuera de alcance del piloto (backlog):** sumar/restar stock, ajustes de inventario, valorización, gestión de lotes. Cualquier operación que modifique cantidades de inventario queda explícitamente excluida.

### Decisiones puntuales

| # | Decisión | Justificación |
|---|---|---|
| 1 | **Aislamiento vía ADR-009**: el `empr_id` se deriva del `X-JWT-Assertion` firmado por el APIM; el MI lo inyecta con la sequence `EmprIdFromHeader`. El wrapper `toolsALMAPI` NUNCA acepta `empr_id` como parámetro | Idéntico a Mantenimiento. Cierra el gap de seguridad detectado en el relevamiento. Reusa código probado |
| 2 | **`crear_pedido_materiales` usa el patrón de orquestación de `create_ot`**: sequence de mediación con INSERT → instancia BPM en Bonita → rollback (DELETE) si Bonita falla | El PM confirmó que el pedido dispara un proceso Bonita igual que `create_ot`. Mismo patrón, mismo rollback ya probado |
| 3 | **`crear_pedido_materiales` pide confirmación explícita del usuario** antes de ejecutar (annotation tipo `openWorldHint`, como `create_ot`) | Es una escritura que inicia un proceso externo. Aunque no toca stock, iniciar un pedido es una acción con efecto en el mundo real (alguien va a tener que atender ese pedido) |
| 4 | **Sin validación de stock negativo ni lógica de inventario** | Un pedido de materiales no mueve stock — es una solicitud. Las validaciones de inventario no aplican a este alcance |
| 5 | **Virtual MCP Server propio: `trazalog-almacenes`** | Coherente con la separación por módulo (`trazalog-equipos`, `trazalog-ots`). Patrón de URL `/trazalog-almacenes/1.0/mcp` |

---

## Flujo resultante (idéntico a Mantenimiento)

```
Claude.ai ──JWT──> APIM (valida, firma X-JWT-Assertion)
                    ──> MI (EmprIdFromHeader deriva empr_id)
                    ──> toolsALMAPI:
                          - lecturas: ALMDataService con WHERE empr_id = :empr_id
                          - crear_pedido_materiales: INSERT + BPM Bonita + rollback
```

---

## Consecuencias

### Positivas
- **Riesgo bajo**: no se inventa arquitectura, se replica un patrón probado en producción (Mantenimiento).
- Cierra el gap de seguridad del relevamiento antes de exponer cualquier tool.
- Alcance acotado = implementación rápida y superficie de error chica.
- El cliente minero obtiene consulta de inventario + capacidad de pedir materiales desde Claude, que es valor concreto para su operación.

### Negativas / riesgos aceptados
- **El alcance no cubre operaciones de stock** (entradas/salidas/ajustes). Es una limitación consciente del piloto; si el cliente las pide, es material de un sprint futuro con su propio ADR (ahí sí volverían las validaciones de inventario que este ADR descarta).

---

## Preguntas abiertas (a resolver en la implementación, no bloquean el ADR)

- Nombres exactos de las queries de lectura en `ALMDataService` (stock, artículos, movimientos) → Claude Code las releva del DataService existente al implementar E1-ALM-01.
- Estructura exacta del payload de `crear_pedido_materiales` (qué campos: artículo, cantidad, depósito, etc.) → se define contra el `ALMDataService` real y el proceso Bonita correspondiente.

---

## Alternativas descartadas

- **Pasar `empr_id` como parámetro (como está hoy):** descartado — es el gap de seguridad que este ADR resuelve.
- **Incluir operaciones de stock en el piloto:** descartado por decisión del PM — fuera de alcance; agrega complejidad (validaciones de inventario) sin ser necesario para la primera sesión con el cliente.
