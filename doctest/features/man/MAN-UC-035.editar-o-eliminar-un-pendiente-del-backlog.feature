# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-035.yaml (versión 0.1, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-035
Característica: Editar o eliminar un pendiente del backlog

  Quién lo hace: Supervisor
  Dónde: Mantenimiento → Backlog

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner
    Y Existe al menos un pendiente del backlog cargado (MAN-UC-015)

  Escenario: Camino principal
    Cuando En el listado elige la acción Editar sobre una fila
    Entonces Se abren los datos para modificarlos
    Y cuando Cambia lo que corresponda y guarda
    Entonces Queda actualizado

  Escenario: Eliminar
    Cuando Elige la acción Eliminar
    Entonces El sistema pide confirmación
    Y cuando Confirma
    Entonces Deja de figurar en el listado

  # Reglas que este caso verifica:
  #   - Editar el pendiente del backlog afecta a las órdenes que se generen **de ahí en adelante**: las ya creadas conservan lo que se les copió
  #   - El listado ofrece Editar, Eliminar y Ver Archivo sobre cada fila
