# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-006.yaml (versión 1.0, validado 2026-08-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-006
Característica: Pedir materiales al almacén

  Quién lo hace: Solicitante
  Dónde: Almacenes → Pedido Materiales · Almacenes → Pedido Materiales → Agregar

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y La empresa tiene artículos cargados

  Escenario: Camino principal
    Cuando Entra a Almacenes → Pedido Materiales
    Entonces Se muestra el listado de pedidos con las columnas Acciones, Pedido, Ord.Trabajo, Fecha, Detalle y Estado
    Y cuando Hace clic en 'Agregar'
    Entonces Se abre el formulario de pedido nuevo
    Y cuando Escribe la justificación del pedido
    Entonces El formulario acepta el texto
    Y cuando Busca un artículo, indica la cantidad y lo agrega al pedido
    Entonces El artículo aparece en el detalle del pedido con su cantidad
    Y cuando Repite para cada artículo que necesita
    Entonces El detalle acumula todos los artículos pedidos
    Y cuando Elige el establecimiento y el depósito al que se le pide
    Entonces El pedido queda dirigido a ese depósito
    Y cuando Confirma con 'Guardar'
    Entonces El pedido queda creado en estado 'Creada' y se dispara el proceso de aprobación en Bonita

  Escenario: El pedido nace de una orden de trabajo
    Cuando Desde una orden de trabajo pide material para esa orden
    Entonces El formulario se abre con la orden ya asociada
    Y cuando Carga los artículos y confirma
    Entonces El pedido queda asociado a la orden y aparece en la columna Ord.Trabajo del listado

  Escenario: El proceso en Bonita no arranca
    Cuando Confirma el pedido y el proceso de Bonita falla
    Entonces El pedido **se elimina**: no debe quedar un pedido guardado sin su proceso de aprobación

  # Reglas que este caso verifica:
  #   - La justificación es obligatoria siempre, venga el pedido de una orden de trabajo o no
  #   - No hay tope de cantidad: se puede pedir lo que sea, aunque no haya existencias — el pedido no mueve stock
  #   - El pedido se crea en estado 'Creada'
  #   - Si el proceso de Bonita falla, el pedido se elimina
  #   - El pedido queda asociado a la empresa de la sesión

  # Datos de prueba:
  #   empresa: EMPRESA_TEST_1
  #   articulo: uno existente de la empresa de prueba
  #   cantidad: 1

  # ⚠️ Atención al ejecutarlo:
  #   El pedido extraordinario quedó declarado **obsoleto por el PM (2026-08-25)** y se sacó de este caso. El `empr_id` fijo en 1 que tenía (issue #480) deja de ser urgente por eso, pero el issue sigue abierto porque el código está.
