# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-011.yaml (versión 2.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-011
Característica: Asignar la orden de trabajo, con sus herramientas y el pedido de materiales

  Quién lo hace: Planificador
  Dónde: Mantenimiento → Plan de Mantenimiento → (clic en la orden) → Ejecutar OT · Mis Tareas → Asignar Recursos y Tareas

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO) con perfil Planificador
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"
    Y Existe una orden de trabajo programada, creada con MAN-UC-009
    Y La empresa tiene artículos en el almacén de tools y herramientas en el pañol de tools

  Escenario: Camino principal
    Cuando Abre la orden en el calendario y elige ejecutarla
    Entonces Se abre la ventana "Ejecutar OT" con las pestañas Detalle, Herramientas, Pedido Materiales y Asignación Responsable
    Y cuando En Herramientas revisa la lista que la orden heredó de su plan
    Entonces Puede agregar herramientas del maestro del pañol de tools, o en texto libre las que no están, y quitar las que sobran
    Y cuando En Pedido Materiales revisa el pedido
    Entonces El pedido viene prearmado con los insumos de la orden; puede agregar artículos del almacén de tools buscándolos por código o por descripción, y cambiar cantidades
    Y cuando Elige el responsable y confirma con "Asignar OT"
    Entonces Se guardan las herramientas, la tarea "Ejecutar OT" le llega al responsable y el pedido se manda al almacén, atado a la orden

  Escenario: El envío del pedido falló
    Cuando La orden quedó asignada o en curso pero el pedido no se creó
    Entonces La pestaña Pedido Materiales ofrece "Enviar pedido" para reintentarlo, mientras la orden esté `AS` o `C`

  Escenario: La orden ya tiene su pedido
    Cuando Abre de nuevo la ventana de una orden con el pedido enviado
    Entonces Ve el pedido en solo lectura: a una orden con el pedido enviado no se le agregan artículos

  # Reglas que este caso verifica:
  #   - **Una orden tiene un solo pedido de materiales**; ya enviado, no se le agregan artículos (decisión del PM)
  #   - El pedido se crea en el almacén de tools con el número de la orden, y sigue el circuito de Almacenes: el almacenero lo aprueba o lo rechaza, y después entrega
  #   - **Las herramientas no se piden**: solo se declaran en la orden; las que se usan se registran desde los vales del pañol (MAN-UC-039)
  #   - Si el pedido no se puede crear entero (almacén o Bonita), se deshace lo creado y la orden queda sin pedido, lista para "Enviar pedido"
