# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/adm/ADM-UC-010.yaml (versión 1.0, validado 2026-11-20).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/adm/ADM-UC-010.lista-publica.spec.ts

@adm @ADM-UC-010
Característica: Entrar sin sesión solo a las páginas públicas de identidad del módulo

  Quién lo hace: Visitante
  Dónde: Ingreso del módulo (dirección traz-comp-adm/main/login) · Registro Nuevo Usuario (traz-comp-adm/main/register) · Recuperar Contraseña (traz-comp-adm/main/forgot)

  Antecedentes:
    Dado Sin sesión iniciada
    Y El módulo Administración está montado en Tools (REQ-002)

  Escenario: Camino principal
    Cuando Sin haber iniciado sesión, abre la dirección del ingreso del módulo
    Entonces Se muestra la pantalla 'Bienvenido' con los campos de correo y contraseña, igual a la de DNATO
    Y cuando Toca 'Registrese por favor'
    Entonces Se muestra 'Registro Nuevo Usuario', igual al de DNATO, dentro de la dirección del módulo
    Y cuando Vuelve al ingreso y toca 'Recupere contraseña'
    Entonces Se muestra 'Recuperar Contraseña', dentro de la dirección del módulo

  Escenario: Pantalla del módulo que no es pública
    Cuando Sin sesión, abre la dirección del Portal de la empresa (traz-comp-adm/portal)
    Entonces Lo lleva al ingreso del módulo (no al de DNATO) y no ve nada del Portal

  Escenario: Método auxiliar del registro
    Cuando Sin sesión, abre por dirección directa traz-comp-adm/main/procesarRegistro
    Entonces Ve 'Esa página no existe.' y no se crea ninguna cuenta

  Escenario: Pantalla de DNATO que no se copió
    Cuando Sin sesión, abre traz-comp-adm/main/users
    Entonces Ve 'Esa página no existe.'

  Escenario: Envío sin código de seguridad
    Cuando Envía el formulario de ingreso del módulo desde otra página, sin el código de seguridad
    Entonces Ve 'La página venció. Volvé a cargarla e intentá de nuevo.' y no inicia sesión

  Escenario: Ya tiene sesión
    Cuando Con la sesión abierta, abre la dirección del ingreso del módulo
    Entonces Lo lleva al tablero de Tools sin mostrar el ingreso, igual que DNATO

  # Reglas que este caso verifica:
  #   - Sin sesión solo se entra a las páginas de la lista pública: ingreso, elección de empresa, salida, registro, activación, recuperación y los pasos de alta de empresa
  #   - Una pantalla del módulo que no es pública manda al ingreso del módulo
  #   - Ningún método auxiliar de la copia se puede abrir desde el navegador
  #   - Lo que no se copió de DNATO no existe en el módulo
  #   - Todo envío, también los de las páginas públicas, exige el código de seguridad
  #   - Con sesión abierta, el ingreso manda al tablero de Tools

  # Datos de prueba:
  #   direccion_ingreso_copia: valor de la variable de identidad de DocTest del ambiente
