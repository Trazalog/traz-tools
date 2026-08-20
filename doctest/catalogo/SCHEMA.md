# Esquema del Catálogo Funcional

## Objetivo

Documenta cómo se escribe un caso de uso del catálogo de DocTest y qué reglas verifica el CI antes de dejarlo entrar. Está escrito para quien redacta o revisa un caso (Claude Code al relevar, Rodolfo al validar en el PR). **No** cubre cómo se derivan los artefactos (eso está en `TRAZALOG_v3_DOCTEST_03_ARQUITECTURA.md` §6) ni el ciclo de vida en CI/CD (Doc 2).

- Esquema formal ejecutable: [`catalogo.schema.json`](catalogo.schema.json) (JSON Schema 2020-12)
- Validador: `npm run validate:catalog` → [`../generators/validate-catalog.ts`](../generators/validate-catalog.ts)
- Fuente de la especificación: `doc/v3/TRAZALOG_v3_DOCTEST_03_ARQUITECTURA.md` §3

---

## Dónde vive cada caso

Un archivo YAML por caso de uso, en `doctest/catalogo/<modulo>/<ID>.yaml`:

```
catalogo/dnato/DNATO-UC-001.yaml
catalogo/man/MAN-UC-001.yaml
catalogo/alm/ALM-UC-001.yaml
catalogo/mcp/MCP-UC-001.yaml
```

El nombre del archivo **es** el id del caso. El directorio **es** el módulo en minúsculas. Las dos cosas las verifica la regla R4.

## Campos

| Campo | Obligatorio | Qué es |
|---|---|---|
| `id` | sí | `<MOD>-UC-<NNN>`. Módulos: `DNATO`, `MAN`, `ALM`, `MCP`, `PAN`, `PRD`, `TAR` |
| `modulo` | sí | Mismo prefijo que el id |
| `titulo` | sí | Título funcional, en lenguaje de usuario |
| `perfil` | sí | Perfil funcional que ejecuta el flujo. **Vocabulario fijo** (ver abajo) |
| `estado` | sí | `borrador` \| `validado` \| `obsoleto` |
| `version` | sí | `mayor.menor`. Se incrementa al cambiar el comportamiento de un caso ya validado |
| `origen` | sí | `baseline` \| `delta-PR#<N>` \| `feedback-issue#<N>` |
| `fecha_validacion` | si `validado` | `YYYY-MM-DD` de la validación del PM |
| `referencias_codigo` | sí | Lista de `{repo, path, detalle?}` — trazabilidad al fuente relevado |
| `pantallas` | sí | Ruta de navegación como la ve el usuario: `"Mantenimiento → Equipos → Agregar"` |
| `precondiciones` | sí | Estado previo necesario (sesión, perfil, datos semilla) |
| `flujo_principal` | sí | Lista de `{paso, resultado}` — el camino feliz |
| `flujos_alternativos` | no | Lista de `{nombre, pasos[]}` — errores, variantes, casos borde |
| `validaciones` | no | Reglas de negocio que el caso verifica |
| `datos_prueba` | no | Convenciones de datos del caso. **Nunca credenciales ni datos de clientes reales** |
| `dudas` | si `borrador` | Dudas de intención funcional, en texto claro para el PM |
| `derivados` | no | `{test_e2e, test_hurl, feature, ayuda}`, paths relativos a `doctest/` |
| `notas` | no | Observaciones para el revisor; no se derivan a ningún artefacto |

### El campo `perfil` tiene vocabulario cerrado

El validador rechaza cualquier valor fuera de esta lista, a propósito: si en un relevamiento aparece un rol nuevo, **no se inventa** — se propone acá y el PM lo valida.

| Perfil | Quién es | Estado |
|---|---|---|
| `Solicitante` | Genera solicitudes de servicio | ✅ validado (Doc 1 v1.1 RF-05.4) |
| `Supervisor` | Acepta/rechaza solicitudes, da de alta equipos, verifica informes | ✅ validado |
| `Planificador` | Programa preventivos y asigna órdenes de trabajo | ✅ validado |
| `Mantenedor` | Ejecuta órdenes de trabajo y carga el informe de servicio | ✅ validado |
| `Administrador` | Administra la cuenta: usuarios, roles y datos de su empresa | ⏳ propuesto en F1 (#438) |
| `Usuario` | Cualquier usuario autenticado, sin importar su rol (perfil propio, contraseña) | ⏳ propuesto en F1 (#438) |
| `Visitante` | Todavía no tiene cuenta: se está registrando o activándola | ⏳ propuesto en F1 (#438) |

Los tres propuestos salieron del relevamiento de DNATO, que es lo que el Doc 1 v1.1 RF-05.4 anticipa ("más los roles de administración de cuenta que surjan del relevamiento DNATO"). Quedan pendientes de la validación del PM junto con el catálogo de DNATO; si prefiere otros nombres, se renombran y se regeneran los casos.

### Cómo se escriben los pasos

Los pasos son la fuente del `.feature` que lee un tester y de la ayuda que lee el usuario final: se escriben **en lenguaje de usuario, sin selectores ni tecnicismos** (RF-03.3).

```yaml
flujo_principal:
  - paso: "Hace clic en 'Agregar' en el listado de equipos"     # ✅
    resultado: "Se abre el formulario de alta vacío"
  - paso: "Click en #btn-agregar y espera el XHR de /equipos"    # ❌ eso va en el spec
    resultado: "HTTP 200"
```

## Estados y modo conservador

El código dice **qué** hace el sistema, no **para qué**. Si al relevar no se puede inferir la intención de negocio, el caso queda en `borrador` con la duda escrita — nunca se inventa intención (RF-02.3).

| Estado | Significa | Habilita derivados |
|---|---|---|
| `borrador` | Relevado desde código, sin validar por el PM | **No** |
| `validado` | Rodolfo confirmó la intención funcional en el review del PR | Sí |
| `obsoleto` | El flujo ya no existe. Se conserva por historia | No (se borran los que tenía) |

## Reglas duras que verifica el CI

| Código | Regla |
|---|---|
| `SCHEMA` | El YAML cumple `catalogo.schema.json` |
| `YAML` | El archivo parsea como YAML y no está vacío |
| `R1` | `borrador` ⇒ `dudas` no vacío **y** `derivados` vacío (Doc 3 §3.1 + RF-01.3) |
| `R2` | `validado` ⇒ `dudas` vacío, `fecha_validacion` presente y **cada derivado declarado existe en el repo** |
| `R3` | `obsoleto` ⇒ `derivados` vacío (los archivos derivados se eliminan en el mismo PR, Doc 3 §3.3) |
| `R4` | `id` = nombre de archivo = prefijo de módulo = directorio |
| `R5` | No hay ids duplicados en todo el catálogo |
| `R6` | Cambiar `flujo_principal` / `flujos_alternativos` / `validaciones` de un caso `validado` exige bump de `version` (Doc 3 §3.2). Solo corre con `--diff-base <ref>`, que es como lo invoca el workflow |

R6 compara contra la rama base del PR; los casos nuevos no la disparan. La regeneración de los derivados que exige esa misma regla la revisa el humano en el PR — el validador no la puede probar solo.

## Comandos

Todos se corren **en una terminal, parado en `doctest/`**:

```bash
npm run validate:catalog                                  # catálogo completo
npm run validate:catalog -- --diff-base origin/develop-v3 # + regla R6
npm run validate:catalog:selftest                         # el validador contra sus propias fixtures
```

Las fixtures del selftest viven en `generators/fixtures/` y **no son casos reales**: existen para que un cambio en el validador que rompa una regla se note en el acto. Cada fixture inválida declara en su primera línea qué código de error tiene que disparar (`# expect-error: R1`).

## Ejemplo completo

```yaml
id: MAN-UC-001
modulo: MAN
titulo: Alta de equipo con componentes
perfil: Supervisor
estado: validado
version: "1.2"
origen: baseline
fecha_validacion: 2026-09-02
referencias_codigo:
  - repo: traz-prod-assetplanner
    path: application/controllers/Equipos.php
    detalle: "método guardar()"
pantallas:
  - "Mantenimiento → Equipos → Agregar"
precondiciones:
  - Usuario autenticado con perfil Supervisor
  - Empresa de test con establecimiento activo
flujo_principal:
  - paso: "Hace clic en 'Agregar' en el listado de equipos"
    resultado: "Se abre el formulario de alta vacío"
  - paso: "Completa Código, Descripción, Criticidad y guarda"
    resultado: "El equipo aparece en el listado con estado Activo"
flujos_alternativos:
  - nombre: "Campos obligatorios incompletos"
    pasos:
      - paso: "Guarda sin completar Código de Equipo"
        resultado: "Se muestra el error de campo obligatorio y el equipo no se registra"
validaciones:
  - "Código de equipo único por empresa"
datos_prueba:
  empresa: EMPRESA_TEST_1
  equipo_codigo_prefijo: "EQ-TEST-"
dudas: []
derivados:
  test_e2e: tests/e2e/specs/man/MAN-UC-001.alta-equipo.spec.ts
  feature: features/man/MAN-UC-001.alta-equipo.feature
  ayuda: ayudas/src/man/alta_equipos_componentes.html#s03
```
