-- Rollback de 006-entrevistador.sql
-- ATENCION: borra el conocimiento capturado a expertos que todavia no fue
-- promovido a agente.chunk. Los chunks ya promovidos quedan, pero pierden la
-- trazabilidad hacia el hecho y la sesion que los originaron.
\set ON_ERROR_STOP on

DROP VIEW     IF EXISTS agente.v_hechos_para_validar;
DROP TRIGGER  IF EXISTS validacion_no_autovalida ON agente.validacion_cruzada;
DROP FUNCTION IF EXISTS agente.tg_validacion_no_autovalida();
DROP TABLE    IF EXISTS agente.validacion_cruzada;
DROP TABLE    IF EXISTS agente.hecho;
DROP TABLE    IF EXISTS agente.sesion_entrevista;
DROP TABLE    IF EXISTS agente.experto;
DROP TRIGGER  IF EXISTS tema_set_fec_mod ON agente.tema;
DROP TABLE    IF EXISTS agente.tema;

DELETE FROM agente.schema_version WHERE script = '006-entrevistador';
