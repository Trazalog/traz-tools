-- Rollback de v2.8.1.8/kpi_metas_pedido_hito.sql: vuelve kpi.objetivo_guardar() a la versión
-- de v2.8.1.6 y borra kpi.objetivos_de_pedido().
--
-- ⚠️ Las metas de pedido y de hito ya cargadas NO se borran: siguen en kpi.objetivos con su
-- petr_id, y el Tablero las sigue mostrando. Las columnas hito_id, linea_base y
-- linea_base_fecha quedan (borrarlas perdería datos). Si de verdad se quieren sacar:
--   ALTER TABLE kpi.objetivos DROP COLUMN hito_id, DROP COLUMN linea_base, DROP COLUMN linea_base_fecha;

DROP FUNCTION IF EXISTS kpi.objetivos_de_pedido(integer, integer);
DROP FUNCTION IF EXISTS kpi.objetivo_guardar(integer, varchar, varchar, varchar, numeric, date, date, varchar, varchar, varchar, integer, integer, numeric);
DROP INDEX IF EXISTS kpi.objetivos_pedido_ix;

CREATE OR REPLACE FUNCTION kpi.objetivo_guardar(
    p_empr_id integer, p_kpi varchar, p_fuente varchar, p_operador varchar, p_meta numeric,
    p_desde date, p_hasta date, p_responsable varchar, p_propuesto_por varchar, p_usuario varchar)
RETURNS integer
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id integer;
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
    IF EXISTS (SELECT 1 FROM kpi.objetivos
                WHERE empr_id = p_empr_id AND kpi = p_kpi AND estado = 'vigente'
                  AND hasta >= current_date) THEN
        RAISE EXCEPTION 'ya hay un objetivo vigente para %: cancelalo antes de cargar otro', p_kpi;
    END IF;
    INSERT INTO kpi.objetivos (empr_id, kpi, fuente, operador, meta, desde, hasta, responsable,
                               propuesto_por, usuario_alta)
    VALUES (p_empr_id, p_kpi, coalesce(p_fuente, 'tools'), p_operador, p_meta,
            coalesce(p_desde, current_date), p_hasta, nullif(p_responsable, ''),
            CASE WHEN p_propuesto_por = 'kuntur' THEN 'kuntur' ELSE 'usuario' END, p_usuario)
    RETURNING objetivo_id INTO v_id;
    RETURN v_id;
END;
$function$;
