# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-014.yaml (versión 1.0, validado 2026-08-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-014
Característica: Registrar un ajuste de stock

  Quién lo hace: Responsable de Almacén
  Dónde: Almacenes → Ajustes de Stock · Almacenes → Ajustes de Stock → Nuevo Ajuste

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y La empresa tiene tipos de ajuste definidos

  Escenario: Camino principal
    Cuando Entra a Almacenes → Ajustes de Stock
    Entonces Se muestra el listado de ajustes con Comprobante, Fecha / Hora, Establecimiento y Depósito
    Y cuando Hace clic en 'Nuevo Ajuste'
    Entonces Se abre el formulario de ajuste
    Y cuando Elige el establecimiento y el depósito
    Entonces Se ofrecen los lotes disponibles en ese depósito
    Y cuando Agrega cada línea indicando el lote, si es una entrada o una salida, la cantidad y el tipo de ajuste
    Entonces El detalle acumula las líneas. Cada línea lleva su propio tipo de ajuste
    Y cuando Escribe la justificación y confirma
    Entonces El ajuste queda registrado y el stock del lote cambia según lo indicado

  # Reglas que este caso verifica:
  #   - Solo el Responsable de Almacén puede registrar un ajuste
  #   - El ajuste se aplica sobre un lote concreto, no sobre el artículo en general
  #   - Una salida se registra como cantidad negativa
  #   - El tipo de ajuste va en cada línea del detalle, no en la cabecera
  #   - El ajuste es el único camino para corregir una recepción o una entrega ya registradas
  #   - El ajuste queda registrado con su justificación
