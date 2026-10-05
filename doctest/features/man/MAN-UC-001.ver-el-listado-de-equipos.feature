# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/man/MAN-UC-001.yaml (versión 0.1, validado 2026-08-26).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/man/MAN-UC-001.listado-equipos.spec.ts

@man @MAN-UC-001
Característica: Ver el listado de equipos

  Quién lo hace: Supervisor
  Dónde: Mantenimiento → Equipos

  Antecedentes:
    Dado Sesión iniciada en AssetPlanner
    Y La empresa tiene equipos cargados

  Escenario: Camino principal
    Cuando Entra a Mantenimiento → Equipos
    Entonces Se muestra la grilla con las columnas Acciones, Código Equipo, Descripción, Área, Proceso, Sector, Criticidad, Cliente y Estado
    Y cuando Busca un equipo por su código o su descripción
    Entonces La grilla se reduce a los equipos que coinciden
    Y cuando Mira la columna Acciones de una fila
    Entonces Se ofrecen las once acciones que se pueden hacer sobre ese equipo, cada una con su caso propio: editar (MAN-UC-003), eliminar (MAN-UC-004), habilitar o inhabilitar (MAN-UC-022), asignar contratistas (MAN-UC-023), registrar una lectura o reportar una falla (MAN-UC-024), ver el historial de lecturas (MAN-UC-025), asignar una meta (MAN-UC-026) y adjuntar documentación (MAN-UC-027)

  # Reglas que este caso verifica:
  #   - La columna Estado distingue los tres estados del equipo: activo, inhabilitado y dado de baja
  #   - El listado solo muestra equipos de la empresa de la sesión
