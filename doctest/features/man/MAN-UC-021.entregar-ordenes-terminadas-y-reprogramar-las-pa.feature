# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-021.yaml (versión 2.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-021
Característica: Entregar órdenes terminadas y reprogramar las parciales

  Quién lo hace: Planificador
  Dónde: Mantenimiento → Administrar Ordenes

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO) con perfil Planificador
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"
    Y Hay órdenes terminadas o terminadas parcialmente

  Escenario: Camino principal
    Cuando Entra a Mantenimiento → Administrar Ordenes
    Entonces Se listan las órdenes con ID, Número, Fecha Inicio, Fecha Entrega, Fecha Terminada, Fecha Aviso, Detalle y Estado
    Y cuando Sobre una orden terminada elige entregarla
    Entonces La orden queda entregada, con su fecha de entrega

  Escenario: Reprogramar una orden terminada parcialmente
    Cuando Sobre una orden `TE` cambia la fecha
    Entonces La orden queda reprogramada para la fecha nueva

  # Reglas que este caso verifica:
  #   - Solo opera sobre órdenes de la empresa de la sesión
