# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-018.yaml (versión 0.3, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@dnato @DNATO-UC-018
Característica: Asignar y quitar roles de trabajo a un usuario en una empresa

  Quién lo hace: Administrador
  Dónde: Gestión de Usuarios → Lista de Usuarios → Asignar Rol · Cambio de Rol

  Antecedentes:
    Dado Sesión iniciada con perfil Administrador
    Y El usuario destino existe
    Y La empresa tiene creados sus roles de trabajo (los crea el alta de empresa, DNATO-UC-004)

  Escenario: Camino principal
    Cuando Elige 'Asignar Rol' sobre un usuario de la lista
    Entonces Se abre 'Cambio de Rol' con el email y el nombre del usuario, su perfil actual y la tabla 'Roles en el Sistema' con los roles que ya tiene por empresa
    Y cuando Hace clic en 'Agregar Rol', elige la empresa y el rol de trabajo, y acepta
    Entonces El rol se suma a la tabla de roles del usuario para esa empresa
    Y cuando Guarda los cambios
    Entonces Se confirma que los roles quedaron asignados y el usuario ya puede entrar a esa empresa con ese rol

  Escenario: Quitar un rol
    Cuando Elimina una fila de la tabla 'Roles en el Sistema' y guarda
    Entonces El rol deja de figurar y el usuario pierde ese acceso en esa empresa

  Escenario: Datos incompletos
    Cuando Acepta el modal sin elegir empresa o sin elegir rol
    Entonces Se muestra el error y no se agrega nada a la tabla

  Escenario: Falla la asignación en el sistema de procesos
    Cuando Guarda cuando Bonita responde con error
    Entonces Se muestra el error y se revierten las asignaciones de esa operación

  # Reglas que este caso verifica:
  #   - Los roles disponibles se cargan según la empresa elegida — son los roles de Bonita de esa empresa
  #   - Sin al menos un rol en una empresa, el usuario no puede iniciar sesión en ella (ver DNATO-UC-006 y DNATO-UC-014)
  #   - Un mismo usuario puede tener roles en varias empresas a la vez
  #   - No hay combinaciones de roles prohibidas: un usuario puede tener los que haga falta

  # Datos de prueba:
  #   empresa: EMPRESA_TEST_1
  #   rol: Solicitante de Mantenimiento
