-- Rollback de 004-cola-candidatos.sql
-- Borra la cola de curaduria pendiente.
\set ON_ERROR_STOP on

DROP TABLE IF EXISTS agente.candidato;

DELETE FROM agente.schema_version WHERE script = '004-cola-candidatos';
