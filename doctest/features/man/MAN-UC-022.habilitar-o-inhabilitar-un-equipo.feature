# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-022.yaml (versión 2.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-022
Característica: Habilitar o inhabilitar un equipo

  Quién lo hace: Supervisor
  Dónde: Mantenimiento → Equipos → Habilitar / Inhabilitar

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO)
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"
    Y Existe el equipo

  Escenario: Camino principal
    Cuando En el listado, sobre un equipo activo, elige Inhabilitar
    Entonces El equipo pasa a estado inactivo y la columna Estado lo refleja
    Y cuando Sobre un equipo inactivo, elige Habilitar
    Entonces El equipo vuelve a estar activo

  # Reglas que este caso verifica:
  #   - Inhabilitar deja el equipo en estado `IN`; habilitar lo devuelve a activo (`AC`)
  #   - La acción que se ofrece depende del estado actual: a un equipo activo se le ofrece Inhabilitar y a uno inactivo, Habilitar
