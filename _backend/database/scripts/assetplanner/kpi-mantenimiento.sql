-- ============================================================================
-- AssetPlanner (MariaDB) — Indicadores de mantenimiento para el Tablero de Tools (MIG-ASSET, tablero de KPIs).
--
-- Objetivo: dejar en `kpi_cache`, por empresa y mes, los indicadores que la pantalla "Rep Equipo" de asset
-- (Kpi/disponibilidadKpi) muestra además de la disponibilidad: MTTR, MTTF, MTBF y confiabilidad. El tablero de
-- tools los lee con ToolsKPIDataService (getManKPI, promedio de los meses cacheados).
--
-- Se ejecuta CONECTADO A LA BASE DE ASSETPLANNER (MariaDB), schema de la instalación (dev: assetv2). Es idempotente.
--
-- Cómo calcula asset (Kpi.php, por mes, todos los equipos de la empresa):
--   equipos = cantidad de equipos con historial; total = horas laborales del mes * equipos
--   reparacion = tiempo total en reparación; activo = total - reparacion; fallas = cantidad de fallas
--   MTTR = reparacion / fallas (0 sin fallas); MTTF = activo / fallas (activo sin fallas); MTBF = MTTR + MTTF;
--   confiabilidad = MTBF / (MTBF + MTTR) * 100 (0 si MTBF y MTTR son 0).  Sin equipos todo da 0.
--
-- Los cuatro nuevos se calculan DESDE kpi_cache (las tres consultas base de abajo), así que el procedimiento
-- kpi_calcular_queries_cacheados las recorre antes (el cursor va por nombre: 'get...' antes que 'man_...').
-- Binding de MENSUAL: 5 '?' = (fecha_inicio, fecha_fin, fecha_inicio, fecha_fin, id_empresa).
-- ============================================================================

-- Consultas base (ya existían, estaban deshabilitadas)
UPDATE kpi_queries_a_cachear SET habilitado = 1
 WHERE nombre IN ('getCantEquiposxEmpresaxSectorxGrupo', 'getCantidadFallos', 'getTiempoTotalReparacion');

-- Tiempo medio de reparación (MTTR), en horas: tiempo en reparación / cantidad de fallas
INSERT INTO kpi_queries_a_cachear (nombre, query, periodicidad, periodos_a_cachear, habilitado)
VALUES ('man_mttr', 'SELECT IFNULL((SELECT IF(e.valor = 0 OR f.valor = 0, 0, ROUND(r.valor / f.valor, 2)) FROM (SELECT count_labourdays(STR_TO_DATE(CONCAT(?, '' 00:00:00''), ''%Y-%m-%d %H:%i:%s''), STR_TO_DATE(CONCAT(?, '' 23:59:59''), ''%Y-%m-%d %H:%i:%s'')) AS lab) t JOIN kpi_cache e ON e.nombre = ''getCantEquiposxEmpresaxSectorxGrupo'' JOIN kpi_cache f ON f.nombre = ''getCantidadFallos'' AND f.empr_id = e.empr_id AND f.periodo = e.periodo JOIN kpi_cache r ON r.nombre = ''getTiempoTotalReparacion'' AND r.empr_id = e.empr_id AND r.periodo = e.periodo WHERE e.periodo = DATE_FORMAT(?, ''%Y%m'') AND ? IS NOT NULL AND e.empr_id = ?), 0) AS valor', 'MENSUAL', 12, 1)
ON DUPLICATE KEY UPDATE query = VALUES(query), periodicidad = VALUES(periodicidad),
  periodos_a_cachear = VALUES(periodos_a_cachear), habilitado = VALUES(habilitado);

-- Tiempo medio hasta la falla (MTTF), en horas: tiempo activo / cantidad de fallas
INSERT INTO kpi_queries_a_cachear (nombre, query, periodicidad, periodos_a_cachear, habilitado)
VALUES ('man_mttf', 'SELECT IFNULL((SELECT IF(e.valor = 0, 0, IF(f.valor = 0, ROUND(t.lab * e.valor - r.valor), ROUND((t.lab * e.valor - r.valor) / f.valor, 2))) FROM (SELECT count_labourdays(STR_TO_DATE(CONCAT(?, '' 00:00:00''), ''%Y-%m-%d %H:%i:%s''), STR_TO_DATE(CONCAT(?, '' 23:59:59''), ''%Y-%m-%d %H:%i:%s'')) AS lab) t JOIN kpi_cache e ON e.nombre = ''getCantEquiposxEmpresaxSectorxGrupo'' JOIN kpi_cache f ON f.nombre = ''getCantidadFallos'' AND f.empr_id = e.empr_id AND f.periodo = e.periodo JOIN kpi_cache r ON r.nombre = ''getTiempoTotalReparacion'' AND r.empr_id = e.empr_id AND r.periodo = e.periodo WHERE e.periodo = DATE_FORMAT(?, ''%Y%m'') AND ? IS NOT NULL AND e.empr_id = ?), 0) AS valor', 'MENSUAL', 12, 1)
ON DUPLICATE KEY UPDATE query = VALUES(query), periodicidad = VALUES(periodicidad),
  periodos_a_cachear = VALUES(periodos_a_cachear), habilitado = VALUES(habilitado);

-- Tiempo medio entre fallas (MTBF) = MTTR + MTTF, en horas
INSERT INTO kpi_queries_a_cachear (nombre, query, periodicidad, periodos_a_cachear, habilitado)
VALUES ('man_mtbf', 'SELECT IFNULL((SELECT ROUND(IF(e.valor = 0 OR f.valor = 0, 0, ROUND(r.valor / f.valor, 2)) + IF(e.valor = 0, 0, IF(f.valor = 0, ROUND(t.lab * e.valor - r.valor), ROUND((t.lab * e.valor - r.valor) / f.valor, 2))), 2) FROM (SELECT count_labourdays(STR_TO_DATE(CONCAT(?, '' 00:00:00''), ''%Y-%m-%d %H:%i:%s''), STR_TO_DATE(CONCAT(?, '' 23:59:59''), ''%Y-%m-%d %H:%i:%s'')) AS lab) t JOIN kpi_cache e ON e.nombre = ''getCantEquiposxEmpresaxSectorxGrupo'' JOIN kpi_cache f ON f.nombre = ''getCantidadFallos'' AND f.empr_id = e.empr_id AND f.periodo = e.periodo JOIN kpi_cache r ON r.nombre = ''getTiempoTotalReparacion'' AND r.empr_id = e.empr_id AND r.periodo = e.periodo WHERE e.periodo = DATE_FORMAT(?, ''%Y%m'') AND ? IS NOT NULL AND e.empr_id = ?), 0) AS valor', 'MENSUAL', 12, 1)
ON DUPLICATE KEY UPDATE query = VALUES(query), periodicidad = VALUES(periodicidad),
  periodos_a_cachear = VALUES(periodos_a_cachear), habilitado = VALUES(habilitado);

-- Confiabilidad, en %: MTBF / (MTBF + MTTR) * 100 (misma fórmula que la pantalla Rep Equipo de asset)
INSERT INTO kpi_queries_a_cachear (nombre, query, periodicidad, periodos_a_cachear, habilitado)
VALUES ('man_confiabilidad', 'SELECT IFNULL((SELECT IF(e.valor = 0 OR (ROUND(IF(e.valor = 0 OR f.valor = 0, 0, ROUND(r.valor / f.valor, 2)) + IF(e.valor = 0, 0, IF(f.valor = 0, ROUND(t.lab * e.valor - r.valor), ROUND((t.lab * e.valor - r.valor) / f.valor, 2))), 2) = 0 AND IF(e.valor = 0 OR f.valor = 0, 0, ROUND(r.valor / f.valor, 2)) = 0), 0, ROUND(ROUND(IF(e.valor = 0 OR f.valor = 0, 0, ROUND(r.valor / f.valor, 2)) + IF(e.valor = 0, 0, IF(f.valor = 0, ROUND(t.lab * e.valor - r.valor), ROUND((t.lab * e.valor - r.valor) / f.valor, 2))), 2) / (ROUND(IF(e.valor = 0 OR f.valor = 0, 0, ROUND(r.valor / f.valor, 2)) + IF(e.valor = 0, 0, IF(f.valor = 0, ROUND(t.lab * e.valor - r.valor), ROUND((t.lab * e.valor - r.valor) / f.valor, 2))), 2) + IF(e.valor = 0 OR f.valor = 0, 0, ROUND(r.valor / f.valor, 2))) * 100, 2)) FROM (SELECT count_labourdays(STR_TO_DATE(CONCAT(?, '' 00:00:00''), ''%Y-%m-%d %H:%i:%s''), STR_TO_DATE(CONCAT(?, '' 23:59:59''), ''%Y-%m-%d %H:%i:%s'')) AS lab) t JOIN kpi_cache e ON e.nombre = ''getCantEquiposxEmpresaxSectorxGrupo'' JOIN kpi_cache f ON f.nombre = ''getCantidadFallos'' AND f.empr_id = e.empr_id AND f.periodo = e.periodo JOIN kpi_cache r ON r.nombre = ''getTiempoTotalReparacion'' AND r.empr_id = e.empr_id AND r.periodo = e.periodo WHERE e.periodo = DATE_FORMAT(?, ''%Y%m'') AND ? IS NOT NULL AND e.empr_id = ?), 0) AS valor', 'MENSUAL', 12, 1)
ON DUPLICATE KEY UPDATE query = VALUES(query), periodicidad = VALUES(periodicidad),
  periodos_a_cachear = VALUES(periodos_a_cachear), habilitado = VALUES(habilitado);
