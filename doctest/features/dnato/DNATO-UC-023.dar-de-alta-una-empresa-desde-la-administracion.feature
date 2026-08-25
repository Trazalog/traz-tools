# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-023.yaml (versión 0.2, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@dnato @DNATO-UC-023
Característica: Dar de alta una empresa desde la administración

  Quién lo hace: Superusuario
  Dónde: Gestión de Empresas → Agregar Empresa · Nueva Empresa

  Antecedentes:
    Dado Sesión iniciada con el usuario superusuario del ambiente

  Escenario: Camino principal
    Cuando Abre 'Agregar Empresa'
    Entonces Se muestra el formulario Nueva Empresa con nombre, identificador tributario, descripción, teléfono, correo, país, provincia, localidad y logo
    Y cuando Completa los datos y confirma
    Entonces La empresa queda creada con sus 16 roles de trabajo y aparece en la lista de empresas

  Escenario: Campos obligatorios incompletos
    Cuando Confirma sin nombre, identificador tributario o descripción
    Entonces Se vuelve a mostrar el formulario con el error de validación

  Escenario: Administrador común
    Cuando Un administrador que no es el superusuario abre la dirección del alta
    Entonces Se lo redirige sin poder crear la empresa

  # Reglas que este caso verifica:
  #   - Nombre, identificador tributario y descripción son obligatorios
  #   - El alta crea los mismos 16 roles de trabajo que el alta por registración (DNATO-UC-004)
  #   - El alta desde la administración valida lo mismo que la registración: no puede repetirse la empresa para el mismo país e identificador tributario
  #   - El alta desde la administración deja la empresa igual de configurada que la registración: con su establecimiento, su depósito y sus usuarios iniciales

  # Datos de prueba:
  #   nombre_prefijo: DOCTEST EMPRESA 

  # ⚠️ Atención al ejecutarlo:
  #   Validado por el PM el 2026-08-24: los dos caminos de alta tienen que terminar en el mismo resultado y usar la misma API. **Hoy no pasa** — este alta no valida duplicados y no crea establecimiento, depósito ni usuarios iniciales. Registrado como hallazgo H-014, y el caso describe el comportamiento esperado.
