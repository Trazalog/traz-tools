-- =============================================================================
-- 022 - Catalogo: las tools de indicadores (KPI-TOOLS, ADR-A9)
-- =============================================================================
-- Idempotente. Rollback: 022-tools-kpi.rollback.sql
--
-- Las cuatro operaciones de lectura del motor de KPIs que publica toolsMCPAPI
-- (/mcp/kpi/*). Sin estas filas ningun agente las puede usar, aunque las
-- tenga en su configuracion (011): Quirqui tiene kpi_get_valor; Kuntur, kpi_get_*.
-- Las metas las graba el administrador desde Tools, no un agente (ADR-A8).
-- =============================================================================

\set ON_ERROR_STOP on

INSERT INTO agente.tool (nombre, modulo, clase, riesgo, reversible, descripcion)
VALUES
    ('kpi_get_valor',     'kpi', 'lectura', 'bajo', true, 'Valor de hoy de un indicador de la empresa (o de todos)'),
    ('kpi_get_historico', 'kpi', 'lectura', 'bajo', true, 'Historia diaria de un indicador'),
    ('kpi_get_objetivos', 'kpi', 'lectura', 'bajo', true, 'Metas de la empresa, con el valor de hoy y si se cumplen'),
    ('kpi_get_desvios',   'kpi', 'lectura', 'bajo', true, 'Metas vigentes que hoy no se cumplen, con la tendencia')
ON CONFLICT (nombre) DO UPDATE SET
    modulo      = EXCLUDED.modulo,
    clase       = EXCLUDED.clase,
    riesgo      = EXCLUDED.riesgo,
    reversible  = EXCLUDED.reversible,
    descripcion = EXCLUDED.descripcion,
    fec_mod     = now();

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('022-tools-kpi', 'Catalogo: tools de indicadores (kpi_get_*)')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();
