# CONTEXT-PACK — traz-tools

> `Versión: 1.0 | Sincronizado con: TRAZALOG_v3_MCP_ARCHITECTURE.md / último ADR: ADR-009 | Última actualización: 2026-07-14`

> **Este archivo es un RESUMEN OPERATIVO, NO la fuente de verdad.** Leelo primero, pero ante cualquier ambigüedad, contradicción, o tema que no cubra, andá a la fuente canónica ANTES de decidir. Si ni la fuente canónica lo cubre, PARÁ — es una decisión de arquitectura o de negocio, no la tomes solo (ver reglas de escalamiento en CLAUDE.md).

## Jerarquía de fuentes (en este orden)

1. **Negocio y objetivos** → `doc/v3/investigacion-sector-minero-trazalog-v3-2.md` + la estrategia de pricing (`TRAZALOG_v3_PRICING_STRATEGY` — verificar path real en `doc/v3/` antes de citarla en un PR)
2. **Arquitectura** → `doc/v3/TRAZALOG_v3_MCP_ARCHITECTURE.md` + `doc/adr/ADR-*.md`
3. **Proceso** → `doc/v3/TRAZALOG_v3_CICD_STRATEGY.md` (sección 5-bis)
4. **Entorno y git** → `CLAUDE.md` (este mismo repo)

**Chequeo de staleness (hacer antes de cualquier tarea):** corré `ls doc/adr/` y compará contra el "último ADR" del encabezado de este archivo. Si hay un ADR más nuevo que el declarado, reportá la desincronización antes de continuar — no asumas que este resumen está al día.

---

## 1. Qué es este proyecto y su objetivo de negocio

Trazalog es una plataforma SaaS de gestión de operaciones industriales (mantenimiento de activos, almacenes, BPM, producción, residuos) para PyMEs de Cuyo, Argentina. La v3 pivotea hacia el **sector de servicios mineros**, anticipando que Los Azules, Josemaría/Filo del Sol, Veladero y El Pachón entran en construcción ~2027 — ventana de oportunidad para que proveedores locales se profesionalicen antes de que firmas chilenas/peruanas capturen el mercado. Modelo: **freemium (≤5 usuarios) + tiers de capacidad MCP pagos siempre** (Starter/Professional/Enterprise). Toda funcionalidad debe ser coherente con este modelo — una tool que ignore tiers o límites de capacidad contradice el negocio.

## 2. Decisiones de arquitectura vigentes

> ⚠️ **Estado actual de formalización:** solo **ADR-003 y ADR-009 existen como archivos** en `doc/adr/`. Las demás decisiones (001, 002, 005, 008) viven consolidadas dentro de `TRAZALOG_v3_MCP_ARCHITECTURE.md` — su formalización como archivos retroactivos está aprobada pero pendiente de ejecución. Hasta entonces: el chequeo de staleness se hace contra los archivos que SÍ existen; para las decisiones sin archivo, la fuente es el doc de arquitectura.

| Decisión | Archivo propio | Resumen (1 línea) |
|---|---|---|
| ADR-001 | ❌ (en arch doc) | WSO2 APIM es el único punto de entrada del tráfico MCP/API |
| ADR-002 | ❌ (en arch doc) | Maximizar Virtual MCP Servers autogenerados; minimizar Python/FastMCP |
| ADR-003 | ✅ `doc/adr/ADR-003-php-to-wso2-mapping.md` | Mapeo de orquestaciones PHP → WSO2; estrategia por operación |
| ADR-005 | ❌ (en arch doc) | Costo $0 incremental hasta 2027 — open source siempre que sea posible |
| ADR-008 | ❌ (en arch doc + Sección 6.8) | El APIM valida el JWT de Dnato como Key Manager federado (no el MI) |
| **ADR-009** | ✅ `doc/adr/ADR-009-backend-jwt-assertion.md` | **VIGENTE.** El `empr_id` viaja en el backend JWT `X-JWT-Assertion` (firmado por APIM, `apim.jwt.enable=true`); el MI lo deriva con la sequence `EmprIdFromHeader`. La `EmprIdInjectorPolicy` de ADR-008 quedó **DEPRECADA** — no la reimplementes ni la reactives |

## 3. Mecanismo de identidad vigente (el que importa en el día a día)

```
Claude.ai ──JWT Dnato──> APIM (:8243)
                          │ valida firma (Key Manager federado, ADR-008)
                          │ genera backend JWT propio → header X-JWT-Assertion
                          ▼
                          MI (:8290, misma VM, nunca expuesto)
                          │ sequence EmprIdFromHeader lee X-JWT-Assertion
                          │ extrae empr_id (NO del caller, NO de un header del cliente)
                          ▼
                          DataService (SQL con WHERE empr_id = :empr_id)
```

**Regla de oro:** el `empr_id` NUNCA es un parámetro que el agente (Claude) pueda pasar. Si una tarea te pide agregar `empr_id` como parámetro de un endpoint o tool, es una violación de arquitectura — parar y escalar.

## 4. Restricciones duras

- **WSO2 API Manager 4.6.0.** No asumas features de versiones distintas sin verificar contra la doc oficial de esa versión.
- **`initialize` y `tools/list` no pueden exigir auth** (limitación del producto, `McpInitHandler` hardcoded). El 401 real ocurre recién en el primer `tools/call` — es correcto y suficiente para el flujo OAuth, no es un bug a "arreglar".
- **Patrón de URL de Virtual MCP Server:** `https://<host>/<nombre-del-virtual-mcp-server>/1.0/mcp` — el contexto usa el **nombre del server** (ej. `trazalog-equipos`), NUNCA el nombre genérico de la API (`equipos`).
- **`protocolVersion` del handshake MCP:** `2025-06-18`. Si el cliente manda una versión distinta (ej. Claude manda `2025-11-25`), se necesita un shim de traducción — ver `scripts/dev/mcp-session-shim.py`.
- **Costo $0 hasta 2027** (ADR-005): no agregar dependencias con costo de licencia o de tokens sin aprobación explícita de Rodolfo (clase 🔴).

## 5. Regla de oro de repos

| Si el trabajo es… | Va en el repo… |
|---|---|
| WSO2 (APIM, MI), APIs, DataServices, sequences, specs OpenAPI, Virtual MCP Servers | **traz-tools** (este repo) |
| Login, tokens, JWT, OAuth, usuarios, roles | **traz-comp-dnato** |

## 6. Si tu tarea toca X → leé también Y

| Tu tarea toca… | Leé también… |
|---|---|
| Identidad / OAuth / JWT / empr_id | `MCP_ARCHITECTURE.md` §6 + ADR-008 + ADR-009 |
| DataServices / filtrado multi-tenant | ADR-003 + `doc/identity/dataservices-remediation-phase-a.md` |
| Virtual MCP Server nuevo o modificado | `doc/mcp/virtual-mcp-equipos.md` / `virtual-mcp-ots.md` (como referencia de formato) + `doc/mcp/tool-annotations-standard.md` |
| Tiers, límites de uso, analytics de tools | `TRAZALOG_v3_PRICING_STRATEGY` en doc/v3/ (verificar path) |
| Priorización de features, próximo cliente | `investigacion-sector-minero-trazalog-v3-2.md` |
| Cualquier cosa en PHP dentro de Dnato | `traz-comp-dnato/CLAUDE.md` (PHP 5.6 estricto) |

## 7. Dónde está cada cosa (mapa de directorios clave)

```
doc/v3/                 → documentos ancla (arquitectura, CICD, pricing, negocio) + STATE.md
doc/adr/                → ADRs individuales (ADR-003, ADR-009, ...)
doc/identity/            → docs de identidad/JWT/discovery OAuth
doc/mcp/                 → docs de Virtual MCP Servers y demo
doc/api/                 → specs OpenAPI (equipos.yaml, ot.yaml)
_backend/api/ToolsAPIProject/    → artefactos WSO2 MI (DataServices, sequences, APIs)
_backend/api/ApimDiscoveryProject/ → discovery OAuth 2.1 (RFC 9728)
scripts/dev/             → scripts reutilizables (setup ngrok, generación de JWT de test, etc.)
tests/security/, tests/oauth/ → tests Hurl y de discovery
```

---

## Mantenimiento de este archivo

**Todo PR que cree o modifique un ADR debe actualizar este CONTEXT-PACK en el mismo PR** — agregar la línea del ADR a la tabla de la sección 2 y hacer bump de versión en el encabezado. No dejarlo para después.
