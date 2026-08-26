# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-018.yaml (versión 1.0, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-018
Característica: Definir un mantenimiento predictivo

  Quién lo hace: Planificador
  Dónde: Mantenimiento → Predictivo

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner
    Y El equipo tiene parámetros configurados y lecturas cargadas

  Escenario: Camino principal
    Cuando Entra a Mantenimiento → Predictivo
    Entonces Se listan los predictivos con Id, Equipo, Tarea, Fecha, Período, Cantidad y Horas Hombre
    Y cuando Crea uno nuevo: elige el equipo y la tarea
    Entonces Queda definido el trabajo
    Y cuando Define el período y la cantidad que lo dispara
    Entonces Queda definido cuándo corresponde hacerlo
    Y cuando Declara herramientas e insumos
    Entonces Quedan asociados, igual que en el preventivo

  # Reglas que este caso verifica:
  #   - Las herramientas e insumos quedan declarados, no pedidos — igual que en el preventivo
  #   - Las herramientas y los insumos quedan declarados, no pedidos
