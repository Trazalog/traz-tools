# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-026.yaml (versión 1.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-003-004-022-026-028.equipos.spec.ts

@man @MAN-UC-026
Característica: Asignar una meta a un equipo

  Quién lo hace: Supervisor
  Dónde: Mantenimiento → Equipos → Asignar Meta

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO)
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"

  Escenario: Camino principal
    Cuando En el listado de equipos elige la acción Asignar Meta
    Entonces Se abre el formulario con la meta actual, si tiene
    Y cuando Carga un valor entre 1 y 100
    Entonces La meta queda asignada al equipo

  Escenario: Quitar la meta
    Cuando Usa la opción 'Borrar Meta'
    Entonces El equipo queda sin meta

  # Reglas que este caso verifica:
  #   - Es la **meta de disponibilidad** del equipo, en porcentaje
  #   - La meta es **opcional**: un equipo puede no tener ninguna
  #   - El valor va de 1 a 100
