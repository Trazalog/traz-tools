# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/adm/ADM-UC-003.yaml (versión 1.0, validado 2026-11-10).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/adm/ADM-UC-003.envios-falsificados.spec.ts

@adm @ADM-UC-003
Característica: Rechazar envíos falsificados en el módulo

  Quién lo hace: Administrador
  Dónde: Portal de la empresa → Inicio (dirección traz-comp-adm/portal)

  Antecedentes:
    Dado Usuario con sesión iniciada en Tools
    Y El usuario es Administrador de la empresa activa de su sesión
    Y Es una prueba de servicio, sin pantalla propia; el esqueleto todavía no tiene acciones que guarden

  Escenario: Camino principal
    Cuando Con la sesión abierta, manda un envío a la pantalla de inicio del Portal con el código de seguridad que le dio la página
    Entonces El envío se acepta y responde la pantalla normal

  Escenario: Dos pestañas abiertas
    Cuando Abre el Portal en dos pestañas y manda un envío desde cada una
    Entonces Los dos envíos se aceptan, porque el código dura toda la sesión

  Escenario: Envío sin código de seguridad
    Cuando Manda el mismo envío sin el código de seguridad
    Entonces Responde 'La página venció. Volvé a cargarla e intentá de nuevo.' (403) y no ejecuta nada

  Escenario: Envío con el código de otra sesión
    Cuando Manda el envío con un código de seguridad sacado de otra sesión
    Entonces Responde lo mismo que sin código y no ejecuta nada

  Escenario: Envío sin sesión
    Cuando Sin sesión, manda un envío a la pantalla de inicio del Portal
    Entonces Responde que hace falta iniciar sesión (401) y no ejecuta nada

  # Reglas que este caso verifica:
  #   - El código de seguridad dura toda la sesión: sirve en dos pestañas abiertas a la vez
  #   - Todo envío que no es de lectura exige el código de seguridad de la sesión
  #   - Un código de otra sesión no sirve
  #   - El control de sesión corre antes que el de código de seguridad

  # Datos de prueba:
  #   empresa: empresa DocTest del ambiente (DOCTEST_EMPRESA)
