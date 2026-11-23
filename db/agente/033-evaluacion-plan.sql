-- =============================================================================
-- 033 - Medicion del plan y practicas (AGENTE-CO-05)
-- =============================================================================
-- Idempotente. Rollback: 033-evaluacion-plan.rollback.sql
--
-- Cuando la ventana de una medicion de un plan (medicion_pedida con petr_id)
-- termina, el trabajo diario compara el primer valor medido con el ultimo y
-- deja UNA evaluacion: funciono / no_funciono / sin_datos. Lo decide una regla
-- (agente/evaluacion.py), no el modelo; los dos numeros salen de
-- medicion_resultado, que guarda la tool de la que vino cada uno (R4).
--
--   agente.evaluacion_plan   una fila por medicion (la clave es medicion_id:
--                            se evalua una sola vez). Con RLS por empresa y
--                            sin texto libre (R3): los text son estados con
--                            CHECK o el nombre de la tool.
--   agente.candidato         suma el origen 'plan_accion': un plan que
--                            funciono se propone como practica, sin cifras ni
--                            datos de la empresa, y lo aprueba un curador
--                            (ADR-A4). La cola no tiene empresa: es conocimiento
--                            compartido.
-- =============================================================================

\set ON_ERROR_STOP on

CREATE TABLE IF NOT EXISTS agente.evaluacion_plan (
    medicion_id    bigint      PRIMARY KEY REFERENCES agente.medicion_pedida(medicion_id) ON DELETE CASCADE,
    empr_id        integer     NOT NULL,
    petr_id        integer     NOT NULL,
    mejor          text        NOT NULL DEFAULT 'subir',
    valor_inicial  numeric,
    fecha_inicial  date,
    valor_final    numeric,
    fecha_final    date,
    mediciones     integer     NOT NULL DEFAULT 0,
    tool           text,
    resultado      text        NOT NULL,
    aviso_id       integer,
    candidato_id   bigint      REFERENCES agente.candidato(candidato_id) ON DELETE SET NULL,
    fec_alta       timestamptz NOT NULL DEFAULT now(),
    fec_mod        timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT evaluacion_plan_mejor_ck     CHECK (mejor IN ('subir', 'bajar')),
    CONSTRAINT evaluacion_plan_resultado_ck CHECK (resultado IN ('funciono', 'no_funciono', 'sin_datos')),
    CONSTRAINT evaluacion_plan_datos_ck
        CHECK (resultado = 'sin_datos' OR (valor_inicial IS NOT NULL AND valor_final IS NOT NULL))
);

COMMENT ON TABLE agente.evaluacion_plan IS
    'Resultado de un plan de accion al cerrar su medicion (AGENTE-CO-05): primer y ultimo valor medido y la regla que decidio. Una vez por medicion.';
COMMENT ON COLUMN agente.evaluacion_plan.mejor IS
    'Hacia donde mejora el indicador (parametros.mejor de la medicion; si no lo dice, subir).';
COMMENT ON COLUMN agente.evaluacion_plan.aviso_id IS
    'Aviso de Tools (ntf) que se le mando al administrador. NULL = todavia no se pudo publicar: el trabajo diario lo reintenta.';

ALTER TABLE agente.evaluacion_plan ENABLE ROW LEVEL SECURITY;
ALTER TABLE agente.evaluacion_plan FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS evaluacion_plan_aislamiento ON agente.evaluacion_plan;
CREATE POLICY evaluacion_plan_aislamiento ON agente.evaluacion_plan
    USING (empr_id = NULLIF(current_setting('agente.empr_id', true), '')::integer)
    WITH CHECK (empr_id = NULLIF(current_setting('agente.empr_id', true), '')::integer);
REVOKE ALL ON agente.evaluacion_plan FROM agente_app;
GRANT SELECT, INSERT, UPDATE ON agente.evaluacion_plan TO agente_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON agente.evaluacion_plan TO agente_curador;

ALTER TABLE agente.candidato DROP CONSTRAINT IF EXISTS candidato_origen_ck;
ALTER TABLE agente.candidato ADD CONSTRAINT candidato_origen_ck
    CHECK (origen IN ('patron_operativo', 'entrevista', 'documento', 'feedback', 'plan_accion'));

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('033-evaluacion-plan', 'Medicion del plan: evaluacion_plan y origen plan_accion en la cola de curaduria')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();
