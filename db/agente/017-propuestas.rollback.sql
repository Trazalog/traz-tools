-- Rollback de 017-propuestas.sql
--
-- Borra las propuestas y lo que cada usuario hizo con ellas. Quirqui deja de
-- proponer el siguiente paso hasta que se vuelva a aplicar 017.
\set ON_ERROR_STOP on

DROP TABLE IF EXISTS agente.propuesta;
DELETE FROM agente.schema_version WHERE script = '017-propuestas';
