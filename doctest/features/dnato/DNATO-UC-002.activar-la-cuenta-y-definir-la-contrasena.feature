# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-002.yaml (versión 0.4, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@dnato @DNATO-UC-002
Característica: Activar la cuenta y definir la contraseña

  Quién lo hace: Visitante
  Dónde: Correo 'Activar cuenta en Trazalog.com' → 'Activar mi cuenta' · Establecer Contraseña

  Antecedentes:
    Dado Existe una cuenta registrada sin contraseña (DNATO-UC-001)
    Y El enlace de activación se usa el mismo día en que se generó

  Escenario: Camino principal
    Cuando Abre el enlace de activación recibido por correo
    Entonces Se muestra la pantalla para establecer la contraseña, con el nombre y el correo de la cuenta
    Y cuando Ingresa la contraseña y su confirmación, y confirma
    Entonces La cuenta queda activa, se crea el usuario en el sistema de procesos y en Asset Planner, se inicia sesión y se continúa con el formulario de datos de registro

  Escenario: Enlace ya usado o de otro día
    Cuando Abre un enlace de activación inválido, o uno generado un día anterior
    Entonces Se muestra 'Token invalido o expirado...' y se vuelve a la pantalla de ingreso

  Escenario: Contraseña que no cumple la política
    Cuando Ingresa 'doctest2026' (10 caracteres, sin mayúscula ni símbolo)
    Entonces Se muestra el error de contraseña y la cuenta no se activa

  Escenario: Confirmación distinta
    Cuando Ingresa una confirmación que no coincide con la contraseña
    Entonces Se muestra el error de coincidencia y la contraseña no se guarda

  Escenario: La sincronización con el sistema de procesos falla
    Cuando Confirma la contraseña cuando el servicio de procesos no responde
    Entonces La cuenta queda activada igual y se avisa que no se pudo sincronizar, invitando a continuar

  # Reglas que este caso verifica:
  #   - La contraseña exige 10 caracteres o más, al menos una mayúscula, una minúscula, un dígito y un carácter no alfanumérico
  #   - La confirmación debe coincidir con la contraseña
  #   - El enlace de activación es de un solo uso y vence a la medianoche del día en que se generó

  # Datos de prueba:
  #   password_valida: Doctest2026!
  #   password_invalida_sin_simbolo: Doctest2026
  #   password_invalida_corta: Doct2026!
