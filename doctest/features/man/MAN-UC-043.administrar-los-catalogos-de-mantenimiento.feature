# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-043.yaml (versión 1.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-043.catalogos.spec.ts

@man @MAN-UC-043
Característica: Administrar los catálogos de mantenimiento

  Quién lo hace: Supervisor
  Dónde: ABM de Mantenimiento → Área · ABM de Mantenimiento → Procesos · ABM de Mantenimiento → Grupo · ABM de Mantenimiento → Sector · ABM de Mantenimiento → Contratista · ABM de Mantenimiento → Tareas estándar · ABM de Mantenimiento → Parámetros · ABM de Mantenimiento → Familia · ABM de Mantenimiento → Marca · ABM de Mantenimiento → Clientes · ABM de Mantenimiento → Criticidad · ABM de Mantenimiento → Sucursales · ABM de Mantenimiento → Sistemas

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO) con perfil Supervisor
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"

  Escenario: Camino principal
    Cuando Entra a un catálogo del menú ABM de Mantenimiento
    Entonces Se lista lo cargado en la empresa
    Y cuando Agrega un valor nuevo
    Entonces Aparece en el listado y en los desplegables que lo usan
    Y cuando Edita un valor
    Entonces Queda actualizado
    Y cuando Elimina un valor
    Entonces Deja de figurar en el listado

  # Reglas que este caso verifica:
  #   - Cada catálogo muestra y modifica solo los valores de la empresa de la sesión
  #   - Unidad de medida no está: se administra en Almacenes de tools (E57)
