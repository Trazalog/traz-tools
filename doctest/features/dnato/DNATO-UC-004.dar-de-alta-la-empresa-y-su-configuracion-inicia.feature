# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-004.yaml (versión 0.4, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@dnato @DNATO-UC-004
Característica: Dar de alta la empresa y su configuración inicial

  Quién lo hace: Administrador
  Dónde: Completar Datos de Empresa

  Antecedentes:
    Dado La cuenta está activa y con sesión iniciada
    Y El usuario tiene razón social, teléfono y país cargados desde su registro

  Escenario: Camino principal
    Cuando Ve la pantalla de datos de la empresa con la razón social y el país que cargó al registrarse
    Entonces Se muestran los campos a completar: identificador tributario, provincia y localidad
    Y cuando Selecciona provincia y localidad, ingresa el identificador tributario y confirma
    Entonces Se crea la empresa con sus 16 roles de trabajo, el Establecimiento Principal con su Depósito 1, los cinco usuarios iniciales con sus roles, y se muestra la pantalla de bienvenida

  Escenario: Correo de webmail público: hace falta el dominio de la empresa
    Cuando Se registró con un correo tipo gmail.com y completa el formulario sin un dominio de empresa válido
    Entonces Se muestra 'Ingresá un dominio de empresa valido (por ejemplo: rtools.ca). No se permiten dominios de webmail publicos.' y la empresa no se crea

  Escenario: La empresa ya existe
    Cuando Confirma con una razón social y un identificador tributario ya registrados para ese país
    Entonces Se muestra 'La empresa ya existe para el pais y CUIT indicados.' y no se crea nada

  Escenario: Campos obligatorios incompletos
    Cuando Confirma sin identificador tributario, provincia o localidad
    Entonces Se vuelve a mostrar el formulario con el error de validación

  Escenario: Falla la configuración inicial y se revierte el alta
    Cuando Confirma el alta cuando falla la creación de los usuarios, roles o del depósito por defecto
    Entonces Se avisa el detalle del problema, se elimina la empresa recién creada y el alta queda anulada

  # Reglas que este caso verifica:
  #   - Identificador tributario, provincia y localidad son obligatorios
  #   - La empresa no puede repetirse para el mismo país e identificador tributario
  #   - Si el correo del usuario es de un webmail público, el dominio de empresa es obligatorio y no puede ser otro webmail
  #   - El alta crea los 16 roles de la empresa: Responsable / Solicitante de Almacén, Responsable de Producción, Responsable de Lote, Responsable de Pañol, Planificador de Tareas, Responsable de Procesos, Supervisor / Planificador / Solicitante de Mantenimiento, Mantenedor, Administrador y los cuatro roles SMA (Transportista, Generador, Operario Descarga, Operador de Bascula)
  #   - El alta crea el Establecimiento Principal, el Depósito 1 y le asigna como encargado al usuario almacen@<dominio>
  #   - Al usuario que dio de alta la empresa se le asigna el rol Administrador de esa empresa
  #   - La empresa nueva queda con sus menúes iniciales asignados por rol, con el superusuario habilitado como administrador, y con las listas de valores por defecto (sectores, tipos de artículo, tipos de transportista y unidades de medida)
  #   - El identificador tributario NO se valida por formato — decisión del PM: se acepta lo que el usuario cargue y después se corrige

  # Datos de prueba:
  #   cuit_prefijo: 30-DOCTEST
  #   dominio_empresa_test: doctest-empresa.com

  # ⚠️ Atención al ejecutarlo:
  #   Validado por el PM el 2026-08-24, con tres definiciones: el identificador tributario no se valida (máscaras por país, mejora futura), tiene que poder corregirse después desde Dnato (hoy no hay pantalla para eso — hallazgo H-023), y el mensaje de error debe mostrar el contacto de soporte, soporte@trazalog.com (hallazgo H-024).
