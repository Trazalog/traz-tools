# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-027.yaml (versión 0.3, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/dnato/DNATO-UC-026-027.carga-masiva.spec.ts

@dnato @DNATO-UC-027
Característica: Cargar datos masivamente desde una planilla

  Quién lo hace: Administrador
  Dónde: Carga Masiva · Resultado de Carga Masiva

  Antecedentes:
    Dado Sesión iniciada con perfil Administrador
    Y Se completó la plantilla de la entidad a cargar (DNATO-UC-026)

  Escenario: Camino principal
    Cuando Elige la entidad que va a cargar y adjunta la planilla completada
    Entonces El archivo se acepta y comienza el procesamiento
    Y cuando Confirma la carga
    Entonces Se muestra el resultado de la carga con lo que se procesó

  Escenario: La planilla tiene filas con errores
    Cuando Carga una planilla en la que alguna fila no cumple lo esperado
    Entonces No se carga ninguna fila y el resultado indica qué estuvo mal

  Escenario: Sin elegir la entidad
    Cuando Adjunta el archivo sin elegir qué se está cargando
    Entonces Se muestra el error de campo obligatorio y no se procesa nada

  Escenario: Archivo que no es una planilla
    Cuando Adjunta un archivo que no es .xlsx ni .xls
    Entonces Se muestra 'Formato de archivo no válido. Solo se permiten archivos Excel (.xlsx, .xls)' y no se procesa nada

  Escenario: Sin archivo
    Cuando Confirma sin adjuntar ningún archivo
    Entonces Se muestra 'Error al cargar el archivo. Verifique que el archivo sea válido.'

  Escenario: Quedó una carga anterior sin terminar (entidades de Mantenimiento)
    Cuando Carga una entidad de Mantenimiento cuando la tabla de staging todavía tiene filas sin procesar de una corrida anterior
    Entonces No se carga nada y se avisa cuántas filas quedaron sin procesar, con la indicación de revisarlas y limpiarlas antes de reintentar. No se borran solas: podrían ser de otro usuario cargando al mismo tiempo

  Escenario: La empresa no está vinculada con Mantenimiento
    Cuando Carga una entidad de Mantenimiento desde una empresa que no tiene definido su vínculo con AssetPlanner
    Entonces No se carga nada y se avisa que la empresa no tiene el vínculo definido

  # Reglas que este caso verifica:
  #   - La entidad de negocio es obligatoria
  #   - Solo se aceptan planillas .xlsx o .xls
  #   - **La carga es todo o nada**: si alguna fila tiene un error, no se carga ninguna
  #   - Los datos se cargan en la empresa de la sesión: no hace falta que la planilla la identifique ni se valida contra ella
  #   - Una carga que terminó bien no se puede deshacer
  #   - Cada entidad se carga contra la base donde vive su procedimiento: las de Mantenimiento (Equipos y Articulos) contra la de AssetPlanner, el resto contra la de Tools. Para quien usa la pantalla es lo mismo: el flujo, el mensaje de resultado y el 'todo o nada' no cambian
  #   - Para las entidades de Mantenimiento, la empresa de la sesión se traduce a su equivalente en AssetPlanner. Si ese vínculo no está definido, la carga no se hace

  # ⚠️ Atención al ejecutarlo:
  #   **El despacho por motor lo agregó el PR #34 de `traz-comp-dnato` (2026-08-31)**, que es lo que hizo funcionar Mantenimiento Equipos (hallazgo H-030 / issue #470). El controlador, la vista y el flujo del usuario no cambiaron: lo que cambió es contra qué base ejecuta el modelo.
  #   El vínculo empresa Tools ↔ empresa AssetPlanner es el campo `empr_id_mysql` de `core.empresas`, el mismo que escribe el alta de empresa. **Una empresa creada mientras el issue #491 estaba roto no lo tiene**, así que su carga masiva de Mantenimiento va a fallar hasta que se le complete.
