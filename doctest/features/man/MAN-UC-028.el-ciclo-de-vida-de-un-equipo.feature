# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-028.yaml (versión 0.1, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-028
Característica: El ciclo de vida de un equipo

  Quién lo hace: Supervisor
  Dónde: Mantenimiento → Equipos

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner

  Escenario: Camino principal
    Cuando Se da de alta el equipo (MAN-UC-002)
    Entonces Nace activo y ya puede recibir solicitudes, planes y órdenes de trabajo
    Y cuando Mientras está activo, acumula historia: lecturas, órdenes, informes, componentes
    Entonces Todo eso queda asociado al equipo
    Y cuando Si sale de servicio, se inhabilita (MAN-UC-022)
    Entonces Pasa a inactivo, y la columna Estado del listado lo muestra
    Y cuando Si vuelve a servicio, se habilita de nuevo
    Entonces Vuelve a estar activo, conservando toda su historia

  # Reglas que este caso verifica:
  #   - El equipo tiene **tres** estados: `AC` activo, `IN` inhabilitado y `AN` dado de baja
  #   - Ninguna de las dos acciones borra el registro: el historial del equipo se conserva siempre
  #   - En la base el equipo tiene dos estados: `AC` (activo) y `AN`
  #   - La única transición que el usuario controla a mano es habilitar / inhabilitar
