-- Rollback de 007-notificaciones.sql
-- Borra los tokens de dispositivo registrados y el historial de notificaciones.
\set ON_ERROR_STOP on

DROP FUNCTION IF EXISTS agente.expandir_envios(bigint);
DROP TABLE IF EXISTS agente.envio;
DROP TABLE IF EXISTS agente.notificacion;
DROP TABLE IF EXISTS agente.dispositivo;

DELETE FROM agente.schema_version WHERE script = '007-notificaciones';
