# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-017.yaml (versión 1.0, validado 2026-08-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-017
Característica: Mover mercadería entre depósitos — recepción

  Quién lo hace: Responsable de Almacén
  Dónde: Almacenes → Movimientos Internos → Nueva Recepción

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y Existe un movimiento de salida pendiente de recibir

  Escenario: Camino principal
    Cuando En Movimientos Internos hace clic en 'Nueva Recepción'
    Entonces Se abre el formulario de recepción en depósito
    Y cuando Elige el movimiento que está recibiendo
    Entonces Se muestran los artículos y las cantidades que salieron del origen
    Y cuando Carga lo que efectivamente recibió
    Entonces Si la cantidad no coincide con la que salió, la pantalla avisa la diferencia y exige una justificación
    Y cuando Justifica la diferencia si la hay y confirma
    Entonces El stock del depósito de destino sube por lo efectivamente recibido y el movimiento queda cerrado

  # Reglas que este caso verifica:
  #   - Si lo recibido difiere de lo que salió, la justificación es obligatoria
  #   - El stock del depósito de destino sube por la cantidad efectivamente recibida

  # ⚠️ Atención al ejecutarlo:
  #   Misma advertencia que ALM-UC-016: pantalla que no está en el árbol de `develop-v3` (H-038 / issue #481).
