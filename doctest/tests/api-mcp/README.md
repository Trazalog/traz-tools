# Suite de contrato MCP (Hurl)

## Objetivo

Explica cómo se corre la suite Hurl que valida las tools del gateway MCP. Está escrito para quien ejecuta los tests (developer en su terminal, o el workflow de CI). **No** cubre el diseño de los casos —eso vive en `doctest/catalogo/mcp/`— ni la arquitectura MCP (`doc/v3/TRAZALOG_v3_MCP_ARCHITECTURE.md` + ADR-009/ADR-013).

> **Estado: 7 archivos, verificados en verde contra el gateway real el 2026-10-24.** Cubren el contrato, los errores de autorización y **5 de las 25 tools** — `core_get_empresa_actual` y las cuatro `pan_*`. Las otras 20 siguen sin cubrir: es la fase F4 (issue #441) y el hallazgo **H-085**.

## Instalar Hurl

**Dónde:** en la terminal de tu máquina, parado en `doctest/`.

```bash
npm run hurl:install     # instala Hurl 8.0.1 en ~/.local/bin, sin sudo
hurl --version           # verificación
```

## Correr la suite

**Dónde:** en la terminal, parado en `doctest/`. Antes: copiar `env/staging-v3.env.example` a `env/staging-v3.env` y completarlo con los datos que provee el PM.

```bash
hurl --test --variables-file env/staging-v3.env hurl/*.hurl
```

Las dos primeras —`contrato_mcp.hurl` y `auth_errores.hurl`— **no necesitan token**: validan el handshake, el catálogo de tools y que el gateway corte sin credenciales. Se pueden correr solas para saber si el MCP está publicado y respondiendo:

```bash
hurl --test --variables-file env/staging-v3.env hurl/contrato_mcp.hurl hurl/auth_errores.hurl
```

## Reglas de la suite

- **Nunca contra producción** (RNF-04). El único entorno admitido es staging-v3 / la VM de trabajo.
- `--very-verbose` está **prohibido en CI**: filtra tokens al log (Doc 3 §7).
- Cada archivo valida status, esquema de respuesta (jsonpath) y **aislamiento de empresa**: con el token de la empresa A no se ven datos de la empresa B.
- `empr_id` nunca viaja como parámetro de una tool: lo resuelve el MI desde el backend JWT `X-JWT-Assertion` (ADR-009). Un test que lo mande como parámetro está probando una violación de arquitectura.
- `initialize` y `tools/list` **no exigen auth** — es una limitación conocida de WSO2 4.6.0, no un bug: el 401 real aparece en el primer `tools/call` (CONTEXT-PACK §4).
- **Los headers `Mcp-Method` y `Mcp-Name` van en todos los requests.** El reverse proxy reescribe `202 → 200` para `tools/call` matcheando por `Mcp-Method`: sin ese header el rewrite no aplica y un test puede dar un falso negativo.
- **El payload de una tool viaja como JSON dentro de un string**, en `$.result.content[0].text`. Para sacar un dato de ahí hay que encadenar los filtros —`jsonpath "..." regex /.../`— y no buscar sobre el cuerpo crudo, donde las comillas están escapadas.
- Las tools de escritura crean datos con prefijo `TEST` y verifican el efecto con un GET posterior.

## Convenciones de archivos

```
hurl/
├── contrato_mcp.hurl                  # initialize, tools/list, protocolVersion
├── auth_errores.hurl                  # sin token, token vencido, tool no habilitada
├── core_get_empresa_actual.hurl       # un archivo por tool
├── pan_get_herramientas.hurl
├── pan_get_herramienta.hurl           # encadena: toma un herr_id del listado
├── pan_get_certificaciones.hurl
└── pan_get_movimientos.hurl
env/
├── staging-v3.env.example             # plantilla versionada (sin secretos)
└── staging-v3.env                     # local, ignorado por git
```
