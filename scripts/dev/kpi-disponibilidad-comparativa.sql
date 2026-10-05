-- ============================================================================
--  DISPONIBILIDAD: valor actual vs valor saneado
--
--  El calculo de produccion suma tramos con duracion negativa (lecturas cuya
--  "siguiente por id_lectura" tiene fecha anterior, o directamente invalida:
--  anio 0001, 0025, 2092, o vacia). Este script mide cuanto cambia el KPI si
--  se excluyen esos tramos, sin tocar nada mas de la logica.
--
--  SOLO LEE. No modifica datos ni configuracion.
--
--  USO:  mysql -h <host> -u <user> -p <base> < kpi-disponibilidad-comparativa.sql
-- ============================================================================

SET @id_empresa = 6;              -- ajustar a la empresa a analizar
SET @fec_inicio = '2026-07-01';
SET @fec_fin    = '2026-07-31';


-- ---------------------------------------------------------------------------
-- 1. Cuanto pesa la basura en el total
-- ---------------------------------------------------------------------------
SELECT
    COUNT(*)                                                        AS tramos,
    SUM(fecha_fin IS NULL)                                          AS sin_cierre,
    SUM(fecha_fin IS NOT NULL AND fecha_fin < fecha_inicio)         AS invertidos,
    SUM(YEAR(fecha_inicio) < 2000 OR YEAR(fecha_inicio) > YEAR(NOW())+1) AS inicio_fecha_absurda,
    SUM(fecha_fin IS NOT NULL AND (YEAR(fecha_fin) < 2000 OR YEAR(fecha_fin) > YEAR(NOW())+1)) AS fin_fecha_absurda,
    ROUND(100 * SUM(fecha_fin IS NOT NULL AND fecha_fin < fecha_inicio) / COUNT(*), 1) AS pct_invertidos
FROM (
    SELECT hl.fecha AS fecha_inicio,
           (SELECT hl2.fecha FROM historial_lecturas_mem hl2
             WHERE hl2.id_equipo = hl.id_equipo AND hl2.id_lectura > hl.id_lectura
             ORDER BY hl2.id_lectura LIMIT 1) AS fecha_fin
      FROM historial_lecturas_mem hl
      JOIN equipos e ON e.id_equipo = hl.id_equipo
     WHERE e.id_empresa = @id_empresa
) t;


-- ---------------------------------------------------------------------------
-- 2. Disponibilidad ACTUAL vs SANEADA, sobre el mismo periodo
-- ---------------------------------------------------------------------------
--  "actual"  = como lo calcula hoy el DataService (incluye tramos negativos)
--  "saneada" = misma formula, descartando los tramos imposibles:
--                - sin lectura siguiente (tramo abierto)
--                - fin anterior al inicio
--                - fechas fuera de un rango plausible
--  (sin CTE: MariaDB 10.1 no soporta WITH)
SELECT
    ROUND(100 * SUM(CASE WHEN estado='AC' THEN minutos ELSE 0 END)
              / NULLIF(SUM(minutos),0), 2)                       AS disponibilidad_actual,
    ROUND(100 * SUM(CASE WHEN valido=1 AND estado='AC' THEN minutos ELSE 0 END)
              / NULLIF(SUM(CASE WHEN valido=1 THEN minutos ELSE 0 END),0), 2) AS disponibilidad_saneada,
    SUM(minutos)                                                 AS minutos_todos,
    SUM(CASE WHEN valido=1 THEN minutos ELSE 0 END)              AS minutos_validos,
    SUM(CASE WHEN valido=0 THEN minutos ELSE 0 END)              AS minutos_descartados
FROM (
    SELECT t.estado,
           TIMESTAMPDIFF(MINUTE, t.ini,
               IFNULL(t.fin, STR_TO_DATE(CONCAT(@fec_fin,' 23:59:59'), '%Y-%m-%d %H:%i:%s'))
           ) AS minutos,
           CASE WHEN t.fin IS NOT NULL
                 AND t.fin >= t.ini
                 AND YEAR(t.ini) BETWEEN 2000 AND YEAR(NOW())+1
                 AND YEAR(t.fin) BETWEEN 2000 AND YEAR(NOW())+1
                THEN 1 ELSE 0 END AS valido
      FROM (
        SELECT hl.id_lectura, hl.id_equipo, hl.estado, hl.fecha AS ini,
               (SELECT hl2.fecha FROM historial_lecturas_mem hl2
                 WHERE hl2.id_equipo = hl.id_equipo AND hl2.id_lectura > hl.id_lectura
                 ORDER BY hl2.id_lectura LIMIT 1) AS fin
          FROM historial_lecturas_mem hl
          JOIN equipos e ON e.id_equipo = hl.id_equipo
         WHERE e.id_empresa = @id_empresa
      ) t
     WHERE t.ini <= STR_TO_DATE(CONCAT(@fec_fin,' 23:59:59'), '%Y-%m-%d %H:%i:%s')
) acotados;


-- ---------------------------------------------------------------------------
-- 3. De donde salen las lecturas rotas (causa raiz)
-- ---------------------------------------------------------------------------
--  Si casi todas tienen observacion "... | OT: NNNN", las genera el flujo de
--  ordenes de trabajo y no la carga manual de horometro. Ahi hay que corregir.
SELECT
    CASE WHEN observacion LIKE '%| OT:%' THEN 'generada por una OT'
         ELSE 'otra via (carga manual u otro flujo)' END AS origen,
    COUNT(*) AS lecturas_con_fecha_invalida
FROM historial_lecturas hl
JOIN equipos e ON e.id_equipo = hl.id_equipo
WHERE e.id_empresa = @id_empresa
  AND (hl.fecha IS NULL OR YEAR(hl.fecha) < 2000 OR YEAR(hl.fecha) > YEAR(NOW())+1)
GROUP BY origen;


-- ---------------------------------------------------------------------------
-- 4. Cuantos equipos quedan afectados
-- ---------------------------------------------------------------------------
SELECT COUNT(DISTINCT hl.id_equipo) AS equipos_con_lecturas_invalidas,
       (SELECT COUNT(*) FROM equipos WHERE id_empresa=@id_empresa AND estado<>'AN') AS equipos_activos
FROM historial_lecturas hl
JOIN equipos e ON e.id_equipo = hl.id_equipo
WHERE e.id_empresa = @id_empresa
  AND (hl.fecha IS NULL OR YEAR(hl.fecha) < 2000 OR YEAR(hl.fecha) > YEAR(NOW())+1);
