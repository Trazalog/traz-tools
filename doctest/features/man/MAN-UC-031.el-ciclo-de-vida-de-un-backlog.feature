# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-031.yaml (versión 1.0, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-031
Característica: El ciclo de vida de un backlog

  Quién lo hace: Supervisor
  Dónde: Mantenimiento → Backlog

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner

  Escenario: Camino principal
    Cuando El backlog nace de dos maneras: se anota a mano (MAN-UC-015), o **lo genera el proceso** cuando el Supervisor decide que una solicitud no es urgente
    Entonces Queda a la espera de que el Planificador lo programe
    Y cuando Cuando hay lugar en el plan, se le programa una orden de trabajo (MAN-UC-009)
    Entonces El backlog pasa a planificado y sus herramientas e insumos se copian a la orden
    Y cuando La orden sigue su propio ciclo (MAN-UC-030)
    Entonces El backlog queda cerrado cuando se completa el trabajo

  # Reglas que este caso verifica:
  #   - **El backlog es, sobre todo, la solicitud que no era urgente**: el proceso lo genera automáticamente en esa rama
  #   - No caduca: queda pendiente hasta que alguien lo programe
  #   - El backlog nace en estado 'C' y pasa a planificado al generarle la orden
  #   - Al programarlo se cierra además la tarea de Bonita 'Planificar Backlog'
