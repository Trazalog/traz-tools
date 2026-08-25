# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-008.yaml (versión 0.4, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/dnato/DNATO-UC-008.recuperar-contrasena.spec.ts

@dnato @DNATO-UC-008
Característica: Recuperar la contraseña olvidada

  Quién lo hace: Usuario
  Dónde: Login → 'Olvido su contraseña? Recupere contraseña' · Recuperar Contraseña · Restablecer Contraseña

  Antecedentes:
    Dado Sin sesión iniciada
    Y La cuenta existe y está aprobada

  Escenario: Camino principal
    Cuando Desde la pantalla de ingreso hace clic en 'Recupere contraseña'
    Entonces Se muestra el formulario para ingresar el correo
    Y cuando Ingresa su correo y confirma
    Entonces Se envía un correo con el enlace para restablecer la contraseña y se muestra la confirmación
    Y cuando Abre el enlace del correo, ingresa la contraseña nueva y su confirmación, y confirma
    Entonces Se muestra que la contraseña se actualizó correctamente y ya puede iniciar sesión con ella

  Escenario: Correo no registrado
    Cuando Ingresa un correo que no existe en el sistema
    Entonces Se muestra 'No encontramos esa dirección de correo en el sistema.' y no se envía ningún correo

  Escenario: Cuenta todavía no aprobada
    Cuando Ingresa el correo de una cuenta que no está aprobada
    Entonces Se muestra 'Tu cuenta aún no está aprobada.' y no se envía el enlace

  Escenario: Enlace vencido o ya usado
    Cuando Abre un enlace de restablecimiento inválido o expirado
    Entonces Se muestra 'El token es inválido o expiró.' y vuelve a la pantalla de ingreso

  Escenario: Contraseña que no cumple la política
    Cuando Ingresa 'doctest2026' (10 caracteres, sin mayúscula ni símbolo)
    Entonces Se muestra el error de validación y la contraseña no se cambia

  # Reglas que este caso verifica:
  #   - El correo es obligatorio y con formato válido
  #   - Solo se envía el enlace si la cuenta existe y está aprobada
  #   - El enlace de restablecimiento vence a la medianoche del día en que se generó (misma regla que la activación)
  #   - La contraseña nueva exige 10 caracteres o más, mayúscula, minúscula, dígito y símbolo, y coincidir con su confirmación
  #   - Solo puede recuperar la contraseña quien tenga el correo validado: el administrador que dio de alta la empresa. Los cinco usuarios iniciales y los que crea el administrador NO tienen correo validado y no deben poder usarla

  # Datos de prueba:
  #   empresa: EMPRESA_TEST_1

  # ⚠️ Atención al ejecutarlo:
  #   Validado por el PM el 2026-08-24 con una regla nueva: la recuperación es solo para usuarios con correo validado. **Hoy el sistema no la cumple** — los usuarios creados automáticamente y los creados por el administrador nacen en estado `approved`, que es lo único que mira la pantalla, así que pueden recuperar contraseña. Registrado como hallazgo H-016.
