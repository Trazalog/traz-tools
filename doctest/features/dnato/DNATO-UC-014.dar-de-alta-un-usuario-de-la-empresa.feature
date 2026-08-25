# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-014.yaml (versión 0.3, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@dnato @DNATO-UC-014
Característica: Dar de alta un usuario de la empresa

  Quién lo hace: Administrador
  Dónde: Gestión de Usuarios → Agregar Usuario

  Antecedentes:
    Dado Sesión iniciada con perfil Administrador
    Y El correo del nuevo usuario no existe en el sistema

  Escenario: Camino principal
    Cuando Abre 'Agregar Usuario'
    Entonces Se muestra el formulario Nuevo Usuario con los campos Nombre, Apellido, Email, Foto de perfil, Teléfono, D.N.I, Empresa, Rol, Contraseña y Confirme Contraseña
    Y cuando Completa los campos obligatorios y confirma
    Entonces El usuario queda creado y se avisa que, para que pueda acceder, hay que asignarle roles desde la acción 'Asignar Rol' de la lista

  Escenario: Correo ya existente
    Cuando Completa el formulario con un correo ya registrado
    Entonces Se muestra 'Ya existe un usuario asociado a ese Email' y no se crea nada

  Escenario: Contraseña que no cumple la política
    Cuando Ingresa 'doctest2026' (sin mayúscula ni símbolo)
    Entonces Se muestra el error de contraseña y el usuario no se crea

  Escenario: Campos obligatorios incompletos
    Cuando Confirma sin completar Nombre, Apellido, Email, Empresa o Rol
    Entonces Se vuelve a mostrar el formulario con el error

  Escenario: Falla el alta en el backend
    Cuando Confirma cuando el servicio de alta responde con error
    Entonces Se muestra el motivo del error y el usuario no se crea

  # Reglas que este caso verifica:
  #   - Nombre, Apellido, Email, Empresa, Rol, Contraseña y su confirmación son obligatorios; Teléfono, D.N.I y Foto son opcionales
  #   - El correo debe ser válido y no puede estar repetido
  #   - La contraseña exige 10 caracteres, mayúscula, minúscula, dígito y símbolo
  #   - Un usuario recién creado no puede operar hasta que se le asignen roles de empresa (DNATO-UC-018)
  #   - El desplegable de empresas muestra solo aquellas en las que el usuario conectado es administrador

  # Datos de prueba:
  #   empresa: EMPRESA_TEST_1
  #   email_prefijo: doctest+user-
  #   password_valida: Doctest2026!

  # ⚠️ Atención al ejecutarlo:
  #   Validado por el PM el 2026-08-24 con esa regla. **Hoy el sistema no la cumple**: el desplegable trae todas las empresas del sistema. Registrado como hallazgo H-019.
  #   La etiqueta 'Rol' de este formulario es en realidad el perfil de Dnato: renombrarla queda anotado como mejora (hallazgo H-025), no se toca ahora.
