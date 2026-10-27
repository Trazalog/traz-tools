# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/pan/PAN-UC-003.yaml (versión 1.0, validado 2026-09-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@pan @PAN-UC-003
Característica: Inhabilitar una herramienta que no está en condiciones de usarse

  Quién lo hace: Usuario
  Dónde: Herramientas → Herramientas → acción Inhabilitar / Habilitar

  Antecedentes:
    Dado Existe una herramienta en estado Activa

  Escenario: Camino principal
    Cuando Usa la acción Inhabilitar sobre una herramienta Activa
    Entonces Se pide confirmación: '¿Está seguro que desea inhabilitar a la herramienta <código>?'
    Y cuando Confirma
    Entonces Se pide una justificación, que es obligatoria
    Y cuando Escribe la justificación y guarda
    Entonces La herramienta queda Inhabilitada y no se puede prestar más
    Y cuando Usa la acción Habilitar sobre esa herramienta
    Entonces Vuelve a estado Activa

  Escenario: La herramienta está entregada
    Cuando Intenta inhabilitar una herramienta en estado Entregada
    Entonces Se muestra el error 'No puede inhabilitar herramienta — No se puede inhabilitar mientras no vuelva a ser recepcionada' y la operación no se hace

  # Reglas que este caso verifica:
  #   - Una herramienta Entregada no se puede inhabilitar: primero tiene que volver al pañol
  #   - La justificación es obligatoria y queda registrada en la trazabilidad de la herramienta
  #   - Una herramienta Inhabilitada no puede salir en un vale de entrega

  # Datos de prueba:
  #   empresa: EMPRESA_TEST_1
  #   precondicion: una herramienta Activa y otra Entregada
