# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/adm/ADM-UC-032.yaml (versión 1.0, validado 2026-11-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/adm/ADM-UC-032.administrador-unico.spec.ts

@adm @ADM-UC-032
Característica: Ser administrador de la empresa por una sola definición

  Quién lo hace: Administrador
  Dónde: Tools → 🏢 Mi empresa → Portal de la empresa

  Antecedentes:
    Dado Usuario con sesión iniciada en Tools
    Y El usuario tiene rol de Administrador en la empresa activa

  Escenario: Camino principal
    Cuando Un usuario con rol de Administrador en la empresa activa entra al tablero de Tools
    Entonces Ve '🏢 Mi empresa'
    Y cuando Toca '🏢 Mi empresa'
    Entonces Entra al Portal de la empresa: el botón y el Portal dicen lo mismo

  Escenario: Se registró pero no es administrador de esta empresa
    Cuando Un usuario que se registró solo (tiene el nivel general de administrador) pero en la empresa activa tiene rol de Supervisor entra al tablero y abre la dirección del Portal
    Entonces No ve '🏢 Mi empresa' y el Portal muestra 'No tenés permiso para entrar a esta pantalla.'

  Escenario: Membresía suspendida
    Cuando En un ambiente de prueba, la membresía de administrador en la empresa queda en estado baneado, y la persona entra al tablero
    Entonces No ve '🏢 Mi empresa' y el Portal le responde 'sin permiso'

  Escenario: La empresa coincide solo por la descripción
    Cuando Un administrador cuya membresía nombra a la empresa por su descripción y no por su nombre abre el Portal
    Entonces Ve 'No tenés permiso para entrar a esta pantalla.': la membresía se une a la empresa solo por el nombre

  Escenario: Superusuario sin rol en la empresa
    Cuando Un superusuario sin rol de administrador en la empresa activa abre la dirección del Portal
    Entonces Ve 'No tenés permiso para entrar a esta pantalla.'

  # Reglas que este caso verifica:
  #   - Es administrador solo quien tiene rol de Administrador en la membresía de la empresa activa
  #   - El nivel general del usuario (role = 1) no hace administrador a nadie
  #   - Una membresía baneada o dada de baja no hace administrador
  #   - La membresía se une a la empresa por el nombre de la empresa, no por la descripción
  #   - Ser superusuario no hace administrador de una empresa
  #   - El botón 'Mi empresa' y el Portal usan la misma definición

  # Datos de prueba:
  #   administrador: administrador de la empresa DocTest
  #   registrado_con_otro_rol: usuario de prueba registrado por la registración (role = 1) con rol Supervisor en la empresa activa
