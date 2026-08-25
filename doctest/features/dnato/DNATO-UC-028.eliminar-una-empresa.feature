# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-028.yaml (versión 0.2, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@dnato @DNATO-UC-028
Característica: Eliminar una empresa

  Quién lo hace: Superusuario
  Dónde: Gestión de Empresas → Lista de Empresas → Eliminar

  Antecedentes:
    Dado Sesión iniciada con el usuario superusuario del ambiente

  Escenario: Camino principal
    Cuando Elige dar de baja una empresa del listado
    Entonces Se pide confirmación antes de hacer nada
    Y cuando Confirma la baja
    Entonces La empresa queda dada de baja y deja de estar disponible para operar, pero se conserva junto con todo su historial

  Escenario: Administrador común
    Cuando Un administrador que no es el superusuario intenta dar de baja una empresa
    Entonces No puede: la acción es exclusiva del superusuario

  # Reglas que este caso verifica:
  #   - La baja es lógica: la empresa y sus datos se conservan, porque borrarlos rompería la trazabilidad
  #   - Solo el superusuario puede dar de baja una empresa

  # ⚠️ Atención al ejecutarlo:
  #   Validado por el PM el 2026-08-24: baja lógica, nunca física, y solo el superusuario. **El caso describe el comportamiento esperado: hoy el sistema hace otra cosa** — ver hallazgo H-028 e issue #462, donde la acción borra un usuario en vez de la empresa. Sus derivados van a fallar hasta que se corrija, que es lo que se espera de una suite de regresión.
