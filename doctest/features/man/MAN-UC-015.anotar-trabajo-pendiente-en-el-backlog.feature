# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-015.yaml (versión 1.0, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-014-018.planes.spec.ts

@man @MAN-UC-015
Característica: Anotar trabajo pendiente en el backlog

  Quién lo hace: Supervisor
  Dónde: Mantenimiento → Backlog

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner

  Escenario: Camino principal
    Cuando Entra a Mantenimiento → Backlog
    Entonces Se listan los pendientes con Nº Backlog, Equipo, Componente, Sistema, Tarea, Fecha, Duración y Estado
    Y cuando Anota un trabajo que hay que hacer pero no es urgente
    Entonces Queda registrado con el equipo, el componente y la tarea
    Y cuando Declara las herramientas y los insumos que va a necesitar
    Entonces Quedan asociados al backlog, para copiarse a la orden cuando se programe

  # Reglas que este caso verifica:
  #   - **El backlog es lo no urgente**: es donde va a parar una solicitud de servicio que el Supervisor decidió que puede esperar
  #   - Un backlog **no vence ni caduca**: queda pendiente hasta que se lo programe
  #   - El backlog nace en estado 'C' y pasa a planificado cuando se le genera la orden
