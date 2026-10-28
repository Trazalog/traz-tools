-- =============================================================================
-- 020 - Cola de envio push: solo la lee el transporte (AGENTE-AS-03)
-- =============================================================================
-- Idempotente. Rollback: 020-cola-envio.rollback.sql
--
-- HALLAZGO del 2026-10-28: desde 007, agente.dispositivo (los tokens de push
-- de los usuarios de cada empresa) y agente.envio (titulo y detalle de cada
-- aviso) no tenian RLS, y el usuario del orquestador podia leerlos de TODAS
-- las empresas.
--
--   dispositivo  pasa a tener RLS por empresa, como el resto.
--   envio        es la cola GLOBAL que procesa el transporte (la app Siddhi
--                -> FirebaseConnectorAPI, Opcion C de E0): por eso no lleva
--                RLS. En cambio, el orquestador solo puede INSERTAR en ella,
--                nunca leerla, y un rol propio, agente_envio, es el unico que
--                la lee y la actualiza. El usuario con el que se conecte el
--                Streaming Integrator tiene que tener ese rol y ningun otro.
-- =============================================================================

\set ON_ERROR_STOP on

-- dispositivo: RLS por empresa.
ALTER TABLE agente.dispositivo ENABLE ROW LEVEL SECURITY;
ALTER TABLE agente.dispositivo FORCE  ROW LEVEL SECURITY;
DROP POLICY IF EXISTS dispositivo_aislamiento_empresa ON agente.dispositivo;
CREATE POLICY dispositivo_aislamiento_empresa ON agente.dispositivo
    USING (empr_id = NULLIF(current_setting('agente.empr_id', true), '')::integer)
    WITH CHECK (empr_id = NULLIF(current_setting('agente.empr_id', true), '')::integer);

-- envio: el orquestador solo encola.
REVOKE ALL ON agente.envio FROM agente_app;
GRANT INSERT ON agente.envio TO agente_app;

-- El transporte: lee los pendientes y marca el resultado. Nada mas.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'agente_envio') THEN
        CREATE ROLE agente_envio NOLOGIN;
    END IF;
END
$$;
GRANT USAGE ON SCHEMA agente TO agente_envio;
GRANT SELECT, UPDATE (estado, intentos, ultimo_error, fec_envio) ON agente.envio TO agente_envio;

COMMENT ON TABLE agente.envio IS
    'Cola global de push. Sin RLS a proposito: la procesa el transporte. El orquestador solo inserta; solo agente_envio lee y actualiza (020).';

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('020-cola-envio', 'RLS en dispositivo; la cola envio solo la lee el transporte (agente_envio)')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();
