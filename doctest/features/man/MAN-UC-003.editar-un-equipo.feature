# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-003.yaml (versión 1.0, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-003
Característica: Editar un equipo

  Quién lo hace: Supervisor
  Dónde: Mantenimiento → Equipos → (editar una fila)

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner
    Y Existe al menos un equipo en la empresa

  Escenario: Camino principal
    Cuando En el listado abre un equipo para editarlo
    Entonces Se muestra el formulario con los datos cargados
    Y cuando Modifica lo que corresponda y guarda
    Entonces El equipo queda actualizado
