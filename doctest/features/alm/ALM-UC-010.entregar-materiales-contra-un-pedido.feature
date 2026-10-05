# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-010.yaml (versión 1.0, validado 2026-08-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-010
Característica: Entregar materiales contra un pedido

  Quién lo hace: Responsable de Almacén
  Dónde: Almacenes → Entrega Materiales

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y Existe un pedido de materiales pendiente de entrega
    Y Hay existencias del artículo en el depósito

  Escenario: Camino principal
    Cuando Entra a Almacenes → Entrega Materiales
    Entonces Se muestra el listado con N° de Pedido, N° de Entrega, Ord.Trabajo, Fecha, N° Comprobante, Entregado y Estado Ped.
    Y cuando Abre un pedido pendiente
    Entonces Se muestran los artículos pedidos con la cantidad pedida y la cantidad a entregar
    Y cuando Indica cuánto entrega de cada artículo y elige de qué lote y depósito sale
    Entonces Las cantidades quedan cargadas. La pantalla no ofrece agregar más de lo pedido ni sacar de un lote sin existencias
    Y cuando Confirma la entrega
    Entonces La entrega queda registrada, el stock del depósito baja y el pedido actualiza cuánto lleva entregado

  Escenario: Entrega parcial
    Cuando Indica una cantidad menor a la pedida de un artículo
    Entonces La entrega se registra por esa cantidad
    Y cuando Vuelve al listado de pedidos
    Entonces El pedido queda con saldo pendiente y admite una entrega posterior

  # Reglas que este caso verifica:
  #   - La entrega descuenta stock del depósito y del lote indicados
  #   - No se puede entregar más de lo pedido
  #   - No se puede entregar si el lote no tiene existencias
  #   - Quien elige el lote del que sale la mercadería es el Responsable de Almacén
  #   - Una entrega registrada no se anula ni se corrige: toda corrección se hace por un ajuste de stock (ALM-UC-014)
