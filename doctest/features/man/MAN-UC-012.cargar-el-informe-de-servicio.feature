# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-012.yaml (versión 2.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-012
Característica: Cargar el informe de servicio

  Quién lo hace: Mantenedor
  Dónde: Mis Tareas → Confecciona informe de servicio · Mantenimiento → Bandeja de Tareas → Confecciona informe de servicio

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO) con perfil Mantenedor
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"
    Y La orden de trabajo se ejecutó y la tarea "Confecciona informe de servicio" está en su bandeja

  Escenario: Camino principal
    Cuando Abre la tarea "Confecciona informe de servicio" desde su bandeja
    Entonces Se abre el informe con las pestañas Lecturas, Tareas, Recursos Humanos, Herramientas e Insumos y Evidencias
    Y cuando Registra la lectura de cierre del equipo, las tareas realizadas y quiénes trabajaron
    Entonces Quedan cargadas las tareas y los operarios
    Y cuando En Herramientas e Insumos revisa el pedido y las entregas, y asocia los vales del pañol que usó en esta orden (MAN-UC-039)
    Entonces Las herramientas de esos vales quedan como usadas en la orden
    Y cuando Adjunta evidencias si las tiene y confirma
    Entonces El informe queda guardado, la orden pasa a Terminada (`T`) y la tarea de verificación le llega al Supervisor

  Escenario: El Supervisor rechazó el informe
    Cuando Abre la tarea "Edición Informe de Servicios"
    Entonces Se abre el informe cargado, con las mismas pestañas, para corregirlo; al guardar vuelve a verificación. Las evidencias se conservan

  # Reglas que este caso verifica:
  #   - Insumos: lo pedido = lo entregado + lo pendiente; las entregas parciales se ven una por una
  #   - **Desde el informe nunca se genera un vale**: los vales los hace siempre el pañolero; el mantenedor solo indica cuáles de sus vales son de esta orden (regla del PM, 2026-11-03)
  #   - Si la base falla no se cierra la tarea; si falla Bonita, el informe queda guardado y al reintentar se reemplaza completo (E33)
  #   - El informe queda asociado a la orden de trabajo
