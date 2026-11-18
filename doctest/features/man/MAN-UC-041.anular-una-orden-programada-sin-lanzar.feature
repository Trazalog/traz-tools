# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-041.yaml (versión 1.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-040-041.lanzar-anular.spec.ts

@man @MAN-UC-041
Característica: Anular una orden programada sin lanzar

  Quién lo hace: Planificador
  Dónde: Mantenimiento → Ordenes de Trabajo → Anular · Mantenimiento → Plan de Mantenimiento → (clic en la orden) → Anular

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO) con perfil Planificador
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"
    Y Hay una orden programada sin lanzar

  Escenario: Camino principal
    Cuando En Ordenes de Trabajo elige Anular sobre una orden "Sin lanzar"
    Entonces El sistema pide confirmación
    Y cuando Confirma
    Entonces La orden queda anulada (`AN`) y deja de verse en el listado y en el calendario

  # Reglas que este caso verifica:
  #   - Solo se pueden anular órdenes sin lanzar (`PL`, preventivo o predictivo, `case_id` 0): no hay caso de Bonita que cerrar
  #   - Queda registrado quién la anuló y cuándo
  #   - No se puede deshacer
