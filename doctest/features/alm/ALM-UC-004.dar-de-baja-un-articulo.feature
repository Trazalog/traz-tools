# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-004.yaml (versión 1.0, validado 2026-08-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-004
Característica: Dar de baja un artículo

  Quién lo hace: Responsable de Almacén
  Dónde: Almacenes → Articulos → (acción de baja de una fila)

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y Existe un artículo activo en la empresa

  Escenario: Camino principal
    Cuando En el listado hace clic en la acción de baja de un artículo sin existencias
    Entonces El sistema pide confirmación
    Y cuando Confirma la baja
    Entonces El artículo queda dado de baja —la baja es lógica, el artículo no se borra— y la columna Estado lo refleja

  Escenario: El artículo todavía tiene existencias
    Cuando Intenta dar de baja un artículo con stock
    Entonces El sistema no lo permite: primero hay que dejar el artículo en cero

  # Reglas que este caso verifica:
  #   - La baja es lógica: el artículo nunca se borra, para no romper la trazabilidad de lo que se movió con él
  #   - No se puede dar de baja un artículo que todavía tiene existencias
  #   - Un artículo dado de baja no se ofrece para elegir en un pedido nuevo
  #   - La columna Estado del listado distingue los artículos dados de baja
