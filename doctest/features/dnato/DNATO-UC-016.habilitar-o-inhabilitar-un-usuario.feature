# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-016.yaml (versión 0.3, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@dnato @DNATO-UC-016
Característica: Habilitar o inhabilitar un usuario

  Quién lo hace: Administrador
  Dónde: Usuarios → Habilitar/Deshabilitar Usuario

  Antecedentes:
    Dado Sesión iniciada con perfil de administrador

  Escenario: Camino principal
    Cuando Abre 'Habilitar/Deshabilitar Usuario'
    Entonces Se muestra el listado de usuarios con su estado actual
    Y cuando Elige un usuario habilitado, lo marca como inhabilitado y confirma
    Entonces Se muestra 'El usuario ha sido inhabilitado exitosamente.' y el usuario ya no puede iniciar sesión
    Y cuando Vuelve a marcarlo como habilitado y confirma
    Entonces Se muestra 'El usuario fue habilitado con éxito.' y el usuario puede volver a iniciar sesión

  Escenario: No se puede actualizar
    Cuando Confirma el cambio cuando la actualización falla
    Entonces Se muestra el mensaje de error y el estado no cambia

  Escenario: Usuario sin permisos de administración
    Cuando Un usuario sin perfil de administrador abre la pantalla
    Entonces Se lo redirige a la pantalla principal

  # Reglas que este caso verifica:
  #   - Correo y estado son obligatorios
  #   - Un usuario inhabilitado no puede iniciar sesión (ver DNATO-UC-006)
  #   - Un administrador no puede inhabilitarse a sí mismo

  # ⚠️ Atención al ejecutarlo:
  #   Validado por el PM el 2026-08-24. La pantalla anterior (`banuser_old`) queda declarada obsoleta (hallazgo H-006). Que un administrador pueda inhabilitarse a sí mismo es un hallazgo nuevo (H-018); el texto equivocado del mensaje de error sigue anotado (H-009).
