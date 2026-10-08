-- =============================================================================
-- Punto de menú "Mis Tareas 2" (bandeja de entrada 2: traz-comp-bpm/Proceso2)
-- habilitado SOLO para un usuario especial de prueba, dentro de una empresa.
-- =============================================================================
-- Ver doc/v3/bandeja-paginado-real.md (sección "Punto de menú").
--
-- Cómo funciona el permiso de menú en Tools: el menú sale de seg.menues y un ítem se muestra si existe
-- una fila en seg.memberships_menues (grupo, rol, modulo, opcion) cuyo grupo+rol el usuario tiene en
-- seg.memberships_users (email, grupo, rol), y el grupo es el de la empresa activa en la sesión.
-- Acá se crea un ROL PROPIO ("Prueba Bandeja 2") solo en esas tablas de Tools, así el ítem lo ve
-- únicamente el usuario especial. Ese rol no existe en Bonita y no cambia qué tareas ve el usuario:
-- las tareas salen de sus memberships de Bonita (las del alta normal del usuario en la empresa).
--
-- Requisito: el usuario especial ya tiene que existir (alta normal en DNATO, con su membership en la empresa).
-- seg.memberships_users tiene FK a seg.users(email): si el usuario no existe, el script falla y no cambia nada.
--
-- Dónde se ejecuta: en la base de Tools del ambiente (la de ToolsDataSource), con psql.
-- Variables (obligatorias):
--   email  = email del usuario especial (el mismo con el que entra a Tools)
--   grupo  = nombre del grupo/empresa tal como figura en seg.memberships_users."group" (ej. 'Yudica')
-- Ejemplo (TEST):
--   psql -h 10.142.0.13 -U postgres -d tools_prod_t -v ON_ERROR_STOP=1 \
--     -v email='prueba.bandeja2@yudica.com.ar' -v grupo='Yudica' \
--     -f _backend/database/scripts/versiones/bandeja2_menu_prueba.sql
--
-- Es aditivo e idempotente. Para revertir (mismas variables):
--   DELETE FROM seg.memberships_users  WHERE email = :'email' AND "group" = :'grupo' AND role = 'Prueba Bandeja 2';
--   DELETE FROM seg.memberships_menues WHERE "group" = :'grupo' AND role = 'Prueba Bandeja 2' AND modulo = 'PRD' AND opcion = 'tareas2';
--   DELETE FROM seg.menues WHERE modulo = 'PRD' AND opcion = 'tareas2';
-- =============================================================================

BEGIN;

-- 1) El ítem de menú, al lado de "Mis Tareas" (PRD / tareas, orden 800)
INSERT INTO seg.menues (modulo, opcion, opcion_padre, texto, url, javascript, orden, url_icono, texto_onmouseover, eliminado, usuario_app)
SELECT 'PRD', 'tareas2', NULL, 'Mis Tareas 2 (prueba)', 'traz-comp-bpm/Proceso2', NULL, 801,
       'fa fa-check-square-o', 'Bandeja de entrada 2: paginado y búsqueda en la base', 0, 'bandeja2'
WHERE NOT EXISTS (SELECT 1 FROM seg.menues WHERE modulo = 'PRD' AND opcion = 'tareas2');

-- 2) El permiso: el ítem se habilita para el rol propio dentro del grupo de la empresa
INSERT INTO seg.memberships_menues (modulo, opcion, "group", role, usuario_app, eliminado)
SELECT 'PRD', 'tareas2', :'grupo', 'Prueba Bandeja 2', 'bandeja2', 0
WHERE NOT EXISTS (SELECT 1 FROM seg.memberships_menues
                  WHERE modulo = 'PRD' AND opcion = 'tareas2' AND "group" = :'grupo' AND role = 'Prueba Bandeja 2');

-- 3) El usuario especial recibe ese rol propio en ese grupo
INSERT INTO seg.memberships_users (email, "group", role, usuario_app)
SELECT :'email', :'grupo', 'Prueba Bandeja 2', 'bandeja2'
WHERE NOT EXISTS (SELECT 1 FROM seg.memberships_users
                  WHERE email = :'email' AND "group" = :'grupo' AND role = 'Prueba Bandeja 2');

COMMIT;

-- Verificación: debe devolver 1 fila con el usuario especial
SELECT * FROM seg.menues_users_vw WHERE modulo = 'PRD' AND opcion = 'tareas2' AND email = :'email';
