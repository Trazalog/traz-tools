-- =============================================================================
-- 024 - Kuntur: entrevista de configuracion y seguimiento de metas (AGENTE-CO-02, CO-07)
-- =============================================================================
-- Idempotente. Rollback: 024-kuntur-configuracion.rollback.sql
--
-- Tres cosas:
--
--   * perfil_empresa crece con lo que cuenta el administrador en la entrevista
--     de Kuntur: que partes de Trazalog usa o usaria, si trabaja para una
--     operadora y que le exige, y que le preocupa. Hasta 016 solo tenia la
--     industria y la cargaba Trazalog; desde aca la confirma el administrador
--     (queda quien y cuando). El runtime la escribe, siempre con el RLS de la
--     empresa: la API solo lo hace con el token de un administrador (R1).
--
--   * entrevista_config: la entrevista en curso, para cortarla y seguirla otro
--     dia. Una por empresa.
--
--   * aviso_meta: en que estado vio Kuntur cada meta la ultima vez (ok, en
--     riesgo, no se cumple) y si el administrador le pidio que no insista.
--     Kuntur avisa cuando el estado cambia, no por calendario.
-- =============================================================================

\set ON_ERROR_STOP on

-- -----------------------------------------------------------------------------
-- El perfil de la empresa
-- -----------------------------------------------------------------------------
ALTER TABLE agente.perfil_empresa
    ADD COLUMN IF NOT EXISTS modulos          text[]      NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS operadora        boolean,
    ADD COLUMN IF NOT EXISTS operadora_nombre text,
    ADD COLUMN IF NOT EXISTS exigencias       jsonb       NOT NULL DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS preocupaciones   text[]      NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS confirmado_por   text,
    ADD COLUMN IF NOT EXISTS fec_confirmacion timestamptz;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'perfil_empresa_modulos_ck') THEN
        ALTER TABLE agente.perfil_empresa ADD CONSTRAINT perfil_empresa_modulos_ck
            CHECK (modulos <@ ARRAY['almacenes', 'mantenimiento', 'herramientas', 'tareas']::text[]);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'perfil_empresa_exigencias_ck') THEN
        ALTER TABLE agente.perfil_empresa ADD CONSTRAINT perfil_empresa_exigencias_ck
            CHECK (jsonb_typeof(exigencias) = 'array');
    END IF;
END $$;

COMMENT ON TABLE agente.perfil_empresa IS
    'Perfil de cada empresa para los agentes: industria (016) y lo que el administrador conto en la entrevista de Kuntur (024).';
COMMENT ON COLUMN agente.perfil_empresa.modulos IS
    'Partes de Trazalog que la empresa usa o usaria: almacenes, mantenimiento, herramientas, tareas.';
COMMENT ON COLUMN agente.perfil_empresa.exigencias IS
    'Lo que le exige la operadora: [{"kpi": "<indicador del Tablero>"|null, "texto": "..."}]. kpi null = hoy no se mide.';
COMMENT ON COLUMN agente.perfil_empresa.preocupaciones IS
    'Hasta dos indicadores del Tablero que mas le preocupan al administrador. Las exigencias de la operadora van antes.';
COMMENT ON COLUMN agente.perfil_empresa.confirmado_por IS
    'El administrador que confirmo la configuracion (nick del token). NULL = la cargo Trazalog.';

-- El runtime escribe el perfil de SU empresa (lo confirma un administrador).
GRANT SELECT, INSERT, UPDATE ON agente.perfil_empresa TO agente_app;

-- -----------------------------------------------------------------------------
-- La entrevista en curso
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agente.entrevista_config (
    empr_id    integer     PRIMARY KEY,
    usuario    text        NOT NULL,
    respuestas jsonb       NOT NULL DEFAULT '{}'::jsonb,
    estado     text        NOT NULL DEFAULT 'en_curso',
    fec_alta   timestamptz NOT NULL DEFAULT now(),
    fec_mod    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT entrevista_config_estado_ck CHECK (estado IN ('en_curso', 'confirmada'))
);

COMMENT ON TABLE agente.entrevista_config IS
    'La entrevista de configuracion de Kuntur en curso (una por empresa), para retomarla. AGENTE-CO-02.';

ALTER TABLE agente.entrevista_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE agente.entrevista_config FORCE  ROW LEVEL SECURITY;
DROP POLICY IF EXISTS entrevista_config_aislamiento ON agente.entrevista_config;
CREATE POLICY entrevista_config_aislamiento ON agente.entrevista_config
    USING (empr_id = NULLIF(current_setting('agente.empr_id', true), '')::integer)
    WITH CHECK (empr_id = NULLIF(current_setting('agente.empr_id', true), '')::integer);
GRANT SELECT, INSERT, UPDATE, DELETE ON agente.entrevista_config TO agente_app;
GRANT SELECT ON agente.entrevista_config TO agente_curador;

-- -----------------------------------------------------------------------------
-- Lo que Kuntur ya aviso de cada meta
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agente.aviso_meta (
    empr_id          integer     NOT NULL,
    objetivo_id      integer     NOT NULL,   -- kpi.objetivos.objetivo_id (base de Tools)
    estado           text        NOT NULL,   -- el ultimo que vio el seguimiento
    titulo           text,                   -- el del ultimo aviso, para listarlo en el panel
    cuerpo           text,
    silenciado       boolean     NOT NULL DEFAULT false,
    silenciado_por   text,
    fec_silencio     timestamptz,
    fec_aviso        timestamptz,            -- el ultimo aviso publicado
    fec_mod          timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (empr_id, objetivo_id),
    CONSTRAINT aviso_meta_estado_ck CHECK (estado IN ('ok', 'en_riesgo', 'no_cumple'))
);

COMMENT ON TABLE agente.aviso_meta IS
    'Ultimo estado de cada meta visto por Kuntur y si el administrador le pidio que no insista. Avisa cuando el estado cambia (AGENTE-CO-07).';
COMMENT ON COLUMN agente.aviso_meta.silenciado IS
    '"No insistas": no se avisa mas de esa meta hasta que vuelva a cumplirse (ahi se limpia).';

ALTER TABLE agente.aviso_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE agente.aviso_meta FORCE  ROW LEVEL SECURITY;
DROP POLICY IF EXISTS aviso_meta_aislamiento ON agente.aviso_meta;
CREATE POLICY aviso_meta_aislamiento ON agente.aviso_meta
    USING (empr_id = NULLIF(current_setting('agente.empr_id', true), '')::integer)
    WITH CHECK (empr_id = NULLIF(current_setting('agente.empr_id', true), '')::integer);
GRANT SELECT, INSERT, UPDATE ON agente.aviso_meta TO agente_app;
GRANT SELECT ON agente.aviso_meta TO agente_curador;

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('024-kuntur-configuracion', 'Kuntur: perfil ampliado, entrevista de configuracion y estado de los avisos de metas (CO-02, CO-07)')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();
