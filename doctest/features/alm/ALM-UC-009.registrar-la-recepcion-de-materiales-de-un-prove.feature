# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-009.yaml (versión 1.0, validado 2026-08-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-009
Característica: Registrar la recepción de materiales de un proveedor

  Quién lo hace: Responsable de Almacén
  Dónde: Almacenes → Recepción Materiales · Almacenes → Recepción Materiales → Agregar

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y La empresa tiene proveedores y depósitos cargados
    Y Los artículos a recibir están dados de alta

  Escenario: Camino principal
    Cuando Entra a Almacenes → Recepción Materiales
    Entonces Se muestra el listado de recepciones con Nº de Comprobante, Fecha y Proveedor
    Y cuando Hace clic en 'Agregar'
    Entonces Se abre el formulario de recepción
    Y cuando Transcribe el número del comprobante físico que trae el proveedor, la fecha y el proveedor
    Entonces Quedan registrados los datos de cabecera
    Y cuando Agrega cada artículo recibido con su cantidad, depósito y establecimiento. Si el artículo es loteado, escribe el número de lote
    Entonces El detalle acumula los artículos recibidos
    Y cuando Confirma la recepción
    Entonces La recepción queda registrada y el stock de esos artículos aumenta en el depósito indicado

  Escenario: Consultar una recepción ya registrada
    Cuando En el listado abre una recepción
    Entonces Se muestra su detalle con los artículos, las cantidades y el depósito
    Y cuando Hace clic en 'Imprimir'
    Entonces La recepción se puede imprimir

  # Reglas que este caso verifica:
  #   - La recepción aumenta el stock del depósito indicado
  #   - El número de comprobante no se valida ni tiene que ser único: es la transcripción del comprobante físico del proveedor
  #   - Para un artículo loteado, el número de lote es obligatorio y lo escribe quien recibe
  #   - Una recepción registrada no se corrige ni se anula: toda corrección se hace por un ajuste de stock (ALM-UC-014)
