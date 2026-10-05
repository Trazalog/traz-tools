# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-007.yaml (versión 1.0, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-007.solicitud-servicio.spec.ts

@man @MAN-UC-007
Característica: Pedir un servicio cuando algo falla

  Quién lo hace: Solicitante
  Dónde: Mantenimiento → Solicitud de Servicio

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner
    Y El equipo que falla está dado de alta

  Escenario: Camino principal
    Cuando Entra a Mantenimiento → Solicitud de Servicio
    Entonces Se muestra el listado con Nro, Nro de OT, Fecha, Fecha Fin, tiempos de ciclo, asignación y generación, Solicitante, Equipo y Sector
    Y cuando Crea una solicitud nueva
    Entonces Se abre el formulario
    Y cuando Elige el equipo que tiene el problema y describe qué pasa
    Entonces Quedan registrados el equipo y la descripción de la falla
    Y cuando Adjunta fotos o documentos si los tiene
    Entonces Los archivos quedan asociados a la solicitud
    Y cuando Confirma
    Entonces La solicitud queda registrada y a la espera de que alguien la analice

  # Reglas que este caso verifica:
  #   - Puede pedir un servicio cualquier usuario con el rol *Solicitante de Mantenimiento* en Bonita
  #   - La solicitud queda asociada al equipo y al solicitante
