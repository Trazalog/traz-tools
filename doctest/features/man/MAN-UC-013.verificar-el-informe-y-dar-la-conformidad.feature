# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-013.yaml (versión 1.0, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-013
Característica: Verificar el informe y dar la conformidad

  Quién lo hace: Supervisor
  Dónde: Mantenimiento → Informe de Servicios · Mis Tareas

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner
    Y Hay un informe de servicio cargado

  Escenario: Camino principal
    Cuando Filtra los informes por estado para ver los pendientes de verificar
    Entonces El listado muestra los que esperan revisión
    Y cuando Abre uno y usa 'Verificar'
    Entonces Se muestra qué se hizo, quiénes trabajaron y qué materiales se pidieron
    Y cuando Aprueba o rechaza
    Entonces Si aprueba, el informe pasa a la conformidad del solicitante
    Y cuando El solicitante presta conformidad
    Entonces La orden de trabajo queda cerrada

  # Reglas que este caso verifica:
  #   - Si el Supervisor rechaza el informe, **vuelve al Mantenedor** para que lo corrija y lo presente de nuevo
  #   - Si el Solicitante no presta conformidad, la solicitud **vuelve al análisis del Supervisor**: no queda marcada como no conforme, reabre el circuito
  #   - Son dos aprobaciones distintas: la del supervisor sobre el trabajo, y la del solicitante que pidió el servicio
