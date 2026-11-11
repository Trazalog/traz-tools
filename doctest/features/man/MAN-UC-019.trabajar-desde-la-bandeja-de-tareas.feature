# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-019.yaml (versión 2.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-012-020.informes-reportes.spec.ts

@man @MAN-UC-019
Característica: Trabajar desde la bandeja de tareas

  Quién lo hace: Mantenedor
  Dónde: Mis Tareas (bandeja de tools, panel de Mantenimiento) · Mantenimiento → Bandeja de Tareas

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO)
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"

  Escenario: Camino principal
    Cuando Entra a Mis Tareas
    Entonces Se listan como tarjetas las tareas pendientes de todos los procesos de la empresa, entre ellas las de Mantenimiento
    Y cuando Abre una tarea de Mantenimiento
    Entonces Se abre el panel de Mantenimiento: la cabecera de la solicitud y la orden en paneles plegables y, abajo, el formulario del paso (analizar, asignar, ejecutar, informe, verificar, conformidad)
    Y cuando Resuelve la tarea
    Entonces La tarea se cierra y el proceso le pasa la siguiente a quien corresponda

  Escenario: Bandeja propia de Mantenimiento
    Cuando Entra a Mantenimiento → Bandeja de Tareas
    Entonces Se listan solo las tareas de Mantenimiento, con tipo, estado, asignado, fecha, equipo, sector, cliente y los números de solicitud, orden y pedido

  # Reglas que este caso verifica:
  #   - Es la bandeja de entrada del proceso: refleja las tareas de Bonita del usuario
  #   - Solo muestra tareas de casos de la empresa de la sesión
  #   - Cada tarea corresponde a un paso del circuito que le toca a este usuario
  #   - Las pestañas Comentarios y Trazabilidad las pone la bandeja de tools; las demás pestañas del paso se ven todas
