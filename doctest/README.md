# DocTest — catálogo funcional, tests automatizados y ayudas de Trazalog v3

## Objetivo

Punto de entrada de DocTest: qué hay en este árbol, qué comando corrés y dónde, y cómo se contribuye. Está escrito para cualquiera que toque el repo — developer que va a correr la suite antes de pushear, tester que quiere leer los casos, o Claude Code al implementar una fase. **No** cubre el diseño de la solución ni el porqué de las decisiones: eso está en los tres documentos ancla de `doc/v3/` (`TRAZALOG_v3_DOCTEST_01_REQUERIMIENTOS.md`, `..._02_CICLO_VIDA_CICD.md`, `..._03_ARQUITECTURA.md`).

---

## La idea en cuatro líneas

El **catálogo funcional** (`catalogo/`) es la única fuente de verdad: un YAML por caso de uso, versionado en git y validado por Rodolfo. De ahí se **derivan** los tests E2E (Playwright), los tests de contrato MCP (Hurl), los `.feature` que leen los testers y las ayudas HTML del usuario final. Nada derivado se edita a mano en forma divergente: se corrige el caso y se regenera. Un caso sin validar (`estado: borrador`) **no genera nada**.

```
código PHP + ayudas actuales ──relevamiento──> catálogo (gate humano) ──> ayudas · tests · .feature
                                                     ↑
                                     feedback de testers (issues test-gap)
```

## Qué hay en cada carpeta

| Carpeta | Contenido |
|---|---|
| `catalogo/` | Casos de uso YAML por módulo + [`SCHEMA.md`](catalogo/SCHEMA.md) y el JSON Schema |
| `features/` | `.feature` Gherkin en español — documentación para testers, sin runtime Cucumber |
| `tests/e2e/` | Suite Playwright: `playwright.config.ts`, `config/`, `fixtures/`, `pages/`, `specs/`, `seeds/` |
| `tests/api-mcp/` | Suite Hurl de contrato MCP ([README](tests/api-mcp/README.md)) |
| `ayudas/` | `legacy/` (manuales vigentes, fuente de intención funcional), `plantilla/`, `src/`, `build/` |
| `generators/` | Scripts de validación y derivación catálogo → salidas |
| `ci/` | [`module-map.json`](ci/module-map.json): mapa path→módulo que usa el CI |
| `feedback/` | Cómo reporta un tester lo que falta probar |
| `scripts/` | Envoltorios de ejecución (`pw.mjs`, `test-module.mjs`, `install-hurl.sh`) |

## Puesta a punto (una sola vez)

**Dónde se ejecuta:** en una terminal de tu máquina, parado en `traz-tools/doctest/`.

```bash
npm install                       # dependencias (Playwright, ajv, tsx, ...)
npx playwright install chromium   # navegador headless
npm run hurl:install              # Hurl 8.0.1 en ~/.local/bin (solo si vas a tocar la suite MCP)
cp .env.example .env              # y completar; .env NO se commitea
```

> Las URLs de staging-v3 y las credenciales de las empresas de test las provee Rodolfo. Nunca se hardcodean ni se inventan: si falta una, el test falla con un mensaje que dice exactamente qué variable falta.

## Comandos

**Dónde se ejecutan:** en una terminal, parado en `doctest/`.

| Comando | Qué hace |
|---|---|
| `npm run test:smoke` | Suite `@smoke` (< 2 min). **Es la que corrés antes de cada push** |
| `npm run test:module -- man` | Suite completa de un módulo (`dnato`, `man`, `alm`, `mcp`, `pan`, `prd`, `tar`) |
| `npm run test:all` | Suite E2E completa, sin lo que esté en cuarentena |
| `npm run test:list` | Lista los tests sin ejecutarlos (carga config y specs; es lo que corre el CI de validación) |
| `npm run test:report` | Abre el último reporte HTML de Playwright |
| `npm run validate:catalog` | Valida el catálogo contra el schema y las reglas duras |
| `npm run generators:dry-run` | Corrida en seco de los generadores (lo mismo que corre el CI) |
| `npm run typecheck` | `tsc --noEmit` sobre generators y tests |
| `npm run hurl:install` | Instala Hurl sin sudo |

El entorno se elige con `DOCTEST_ENV` (`local` por defecto, o `staging-v3`), desde tu `.env` o inline:

```bash
DOCTEST_ENV=staging-v3 npm run test:smoke
```

## Convenciones que hay que respetar

- **Tags:** cada spec lleva `@<modulo>` y, si es crítico, `@smoke`. Un test inestable se marca `@quarantine` **y se abre un issue** — no se ignora en silencio (RNF-03).
- **Selectores:** `data-testid` como selector primario, con formato `<modulo>-<pantalla>-<tipo>-<nombre>` en minúsculas. `getByRole()`/`getByLabel()` como secundario. XPath o CSS estructural: prohibido salvo excepción justificada en comentario (Doc 3 §4.5).
- **Sin selectores en los specs:** los specs llaman métodos de page objects. Un cambio de UI se arregla en un solo archivo.
- **Sin esperas fijas:** nada de `waitForTimeout`; auto-wait de Playwright + asserts explícitos.
- **Trazabilidad:** cada spec declara en su cabecera el id del caso de uso; el YAML del caso lista sus derivados. El validador verifica que los derivados declarados existan.
- **Nunca producción:** los tests corren contra staging-v3 o local (RNF-04). Hay una guarda en `tests/e2e/config/apps.ts` que corta si una URL apunta a un host productivo.
- **Nunca secretos en el repo:** credenciales por `.env` (local) o GitHub Secrets (CI).

## Cómo se agrega un caso de uso

1. Se releva desde el código y las ayudas actuales → YAML en `catalogo/<modulo>/` con `estado: borrador` y las `dudas` explícitas.
2. **Gate humano:** Rodolfo valida la intención funcional en el review del PR → `estado: validado` + `fecha_validacion`.
3. Recién ahí se derivan test, `.feature` y ayuda, y se declaran en `derivados`.
4. Si después cambia el comportamiento del caso: bump de `version` y regeneración de los derivados en el mismo PR.

Todo entra por feature branch + PR (metodología git del `CLAUDE.md`). Nunca commit directo a `develop-v3`.

## Estado de implementación

| Fase | Alcance | Issue | Estado |
|---|---|---|---|
| F0 | Infraestructura: árbol, Playwright, Hurl, schema + validador, CI de validación | #437 | ✅ |
| F1 | DNATO — registración y administración de cuenta | #438 | pendiente |
| F2 | MAN piloto — Alta de Equipos y Componentes | #439 | pendiente |
| F3 | ALM — almacenes y pedido de materiales | #440 | pendiente |
| F4 | MCP — suite Hurl de contrato y aislamiento | #441 | pendiente |
| F5 | Integración CI/CD, hook pre-push, `test-gap`, generators restantes | #442 | pendiente |
