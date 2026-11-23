-- Rollback de 029-tools-tar.sql
\set ON_ERROR_STOP on

DELETE FROM agente.tool
 WHERE nombre IN ('tar_get_pedidos', 'tar_get_pedido', 'tar_get_tareas', 'tar_get_atrasadas');

DELETE FROM agente.schema_version WHERE script = '029-tools-tar';
