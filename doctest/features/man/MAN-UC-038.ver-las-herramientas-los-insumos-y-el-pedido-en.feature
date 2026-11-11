# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-038.yaml (versión 1.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-038-039.herramientas-insumos-ot.spec.ts

@man @MAN-UC-038
Característica: Ver las herramientas, los insumos y el pedido en cada paso de la orden de trabajo

  Quién lo hace: Mantenedor
  Dónde: Mis Tareas → Ejecutar OT → Herramientas e Insumos · Mis Tareas → Confecciona informe de servicio → Herramientas e Insumos · Mis Tareas → Edición Informe de Servicios → Herramientas e Insumos · Mis Tareas → Verifica Informe de Servicio → Herramientas e Insumos · Mis Tareas → Presta conformidad → Herramientas e Insumos

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO)
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"
    Y La orden de trabajo fue asignada con su lista de herramientas y su pedido (MAN-UC-011)

  Escenario: Camino principal
    Cuando Abre una tarea de la orden (Ejecutar OT, informe, edición, verificación o conformidad) y entra a la pestaña "Herramientas e Insumos"
    Entonces Ve las herramientas declaradas en la orden
    Y cuando Mira el pedido al almacén
    Entonces Por cada artículo ve lo pedido, lo entregado y lo pendiente
    Y cuando Mira las entregas
    Entonces Ve cada entrega del almacén con su detalle: comprobante, artículo, lote, depósito y cantidad
    Y cuando Mira las herramientas usadas
    Entonces Ve las herramientas de los vales del pañol asociados a la orden, con quién asoció cada vale

  # Reglas que este caso verifica:
  #   - Lo pedido = lo entregado + lo pendiente
  #   - La misma pestaña está en los cinco pasos de la orden; en Presta conformidad es solo de lectura
  #   - Una orden sin pedido lo dice, en vez de mostrar una tabla vacía
  #   - Las entregas aparecen cuando el almacén entrega desde sus propias pantallas de tools; la orden no entrega nada
