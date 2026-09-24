-- ============================================================================
-- AssetPlanner (MariaDB) — Registro del KPI "Disponibilidad" en el mecanismo de
-- caché periódica de KPIs (kpi_queries_a_cachear + procedure + events).
--
-- Objetivo: que el EVENTO periódico de AssetPlanner calcule la disponibilidad por
-- empresa y mes y la deje en `kpi_cache`, de donde la lee el ToolsKPIDataService
-- (via AssetPlannerDataSource) para el Tablero del Administrador de Tools.
--
-- Se ejecuta CONECTADO A LA BASE DE ASSETPLANNER (MariaDB), en el schema de esa
-- instalación (dev: assetv2). El mecanismo (tablas kpi_*, procedure
-- kpi_calcular_queries_cacheados, events kpi_correr_cache/kpi_actualizar_cache) ya
-- existe en producción; este script SOLO registra la query nueva y asegura los events.
--
-- La query replica en SQL la disponibilidad que AssetPlanner calcula en PHP
-- (Kpi.php::calcularDisponibilidad = tiempoActivo/tiempoTotal*100). Cada lectura en
-- estado 'AC' aporta su solapamiento con el mes [fi,ff] (así el estado heredado de
-- antes del mes cuenta). Binding del procedure para periodicidad MENSUAL: los 5 '?'
-- se bindean en orden (fecha_inicio, fecha_fin, fecha_inicio, fecha_fin, id_empresa).
-- Validado: ~65% para una empresa con datos, coherente con la pantalla de AssetPlanner.
-- ============================================================================

INSERT INTO kpi_queries_a_cachear (nombre, query, periodicidad, periodos_a_cachear, habilitado)
VALUES (
  'getDisponibilidad',
  'select coalesce(round(avg(disp),2),0) as valor from ( select hl.id_equipo, least(100, greatest(0, sum(case when hl.estado = ''AC'' then greatest(0, timestampdiff(minute, greatest(hl.fecha, cast(? as datetime)), least(cast(? as datetime), coalesce((select min(h2.fecha) from historial_lecturas h2 where h2.id_equipo = hl.id_equipo and h2.fecha > hl.fecha and h2.fecha > ''2000-01-01'' and coalesce(h2.obs,0) <> 1), now())))) else 0 end) * 100.0 / nullif(timestampdiff(minute, cast(? as datetime), cast(? as datetime)), 0))) disp from historial_lecturas hl join equipos e on e.id_equipo = hl.id_equipo and e.estado <> ''AN'' where e.id_empresa = ? and hl.fecha > ''2000-01-01'' and coalesce(hl.obs,0) <> 1 group by hl.id_equipo ) t',
  'MENSUAL',
  12,
  1
)
ON DUPLICATE KEY UPDATE query = VALUES(query), periodicidad = VALUES(periodicidad),
  periodos_a_cachear = VALUES(periodos_a_cachear), habilitado = VALUES(habilitado);

-- Asegurar el event que dispara el cálculo. El procedure desplegado escribe DIRECTO a kpi_cache
-- (una sola fase, sin kpi_cache_tmp), así que alcanza con un event que llame al procedure.
-- Requiere event_scheduler = ON (verificar: SHOW VARIABLES LIKE 'event_scheduler';).
-- En prod este event ya existe; IF NOT EXISTS lo hace seguro para ambientes nuevos.
CREATE EVENT IF NOT EXISTS kpi_correr_cache
  ON SCHEDULE EVERY 10 MINUTE
  ON COMPLETION NOT PRESERVE ENABLE
  DO CALL kpi_calcular_queries_cacheados();

-- Para una primera carga inmediata (sin esperar los 10 min del event):
--   CALL kpi_calcular_queries_cacheados();
-- (el procedure ya deja los valores en kpi_cache; NO hay fase tmp).
