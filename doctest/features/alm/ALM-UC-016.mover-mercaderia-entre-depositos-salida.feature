# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-016.yaml (versión 1.0, validado 2026-08-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-016
Característica: Mover mercadería entre depósitos — salida

  Quién lo hace: Responsable de Almacén
  Dónde: Almacenes → Movimientos Internos · Almacenes → Movimientos Internos → Nueva Salida

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y La empresa tiene al menos dos depósitos
    Y Hay existencias en el depósito de origen

  Escenario: Camino principal
    Cuando Entra a Almacenes → Movimientos Internos
    Entonces Se muestra el listado con Remito, Fecha y Hora, Establecimiento y Depósito de origen, Establecimiento y Depósito de destino, y Estado
    Y cuando Hace clic en 'Nueva Salida'
    Entonces Se abre el formulario de salida de depósito
    Y cuando Elige el depósito de origen y el de destino
    Entonces El movimiento queda definido entre esos dos depósitos
    Y cuando Agrega los artículos y las cantidades que salen, eligiendo el lote
    Entonces El detalle acumula los artículos. Si la cantidad supera lo que hay en el lote, la pantalla avisa cuánto hay y no deja seguir
    Y cuando Confirma la salida
    Entonces El movimiento queda registrado, el stock del depósito de origen baja y el movimiento queda pendiente de recepción en destino

  # Reglas que este caso verifica:
  #   - **Nunca** se puede sacar más de lo que hay en el lote de origen
  #   - El stock del depósito de origen baja al confirmar la salida
  #   - La mercadería en tránsito no figura en ningún depósito: sale del origen y aparece recién cuando se recibe en destino
  #   - Una salida confirmada no se anula

  # ⚠️ Atención al ejecutarlo:
  #   **Esta pantalla no existe en el árbol que ve `develop-v3`**: el controlador entró en un commit posterior al puntero del submódulo (H-038 / issue #481). Está relevada contra `origin/develop`, que es lo que corre en el DEMO. Es funcionalidad reciente y por eso el relevamiento es más superficial que el del resto.
