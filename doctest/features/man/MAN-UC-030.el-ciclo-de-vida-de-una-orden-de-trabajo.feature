# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-030.yaml (versión 0.1, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-030
Característica: El ciclo de vida de una orden de trabajo

  Quién lo hace: Planificador
  Dónde: Mantenimiento → Ordenes de trabajo

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner

  Escenario: Camino principal
    Cuando Se programa desde el plan de mantenimiento (MAN-UC-009), venga de una solicitud, un preventivo, un predictivo o un backlog
    Entonces La orden nace planificada, con las herramientas y los insumos copiados de su origen
    Y cuando Se ejecuta (MAN-UC-011)
    Entonces Se pide el material al almacén y la orden queda en curso
    Y cuando Se carga el informe de servicio (MAN-UC-012)
    Entonces Queda registrado qué se hizo, quiénes y en cuánto tiempo
    Y cuando El supervisor verifica y el solicitante presta conformidad (MAN-UC-013)
    Entonces La orden queda cerrada

  # Reglas que este caso verifica:
  #   - Una orden se puede cerrar **parcial** (`TE`) o **total** desde el listado
  #   - La orden nace `PL` (planificada), pasa a `C` (en curso) cuando el mantenedor la arranca, a `T` (terminada) cuando la cierra, a `CE` (cerrada) cuando el supervisor da por bueno el informe, y a `CN` (conforme) cuando el solicitante acepta
  #   - La columna Origen dice de cuál de los cuatro caminos vino la orden
  #   - Los filtros del listado permiten ver las órdenes por estado y por período programado
