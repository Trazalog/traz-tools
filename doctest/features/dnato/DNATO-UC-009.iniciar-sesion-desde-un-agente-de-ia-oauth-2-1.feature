# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-009.yaml (versión 0.3, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@dnato @DNATO-UC-009
Característica: Iniciar sesión desde un agente de IA (OAuth 2.1)

  Quién lo hace: Usuario
  Dónde: Pantalla de ingreso del agente (OAuth) — indica qué aplicación pide acceso

  Antecedentes:
    Dado El cliente OAuth está habilitado en la configuración
    Y El usuario tiene rol asignado en al menos una empresa

  Escenario: Camino principal
    Cuando El agente lo redirige a la pantalla de ingreso de Trazalog
    Entonces Se muestra el formulario de correo y contraseña, indicando qué aplicación pide el acceso
    Y cuando Ingresa correo y contraseña y confirma
    Entonces Se resuelve su empresa y vuelve al agente ya autorizado

  Escenario: Usuario sin empresa asignada
    Cuando Ingresa con una cuenta que no tiene ninguna empresa asignada
    Entonces Se muestra que no tiene empresa asignada y que contacte al administrador

  Escenario: Usuario con más de una empresa (comportamiento actual)
    Cuando Ingresa con una cuenta que tiene más de una empresa asignada
    Entonces Se muestra que la configuración no está soportada y que contacte al administrador

  Escenario: Credenciales incorrectas
    Cuando Ingresa una contraseña equivocada
    Entonces Se muestra 'Correo o contraseña incorrectos.'

  Escenario: Cuenta inhabilitada
    Cuando Ingresa con una cuenta inhabilitada
    Entonces Se muestra que la cuenta está temporalmente inhabilitada

  Escenario: Sesión del pedido vencida
    Cuando Confirma las credenciales cuando el pedido del agente ya venció
    Entonces Se muestra que la sesión expiró y que inicie el proceso de nuevo desde el agente

  # Reglas que este caso verifica:
  #   - Solo se aceptan clientes registrados, con response_type=code y code_challenge_method=S256
  #   - El formulario valida un token de seguridad propio antes de aceptar las credenciales
  #   - Hoy la pantalla exige exactamente una empresa por usuario (TAD-IDENT-02)

  # Datos de prueba:
  #   empresa: EMPRESA_TEST_1
