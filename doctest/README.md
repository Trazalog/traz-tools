# DocTest — catálogo funcional, tests automatizados y ayudas de Trazalog v3

## Objetivo

Punto de entrada de DocTest: qué hay en este árbol, qué comando corrés y dónde, y cómo se contribuye. Está escrito para cualquiera que toque el repo — developer que va a correr la suite antes de pushear, tester que quiere leer los casos, o Claude Code al implementar una fase. **No** cubre el diseño de la solución ni el porqué de las decisiones: eso está en los tres documentos ancla de `doc/v3/` (`TRAZALOG_v3_DOCTEST_01_REQUERIMIENTOS.md`, `..._02_CICLO_VIDA_CICD.md`, `..._03_ARQUITECTURA.md`).

> **¿Buscás dónde queda la evidencia de una corrida, dónde se anotan los hallazgos, o cómo se
> publican y se opinan las ayudas?** Está todo en [`GUIA-PRUEBAS-Y-AYUDAS.md`](GUIA-PRUEBAS-Y-AYUDAS.md).

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
| `tests/e2e/` | Suite Playwright: `playwright.config.ts`, `config/`, `fixtures/` (incluye la casilla de correo descartable), `pages/`, `specs/`, `seeds/` |
| `tests/api-mcp/` | Suite Hurl de contrato MCP ([README](tests/api-mcp/README.md)) |
| `ayudas/` | `legacy/` (el sitio anterior, tal cual), `plantilla/` (theme.css + esqueleto extraídos de ahí) y `src/` (el contenido nuevo, por módulo). El sitio armado sale en **`ayuda/` en la raíz del repo**, que es lo que sirve el frontend |
| `generators/` | Scripts de validación y derivación catálogo → salidas |
| `ci/` | [`module-map.json`](ci/module-map.json): mapa path→módulo que usa el CI |
| `feedback/` | [`PROCESO.md`](feedback/PROCESO.md): cómo reporta un tester lo que falta probar o lo que está mal en una ayuda |
| `scripts/` | Envoltorios de ejecución (`pw.mjs`, `test-module.mjs`, `install-hurl.sh`) |

## Puesta a punto (una sola vez)

**Dónde se ejecuta:** en una terminal de tu máquina, parado en `traz-tools/doctest/`.

```bash
npm install                       # dependencias (Playwright, ajv, tsx, ...)
npx playwright install chromium   # navegador headless
npm run hurl:install              # Hurl 8.0.1 en ~/.local/bin (solo si vas a tocar la suite MCP)
cp .env.example .env              # y completar las credenciales; .env NO se commitea
```

> Las URLs ya vienen en `.env.example`. Lo que falta completar son las **credenciales de las empresas de test**, que provee Rodolfo. Los casos que dependen de un mail (activación, recuperación de contraseña) **no** necesitan credenciales de correo: el test se crea una casilla descartable y la lee por API. Nunca se hardcodean ni se inventan: si falta una, el test falla con un mensaje que dice exactamente qué variable falta.

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
| `npm run test:report` | Abre el último reporte HTML de Playwright |
| `npm run ayudas` | Arma el sitio de ayudas en `ayuda/` (raíz del repo, versionado): copia los manuales actuales tal cual, ensambla los nuevos con la plantilla y **regenera el buscador del inicio desde el contenido de todos los manuales** |
| `npm run ayudas:unico` | Empaqueta todo el sitio de ayudas en un archivo navegable (`.validacion/sitio-ayudas.html`) para revisarlo antes de publicar |
| `npm run verificar:asset` | ¿Un usuario creado por la registración puede entrar a AssetPlanner? Es la verificación del issue #489 (la contraseña se guardaba sin hashear). Solo intenta ingresar, no escribe nada |
| `npm run test:alta-empresa` | Corre el alta completa de una empresa como test. **Crea una empresa real**: se ejecuta a demanda, está fuera de las corridas normales |
| `npm run features` | Regenera los `.feature` Gherkin desde los casos **validados** (agregá `-- --dry-run` para ver qué cambiaría). Los `.feature` no se editan a mano |
| `npm run hoja:validacion -- dnato` | Arma la **hoja de validación** del módulo: los casos en prosa legible, con las dudas al frente y un control para marcar validado / obsoleto / sigue en borrador. Sale en `.validacion/<modulo>.html` (no se commitea) y se publica para que el PM la lea |
| `npm run generators:dry-run` | Corrida en seco de los generadores (lo mismo que corre el CI) |
| `npm run typecheck` | `tsc --noEmit` sobre generators y tests |
| `npm run hurl:install` | Instala Hurl sin sudo |
| `npm run seed:empresa` | **Crea una empresa de test desde cero**, recorriendo el registro real de punta a punta: se crea una casilla descartable, se registra, **lee el mail de activación solo** y da de alta la empresa con sus 16 roles, establecimiento, depósito y 5 usuarios. `-- --dry-run` muestra los datos sin tocar nada; `-- --headed` deja mirarlo. Escribe datos reales: se corre pocas veces |

### Entornos

| `DOCTEST_ENV` | Qué es | Estado |
|---|---|---|
| `local` | Las apps levantadas en tu máquina | según cada developer |
| `demo` | `demo.cloudtrazalog.com` — entorno **DEMO de v2** | ✅ el único desplegado hoy, y contra el que corre DocTest |
| `staging-v3` | Staging de v3 | ⛔ todavía no existe (lo entrega E7-CICD) |

Se elige desde tu `.env` o inline:

```bash
DOCTEST_ENV=demo npm run test:smoke
```

> **No hay nada de v3 desplegado todavía.** Mientras tanto la suite corre contra el DEMO de v2, que es funcionalmente el mismo sistema bajo prueba. El día que exista staging-v3 alcanza con completar sus tres URLs en el `.env`: la config ya tiene el project declarado.

## Convenciones que hay que respetar

- **Tags:** cada spec lleva `@<modulo>`, el id del caso (`@DNATO-UC-013`) y, si es crítico, `@smoke`. El conjunto `@smoke` se mantiene chico a propósito —los flujos sin los cuales nada funciona— para que siga entrando en los 2 minutos que pide RNF-02: ingreso, salida, aislamiento entre empresas, el formulario público de registro y el corte de acceso a la administración de empresas. Un test inestable se marca `@quarantine` **y se abre un issue** — no se ignora en silencio (RNF-03).
- **Bugs conocidos:** cuando un caso validado describe lo que *tiene* que pasar y el sistema todavía no lo cumple, el test se marca con `test.fail()` y un comentario con el hallazgo y su issue. Así el test sigue vivo: hoy tiene que fallar, y **el día que se corrija el bug la corrida se pone en rojo** avisando que hay que sacar la marca. No se comenta el test ni se lo saca de la suite.
- **Corre en serie:** el entorno de pruebas es una máquina chica y compartida; con tests en paralelo aparecen fallas que no son del sistema. Está medido y explicado en `playwright.config.ts`.
- **Selectores:** `data-testid` como selector primario, con formato `<modulo>-<pantalla>-<tipo>-<nombre>` en minúsculas. `getByRole()`/`getByLabel()` como secundario. XPath o CSS estructural: prohibido salvo excepción justificada en comentario (Doc 3 §4.5).
- **Sin selectores en los specs:** los specs llaman métodos de page objects. Un cambio de UI se arregla en un solo archivo.
- **Sin esperas fijas:** nada de `waitForTimeout`; auto-wait de Playwright + asserts explícitos.
- **Trazabilidad:** cada spec declara en su cabecera el id del caso de uso; el YAML del caso lista sus derivados. El validador verifica que los derivados declarados existan.
- **Nunca producción:** los tests corren contra `local`, `demo` o `staging-v3` (RNF-04). Hay una guarda en `tests/e2e/config/apps.ts` que corta si una URL apunta a un host productivo (`cloudtrazalog.com` a secas).
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
| F1 | DNATO — registración y administración de cuenta | #438 | ✅ catálogo validado (25), 25 `.feature`, 55 tests y la ayuda de usuario |
| F2 | MAN piloto — Alta de Equipos y Componentes | #439 | pendiente |
| F3 | ALM — almacenes y pedido de materiales | #440 | pendiente |
| F4 | MCP — suite Hurl de contrato y aislamiento | #441 | pendiente |
| F5 | Integración CI/CD, hook pre-push, `test-gap`, generators restantes | #442 | pendiente |
