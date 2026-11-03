# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-020.yaml (versión 1.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-020
Característica: Consultar los reportes e indicadores de mantenimiento

  Quién lo hace: Supervisor
  Dónde: Mantenimiento → Rep Equipo · Mantenimiento → Rep Informe de Servicios · Mantenimiento → Rep Ordenes de trabajo

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO)
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"
    Y Hay órdenes e informes registrados en el período que se consulta

  Escenario: Camino principal
    Cuando Entra a Mantenimiento → Rep Equipo y elige el período
    Entonces Se listan los equipos con área, proceso, sector, criticidad, estado y su porcentaje de disponibilidad
    Y cuando Entra a Mantenimiento → Rep Informe de Servicios, elige los filtros y consulta
    Entonces Se listan las solicitudes, los preventivos y los backlogs con su informe: tarea, fechas, personas, horas hombre y estado
    Y cuando Entra a Mantenimiento → Rep Ordenes de trabajo, elige equipo, estado y período, y consulta
    Entonces Se listan las órdenes con su descripción, tarea estándar, equipo, fechas, origen, mantenedor y estado

  # Reglas que este caso verifica:
  #   - El indicador central es la **disponibilidad** de cada equipo, que se compara contra su meta (MAN-UC-026)
  #   - Los equipos inhabilitados quedan fuera del cálculo
  #   - Los reportes se acotan por período y muestran solo datos de la empresa de la sesión
  #   - Los reportes se pueden imprimir y bajar a Excel
