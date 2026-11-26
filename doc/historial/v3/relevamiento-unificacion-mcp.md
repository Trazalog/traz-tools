# Relevamiento — Unificación de Virtual MCP Servers (E2-MCP-10-RELEV)

> Tarea: E2-MCP-10-RELEV — Bloque 0 de `doc/v3/sprint-3-prompts.md`. Clase 🟢 (relevamiento, no modifica nada).
> Objetivo: responder con datos reales dos preguntas técnicas para que CW + Rodolfo cierren el **ADR-013 (unificación MCP)** sin adivinar. Este documento NO implementa la unificación.

---

## Metodología y limitación honesta

Claude Code (esta sesión) **no tiene acceso a la consola WSO2 APIM real** (ni credenciales, ni red hacia la VM de GCP ni hacia el DEV de Rodolfo) — no pudo "entrar y mirar" en vivo, a pesar de que el prompt de la tarea lo pedía. Para no adivinar, esta investigación se apoya en dos fuentes que sí son verificables:

1. **Documentación oficial de WSO2 API Manager 4.6.0** (`apim.docs.wso2.com/en/4.6.0/...`), consultada activamente para esta tarea, citada con URL.
2. **Artefactos y documentación YA EXISTENTES en este repo** que registran configuración REAL hecha en esa misma consola durante el Sprint 2 (`doc/mcp/virtual-mcp-equipos.md`, `doc/mcp/virtual-mcp-ots.md`, `doc/api/openapi-publish-procedure.md`, y los fuentes WSO2 MI en `_backend/api/ToolsAPIProject/.../artifacts/apis/`). Estos no son "documentación genérica del producto" — son el registro de lo que Rodolfo/CW efectivamente configuraron y verificaron en este entorno.

Donde estas dos fuentes no alcanzan para responder con certeza, lo marco explícitamente como pregunta abierta (sección final), en vez de inventar.

---

## Pregunta 1 — ¿Se puede agrupar varias APIs en un solo Virtual MCP Server?

### Respuesta corta: no, no de forma directa. El wizard de WSO2 4.6.0 exige una sola API como fuente.

**Lo que dice la documentación oficial** (verificado contra `apim.docs.wso2.com/en/4.6.0/ai-gateway/mcp-gateway/overview/`): WSO2 API Manager 4.6.0 ofrece exactamente **tres** caminos para crear un MCP Server:

1. **From OpenAPI Definition** — "Generate tools and configuration from an existing OpenAPI" (una sola spec OpenAPI).
2. **From Existing API** — "Select an **API** already in APIM and convert operations into MCP tools" (singular: se selecciona UNA API, y de ahí un subconjunto de sus operaciones).
3. **Proxy External MCP Server** — "Wrap an external MCP server for governance, security, and analytics."

Ninguno de los tres caminos menciona **API Products** (el mecanismo nativo de WSO2 para combinar recursos de varias APIs en un consumible único) como fuente válida para generar un MCP Server. La documentación no dice "no se puede" en esas palabras, pero tampoco ofrece ningún mecanismo para combinar operaciones de APIs *distintas* en un solo MCP Server — el flujo 2 (el que usamos en Sprint 2) opera sobre **una** API, seleccionando un subconjunto de **sus propias** operaciones.

**Lo que confirma el entorno real (Sprint 2):** `doc/mcp/virtual-mcp-equipos.md` y `doc/mcp/virtual-mcp-ots.md` documentan que se crearon **dos APIs separadas** en el Publisher (`EquiposAPI-TrazalogMCP` y `OrdenesdeTrabajoAPI-TrazalogMCP`), cada una con su **propio** Virtual MCP Server (`trazalog-equipos`, `trazalog-ots`) — a pesar de que ambas apuntan al **mismo backend MI** (`http://<host>:8280/tools/man`, ver `doc/api/openapi-publish-procedure.md` líneas 77-80 y 152-153). Si WSO2 4.6.0 permitiera agrupar varias APIs en un MCP Server, este habría sido el caso ideal para hacerlo (mismo backend, mismo dominio funcional) — y no se hizo así, lo cual es consistente con que el wizard no lo permite.

### El camino real para lograr el objetivo (un solo MCP Server con tools de man+alm)

No se logra combinando *APIs* distintas en un MCP Server. Se logra **consolidando las operaciones en UNA sola API de WSO2** (con las rutas prefijadas por módulo dentro de esa única API, ej. `/mcp/man/equipos`, `/mcp/man/ot`, `/mcp/alm/pedidos`) y generando el MCP Server **desde esa API única**. Hay precedente arquitectónico de esto en el propio repo: a nivel del **MI** (no del Publisher), `toolsMANAPI.xml` (context `/tools/man`) ya implementa los recursos de **equipos y OTs juntos** dentro de un mismo artefacto WSO2 — la consolidación por módulo dentro de una sola API ya se practica, solo que hoy se corta en dos APIs distintas recién al nivel del Publisher/MCP Server.

### Aclaración importante sobre "prefijos por URL"

El Virtual MCP Server expone **una sola URL** (`https://<host>/<nombre-del-server>/1.0/mcp` — ver `doc/v3/CONTEXT-PACK.md` §4, ya confirmado en los dos servers existentes). El protocolo MCP no rutea por path después de esa URL única: los tool calls van todos por JSON-RPC (`tools/call` con un parámetro `name`), no por URLs distintas por tool. Es decir: **no existe un "prefijo de URL" navegable por el agente dentro del MCP Server** — lo que sí puede (y hoy ya) llevar prefijo/estructura por módulo son:
- Las **rutas REST internas** de la API fuente (`/mcp/man/...`, `/mcp/alm/...`), que determinan de qué operación sale cada tool.
- Los **nombres de las tools** generadas (`get_equipos`, `get_pedido_material`, etc.) — hoy no llevan prefijo (`man_`, `alm_`), simplemente son nombres únicos por dominio. Si al unificar se quiere namespacing explícito en el nombre de la tool, es una decisión de diseño (no una restricción técnica), a definir en el ADR-013.

---

## Pregunta 2 — ¿Cómo están estructuradas HOY las APIs con recursos MCP de mantenimiento?

### A nivel MI (backend real): una sola API, con recursos MCP y no-MCP mezclados

`_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/apis/toolsMANAPI.xml` (context `/tools/man`) es **una única API WSO2 MI** que implementa:
- `GET /mcp/equipo/{equi_id}` — MCP
- `GET /mcp/equipos` — MCP
- `POST /mcp/ot` — MCP (create_ot, con BPM + rollback)
- `GET /mcp/ot` — MCP
- `GET /mcp/ot/{id_solicitud}` — MCP
- `POST /solicitudServicio?bpmSession={bpmSession}` — **NO es MCP**, es un recurso preexistente (probablemente ligado al flujo BPM/v2 anterior a la capa MCP; no se investigó su consumidor actual, fuera de alcance de esta tarea).

Es decir: a nivel MI, los recursos `/mcp/*` de mantenimiento (equipos + OTs) **conviven en la misma API** que al menos un recurso no-MCP. No es una API "limpia" dedicada 100% a MCP en este nivel.

### A nivel APIM/Publisher (la capa que se virtualiza como MCP Server): dos APIs dedicadas, creadas específicamente para MCP

`doc/api/equipos.yaml` (`Equipos API — Trazalog MCP`) y `doc/api/ot.yaml` (`Órdenes de Trabajo API — Trazalog MCP`) son **dos specs OpenAPI separadas**, publicadas como **dos APIs independientes** en el Publisher (`EquiposAPI-TrazalogMCP`, `OrdenesdeTrabajoAPI-TrazalogMCP` — ver `doc/api/openapi-publish-procedure.md`, tarea E1-API-10). Ninguna de las dos es una API de v2 reutilizada — **ambas se crearon nuevas, específicamente para exponer MCP** (por eso el sufijo `-TrazalogMCP` en el nombre). Cada una solo incluye en su spec las operaciones `/mcp/*` que le corresponden — el recurso no-MCP `/solicitudServicio` del MI **no está expuesto** en ninguna de las dos.

Ambas APIs, aunque separadas a nivel Publisher, apuntan al **mismo backend MI** (`http://<host>:8280/tools/man`, el mismo `toolsMANAPI`). Por eso hoy hay **2 Virtual MCP Servers** (`trazalog-equipos`, `trazalog-ots`) sobre un único backend compartido.

### Resumen de la estructura real

| Capa | Equipos + OTs |
|---|---|
| MI (`toolsMANAPI.xml`, `/tools/man`) | **Una sola API**, mezcla recursos `/mcp/*` de ambos dominios + 1 recurso no-MCP (`/solicitudServicio`) |
| Publisher/APIM | **Dos APIs separadas**, creadas nuevas para MCP (`EquiposAPI-TrazalogMCP`, `OrdenesdeTrabajoAPI-TrazalogMCP`), cada una con su propio Virtual MCP Server |

---

## Opciones de unificación

### Opción A — Consolidar en una sola API WSO2 (Publisher) con rutas prefijadas por módulo, y generar UN Virtual MCP Server desde ahí

Fusionar `equipos.yaml` + `ot.yaml` + la futura spec de almacenes en **una sola** spec OpenAPI (rutas del estilo `/mcp/man/equipos`, `/mcp/man/ot`, `/mcp/alm/pedidos`), publicarla como **una** API en el Publisher, y generar **un único** Virtual MCP Server desde ella (ej. `trazalog-operaciones`).

- **Pros:** es el único camino soportado nativamente por el producto según la Pregunta 1 (1 API → 1 MCP Server); reusa exactamente el patrón ya probado en Sprint 2 (selección de operaciones desde una API); no requiere componentes nuevos (Python/FastMCP).
- **Contras:** implica **deprecar** `trazalog-equipos` y `trazalog-ots` (y sus URLs actuales) — hay que migrar la config de Claude.ai de la demo a la URL nueva. También implica trabajo en el MI: consolidar (o crear un nuevo artefacto) que sirva los recursos de mantenimiento + almacenes bajo una estructura de rutas coherente por módulo.

### Opción B — No tocar equipos/ots; crear el server unificado solo para módulos nuevos hacia adelante

Dejar `trazalog-equipos` y `trazalog-ots` como están, y unificar únicamente los módulos que todavía no existen (empezando por almacenes) en un nuevo Virtual MCP Server aparte.

- **Pros:** cero riesgo inmediato sobre lo que ya funciona en la demo; no bloquea la entrega de almacenes esperando una migración.
- **Contras:** no es una unificación real — quedarían 2 o más MCP Servers igual, contradice el objetivo de fondo que motivó esta tarea ("un solo MCP Server con todo"); pospone indefinidamente el trabajo de consolidación si nadie lo prioriza después.

### Opción C — Server intermedio en Python/FastMCP que agregue las APIs existentes ("proxy" del wizard, camino 3)

Construir un MCP Server externo (Python/FastMCP) que internamente llame a las APIs WSO2 existentes (equipos, ots, almacenes) y las re-exponga unificadas con namespacing propio, gobernado por el WSO2 Gateway vía la opción "Proxy External MCP Server".

- **Pros:** control total sobre el namespacing/prefijos de las tools, sin las restricciones del wizard "from existing API".
- **Contras:** contradice directamente **ADR-002** ("maximizar Virtual MCP Servers autogenerados, minimizar Python/FastMCP") — esa decisión reserva Python solo para capacidades que WSO2 no puede replicar, y la Opción A demuestra que WSO2 SÍ puede lograr la unificación sin código nuevo. Suma latencia de doble salto (riesgo ya documentado en `TRAZALOG_v3_MCP_ARCHITECTURE.md`, tabla de riesgos) y una capa operativa nueva sin necesidad real.

### Recomendación técnica

**Opción A.** Es la única que logra el objetivo real (un Virtual MCP Server único) usando el producto tal como está pensado, sin contradecir ADR-002 como sí hace la Opción C, y sin dejar la unificación a medias como la Opción B. El costo de la Opción A (romper las URLs de `trazalog-equipos`/`trazalog-ots`) es una ventana de migración coordinable — no un bloqueo técnico — descrita en la siguiente sección.

---

## Impacto sobre lo que ya funciona

- **`trazalog-equipos` y `trazalog-ots` dejarían de existir** (o quedarían deprecados) si se adopta la Opción A. Antes de dar de baja cualquiera de los dos, hace falta:
  - Crear y verificar completamente el MCP Server unificado (incluyendo un smoke test de las 5 tools actuales: `get_equipos`, `get_equipo`, `get_ots`, `get_ot`, `create_ot`, más las que sume almacenes).
  - Reconfigurar el cliente de Claude.ai de la demo con la URL nueva (`Settings → Integrations → MCP Servers`) — es un paso manual, sencillo, pero hay que coordinarlo con quien haga la próxima demo para que no la encuentre rota.
  - Recién ahí despublicar/deprecar los dos servers viejos.
- **En el MI**, `toolsMANAPI` (o un artefacto nuevo que lo reemplace) tendría que crecer para servir también los recursos de almacenes bajo una estructura de rutas coherente por módulo — esto es trabajo de implementación real, no cubierto por esta tarea de relevamiento.
- **Riesgo para la demo que ya anda:** bajo si se coordina la ventana de corte (crear lo nuevo → verificar → recién migrar → recién deprecar lo viejo). Alto solo si se apaga `trazalog-equipos`/`trazalog-ots` antes de tener el reemplazo probado.

---

## Preguntas abiertas (no determinables sin acceso a la consola real o sin arriesgar lo que ya funciona)

1. **¿WSO2 4.6.0 permite configurar un *endpoint* distinto por recurso dentro de una misma API del Publisher?** Esto importa si al consolidar man+alm en una sola API se quiere mantener el backend MI *separado* por módulo (en vez de fusionar también el MI). No lo pude confirmar contra la doc oficial ni contra el entorno real — requiere probarlo a mano en una copia de prueba de una API antes de decidir el diseño final del ADR-013.
2. **¿Los nombres de las tools deberían llevar prefijo explícito** (`man_get_equipos`, `alm_get_pedidos`) **o alcanza con nombres únicos sin colisión** (como hoy)? Hoy no hay colisión de nombres entre equipos/ots y lo que se conoce de almacenes (ADR-012). Es una decisión de UX/diseño para el agente, no una restricción técnica — la dejo para el workshop del ADR-013.
3. **¿Se pueden tener 2+ Virtual MCP Servers activos en paralelo durante la ventana de migración** (viejo + nuevo) **sin que se pisen entre sí?** Son entidades independientes en APIM, así que la expectativa razonable es que sí — pero no está verificado explícitamente contra el entorno real ni contra la doc oficial, lo marco como supuesto de bajo riesgo, no como hecho confirmado.

---

*Generado para E2-MCP-10-RELEV, Bloque 0 de `doc/v3/sprint-3-prompts.md`. No modifica ninguna configuración de MCP Servers ni APIs existentes — es solo relevamiento.*
