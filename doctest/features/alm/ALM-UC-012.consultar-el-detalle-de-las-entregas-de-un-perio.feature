# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-012.yaml (versión 1.0, validado 2026-08-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-012
Característica: Consultar el detalle de las entregas de un período

  Quién lo hace: Responsable de Almacén
  Dónde: Almacenes → Entrega Detallada

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y Hay entregas registradas en el período que se consulta

  Escenario: Camino principal
    Cuando Entra a Almacenes → Entrega Detallada
    Entonces Se muestran los filtros Desde, Hasta, Obras, Establecimiento y Depósito
    Y cuando Elige el rango de fechas y los filtros que necesita
    Entonces Los desplegables de establecimiento y depósito ofrecen los de la empresa
    Y cuando Hace clic en 'Filtrar'
    Entonces Se listan las entregas del período con su detalle

  # Reglas que este caso verifica:
  #   - Las fechas Desde y Hasta son obligatorias
  #   - El filtro de Obras solo tiene contenido si la empresa lo cargó: es un formulario dinámico, no un dato del módulo
  #   - El informe solo incluye entregas de la empresa de la sesión
