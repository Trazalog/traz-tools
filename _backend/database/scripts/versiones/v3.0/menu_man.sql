-- v3.0 — Opciones del menú de Mantenimiento (módulo MAN) en seg.menues (paso 7 del despliegue).
--
-- Qué hace: deja en seg.menues las 31 opciones MAN tal como están en desarrollo (tools_prod_t, leído el
-- 2026-11-17): las 14 que ya existían desde 2024 con su dirección nueva de traz-tools-man, y las 17 que
-- agregó la migración (Bandeja de Tareas, los reportes y el submenú "ABM de Mantenimiento").
-- Si una opción ya existe, actualiza texto, dirección, orden, ícono y padre, y la deja habilitada; si no
-- existe, la crea. No toca seg.memberships_menues: quién ve cada opción lo asigna el alta de empresa
-- (v2.8.1.7/configuracion_inicial_empresa_trg_func.sql) a las empresas nuevas. Ver doc/migracion/MENU-MAN.md.
--
-- Antes de cambiar nada guarda una copia de las filas MAN en seg.menues_bk_man_v30 (solo la primera vez).
-- Es idempotente: se puede correr más de una vez.
--
-- Dónde se ejecuta: en una terminal con psql, conectada a la base de tools del ambiente (la de
-- ToolsDataSource). Ejemplo:
--   psql -h <host> -U <usuario> -d <base> -v ON_ERROR_STOP=1 -f _backend/database/scripts/versiones/v3.0/menu_man.sql
--
-- Para deshacer (restaura las filas MAN como estaban antes de la primera corrida):
--   BEGIN;
--   DELETE FROM seg.menues WHERE modulo = 'MAN' AND opcion_padre IS NOT NULL;
--   DELETE FROM seg.menues WHERE modulo = 'MAN';
--   INSERT INTO seg.menues SELECT * FROM seg.menues_bk_man_v30 WHERE opcion_padre IS NULL;
--   INSERT INTO seg.menues SELECT * FROM seg.menues_bk_man_v30 WHERE opcion_padre IS NOT NULL;
--   COMMIT;
--   (Si alguna opción nueva ya está asignada en seg.memberships_menues y hay una FK, borrar esas filas antes.)

BEGIN;

CREATE TABLE IF NOT EXISTS seg.menues_bk_man_v30 AS
SELECT * FROM seg.menues WHERE modulo = 'MAN';

-- Primero las opciones padre (mantenimiento, abm_man) y después las hijas, por la FK de opcion_padre.
INSERT INTO seg.menues (modulo, opcion, opcion_padre, texto, url, javascript, orden, url_icono, texto_onmouseover, eliminado, usuario_app)
SELECT 'MAN', v.opcion, v.opcion_padre, v.texto, v.url, v.javascript, v.orden, v.url_icono, v.texto_onmouseover, 0, 'migracion-man'
FROM (VALUES
  ('mantenimiento', NULL, 'Mantenimiento', NULL, NULL, 100, 'fa fa-sign-language', NULL),
  ('abm_man', NULL, 'ABM de Mantenimiento', NULL, NULL, 300, NULL, NULL),
  ('abm_area', 'abm_man', 'Área', 'traz-tools-man/Area/index/Add-Edit-Del', NULL, 310, NULL, NULL),
  ('abm_proceso', 'abm_man', 'Procesos', 'traz-tools-man/Proceso/index/Add-Edit-Del', NULL, 320, NULL, NULL),
  ('abm_grupo', 'abm_man', 'Grupo', 'traz-tools-man/Grupo/index/Add-Edit-Del', NULL, 330, NULL, NULL),
  ('abm_sector', 'abm_man', 'Sector', 'traz-tools-man/Sector/index/Add-Edit-Del', NULL, 340, NULL, NULL),
  ('abm_contratista', 'abm_man', 'Contratista', 'traz-tools-man/Contratista/index/Add-Edit-Del', NULL, 350, NULL, NULL),
  ('abm_tarea_estandar', 'abm_man', 'Tareas estándar', 'traz-tools-man/Tareaestandar/index/Add-Edit-Del', NULL, 360, NULL, NULL),
  ('abm_parametros', 'abm_man', 'Parámetros', 'traz-tools-man/Altparametro/index/Add-Edit-Del', NULL, 370, NULL, NULL),
  ('abm_familia', 'abm_man', 'Familia', 'traz-tools-man/Family/index/Add-Edit-Del', NULL, 380, NULL, NULL),
  ('abm_marca', 'abm_man', 'Marca', 'traz-tools-man/Marca/index/Add-Edit-Del', NULL, 390, NULL, NULL),
  ('abm_clientes', 'abm_man', 'Clientes', 'traz-tools-man/Cliente/index/Add-Edit-Del', NULL, 400, NULL, NULL),
  ('abm_criticidad', 'abm_man', 'Criticidad', 'traz-tools-man/Criticidad/index/Add-Edit-Del', NULL, 410, NULL, NULL),
  ('abm_sucursales', 'abm_man', 'Sucursales', 'traz-tools-man/Sucursal/index/Add-Edit-Del', NULL, 420, NULL, NULL),
  ('abm_sistemas', 'abm_man', 'Sistemas', 'traz-tools-man/SistemaABM/index/Add-Edit-Del', NULL, 430, NULL, NULL),
  ('equipos', 'mantenimiento', 'Equipos', 'traz-tools-man/Equipo/index/Add-Edit-Del-Lectura', NULL, 100, 'fa fa-circle-o', NULL),
  ('bandeja', 'mantenimiento', 'Bandeja de Tareas', 'traz-tools-man/Tarea/index/Add-Edit-Del', '', 105, 'fa fa-circle-o', ''),
  ('componentes', 'mantenimiento', 'Componentes', 'traz-tools-man/Componente/asigna/Add-Edit-Del', NULL, 110, 'fa fa-circle-o', NULL),
  ('solicitud_servicio', 'mantenimiento', 'Solicitud de Servicio', 'traz-tools-man/Sservicio/index/Add-Edit-Del', NULL, 120, 'fa fa-circle-o', NULL),
  ('informe_servicios', 'mantenimiento', 'Informe de Servicios', 'traz-tools-man/Ordenservicio/index/Add-Edit-Del', NULL, 130, 'fa fa-circle-o', NULL),
  ('preventivo', 'mantenimiento', 'Preventivo', 'traz-tools-man/Preventivo/index/Add-Edit-Del', NULL, 140, 'fa fa-circle-o', NULL),
  ('parametrizar_predictivo', 'mantenimiento', 'Parametrizar Predictivo', 'traz-tools-man/Parametro/index/Add-Edit-Del', NULL, 150, 'fa fa-circle-o', NULL),
  ('backlog', 'mantenimiento', 'Backlog', 'traz-tools-man/Backlog/index/Add-Edit-Del', NULL, 160, 'fa fa-circle-o', NULL),
  ('predictivo', 'mantenimiento', 'Predictivo', 'traz-tools-man/Predictivo/index/Add-Edit-Del', NULL, 170, 'fa fa-circle-o', NULL),
  ('ordenes_trabajo', 'mantenimiento', 'Ordenes de Trabajo', 'traz-tools-man/Otrabajo/listOrden/Add-Edit-Del', NULL, 180, 'fa fa-circle-o', NULL),
  ('plan_mantenimiento', 'mantenimiento', 'Plan de Mantenimiento', 'traz-tools-man/Calendario/indexot/Add-Edit-Del', NULL, 190, 'fa fa-circle-o', NULL),
  ('registro_parametros', 'mantenimiento', 'Registro de Parametros', 'traz-tools-man/Lectura/index/Add-Edit-Del', NULL, 200, 'fa fa-circle-o', NULL),
  ('administrar_ordenes', 'mantenimiento', 'Administrar Ordenes', 'traz-tools-man/Envio/index/Add-Edit-Del', NULL, 210, 'fa fa-circle-o', NULL),
  ('rep_equipo', 'mantenimiento', 'Rep Equipo', 'traz-tools-man/Kpi/index/Add-Edit-Del', NULL, 220, NULL, NULL),
  ('rep_informe_servicios', 'mantenimiento', 'Rep Informe de Servicios', 'traz-tools-man/Reporte/index/Add-Edit-Del', NULL, 230, NULL, NULL),
  ('rep_ordenes_trabajo', 'mantenimiento', 'Rep Ordenes de trabajo', 'traz-tools-man/Reporteorden/index/Add-Edit-Del', NULL, 240, NULL, NULL)
) AS v(opcion, opcion_padre, texto, url, javascript, orden, url_icono, texto_onmouseover)
ORDER BY (v.opcion_padre IS NOT NULL)
ON CONFLICT (modulo, opcion) DO UPDATE SET
  opcion_padre = EXCLUDED.opcion_padre,
  texto        = EXCLUDED.texto,
  url          = EXCLUDED.url,
  orden        = EXCLUDED.orden,
  url_icono    = EXCLUDED.url_icono,
  eliminado    = 0;

COMMIT;

-- Verificación: tiene que dar 31 filas habilitadas, con mantenimiento y abm_man como padres.
SELECT opcion_padre, count(*) AS opciones FROM seg.menues
WHERE modulo = 'MAN' AND eliminado = 0
GROUP BY opcion_padre ORDER BY opcion_padre NULLS FIRST;
