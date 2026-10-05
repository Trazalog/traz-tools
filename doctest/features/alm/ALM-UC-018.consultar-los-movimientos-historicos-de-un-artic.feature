# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-018.yaml (versión 1.0, validado 2026-08-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-018
Característica: Consultar los movimientos históricos de un artículo

  Quién lo hace: Responsable de Almacén
  Dónde: Almacenes → Mov Históricos de Stock

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y El artículo tiene movimientos registrados

  Escenario: Camino principal
    Cuando Entra a Almacenes → Mov Históricos de Stock
    Entonces Se muestran los filtros del reporte
    Y cuando Elige el artículo y el período
    Entonces Los filtros quedan cargados
    Y cuando Hace clic en 'Filtrar'
    Entonces Se listan los movimientos con Referencia, Cod. Artículo, Descripción, Lote, Cantidad, Depósito, Fecha y Tipo de Movimiento
    Y cuando Hace clic en 'Imprimir'
    Entonces El reporte se puede imprimir

  # Reglas que este caso verifica:
  #   - El reporte incluye **todos** los tipos de movimiento, así que sumándolos se puede reconstruir el stock
  #   - El reporte solo incluye movimientos de la empresa de la sesión
