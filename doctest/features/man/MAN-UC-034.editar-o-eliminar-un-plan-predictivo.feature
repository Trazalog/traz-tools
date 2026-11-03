# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-034.yaml (versión 1.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-034
Característica: Editar o eliminar un plan predictivo

  Quién lo hace: Planificador
  Dónde: Mantenimiento → Predictivo

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO)
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"
    Y Existe al menos un plan predictivo cargado (MAN-UC-018)

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
  #   - Editar el plan predictivo afecta a las órdenes que se generen **de ahí en adelante**: las ya creadas conservan lo que se les copió
  #   - El listado ofrece Editar, Eliminar y Ver Archivo sobre cada fila
