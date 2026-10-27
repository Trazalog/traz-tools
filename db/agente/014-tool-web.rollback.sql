-- Rollback de 014-tool-web.sql
--
-- Saca web_buscar del catalogo: ningun agente la puede usar, aunque este en su
-- configuracion y haya un SearXNG configurado.
\set ON_ERROR_STOP on

DELETE FROM agente.tool WHERE nombre = 'web_buscar';
DELETE FROM agente.schema_version WHERE script = '014-tool-web';
