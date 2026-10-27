# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/pan/PAN-UC-004.yaml (versión 1.0, validado 2026-09-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@pan @PAN-UC-004
Característica: Entregar herramientas y emitir el vale

  Quién lo hace: Usuario
  Dónde: Herramientas → Movimientos Herramientas → Nueva Entrega

  Antecedentes:
    Dado Hay herramientas en estado Activa en el pañol

  Escenario: Camino principal
    Cuando Entra a Movimientos Herramientas
    Entonces Se muestra la grilla con Nro. Vale, Tipo, Fecha y Hora, Establecimiento/Pañol, Responsable y Herramientas, ordenada por fecha y hora descendente
    Y cuando Abre Nueva Entrega
    Entonces Se abre el modal con Establecimiento, Pañol, los datos del encargado, Observaciones y el selector de Herramientas
    Y cuando Elige las herramientas una por una con Agregar
    Entonces Las herramientas se van sumando a la lista del vale
    Y cuando Guarda
    Entonces Se registra la entrega con su Nro. de Vale y las herramientas pasan a estado Entregada
    Y cuando Usa la acción de impresión de esa fila
    Entonces Se muestra el vale con el logo de la empresa, Nº, fecha, establecimiento/depósito, nombre y DNI del responsable, la tabla de código y descripción, y las observaciones

  # Reglas que este caso verifica:
  #   - Una herramienta que ya está Entregada NO puede volver a entregarse sin haber sido recepcionada antes
  #   - Una herramienta Inhabilitada no puede entregarse
  #   - En la grilla, las herramientas del vale se muestran concatenadas como CÓDIGO-DESCRIPCIÓN / CÓDIGO2-DESCRIPCIÓN2, cortadas a 400 caracteres con '...'
  #   - El número de vale es el id del vale
  #   - El logo del vale usa el mismo parámetro que el resto de los logos del sistema
  #   - El vale aclara que no es válido como factura

  # Datos de prueba:
  #   empresa: EMPRESA_TEST_1
