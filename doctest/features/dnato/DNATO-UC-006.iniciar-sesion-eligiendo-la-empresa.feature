# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-006.yaml (versión 0.4, validado 2026-09-04).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/dnato/DNATO-UC-006.iniciar-sesion.spec.ts

@dnato @DNATO-UC-006
Característica: Iniciar sesión eligiendo la empresa

  Quién lo hace: Usuario
  Dónde: Bienvenido · ¿Con qué empresa querés ingresar?

  Antecedentes:
    Dado Sin sesión iniciada
    Y La cuenta está activada y habilitada
    Y El usuario tiene al menos una empresa con membresía resoluble

  Escenario: Camino principal
    Cuando Abre la pantalla de ingreso
    Entonces Se muestra el formulario con dos campos: correo y contraseña. No se ofrece ninguna lista de empresas
    Y cuando Ingresa correo y contraseña, y confirma
    Entonces Se validan las credenciales y el sistema resuelve por su cuenta a qué empresas pertenece el usuario
    Y cuando Si pertenece a una sola empresa, no hace nada más
    Entonces Inicia sesión con esa empresa como empresa activa y entra a Trazalog Tools
    Y cuando Si pertenece a más de una, elige una de las empresas que se le muestran
    Entonces Inicia sesión con la empresa elegida como empresa activa y entra a Trazalog Tools

  Escenario: Correo o contraseña incorrectos
    Cuando Ingresa una contraseña equivocada
    Entonces Se muestra 'Correo o contraseña incorrectos.' y no inicia sesión

  Escenario: El usuario no tiene ninguna empresa
    Cuando Ingresa credenciales correctas de una cuenta sin membresías resolubles
    Entonces Se muestra que no tiene ninguna empresa asignada y que contacte al administrador, y no inicia sesión

  Escenario: Se intenta llegar a la elección de empresa sin haber ingresado
    Cuando Abre la pantalla de elección de empresa por dirección directa, sin credenciales validadas
    Entonces Se muestra 'Tu sesión expiró. Ingresá nuevamente.' y vuelve a la pantalla de ingreso

  Escenario: Se confirma una empresa que no es del usuario
    Cuando Se envía la elección con una empresa en la que el usuario no tiene membresía
    Entonces Se muestra que la empresa seleccionada no corresponde a su usuario, se descarta el ingreso a medias y vuelve a la pantalla de ingreso

  Escenario: Usuario inhabilitado
    Cuando Ingresa credenciales correctas de una cuenta inhabilitada
    Entonces Se muestra que está temporalmente inhabilitado para el sistema y no inicia sesión

  Escenario: Campos vacíos
    Cuando Confirma sin completar correo o contraseña
    Entonces Se vuelve a mostrar la pantalla de ingreso con el error de validación

  Escenario: El usuario no existe en el sistema de procesos
    Cuando Ingresa con una cuenta que no tiene usuario en Bonita
    Entonces Se muestra 'Error de inicio de sesión en BPM.' y no inicia sesión

  # Reglas que este caso verifica:
  #   - Correo y contraseña son obligatorios; el correo debe tener formato válido
  #   - Las credenciales se validan ANTES que cualquier otra cosa: nada del sistema se revela a quien no se autenticó
  #   - La pantalla de ingreso no expone ninguna empresa: sin sesión no se puede saber qué empresas existen
  #   - Las empresas de un usuario las resuelve el servidor a partir de sus membresías; nunca llegan desde el formulario
  #   - Un usuario puede pertenecer a varias empresas y elige con cuál entra, pero sólo entre las suyas
  #   - Con una sola empresa no se pide elegir: entra directo
  #   - La empresa confirmada se vuelve a verificar contra la base antes de abrir la sesión
  #   - La elección de empresa exige credenciales ya validadas y un token de seguridad propio del formulario
  #   - Una cuenta inhabilitada no puede iniciar sesión aunque la contraseña sea correcta

  # Datos de prueba:
  #   empresa: EMPRESA_TEST_1
