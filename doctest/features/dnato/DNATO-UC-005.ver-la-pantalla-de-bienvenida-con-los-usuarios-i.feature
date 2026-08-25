# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-005.yaml (versión 0.3, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@dnato @DNATO-UC-005
Característica: Ver la pantalla de bienvenida con los usuarios iniciales

  Quién lo hace: Administrador
  Dónde: Registro Completado

  Antecedentes:
    Dado La empresa fue creada correctamente (DNATO-UC-004)

  Escenario: Camino principal
    Cuando Termina el alta de la empresa
    Entonces Se muestra la bienvenida con los cinco usuarios iniciales de la empresa —usuario, almacen, panol, produccion y mantenimiento, en el dominio de la empresa— con los roles de cada uno y la contraseña con la que fueron creados
    Y cuando Hace clic en 'Ir a iniciar sesión'
    Entonces Se cierra la sesión del registro y se muestra la pantalla de ingreso, donde ya puede entrar con su empresa

  Escenario: El alta terminó con advertencias
    Cuando Llega a la bienvenida cuando alguna parte de la configuración inicial dejó advertencias
    Entonces Se muestran las advertencias junto con la lista de usuarios

  # Reglas que este caso verifica:
  #   - Los usuarios iniciales son cinco: usuario (Solicitante de Almacén y de Mantenimiento), almacen (Responsable de Almacén), panol (Responsable de Pañol), produccion (Responsable de Producción) y mantenimiento (Supervisor y Planificador de Mantenimiento)
  #   - La sesión del registro se cierra al llegar a esta pantalla

  # ⚠️ Atención al ejecutarlo:
  #   Validado por el PM el 2026-08-24: por ahora la pantalla muestra la contraseña inicial a propósito. Pedirle al administrador que elija una contraseña para esos usuarios queda como mejora para más adelante, no para esta etapa (hallazgo H-001).
