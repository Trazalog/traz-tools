-- v2.8.1.4 — Definiciones de KPIs del Tablero del Administrador (Postgres).
-- Se cargan en kpi.definiciones (motor: kpi_cache_engine.sql). El motor ejecuta cada
-- sql_template por empresa pasando el empr_id como $1 (se puede repetir). Cada template
-- devuelve UNA fila con columnas `valor` (numeric) y `valor_json` (jsonb).
--
-- IMPORTANTE (regla de sistema productivo): estas queries están INFERIDAS del schema real
-- (mapeado desde los .dbs), pero NO se corrieron contra la BD. Antes de habilitarlas en un
-- ambiente compartido hay que probarlas en dev/local con VPN. El motor aísla cada cálculo en
-- su propio BEGIN/EXCEPTION y loguea fallas en kpi.event_log, así que un template con error
-- no rompe al resto (queda esa empresa/KPI sin dato hasta corregir).
--
-- Caveats del schema (confirmados):
--   * No hay stock materializado: el stock por depósito es SUM(alm.alm_lotes.cantidad).
--   * punto_pedido es GLOBAL por artículo (alm.alm_articulos), NO por depósito. El KPI 1
--     compara el stock-por-depósito contra ese punto_pedido único del artículo.
--   * Herramientas "en tránsito" = pan.herramientas.estado = 'TRANSITO'; total = no eliminadas.
--   * MAN (disponibilidad, etc.) NO va acá: su caché ya vive en AssetPlanner (MariaDB) y la lee
--     MANKPIDataService.dbs. El tablero enruta esos KPIs a ese servicio (config 'fuente' = 'man').
--
-- Idempotente: ON CONFLICT (nombre) DO UPDATE.

-- KPI 1: Artículos bajo punto de pedido, por establecimiento/depósito (ALM).
--   valor      = cantidad de (artículo x depósito) con stock < punto_pedido
--   valor_json = [{establecimiento, deposito, criticos}, ...]  (para el gráfico de barras + drill-down)
INSERT INTO kpi.definiciones (nombre, descripcion, modulo, sql_template, refresh_seg, habilitado)
VALUES (
  'alm_reorder',
  'Artículos bajo punto de pedido por establecimiento/depósito',
  'ALM',
  -- Query verificada contra tools_prod_t (empr_id=1). Stock = SUM(alm_lotes.cantidad) de lotes
  -- 'AC'; se comparan contra punto_pedido del artículo (global, no por depósito).
  -- Borde conocido: un artículo con punto_pedido>0 pero SIN lotes en un depósito (stock 0) no
  -- aparece — se parte de alm_lotes. Refinable después si hace falta contar esos.
  $KPI$
    select
      (select count(*) from (
          select s.arti_id, s.depo_id
          from ( select l.depo_id, l.arti_id, sum(l.cantidad) as stock
                 from alm.alm_lotes l
                 where l.empr_id = $1 and l.estado = 'AC' and coalesce(l.eliminado,false) = false
                 group by l.depo_id, l.arti_id ) s
          join alm.alm_articulos a on a.arti_id = s.arti_id
               and coalesce(a.eliminado,false) = false and coalesce(a.punto_pedido,0) > 0
          where s.stock < a.punto_pedido
      ) crit)::numeric as valor,
      (select coalesce(jsonb_agg(row_to_json(x)), '[]'::jsonb) from (
          select coalesce(e.nombre,'Sin establecimiento') as establecimiento,
                 coalesce(d.nombre, d.descripcion)        as deposito,
                 count(*)                                 as criticos
          from ( select l.depo_id, l.arti_id, sum(l.cantidad) as stock
                 from alm.alm_lotes l
                 where l.empr_id = $1 and l.estado = 'AC' and coalesce(l.eliminado,false) = false
                 group by l.depo_id, l.arti_id ) s
          join alm.alm_articulos a on a.arti_id = s.arti_id
               and coalesce(a.eliminado,false) = false and coalesce(a.punto_pedido,0) > 0
          join alm.alm_depositos d on d.depo_id = s.depo_id
          left join prd.establecimientos e on e.esta_id = d.esta_id
          where s.stock < a.punto_pedido
          group by 1, 2
      ) x) as valor_json
  $KPI$,
  300, true
)
ON CONFLICT (nombre) DO UPDATE
   SET descripcion = excluded.descripcion, modulo = excluded.modulo,
       sql_template = excluded.sql_template, refresh_seg = excluded.refresh_seg,
       habilitado = excluded.habilitado;

-- KPI 2: Movimientos internos sin entregar (ALM).
--   valor      = cantidad de movimientos en 'EN_CURSO'
--   valor_json = {sin_entregar, recibidos}  (para el doughnut)
INSERT INTO kpi.definiciones (nombre, descripcion, modulo, sql_template, refresh_seg, habilitado)
VALUES (
  'alm_mov_sin_entregar',
  'Movimientos internos sin entregar',
  'ALM',
  $KPI$
    select
      (select count(*) from alm.movimientos_internos
        where estado = 'EN_CURSO' and empr_id = $1 and coalesce(eliminado,false) = false)::numeric as valor,
      jsonb_build_object(
        'sin_entregar', (select count(*) from alm.movimientos_internos
                          where estado = 'EN_CURSO' and empr_id = $1 and coalesce(eliminado,false) = false),
        'recibidos',    (select count(*) from alm.movimientos_internos
                          where estado = 'RECIBIDO' and empr_id = $1 and coalesce(eliminado,false) = false)
      ) as valor_json
  $KPI$,
  300, true
)
ON CONFLICT (nombre) DO UPDATE
   SET descripcion = excluded.descripcion, modulo = excluded.modulo,
       sql_template = excluded.sql_template, refresh_seg = excluded.refresh_seg,
       habilitado = excluded.habilitado;

-- KPI 3: Herramientas en tránsito vs total (HER / Pañol).
--   valor      = herramientas en tránsito
--   valor_json = {en_transito, total}  (para el doughnut)
INSERT INTO kpi.definiciones (nombre, descripcion, modulo, sql_template, refresh_seg, habilitado)
VALUES (
  'her_transito',
  'Herramientas en tránsito vs total',
  'HER',
  $KPI$
    select
      (select count(*) from pan.herramientas
        where empr_id = $1 and coalesce(eliminado,false) = false and estado = 'TRANSITO')::numeric as valor,
      jsonb_build_object(
        'en_transito', (select count(*) from pan.herramientas
                         where empr_id = $1 and coalesce(eliminado,false) = false and estado = 'TRANSITO'),
        'total',       (select count(*) from pan.herramientas
                         where empr_id = $1 and coalesce(eliminado,false) = false)
      ) as valor_json
  $KPI$,
  600, true
)
ON CONFLICT (nombre) DO UPDATE
   SET descripcion = excluded.descripcion, modulo = excluded.modulo,
       sql_template = excluded.sql_template, refresh_seg = excluded.refresh_seg,
       habilitado = excluded.habilitado;
