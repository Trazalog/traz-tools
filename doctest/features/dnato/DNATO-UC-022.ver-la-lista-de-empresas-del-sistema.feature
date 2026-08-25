# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-022.yaml (versión 0.2, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/dnato/DNATO-UC-022.empresas-superusuario.spec.ts

@dnato @DNATO-UC-022
Característica: Ver la lista de empresas del sistema

  Quién lo hace: Superusuario
  Dónde: Gestión de Empresas → Lista de Empresas

  Antecedentes:
    Dado Sesión iniciada con el usuario superusuario del ambiente

  Escenario: Camino principal
    Cuando Abre 'Lista de Empresas'
    Entonces Se muestra el listado de todas las empresas del sistema

  Escenario: Administrador común
    Cuando Un administrador que no es el superusuario abre la dirección de la lista de empresas
    Entonces Se lo redirige a la pantalla principal sin mostrar la lista

  Escenario: Sin sesión
    Cuando Abre la dirección sin haber iniciado sesión
    Entonces Se lo redirige a la pantalla de ingreso

  # Reglas que este caso verifica:
  #   - El menú 'Gestión de Empresas' solo aparece para el superusuario del ambiente
  #   - El superusuario se define hoy en `constants.php` y además tiene que existir como usuario en `seg.users`
