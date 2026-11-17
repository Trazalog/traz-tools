# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-005.yaml (versión 1.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-005-006.componentes.spec.ts

@man @MAN-UC-005
Característica: Dar de alta un componente

  Quién lo hace: Supervisor
  Dónde: Mantenimiento → Componentes → Nuevo

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO)
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"

  Escenario: Camino principal
    Cuando Abre el alta de componentes
    Entonces Se muestra el formulario
    Y cuando Carga los datos del componente y su marca
    Entonces El formulario acepta los datos
    Y cuando Guarda
    Entonces El componente queda dado de alta y disponible para asignarlo a un equipo

  # Reglas que este caso verifica:
  #   - El **código trazable lo escribe el usuario**: no se genera solo
  #   - Un componente es una **pieza intercambiable del equipo**
  #   - El código del componente lo arma el sistema a partir del último id y de la empresa
