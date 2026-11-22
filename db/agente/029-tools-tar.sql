-- =============================================================================
-- 029 - Catalogo: las tools de lectura del modulo de Tareas (AGENTE-TAR-01, TAR-API)
-- =============================================================================
-- Idempotente. Rollback: 029-tools-tar.rollback.sql
--
-- Las cuatro operaciones de lectura de Tareas que publica toolsMCPAPI
-- (/mcp/tar/*): pedidos de trabajo, un pedido con sus hitos y tareas, tareas y
-- tareas atrasadas. Kuntur y Quirqui ya tienen el patron 'tar_get_*' en su
-- configuracion (011): sin estas filas ninguno las podia usar.
-- Solo leen; la empresa sale del token (analisis:
-- doc/agente/analisis-impacto-tar-lectura.md).
-- =============================================================================

\set ON_ERROR_STOP on

INSERT INTO agente.tool (nombre, modulo, clase, riesgo, reversible, descripcion)
VALUES
    ('tar_get_pedidos',   'tar', 'lectura', 'bajo', true, 'Pedidos de trabajo de la empresa (sin los finalizados, salvo que se pidan)'),
    ('tar_get_pedido',    'tar', 'lectura', 'bajo', true, 'Un pedido de trabajo con sus hitos y las tareas de cada hito'),
    ('tar_get_tareas',    'tar', 'lectura', 'bajo', true, 'Tareas planificadas de la empresa o de un hito, con estado, responsable y fechas'),
    ('tar_get_atrasadas', 'tar', 'lectura', 'bajo', true, 'Tareas no finalizadas cuyo vencimiento ya paso, con los dias de atraso')
ON CONFLICT (nombre) DO UPDATE SET
    modulo      = EXCLUDED.modulo,
    clase       = EXCLUDED.clase,
    riesgo      = EXCLUDED.riesgo,
    reversible  = EXCLUDED.reversible,
    descripcion = EXCLUDED.descripcion,
    fec_mod     = now();

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('029-tools-tar', 'Catalogo: tools de lectura de Tareas (tar_get_*)')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();
