-- Rollback de 011-agentes.sql
--
-- Borra la configuracion de los agentes. El orquestador deja de poder
-- responder hasta que se vuelva a aplicar 011: sin configuracion no sabe que
-- agente es ni que prompt usar.
\set ON_ERROR_STOP on

DROP TABLE IF EXISTS agente.agente;

DELETE FROM agente.schema_version WHERE script = '011-agentes';
