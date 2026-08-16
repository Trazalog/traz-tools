-- ============================================================================
--  DISPONIBILIDAD: separar los 3 efectos y medir el fix de ordenamiento
--
--  El calculo actual cierra cada tramo con la lectura siguiente POR id_lectura.
--  Si las lecturas no se cargaron en orden cronologico, el "fin" del tramo
--  queda antes que el "inicio" y la duracion es negativa.
--
--  Este script separa tres cosas que no son lo mismo:
--    (a) tramos abiertos      -> NO son un error: el calculo los cierra con
--                                 la fecha fin del periodo, que es correcto
--    (b) fechas invalidas     -> error de DATOS (pocos registros)
--    (c) tramos invertidos    -> error de LOGICA (ordenar por id en vez de fecha)
--
--  y compara la disponibilidad actual contra la que da ordenando por fecha.
--
--  SOLO LEE.
-- ============================================================================

SET @id_empresa = 6;
SET @fec_fin    = '2026-07-31';


-- ---------------------------------------------------------------------------
-- 1. Los tres efectos, cuantificados por separado
-- ---------------------------------------------------------------------------
SELECT
    COUNT(*)                                                     AS tramos,
    SUM(fin IS NULL)                                             AS a_abiertos_ok,
    SUM(fin IS NOT NULL AND (YEAR(ini) NOT BETWEEN 2000 AND YEAR(NOW())+1
                          OR YEAR(fin) NOT BETWEEN 2000 AND YEAR(NOW())+1)) AS b_fecha_invalida,
    SUM(fin IS NOT NULL AND fin < ini
        AND YEAR(ini) BETWEEN 2000 AND YEAR(NOW())+1
        AND YEAR(fin) BETWEEN 2000 AND YEAR(NOW())+1)            AS c_invertidos_por_orden
FROM (
    SELECT hl.fecha AS ini,
           (SELECT hl2.fecha FROM historial_lecturas_mem hl2
             WHERE hl2.id_equipo = hl.id_equipo AND hl2.id_lectura > hl.id_lectura
             ORDER BY hl2.id_lectura LIMIT 1) AS fin
      FROM historial_lecturas_mem hl
      JOIN equipos e ON e.id_equipo = hl.id_equipo
     WHERE e.id_empresa = @id_empresa
) t;


-- ---------------------------------------------------------------------------
-- 2. Cuantos de los invertidos se arreglan solo con ordenar por FECHA
-- ---------------------------------------------------------------------------
--  Mismo tramo, pero el "fin" se busca por fecha (que es lo que el calculo
--  quiere decir) en vez de por id_lectura.
SELECT
    SUM(fin_por_id    IS NOT NULL AND fin_por_id    < ini) AS invertidos_ordenando_por_id,
    SUM(fin_por_fecha IS NOT NULL AND fin_por_fecha < ini) AS invertidos_ordenando_por_fecha
FROM (
    SELECT hl.fecha AS ini,
           (SELECT hl2.fecha FROM historial_lecturas_mem hl2
             WHERE hl2.id_equipo = hl.id_equipo AND hl2.id_lectura > hl.id_lectura
             ORDER BY hl2.id_lectura LIMIT 1) AS fin_por_id,
           (SELECT hl3.fecha FROM historial_lecturas_mem hl3
             WHERE hl3.id_equipo = hl.id_equipo AND hl3.fecha > hl.fecha
             ORDER BY hl3.fecha LIMIT 1) AS fin_por_fecha
      FROM historial_lecturas_mem hl
      JOIN equipos e ON e.id_equipo = hl.id_equipo
     WHERE e.id_empresa = @id_empresa
       AND YEAR(hl.fecha) BETWEEN 2000 AND YEAR(NOW())+1
) t;


-- ---------------------------------------------------------------------------
-- 3. Disponibilidad: hoy vs ordenando por fecha
-- ---------------------------------------------------------------------------
--  Los tramos abiertos se cierran con la fecha fin del periodo en AMBOS casos,
--  igual que hace el calculo original: la comparacion es pareja y el unico
--  cambio es el criterio de ordenamiento.
SELECT
    ROUND(100 * SUM(CASE WHEN estado='AC' THEN min_id ELSE 0 END)
              / NULLIF(SUM(min_id),0), 2)    AS disponibilidad_hoy_por_id,
    ROUND(100 * SUM(CASE WHEN estado='AC' THEN min_fecha ELSE 0 END)
              / NULLIF(SUM(min_fecha),0), 2) AS disponibilidad_ordenando_por_fecha,
    SUM(min_id)                              AS minutos_por_id,
    SUM(min_fecha)                           AS minutos_por_fecha
FROM (
    SELECT t.estado,
           TIMESTAMPDIFF(MINUTE, t.ini, IFNULL(t.fin_por_id,    STR_TO_DATE(CONCAT(@fec_fin,' 23:59:59'), '%Y-%m-%d %H:%i:%s'))) AS min_id,
           TIMESTAMPDIFF(MINUTE, t.ini, IFNULL(t.fin_por_fecha, STR_TO_DATE(CONCAT(@fec_fin,' 23:59:59'), '%Y-%m-%d %H:%i:%s'))) AS min_fecha
      FROM (
        SELECT hl.estado, hl.fecha AS ini,
               (SELECT hl2.fecha FROM historial_lecturas_mem hl2
                 WHERE hl2.id_equipo = hl.id_equipo AND hl2.id_lectura > hl.id_lectura
                 ORDER BY hl2.id_lectura LIMIT 1) AS fin_por_id,
               (SELECT hl3.fecha FROM historial_lecturas_mem hl3
                 WHERE hl3.id_equipo = hl.id_equipo AND hl3.fecha > hl.fecha
                 ORDER BY hl3.fecha LIMIT 1) AS fin_por_fecha
          FROM historial_lecturas_mem hl
          JOIN equipos e ON e.id_equipo = hl.id_equipo
         WHERE e.id_empresa = @id_empresa
           AND YEAR(hl.fecha) BETWEEN 2000 AND YEAR(NOW())+1
      ) t
) x;


-- ---------------------------------------------------------------------------
-- 4. Los 7 registros con fecha invalida, para corregirlos a mano si se decide
-- ---------------------------------------------------------------------------
SELECT hl.id_lectura, hl.id_equipo, e.codigo, hl.fecha, hl.lectura, hl.estado,
       LEFT(hl.observacion, 60) AS observacion
  FROM historial_lecturas hl
  JOIN equipos e ON e.id_equipo = hl.id_equipo
 WHERE e.id_empresa = @id_empresa
   AND (hl.fecha IS NULL OR YEAR(hl.fecha) NOT BETWEEN 2000 AND YEAR(NOW())+1)
 ORDER BY hl.id_lectura;
