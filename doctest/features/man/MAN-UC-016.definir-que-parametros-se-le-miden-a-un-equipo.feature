# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-016.yaml (versión 0.1, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-014-018.planes.spec.ts

@man @MAN-UC-016
Característica: Definir qué parámetros se le miden a un equipo

  Quién lo hace: Planificador
  Dónde: Mantenimiento → Parametrizar Predictivo

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner
    Y El equipo está dado de alta y el parámetro existe en el ABM

  Escenario: Camino principal
    Cuando Entra a Mantenimiento → Parametrizar Predictivo
    Entonces Se listan los parámetros ya configurados con su equipo, máximo y mínimo
    Y cuando Elige el equipo y el parámetro que se le va a medir
    Entonces Queda definido qué se controla en ese equipo
    Y cuando Carga el valor máximo y el mínimo aceptables, y una descripción
    Entonces Quedan definidos los límites que disparan la alerta
    Y cuando Guarda
    Entonces El parámetro queda activo para ese equipo

  # Reglas que este caso verifica:
  #   - El máximo y el mínimo quedan registrados como referencia del rango normal del parámetro
  #   - Un equipo puede tener varios parámetros configurados
  #   - El equipo, el parámetro, el máximo, el mínimo y la descripción son obligatorios
