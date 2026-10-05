# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-006.yaml (versión 0.3, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/dnato/DNATO-UC-006.iniciar-sesion.spec.ts

@dnato @DNATO-UC-006
Característica: Iniciar sesión eligiendo la empresa

  Quién lo hace: Usuario
  Dónde: Bienvenido! Ingrese por favor

  Antecedentes:
    Dado Sin sesión iniciada
    Y La cuenta está activada y habilitada
    Y El usuario tiene rol asignado en la empresa que elige

  Escenario: Camino principal
    Cuando Abre la pantalla de ingreso
    Entonces Se muestra el formulario con la lista de empresas, correo y contraseña
    Y cuando Elige su empresa, ingresa correo y contraseña, y confirma
    Entonces Inicia sesión y entra a Trazalog Tools con esa empresa como empresa activa

  Escenario: El usuario no pertenece a la empresa elegida
    Cuando Elige una empresa en la que no tiene roles e ingresa sus credenciales
    Entonces Se muestra 'El usuario no corresponde a la empresa seleccionada.' y no inicia sesión

  Escenario: Correo o contraseña incorrectos
    Cuando Ingresa una contraseña equivocada
    Entonces Se muestra 'Correo o contraseña incorrectos.' y no inicia sesión

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
  #   - Un usuario puede pertenecer a varias empresas y elige con cuál entra
  #   - La pertenencia a la empresa elegida se verifica antes de validar la contraseña
  #   - Una cuenta inhabilitada no puede iniciar sesión aunque la contraseña sea correcta

  # Datos de prueba:
  #   empresa: EMPRESA_TEST_1
