# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-011.yaml (versión 1.0, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-011
Característica: Ejecutar una orden de trabajo y pedir los materiales

  Quién lo hace: Mantenedor
  Dónde: Mantenimiento → Ordenes de trabajo → Ejecutar

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner
    Y Existe una orden de trabajo programada

  Escenario: Camino principal
    Cuando Abre la orden de trabajo y elige ejecutarla
    Entonces Se muestra qué hay que hacer, con las herramientas y los insumos que se declararon
    Y cuando Revisa los materiales que hacen falta y agrega los que falten
    Entonces El pedido de materiales queda armado
    Y cuando Confirma la ejecución
    Entonces El pedido se manda al almacén para que lo aprueben y lo entreguen

  # Reglas que este caso verifica:
  #   - El pedido se crea, y desde ahí lo toma el almacenero: **aprueba o rechaza, y después entrega**
  #   - El pedido de materiales se arma con los insumos declarados en la orden
