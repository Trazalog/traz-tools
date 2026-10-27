-- Rollback de 012-tools.sql
--
-- Sin catalogo, el orquestador no puede armar la lista de tools permitidas y
-- no responde: falla cerrado, nunca abierto. Para volver a usarlo hay que
-- re-aplicar 012.
\set ON_ERROR_STOP on

DROP FUNCTION IF EXISTS agente.tools_permitidas(text);
DROP FUNCTION IF EXISTS agente.tools_por_patrones(text[]);
DROP TABLE IF EXISTS agente.tool;

DELETE FROM agente.schema_version WHERE script = '012-tools';
