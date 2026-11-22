-- =============================================================================
-- 031 - Plan de accion de Kuntur, opcion B (ADR-A13, AGENTE-CO-04)
-- =============================================================================
-- Idempotente. Rollback: 031-plan-accion.rollback.sql
--
-- Decision del PM (2026-11-12): la propuesta COMPLETA (pedido, hitos y tareas
-- sin responsable) vive en la base del agente. El pedido de trabajo se crea en
-- el modulo de Tareas recien cuando el administrador toca "Aceptar", con SU
-- token, siempre con el Proceso Estandar. Hasta entonces no hay nada en Tareas
-- y no le llega nada a nadie.
--
--   * agente.plan_propuesta: la propuesta, su estado y, si se acepto, el
--     pedido creado (petr_id) y lo que devolvio cada paso.
--   * kuntur_proponer_plan: tool del motor (agente/planes.py), clase
--     'generacion': no graba en Tools, deja la propuesta para la tarjeta.
--   * tar_alta_pedido, tar_alta_hito, tar_alta_tarea, tar_baja_pedido y
--     tar_baja_tarea: las operaciones de la fachada MCP que usa el ejecutor al
--     aceptar. Clase 'accion': NINGUN agente las ve ni las puede pedir
--     (tools_por_patrones las excluye); solo las llama el motor, con el token
--     del administrador que acepto. Mientras el PM no apruebe los recursos MCP
--     (doc/agente/analisis-impacto-plan-accion-kuntur.md, anexo), el ejecutor
--     corre SIMULADO (agente/planes.py, SIMULADO = True).
-- =============================================================================

\set ON_ERROR_STOP on

-- -----------------------------------------------------------------------------
-- Las propuestas de plan
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agente.plan_propuesta (
    plan_id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    empr_id          integer     NOT NULL,
    interaccion_id   uuid,                   -- la corrida en la que se propuso (R8)
    agente           text        NOT NULL DEFAULT 'kuntur',
    usuario          text        NOT NULL,   -- a quien se le propuso
    plan             jsonb       NOT NULL,   -- porque, objetivo, meta, pedido, hitos[tareas]
    estado           text        NOT NULL DEFAULT 'propuesta',
    motivo_descarte  text,
    texto_descarte   text,
    petr_id          text,                   -- el pedido creado (o el simulado, 'SIM-...')
    simulado         boolean     NOT NULL DEFAULT false,
    respondido_por   text,
    resultado        jsonb,                  -- lo que devolvio cada paso, o el error
    fec_alta         timestamptz NOT NULL DEFAULT now(),
    fec_respuesta    timestamptz,
    CONSTRAINT plan_propuesta_estado_ck
        CHECK (estado IN ('propuesta', 'aceptada', 'descartada', 'fallida', 'vencida')),
    CONSTRAINT plan_propuesta_motivo_ck
        CHECK (motivo_descarte IS NULL OR motivo_descarte IN ('no_es_prioridad', 'ya_lo_hacemos', 'no_aplica', 'otro')),
    CONSTRAINT plan_propuesta_descarte_ck
        CHECK (estado <> 'descartada' OR motivo_descarte IS NOT NULL),
    CONSTRAINT plan_propuesta_texto_ck
        CHECK (texto_descarte IS NULL OR length(texto_descarte) <= 1000)
);

CREATE INDEX IF NOT EXISTS plan_propuesta_empresa_ix ON agente.plan_propuesta (empr_id, estado, fec_alta DESC);

COMMENT ON TABLE agente.plan_propuesta IS
    'Planes de accion que propuso Kuntur (ADR-A13, opcion B). Nada se crea en Tareas hasta que el '
    'administrador acepta; ahi se crea el pedido con su token y el Proceso Estandar.';
COMMENT ON COLUMN agente.plan_propuesta.motivo_descarte IS
    'Por que el administrador no lo quiso. Es lo que usa Kuntur para no repetir planes que no sirven.';

ALTER TABLE agente.plan_propuesta ENABLE ROW LEVEL SECURITY;
ALTER TABLE agente.plan_propuesta FORCE  ROW LEVEL SECURITY;
DROP POLICY IF EXISTS plan_propuesta_aislamiento ON agente.plan_propuesta;
CREATE POLICY plan_propuesta_aislamiento ON agente.plan_propuesta
    USING (empr_id = NULLIF(current_setting('agente.empr_id', true), '')::integer)
    WITH CHECK (empr_id = NULLIF(current_setting('agente.empr_id', true), '')::integer);
GRANT SELECT, INSERT, UPDATE ON agente.plan_propuesta TO agente_app;
GRANT SELECT ON agente.plan_propuesta TO agente_curador;

-- -----------------------------------------------------------------------------
-- Catalogo
-- -----------------------------------------------------------------------------
INSERT INTO agente.tool (nombre, modulo, clase, riesgo, reversible, descripcion)
VALUES
    ('kuntur_proponer_plan', 'tar', 'generacion', 'bajo', true,
     'Kuntur propone un plan de accion (pedido, hitos y tareas sin responsable). No graba: el administrador acepta desde la tarjeta'),
    ('tar_alta_pedido', 'tar', 'accion', 'medio', true,
     'Crea un pedido de trabajo con el Proceso Estandar. Solo la usa el motor al aceptar un plan, con el token del administrador'),
    ('tar_alta_hito', 'tar', 'accion', 'medio', true,
     'Agrega un hito a un pedido de la empresa. Solo la usa el motor al aceptar un plan'),
    ('tar_alta_tarea', 'tar', 'accion', 'medio', true,
     'Agrega una tarea sin responsable a un hito de la empresa. Solo la usa el motor al aceptar un plan'),
    ('tar_baja_pedido', 'tar', 'accion', 'medio', true,
     'Marca eliminado un pedido de la empresa. Solo para deshacer un plan que fallo a mitad de camino'),
    ('tar_baja_tarea', 'tar', 'accion', 'medio', true,
     'Marca eliminada una tarea de la empresa. Solo para deshacer un plan que fallo a mitad de camino')
ON CONFLICT (nombre) DO UPDATE SET
    modulo      = EXCLUDED.modulo,
    clase       = EXCLUDED.clase,
    riesgo      = EXCLUDED.riesgo,
    reversible  = EXCLUDED.reversible,
    descripcion = EXCLUDED.descripcion,
    fec_mod     = now();

-- Solo Kuntur, por nombre exacto (no entra por ningun patron 'tar_get_*').
UPDATE agente.agente
   SET tools_permitidas = CASE WHEN 'kuntur_proponer_plan' = ANY (tools_permitidas) THEN tools_permitidas
                               ELSE tools_permitidas || 'kuntur_proponer_plan'::text END,
       fec_mod = now()
 WHERE clave = 'kuntur';

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('031-plan-accion', 'Plan de accion de Kuntur, opcion B (ADR-A13): propuesta en el agente, pedido al aceptar')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();
