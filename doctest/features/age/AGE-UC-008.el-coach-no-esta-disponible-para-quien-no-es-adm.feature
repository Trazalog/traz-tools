# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/age/AGE-UC-008.yaml (versión 1.0, validado 2026-11-22).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/age/AGE-UC-001-009.panel-de-los-agentes.spec.ts

@age @AGE-UC-008
Característica: El Coach no está disponible para quien no es administrador

  Quién lo hace: Usuario
  Dónde: Cualquier pantalla de Tools

  Antecedentes:
    Dado Sesión iniciada en Tools con un usuario que no es administrador

  Escenario: Camino principal
    Cuando Busca al Coach entre los agentes disponibles
    Entonces Solo aparece Quirqui; el Coach no figura

  Escenario: Intenta llamar al Coach directamente
    Cuando Pide una consulta al Coach sin ser administrador
    Entonces Recibe la misma respuesta que si el Coach no existiera

  # Reglas que este caso verifica:
  #   - Un usuario que no es administrador no puede ver ni usar al Coach por ninguna vía, ni confirmar que existe
  #   - Decisión del PM (2026-11-22): 'administrador' es el nivel 1 de Dnato hasta que Dnato v3 tenga administradores por empresa
