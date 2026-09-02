-- Rollback de 005-feedback.sql
-- Borra el historial de interacciones y calificaciones: es el insumo del ciclo
-- de mejora, no se recupera.
\set ON_ERROR_STOP on

DROP VIEW  IF EXISTS agente.v_feedback_negativo;
DROP TABLE IF EXISTS agente.feedback;
DROP TABLE IF EXISTS agente.interaccion;

DELETE FROM agente.schema_version WHERE script = '005-feedback';
