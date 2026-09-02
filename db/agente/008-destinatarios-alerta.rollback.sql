-- Rollback de 008-destinatarios-alerta.sql
-- Borra la configuracion de destinatarios de alertas de todas las empresas.
\set ON_ERROR_STOP on

DROP FUNCTION IF EXISTS agente.destinatarios_de(integer, text);
DROP TRIGGER  IF EXISTS destinatario_set_fec_mod ON agente.destinatario_alerta;
DROP TABLE    IF EXISTS agente.destinatario_alerta;

DELETE FROM agente.schema_version WHERE script = '008-destinatarios-alerta';
