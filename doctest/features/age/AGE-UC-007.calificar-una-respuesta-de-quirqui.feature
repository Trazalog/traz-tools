# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/age/AGE-UC-007.yaml (versión 1.0, validado 2026-11-22).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/age/AGE-UC-001-009.panel-de-los-agentes.spec.ts

@age @AGE-UC-007
Característica: Calificar una respuesta de Quirqui

  Quién lo hace: Usuario
  Dónde: Cualquier pantalla de Tools → botón Q

  Antecedentes:
    Dado Sesión iniciada en Tools, con el agente habilitado en el menú
    Y Quirqui respondió una pregunta

  Escenario: Camino principal
    Cuando Marca con el pulgar arriba o abajo una respuesta
    Entonces La calificación queda registrada

  # Reglas que este caso verifica:
  #   - Un usuario no puede calificar la respuesta de otra empresa
  #   - Decisión del PM (2026-11-22): en el panel, una calificación negativa ofrece tres motivos rápidos ('no era eso', 'dato equivocado', 'no se entiende') y un campo libre, opcionales
