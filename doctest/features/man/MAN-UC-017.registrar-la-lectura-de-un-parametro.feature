# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-017.yaml (versión 0.1, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-012-020.informes-reportes.spec.ts

@man @MAN-UC-017
Característica: Registrar la lectura de un parámetro

  Quién lo hace: Mantenedor
  Dónde: Mantenimiento → Registro de Parametros

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner
    Y El equipo tiene parámetros configurados (MAN-UC-016)

  Escenario: Camino principal
    Cuando Entra a Mantenimiento → Registro de Parametros
    Entonces Se listan las lecturas ya cargadas con Equipo, Parámetro, Fecha y Valor
    Y cuando Elige el equipo y el parámetro que midió
    Entonces El formulario queda listo para el valor
    Y cuando Carga la fecha y el valor medido
    Entonces La lectura queda registrada

  # Reglas que este caso verifica:
  #   - La lectura queda como la última del equipo y alimenta los mantenimientos que se disparan por uso
  #   - Equipo, parámetro, fecha y valor son obligatorios
  #   - La lectura queda como la última del equipo
