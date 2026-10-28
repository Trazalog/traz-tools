-- =============================================================================
-- 016 - Conocimiento multi-vertical (ADR-A11, AGENTE-M-08)
-- =============================================================================
-- Idempotente. Rollback: 016-vertical.rollback.sql
--
-- Decision del PM (2026-10-27): el producto no es solo minero, sirve para
-- industrias extractivas y de proceso. Hoy: mineria, oil & gas y electricidad.
-- El motor y los agentes son los mismos; cambia el conocimiento.
--
--   chunk.vertical   a que industria aplica un fragmento. 'general' = a todas
--                    (seguridad, normativa transversal, las ayudas del
--                    producto, los casos de uso).
--   tema.vertical    la taxonomia de Faustino por industria. Al promover un
--                    hecho a conocimiento, el chunk hereda la vertical del
--                    tema de la entrevista (no hace falta guardarla en hecho).
--   perfil_empresa   la industria de cada empresa. Con vertical declarada,
--                    recibe lo de su vertical y lo general. Sin declarar,
--                    recibe todo (etiquetado), para no esconderle conocimiento
--                    a un cliente nuevo. Hoy la carga Trazalog; la entrevista
--                    de Kuntur (AGENTE-CO-02) la va a completar y ampliar.
-- =============================================================================

\set ON_ERROR_STOP on

DO $$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['chunk', 'tema'] LOOP
        EXECUTE format('ALTER TABLE agente.%I ADD COLUMN IF NOT EXISTS vertical text NOT NULL DEFAULT ''general''', t);
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = t || '_vertical_ck') THEN
            EXECUTE format(
                'ALTER TABLE agente.%I ADD CONSTRAINT %I CHECK (vertical IN (''mineria'', ''oil_gas'', ''electricidad'', ''general''))',
                t, t || '_vertical_ck');
        END IF;
    END LOOP;
END
$$;

CREATE INDEX IF NOT EXISTS chunk_vertical_ix ON agente.chunk (vertical) WHERE vigente;

COMMENT ON COLUMN agente.chunk.vertical IS 'Industria a la que aplica: mineria, oil_gas, electricidad o general (todas). ADR-A11.';
COMMENT ON COLUMN agente.tema.vertical  IS 'Industria del tema de la agenda de Faustino. El conocimiento que sale de la entrevista la hereda.';

-- -----------------------------------------------------------------------------
-- La industria de cada empresa
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agente.perfil_empresa (
    empr_id   integer     PRIMARY KEY,
    vertical  text        NOT NULL,
    fec_alta  timestamptz NOT NULL DEFAULT now(),
    fec_mod   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT perfil_empresa_vertical_ck
        CHECK (vertical IN ('mineria', 'oil_gas', 'electricidad', 'general'))
);

COMMENT ON TABLE agente.perfil_empresa IS
    'Perfil de cada empresa para los agentes. Hoy solo la vertical; la entrevista de Kuntur (AGENTE-CO-02) lo amplia.';

ALTER TABLE agente.perfil_empresa ENABLE ROW LEVEL SECURITY;
ALTER TABLE agente.perfil_empresa FORCE  ROW LEVEL SECURITY;

DROP POLICY IF EXISTS perfil_empresa_aislamiento ON agente.perfil_empresa;
CREATE POLICY perfil_empresa_aislamiento ON agente.perfil_empresa
    USING (empr_id = NULLIF(current_setting('agente.empr_id', true), '')::integer)
    WITH CHECK (empr_id = NULLIF(current_setting('agente.empr_id', true), '')::integer);

-- El runtime lee. Quien la carga hoy es Trazalog (curador o propietario).
REVOKE ALL ON agente.perfil_empresa FROM agente_app;
GRANT SELECT ON agente.perfil_empresa TO agente_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON agente.perfil_empresa TO agente_curador;

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('016-vertical', 'Conocimiento multi-vertical: chunk.vertical, tema.vertical y perfil_empresa (ADR-A11)')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();
