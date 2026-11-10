# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-030.yaml (versión 1.0, validado 2026-11-03).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-030.ciclo-ot.spec.ts

@man @MAN-UC-030
Característica: El ciclo de vida de una orden de trabajo

  Quién lo hace: Planificador
  Dónde: Mantenimiento → Ordenes de Trabajo

  Antecedentes:
    Dado Sesión iniciada en Tools (ingreso de DNATO)
    Y La empresa está vinculada con Mantenimiento (`core.empresas.empr_id_mysql`); sin eso las pantallas avisan "La empresa no está vinculada con Mantenimiento"

  Escenario: Camino principal
    Cuando Se programa desde el plan de mantenimiento (MAN-UC-009), venga de una solicitud, un preventivo, un predictivo o un backlog
    Entonces La orden nace planificada (`PL`), con las herramientas y los insumos copiados de su origen. Si es un preventivo o un predictivo lejano, nace sin lanzar y se lanza al entrar en el margen (MAN-UC-040)
    Y cuando Se asigna a un responsable con su pedido de materiales (MAN-UC-011)
    Entonces La orden queda asignada (`AS`) y el pedido va al almacén de tools
    Y cuando El mantenedor la ejecuta desde su bandeja
    Entonces La orden queda en curso (`C`)
    Y cuando Se carga el informe de servicio (MAN-UC-012)
    Entonces La orden queda terminada (`T`)
    Y cuando El supervisor verifica y el solicitante presta conformidad (MAN-UC-013)
    Entonces La orden pasa a `CE` y después a `CN`

  Escenario: Anular una orden sin lanzar
    Cuando Se anula desde el listado o el calendario (MAN-UC-041)
    Entonces La orden queda `AN` y deja de verse en el listado y en el calendario

  # Reglas que este caso verifica:
  #   - Una orden se puede cerrar **parcial** (`TE`) o **total** desde el listado
  #   - La orden pasa por `PL` → `AS` → `C` → `T` → `CE` → `CN`; las sin lanzar se pueden anular (`AN`)
  #   - La columna Origen dice de cuál de los cuatro caminos vino la orden
  #   - Los filtros del listado permiten ver las órdenes por estado y por período programado
