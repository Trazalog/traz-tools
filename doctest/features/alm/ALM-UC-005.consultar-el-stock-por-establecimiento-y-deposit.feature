# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-005.yaml (versión 1.1, validado 2026-08-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-005
Característica: Consultar el stock por establecimiento y depósito

  Quién lo hace: Responsable de Almacén
  Dónde: Almacenes → Stock

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y Hay existencias cargadas: entran al sistema por una recepción (ALM-UC-009)
    Y La empresa tiene establecimientos y depósitos — los crea el alta de la empresa (DNATO-UC-004)

  Escenario: Camino principal
    Cuando Entra a Almacenes → Stock
    Entonces Se muestran los filtros: Establecimiento, Depósito, Tipo de Artículo, Artículo y la opción de incluir artículos con stock en cero
    Y cuando Elige un establecimiento
    Entonces El desplegable de depósitos se limita a los de ese establecimiento
    Y cuando Hace clic en 'Filtrar'
    Entonces Se listan las existencias que cumplen el filtro, con las columnas Acciones, Código, Producto, Tipo de Articulo, N° Lote, Establecimiento, Depósito, Unidad de Medida y Stock
    Y cuando Usa el buscador o cambia de página de la grilla
    Entonces La grilla se actualiza. La búsqueda, el orden y el paginado los resuelve el servidor, no el navegador
    Y cuando Hace clic en 'Limpiar'
    Entonces Los filtros vuelven a su valor inicial

  Escenario: Incluir artículos sin existencias
    Cuando Marca 'Incluir artículos con stock en 0'
    Entonces La opción queda tildada
    Y cuando Hace clic en 'Filtrar'
    Entonces El listado agrega los artículos cuya existencia es cero

  # Reglas que este caso verifica:
  #   - La cantidad que muestra esta pantalla es la **existencia física**: lo que hay, sin descontar lo comprometido en pedidos
  #   - Es una pantalla de consulta: no permite operar sobre el stock. La acción **Info** de cada fila abre una ficha del lote; **no modifica nada**
  #   - El stock listado corresponde solo a la empresa de la sesión
  #   - Los depósitos ofrecidos son los del establecimiento elegido

  # ⚠️ Atención al ejecutarlo:
  #   El modal de la acción Info contiene un formulario de edición (`formEdicion`, campos `_edit`) que **no está conectado a nada**: no tiene botón de envío ni destino, y la única llamada de la vista es la del paginado. Por eso la pantalla sigue siendo de consulta. Anotado como hallazgo H-062.
