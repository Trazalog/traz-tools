# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-036.yaml (versión 0.1, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@man @MAN-UC-036
Característica: Editar o quitar la asociación de un componente

  Quién lo hace: Supervisor
  Dónde: Mantenimiento → Componentes

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner
    Y El equipo tiene componentes asociados (MAN-UC-006)

  Escenario: Camino principal
    Cuando En la tabla de componentes del equipo elige Editar asociación
    Entonces Se pueden cambiar el código trazable y el sistema de esa asociación
    Y cuando Guarda
    Entonces La asociación queda actualizada

  Escenario: Quitar el componente del equipo
    Cuando Elige Eliminar asociación
    Entonces El componente deja de estar asociado a ese equipo, pero sigue existiendo en el catálogo

  # Reglas que este caso verifica:
  #   - Quitar la asociación no borra el componente del catálogo: sigue disponible para otros equipos
  #   - Quitar la asociación no borra el componente del catálogo
