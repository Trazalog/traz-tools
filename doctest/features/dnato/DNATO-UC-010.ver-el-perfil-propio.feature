# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-010.yaml (versión 0.3, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/dnato/DNATO-UC-010.ver-perfil.spec.ts

@dnato @DNATO-UC-010
Característica: Ver el perfil propio

  Quién lo hace: Usuario
  Dónde: Menú de usuario → Perfil

  Antecedentes:
    Dado Sesión iniciada

  Escenario: Camino principal
    Cuando Abre 'Perfil' desde el menú de usuario
    Entonces Se muestran sus datos de cuenta

  Escenario: Sin sesión
    Cuando Abre la dirección del perfil sin haber iniciado sesión
    Entonces Se lo redirige a la pantalla de ingreso

  # Reglas que este caso verifica:
  #   - El perfil muestra los datos de la cuenta que el usuario reconoce (nombre, apellido, correo, teléfono, empresa); el nombre de usuario interno (`usernick`) no se muestra
