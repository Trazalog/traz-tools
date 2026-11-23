# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/age/AGE-UC-003.yaml (versión 1.0, validado 2026-11-22).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/age/AGE-UC-001-009.panel-de-los-agentes.spec.ts

@age @AGE-UC-003
Característica: Ver o descartar el siguiente paso que propone Quirqui

  Quién lo hace: Responsable de Almacén
  Dónde: Almacenes → cualquier pantalla → botón Q · Herramientas → cualquier pantalla → botón Q

  Antecedentes:
    Dado Sesión iniciada en Tools, con el agente habilitado en el menú
    Y La empresa tiene un lote vencido o un artículo bajo su punto de pedido

  Escenario: Camino principal
    Cuando Abre el panel de Quirqui en una pantalla de Almacenes
    Entonces Arriba aparecen hasta tres propuestas, la más urgente primero
    Y cuando Elige 'Ver cómo' en una propuesta
    Entonces Se muestra qué hacer y un enlace a la ayuda

  Escenario: El usuario descarta una propuesta
    Cuando Elige 'Descartar'
    Entonces La propuesta desaparece y no se le vuelve a mostrar por siete días

  Escenario: No hay nada para proponer
    Cuando Abre el panel en una empresa sin vencimientos ni faltantes
    Entonces No aparece ninguna propuesta

  # Reglas que este caso verifica:
  #   - Lo que descarta un usuario se le sigue mostrando a los demás
  #   - Quirqui no hace nada por su cuenta: la propuesta dice cómo hacerlo
  #   - Decisión del PM (2026-11-22): valores por defecto confirmados (certificaciones a 30 días, una propuesta descartada no se repite por 7 días, máximo 3 propuestas); las propuestas sobre el trabajo de cada usuario llegan con la lectura de Tareas
