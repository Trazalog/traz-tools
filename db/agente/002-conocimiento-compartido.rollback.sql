-- Rollback de 002-conocimiento-compartido.sql
-- ATENCION: borra la base de conocimiento minero curada -- el activo central
-- del producto. Recuperarla significa re-ingestar documentos y re-entrevistar
-- expertos. No es una operacion de rutina.
\set ON_ERROR_STOP on

DROP TRIGGER IF EXISTS chunk_set_fec_mod ON agente.chunk;
DROP TABLE   IF EXISTS agente.chunk;
DROP TABLE   IF EXISTS agente.fuente;
-- tg_set_fec_mod la comparte tema (006); se borra solo si 006 ya no esta.
DROP FUNCTION IF EXISTS agente.tg_set_fec_mod();

DELETE FROM agente.schema_version WHERE script = '002-conocimiento-compartido';
