# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-024.yaml (versión 1.0, validado 2026-09-07).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-024
Característica: Ver el detalle de un ajuste de stock

  Quién lo hace: Responsable de Almacén
  Dónde: Almacenes → Ajustes de Stock

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y Existe al menos un ajuste, registrado con ALM-UC-014

  Escenario: Camino principal
    Cuando En el listado de ajustes, usa la acción Ver Detalle de una fila
    Entonces Se abre el detalle, que muestra el Id del ajuste, el Tipo de Ajuste y la **Justificación**, y debajo una fila por artículo ajustado con Código, Descripción, Cantidad, Tipo Ajuste y U. Med

  # Reglas que este caso verifica:
  #   - El detalle solo debería ser visible para la empresa dueña del ajuste
  #   - El detalle es de consulta: un ajuste registrado no se edita ni se borra — corregirlo es registrar otro ajuste
  #   - **La justificación se muestra**: es el campo que explica por qué se ajustó y el que mira quien audita
  #   - El tipo de ajuste aparece dos veces y son cosas distintas: el de la cabecera y el de **cada línea**, que es el que vale por artículo
