# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-021.yaml (versión 1.0, validado 2026-09-07).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-021
Característica: Imprimir el remito de un movimiento interno

  Quién lo hace: Responsable de Almacén
  Dónde: Almacenes → Movimientos Internos

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y Existe al menos un movimiento interno, creado con ALM-UC-016

  Escenario: Camino principal
    Cuando En el listado de movimientos internos, usa la acción Imprimir de una fila
    Entonces Se arma el remito de ese movimiento, con la cabecera —origen, destino, fecha— y el detalle de lo que se movió

  Escenario: La empresa no tiene logo cargado
    Cuando Imprime el remito de una empresa que no tiene logo configurado
    Entonces El remito se arma igual, sin el logo

  # Reglas que este caso verifica:
  #   - El remito solo debería armarse para movimientos de la empresa de la sesión
  #   - El logo que se imprime es el de la empresa de la sesión
  #   - **Es el comprobante del movimiento y se imprime en cualquier momento**: antes de mover, para que acompañe físicamente la mercadería, y después, para auditar lo que se movió. No depende del estado
  #   - Se puede reimprimir todas las veces que haga falta: no se registra la impresión
