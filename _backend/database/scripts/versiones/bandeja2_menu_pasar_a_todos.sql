-- =============================================================================
-- Pasar a TODOS los usuarios a la bandeja de entrada 2 (traz-comp-bpm/Proceso2)
-- =============================================================================
-- Ver doc/v3/bandeja-paginado-real.md (etapa 4, paso 4B).
--
-- Qué hace:
--   1) El ítem de menú "Mis Tareas" (PRD / tareas) pasa a abrir la bandeja 2.
--   2) Borra el ítem de prueba "Mis Tareas 2 (prueba)" y su permiso (los creó bandeja2_menu_prueba.sql).
-- No toca a qué usuarios se les muestra "Mis Tareas": sigue igual que antes.
--
-- Dónde se ejecuta: en la base de Tools del ambiente (la de ToolsDataSource), con psql. Ejemplo:
--   psql -h <host base Tools> -U postgres -d <base Tools> -v ON_ERROR_STOP=1 \
--     -f _backend/database/scripts/versiones/bandeja2_menu_pasar_a_todos.sql
--
-- Para volver atrás (deja "Mis Tareas" apuntando a la bandeja vieja):
--   UPDATE seg.menues SET url = 'traz-comp-bpm/Proceso' WHERE modulo = 'PRD' AND opcion = 'tareas';
-- =============================================================================

BEGIN;

UPDATE seg.menues
   SET url = 'traz-comp-bpm/Proceso2'
 WHERE modulo = 'PRD' AND opcion = 'tareas' AND url = 'traz-comp-bpm/Proceso';

DELETE FROM seg.memberships_users  WHERE role = 'Prueba Bandeja 2';
DELETE FROM seg.memberships_menues WHERE modulo = 'PRD' AND opcion = 'tareas2';
DELETE FROM seg.menues             WHERE modulo = 'PRD' AND opcion = 'tareas2';

COMMIT;

-- Verificación: "Mis Tareas" tiene que decir traz-comp-bpm/Proceso2 y no tiene que quedar "tareas2"
SELECT modulo, opcion, texto, url FROM seg.menues WHERE modulo = 'PRD' AND opcion IN ('tareas', 'tareas2');
