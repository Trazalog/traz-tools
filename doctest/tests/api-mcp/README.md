# Suite de contrato MCP (Hurl)

## Objetivo

Explica cómo se corre la suite Hurl que valida las tools del gateway MCP. Está escrito para quien ejecuta los tests (developer en su terminal, o el workflow de CI). **No** cubre el diseño de los casos —eso vive en `doctest/catalogo/mcp/`— ni la arquitectura MCP (`doc/v3/TRAZALOG_v3_MCP_ARCHITECTURE.md` + ADR-009/ADR-013).

> **Estado: infraestructura preparada, suite pendiente.** Los `.hurl` se escriben en la fase F4 (issue #441). Este README ya documenta cómo se ejecutará.

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

## Reglas de la suite

- **Nunca contra producción** (RNF-04). El único entorno admitido es staging-v3 / la VM de trabajo.
- `--very-verbose` está **prohibido en CI**: filtra tokens al log (Doc 3 §7).
- Cada archivo valida status, esquema de respuesta (jsonpath) y **aislamiento de empresa**: con el token de la empresa A no se ven datos de la empresa B.
- `empr_id` nunca viaja como parámetro de una tool: lo resuelve el MI desde el backend JWT `X-JWT-Assertion` (ADR-009). Un test que lo mande como parámetro está probando una violación de arquitectura.
- `initialize` y `tools/list` **no exigen auth** — es una limitación conocida de WSO2 4.6.0, no un bug: el 401 real aparece en el primer `tools/call` (CONTEXT-PACK §4).
- Las tools de escritura crean datos con prefijo `TEST` y verifican el efecto con un GET posterior.

## Convenciones de archivos

```
hurl/
├── contrato_mcp.hurl                  # initialize, tools/list, protocolVersion
├── auth_errores.hurl                  # sin token, token vencido, tool no habilitada
├── man_get_equipos.hurl               # un archivo por tool
├── alm_crear_pedido_materiales.hurl
└── ...
env/
├── staging-v3.env.example             # plantilla versionada (sin secretos)
└── staging-v3.env                     # local, ignorado por git
```
