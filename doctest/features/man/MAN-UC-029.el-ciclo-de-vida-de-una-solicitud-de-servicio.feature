# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-029.yaml (versión 1.0, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-029
Característica: El ciclo de vida de una solicitud de servicio

  Quién lo hace: Solicitante
  Dónde: Mantenimiento → Solicitud de Servicio · Mis Tareas

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner

  Escenario: Camino principal
    Cuando Alguien reporta una falla y crea la solicitud (MAN-UC-007), o la reporta al cargar una lectura (MAN-UC-024)
    Entonces La solicitud queda registrada y esperando análisis
    Y cuando El supervisor la analiza y decide (MAN-UC-008)
    Entonces La solicitud se acepta y pasa a planificación, o se rechaza
    Y cuando Se le programa una orden de trabajo (MAN-UC-009)
    Entonces La solicitud queda vinculada a esa orden — el listado muestra el Nº de OT
    Y cuando La orden se ejecuta, se informa y se verifica
    Entonces Cuando el solicitante presta conformidad, la solicitud queda cerrada

  # Reglas que este caso verifica:
  #   - Los estados los mueve el proceso, no el usuario: `S` solicitada, `PL` planificada, `C` en curso, `T` terminada, `CE` cerrada y `CN` conforme
  #   - Si el solicitante no presta conformidad, la solicitud vuelve a `S` y se reanaliza
  #   - El listado muestra el Nº de OT de la solicitud una vez programada
  #   - Los tiempos de ciclo, asignación y generación se miden sobre este recorrido
