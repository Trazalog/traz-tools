# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-028.yaml (versión 2.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-003-004-022-026-028.equipos.spec.ts

@man @MAN-UC-028
Característica: El ciclo de vida de un equipo

  Quién lo hace: Supervisor
  Dónde: Mantenimiento → Equipos

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO)
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"

  Escenario: Camino principal
    Cuando Se da de alta el equipo (MAN-UC-002)
    Entonces Nace en estado de alta (`AL`); con la acción Habilitar pasa a activo (`AC`), con su lectura de alta, y ya puede recibir solicitudes, planes y órdenes de trabajo
    Y cuando Mientras está activo, acumula historia: lecturas, órdenes, informes, componentes
    Entonces Todo eso queda asociado al equipo
    Y cuando Si sale de servicio, se inhabilita (MAN-UC-022)
    Entonces Pasa a inactivo, y la columna Estado del listado lo muestra
    Y cuando Si vuelve a servicio, se habilita de nuevo
    Entonces Vuelve a estar activo, conservando toda su historia

  # Reglas que este caso verifica:
  #   - El equipo tiene **cuatro** estados: `AL` en alta, `AC` activo, `IN` inhabilitado y `AN` dado de baja
  #   - Ninguna acción borra el registro: el historial del equipo se conserva siempre
  #   - La única transición que el usuario controla a mano es habilitar / inhabilitar / eliminar
