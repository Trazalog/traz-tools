-- Rollback de 019-contrato-coach.sql: borra el contrato y lo medido.
\set ON_ERROR_STOP on
DROP TABLE IF EXISTS agente.avance_plan;
DROP TABLE IF EXISTS agente.medicion_resultado;
DROP TABLE IF EXISTS agente.medicion_pedida;
DELETE FROM agente.schema_version WHERE script = '019-contrato-coach';
