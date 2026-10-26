# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-013.yaml (versión 1.0, validado 2026-08-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-013
Característica: Consultar el stock valorizado

  Quién lo hace: Responsable de Almacén
  Dónde: Almacenes → Stock Valorizado

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y Hay existencias recibidas **con su precio cargado** (ALM-UC-009): sin precio no hay nada que valorizar
    Y La empresa tiene activada la valorización con un registro en `core.tablas` cuyo `tabla` contiene `alm_configs`

  Escenario: Camino principal
    Cuando Entra a Almacenes → Stock Valorizado
    Entonces Se muestran los filtros Fecha Desde, Fecha Hasta, Establecimiento, Tipo Depósito y Depósito
    Y cuando Elige el período y el alcance
    Entonces Los filtros quedan cargados
    Y cuando Hace clic en 'Filtrar'
    Entonces Se lista el stock con su valorización

  # Reglas que este caso verifica:
  #   - El valor de cada existencia es el precio que se cargó al recibir la mercadería, no una lista de precios
  #   - El informe solo incluye stock de la empresa de la sesión
