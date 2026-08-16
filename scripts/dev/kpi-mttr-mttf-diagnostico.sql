-- ============================================================================
--  MTTR / MTTF — diagnostico  (v2 — corregido)
--
--  CORRECCION RESPECTO DE LA v1:
--    la v1 calculaba el MTTF dividiendo por la cantidad de tramos 'AC'. El
--    DataService real (getKPIMttfporFecha) divide por la cantidad de tramos
--    'RE' -- es decir, por el numero de FALLOS. Con 4 fallos registrados y
--    20.704 tramos AC, la diferencia es de cuatro ordenes de magnitud.
--    Los resultados de la v1 para el MTTF hay que descartarlos.
--
--  Formula real, de MANDataService.dbs:
--    MTTR = SUM(minutos/24 en tramos 'RE') / COUNT(tramos 'RE')
--    MTTF = SUM(minutos/24 en tramos 'AC') / COUNT(tramos 'RE')   <-- denominador RE
--
--  Este script mide, sin cambiar la definicion de los KPIs:
--    - el valor tal cual sale hoy
--    - el valor descartando tramos imposibles (fin < inicio, fechas absurdas)
--    - el valor usando 60 min/hora en vez de 24
--    - si hay suficientes eventos 'RE' como para que el KPI signifique algo
--
--  SOLO LEE.
--  USO:  mysql -h <host> -u <user> -p <base> < kpi-mttr-mttf-diagnostico.sql
-- ============================================================================

SET @id_empresa = 15;             -- 15 = Tierra Capayan
SET @fec_inicio = '2024-01-01';
SET @fec_fin    = '2026-07-31';


-- ---------------------------------------------------------------------------
-- 1. Como se cuentan hoy los "fallos"
-- ---------------------------------------------------------------------------
--  Un "fallo" = una lectura con estado 'RE'. Todo el MTTR y todo el MTTF
--  dependen de este numero: es el denominador de los dos.
SELECT hl.estado, COUNT(*) AS lecturas
  FROM historial_lecturas_mem hl
  JOIN equipos e ON e.id_equipo = hl.id_equipo
 WHERE e.id_empresa = @id_empresa
 GROUP BY hl.estado ORDER BY lecturas DESC;


-- ---------------------------------------------------------------------------
-- 2. MTTR: actual vs corregido
-- ---------------------------------------------------------------------------
--   actual        = tal cual el DataService: SUM(minutos/24) / COUNT(*)
--   sin_negativos = descarta tramos con fin anterior al inicio o fecha absurda
--   en_horas      = ademas divide por 60 (minutos -> horas) en vez de por 24
SELECT
    ROUND(SUM(minutos/24)  / NULLIF(COUNT(*),0), 2)                      AS mttr_actual,
    ROUND(SUM(CASE WHEN ok=1 THEN minutos/24 ELSE 0 END)
          / NULLIF(SUM(ok),0), 2)                                        AS mttr_sin_negativos,
    ROUND(SUM(CASE WHEN ok=1 THEN minutos/60 ELSE 0 END)
          / NULLIF(SUM(ok),0), 2)                                        AS mttr_en_horas_reales,
    COUNT(*)                                                             AS tramos_re,
    SUM(ok)                                                              AS tramos_re_validos,
    SUM(CASE WHEN ok=0 THEN 1 ELSE 0 END)                                AS tramos_re_descartados
FROM (
    SELECT TIMESTAMPDIFF(MINUTE, t.ini, IFNULL(t.fin, CURRENT_TIMESTAMP)) AS minutos,
           CASE WHEN t.fin IS NOT NULL AND t.fin >= t.ini
                     AND YEAR(t.ini) BETWEEN 2000 AND YEAR(NOW())+1
                     AND YEAR(t.fin) BETWEEN 2000 AND YEAR(NOW())+1
                THEN 1 ELSE 0 END AS ok
      FROM (
        SELECT hl.fecha AS ini, hl.estado,
               (SELECT hl2.fecha FROM historial_lecturas_mem hl2
                 WHERE hl2.id_equipo = hl.id_equipo AND hl2.id_lectura > hl.id_lectura
                 ORDER BY hl2.id_lectura LIMIT 1) AS fin
          FROM historial_lecturas_mem hl
          JOIN equipos e ON e.id_equipo = hl.id_equipo
         WHERE e.id_empresa = @id_empresa AND hl.estado = 'RE'
      ) t
     WHERE t.ini >= STR_TO_DATE(CONCAT(@fec_inicio,' 00:00:00'), '%Y-%m-%d %H:%i:%s')
       AND IFNULL(t.fin, CURRENT_TIMESTAMP) <= STR_TO_DATE(CONCAT(@fec_fin,' 23:59:59'), '%Y-%m-%d %H:%i:%s')
) x;


-- ---------------------------------------------------------------------------
-- 3. MTTF: tiempo activo dividido por CANTIDAD DE FALLOS (no por tramos AC)
-- ---------------------------------------------------------------------------
--  Esta es la correccion de la v2. El denominador se calcula aparte, sobre
--  los tramos 'RE', exactamente como hace getKPIMttfporFecha.
SELECT
    ROUND(ac.horas_todas    / NULLIF(re.fallos,0), 2)        AS mttf_actual,
    ROUND(ac.horas_validas  / NULLIF(re.fallos_validos,0), 2) AS mttf_sin_negativos,
    ROUND(ac.horas_reales   / NULLIF(re.fallos_validos,0), 2) AS mttf_en_horas_reales,
    ac.tramos_ac,
    ac.tramos_ac_validos,
    ac.tramos_ac - ac.tramos_ac_validos                      AS tramos_ac_descartados,
    re.fallos                                                AS denominador_fallos,
    re.fallos_validos                                        AS denominador_fallos_validos
FROM
(
    SELECT SUM(minutos/24)                                        AS horas_todas,
           SUM(CASE WHEN ok=1 THEN minutos/24 ELSE 0 END)         AS horas_validas,
           SUM(CASE WHEN ok=1 THEN minutos/60 ELSE 0 END)         AS horas_reales,
           COUNT(*)                                               AS tramos_ac,
           SUM(ok)                                                AS tramos_ac_validos
      FROM (
        SELECT TIMESTAMPDIFF(MINUTE, t.ini, IFNULL(t.fin, CURRENT_TIMESTAMP)) AS minutos,
               CASE WHEN t.fin IS NOT NULL AND t.fin >= t.ini
                         AND YEAR(t.ini) BETWEEN 2000 AND YEAR(NOW())+1
                         AND YEAR(t.fin) BETWEEN 2000 AND YEAR(NOW())+1
                    THEN 1 ELSE 0 END AS ok
          FROM (
            SELECT hl.fecha AS ini,
                   (SELECT hl2.fecha FROM historial_lecturas_mem hl2
                     WHERE hl2.id_equipo = hl.id_equipo AND hl2.id_lectura > hl.id_lectura
                     ORDER BY hl2.id_lectura LIMIT 1) AS fin
              FROM historial_lecturas_mem hl
              JOIN equipos e ON e.id_equipo = hl.id_equipo
             WHERE e.id_empresa = @id_empresa AND hl.estado = 'AC'
          ) t
         WHERE t.ini >= STR_TO_DATE(CONCAT(@fec_inicio,' 00:00:00'), '%Y-%m-%d %H:%i:%s')
           AND IFNULL(t.fin, CURRENT_TIMESTAMP) <= STR_TO_DATE(CONCAT(@fec_fin,' 23:59:59'), '%Y-%m-%d %H:%i:%s')
      ) xa
) ac,
(
    SELECT COUNT(*) AS fallos, SUM(ok) AS fallos_validos
      FROM (
        SELECT CASE WHEN t.fin IS NOT NULL AND t.fin >= t.ini
                         AND YEAR(t.ini) BETWEEN 2000 AND YEAR(NOW())+1
                         AND YEAR(t.fin) BETWEEN 2000 AND YEAR(NOW())+1
                    THEN 1 ELSE 0 END AS ok
          FROM (
            SELECT hl.fecha AS ini,
                   (SELECT hl2.fecha FROM historial_lecturas_mem hl2
                     WHERE hl2.id_equipo = hl.id_equipo AND hl2.id_lectura > hl.id_lectura
                     ORDER BY hl2.id_lectura LIMIT 1) AS fin
              FROM historial_lecturas_mem hl
              JOIN equipos e ON e.id_equipo = hl.id_equipo
             WHERE e.id_empresa = @id_empresa AND hl.estado = 'RE'
          ) t
         WHERE t.ini >= STR_TO_DATE(CONCAT(@fec_inicio,' 00:00:00'), '%Y-%m-%d %H:%i:%s')
           AND IFNULL(t.fin, CURRENT_TIMESTAMP) <= STR_TO_DATE(CONCAT(@fec_fin,' 23:59:59'), '%Y-%m-%d %H:%i:%s')
      ) xr
) re;


-- ---------------------------------------------------------------------------
-- 4. LA PREGUNTA DE FONDO: ¿se registran las reparaciones como estado 'RE'?
-- ---------------------------------------------------------------------------
--  Si hay muchas solicitudes correctivas pero casi ninguna lectura 'RE',
--  entonces las reparaciones SI ocurren pero NO quedan reflejadas en el
--  historial de estados -- y el MTTR/MTBF miden sobre una muestra que no
--  representa la operacion real.
--  4.a  Solicitudes por tipo, con el valor del flag tal cual esta en la base
--       (no asumimos si 'correctivo' se guarda como 1/0, 'S'/'N' u otra cosa).
SELECT IFNULL(sr.correctivo,'(null)') AS correctivo,
       COUNT(*)                       AS solicitudes
  FROM solicitud_reparacion sr
 WHERE sr.id_empresa = @id_empresa
   AND sr.f_solicitado >= @fec_inicio
   AND sr.f_solicitado <= @fec_fin
 GROUP BY sr.correctivo
 ORDER BY solicitudes DESC;

--  4.a-bis  El flag 'correctivo' vino NULL en las 17.372 solicitudes: no sirve
--           para separar correctivo de preventivo. Probamos con id_tipo, que es
--           el otro campo candidato.
SELECT IFNULL(sr.id_tipo,'(null)') AS id_tipo,
       COUNT(*)                    AS solicitudes,
       MIN(sr.f_solicitado)        AS desde,
       MAX(sr.f_solicitado)        AS hasta
  FROM solicitud_reparacion sr
 WHERE sr.id_empresa = @id_empresa
   AND sr.f_solicitado >= @fec_inicio
   AND sr.f_solicitado <= @fec_fin
 GROUP BY sr.id_tipo
 ORDER BY solicitudes DESC;

--  4.b  El contraste: solicitudes registradas vs equipos puestos en reparacion
SELECT
    (SELECT COUNT(*) FROM solicitud_reparacion sr
      WHERE sr.id_empresa = @id_empresa
        AND sr.f_solicitado >= @fec_inicio
        AND sr.f_solicitado <= @fec_fin)                          AS solicitudes_totales,
    (SELECT COUNT(*) FROM historial_lecturas_mem hl
       JOIN equipos e ON e.id_equipo = hl.id_equipo
      WHERE e.id_empresa = @id_empresa AND hl.estado = 'RE'
        AND hl.fecha >= @fec_inicio AND hl.fecha <= @fec_fin)     AS lecturas_en_reparacion;


-- ---------------------------------------------------------------------------
-- 5. ¿Un "fallo" = una lectura 'RE', o una PARADA?
-- ---------------------------------------------------------------------------
--  Si un equipo tiene varias lecturas 'RE' seguidas (sin volver a 'AC' en el
--  medio), hoy cada una cuenta como un fallo distinto. Para un ingeniero de
--  mantenimiento eso es UNA sola parada.
SELECT
    COUNT(*)                                              AS lecturas_re,
    COUNT(DISTINCT id_equipo)                             AS equipos_con_re,
    SUM(re_consecutiva)                                   AS re_precedida_por_otra_re,
    ROUND(100*SUM(re_consecutiva)/NULLIF(COUNT(*),0),1)   AS pct_consecutivas
FROM (
    SELECT hl.id_lectura, hl.id_equipo,
           CASE WHEN (SELECT hl0.estado FROM historial_lecturas_mem hl0
                       WHERE hl0.id_equipo = hl.id_equipo AND hl0.id_lectura < hl.id_lectura
                       ORDER BY hl0.id_lectura DESC LIMIT 1) = 'RE'
                THEN 1 ELSE 0 END AS re_consecutiva
      FROM historial_lecturas_mem hl
      JOIN equipos e ON e.id_equipo = hl.id_equipo
     WHERE e.id_empresa = @id_empresa AND hl.estado = 'RE'
) t;


-- ---------------------------------------------------------------------------
-- 6. De que estan hechos los tramos descartados
-- ---------------------------------------------------------------------------
--  Separa las dos causas: fecha imposible (dato roto) vs fin anterior al
--  inicio (efecto de ordenar por id_lectura en vez de por fecha).
SELECT
    COUNT(*)                                                          AS tramos_cerrados,
    SUM(CASE WHEN YEAR(ini) NOT BETWEEN 2000 AND YEAR(NOW())+1
              OR YEAR(fin) NOT BETWEEN 2000 AND YEAR(NOW())+1
             THEN 1 ELSE 0 END)                                       AS fecha_absurda,
    SUM(CASE WHEN fin < ini
              AND YEAR(ini) BETWEEN 2000 AND YEAR(NOW())+1
              AND YEAR(fin) BETWEEN 2000 AND YEAR(NOW())+1
             THEN 1 ELSE 0 END)                                       AS invertidos_por_orden,
    ROUND(100*SUM(CASE WHEN fin < ini
              AND YEAR(ini) BETWEEN 2000 AND YEAR(NOW())+1
              AND YEAR(fin) BETWEEN 2000 AND YEAR(NOW())+1
             THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0),1)                 AS pct_invertidos
FROM (
    SELECT hl.fecha AS ini,
           (SELECT hl2.fecha FROM historial_lecturas_mem hl2
             WHERE hl2.id_equipo = hl.id_equipo AND hl2.id_lectura > hl.id_lectura
             ORDER BY hl2.id_lectura LIMIT 1) AS fin
      FROM historial_lecturas_mem hl
      JOIN equipos e ON e.id_equipo = hl.id_equipo
     WHERE e.id_empresa = @id_empresa
) t
WHERE fin IS NOT NULL;


-- ---------------------------------------------------------------------------
-- 7. Tramos abiertos: se cierran con AHORA, no con el fin del periodo
-- ---------------------------------------------------------------------------
--  MTTR/MTTF usan IFNULL(fecha_fin, CURRENT_TIMESTAMP); Disponibilidad usa el
--  fin del periodo consultado. Al pedir un mes pasado, un tramo abierto suma
--  hasta HOY en MTTR/MTTF -- y el valor cambia segun el dia en que se consulte.
SELECT COUNT(*) AS tramos_abiertos,
       MIN(ini) AS mas_antiguo,
       ROUND(AVG(TIMESTAMPDIFF(DAY, ini, CURRENT_TIMESTAMP)),0) AS dias_promedio_hasta_hoy
FROM (
    SELECT hl.fecha AS ini,
           (SELECT hl2.fecha FROM historial_lecturas_mem hl2
             WHERE hl2.id_equipo = hl.id_equipo AND hl2.id_lectura > hl.id_lectura
             ORDER BY hl2.id_lectura LIMIT 1) AS fin
      FROM historial_lecturas_mem hl
      JOIN equipos e ON e.id_equipo = hl.id_equipo
     WHERE e.id_empresa = @id_empresa
) t
WHERE fin IS NULL AND YEAR(ini) BETWEEN 2000 AND YEAR(NOW())+1;
