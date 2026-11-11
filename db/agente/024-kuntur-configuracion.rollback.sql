-- Rollback de 024-kuntur-configuracion.sql
-- OJO: borra lo que contaron los administradores en la entrevista de Kuntur.
\set ON_ERROR_STOP on

DROP TABLE IF EXISTS agente.aviso_meta;
DROP TABLE IF EXISTS agente.entrevista_config;

REVOKE INSERT, UPDATE ON agente.perfil_empresa FROM agente_app;
ALTER TABLE agente.perfil_empresa
    DROP CONSTRAINT IF EXISTS perfil_empresa_modulos_ck,
    DROP CONSTRAINT IF EXISTS perfil_empresa_exigencias_ck,
    DROP COLUMN IF EXISTS modulos,
    DROP COLUMN IF EXISTS operadora,
    DROP COLUMN IF EXISTS operadora_nombre,
    DROP COLUMN IF EXISTS exigencias,
    DROP COLUMN IF EXISTS preocupaciones,
    DROP COLUMN IF EXISTS confirmado_por,
    DROP COLUMN IF EXISTS fec_confirmacion;

COMMENT ON TABLE agente.perfil_empresa IS
    'Perfil de cada empresa para los agentes. Hoy solo la vertical; la entrevista de Kuntur (AGENTE-CO-02) lo amplia.';

DELETE FROM agente.schema_version WHERE script = '024-kuntur-configuracion';
