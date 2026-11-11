# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-014.yaml (versión 2.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-014-018.planes.spec.ts

@man @MAN-UC-014
Característica: Definir un mantenimiento preventivo

  Quién lo hace: Planificador
  Dónde: Mantenimiento → Preventivo

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO)
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"
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
  #   - Las herramientas salen del pañol de tools y los insumos del almacén de tools
  #   - El preventivo se graba entero o no se graba: cabecera, herramientas e insumos van en una sola operación (E20)
