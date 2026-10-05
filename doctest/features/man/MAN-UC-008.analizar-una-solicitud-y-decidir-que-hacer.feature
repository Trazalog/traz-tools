# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-008.yaml (versión 1.0, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-008
Característica: Analizar una solicitud y decidir qué hacer

  Quién lo hace: Supervisor
  Dónde: Mantenimiento → Solicitud de Servicio · Mis Tareas

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner
    Y Existe una solicitud pendiente de análisis

  Escenario: Camino principal
    Cuando Abre la solicitud pendiente, desde el listado o desde Mis Tareas
    Entonces Se muestra qué equipo es, qué reportó el solicitante y los archivos que adjuntó
    Y cuando Decide si el trabajo es urgente
    Entonces De esa única decisión sale todo lo demás
    Y cuando Si es urgente: la solicitud se marca como urgente y el propio Supervisor la planifica
    Entonces El Supervisor le pone fecha y después asigna el mantenedor que la va a hacer
    Y cuando Si no es urgente: la solicitud se convierte en un backlog
    Entonces El Supervisor completa el backlog y a partir de ahí lo toma el Planificador, que le pone fecha y asigna el mantenedor

  # Reglas que este caso verifica:
  #   - **La urgencia es la única decisión de este paso, y define quién sigue**: si es urgente, el Supervisor planifica y asigna; si no, pasa al Planificador por la vía del backlog
  #   - Una solicitud rechazada no genera orden de trabajo
