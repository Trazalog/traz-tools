# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-037.yaml (versión 1.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-021-037.entrega-informe.spec.ts

@man @MAN-UC-037
Característica: Ver el detalle de un informe de servicio

  Quién lo hace: Supervisor
  Dónde: Mantenimiento → Informe de Servicios

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO)
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"
    Y Hay informes cargados

  Escenario: Camino principal
    Cuando En el listado usa el ícono 'Ver Informe' de una fila
    Entonces Se muestra el informe completo: qué se hizo, quiénes trabajaron, cuánto tiempo llevó y qué materiales figuran

  Escenario: Verificar varios informes juntos
    Cuando Marca las casillas de varias filas (o "Seleccionar todos") y verifica
    Entonces Cada informe seleccionado queda verificado: se cierra su tarea "Verifica Informe de Servicio" en Bonita y el informe y la orden pasan a `CE`

  # Reglas que este caso verifica:
  #   - El listado se puede filtrar por estado
  #   - La verificación en bloque toma el caso de cada orden de la empresa, no el que manda la pantalla (E28)
