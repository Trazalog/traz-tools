# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/adm/ADM-UC-033.yaml (versión 1.0, validado 2026-11-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/adm/ADM-UC-033.variables-sistema.spec.ts

@adm @ADM-UC-033
Característica: Editar las variables de sistema y volver atrás

  Quién lo hace: Superusuario
  Dónde: Consola → Variables de sistema

  Antecedentes:
    Dado Usuario con sesión iniciada en Tools y la marca de superusuario
    Y El script de base corrió en el ambiente (las variables de RF-102 están cargadas)
    Y validez_invitacion_dias vale 7

  Escenario: Camino principal
    Cuando En la Consola toca '⚙️ Variables de sistema'
    Entonces Ve la tabla con Grupo, Clave, Valor, Última modificación y 'Historial' por fila, con las claves de la lista (validez_invitacion_dias, contacto_soporte, zona_horaria_cuotas, etc.)
    Y cuando Cambia validez_invitacion_dias de 7 a 10 y toca 'Guardar cambios'
    Entonces Ve 'Guardamos los cambios.'; la fila muestra 10 y en Última modificación su correo y la fecha de hoy
    Y cuando Toca 'Historial' en validez_invitacion_dias
    Entonces Ve la ventana 'Historial · validez_invitacion_dias' con el cambio de 7 a 10, su correo y la fecha
    Y cuando Toca 'Volver a 7'
    Entonces Ve 'Volvimos validez_invitacion_dias a 7.'; la variable vale 7 y el historial tiene 2 entradas

  Escenario: Guardar sin cambios
    Cuando Toca 'Guardar cambios' sin haber cambiado ningún valor
    Entonces Ve 'No hay cambios para guardar.' y el historial no cambia

  Escenario: Varias a la vez
    Cuando Cambia contacto_soporte y aviso_cuota_porcentaje y toca 'Guardar cambios'
    Entonces Las dos se guardan y cada una tiene su entrada en el historial

  Escenario: No es superusuario
    Cuando Un administrador sin la marca entra a la dirección de Variables de sistema
    Entonces Ve 'No tenés permiso para entrar a esta pantalla.' y no ve ninguna variable

  Escenario: El servicio no responde
    Cuando Toca 'Guardar cambios' mientras el servicio de datos no responde
    Entonces Ve 'No pudimos guardar. Probá de nuevo en un rato.' y ni el valor ni el historial cambian

  Escenario: Quién cambió
    Cuando Cambia una variable enviando, además, otro correo como autor del cambio
    Entonces El historial muestra su propio correo; el que vino del navegador se ignora

  # Reglas que este caso verifica:
  #   - Solo el superusuario ve y cambia variables de sistema
  #   - Cada cambio guarda el valor anterior, el nuevo, quién y cuándo
  #   - Volver atrás deja el valor anterior y queda como una entrada más del historial
  #   - Guardar sin cambios no agrega nada al historial
  #   - Se pueden guardar varias variables juntas, cada una con su historial
  #   - Un cambio que falla no deja ni el valor ni el historial a medias
  #   - Quién hizo el cambio sale de la sesión

  # Datos de prueba:
  #   variable: validez_invitacion_dias
  #   valor_inicial: 7
  #   valor_nuevo: 10
