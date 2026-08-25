# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/dnato/DNATO-UC-019.yaml (versión 0.4, validado 2026-08-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@dnato @DNATO-UC-019
Característica: Cambiar el perfil de un usuario en DNATO

  Quién lo hace: Administrador
  Dónde: Gestión de Usuarios → Lista de Usuarios → Asignar Rol · Cambio de Rol — campo Perfil

  Antecedentes:
    Dado Sesión iniciada con perfil Administrador

  Escenario: Camino principal
    Cuando Abre 'Asignar Rol' sobre un usuario
    Entonces Se muestra el perfil actual del usuario en el campo Perfil
    Y cuando Elige el otro perfil y guarda
    Entonces El perfil queda cambiado y la columna 'Nivel de Usuario' de la lista lo refleja

  Escenario: No se puede actualizar
    Cuando Guarda cuando la actualización falla
    Entonces Se muestra el error y el perfil no cambia

  # Reglas que este caso verifica:
  #   - El perfil administrador habilita Gestión de Usuarios, Gestión de Menúes, Carga Masiva y Configuración; el perfil no administrador solo da acceso a los datos propios del usuario
  #   - El perfil de DNATO es independiente de los roles de trabajo de cada empresa (DNATO-UC-018): el perfil dice qué puede administrar, el rol dice qué puede hacer en la operación

  # ⚠️ Atención al ejecutarlo:
  #   Nomenclatura resuelta (decisión del PM, 2026-08-24): el catálogo y las ayudas usan el lenguaje de negocio — **Administrador** y **Usuario** — mientras que los datos siguen diciendo `Admin` y `Author`. El renombre de los datos queda anotado como mejora futura (hallazgo H-015), no se toca ahora.
