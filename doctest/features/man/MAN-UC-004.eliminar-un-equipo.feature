# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-004.yaml (versión 1.0, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-004
Característica: Eliminar un equipo

  Quién lo hace: Supervisor
  Dónde: Mantenimiento → Equipos → Eliminar

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner
    Y Existe un equipo activo

  Escenario: Camino principal
    Cuando En la columna Acciones del listado elige Eliminar
    Entonces El sistema pide confirmación
    Y cuando Confirma
    Entonces El equipo deja de figurar en el listado
