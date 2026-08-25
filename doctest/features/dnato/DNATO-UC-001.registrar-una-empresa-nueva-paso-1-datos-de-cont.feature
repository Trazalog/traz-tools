# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-001.yaml (versión 0.4, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@dnato @DNATO-UC-001
Característica: Registrar una empresa nueva (paso 1 - datos de contacto)

  Quién lo hace: Visitante
  Dónde: Login → 'No esta registrado? Registrese por favor' · Registro Nuevo Usuario

  Antecedentes:
    Dado Sin sesión iniciada
    Y El correo no está registrado en el sistema
    Y La razón social no existe todavía para ese país

  Escenario: Camino principal
    Cuando Desde la pantalla de ingreso hace clic en 'Registrese por favor'
    Entonces Se abre el formulario de registro con la lista de países disponibles
    Y cuando Completa Nombre, Apellido, Correo electrónico, Razón Social de la Empresa, Teléfono y País, y confirma
    Entonces Se crea la cuenta sin contraseña y con perfil Administrador, se muestra 'Registro exitoso! Revise su email para activar su cuenta.' y llega el correo 'Activar cuenta en Trazalog.com' con el enlace de activación

  Escenario: Correo ya registrado
    Cuando Completa el formulario con un correo que ya existe en el sistema
    Entonces Se muestra 'El email que intenta registrar ya existe...' y la cuenta no se crea

  Escenario: Razón social repetida en el mismo país
    Cuando Completa el formulario con una razón social ya existente para el país elegido
    Entonces Se muestra 'La Razón Social ingresada ya existe en el sistema para el país solicitado' y la cuenta no se crea

  Escenario: Teléfono con formato inválido para el país
    Cuando Ingresa un teléfono que no cumple el formato del país seleccionado
    Entonces Se muestra 'El formato del teléfono no es válido para el país seleccionado.' y la cuenta no se crea

  Escenario: Campos obligatorios incompletos
    Cuando Confirma el formulario sin completar alguno de los seis campos
    Entonces El formulario se vuelve a mostrar con el error del campo y conserva lo ya cargado

  # Reglas que este caso verifica:
  #   - Nombre, Apellido, Correo, Razón Social, Teléfono y País son obligatorios
  #   - El correo debe tener formato válido y no puede estar registrado
  #   - La razón social no puede repetirse dentro del mismo país
  #   - El teléfono se valida según el país elegido
  #   - Quien se auto-registra queda con perfil Administrador de su empresa

  # Datos de prueba:
  #   email_prefijo: doctest+reg-
  #   razon_social_prefijo: DOCTEST SA 
  #   nota_recaptcha: reCAPTCHA está desactivado en el entorno de pruebas (decisión del PM, 2026-08-19): el flujo es automatizable de punta a punta

  # ⚠️ Atención al ejecutarlo:
  #   Validado por el PM el 2026-08-24. La cuenta queda creada solo en Dnato, sin confirmar el correo, hasta que se activa: depurar las cuentas sin confirmar es una mejora futura (hallazgo H-021).
