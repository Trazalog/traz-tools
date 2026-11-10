# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-040.yaml (versión 1.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-040-041.lanzar-anular.spec.ts

@man @MAN-UC-040
Característica: Lanzar las órdenes programadas

  Quién lo hace: Planificador
  Dónde: Mantenimiento → Ordenes de Trabajo → Lanzar · Mantenimiento → Plan de Mantenimiento → (clic en la orden) → Lanzar ahora

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO) con perfil Planificador
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"
    Y Hay una orden de preventivo o predictivo programada sin lanzar (MAN-UC-009)

  Escenario: Camino principal
    Cuando En Ordenes de Trabajo ubica una orden marcada "Sin lanzar" y elige Lanzar
    Entonces Se abre el caso de Bonita de la orden y la marca "Sin lanzar" desaparece

  Escenario: Lanzamiento automático
    Cuando El cron del servidor corre el lanzamiento
    Entonces Se lanzan todas las órdenes sin lanzar cuya fecha entró en el margen de la empresa

  Escenario: Desde el calendario
    Cuando Hace clic sobre la orden y elige "Lanzar ahora"
    Entonces Pasa lo mismo que con el botón de la lista

  Escenario: El lanzamiento falla
    Cuando Bonita no responde al lanzar
    Entonces La orden queda programada sin lanzar y se reintenta en la corrida siguiente

  # Reglas que este caso verifica:
  #   - "Sin lanzar" es una orden `PL` de preventivo o predictivo sin caso de Bonita (`case_id` 0)
  #   - El margen es de 7 días salvo que la empresa configure otro en la lista de valores (`core.tablas`, `man_dias_lanzamiento_<empresa>`)
  #   - El caso se inicia en nombre del usuario que programó la orden
  #   - Las series ya lanzadas se dejan como están
