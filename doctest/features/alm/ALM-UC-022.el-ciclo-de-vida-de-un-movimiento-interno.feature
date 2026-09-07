# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-022.yaml (versión 1.0, validado 2026-09-07).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-022
Característica: El ciclo de vida de un movimiento interno

  Quién lo hace: Responsable de Almacén
  Dónde: Almacenes → Movimientos Internos · Almacenes → Movimientos Internos → Nueva Salida · Almacenes → Movimientos Internos → Recepción

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y Hay stock en el depósito de origen

  Escenario: Camino principal
    Cuando Registra la salida de mercadería de un depósito hacia otro (ALM-UC-016)
    Entonces El movimiento aparece en el listado en estado **En Curso**. La mercadería ya salió del depósito de origen
    Y cuando Registra la recepción en el depósito de destino (ALM-UC-017)
    Entonces El movimiento pasa a **Recibido**. La mercadería queda disponible en el depósito de destino

  Escenario: Llegó menos de lo que salió
    Cuando Recibe una cantidad menor a la que salió del depósito de origen
    Entonces Se registra lo que llegó. La diferencia no se resuelve acá: el Responsable de Almacén la corrige con un ajuste de stock (ALM-UC-014), justificando el motivo

  Escenario: El movimiento queda en tránsito
    Cuando Consulta el listado después de la salida y antes de la recepción
    Entonces El movimiento se muestra **En Curso**: ya no está en el origen y todavía no está en el destino

  # Reglas que este caso verifica:
  #   - Un movimiento nace **En Curso** con la salida y pasa a **Recibido** con la recepción
  #   - Los dos son los únicos estados que la pantalla reconoce y colorea
  #   - **Un movimiento no se cancela.** No hay forma de anular una salida ya registrada: si se registró de más o por error, la corrección se hace con un **ajuste de stock**
  #   - **Si llega menos de lo que salió, se recibe lo que efectivamente llegó** y la diferencia la corrige el Responsable de Almacén con un ajuste, que **exige justificar el porqué**
