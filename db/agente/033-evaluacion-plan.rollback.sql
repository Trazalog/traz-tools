-- Rollback de 033-evaluacion-plan.sql
-- Borra las evaluaciones y los candidatos PENDIENTES que salieron de un plan
-- (los revisados por un curador se dejan como 'patron_operativo' para no
-- perder la decision del curador), y vuelve el CHECK de origen a 004.
\set ON_ERROR_STOP on

DROP TABLE IF EXISTS agente.evaluacion_plan;

DELETE FROM agente.candidato WHERE origen = 'plan_accion' AND estado = 'pendiente';
UPDATE agente.candidato SET origen = 'patron_operativo' WHERE origen = 'plan_accion';

ALTER TABLE agente.candidato DROP CONSTRAINT IF EXISTS candidato_origen_ck;
ALTER TABLE agente.candidato ADD CONSTRAINT candidato_origen_ck
    CHECK (origen IN ('patron_operativo', 'entrevista', 'documento', 'feedback'));

DELETE FROM agente.schema_version WHERE script = '033-evaluacion-plan';
