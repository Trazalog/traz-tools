# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-015.yaml (versión 0.3, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/dnato/DNATO-UC-015.editar-usuario.spec.ts

@dnato @DNATO-UC-015
Característica: Editar un usuario de la empresa

  Quién lo hace: Administrador
  Dónde: Usuarios → Lista de Usuarios → Editar

  Antecedentes:
    Dado Sesión iniciada con perfil de administrador
    Y El usuario a editar existe

  Escenario: Camino principal
    Cuando Elige 'Editar' sobre un usuario del listado
    Entonces Se muestra el formulario con los datos actuales del usuario
    Y cuando Modifica los datos y confirma
    Entonces Los cambios quedan guardados y se vuelve al listado

  Escenario: Campos obligatorios incompletos
    Cuando Borra nombre, apellido, correo o rol y confirma
    Entonces Se muestra el error de validación y no se guarda

  # Reglas que este caso verifica:
  #   - Nombre, apellido, correo y rol son obligatorios
  #   - La contraseña, si se cambia, exige al menos 10 caracteres y su confirmación
  #   - Un administrador solo puede editar usuarios de una empresa suya
  #   - Editar los datos de un usuario no exige cambiarle la contraseña
