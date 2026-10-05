# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-024.yaml (versión 0.1, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-024
Característica: Registrar una lectura desde el equipo y reportar una falla

  Quién lo hace: Mantenedor
  Dónde: Mantenimiento → Equipos → Mantenimiento Autónomo

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner
    Y El equipo está dado de alta

  Escenario: Camino principal
    Cuando En el listado de equipos elige la acción Mantenimiento Autónomo
    Entonces Se abre el formulario para cargar la lectura del equipo
    Y cuando Carga la lectura, el operario, el turno y las observaciones
    Entonces Los datos quedan cargados
    Y cuando Si además detectó una falla, la reporta en el mismo formulario
    Entonces Se registra la lectura **y** se crea una solicitud de servicio con esa falla, que arranca el circuito correctivo

  Escenario: Solo cargar la lectura, sin falla
    Cuando Completa la lectura y deja el campo de falla vacío
    Entonces La lectura queda registrada y no se genera ninguna solicitud

  # Reglas que este caso verifica:
  #   - Lo carga el **Mantenedor**
  #   - La solicitud de servicio se crea solo si se reporta una falla; si no, queda solo la lectura
  #   - Lectura, operario, turno y observaciones son obligatorios
  #   - La solicitud de servicio solo se crea si se reporta una falla
