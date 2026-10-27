-- Rollback de 013-corrida.sql
--
-- Borra el detalle de tools de las corridas (agente.tool_llamada) y las
-- columnas nuevas de interaccion, con lo que tuvieran. Saca tambien el RLS de
-- interaccion y feedback: quedan como antes de 013, protegidas solo por el
-- WHERE del codigo.
\set ON_ERROR_STOP on

ALTER VIEW IF EXISTS agente.v_feedback_negativo RESET (security_invoker);

DROP POLICY IF EXISTS feedback_aislamiento_empresa ON agente.feedback;
DROP POLICY IF EXISTS interaccion_aislamiento_empresa ON agente.interaccion;
ALTER TABLE agente.feedback    NO FORCE ROW LEVEL SECURITY;
ALTER TABLE agente.feedback    DISABLE ROW LEVEL SECURITY;
ALTER TABLE agente.interaccion NO FORCE ROW LEVEL SECURITY;
ALTER TABLE agente.interaccion DISABLE ROW LEVEL SECURITY;

DROP TABLE IF EXISTS agente.tool_llamada;

DROP INDEX IF EXISTS agente.interaccion_con_incidentes_ix;
DROP INDEX IF EXISTS agente.interaccion_agente_fecha_ix;
ALTER TABLE agente.interaccion
    DROP CONSTRAINT IF EXISTS interaccion_disparador_ck,
    DROP COLUMN IF EXISTS incidentes,
    DROP COLUMN IF EXISTS controles,
    DROP COLUMN IF EXISTS costo_usd,
    DROP COLUMN IF EXISTS disparador,
    DROP COLUMN IF EXISTS agente;

DELETE FROM agente.schema_version WHERE script = '013-corrida';
