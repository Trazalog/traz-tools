-- KPI MAN "Disponibilidad de equipos" — origen AssetPlanner (MariaDB assetv2).
--
-- Objetivo: replicar en SQL la disponibilidad que AssetPlanner calcula en PHP
-- (Kpi.php::calcularDisponibilidad = tiempoActivo / tiempoTotal * 100, recorriendo
-- historial_lecturas por transiciones de estado AC/RE). Validado: da ~65% para la
-- empresa 8, coherente con el ~64% que muestra la pantalla de KPIs de AssetPlanner.
--
-- CÓMO SE USA EN EL TABLERO:
--   El motor de caché de Tools (schema kpi.*, Postgres) NO puede consultar MariaDB. Por eso
--   este KPI se calcula acá (AssetPlanner) y su resultado se ESCRIBE en kpi.cache de Postgres,
--   de donde lo lee el ToolsKPIDataService como cualquier otro KPI. Falta un job periódico que
--   corra esta query por empresa y haga el UPSERT en kpi.cache (hoy se cargó a mano para demo).
--
-- Parámetros: :id_empresa (id de AssetPlanner = core.empresas.empr_id_mysql), :fi, :ff (rango).
-- Nota MariaDB 10.1: sin window functions -> el "siguiente estado" va por subconsulta correlacionada.
-- Nota: se filtran fechas inválidas (0000-00-00), equipos dados de baja ('AN') y lecturas obs=1
--       (mantenimientos que no cambian el estado del equipo, igual que el PHP).

SELECT ROUND(AVG(disp), 2) AS disponibilidad_pct
FROM (
    SELECT hl.id_equipo,
        LEAST(100, GREATEST(0,
            SUM(CASE WHEN hl.estado = 'AC'
                     THEN TIMESTAMPDIFF(MINUTE, hl.fecha,
                            COALESCE((SELECT MIN(h2.fecha)
                                      FROM historial_lecturas h2
                                      WHERE h2.id_equipo = hl.id_equipo
                                        AND h2.fecha > hl.fecha
                                        AND h2.fecha > '2000-01-01'
                                        AND COALESCE(h2.obs, 0) <> 1), :ff))
                     ELSE 0 END) * 100.0
            / NULLIF(TIMESTAMPDIFF(MINUTE, MIN(hl.fecha), :ff), 0)
        )) AS disp
    FROM historial_lecturas hl
    JOIN equipos e ON e.id_equipo = hl.id_equipo AND e.estado <> 'AN'
    WHERE e.id_empresa = :id_empresa
      AND hl.fecha > '2000-01-01'
      AND hl.fecha < :ff
      AND COALESCE(hl.obs, 0) <> 1
    GROUP BY hl.id_equipo
) t;

-- Luego, el UPSERT en Postgres (tools) que consume el tablero:
--   INSERT INTO kpi.cache(nombre, empr_id, valor, valor_json, calculado_en, vence_en)
--   VALUES ('man_disponibilidad', <empr_id_tools>, <disp>,
--           jsonb_build_object('disponibilidad', <disp>, 'periodo', 'Últimos 12 meses'),
--           now(), now() + interval '1 day')
--   ON CONFLICT (nombre, empr_id) DO UPDATE
--     SET valor = excluded.valor, valor_json = excluded.valor_json,
--         calculado_en = excluded.calculado_en, vence_en = excluded.vence_en;
