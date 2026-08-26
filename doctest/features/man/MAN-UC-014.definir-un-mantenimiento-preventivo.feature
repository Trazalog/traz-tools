# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-014.yaml (versión 1.0, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-014
Característica: Definir un mantenimiento preventivo

  Quién lo hace: Planificador
  Dónde: Mantenimiento → Preventivo

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner
    Y El equipo está dado de alta

  Escenario: Camino principal
    Cuando Entra a Mantenimiento → Preventivo
    Entonces Se listan los preventivos con Id tarea, Tarea, Equipo, Grupo, Componente, Período, Frecuencia, Fecha Base y Horas Hombre
    Y cuando Crea uno nuevo y elige el equipo y la tarea a realizar
    Entonces Queda definido qué se hace y sobre qué
    Y cuando Define el período y la frecuencia con que se repite, y la fecha base
    Entonces El sistema sabe cuándo vence la próxima vez
    Y cuando Indica cuántas horas hombre lleva
    Entonces Queda registrada la duración estimada
    Y cuando Agrega las herramientas y los insumos que hacen falta
    Entonces Quedan declarados, para copiarse a cada orden de trabajo que se genere
    Y cuando Guarda
    Entonces El preventivo queda activo y va a aparecer en el plan de mantenimiento cuando venza

  # Reglas que este caso verifica:
  #   - Las herramientas y los insumos quedan **declarados**, no pedidos: el pedido nace al ejecutar cada orden
