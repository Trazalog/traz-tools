# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-039.yaml (versión 1.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-038-039.herramientas-insumos-ot.spec.ts

@man @MAN-UC-039
Característica: Asociar a la orden de trabajo los vales del pañol

  Quién lo hace: Mantenedor
  Dónde: Mis Tareas → Confecciona informe de servicio → Herramientas e Insumos · Mis Tareas → Edición Informe de Servicios → Herramientas e Insumos · Mis Tareas → Verifica Informe de Servicio → Herramientas e Insumos

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO) con perfil Mantenedor (o Supervisor al verificar)
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"
    Y El pañolero de tools le entregó herramientas con un vale de salida

  Escenario: Camino principal
    Cuando En el informe, en Herramientas e Insumos, busca sus vales por DNI
    Entonces Se listan los vales de salida del pañol entregados a ese DNI que todavía no están en otra orden
    Y cuando Asocia el vale que usó en esta orden
    Entonces Las herramientas del vale aparecen como usadas en la orden
    Y cuando Destilda la herramienta del vale que al final no usó
    Entonces Esa herramienta queda registrada como no usada

  Escenario: Quitar un vale asociado por error
    Cuando Quita un vale que asoció él
    Entonces El vale deja de estar en la orden y vuelve a estar disponible

  Escenario: El Supervisor corrige los vales al verificar
    Cuando En "Verifica Informe de Servicio" busca vales sin poner DNI
    Entonces Ve los vales disponibles de la empresa y puede asociarlos
    Y cuando Quita un vale que había asociado el pañolero
    Entonces El vale deja de estar en la orden

  # Reglas que este caso verifica:
  #   - **Desde la orden nunca se crea un vale**: los vales los hace siempre el pañolero o el responsable de pañol; acá solo se asocian (regla del PM, 2026-11-03)
  #   - Si el pañolero ya ató el vale a la orden al entregarlo, sus herramientas se ven sin que nadie haga nada
  #   - El Mantenedor busca solo por DNI y solo puede quitar los vales que asoció él; el Supervisor busca sin DNI y puede quitar también los del pañolero (def. 8)
  #   - Un vale no se asocia dos veces a la misma orden, ni se toma uno que ya está en otra orden
  #   - Los permisos se controlan en el servidor, no solo en la pantalla
