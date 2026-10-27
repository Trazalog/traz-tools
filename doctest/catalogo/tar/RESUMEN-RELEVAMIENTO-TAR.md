# Relevamiento TAR — Tareas: pedidos de trabajo, hitos y tareas planificadas

## Objetivo

Resume qué hay en el catálogo de TAR, de dónde salió, qué falta para validarlo y cómo se corre su suite. Es para el PM (que valida los casos) y para quien mantenga la suite. **No** repite la especificación del módulo ([`doc/specs/TAR-spec-modulo-tareas.md`](../../../doc/specs/TAR-spec-modulo-tareas.md)) ni el detalle de los bugs ([`doc/specs/TAR-bugs-detectados.md`](../../../doc/specs/TAR-bugs-detectados.md)).

## Qué hay

- **22 casos** `TAR-UC-001` a `TAR-UC-022`, todos en `borrador`, pasados a YAML desde §6 del spec, con las dudas D-01 a D-21 repartidas por caso y los ids de casos de prueba (`TAR-CP-*`) e hipótesis (`HIP-TAR-*`) en `notas`.
- **Perfil propuesto `Operario`** (TAR-UC-016/017/018, duda D-01), agregado al schema como pendiente de validación.
- **Suite** en `tests/e2e/specs/tar/` (4 specs), page objects en `tests/e2e/pages/tar/`, sesiones por rol en `tests/e2e/fixtures/roles-tar.ts`, seed en `tests/e2e/seeds/tar/`.

## Lo que el PM tiene que resolver para validar

1. Las dudas de cada caso (D-01 a D-21 y las dos nuevas de TAR-UC-002 y TAR-UC-009).
2. El perfil `Operario`.
3. Al validar, declarar en `derivados` los specs que ya existen (hoy no se declaran: un borrador no tiene derivados, regla R1).

## Cómo se corre

**Dónde:** terminal local con VPN, parado en `doctest/`.

```bash
npm run seed:tar                 # una vez: clientes y tipos de trabajo de la empresa de test
npm run test:module -- tar       # la suite completa (~25 min contra el DEMO)
```

Requisitos: las variables `DOCTEST_TAR_*` y `DOCTEST_EMPRESA1/2_*` del `.env` (plantilla en `.env.example`), y `PROCESO-STANDAR` en `pro.procesos` de la empresa (`tests/e2e/seeds/tar/pro-procesos-empresas-test.sql`, lo aplica el PM en la base del DEMO). Sin ese proceso, los tests que necesitan un pedido real se saltean con el motivo escrito y el resto del ciclo corre sobre un origen sintético.
