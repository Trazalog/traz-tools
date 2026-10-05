-- ===========================================================================
-- ¿Los KPIs de mantenimiento están mal calculados en producción?
-- ===========================================================================
--
-- QUÉ ES
--   Diagnóstico de una sola pasada sobre la base de Asset Planner. Detecta si
--   las lecturas de los equipos están cargadas fuera de orden cronológico, que
--   es lo que rompe el cálculo de Disponibilidad, MTTR, MTBF y MTTF.
--
-- POR QUÉ
--   Las 4 queries de KPI (`getKPIDisponibiidadPorFecha`, `getKPIMttrporFecha`,
--   `getKPIMttfporFecha`, `getCantidadFallos` en MANDataService.dbs) calculan
--   cuánto duró cada tramo tomando como fecha de fin *la lectura siguiente por
--   id_lectura*:
--
--       (select hl2.fecha from historial_lecturas_mem hl2
--         where hl2.id_equipo = hl.id_equipo
--           and hl2.id_lectura > hl.id_lectura
--         order by hl2.id_lectura limit 1)
--
--   Eso asume que un id_lectura más alto es siempre una fecha posterior. En la
--   base de DESARROLLO esa suposición es falsa en 115 pares: la lectura
--   siguiente por ID es ANTERIOR en el tiempo, y cada uno de esos casos aporta
--   una duración NEGATIVA al cálculo.
--
-- DÓNDE SE EJECUTA
--   En la base de PRODUCCIÓN, esquema `assetv2`. Da igual el cliente: DBeaver
--   conectado a producción, o por SSH al server de la base y ahí:
--       mysql -u <usuario> -p assetv2 < kpi-lecturas-desorden.sql
--   Es 100% de solo lectura: ningún INSERT, UPDATE, DELETE ni SET.
--
-- CUÁNTO TARDA
--   Segundos si las tablas rondan el millar de filas. Si producción tiene
--   cientos de miles, las subconsultas correlacionadas pueden tardar varios
--   minutos — dejalo correr, no lo cortes.
--
-- QUÉ HACER CON EL RESULTADO
--   Pegar la salida completa en el chat. La interpretación está al final del
--   archivo, en el bloque "CÓMO SE LEE".
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- BLOQUE 1 · Contexto: ¿hay datos para medir?
--   Si `filas_mem` da 0, el event_scheduler está apagado también en producción
--   y los KPIs del dashboard estarían saliendo vacíos. Ese sería otro hallazgo.
-- ---------------------------------------------------------------------------
SELECT '--- BLOQUE 1: contexto ---' AS bloque;

SELECT
    (SELECT count(*) FROM historial_lecturas_mem) AS filas_mem,
    (SELECT count(*) FROM historial_lecturas)     AS filas_historico,
    (SELECT count(DISTINCT id_equipo) FROM historial_lecturas_mem) AS equipos_con_lecturas,
    @@event_scheduler AS event_scheduler;

-- ---------------------------------------------------------------------------
-- BLOQUE 2 · El diagnóstico principal
--   Cuenta los pares donde la lectura siguiente POR ID es anterior EN EL TIEMPO.
--   Corre sobre las dos tablas: `_mem` es la que leen los KPIs, `historial_lecturas`
--   es la fuente persistente (si el desorden ya está en el origen, no alcanza con
--   repoblar la tabla MEMORY).
-- ---------------------------------------------------------------------------
SELECT '--- BLOQUE 2: pares fuera de orden ---' AS bloque;

SELECT 'historial_lecturas_mem' AS tabla,
       count(*)                                        AS pares_evaluados,
       sum(CASE WHEN sig < fecha THEN 1 ELSE 0 END)    AS pares_fuera_de_orden,
       ROUND(100 * sum(CASE WHEN sig < fecha THEN 1 ELSE 0 END) / count(*), 2) AS porcentaje
FROM (
    SELECT a.fecha,
           (SELECT b.fecha FROM historial_lecturas_mem b
             WHERE b.id_equipo = a.id_equipo
               AND b.id_lectura > a.id_lectura
             ORDER BY b.id_lectura LIMIT 1) AS sig
    FROM historial_lecturas_mem a
) x
WHERE sig IS NOT NULL

UNION ALL

SELECT 'historial_lecturas' AS tabla,
       count(*),
       sum(CASE WHEN sig < fecha THEN 1 ELSE 0 END),
       ROUND(100 * sum(CASE WHEN sig < fecha THEN 1 ELSE 0 END) / count(*), 2)
FROM (
    SELECT a.fecha,
           (SELECT b.fecha FROM historial_lecturas b
             WHERE b.id_equipo = a.id_equipo
               AND b.id_lectura > a.id_lectura
             ORDER BY b.id_lectura LIMIT 1) AS sig
    FROM historial_lecturas a
) y
WHERE sig IS NOT NULL;

-- ---------------------------------------------------------------------------
-- BLOQUE 3 · Ejemplos concretos, para ver la pinta que tienen
-- ---------------------------------------------------------------------------
SELECT '--- BLOQUE 3: ejemplos ---' AS bloque;

SELECT id_equipo,
       id_lectura,
       fecha                                   AS fecha_de_esta,
       sig_id                                  AS id_de_la_siguiente,
       sig                                     AS fecha_de_la_siguiente,
       TIMESTAMPDIFF(MINUTE, fecha, sig)       AS minutos_de_diferencia
FROM (
    SELECT a.id_equipo, a.id_lectura, a.fecha,
           (SELECT b.fecha      FROM historial_lecturas_mem b
             WHERE b.id_equipo = a.id_equipo AND b.id_lectura > a.id_lectura
             ORDER BY b.id_lectura LIMIT 1) AS sig,
           (SELECT b.id_lectura FROM historial_lecturas_mem b
             WHERE b.id_equipo = a.id_equipo AND b.id_lectura > a.id_lectura
             ORDER BY b.id_lectura LIMIT 1) AS sig_id
    FROM historial_lecturas_mem a
) z
WHERE sig IS NOT NULL AND sig < fecha
ORDER BY minutos_de_diferencia
LIMIT 15;

-- ---------------------------------------------------------------------------
-- BLOQUE 4 · El impacto real sobre el número que ve el usuario
--   Reproduce exactamente el cálculo de horas de la query de Disponibilidad
--   (incluido el `/24` original) y lo separa entre tramos sanos y tramos
--   negativos, por empresa. `horas_negativas` es la magnitud del error.
-- ---------------------------------------------------------------------------
SELECT '--- BLOQUE 4: impacto por empresa ---' AS bloque;

SELECT id_empresa,
       count(*)                                                       AS tramos,
       sum(CASE WHEN horas < 0 THEN 1 ELSE 0 END)                     AS tramos_negativos,
       ROUND(sum(CASE WHEN horas >= 0 THEN horas ELSE 0 END), 2)      AS horas_sanas,
       ROUND(sum(CASE WHEN horas <  0 THEN horas ELSE 0 END), 2)      AS horas_negativas,
       ROUND(sum(horas), 2)                                           AS total_que_usa_el_kpi
FROM (
    SELECT e.id_empresa,
           TIMESTAMPDIFF(MINUTE, hl.fecha,
               (SELECT hl2.fecha FROM historial_lecturas_mem hl2
                 WHERE hl2.id_equipo = hl.id_equipo
                   AND hl2.id_lectura > hl.id_lectura
                 ORDER BY hl2.id_lectura LIMIT 1)) / 24 AS horas
    FROM historial_lecturas_mem hl
    JOIN equipos e ON e.id_equipo = hl.id_equipo
) w
WHERE horas IS NOT NULL
GROUP BY id_empresa
ORDER BY tramos_negativos DESC;

-- ===========================================================================
-- CÓMO SE LEE
--
--   BLOQUE 2, columna `pares_fuera_de_orden`:
--
--     = 0 en las dos tablas
--         El problema es exclusivo del ambiente de desarrollo (carga
--         desordenada de datos de prueba). Los KPIs de producción están bien.
--         Se corrigen los datos de desarrollo y la ola 3 se destraba sin
--         tocar nada del cálculo.
--
--     > 0 en `historial_lecturas_mem` solamente
--         El desorden lo introduce el evento que puebla la tabla MEMORY. Se
--         arregla en el evento, sin tocar el histórico.
--
--     > 0 en las dos
--         El desorden está en el origen. Los KPIs que muestra hoy el dashboard
--         de Asset Planner están mal calculados, y la corrección es cambiar el
--         `order by hl2.id_lectura` por `order by hl2.fecha` en las 4 queries
--         (más descartar los tramos de duración negativa). Eso mueve números
--         que la gente ya viene mirando: va a workshop antes de tocarse.
--
--   BLOQUE 4, columna `horas_negativas`:
--     Cuánto le resta el error al total. Si es un valor grande comparado con
--     `horas_sanas`, el KPI no está apenas sesgado: está dominado por el error.
--
--   Aparte de esto, y sin depender del resultado, hay un segundo bug ya
--   confirmado por lectura del SQL: la columna se llama `horas` pero calcula
--   TIMESTAMPDIFF(MINUTE,...)/24. Minutos dividido 24 no es ninguna unidad;
--   para pasar a horas hay que dividir por 60. No afecta a la Disponibilidad
--   (es un cociente y se cancela), sí a MTTR y MTBF, que se muestran como
--   valores absolutos.
--
--   Contexto completo: doc/mcp/casos-de-uso-mineria-y-gaps.md §1.2-bis
-- ===========================================================================
