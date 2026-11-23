# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/age/AGE-UC-001.yaml (versión 1.0, validado 2026-11-22).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/age/AGE-UC-001-009.panel-de-los-agentes.spec.ts

@age @AGE-UC-001
Característica: Preguntarle a Quirqui qué se hace en la pantalla donde estoy

  Quién lo hace: Responsable de Almacén
  Dónde: Cualquier pantalla de Tools → botón Q (abajo a la derecha)

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y El usuario tiene en su menú el ítem del agente (los agentes son una suscripción)
    Y Las ayudas y el catálogo están cargados en el conocimiento del agente

  Escenario: Camino principal
    Cuando Entra a Almacenes → Articulos
    Entonces Ve el botón Q abajo a la derecha
    Y cuando Abre el panel de Quirqui
    Entonces Se abre el panel con el aviso de medición arriba y un campo para escribir
    Y cuando Pregunta qué tiene que hacer en esa pantalla
    Entonces Quirqui explica para qué sirve el listado de artículos y sugiere el siguiente paso, citando la ayuda del manual de Almacenes

  Escenario: La pantalla no tiene casos de uso registrados
    Cuando Pregunta qué hacer en una pantalla que el catálogo no describe
    Entonces Quirqui dice que no tiene registrado qué se hace ahí y ofrece lo que sí sabe

  Escenario: El usuario cambia de pantalla con el panel abierto
    Cuando Navega a otra pantalla y vuelve a preguntar
    Entonces La respuesta habla de la pantalla nueva

  # Reglas que este caso verifica:
  #   - Quirqui solo describe la pantalla con lo que dice el catálogo validado; no inventa pasos
  #   - La ruta de la pantalla no puede usarse para darle instrucciones al agente
  #   - Decisión del PM (2026-11-22): el panel lo abre el usuario; la primera vez que entra a Tools, Quirqui muestra un globito chico ('¿Te ayudo con esta pantalla?') sin abrir el panel
  #   - Decisión del PM (2026-11-22): en pantallas que el catálogo todavía no describe (por ejemplo, Mantenimiento antes de llegar a esta versión), Quirqui dice que todavía no conoce esa pantalla
