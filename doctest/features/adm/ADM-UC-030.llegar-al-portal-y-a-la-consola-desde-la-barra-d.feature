# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/adm/ADM-UC-030.yaml (versión 1.0, validado 2026-11-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/adm/ADM-UC-030.barra-tools.spec.ts

@adm @ADM-UC-030
Característica: Llegar al Portal y a la Consola desde la barra de Tools

  Quién lo hace: Administrador
  Dónde: Tools → barra superior → 🏢 Mi empresa · Tools → barra superior → 🔑 Consola

  Antecedentes:
    Dado Usuario con sesión iniciada en Tools
    Y El usuario es Administrador de la empresa activa de su sesión

  Escenario: Camino principal
    Cuando Entra al tablero de Tools
    Entonces En la barra superior, a la izquierda de su perfil, ve el botón '🏢 Mi empresa'
    Y cuando Toca '🏢 Mi empresa'
    Entonces Se abre el Portal de su empresa en la misma pestaña
    Y cuando Toca '← Ir a Tools'
    Entonces Vuelve al tablero de Tools con la misma sesión y la misma empresa

  Escenario: Usuario que no es administrador
    Cuando Un usuario sin rol de administrador en la empresa activa entra al tablero
    Entonces No ve '🏢 Mi empresa' ni '🔑 Consola'; el resto de la barra está igual que antes

  Escenario: Superusuario
    Cuando Un superusuario que además es administrador de la empresa activa entra al tablero
    Entonces Ve '🏢 Mi empresa' y '🔑 Consola'; '🔑 Consola' abre la Consola en la misma pestaña

  Escenario: Superusuario que no administra la empresa activa
    Cuando Un superusuario sin rol de administrador en la empresa activa entra al tablero
    Entonces Ve solo '🔑 Consola'

  Escenario: Cambia a una empresa que no administra
    Cuando Un administrador de una empresa con otro rol en una segunda empresa cambia a la segunda
    Entonces El botón '🏢 Mi empresa' desaparece; al volver a la primera, vuelve a aparecer

  Escenario: El servicio no responde
    Cuando Un administrador entra al tablero mientras el servicio de datos del módulo no responde
    Entonces No ve los botones nuevos, el tablero carga igual y no aparece ningún mensaje de error

  # Reglas que este caso verifica:
  #   - '🏢 Mi empresa' se ve solo si es administrador de la empresa activa
  #   - '🔑 Consola' se ve solo si es superusuario, administre o no la empresa activa
  #   - Los botones dependen de la empresa activa: cambian al cambiar de empresa
  #   - Si el servicio de contexto falla, Tools funciona igual y no muestra botones
  #   - Los botones abren el Portal y la Consola en la misma pestaña

  # Datos de prueba:
  #   administrador: administrador de la empresa DocTest
  #   usuario_no_admin: uno de los usuarios por defecto de la empresa DocTest
  #   superusuario: usuario de prueba con la marca de superusuario en el ambiente (nunca el de producción)
