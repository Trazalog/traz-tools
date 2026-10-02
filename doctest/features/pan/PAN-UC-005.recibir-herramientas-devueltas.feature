# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/pan/PAN-UC-005.yaml (versión 1.0, validado 2026-09-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@pan @PAN-UC-005
Característica: Recibir herramientas devueltas

  Quién lo hace: Usuario
  Dónde: Herramientas → Movimientos Herramientas → Nueva Recepción

  Antecedentes:
    Dado Hay herramientas en estado Entregada

  Escenario: Camino principal
    Cuando Abre Nueva Recepción
    Entonces Se abre el mismo modal que la entrega, con los mismos campos
    Y cuando Elige las herramientas que vuelven y guarda
    Entonces Se registra la recepción con su propio Nro. de Vale y las herramientas vuelven a estado Activa

  Escenario: Vuelve solo una parte de lo entregado
    Cuando Recibe únicamente algunas de las herramientas del vale de entrega
    Entonces Se genera igual un vale de entrada con lo que volvió. Las que no volvieron siguen Entregadas y se reciben después con otro vale

  Escenario: Se recibe en un pañol distinto al de origen
    Cuando Selecciona un pañol distinto al del vale de entrega
    Entonces Se pregunta: 'Esta herramienta fue Entregada en <Pañol origen>. ¿Está seguro que desea recepcionarla en <Pañol seleccionado>?'
    Y cuando Confirma
    Entonces La herramienta queda registrada en el pañol nuevo

  # Reglas que este caso verifica:
  #   - No existe el concepto de cerrar un vale: cada recepción genera su propio vale de entrada
  #   - Una devolución parcial es válida y no necesita ninguna acción de cierre sobre el vale de entrega
  #   - Recibir en otro pañol está permitido, pero se avisa antes porque cambia la ubicación de la herramienta

  # Datos de prueba:
  #   empresa: EMPRESA_TEST_1
  #   precondicion: un vale de entrega con al menos dos herramientas
