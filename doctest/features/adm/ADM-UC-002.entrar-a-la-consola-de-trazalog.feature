# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/adm/ADM-UC-002.yaml (versión 1.0, validado 2026-11-10).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/adm/ADM-UC-002.consola.spec.ts

@adm @ADM-UC-002
Característica: Entrar a la Consola de Trazalog

  Quién lo hace: Superusuario
  Dónde: Portal de la empresa → 🔑 Consola · Consola (dirección traz-comp-adm/consola)

  Antecedentes:
    Dado Usuario con sesión iniciada en Tools
    Y El usuario es superusuario del ambiente (su correo está en TOOLS_ADMIN_USER)
    Y El superusuario es además administrador de su empresa activa, para entrar por el Portal

  Escenario: Camino principal
    Cuando En el Portal de la empresa, toca '🔑 Consola'
    Entonces Se abre la Consola, con la barra 'Trazalog · Consola' y la leyenda 'solo súper usuarios'
    Y cuando Toca '🏢 Mi empresa'
    Entonces Vuelve al Portal de su empresa activa
    Y cuando Vuelve a la Consola y toca '← Ir a Tools'
    Entonces Vuelve al tablero de Tools, con la misma sesión

  Escenario: Segundo superusuario de la lista
    Cuando Otro usuario, cuyo correo es el segundo de la lista de superusuarios del ambiente, entra a la dirección de la Consola
    Entonces Entra a la Consola igual que el primero

  Escenario: Administrador que no es superusuario: no ve el botón
    Cuando Un administrador que no es superusuario entra al Portal
    Entonces No ve el botón '🔑 Consola'

  Escenario: Administrador que no es superusuario: dirección directa
    Cuando Un administrador que no es superusuario entra a la dirección de la Consola
    Entonces Ve 'No tenés permiso para entrar a esta pantalla.' y no ve nada de la Consola

  Escenario: Sin sesión
    Cuando Sin haber iniciado sesión, entra a la dirección de la Consola
    Entonces Lo lleva a la pantalla de ingreso

  # Reglas que este caso verifica:
  #   - Puede haber varios superusuarios: entra cualquiera cuyo correo esté en la lista del ambiente
  #   - A la Consola entra solo el superusuario
  #   - El botón '🔑 Consola' se muestra solo al superusuario
  #   - Sin sesión no se entra a la Consola

  # Datos de prueba:
  #   superusuario: uno de los correos de TOOLS_ADMIN_USER del ambiente; la contraseña va en doctest/.env, nunca en el catálogo
  #   administrador_comun: el administrador de la empresa DocTest
