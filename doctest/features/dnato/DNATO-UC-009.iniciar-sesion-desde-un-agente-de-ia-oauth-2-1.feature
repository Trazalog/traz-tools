# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-009.yaml (versión 0.4, validado 2026-10-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/dnato/DNATO-UC-009.oauth-agente.spec.ts

@dnato @DNATO-UC-009
Característica: Iniciar sesión desde un agente de IA (OAuth 2.1)

  Quién lo hace: Usuario
  Dónde: Pantalla de ingreso del agente (OAuth) — indica qué aplicación pide acceso · Pantalla de selección de empresa (OAuth) — sólo si el usuario tiene más de una

  Antecedentes:
    Dado El cliente OAuth está habilitado en la configuración
    Y El usuario tiene al menos una empresa asignada

  Escenario: Camino principal
    Cuando El agente lo redirige a la pantalla de ingreso de Trazalog
    Entonces Se muestra el formulario de correo y contraseña, indicando qué aplicación pide el acceso
    Y cuando Ingresa correo y contraseña y confirma
    Entonces Si tiene una sola empresa, vuelve al agente ya autorizado. Si tiene más de una, se le muestran para elegir
    Y cuando Elige la empresa con la que quiere trabajar
    Entonces Vuelve al agente ya autorizado, con esa empresa

  Escenario: Usuario con más de una empresa
    Cuando Ingresa con una cuenta que tiene varias empresas asignadas
    Entonces Se muestra una tarjeta por empresa, con su nombre y su logo — las mismas que vería en el ingreso web
    Y cuando Elige una
    Entonces Vuelve al agente autorizado con esa empresa. Para cambiarla hay que reconectar el agente

  Escenario: Usuario sin empresa asignada
    Cuando Ingresa con una cuenta que no tiene ninguna empresa asignada
    Entonces Se muestra que no tiene empresa asignada y que contacte al administrador

  Escenario: Credenciales incorrectas
    Cuando Ingresa una contraseña equivocada
    Entonces Se muestra 'Correo o contraseña incorrectos.'

  Escenario: Cuenta inhabilitada
    Cuando Ingresa con una cuenta inhabilitada
    Entonces Se muestra que la cuenta está temporalmente inhabilitada

  Escenario: Sesión del pedido vencida
    Cuando Confirma las credenciales cuando el pedido del agente ya venció
    Entonces Se muestra que la sesión expiró y que inicie el proceso de nuevo desde el agente

  Escenario: Elige una empresa que no es suya
    Cuando Envía la elección con una empresa que no está entre las suyas
    Entonces Se muestra que la empresa seleccionada no es válida y vuelve a la lista

  # Reglas que este caso verifica:
  #   - Solo se aceptan clientes registrados, con response_type=code y code_challenge_method=S256
  #   - El formulario valida un token de seguridad propio antes de aceptar las credenciales
  #   - Las empresas que se ofrecen son las mismas que ofrece el ingreso web: salen de getEmpresasDeUsuario()
  #   - La empresa elegida se revalida contra esa consulta en el momento de confirmar, no contra lo guardado en la sesión
  #   - Las membresías que no resuelven a ninguna empresa vigente no se ofrecen, y quedan registradas en el log

  # Datos de prueba:
  #   empresa: EMPRESA_TEST_1
  #   nota: El flujo de más de una empresa necesita un usuario que pertenezca a dos. Hoy las fixtures tienen un usuario por empresa.
