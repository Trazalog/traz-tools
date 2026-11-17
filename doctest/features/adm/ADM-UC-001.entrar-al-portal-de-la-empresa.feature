# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/adm/ADM-UC-001.yaml (versión 1.0, validado 2026-11-10).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/adm/ADM-UC-001.portal.spec.ts

@adm @ADM-UC-001
Característica: Entrar al Portal de la empresa

  Quién lo hace: Administrador
  Dónde: Portal de la empresa → Inicio (dirección traz-comp-adm/portal)

  Antecedentes:
    Dado Usuario con sesión iniciada en Tools
    Y El usuario es Administrador de la empresa activa de su sesión

  Escenario: Camino principal
    Cuando Con la sesión de Tools abierta, entra a la dirección del Portal de la empresa
    Entonces Se abre el Portal con la barra 'Trazalog · Mi empresa', la inicial y el nombre de su empresa, el menú lateral con 'Inicio' y el saludo 'Hola, <nombre>'
    Y cuando Toca '← Ir a Tools'
    Entonces Vuelve al tablero de Tools, con la misma sesión y la misma empresa

  Escenario: Sin sesión
    Cuando Sin haber iniciado sesión, entra a la dirección del Portal
    Entonces Lo lleva a la pantalla de ingreso y no ve nada del Portal

  Escenario: Usuario que no es administrador
    Cuando Un usuario sin rol de administrador en la empresa activa entra a la dirección del Portal
    Entonces Ve 'No tenés permiso para entrar a esta pantalla.' y no ve el nombre de la empresa ni el menú

  Escenario: Otra empresa en la dirección
    Cuando Agrega a la dirección del Portal el número de otra empresa (por ejemplo, ?empr_id=1)
    Entonces El Portal sigue mostrando la empresa de su sesión; la de la dirección se ignora

  Escenario: Página del módulo que no existe
    Cuando Entra a una dirección del módulo que no existe (por ejemplo, traz-comp-adm/portal/no-existe)
    Entonces Ve 'Esa página no existe.', distinto del mensaje de falta de permiso

  # Reglas que este caso verifica:
  #   - Sin sesión no se entra a ninguna pantalla del módulo
  #   - Al Portal entra solo el administrador de la empresa activa de la sesión
  #   - La empresa sale siempre de la sesión; la que venga del navegador se ignora
  #   - Una página inexistente responde 'no existe' y no 'sin permiso'

  # Datos de prueba:
  #   empresa: empresa DocTest del ambiente (DOCTEST_EMPRESA)
  #   usuario_no_admin: uno de los usuarios por defecto de la empresa DocTest, por ejemplo usuario@<dominio>
  #   empresa_ajena_en_direccion: cualquier empr_id distinto del de la sesión
