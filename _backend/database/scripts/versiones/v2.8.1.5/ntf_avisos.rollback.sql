-- Rollback de ntf_avisos.sql: borra el esquema ntf con todos los avisos,
-- envios y dispositivos registrados, y el rol del transporte.
-- ANTES: desplegar de nuevo el Siddhi viejo de AssetPlanner si se habia
-- reemplazado por el puente, o los avisos de AssetPlanner dejan de mandarse.
\set ON_ERROR_STOP on
DROP SCHEMA IF EXISTS ntf CASCADE;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ntf_transporte') THEN
        DROP ROLE ntf_transporte;
    END IF;
END
$$;
