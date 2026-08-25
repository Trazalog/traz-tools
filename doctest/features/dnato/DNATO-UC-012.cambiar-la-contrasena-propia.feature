# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-012.yaml (versión 0.3, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@dnato @DNATO-UC-012
Característica: Cambiar la contraseña propia

  Quién lo hace: Usuario
  Dónde: Menú de usuario → Editar Perfil (sección de contraseña)

  Antecedentes:
    Dado Sesión iniciada

  Escenario: Camino principal
    Cuando Abre la pantalla de edición de perfil
    Entonces Se muestra la sección para cambiar la contraseña
    Y cuando Ingresa la contraseña nueva y su confirmación, y confirma
    Entonces Se muestra 'Tu contraseña ha sido actualizada.'

  Escenario: Contraseña que no cumple la política
    Cuando Ingresa 'doctest2026' (10 caracteres, sin mayúscula ni símbolo)
    Entonces Se muestra el error de validación y la contraseña no cambia

  Escenario: Confirmación distinta
    Cuando Ingresa una confirmación que no coincide
    Entonces Se muestra el error de coincidencia y la contraseña no cambia

  # Reglas que este caso verifica:
  #   - La contraseña nueva exige 10 caracteres o más, mayúscula, minúscula, dígito y símbolo
  #   - La confirmación debe coincidir
  #   - La contraseña la administra únicamente Dnato: no se replica a ningún otro sistema

  # ⚠️ Atención al ejecutarlo:
  #   Validado por el PM el 2026-08-24. Que no se pida la contraseña actual queda anotado como mejora de seguridad (hallazgo H-010). Que no se propague a Bonita ni a Asset **no es un problema**: la contraseña la maneja Dnato y nadie más.
