# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-023.yaml (versión 1.0, validado 2026-09-07).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-023
Característica: Ver el listado de ajustes de stock

  Quién lo hace: Responsable de Almacén
  Dónde: Almacenes → Ajustes de Stock

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y El rol tiene asignado el menú de Almacenes
    Y Hay ajustes registrados (ALM-UC-014). Sin ninguno la grilla aparece vacía

  Escenario: Camino principal
    Cuando Entra a Almacenes → Ajustes de Stock
    Entonces Se muestra la grilla con las columnas Acciones, Comprobante, Fecha / Hora, Establecimiento y Depósito
    Y cuando Usa el buscador de la grilla
    Entonces La grilla se reduce a los ajustes que coinciden

  Escenario: La empresa todavía no registró ajustes
    Cuando Entra a la pantalla
    Entonces La grilla aparece vacía y solo se ofrece el acceso a Nuevo Ajuste

  # Reglas que este caso verifica:
  #   - El listado solo muestra ajustes de la empresa de la sesión
  #   - **Cada fila es un ajuste completo, no una línea.** Un ajuste sobre tres artículos aparece una sola vez: la consulta agrupa por ajuste y el establecimiento y el depósito que muestra son los de la primera línea. El detalle de los artículos está en ALM-UC-024
  #   - **Comprobante es el número del ajuste que genera el sistema** (`ajus_id`), no un dato que se carga a mano
  #   - El listado **no tiene filtros propios**: solo el buscador de la grilla, que además del número busca por establecimiento, depósito y número de lote
  #   - La grilla se pagina, busca y ordena contra el servidor
