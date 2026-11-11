-- Rollback de v2.8.1.6/kpi_objetivos.sql: kpi.publicar() vuelve a la versión de v2.8.1.4 y se
-- borran la historia y los objetivos. kpi.cache y el Tablero no se tocan.
-- ATENCIÓN: la historia y los objetivos cargados se pierden.

CREATE OR REPLACE FUNCTION kpi.publicar()
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN
    INSERT INTO kpi.cache(nombre, empr_id, valor, valor_json, calculado_en, vence_en)
    SELECT nombre, empr_id, valor, valor_json, calculado_en, vence_en FROM kpi.cache_tmp
    ON CONFLICT (nombre, empr_id) DO UPDATE
       SET valor = excluded.valor, valor_json = excluded.valor_json,
           calculado_en = excluded.calculado_en, vence_en = excluded.vence_en;

    -- limpio el staging ya publicado
    DELETE FROM kpi.cache_tmp;
END;
$function$;

DROP FUNCTION IF EXISTS kpi.objetivo_cancelar(integer, integer, varchar);
DROP FUNCTION IF EXISTS kpi.objetivo_guardar(integer, varchar, varchar, varchar, numeric, date, date, varchar, varchar, varchar);
DROP FUNCTION IF EXISTS kpi.desvios(integer);
DROP FUNCTION IF EXISTS kpi.objetivos_de(integer, boolean);
DROP TABLE IF EXISTS kpi.objetivos;
DROP TABLE IF EXISTS kpi.historico;
