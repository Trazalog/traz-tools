-- Rollback de 022-tools-kpi.sql: los agentes dejan de alcanzar las tools de indicadores.
\set ON_ERROR_STOP on
DELETE FROM agente.tool WHERE nombre IN ('kpi_get_valor', 'kpi_get_historico', 'kpi_get_objetivos', 'kpi_get_desvios');
DELETE FROM agente.schema_version WHERE script = '022-tools-kpi';
