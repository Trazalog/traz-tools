# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-026.yaml (versión 0.4, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/dnato/DNATO-UC-026-027.carga-masiva.spec.ts

@dnato @DNATO-UC-026
Característica: Descargar la plantilla de carga masiva

  Quién lo hace: Administrador
  Dónde: Carga Masiva

  Antecedentes:
    Dado Sesión iniciada con perfil Administrador

  Escenario: Camino principal
    Cuando Abre 'Carga Masiva'
    Entonces Se muestran las entidades que se pueden cargar (por ejemplo artículos y herramientas)
    Y cuando Descarga la plantilla de la entidad que quiere cargar
    Entonces Se baja un archivo con las columnas esperadas, para completarlo con los datos

  Escenario: No se pueden obtener las entidades
    Cuando Abre la pantalla cuando el servicio que informa las entidades no responde
    Entonces Se avisa que se están usando datos de prueba y se muestra una lista mínima

  # Reglas que este caso verifica:
  #   - Las entidades que se pueden cargar salen de una tabla de configuración (`sta.entidades_negocio`), así que la lista crece sin tocar código. Las verificadas en pantalla son Articulos, Herramientas, Stock Articulos, Mantenimiento Equipos y Solicitantes de Transporte; la configuración declara además Mantenimiento Articulos
  #   - La plantilla que se descarga corresponde a la entidad elegida

  # ⚠️ Atención al ejecutarlo:
  #   **Mantenimiento Equipos ya funciona** (2026-09-01). Hasta el 2026-08-31 esa entidad fallaba con "Stored procedure no encontrado" porque su procedimiento vive en MariaDB y la carga solo sabía ejecutar contra PostgreSQL. Lo corrigió el PR #34 de `traz-comp-dnato`, que agrega el despacho por motor. Era el hallazgo H-030 / issue #470.
  #   La pantalla solo verifica que haya sesión iniciada, no que el usuario sea administrador (hallazgo H-029), aunque el menú se la muestre solo a administradores.
