# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-007.yaml (versión 1.0, validado 2026-09-07).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-007
Característica: Ver el detalle de un pedido de materiales

  Quién lo hace: Solicitante
  Dónde: Almacenes → Pedido Materiales → (ver detalle de una fila)

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y Existe un pedido, creado con ALM-UC-006

  Escenario: Camino principal
    Cuando En el listado de pedidos abre el detalle de una fila
    Entonces Se muestran los artículos pedidos con su cantidad, cuánto se entregó y de qué depósito

  # Reglas que este caso verifica:
  #   - El detalle de un pedido solo debería ser visible para la empresa dueña del pedido
  #   - **Un Solicitante ve solo sus propios pedidos.** Los demás perfiles del almacén ven los de la empresa

  # ⚠️ Atención al ejecutarlo:
  #   El aislamiento entre empresas quedó **confirmado por el PM** el 2026-08-25: el detalle no debe verse desde otra empresa. Hoy no se cumple y está verificado en vivo (issue #478). Cuando el caso salga de borrador, el test se deriva con `test.fail()` y el issue anotado.
