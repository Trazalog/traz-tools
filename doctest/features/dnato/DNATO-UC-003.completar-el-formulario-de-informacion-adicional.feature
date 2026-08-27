# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-003.yaml (versión 0.3, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/dnato/DNATO-UC-002-005.alta-de-empresa.spec.ts

@dnato @DNATO-UC-003
Característica: Completar el formulario de información adicional del registro

  Quién lo hace: Administrador
  Dónde: Información Adicional de Registro

  Antecedentes:
    Dado La cuenta fue activada y hay sesión iniciada (DNATO-UC-002)

  Escenario: Camino principal
    Cuando Después de activar la cuenta, ve el formulario de información adicional
    Entonces Se muestran las cuatro preguntas con sus opciones
    Y cuando Elige cómo se enteró de Trazalog, marca a qué se dedica la empresa, elige la cantidad de empleados, describe sus problemas principales y confirma
    Entonces Las respuestas quedan guardadas y se continúa con el alta de la empresa

  Escenario: Preguntas obligatorias sin responder
    Cuando Confirma sin responder cómo se enteró, a qué se dedica la empresa o cuántos empleados tiene
    Entonces El formulario señala las preguntas obligatorias y no avanza

  Escenario: No se puede preparar el formulario
    Cuando Llega a la pantalla cuando el formulario no se puede generar
    Entonces Se muestra 'No se pudo preparar el formulario de registro. Volvé a iniciar sesión o contactá soporte.'

  # Reglas que este caso verifica:
  #   - '¿Cómo te enteraste de Trazalog?' es obligatoria — opción única: Internet, Referencia de otro usuario, Publicidad
  #   - '¿A qué se dedica tu empresa?' es obligatoria — opción múltiple: Industria, Minería, Agricultura, Ganadería, Reciclado, Tecnología, Militar
  #   - '¿Cuántos empleados tiene tu empresa?' es obligatoria — opción única: 1 a 5, 5 a 20, 20 a 40, Más de 40
  #   - '¿Cuáles son los principales problemas que hoy enfrentas?' es de texto libre y opcional

  # Datos de prueba:
  #   como_enteraste: Internet
  #   actividad_empresa: Minería
  #   cantidad_empleados: 5 a 20

  # ⚠️ Atención al ejecutarlo:
  #   Validado por el PM el 2026-08-24. Hoy las respuestas se guardan y no se usan para nada: la explotación de esos datos va a ser una tool MCP para el superusuario (mejora futura, hallazgo H-022).
