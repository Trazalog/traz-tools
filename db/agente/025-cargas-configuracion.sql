-- =============================================================================
-- 025 - Kuntur graba configuracion con confirmacion del administrador (ADR-A12)
-- =============================================================================
-- Idempotente. Rollback: 025-cargas-configuracion.rollback.sql
--
-- ADR-A12 abre una excepcion acotada a ADR-A8 (agentes de solo lectura) para
-- la puesta en marcha de la empresa:
--
--   * Clase nueva de tool: 'configuracion' (altas y cambios de datos de
--     configuracion: depositos, unidades, tipos, ABM de Mantenimiento, menus y
--     roles). Las de 'accion' (ordenes de trabajo, pedidos) siguen afuera.
--   * Una tool de configuracion NO entra por los patrones de la lista blanca
--     (tools_por_patrones la excluye, igual que a las de accion): el agente la
--     tiene que nombrar EXACTA en su columna nueva tools_configuracion. Asi un
--     patron como 'alm_*' no habilita una escritura sin que nadie lo decida.
--   * Cuando el agente la "llama", el motor no la ejecuta: guarda una carga
--     PROPUESTA (agente.carga_propuesta) y el panel la muestra como tarjeta.
--     Se ejecuta solo cuando el administrador toca "Cargar", con SU token, y
--     se registra quien la confirmo y que devolvio.
-- =============================================================================

\set ON_ERROR_STOP on

-- -----------------------------------------------------------------------------
-- Catalogo: la clase y el modulo nuevos
-- -----------------------------------------------------------------------------
ALTER TABLE agente.tool DROP CONSTRAINT IF EXISTS tool_clase_ck;
ALTER TABLE agente.tool ADD CONSTRAINT tool_clase_ck
    CHECK (clase IN ('lectura', 'generacion', 'accion', 'configuracion'));
ALTER TABLE agente.tool DROP CONSTRAINT IF EXISTS tool_modulo_ck;
ALTER TABLE agente.tool ADD CONSTRAINT tool_modulo_ck
    CHECK (modulo IN ('man', 'alm', 'pan', 'core', 'kpi', 'tar', 'web', 'dnato'));

COMMENT ON TABLE agente.tool IS
    'Catalogo de tools del MCP Gateway con su clase (ADR-A8). Una tool fuera de este catalogo, '
    'o de clase accion, no la puede usar ningun agente; las de configuracion solo con '
    'confirmacion del administrador y nombradas una por una (ADR-A12).';

-- -----------------------------------------------------------------------------
-- La lista blanca: las de configuracion, por nombre exacto
-- -----------------------------------------------------------------------------
ALTER TABLE agente.agente
    ADD COLUMN IF NOT EXISTS tools_configuracion text[] NOT NULL DEFAULT '{}';

COMMENT ON COLUMN agente.agente.tools_configuracion IS
    'Tools de clase configuracion que el agente puede PROPONER (ADR-A12), por nombre exacto, sin '
    'comodines. Se ejecutan solo con la confirmacion del administrador.';

CREATE OR REPLACE FUNCTION agente.tools_por_patrones(p_patrones text[])
RETURNS SETOF text
LANGUAGE sql
STABLE
AS $$
    SELECT DISTINCT t.nombre
    FROM unnest(p_patrones) AS patron
    JOIN agente.tool t
      ON t.nombre LIKE replace(replace(patron, '_', '\_'), '*', '%')
    WHERE t.clase NOT IN ('accion', 'configuracion')
    ORDER BY t.nombre
$$;

COMMENT ON FUNCTION agente.tools_por_patrones(text[]) IS
    'Tools catalogadas que alcanzan los patrones dados, sin las de accion ni las de configuracion.';

CREATE OR REPLACE FUNCTION agente.tools_permitidas(p_clave text)
RETURNS SETOF text
LANGUAGE sql
STABLE
AS $$
    SELECT agente.tools_por_patrones(a.tools_permitidas)
    FROM agente.agente a
    WHERE a.clave = p_clave
    UNION
    SELECT t.nombre
    FROM agente.agente a
    JOIN agente.tool t ON t.nombre = ANY (a.tools_configuracion) AND t.clase = 'configuracion'
    WHERE a.clave = p_clave
$$;

COMMENT ON FUNCTION agente.tools_permitidas(text) IS
    'Tools que el agente puede usar: las de lectura y generacion de su lista blanca, mas las de '
    'configuracion nombradas una por una (ADR-A12). Nunca las de accion.';

CREATE OR REPLACE FUNCTION agente.tools_de_configuracion(p_clave text)
RETURNS SETOF text
LANGUAGE sql
STABLE
AS $$
    SELECT t.nombre
    FROM agente.agente a
    JOIN agente.tool t ON t.nombre = ANY (a.tools_configuracion) AND t.clase = 'configuracion'
    WHERE a.clave = p_clave
    ORDER BY t.nombre
$$;

COMMENT ON FUNCTION agente.tools_de_configuracion(text) IS
    'Las tools que el motor NO ejecuta: las convierte en una carga propuesta (ADR-A12).';

REVOKE ALL ON FUNCTION agente.tools_por_patrones(text[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION agente.tools_permitidas(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION agente.tools_de_configuracion(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agente.tools_por_patrones(text[]) TO agente_app, agente_curador;
GRANT EXECUTE ON FUNCTION agente.tools_permitidas(text) TO agente_app, agente_curador;
GRANT EXECUTE ON FUNCTION agente.tools_de_configuracion(text) TO agente_app, agente_curador;

-- -----------------------------------------------------------------------------
-- Las cargas propuestas
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agente.carga_propuesta (
    carga_id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    empr_id          integer     NOT NULL,
    interaccion_id   uuid,                   -- la corrida en la que se propuso
    agente           text        NOT NULL,
    tool             text        NOT NULL,
    argumentos       jsonb       NOT NULL,
    usuario          text        NOT NULL,   -- a quien se le propuso
    estado           text        NOT NULL DEFAULT 'propuesta',
    confirmado_por   text,
    resultado        jsonb,
    fec_alta         timestamptz NOT NULL DEFAULT now(),
    fec_respuesta    timestamptz,
    CONSTRAINT carga_propuesta_estado_ck
        CHECK (estado IN ('propuesta', 'ejecutada', 'fallida', 'descartada', 'vencida'))
);

CREATE INDEX IF NOT EXISTS carga_propuesta_empresa_ix ON agente.carga_propuesta (empr_id, fec_alta DESC);

COMMENT ON TABLE agente.carga_propuesta IS
    'Lo que Kuntur propuso grabar con una tool de configuracion (ADR-A12). Se ejecuta solo con la '
    'confirmacion del administrador, con su token; aca queda quien confirmo y que devolvio.';

ALTER TABLE agente.carga_propuesta ENABLE ROW LEVEL SECURITY;
ALTER TABLE agente.carga_propuesta FORCE  ROW LEVEL SECURITY;
DROP POLICY IF EXISTS carga_propuesta_aislamiento ON agente.carga_propuesta;
CREATE POLICY carga_propuesta_aislamiento ON agente.carga_propuesta
    USING (empr_id = NULLIF(current_setting('agente.empr_id', true), '')::integer)
    WITH CHECK (empr_id = NULLIF(current_setting('agente.empr_id', true), '')::integer);
GRANT SELECT, INSERT, UPDATE ON agente.carga_propuesta TO agente_app;
GRANT SELECT ON agente.carga_propuesta TO agente_curador;

-- En la corrida, la llamada a una tool de configuracion queda como 'propuesta':
-- no salio al MCP. La ejecucion (si el administrador confirma) queda en la carga.
ALTER TABLE agente.tool_llamada DROP CONSTRAINT IF EXISTS tool_llamada_status_ck;
ALTER TABLE agente.tool_llamada ADD CONSTRAINT tool_llamada_status_ck
    CHECK (status IN ('ok', 'error', 'bloqueada', 'propuesta'));

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('025-cargas-configuracion', 'Kuntur graba configuracion con confirmacion del administrador (ADR-A12)')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();
