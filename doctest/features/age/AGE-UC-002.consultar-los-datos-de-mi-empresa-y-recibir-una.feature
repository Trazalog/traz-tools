# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/age/AGE-UC-002.yaml (versión 1.0, validado 2026-11-22).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/age/AGE-UC-001-009.panel-de-los-agentes.spec.ts

@age @AGE-UC-002
Característica: Consultar los datos de mi empresa y recibir una respuesta respaldada

  Quién lo hace: Responsable de Almacén
  Dónde: Cualquier pantalla de Tools → botón Q

  Antecedentes:
    Dado Sesión iniciada en Tools, con el agente habilitado en el menú
    Y La empresa tiene artículos con stock cargado

  Escenario: Camino principal
    Cuando Abre el panel de Quirqui y pregunta si hay stock de un artículo
    Entonces Quirqui consulta el stock de la empresa y responde con la cantidad que devolvió el sistema
    Y cuando Pregunta qué conviene hacer si el stock está bajo el punto de pedido
    Entonces Quirqui explica cómo pedir la reposición y en qué pantalla se hace, sin hacerlo él

  Escenario: El sistema no responde
    Cuando Pregunta por el stock cuando la consulta de datos falla
    Entonces Quirqui dice que no pudo consultar el dato en este momento, sin inventar una cantidad

  # Reglas que este caso verifica:
  #   - Los datos son siempre de la empresa del usuario; nunca de otra
  #   - Toda cantidad de la respuesta sale de lo que devolvió el sistema en esa consulta
  #   - Decisión del PM (2026-11-22): cada dato de la empresa se acompaña, al final de la frase, de la consulta de la que salió (por ejemplo, 'según el stock de hoy del depósito Central')
