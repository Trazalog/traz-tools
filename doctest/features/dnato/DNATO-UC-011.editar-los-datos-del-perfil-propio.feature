# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-011.yaml (versión 0.3, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/dnato/DNATO-UC-011.editar-perfil.spec.ts

@dnato @DNATO-UC-011
Característica: Editar los datos del perfil propio

  Quién lo hace: Usuario
  Dónde: Menú de usuario → Editar Perfil

  Antecedentes:
    Dado Sesión iniciada

  Escenario: Camino principal
    Cuando Abre 'Editar Perfil'
    Entonces Se muestra el formulario con sus datos actuales
    Y cuando Modifica nombre, apellido o correo y confirma
    Entonces Se muestra 'Tu perfil ha sido actualizado.' y los datos quedan guardados

  Escenario: Campos obligatorios vacíos
    Cuando Borra el nombre, el apellido o el correo y confirma
    Entonces Se muestra el error de validación y los datos no se guardan

  Escenario: No se puede guardar
    Cuando Confirma cuando la actualización falla
    Entonces Se muestra 'Tu perfil no ha podido ser actualizado'

  # Reglas que este caso verifica:
  #   - Nombre, apellido y correo son obligatorios; el correo debe tener formato válido
  #   - El usuario NO puede cambiar su correo: es su identidad en el sistema de procesos y en las membresías

  # ⚠️ Atención al ejecutarlo:
  #   Validado por el PM el 2026-08-24 con esa regla. **Hoy el sistema no la cumple**: el formulario permite editar el correo. Registrado como hallazgo H-017.
