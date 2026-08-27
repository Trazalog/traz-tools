# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-011.yaml (versión 1.0, validado 2026-08-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-011
Característica: Entregar materiales sin pedido previo (entrega directa)

  Quién lo hace: Responsable de Almacén
  Dónde: Almacenes → Entrega Materiales → Entrega Materiales Directa

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y Hay existencias del artículo en el depósito

  Escenario: Camino principal
    Cuando En Entrega Materiales hace clic en 'Entrega Materiales Directa'
    Entonces Se abre el formulario de entrega sin pedido asociado
    Y cuando Elige los artículos, las cantidades y el depósito de salida
    Entonces El detalle queda cargado
    Y cuando Confirma
    Entonces La entrega queda registrada y el stock baja, sin que exista un pedido detrás

  # Reglas que este caso verifica:
  #   - La entrega directa descuenta stock igual que la entrega contra pedido
  #   - Solo el Responsable de Almacén puede hacer una entrega directa
