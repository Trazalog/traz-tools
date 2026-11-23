# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/age/AGE-UC-006.yaml (versión 1.0, validado 2026-11-22).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/age/AGE-UC-001-009.panel-de-los-agentes.spec.ts

@age @AGE-UC-006
Característica: Buscar información pública con la fuente citada

  Quién lo hace: Usuario
  Dónde: Cualquier pantalla de Tools → botón Q

  Antecedentes:
    Dado Sesión iniciada en Tools, con el agente habilitado en el menú
    Y La búsqueda en internet está habilitada en el ambiente

  Escenario: Camino principal
    Cuando Pregunta por un dato público que el conocimiento registrado no tiene, como una norma
    Entonces Quirqui busca en internet y responde citando la dirección de la fuente

  # Reglas que este caso verifica:
  #   - Si la respuesta usa un número de internet, lleva la dirección de la fuente
  #   - La búsqueda nunca incluye datos de la empresa
  #   - Decisión del PM (2026-11-22): una respuesta con información de internet lo avisa en una línea: 'Esto lo saqué de internet (fuente: …). No lo validó un experto de Trazalog.'
