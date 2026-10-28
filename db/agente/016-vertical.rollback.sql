-- Rollback de 016-vertical.sql
--
-- Saca la vertical del conocimiento y de la taxonomia, y borra los perfiles de
-- empresa: el agente vuelve a recuperar todo el conocimiento para todos.
\set ON_ERROR_STOP on

DROP TABLE IF EXISTS agente.perfil_empresa;
DROP INDEX IF EXISTS agente.chunk_vertical_ix;
ALTER TABLE agente.chunk DROP CONSTRAINT IF EXISTS chunk_vertical_ck, DROP COLUMN IF EXISTS vertical;
ALTER TABLE agente.tema  DROP CONSTRAINT IF EXISTS tema_vertical_ck,  DROP COLUMN IF EXISTS vertical;

DELETE FROM agente.schema_version WHERE script = '016-vertical';
