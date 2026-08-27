# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-017.yaml (versión 0.3, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/dnato/DNATO-UC-017.eliminar-usuario.spec.ts

@dnato @DNATO-UC-017
Característica: Eliminar un usuario de la empresa

  Quién lo hace: Administrador
  Dónde: Gestión de Usuarios → Lista de Usuarios → Eliminar Usuario

  Antecedentes:
    Dado Sesión iniciada con perfil Administrador
    Y El usuario a eliminar no tiene roles de trabajo asignados en esa empresa

  Escenario: Camino principal
    Cuando Elige 'Eliminar Usuario' sobre un usuario sin roles asignados
    Entonces Se pide confirmación antes de hacer nada
    Y cuando Confirma
    Entonces Se muestra 'Eliminado Correctamente.' y el usuario desaparece de la lista

  Escenario: El usuario todavía tiene roles asignados
    Cuando Elige 'Eliminar Usuario' sobre un usuario con roles en la empresa
    Entonces Se muestra 'Error, Este usuario tiene roles de sistema en la empresa asignados!' y no se elimina

  Escenario: Cancelar la confirmación
    Cuando Elige 'Eliminar Usuario' y cancela en el pedido de confirmación
    Entonces No se elimina nada y el usuario sigue en la lista

  Escenario: No se puede desvincular de la empresa
    Cuando Confirma la eliminación cuando falla la baja del vínculo con la empresa
    Entonces Se muestra el error indicando el correo del usuario y no se elimina

  # Reglas que este caso verifica:
  #   - Un usuario con roles de trabajo asignados en la empresa no puede eliminarse: primero hay que quitarle los roles (DNATO-UC-018)
  #   - La acción pide confirmación antes de ejecutarse
  #   - La baja es lógica: el usuario deja de operar pero se conserva, porque borrarlo rompería la trazabilidad de lo que hizo

  # ⚠️ Atención al ejecutarlo:
  #   Validado por el PM el 2026-08-24 con una definición fuerte: **nunca debe existir un borrado definitivo, porque rompe la trazabilidad**. El borrado físico que hace hoy el sistema es un bug a corregir (H-002, issue #451). El caso describe el comportamiento esperado, no el actual: sus derivados se generan recién cuando el borrado sea lógico.
