# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-003.yaml (versión 1.0, validado 2026-08-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-003
Característica: Editar un artículo

  Quién lo hace: Responsable de Almacén
  Dónde: Almacenes → Articulos → (ícono de edición de una fila)

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y Existe al menos un artículo en la empresa

  Escenario: Camino principal
    Cuando En el listado de artículos hace clic en el ícono de edición de una fila
    Entonces Se abre el formulario con los datos del artículo cargados
    Y cuando Modifica la descripción, el tipo, la unidad de medida o el punto de pedido
    Entonces El formulario acepta los cambios
    Y cuando Confirma
    Entonces El artículo queda actualizado y el listado refleja el cambio

  # Reglas que este caso verifica:
  #   - Si el punto de pedido se deja vacío, se guarda como 0
  #   - El código y la unidad de medida solo los puede cambiar un Administrador de la empresa: cambiarlos con existencias o con movimientos ya registrados altera el significado de lo que está cargado

  # ⚠️ Atención al ejecutarlo:
  #   `update_editar($data, $id)` arma el WHERE solo con el id del artículo, sin empresa: con el id de un artículo ajeno se podría editar el de otra empresa. NO se ejecutó la prueba para no alterar datos de otra empresa — el hallazgo es lo que dice el código (H-037 / issue #479).
