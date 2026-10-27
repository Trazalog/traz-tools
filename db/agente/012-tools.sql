-- =============================================================================
-- 012 - Catalogo de tools y lista blanca efectiva por agente
-- =============================================================================
-- Idempotente. Rollback: 012-tools.rollback.sql
--
-- ADR-A8 (decision del PM, 2026-10-27): los agentes DICEN COMO, NO HACEN. Este
-- script es lo que lo hace cumplir.
--
-- Cada tool que publica el MCP Gateway se cataloga aca con su clase:
--
--   lectura     trae datos; no cambia nada (GET).
--   generacion  produce un texto o un calculo nuevo sin tocar datos del negocio.
--   accion      cambia algo en el sistema: crea una OT, un pedido, un caso
--               de Bonita. NINGUN agente puede usarlas, sin excepcion.
--
-- Una tool es usable por un agente solo si se cumplen las TRES condiciones:
--
--   1. esta en este catalogo,
--   2. no es de clase 'accion',
--   3. coincide con alguno de los patrones de agente.agente.tools_permitidas.
--
-- Falla cerrado: si manana el gateway publica una tool nueva, ningun agente la
-- ve hasta que alguien la catalogue aca y decida su clase. Una tool de
-- escritura nueva no puede colarse por un patron como 'man_*'.
--
-- La fuente de las tools es doc/api/trazalog-operaciones.yaml (el contrato del
-- MCP Gateway). tests/test_tools.py verifica que todo lo que esta ahi este
-- catalogado y que todo lo que no es GET sea 'accion'.
-- =============================================================================

\set ON_ERROR_STOP on

CREATE TABLE IF NOT EXISTS agente.tool (
    nombre      text        PRIMARY KEY,
    modulo      text        NOT NULL,
    clase       text        NOT NULL,
    riesgo      text        NOT NULL,
    -- 'interno' = una llamada a nuestro MCP; 'externo' = un servicio de
    -- terceros que puede costar o tener limites (por ejemplo, la busqueda web).
    costo       text        NOT NULL DEFAULT 'interno',
    reversible  boolean     NOT NULL,
    descripcion text        NOT NULL,
    fec_alta    timestamptz NOT NULL DEFAULT now(),
    fec_mod     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT tool_nombre_ck CHECK (nombre ~ '^[a-z][a-z0-9_]{2,60}$'),
    CONSTRAINT tool_modulo_ck CHECK (modulo IN ('man', 'alm', 'pan', 'core', 'kpi', 'tar', 'web')),
    CONSTRAINT tool_clase_ck  CHECK (clase IN ('lectura', 'generacion', 'accion')),
    CONSTRAINT tool_riesgo_ck CHECK (riesgo IN ('bajo', 'medio', 'alto')),
    CONSTRAINT tool_costo_ck  CHECK (costo IN ('interno', 'externo')),
    -- Lo que no cambia nada es reversible por definicion; lo que cambia algo
    -- no puede declararse de riesgo bajo.
    CONSTRAINT tool_lectura_reversible_ck CHECK (clase <> 'lectura' OR reversible),
    CONSTRAINT tool_accion_riesgo_ck      CHECK (clase <> 'accion' OR riesgo <> 'bajo')
);

COMMENT ON TABLE agente.tool IS
    'Catalogo de tools del MCP Gateway con su clase (ADR-A8). Una tool fuera de '
    'este catalogo, o de clase accion, no la puede usar ningun agente.';

REVOKE ALL ON agente.tool FROM agente_app;
GRANT SELECT ON agente.tool TO agente_app, agente_curador;

-- -----------------------------------------------------------------------------
-- Las tools que un conjunto de patrones alcanza de verdad: catalogo + clase.
--
-- Los patrones son tipo glob ('man_get_*'). Se traducen a LIKE escapando el
-- guion bajo, que en LIKE es comodin: sin eso, 'man_get_*' tambien dejaria
-- pasar 'manXgetXalgo'.
--
-- Esta separada de tools_permitidas() para poder probar el filtro de clase con
-- un patron amplio ('man_*') sin tener que darselo a ningun agente: es la
-- defensa para el dia que alguien escriba un patron asi.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION agente.tools_por_patrones(p_patrones text[])
RETURNS SETOF text
LANGUAGE sql
STABLE
AS $$
    SELECT DISTINCT t.nombre
    FROM unnest(p_patrones) AS patron
    JOIN agente.tool t
      ON t.nombre LIKE replace(replace(patron, '_', '\_'), '*', '%')
    WHERE t.clase <> 'accion'
    ORDER BY t.nombre
$$;

COMMENT ON FUNCTION agente.tools_por_patrones(text[]) IS
    'Tools catalogadas y no de accion que alcanzan los patrones dados.';

-- Las tools que un agente puede usar: las de sus patrones, pasadas por el filtro.
CREATE OR REPLACE FUNCTION agente.tools_permitidas(p_clave text)
RETURNS SETOF text
LANGUAGE sql
STABLE
AS $$
    SELECT agente.tools_por_patrones(a.tools_permitidas)
    FROM agente.agente a
    WHERE a.clave = p_clave
$$;

COMMENT ON FUNCTION agente.tools_permitidas(text) IS
    'Tools que el agente puede usar: catalogadas, no de accion, y dentro de su lista blanca.';

REVOKE ALL ON FUNCTION agente.tools_por_patrones(text[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION agente.tools_permitidas(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agente.tools_por_patrones(text[]) TO agente_app, agente_curador;
GRANT EXECUTE ON FUNCTION agente.tools_permitidas(text) TO agente_app, agente_curador;

-- -----------------------------------------------------------------------------
-- Seed: las 25 operaciones de doc/api/trazalog-operaciones.yaml.
-- Editar aca y volver a aplicar actualiza por nombre.
-- -----------------------------------------------------------------------------
INSERT INTO agente.tool (nombre, modulo, clase, riesgo, reversible, descripcion)
VALUES
    -- Mantenimiento
    ('man_get_equipos',            'man',  'lectura', 'bajo', true,  'Lista de equipos de la empresa'),
    ('man_get_equipo',             'man',  'lectura', 'bajo', true,  'Ficha de un equipo'),
    ('man_get_ots',                'man',  'lectura', 'bajo', true,  'Ordenes de trabajo'),
    ('man_get_ot',                 'man',  'lectura', 'bajo', true,  'Detalle de una orden de trabajo'),
    ('man_get_lecturas',           'man',  'lectura', 'bajo', true,  'Lecturas de horometros y contadores'),
    ('man_get_preventivos',        'man',  'lectura', 'bajo', true,  'Planes de mantenimiento preventivo'),
    ('man_get_kpi_disponibilidad', 'man',  'lectura', 'bajo', true,  'KPI de disponibilidad'),
    ('man_get_kpi_mttr',           'man',  'lectura', 'bajo', true,  'KPI MTTR'),
    ('man_get_kpi_mttf',           'man',  'lectura', 'bajo', true,  'KPI MTTF'),
    ('man_get_kpi_fallas',         'man',  'lectura', 'bajo', true,  'KPI de fallas'),
    -- Crea una OT y un caso en Bonita: cambia el sistema y no se deshace solo.
    ('man_create_ot',              'man',  'accion',  'alto', false, 'Crea una orden de trabajo y su caso en Bonita'),
    -- Core
    ('core_get_empresa_actual',    'core', 'lectura', 'bajo', true,  'Empresa del usuario autenticado'),
    -- Pañol
    ('pan_get_herramientas',       'pan',  'lectura', 'bajo', true,  'Herramientas del pañol'),
    ('pan_get_herramienta',        'pan',  'lectura', 'bajo', true,  'Ficha de una herramienta'),
    ('pan_get_movimientos',        'pan',  'lectura', 'bajo', true,  'Movimientos de herramientas'),
    ('pan_get_certificaciones',    'pan',  'lectura', 'bajo', true,  'Certificaciones de herramientas'),
    -- Almacenes
    ('alm_get_stock',              'alm',  'lectura', 'bajo', true,  'Stock por deposito'),
    ('alm_get_depositos',          'alm',  'lectura', 'bajo', true,  'Depositos de la empresa'),
    ('alm_get_vencimientos',       'alm',  'lectura', 'bajo', true,  'Articulos vencidos o por vencer'),
    ('alm_get_movimientos',        'alm',  'lectura', 'bajo', true,  'Movimientos de stock'),
    ('alm_get_entregas',           'alm',  'lectura', 'bajo', true,  'Entregas de materiales'),
    ('alm_get_movimientos_internos','alm', 'lectura', 'bajo', true,  'Movimientos internos entre depositos'),
    ('alm_get_pedidos_materiales', 'alm',  'lectura', 'bajo', true,  'Pedidos de materiales'),
    ('alm_get_pedido_material',    'alm',  'lectura', 'bajo', true,  'Detalle de un pedido de materiales'),
    -- Crea un pedido y su caso en Bonita.
    ('alm_crear_pedido_materiales','alm',  'accion',  'alto', false, 'Crea un pedido de materiales y su caso en Bonita')
ON CONFLICT (nombre) DO UPDATE SET
    modulo      = EXCLUDED.modulo,
    clase       = EXCLUDED.clase,
    riesgo      = EXCLUDED.riesgo,
    reversible  = EXCLUDED.reversible,
    descripcion = EXCLUDED.descripcion,
    fec_mod     = now();

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('012-tools', 'Catalogo de tools y lista blanca efectiva por agente (ADR-A8)')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();
