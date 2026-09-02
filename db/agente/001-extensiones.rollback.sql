-- Rollback de 001-extensiones.sql
-- Ultimo paso del rollback: borra el esquema entero y los roles.
-- Aplicar solo despues de 007..002, o usar el CASCADE de abajo con conciencia
-- de que se lleva TODO lo del agente.
\set ON_ERROR_STOP on

DROP SCHEMA IF EXISTS agente CASCADE;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'agente_app') THEN
        DROP ROLE agente_app;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'agente_curador') THEN
        DROP ROLE agente_curador;
    END IF;
EXCEPTION WHEN dependent_objects_still_exist THEN
    RAISE NOTICE 'Los roles tienen objetos o permisos dependientes en otras bases; no se borraron.';
END
$$;

-- Las extensiones vector y pgcrypto NO se borran: puede haber otros esquemas
-- de esta base usandolas. Si hace falta: DROP EXTENSION vector;
