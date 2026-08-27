# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-015.yaml (versión 1.0, validado 2026-08-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-015
Característica: Ver los artículos que llegaron al punto de pedido

  Quién lo hace: Responsable de Almacén
  Dónde: Almacenes → Punto de Pedido

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y Hay artículos con punto de pedido cargado

  Escenario: Camino principal
    Cuando Entra a Almacenes → Punto de Pedido
    Entonces Se listan los artículos con las columnas Producto, Código, Punto Pedido, Cant. Stock y Cant. Disponible

  # Reglas que este caso verifica:
  #   - Un artículo aparece cuando su **cantidad disponible** queda por debajo de su punto de pedido
  #   - La cantidad disponible es la existencia física menos lo que está comprometido en pedidos todavía abiertos
  #   - El punto de pedido es uno solo por artículo y por empresa, no por depósito
  #   - Es una pantalla de consulta: no dispara ninguna acción
  #   - Solo se listan artículos de la empresa de la sesión
