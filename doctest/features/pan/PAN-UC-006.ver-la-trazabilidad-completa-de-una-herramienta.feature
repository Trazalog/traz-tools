# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/pan/PAN-UC-006.yaml (versión 1.0, validado 2026-09-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@pan @PAN-UC-006
Característica: Ver la trazabilidad completa de una herramienta

  Quién lo hace: Usuario
  Dónde: Herramientas → Herramientas → acción Info

  Antecedentes:
    Dado La herramienta tiene al menos un movimiento registrado

  Escenario: Camino principal
    Cuando Usa la acción Info sobre una herramienta
    Entonces Se abre el detalle con Código, Tipo, Descripción, Marca y Modelo, y tres solapas: Trazabilidad, Certificaciones y Checklists
    Y cuando Mira la solapa Trazabilidad
    Entonces Se muestran Nro. Vale, Tipo, Fecha y Hora, Responsable, Establecimiento/Pañol y Justificación/Observación, ordenado por fecha y hora descendente
    Y cuando Observa los tipos de movimiento
    Entonces Aparecen mezclados Entrega, Recepción, Habilitación, Inhabilitación y Alta
    Y cuando Mira la solapa Certificaciones
    Entonces Se muestran Fecha y Hora, Vencimiento, Entidad Certificadora y el adjunto
    Y cuando Mira la solapa Checklists
    Entonces Se muestran Fecha y Hora y Responsable, con la lupa para ver el checklist completo

  Escenario: Exportar la trazabilidad
    Cuando Usa Exportar a Excel o PDF
    Entonces La exportación incluye todas las páginas y agrega la fecha de hoy, el código, la descripción, el modelo y la marca de la herramienta

  # Reglas que este caso verifica:
  #   - La trazabilidad mezcla los vales con la tabla de inhabilitaciones en una sola línea de tiempo
  #   - La última columna muestra la justificación en las inhabilitaciones y las observaciones del vale en los movimientos
  #   - Las filas de habilitación e inhabilitación no tienen Nro. de Vale

  # Datos de prueba:
  #   empresa: EMPRESA_TEST_1
  #   precondicion: una herramienta con entregas, recepciones y al menos una inhabilitación
