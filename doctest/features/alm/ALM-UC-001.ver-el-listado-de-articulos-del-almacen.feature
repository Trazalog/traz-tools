# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-001.yaml (versión 1.0, validado 2026-08-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-001
Característica: Ver el listado de artículos del almacén

  Quién lo hace: Responsable de Almacén
  Dónde: Almacenes → Articulos

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y El rol tiene asignado el menú de Almacenes

  Escenario: Camino principal
    Cuando Entra a Almacenes → Articulos
    Entonces Se muestra la grilla de artículos con las columnas Acciones, Código, Descripción, Tipo de Producto, Unidad de Medida y Estado
    Y cuando Usa el buscador de la grilla para encontrar un artículo
    Entonces La grilla se reduce a los artículos que coinciden

  Escenario: La empresa todavía no cargó artículos
    Cuando Entra a Almacenes → Articulos
    Entonces La grilla aparece vacía y solo se ofrece el botón Agregar

  # Reglas que este caso verifica:
  #   - El listado solo muestra artículos de la empresa de la sesión
  #   - El acceso se controla por el menú: quien tiene la opción de Almacenes, entra

  # Datos de prueba:
  #   empresa: EMPRESA_TEST_1
  #   precondicion: la empresa tiene al menos un artículo cargado

  # ⚠️ Atención al ejecutarlo:
  #   Relevado contra `origin/develop` del submódulo, que es lo desplegado en el DEMO — el puntero de develop-v3 está 25 commits atrás (H-038 / issue #481).
