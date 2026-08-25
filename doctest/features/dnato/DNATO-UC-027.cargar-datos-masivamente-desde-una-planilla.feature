# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-027.yaml (versión 0.2, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

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

  # Reglas que este caso verifica:
  #   - La entidad de negocio es obligatoria
  #   - Solo se aceptan planillas .xlsx o .xls
  #   - **La carga es todo o nada**: si alguna fila tiene un error, no se carga ninguna
  #   - Los datos se cargan en la empresa de la sesión: no hace falta que la planilla la identifique ni se valida contra ella
  #   - Una carga que terminó bien no se puede deshacer
