# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-025.yaml (versión 0.3, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@dnato @DNATO-UC-025
Característica: Asignar opciones de menú a un rol de una empresa

  Quién lo hace: Administrador
  Dónde: Gestión de Menúes → Menu por Rol · Opción de Menú por Rol

  Antecedentes:
    Dado Sesión iniciada con perfil Administrador
    Y La empresa tiene creados sus roles de trabajo (DNATO-UC-004)

  Escenario: Camino principal
    Cuando Abre 'Menu por Rol'
    Entonces Se muestra la grilla con Grupo, Módulo, Opciones, Roles, Estado y Acciones, y una empresa recién creada ya trae sus asignaciones iniciales
    Y cuando Elige la empresa, el rol, el módulo y la opción de menú, y confirma
    Entonces Se muestra 'Guardado correctamente el registro.' y esa opción pasa a estar disponible para los usuarios con ese rol en esa empresa

  Escenario: Activar o desactivar la asignación
    Cuando Cambia el estado de una asignación existente
    Entonces La opción deja de verse (o vuelve a verse) para los usuarios con ese rol

  Escenario: No se puede guardar
    Cuando Confirma cuando la operación falla
    Entonces Se muestra 'Error, no se puede guardar el registro'

  # Reglas que este caso verifica:
  #   - La asignación es por empresa y rol: dos empresas pueden dar acceso a opciones distintas para el mismo rol
  #   - Es la pieza que conecta los roles de trabajo creados con la empresa (DNATO-UC-004) con lo que cada usuario ve en el menú de Tools
  #   - Las asignaciones iniciales de una empresa nueva se crean solas al darla de alta; esta pantalla sirve para ajustarlas después
  #   - Un administrador solo puede asignar menúes a roles de una empresa suya

  # Datos de prueba:
  #   empresa: EMPRESA_TEST_1
  #   rol: Solicitante de Mantenimiento

  # ⚠️ Atención al ejecutarlo:
  #   Validado por el PM el 2026-08-24 con esa regla. **Hoy el sistema no la cumple**: el desplegable de empresas trae todos los grupos del sistema. Registrado como hallazgo H-020.
  #   Que los roles de Mantenimiento no reciban menú es correcto: Mantenimiento todavía no está migrado a Tools y vive en Asset Planner, así que este ABM no lo afecta (aclara el hallazgo H-013, que queda acotado a los roles de SMA/Residuos).
