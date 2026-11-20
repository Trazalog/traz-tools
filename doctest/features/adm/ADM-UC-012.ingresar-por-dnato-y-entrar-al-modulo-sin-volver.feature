# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/adm/ADM-UC-012.yaml (versión 1.0, validado 2026-11-20).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/adm/ADM-UC-012.sesion-compartida-2.spec.ts

@adm @ADM-UC-012
Característica: Ingresar por DNATO y entrar al módulo sin volver a ingresar

  Quién lo hace: Administrador
  Dónde: Ingreso de DNATO → tablero de Tools · Portal de la empresa (dirección traz-comp-adm/portal)

  Antecedentes:
    Dado Sin sesión iniciada
    Y El usuario es Administrador de una empresa

  Escenario: Camino principal
    Cuando Ingresa por el ingreso de DNATO, como hoy
    Entonces Entra al tablero de Tools con su empresa activa
    Y cuando En la misma ventana abre la dirección del Portal de la empresa
    Entonces Se abre el Portal con el nombre de su empresa y el saludo 'Hola, <nombre>', sin volver a pedir el ingreso
    Y cuando Abre la dirección del ingreso del módulo
    Entonces Lo lleva al tablero de Tools sin mostrar el ingreso, porque ya tiene sesión

  Escenario: Ingresó por DNATO con otra empresa
    Cuando Un administrador de dos empresas ingresa por DNATO eligiendo la empresa donde no es administrador, y abre el Portal
    Entonces Ve 'No tenés permiso para entrar a esta pantalla.': el módulo usa la empresa elegida en DNATO

  Escenario: Sale por DNATO
    Cuando Con el Portal abierto, sale por la salida de DNATO y vuelve a abrir el Portal
    Entonces Lo lleva al ingreso del módulo y no ve nada del Portal

  Escenario: Usuario sin rol de administrador
    Cuando Un usuario que no es administrador ingresa por DNATO y abre el Portal
    Entonces Ve 'No tenés permiso para entrar a esta pantalla.', igual que si hubiera ingresado por la copia

  # Reglas que este caso verifica:
  #   - La sesión abierta por DNATO sirve en el módulo sin volver a ingresar
  #   - El módulo usa la empresa activa que eligió en DNATO
  #   - Con sesión abierta por DNATO, el ingreso del módulo manda al tablero de Tools
  #   - Si sale por DNATO, el módulo también queda sin sesión
  #   - El permiso en el módulo es el mismo, haya ingresado por DNATO o por la copia

  # Datos de prueba:
  #   administrador: administrador de la empresa DocTest (el que crea la registración)
  #   usuario_no_admin: uno de los usuarios por defecto de la empresa DocTest
