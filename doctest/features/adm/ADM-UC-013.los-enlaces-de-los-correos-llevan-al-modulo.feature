# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/adm/ADM-UC-013.yaml (versión 1.0, validado 2026-11-20).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@adm @ADM-UC-013
Característica: Los enlaces de los correos llevan al módulo

  Quién lo hace: Visitante
  Dónde: Registro Nuevo Usuario del módulo → correo 'Activar cuenta en Trazalog.com' → Establecer Contraseña · Recuperar Contraseña del módulo → correo de recuperación → Restablecer Contraseña

  Antecedentes:
    Dado Sin sesión iniciada
    Y Casilla de correo descartable de DocTest para recibir los correos

  Escenario: Camino principal
    Cuando Se registra por el registro del módulo con una casilla descartable
    Entonces Llega el correo 'Activar cuenta en Trazalog.com', enviado por register@trazalog.com, y el enlace 'Activar mi cuenta' apunta a la dirección del módulo (traz-comp-adm/main/complete/token/...)
    Y cuando Abre el enlace del correo
    Entonces Se muestra 'Establecer Contraseña' del módulo, con el nombre y el correo de la cuenta
    Y cuando Con la cuenta ya activa, pide recuperar la contraseña desde 'Recupere contraseña' del módulo
    Entonces Llega el correo de recuperación y su enlace apunta a la dirección del módulo (traz-comp-adm/main/reset_password/token/...)
    Y cuando Abre el enlace y define una contraseña nueva
    Entonces Se muestra que la contraseña se actualizó y puede ingresar con ella por el módulo y también por DNATO

  Escenario: Registro por DNATO
    Cuando Se registra por el registro de DNATO, como hoy
    Entonces El enlace del correo sigue apuntando a DNATO: no se redirige nada

  Escenario: Correo de bienvenida de la empresa
    Cuando Termina el alta de la empresa por el módulo
    Entonces Llega el correo de bienvenida y todo enlace que trae apunta al módulo, no a DNATO

  Escenario: Enlace del módulo abierto en DNATO
    Cuando Cambia en el enlace de recuperación del módulo la dirección del módulo por la de DNATO y lo abre
    Entonces DNATO acepta el mismo enlace, porque las dos usan la misma tabla de enlaces

  # Reglas que este caso verifica:
  #   - Los enlaces de activar cuenta y de restablecer contraseña que manda el módulo llevan al módulo
  #   - Los correos que manda DNATO no cambian
  #   - Los correos salen por el mismo envío del servidor que DNATO, con el mismo remitente
  #   - Todo enlace de cualquier correo del módulo apunta al módulo
  #   - Una cuenta activada o una contraseña cambiada por el módulo sirve igual en DNATO

  # Datos de prueba:
  #   casilla: casilla descartable del seed de DocTest (la misma que usa DNATO-UC-002)
