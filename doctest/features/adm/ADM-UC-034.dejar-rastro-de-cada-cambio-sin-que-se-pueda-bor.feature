# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/adm/ADM-UC-034.yaml (versión 1.0, validado 2026-11-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/adm/ADM-UC-034.auditoria-inmutable.spec.ts

@adm @ADM-UC-034
Característica: Dejar rastro de cada cambio sin que se pueda borrar

  Quién lo hace: Superusuario
  Dónde: Consola → Variables de sistema

  Antecedentes:
    Dado Usuario con sesión iniciada en Tools y la marca de superusuario
    Y El script de base corrió en el ambiente

  Escenario: Camino principal
    Cuando Cambia contacto_soporte en Variables de sistema y guarda
    Entonces Queda una fila de auditoría con la fecha, su correo, la acción 'variable de sistema', la clave y el valor anterior y nuevo
    Y cuando Vuelve contacto_soporte al valor anterior desde 'Historial'
    Entonces Queda otra fila de auditoría, separada de la primera

  Escenario: Intento de modificar una fila
    Cuando Con el usuario de base de datos que usa la aplicación, se intenta cambiar el detalle de una fila de auditoría
    Entonces La base lo rechaza y la fila queda igual

  Escenario: Intento de borrar una fila
    Cuando Con el usuario de base de datos que usa la aplicación, se intenta borrar una fila de auditoría
    Entonces La base lo rechaza y la fila sigue estando

  Escenario: No hay forma desde el sistema
    Cuando Se buscan, en el servicio de datos del módulo, operaciones para cambiar o borrar la auditoría
    Entonces No existe ninguna: solo la de agregar

  Escenario: Un cambio que falla
    Cuando Guarda una variable mientras el servicio de datos no responde
    Entonces No queda fila de auditoría de un cambio que no se hizo

  # Reglas que este caso verifica:
  #   - Cada cambio y cada vuelta atrás de una variable de sistema deja su fila de auditoría
  #   - La base rechaza modificar filas de auditoría
  #   - La base rechaza borrar filas de auditoría
  #   - El sistema no ofrece ninguna operación para cambiar o borrar la auditoría
  #   - No hay fila de auditoría de un cambio que no se guardó

  # Datos de prueba:
  #   variable: contacto_soporte
