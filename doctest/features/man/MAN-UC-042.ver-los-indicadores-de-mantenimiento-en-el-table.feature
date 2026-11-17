# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-042.yaml (versión 1.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-042.indicadores.spec.ts

@man @MAN-UC-042
Característica: Ver los indicadores de mantenimiento en el tablero de tools

  Quién lo hace: Supervisor
  Dónde: Tablero de indicadores de tools

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO)
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"
    Y El cálculo de indicadores corrió para el período (cron de KPIs)

  Escenario: Camino principal
    Cuando Entra al tablero de indicadores de tools
    Entonces Entre las cajas de Mantenimiento ve el tiempo medio de reparación (MTTR), el tiempo medio hasta la falla (MTTF), el tiempo medio entre fallas (MTBF), en horas, y la confiabilidad de los equipos, en porcentaje

  # Reglas que este caso verifica:
  #   - Los indicadores se calculan por mes y por empresa
  #   - Las órdenes sin lanzar no afectan ningún indicador
