# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/adm/ADM-UC-031.yaml (versión 1.0, validado 2026-11-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/adm/ADM-UC-031.superusuario-marca.spec.ts

@adm @ADM-UC-031
Característica: Ser superusuario por la marca en el usuario

  Quién lo hace: Superusuario
  Dónde: Portal de la empresa → 🔑 Consola · Consola (dirección traz-comp-adm/consola)

  Antecedentes:
    Dado Usuario con sesión iniciada en Tools
    Y El usuario tiene la marca de superusuario

  Escenario: Camino principal
    Cuando Con la marca de superusuario, entra a la dirección de la Consola
    Entonces Se abre la Consola con la barra 'Trazalog · Consola' y la leyenda 'solo súper usuarios'
    Y cuando Abre el Portal de una empresa que administra
    Entonces Ve '🔑 Consola' en la cabecera del Portal

  Escenario: El correo de TOOLS_ADMIN_USER sin la marca
    Cuando En un ambiente de prueba, al usuario cuyo correo es TOOLS_ADMIN_USER se le saca la marca, y entra a la Consola
    Entonces Ve 'No tenés permiso para entrar a esta pantalla.': el correo ya no autoriza en el módulo

  Escenario: Otro usuario con la marca
    Cuando Un usuario de prueba con otro correo y la marca de superusuario entra a la Consola
    Entonces Entra a la Consola

  Escenario: Después de la migración
    Cuando Después de correr el script en el ambiente, el usuario de TOOLS_ADMIN_USER entra a la Consola
    Entonces Entra, porque la migración le puso la marca

  Escenario: Sin la marca
    Cuando Un administrador sin la marca entra a la dirección de la Consola
    Entonces Ve 'No tenés permiso para entrar a esta pantalla.' y no ve el botón '🔑 Consola' en el Portal

  # Reglas que este caso verifica:
  #   - A la Consola entra solo quien tiene la marca de superusuario
  #   - El correo TOOLS_ADMIN_USER ya no autoriza en el módulo
  #   - La marca vale para cualquier usuario, no para un correo fijo
  #   - La migración marca al usuario de TOOLS_ADMIN_USER de cada ambiente
  #   - Sin la marca no se ve '🔑 Consola' en el Portal

  # Datos de prueba:
  #   superusuario: usuario de prueba con la marca en el ambiente
  #   segundo_superusuario: otro usuario de prueba al que se le pone la marca solo para este caso
