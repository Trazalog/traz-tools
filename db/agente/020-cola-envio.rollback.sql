-- Rollback de 020-cola-envio.sql: vuelve a los permisos de 007 (sin RLS en
-- dispositivo y el orquestador leyendo la cola).
\set ON_ERROR_STOP on
DROP POLICY IF EXISTS dispositivo_aislamiento_empresa ON agente.dispositivo;
ALTER TABLE agente.dispositivo NO FORCE ROW LEVEL SECURITY;
ALTER TABLE agente.dispositivo DISABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON agente.envio TO agente_app;
REVOKE ALL ON agente.envio FROM agente_envio;
REVOKE USAGE ON SCHEMA agente FROM agente_envio;
DROP ROLE IF EXISTS agente_envio;
DELETE FROM agente.schema_version WHERE script = '020-cola-envio';
