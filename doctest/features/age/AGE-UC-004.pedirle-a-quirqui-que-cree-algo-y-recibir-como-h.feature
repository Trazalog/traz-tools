# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/age/AGE-UC-004.yaml (versión 1.0, validado 2026-11-22).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/age/AGE-UC-001-009.panel-de-los-agentes.spec.ts

@age @AGE-UC-004
Característica: Pedirle a Quirqui que cree algo y recibir cómo hacerlo

  Quién lo hace: Mantenedor
  Dónde: Cualquier pantalla de Tools → botón Q

  Antecedentes:
    Dado Sesión iniciada en Tools, con el agente habilitado en el menú

  Escenario: Camino principal
    Cuando Le pide a Quirqui que cree una orden de trabajo para un equipo
    Entonces Quirqui explica cómo crearla y en qué pantalla, pero no la crea

  # Reglas que este caso verifica:
  #   - Ningún agente crea órdenes, pedidos ni ningún otro registro
  #   - Decisión del PM (2026-11-22): Quirqui ofrece el enlace directo a la pantalla de alta
