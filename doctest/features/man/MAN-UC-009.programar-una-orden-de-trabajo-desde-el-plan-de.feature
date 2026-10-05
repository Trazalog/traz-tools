# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-009.yaml (versión 1.0, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-009
Característica: Programar una orden de trabajo desde el plan de mantenimiento

  Quién lo hace: Planificador
  Dónde: Mantenimiento → Plan de Mantenimiento

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner
    Y Hay trabajo pendiente de programar (una solicitud aceptada, un preventivo vencido, un backlog o un predictivo)

  Escenario: Camino principal
    Cuando Entra a Mantenimiento → Plan de Mantenimiento
    Entonces Se muestra el calendario con lo que hay para programar
    Y cuando Elige qué va a programar y para cuándo
    Entonces El formulario pide la fecha de programación según el tipo de trabajo
    Y cuando Confirma con 'Generar Orden'
    Entonces Se crea la orden de trabajo y arranca su circuito

  # Reglas que este caso verifica:
  #   - Las órdenes se programan **de a una**
  #   - **No se debería poder programar una actividad ya vencida**
  #   - La orden hereda las herramientas y los insumos declarados en el trabajo de origen
