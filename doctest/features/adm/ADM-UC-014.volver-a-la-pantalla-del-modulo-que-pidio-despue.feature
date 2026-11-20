# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/adm/ADM-UC-014.yaml (versión 1.0, validado 2026-11-20).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/adm/ADM-UC-014.volver-a-pantalla.spec.ts

@adm @ADM-UC-014
Característica: Volver a la pantalla del módulo que pidió, después de ingresar

  Quién lo hace: Administrador
  Dónde: Portal de la empresa (sin sesión) → Ingreso del módulo → Portal de la empresa

  Antecedentes:
    Dado Sin sesión iniciada
    Y El usuario es Administrador de la empresa con la que va a ingresar

  Escenario: Camino principal
    Cuando Sin sesión, abre la dirección del Portal de la empresa
    Entonces Lo lleva al ingreso del módulo
    Y cuando Ingresa con su correo y contraseña (tiene una sola empresa)
    Entonces Vuelve directo al Portal de la empresa, no al tablero de Tools

  Escenario: Varias empresas
    Cuando Un administrador con varias empresas abre el Portal sin sesión, ingresa y elige la empresa que administra
    Entonces Después de elegir la empresa, vuelve al Portal de esa empresa

  Escenario: Elige una empresa que no administra
    Cuando Abre el Portal sin sesión, ingresa y elige una empresa donde no es administrador
    Entonces Ve 'No tenés permiso para entrar a esta pantalla.'

  Escenario: Ingreso directo
    Cuando Abre directamente la dirección del ingreso del módulo e ingresa
    Entonces Entra al tablero de Tools, como hoy

  Escenario: Dirección de vuelta de afuera
    Cuando Abre el ingreso del módulo agregando a la dirección una página de otro sitio para volver (por ejemplo, ?volver=https://otro-sitio.com) e ingresa
    Entonces Entra al tablero de Tools; la dirección de afuera se ignora

  # Reglas que este caso verifica:
  #   - Si llegó al ingreso porque pidió una pantalla del módulo sin sesión, después de ingresar vuelve a esa pantalla
  #   - Vuelve a la pantalla pedida también cuando tiene que elegir empresa
  #   - Volver no saltea el permiso: si la empresa elegida no le da acceso, ve 'sin permiso'
  #   - Sin pantalla pedida, después de ingresar va al tablero de Tools
  #   - La pantalla a la que se vuelve sale de la sesión, nunca de la dirección, y solo puede ser una del módulo

  # Datos de prueba:
  #   administrador: administrador de la empresa DocTest
  #   administrador_varias_empresas: usuario de prueba administrador en una empresa y con otro rol en otra
