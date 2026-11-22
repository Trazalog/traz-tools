-- v2.8.1.8 — Metas de pedido y de hito sobre los KPIs de la empresa (TAR-METAS).
--
-- Qué pide el PM (2026-11-12): asociar al pedido de trabajo y a sus hitos una meta medible
-- con los KPI de la empresa ("mejorar la disponibilidad de equipos un 30%, llegando a 70%").
-- Decisiones del PM: meta en el pedido y, opcional, en cada hito; se carga el valor a
-- alcanzar y la fecha, y el sistema guarda el valor de partida (línea base); la carga quien
-- planifica el pedido; un pedido o hito puede tener su meta aunque ya haya otra para el mismo KPI.
-- Análisis de impacto: doc/specs/TAR-metas-pedido-hito.md.
--
-- Sobre kpi.objetivos (v2.8.1.6), que ya tenía petr_id sin usar:
--   * columnas nuevas hito_id, linea_base, linea_base_fecha (todas opcionales);
--   * kpi.objetivo_guardar() suma p_petr_id, p_hito_id y p_linea_base con default null: las
--     llamadas de hoy (Tablero, DataService guardarObjetivo) siguen iguales;
--   * la regla "una meta vigente por KPI y empresa" queda solo para las metas generales de la
--     empresa (sin pedido); las de pedido o hito no la chocan ni la bloquean;
--   * kpi.objetivos_de_pedido() nueva. kpi.objetivos_de() y kpi.desvios() no cambian.
--
-- Requiere v2.8.1.6 (kpi_objetivos.sql). Idempotente. Rollback: kpi_metas_pedido_hito.rollback.sql.

ALTER TABLE kpi.objetivos ADD COLUMN IF NOT EXISTS hito_id integer;
ALTER TABLE kpi.objetivos ADD COLUMN IF NOT EXISTS linea_base numeric;
ALTER TABLE kpi.objetivos ADD COLUMN IF NOT EXISTS linea_base_fecha date;
CREATE INDEX IF NOT EXISTS objetivos_pedido_ix ON kpi.objetivos (petr_id) WHERE petr_id IS NOT NULL;
COMMENT ON COLUMN kpi.objetivos.petr_id IS 'Pedido de trabajo al que pertenece la meta (null = meta general de la empresa).';
COMMENT ON COLUMN kpi.objetivos.hito_id IS 'Hito del pedido al que pertenece la meta (opcional; requiere petr_id).';
COMMENT ON COLUMN kpi.objetivos.linea_base IS 'Valor del KPI al crear la meta: el punto de partida para medir el avance.';

-- La firma cambia (parámetros nuevos): se borra la vieja para no dejar dos versiones.
DROP FUNCTION IF EXISTS kpi.objetivo_guardar(integer, varchar, varchar, varchar, numeric, date, date, varchar, varchar, varchar);

CREATE OR REPLACE FUNCTION kpi.objetivo_guardar(
    p_empr_id integer, p_kpi varchar, p_fuente varchar, p_operador varchar, p_meta numeric,
    p_desde date, p_hasta date, p_responsable varchar, p_propuesto_por varchar, p_usuario varchar,
    p_petr_id integer DEFAULT NULL, p_hito_id integer DEFAULT NULL, p_linea_base numeric DEFAULT NULL)
RETURNS integer
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id integer;
    v_base numeric := p_linea_base;
BEGIN
    IF p_empr_id IS NULL OR p_empr_id <= 0 THEN
        RAISE EXCEPTION 'empr_id invalido';
    END IF;
    IF coalesce(p_usuario, '') = '' THEN
        RAISE EXCEPTION 'falta el usuario que confirma el objetivo';
    END IF;
    IF coalesce(p_fuente, 'tools') = 'tools'
       AND NOT EXISTS (SELECT 1 FROM kpi.definiciones WHERE nombre = p_kpi) THEN
        RAISE EXCEPTION 'el KPI % no existe', p_kpi;
    END IF;
    IF p_hito_id IS NOT NULL AND p_petr_id IS NULL THEN
        RAISE EXCEPTION 'la meta de un hito tiene que indicar su pedido';
    END IF;
    IF p_petr_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM pro.pedidos_trabajo
             WHERE petr_id = p_petr_id AND empr_id = p_empr_id AND NOT eliminado) THEN
        RAISE EXCEPTION 'el pedido % no es de la empresa', p_petr_id;
    END IF;
    IF p_hito_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM tst.hitos WHERE hito_id = p_hito_id AND petr_id = p_petr_id AND NOT eliminado) THEN
        RAISE EXCEPTION 'el hito % no es del pedido', p_hito_id;
    END IF;
    -- Una meta general vigente por KPI (para que el desvío de la empresa sea claro).
    -- Las metas de pedido o de hito pueden convivir con ella.
    IF p_petr_id IS NULL AND EXISTS (
            SELECT 1 FROM kpi.objetivos
             WHERE empr_id = p_empr_id AND kpi = p_kpi AND estado = 'vigente'
               AND hasta >= current_date AND petr_id IS NULL) THEN
        RAISE EXCEPTION 'ya hay un objetivo vigente para %: cancelalo antes de cargar otro', p_kpi;
    END IF;
    -- Línea base: la que manda quien llama (KPI de Mantenimiento, que vive en AssetPlanner)
    -- o el valor de hoy del motor de KPIs.
    IF v_base IS NULL AND coalesce(p_fuente, 'tools') = 'tools' THEN
        SELECT c.valor INTO v_base FROM kpi.cache c WHERE c.nombre = p_kpi AND c.empr_id = p_empr_id;
    END IF;
    INSERT INTO kpi.objetivos (empr_id, kpi, fuente, operador, meta, desde, hasta, responsable,
                               propuesto_por, usuario_alta, petr_id, hito_id, linea_base, linea_base_fecha)
    VALUES (p_empr_id, p_kpi, coalesce(p_fuente, 'tools'), p_operador, p_meta,
            coalesce(p_desde, current_date), p_hasta, nullif(p_responsable, ''),
            CASE WHEN p_propuesto_por = 'kuntur' THEN 'kuntur' ELSE 'usuario' END, p_usuario,
            p_petr_id, p_hito_id, v_base, CASE WHEN v_base IS NULL THEN NULL ELSE current_date END)
    RETURNING objetivo_id INTO v_id;
    RETURN v_id;
END;
$function$;

-- ---------------------------------------------------------------------------
-- kpi.objetivos_de_pedido(empr_id, petr_id) — las metas de un pedido y de sus hitos, con el
-- estado efectivo, la línea base y el valor actual (solo KPIs de tools; los de Mantenimiento
-- los completa quien llama, porque el valor vive en AssetPlanner).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION kpi.objetivos_de_pedido(p_empr_id integer, p_petr_id integer)
RETURNS TABLE (objetivo_id integer, kpi varchar, descripcion varchar, fuente varchar, operador varchar,
               meta numeric, desde date, hasta date, responsable varchar, petr_id integer,
               hito_id integer, hito varchar, estado varchar, usuario_alta varchar, fec_alta timestamp,
               linea_base numeric, linea_base_fecha date, valor_actual numeric, calculado_en timestamp,
               cumple boolean)
LANGUAGE sql
STABLE
AS $function$
    SELECT o.objetivo_id, o.kpi, d.descripcion, o.fuente, o.operador, o.meta, o.desde, o.hasta,
           o.responsable, o.petr_id, o.hito_id,
           (CASE WHEN h.hito_id IS NULL THEN NULL
                 ELSE coalesce('Hito ' || h.nro || ' · ', '') || coalesce(h.numero, '') END)::varchar,
           (CASE WHEN o.estado = 'vigente' AND o.hasta < current_date THEN 'vencido' ELSE o.estado END)::varchar,
           o.usuario_alta, o.fec_alta, o.linea_base, o.linea_base_fecha,
           c.valor, c.calculado_en,
           CASE WHEN c.valor IS NULL THEN NULL
                WHEN o.operador = '>=' THEN c.valor >= o.meta
                ELSE c.valor <= o.meta END
      FROM kpi.objetivos o
      LEFT JOIN tst.hitos h ON h.hito_id = o.hito_id
      LEFT JOIN kpi.definiciones d ON d.nombre = o.kpi AND o.fuente = 'tools'
      LEFT JOIN kpi.cache c ON o.fuente = 'tools' AND c.nombre = o.kpi AND c.empr_id = o.empr_id
     WHERE o.empr_id = p_empr_id
       AND o.petr_id = p_petr_id
       AND o.estado <> 'cancelado'
     ORDER BY o.hito_id NULLS FIRST, o.hasta, o.objetivo_id;
$function$;
