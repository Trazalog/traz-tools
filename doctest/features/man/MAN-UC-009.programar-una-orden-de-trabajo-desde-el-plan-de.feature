# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-009.yaml (versión 2.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-030.ciclo-ot.spec.ts

@man @MAN-UC-009
Característica: Programar una orden de trabajo desde el plan de mantenimiento

  Quién lo hace: Planificador
  Dónde: Mantenimiento → Plan de Mantenimiento

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO) con perfil Planificador
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"
    Y Hay trabajo pendiente de programar. Puede venir de cuatro lados: una solicitud aceptada (MAN-UC-008), un preventivo vencido (MAN-UC-014), un pendiente del backlog (MAN-UC-015) o un predictivo disparado (MAN-UC-018)

  Escenario: Camino principal
    Cuando Entra a Mantenimiento → Plan de Mantenimiento
    Entonces Se muestra el calendario con las órdenes del rango visible y, arriba, la caja plegable de filtros y las referencias de color (incluye "Correctivo programado")
    Y cuando Elige qué va a programar y para cuándo
    Entonces El formulario pide la fecha de programación según el tipo de trabajo; un preventivo o un predictivo se puede programar en serie
    Y cuando Confirma con 'Generar Orden'
    Entonces Se crean las órdenes de trabajo, con las herramientas y los insumos copiados del origen, y el origen pasa a planificado

  Escenario: La orden cae lejos en el futuro
    Cuando Programa un preventivo o un predictivo cuya fecha queda fuera del margen de lanzamiento (7 días si la empresa no configuró otro)
    Entonces La orden queda programada sin lanzar (estado `PL` sin caso de Bonita) y se lanza sola cuando entra en el margen (MAN-UC-040)

  Escenario: Falla Bonita o la base a mitad de camino
    Cuando El motor no puede terminar de crear o lanzar alguna orden
    Entonces Se muestra el error, la ventana queda abierta y no queda nada a medias: se borran los casos lanzados, las copias y las órdenes, y el plan queda como estaba

  # Reglas que este caso verifica:
  #   - **No se debería poder programar una actividad ya vencida**
  #   - La orden hereda las herramientas y los insumos declarados en el trabajo de origen
  #   - Las series mensuales, semestrales y anuales se calculan por calendario: el mismo día de cada mes, o el último si el mes no lo tiene (E45)
  #   - Un pedido de programación tiene un tope de 400 órdenes y 36 meses (E43)
  #   - Un plan cuyo equipo es de otra empresa no se programa: "no se creó ninguna orden: el equipo no es de la empresa" (E48)
  #   - Si la solicitud es urgente, la tarea de Bonita la toma el motor al programar, no la ventana al abrirse (E41)
  #   - El aviso "Se ha guardado" sale solo cuando se guardó; los errores del servidor se muestran (E40)
