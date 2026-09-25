# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/pan/PAN-UC-002.yaml (versión 1.0, validado 2026-09-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@pan @PAN-UC-002
Característica: Dar de alta una herramienta con su tipo y su QR

  Quién lo hace: Usuario
  Dónde: Herramientas → Herramientas → Agregar

  Antecedentes:
    Dado La empresa tiene al menos un establecimiento con un pañol
    Y Hay tipos de herramienta cargados en core.tablas

  Escenario: Camino principal
    Cuando Abre Agregar
    Entonces Se abre el modal de alta con Establecimiento, Pañol, Código, Descripción, Modelo, Tipo y Marca, todos obligatorios
    Y cuando Selecciona uno o varios tipos de herramienta
    Entonces Los tipos se muestran como etiquetas de colores y se pueden seleccionar y deseleccionar varios
    Y cuando Completa el resto y guarda
    Entonces La herramienta se crea en estado Activa y aparece en la grilla
    Y cuando Usa la acción de código QR sobre la herramienta
    Entonces Se muestra el QR con código, descripción, modelo, marca y los tipos, y se puede imprimir

  Escenario: Reimprimir el QR más adelante
    Cuando Vuelve a usar la acción de código QR sobre una herramienta ya creada
    Entonces Se vuelve a mostrar el QR, listo para imprimir

  # Reglas que este caso verifica:
  #   - Los tipos NO se graban en la tabla de la herramienta: van en una tabla intermedia contra core.tablas, y una herramienta puede tener varios
  #   - Cada tipo se muestra gris salvo que su `valor2` traiga un código de color
  #   - Las dimensiones del QR se configuran en core.tablas
  #   - El `empr_id` del payload tiene que viajar como string: el DataService lo declara STRING (H-084)

  # Datos de prueba:
  #   empresa: EMPRESA_TEST_1
