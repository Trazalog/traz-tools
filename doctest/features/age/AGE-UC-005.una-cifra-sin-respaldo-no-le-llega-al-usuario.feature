# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/age/AGE-UC-005.yaml (versión 1.0, validado 2026-11-22).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/age/AGE-UC-001-009.panel-de-los-agentes.spec.ts

@age @AGE-UC-005
Característica: Una cifra sin respaldo no le llega al usuario

  Quién lo hace: Usuario
  Dónde: Cualquier pantalla de Tools → botón Q

  Antecedentes:
    Dado Sesión iniciada en Tools, con el agente habilitado en el menú

  Escenario: Camino principal
    Cuando Pregunta algo cuya respuesta necesita un número que el sistema no tiene
    Entonces Quirqui responde que no tiene datos para responder eso con certeza, en lugar de dar un número inventado

  # Reglas que este caso verifica:
  #   - Todo número de una respuesta sale de los datos del sistema, del conocimiento registrado, de la pregunta del usuario o de una fuente de internet citada
  #   - Decisión del PM (2026-11-22): el mensaje de bloqueo es 'No tengo ese dato confirmado. ¿Querés que lo busque en los datos de tu empresa o en internet?'
