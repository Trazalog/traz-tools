# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-013.yaml (versión 2.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-013
Característica: Verificar el informe y dar la conformidad

  Quién lo hace: Supervisor
  Dónde: Mis Tareas → Verifica Informe de Servicio · Mis Tareas → Presta conformidad

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO)
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"
    Y Hay un informe de servicio cargado (MAN-UC-012) y la tarea de verificación está en la bandeja del Supervisor

  Escenario: Camino principal
    Cuando Abre la tarea "Verifica Informe de Servicio" desde su bandeja
    Entonces Se muestra qué se hizo, quiénes trabajaron y, en Herramientas e Insumos, el pedido, las entregas y las herramientas usadas
    Y cuando Si hace falta, corrige los vales asociados (MAN-UC-039)
    Entonces Puede asociar vales sin filtrar por DNI y quitar también los que asoció el pañolero
    Y cuando Aprueba o rechaza
    Entonces Si aprueba, la orden pasa a `CE` y la conformidad le llega al solicitante; si rechaza, el informe vuelve al Mantenedor
    Y cuando El solicitante abre "Presta conformidad" y la da
    Entonces Ve el informe y la pestaña Herramientas e Insumos en lectura; la orden queda Conforme (`CN`) y el caso se cierra

  # Reglas que este caso verifica:
  #   - Al verificar, el Supervisor ve las entregas del pedido y las herramientas usadas; puede asociar vales sin filtro de DNI y quitar los que asoció el pañolero (def. 8, confirmado por el PM el 2026-11-03)
  #   - Si el Supervisor rechaza el informe, **vuelve al Mantenedor** para que lo corrija y lo presente de nuevo
  #   - Si el Solicitante no presta conformidad, la solicitud **vuelve al análisis del Supervisor**: no queda marcada como no conforme, reabre el circuito
  #   - Son dos aprobaciones distintas: la del supervisor sobre el trabajo, y la del solicitante que pidió el servicio
