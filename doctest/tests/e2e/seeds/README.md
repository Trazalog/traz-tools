# Datos semilla de las empresas de test

## Objetivo

Define cómo se versionan y se aplican los datos base que necesitan los tests E2E. Está escrito para quien prepara un entorno de pruebas (developer en su entorno local, o Rodolfo sobre staging-v3). **No** cubre las fixtures de Playwright que los consumen (`../fixtures/`) ni las credenciales, que nunca se versionan.

> **Estado: pendiente.** Los seeds concretos se escriben junto con el catálogo de cada módulo (F1 en adelante). Este README fija las reglas antes de que existan.

## Reglas (Doc 3 §4.4)

1. **Mínimo dos empresas de test** en staging-v3, para poder verificar aislamiento multi-empresa. Con establecimientos, perfiles y datos base conocidos.
2. Los seeds son **idempotentes**: re-ejecutarlos no duplica datos.
3. Los datos creados por los tests usan prefijo (`EQ-TEST-`, `PED-TEST-`) + timestamp, con limpieza best-effort en teardown. La limpieza real es el re-seed periódico.
4. 🔴 **Cualquier seed que toque directamente la BD de staging sigue la política de migraciones del doc CI/CD: manual y revisada.** No se ejecuta desde un workflow.
5. Cero credenciales acá. Usuarios y contraseñas van por `.env` / GitHub Secrets (Doc 3 §8.1).
6. Nunca datos de clientes reales (RNF-05).

## Estructura prevista

```
seeds/
├── README.md            (este archivo)
├── <modulo>/            SQL o scripts contra la app, según lo que exista en cada caso
└── empresas-test.md     inventario de las empresas de test y qué contiene cada una
```
