# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-013.yaml (versión 0.4, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/dnato/DNATO-UC-013.lista-de-usuarios.spec.ts

@dnato @DNATO-UC-013
Característica: Ver la lista de usuarios de la empresa

  Quién lo hace: Administrador
  Dónde: Gestión de Usuarios → Lista de Usuarios

  Antecedentes:
    Dado Sesión iniciada con perfil Administrador

  Escenario: Camino principal
    Cuando Abre 'Lista de Usuarios'
    Entonces Se muestra la grilla con id, Empresa, Nombre, Usuario, Último login, Nivel de Usuario, Estado y Acciones, con los usuarios de las empresas del administrador conectado
    Y cuando Busca un usuario por su correo
    Entonces La grilla filtra y muestra solo las filas que coinciden

  Escenario: Usuario sin perfil de administración
    Cuando Un usuario con perfil no administrador abre la dirección de la lista de usuarios
    Entonces Se lo redirige a la pantalla principal sin mostrar la lista

  Escenario: Sin sesión
    Cuando Abre la dirección sin haber iniciado sesión
    Entonces Se lo redirige a la pantalla de ingreso

  # Reglas que este caso verifica:
  #   - El listado se limita a las empresas en las que el administrador conectado tiene rol — no muestra usuarios de otras empresas
  #   - Cada fila ofrece las acciones 'Asignar Rol' y 'Eliminar Usuario'

  # Datos de prueba:
  #   empresa: EMPRESA_TEST_1
  #   empresa_ajena: EMPRESA_TEST_2

  # ⚠️ Atención al ejecutarlo:
  #   Validado por el PM el 2026-08-24: por ahora el superusuario aparece en la lista de todas las empresas y se acepta así; queda como posible mejora (hallazgo H-003).
