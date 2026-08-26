# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-010.yaml (versión 0.1, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-010.ordenes-trabajo.spec.ts

@man @MAN-UC-010
Característica: Ver y filtrar las órdenes de trabajo

  Quién lo hace: Planificador
  Dónde: Mantenimiento → Ordenes de trabajo

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner

  Escenario: Camino principal
    Cuando Entra a Mantenimiento → Ordenes de trabajo
    Entonces Se muestran los filtros —Programada Desde, Programada Hasta, Equipo y Estado— sobre el listado
    Y cuando Elige el rango de fechas, el equipo o el estado que le interesa y filtra
    Entonces El listado muestra Nº Orden, Fecha Programada, Fecha Inicio, Fecha Terminada, Detalle, Tarea estándar, Equipo, Origen, Id Solicitud y a quién está asignada

  # Reglas que este caso verifica:
  #   - **Parcial** deja la orden en estado terminada-parcial (`TE`); **Total** la finaliza
  #   - La columna Origen dice de dónde vino la orden: solicitud, preventivo, predictivo o backlog
