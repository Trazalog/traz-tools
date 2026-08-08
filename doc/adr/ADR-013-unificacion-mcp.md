# ADR-013 — Unificación de MCP: fachada única toolsMCPAPI

- **Estado:** Aceptado
- **Fecha:** 2026-07-31
- **Contexto de decisión:** Workshop CW + Rodolfo (Sprint 3), sobre el relevamiento E2-MCP-10-RELEV
- **Relacionado:** ADR-002 (maximizar Virtual MCP autogenerados, minimizar Python/FastMCP), ADR-009 (identidad X-JWT-Assertion), ADR-012 (almacenes)

---

## Contexto

En el Sprint 2 se crearon **dos Virtual MCP Servers separados** (`trazalog-equipos`, `trazalog-ots`), cada uno sobre su propia API en el Publisher, aunque ambos apuntan al mismo backend MI (`toolsMANAPI`, context `/tools/man`). Con la incorporación de almacenes (ADR-012), tener un Virtual MCP Server por módulo se vuelve incómodo: el cliente tendría que conectar varios connectors en Claude.ai.

El relevamiento E2-MCP-10-RELEV (`doc/v3/relevamiento-unificacion-mcp.md`) confirmó contra la documentación oficial de WSO2 4.6.0 y contra los artefactos reales del repo:

- **Un Virtual MCP Server no puede componerse desde varias APIs distintas.** El wizard de 4.6 exige una sola API (o una sola OpenAPI) como fuente. No hay mecanismo nativo para agrupar operaciones de APIs separadas.
- Por lo tanto, "un solo MCP Server con todo" solo se logra **consolidando las operaciones en una sola API WSO2** y generando el MCP Server desde ella (Opción A del relevamiento).
- Las otras opciones se descartaron: la B (dejar los viejos, unificar solo lo nuevo) no unifica de verdad; la C (proxy Python/FastMCP) contradice ADR-002 y suma latencia de doble salto sin necesidad.

---

## Decisión

Se crea una **API MI única `toolsMCPAPI` que actúa como fachada DELGADA de la capa MCP**: resuelve el `empr_id` del contexto una sola vez y rutea cada tool al DataService o lógica de negocio que ya existe, sin duplicar lógica. Desde esa API única se genera **un solo Virtual MCP Server** (`trazalog-operaciones` o nombre a confirmar) que expone todas las tools (mantenimiento + almacenes), con nombres prefijados por módulo.

### Decisiones puntuales

| # | Decisión | Justificación |
|---|---|---|
| 1 | **Fachada DELGADA, no gruesa** | `toolsMCPAPI` hace una sola cosa transversal: resolver `empr_id` del `X-JWT-Assertion` (sequence `EmprIdFromHeader`, ADR-009) y rutear a la lógica existente (`MANDataService`, `ALMDataService`, patrón BPM+rollback de `create_ot`). NO reimplementa la lógica de negocio — evita duplicación y dos lugares que mantener |
| 2 | **Rutas internas prefijadas por módulo** | `/mcp/man/equipos`, `/mcp/man/ot`, `/mcp/alm/pedidos`, etc. La estructura por módulo vive en las rutas REST internas de la API fuente, que determinan de qué operación sale cada tool |
| 3 | **Nombres de tools con prefijo de módulo explícito** | `man_get_equipos`, `man_create_ot`, `alm_get_pedidos`, `alm_crear_pedido`, etc. Más claro para el agente y a prueba de colisiones futuras entre módulos. Es decisión de diseño (no restricción técnica) |
| 4 | **Un solo Virtual MCP Server** generado desde `toolsMCPAPI` | Reemplaza a `trazalog-equipos` + `trazalog-ots`. Almacenes nace directamente acá, no como server propio (deja sin efecto la tarea 3.3 de crear `trazalog-almacenes` separado del artefacto de prompts) |
| 5 | **Migración coordinada, sin corte en seco** | Se crea el unificado, se prueba completo (smoke test de las 5 tools actuales + las de almacenes), se reconfigura Claude.ai a la URL nueva, y RECIÉN ahí se despublican los viejos. Los servers viejos y el nuevo conviven durante la ventana de migración |
| 6 | **La fachada rutea a múltiples DataServices** — a verificar en el primer paso de implementación | Un artefacto MI puede orquestar hacia N DataServices (comportamiento normal de WSO2 MI), pero el relevamiento no lo confirmó en vivo. La primera tarea de implementación lo verifica con una prueba mínima ANTES de construir todo encima; si no diera, se escala (parada obligatoria) |

---

## Arquitectura resultante

```
Claude.ai ──JWT──> APIM (valida, firma X-JWT-Assertion)
                    ──> Virtual MCP Server ÚNICO (trazalog-operaciones)
                          │ generado desde la API toolsMCPAPI
                          ▼
                    toolsMCPAPI (fachada delgada, MI)
                      │ EmprIdFromHeader resuelve empr_id UNA vez
                      ├─ /mcp/man/... → MANDataService / BPM create_ot
                      └─ /mcp/alm/... → ALMDataService / BPM crear_pedido
```

Tools expuestas (nombres con prefijo):
- `man_get_equipos`, `man_get_equipo`, `man_get_ots`, `man_get_ot`, `man_create_ot`
- `alm_get_stock` (o equivalente), `alm_get_pedidos_materiales`, `alm_get_pedido_material`, `alm_crear_pedido_materiales`

---

## Consecuencias

### Positivas
- **Un solo connector para el cliente** en Claude.ai — el objetivo de fondo.
- Fachada delgada = separa limpiamente la capa MCP de las APIs de negocio (hoy `toolsMANAPI` mezcla recursos MCP con uno no-MCP, `/solicitudServicio`; la fachada lo evita).
- No duplica lógica ni contradice ADR-002 (sin Python/FastMCP nuevo).
- Prefijos por módulo = claridad para el agente y sin colisiones futuras.

### Negativas / riesgos aceptados
- **Hay que migrar la config de Claude.ai** de la demo a la URL nueva (paso manual, coordinable). Riesgo bajo si se respeta el orden (crear→probar→migrar→deprecar).
- **Trabajo de reorganización en el MI**: crear `toolsMCPAPI` y mover/rutear los recursos MCP existentes bajo la nueva estructura. Los servers viejos no se tocan hasta que el nuevo esté probado.
- **Pregunta abierta #1 del relevamiento** (ruteo a múltiples DataServices) se resuelve en implementación, no antes — con parada obligatoria si falla.

---

## Alternativas descartadas

- **Opción B (dejar equipos/ots, unificar solo lo nuevo):** no unifica de verdad — quedarían 2+ MCP Servers, contradice el objetivo.
- **Opción C (proxy Python/FastMCP):** contradice ADR-002; suma latencia de doble salto y capa operativa nueva sin necesidad, ya que la fachada MI logra lo mismo sin código nuevo.
- **Fachada gruesa (reimplementar lógica):** duplica lo que ya existe en los DataServices y el patrón create_ot; dos lugares que mantener.

---

## Preguntas abiertas (a resolver en implementación, no bloquean el ADR)

- ~~Nombre definitivo del Virtual MCP Server unificado~~ **Resuelto (2026-08-08):** Rodolfo publicó la API/MCP Server como **`Trazalog MCP Server`**, contexto **`/trazalog/mcp`**, versión `1.0` — no `trazalog-operaciones` como se sugería acá. Endpoint MCP: `https://<host-apim>:8243/trazalog/mcp/1.0/mcp`. Ver `doc/mcp/virtual-mcp-unificado.md` §2.6/§2.9.
- Confirmar el ruteo a múltiples DataServices desde un artefacto MI (decisión #6) — primera tarea de implementación.
- Si conviene que la fachada mantenga el backend MI separado por módulo o fusionado (pregunta abierta #1 del relevamiento) — se decide al implementar, según lo que dé la verificación.
