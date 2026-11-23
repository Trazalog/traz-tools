# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/age/AGE-UC-009.yaml (versión 1.0, validado 2026-11-22).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/age/AGE-UC-001-009.panel-de-los-agentes.spec.ts

@age @AGE-UC-009
Característica: Saber qué se mide de lo que hablo con Quirqui

  Quién lo hace: Usuario
  Dónde: Cualquier pantalla de Tools → botón Q

  Antecedentes:
    Dado Sesión iniciada en Tools, con el agente habilitado en el menú

  Escenario: Camino principal
    Cuando Abre el panel de Quirqui
    Entonces Ve el aviso de que lo que habla con Quirqui se usa para medir indicadores de la empresa
    Y cuando Elige '¿Qué se mide?'
    Entonces Se despliega qué se registra y que el administrador no ve las conversaciones

  # Reglas que este caso verifica:
  #   - El aviso está siempre visible mientras el panel está abierto
  #   - Decisión del PM (2026-11-22): el caso se valida con el texto provisorio del aviso; se reemplaza cuando llegue la revisión legal (AGENTE-LEGAL-01)
