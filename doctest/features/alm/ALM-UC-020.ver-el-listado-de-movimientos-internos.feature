# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/alm/ALM-UC-020.yaml (versión 1.0, validado 2026-09-07).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@alm @ALM-UC-020
Característica: Ver el listado de movimientos internos

  Quién lo hace: Responsable de Almacén
  Dónde: Almacenes → Movimientos Internos

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y El rol tiene asignado el menú de Almacenes

  Escenario: Camino principal
    Cuando Entra a Almacenes → Movimientos Internos
    Entonces Se muestra la grilla con las columnas Fecha y Hora, Establecimiento Origen, Depósito Origen, Establecimiento Destino, Depósito Destino, Remito, Estado y Acciones
    Y cuando Usa el buscador de la grilla
    Entonces La grilla se reduce a los movimientos que coinciden. La búsqueda la resuelve el servidor, no el navegador
    Y cuando Ordena por una columna
    Entonces La grilla se reordena; el orden también lo resuelve el servidor

  Escenario: La empresa todavía no registró movimientos
    Cuando Entra a la pantalla
    Entonces La grilla aparece vacía

  # Reglas que este caso verifica:
  #   - El listado solo muestra movimientos de la empresa de la sesión
  #   - **Cada usuario ve solo los movimientos de los depósitos que tiene a cargo.** La consulta exige que exista una fila en `core.encargados_depositos` para ese usuario y el depósito de **origen o** el de **destino** del movimiento: alcanza con estar a cargo de una de las dos puntas
  #   - Es una pantalla de solo listado: los accesos a Nueva Salida y a Recepción siguen estando donde estaban, no se agregaron acá
  #   - El estado se muestra como un indicador de color: **En Curso** en verde y **Recibido** en azul. Cualquier otro valor se muestra tal como viene, sin color

  # Datos de prueba:
  #   empresa: EMPRESA_TEST_1
  #   precondicion: la empresa tiene al menos un movimiento interno registrado
