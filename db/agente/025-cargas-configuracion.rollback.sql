-- Rollback de 025-cargas-configuracion.sql
-- Antes de correrlo: no puede quedar ninguna tool de clase 'configuracion' ni
-- de modulo 'dnato' en agente.tool (el CHECK de vuelta las rechazaria).
\set ON_ERROR_STOP on

DROP TABLE IF EXISTS agente.carga_propuesta;
DELETE FROM agente.tool_llamada WHERE status = 'propuesta';
ALTER TABLE agente.tool_llamada DROP CONSTRAINT IF EXISTS tool_llamada_status_ck;
ALTER TABLE agente.tool_llamada ADD CONSTRAINT tool_llamada_status_ck CHECK (status IN ('ok', 'error', 'bloqueada'));
DROP FUNCTION IF EXISTS agente.tools_de_configuracion(text);

CREATE OR REPLACE FUNCTION agente.tools_por_patrones(p_patrones text[])
RETURNS SETOF text
LANGUAGE sql
STABLE
AS $$
    SELECT DISTINCT t.nombre
    FROM unnest(p_patrones) AS patron
    JOIN agente.tool t
      ON t.nombre LIKE replace(replace(patron, '_', '\_'), '*', '%')
    WHERE t.clase <> 'accion'
    ORDER BY t.nombre
$$;

CREATE OR REPLACE FUNCTION agente.tools_permitidas(p_clave text)
RETURNS SETOF text
LANGUAGE sql
STABLE
AS $$
    SELECT agente.tools_por_patrones(a.tools_permitidas)
    FROM agente.agente a
    WHERE a.clave = p_clave
$$;

ALTER TABLE agente.agente DROP COLUMN IF EXISTS tools_configuracion;

ALTER TABLE agente.tool DROP CONSTRAINT IF EXISTS tool_clase_ck;
ALTER TABLE agente.tool ADD CONSTRAINT tool_clase_ck CHECK (clase IN ('lectura', 'generacion', 'accion'));
ALTER TABLE agente.tool DROP CONSTRAINT IF EXISTS tool_modulo_ck;
ALTER TABLE agente.tool ADD CONSTRAINT tool_modulo_ck
    CHECK (modulo IN ('man', 'alm', 'pan', 'core', 'kpi', 'tar', 'web'));

DELETE FROM agente.schema_version WHERE script = '025-cargas-configuracion';
