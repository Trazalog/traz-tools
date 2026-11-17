# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-004.yaml (versión 2.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-003-004-022-026-028.equipos.spec.ts

@man @MAN-UC-004
Característica: Eliminar un equipo

  Quién lo hace: Supervisor
  Dónde: Mantenimiento → Equipos → Eliminar

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO)
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"
    Y Existe un equipo activo

  Escenario: Camino principal
    Cuando En la columna Acciones del listado elige Eliminar
    Entonces El sistema pide confirmación
    Y cuando Confirma
    Entonces El equipo deja de figurar en el listado

  # Reglas que este caso verifica:
  #   - El equipo eliminado queda en estado `AN`: no se borra el registro
  #   - Solo se elimina un equipo de la empresa de la sesión (E4)
