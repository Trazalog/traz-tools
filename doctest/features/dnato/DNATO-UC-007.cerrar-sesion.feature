# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-007.yaml (versión 0.3, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/dnato/DNATO-UC-007.cerrar-sesion.spec.ts

@dnato @DNATO-UC-007
Característica: Cerrar sesión

  Quién lo hace: Usuario
  Dónde: Menú de usuario → Salir

  Antecedentes:
    Dado Sesión iniciada

  Escenario: Camino principal
    Cuando Elige 'Salir' en el menú de usuario
    Entonces Se cierra la sesión y vuelve a la pantalla de ingreso
    Y cuando Intenta volver a una pantalla interna con el botón atrás del navegador
    Entonces Se lo redirige nuevamente a la pantalla de ingreso

  # Reglas que este caso verifica:
  #   - Después de salir, ninguna pantalla interna queda accesible sin volver a iniciar sesión
  #   - Al salir, el usuario vuelve a la pantalla de ingreso
