# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/adm/ADM-UC-011.yaml (versión 1.0, validado 2026-11-20).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/adm/ADM-UC-011.sesion-compartida-1.spec.ts

@adm @ADM-UC-011
Característica: Ingresar por el módulo y seguir trabajando en Tools y en DNATO

  Quién lo hace: Usuario
  Dónde: Ingreso del módulo → ¿Con qué empresa querés ingresar? → tablero de Tools · DNATO (dirección traz-comp-dnato/main/...)

  Antecedentes:
    Dado Sin sesión iniciada
    Y El usuario tiene membresía en al menos dos empresas

  Escenario: Camino principal
    Cuando Ingresa por la dirección del ingreso del módulo con su correo y contraseña, y elige una empresa
    Entonces Entra al tablero de Tools con esa empresa como empresa activa
    Y cuando Abre en Tools una pantalla de su trabajo (por ejemplo, el listado de equipos)
    Entonces La pantalla muestra los datos de la empresa elegida, sin volver a pedir el ingreso
    Y cuando Abre en la misma ventana una pantalla de DNATO que use la sesión (por ejemplo, su perfil)
    Entonces DNATO lo reconoce con el mismo usuario y la misma empresa, sin volver a pedir el ingreso
    Y cuando Elige 'Salir' en el menú de usuario de Tools
    Entonces Se cierra la sesión para las tres partes: Tools, DNATO y el módulo vuelven a pedir el ingreso

  Escenario: Una sola empresa
    Cuando Un usuario con una sola empresa ingresa por la copia
    Entonces Entra directo al tablero de Tools con esa empresa, y en DNATO se ve la misma empresa

  Escenario: Salir desde la copia
    Cuando Con la sesión abierta por la copia, abre la salida del módulo (traz-comp-adm/main/logout)
    Entonces Vuelve al ingreso del módulo, y Tools y DNATO también piden ingresar de nuevo

  Escenario: Misma sesión en el sistema de procesos
    Cuando Ingresa por la copia y abre en Tools la bandeja de tareas
    Entonces Ve sus tareas de la empresa elegida, igual que si hubiera ingresado por DNATO

  # Reglas que este caso verifica:
  #   - La sesión abierta por la copia sirve, sin volver a ingresar, en Tools y en DNATO
  #   - La empresa activa es la misma en las tres partes
  #   - La copia guarda en la sesión los mismos datos que DNATO, incluido el usuario y el grupo del sistema de procesos
  #   - Salir, desde Tools o desde la copia, cierra la sesión para las tres partes
  #   - Un usuario con una sola empresa entra directo también por la copia

  # Datos de prueba:
  #   usuario_varias_empresas: usuario de la empresa DocTest con membresía también en otra empresa de prueba del ambiente
  #   usuario_una_empresa: uno de los usuarios por defecto de la empresa DocTest
