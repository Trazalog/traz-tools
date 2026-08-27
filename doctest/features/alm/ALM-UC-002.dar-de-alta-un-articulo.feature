# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-002.yaml (versión 1.0, validado 2026-08-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-002
Característica: Dar de alta un artículo

  Quién lo hace: Responsable de Almacén
  Dónde: Almacenes → Articulos → Agregar

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y La empresa tiene cargadas sus unidades de medida y sus tipos de artículo

  Escenario: Camino principal
    Cuando En el listado de artículos hace clic en 'Agregar'
    Entonces Se abre el formulario de alta
    Y cuando Completa el código del artículo, el tipo, la descripción y la unidad de medida
    Entonces El formulario acepta los datos. El identificador interno lo asigna el sistema: el usuario solo escribe el código
    Y cuando Si el artículo se maneja por lotes, marca '¿Lotear Artículo?'
    Entonces A partir de ahí las existencias de ese artículo se llevan por lote dentro de cada depósito, y al recibirlo hay que indicar el número de lote
    Y cuando Opcionalmente carga el punto de pedido y la cantidad por caja
    Entonces Los valores quedan asociados al artículo
    Y cuando Confirma con 'Guardar'
    Entonces El artículo queda dado de alta y aparece en el listado

  Escenario: El código ya existe en la empresa
    Cuando Completa el formulario con un código que ya está en uso
    Entonces El formulario acepta los datos
    Y cuando Confirma con 'Guardar'
    Entonces El sistema avisa que el artículo ya existe y no lo da de alta

  # Reglas que este caso verifica:
  #   - Código, tipo, descripción y unidad de medida son obligatorios
  #   - El código es único dentro de la empresa
  #   - El identificador interno del artículo lo asigna el sistema y es único en todo el sistema: el usuario no lo escribe
  #   - El punto de pedido es uno solo por artículo y por empresa, no por depósito
  #   - El punto de pedido, si se deja vacío al editar, se guarda como 0
  #   - El artículo se da de alta en la empresa de la sesión

  # Datos de prueba:
  #   empresa: EMPRESA_TEST_1
  #   codigo_prefijo: DOCTEST-ART-
  #   nota_codigo: sufijo único por corrida, para no chocar con artículos existentes

  # ⚠️ Atención al ejecutarlo:
  #   El alta no verifica el perfil del usuario: alcanza con tener sesión (H-037 / issue #479).
