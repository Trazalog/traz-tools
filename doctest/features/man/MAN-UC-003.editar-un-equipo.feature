# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-003.yaml (versión 2.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-003-004-022-026-028.equipos.spec.ts

@man @MAN-UC-003
Característica: Editar un equipo

  Quién lo hace: Supervisor
  Dónde: Mantenimiento → Equipos → (editar una fila)

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO)
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"
    Y Existe al menos un equipo en la empresa

  Escenario: Camino principal
    Cuando En el listado abre un equipo para editarlo
    Entonces Se muestra el formulario con los datos cargados
    Y cuando Modifica lo que corresponda y guarda
    Entonces El equipo queda actualizado

  # Reglas que este caso verifica:
  #   - Solo se puede editar un equipo de la empresa de la sesión: ante uno de otra empresa no se modifica nada (E4)
