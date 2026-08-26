# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-022.yaml (versión 1.0, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-022
Característica: Habilitar o inhabilitar un equipo

  Quién lo hace: Supervisor
  Dónde: Mantenimiento → Equipos → Habilitar / Inhabilitar

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner
    Y Existe el equipo

  Escenario: Camino principal
    Cuando En el listado, sobre un equipo activo, elige Inhabilitar
    Entonces El equipo pasa a estado inactivo y la columna Estado lo refleja
    Y cuando Sobre un equipo inactivo, elige Habilitar
    Entonces El equipo vuelve a estar activo

  # Reglas que este caso verifica:
  #   - El equipo tiene dos estados: activo (`AC`) e inhabilitado (`AN`)
  #   - La acción que se ofrece depende del estado actual: a un equipo activo se le ofrece Inhabilitar y a uno inactivo, Habilitar
