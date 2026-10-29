-- =============================================================================
-- 021 - Se borran los avisos propios del agente (ADR-015, D-84)
-- =============================================================================
-- Idempotente. Rollback: 021-drop-avisos-agente.rollback.sql
--
-- Desde ADR-015 los agentes publican sus avisos en el mecanismo unico de Tools
-- (esquema ntf, POST /avisos de toolsNTFAPI). La cola propia del agente que
-- crearon 007, 008, 018 y 020 quedo sin uso: ningun codigo la lee ni la escribe.
--
--   agente.notificacion        -> ntf.aviso / ntf.destino
--   agente.envio               -> ntf.envio
--   agente.dispositivo         -> ntf.dispositivo
--   agente.destinatario_alerta -> ntf.suscripcion
--
-- Lo que esas tablas tengan se pierde. Nunca hubo un emisor en produccion (el
-- monitoreo del agente no llego a desplegarse con esta cola), asi que no hay
-- nada que migrar. Si en algun ambiente hay destinatarios configurados que
-- interese conservar, cargarlos en ntf.suscripcion ANTES de correr esto.
--
-- NO se toca agente.credencial_empresa (tambien de 018): el monitoreo la sigue
-- usando para el token de maquina.
-- =============================================================================

\set ON_ERROR_STOP on

DROP FUNCTION IF EXISTS agente.expandir_envios(bigint);
DROP FUNCTION IF EXISTS agente.destinatarios_de(integer, text);
DROP FUNCTION IF EXISTS agente.destinatarios(integer, text);

-- envio primero: referencia a notificacion y a dispositivo.
DROP TABLE IF EXISTS agente.envio;
DROP TABLE IF EXISTS agente.notificacion;
DROP TABLE IF EXISTS agente.dispositivo;
DROP TABLE IF EXISTS agente.destinatario_alerta;

-- El rol del transporte (020) ya no tiene nada que leer. Si sigue asignado a
-- algun usuario o tiene permisos en otra base, DROP ROLE falla: en ese caso
-- queda el rol (sin permisos aca) y se avisa, en vez de cortar el script.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'agente_envio') THEN
        REVOKE ALL ON SCHEMA agente FROM agente_envio;
        BEGIN
            DROP ROLE agente_envio;
        EXCEPTION WHEN dependent_objects_still_exist THEN
            RAISE NOTICE 'agente_envio no se pudo borrar (tiene dependencias fuera de este esquema): borrarlo a mano';
        END;
    END IF;
END
$$;

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('021-drop-avisos-agente', 'Se borran notificacion, envio, dispositivo y destinatario_alerta: los avisos van por ntf (ADR-015)')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();
