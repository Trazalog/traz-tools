# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-019.yaml (versión 1.0, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-012-020.informes-reportes.spec.ts

@man @MAN-UC-019
Característica: Trabajar desde la bandeja de tareas

  Quién lo hace: Mantenedor
  Dónde: Mis Tareas

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner

  Escenario: Camino principal
    Cuando Entra a Mis Tareas
    Entonces Se listan las tareas pendientes con su tipo, estado, a quién están asignadas, la fecha de asignación, el equipo, el sector, el cliente, la tarea y los identificadores de solicitud, orden y pedido
    Y cuando Abre una tarea
    Entonces Se muestra el detalle de lo que hay que hacer y el formulario para resolverla

  # Reglas que este caso verifica:
  #   - Es la bandeja de entrada del proceso: refleja el Inbox de Bonita
  #   - Cada tarea corresponde a un paso del circuito que le toca a este usuario
