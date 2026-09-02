-- =============================================================================
-- 001 - Extensiones, esquema y roles del Agente Minero
-- =============================================================================
-- Idempotente: se puede correr las veces que haga falta.
-- Rollback: 001-extensiones.rollback.sql
--
-- Requiere que el paquete de pgvector este instalado en el SERVIDOR antes de
-- correr esto (en Debian/Ubuntu: sudo apt install postgresql-16-pgvector).
-- CREATE EXTENSION solo registra la extension en la base; no la instala.
-- =============================================================================

\set ON_ERROR_STOP on

-- ---------------------------------------------------------------------------
-- Chequeo temprano: si pgvector no esta disponible, cortar con un mensaje
-- claro en vez de fallar mas adelante con un error de tipo desconocido.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'vector') THEN
        RAISE EXCEPTION
            'pgvector no esta disponible en este servidor. Instalar el paquete del sistema primero (ej: apt install postgresql-16-pgvector) y volver a correr este script.';
    END IF;
END
$$;

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS agente;

COMMENT ON SCHEMA agente IS
    'Agente Minero: conocimiento compartido, memoria por cliente, feedback, entrevistas y notificaciones. Ver db/agente/README.md';

-- ---------------------------------------------------------------------------
-- Roles
--
-- agente_app     : lo usa el orquestador en el flujo de consulta.
--                  LEE el conocimiento compartido, ESCRIBE solo memoria del
--                  cliente, candidatos, feedback y notificaciones (ADR-A4).
-- agente_curador : el circuito de curaduria. Es el unico que puede escribir en
--                  el conocimiento compartido.
--
-- Son roles NOLOGIN a proposito: los usuarios reales se crean por ambiente y se
-- les concede el rol que corresponda. Asi las credenciales no viven en el repo.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'agente_app') THEN
        CREATE ROLE agente_app NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'agente_curador') THEN
        CREATE ROLE agente_curador NOLOGIN;
    END IF;
END
$$;

GRANT USAGE ON SCHEMA agente TO agente_app, agente_curador;

COMMENT ON ROLE agente_app IS
    'Orquestador del Agente Minero. Solo lectura sobre el conocimiento compartido (ADR-A4).';
COMMENT ON ROLE agente_curador IS
    'Circuito de curaduria. Unico rol con escritura sobre el conocimiento compartido.';

-- ---------------------------------------------------------------------------
-- Tabla de control de versiones del esquema. Cada script registra su
-- aplicacion aca, asi se puede saber que estado tiene una base cualquiera.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agente.schema_version (
    script      text        PRIMARY KEY,
    aplicado_en timestamptz NOT NULL DEFAULT now(),
    descripcion text
);

COMMENT ON TABLE agente.schema_version IS
    'Registro de scripts aplicados. Consultar antes de aplicar nada sobre una base desconocida.';

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('001-extensiones', 'Extensiones vector y pgcrypto, esquema agente, roles agente_app y agente_curador')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();

-- ---------------------------------------------------------------------------
-- Version de pgvector, informativa: HNSW necesita 0.5.0 o superior.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    v_version text;
BEGIN
    SELECT extversion INTO v_version FROM pg_extension WHERE extname = 'vector';
    RAISE NOTICE 'pgvector instalado: version %', v_version;
    IF string_to_array(v_version, '.')::int[] < ARRAY[0,5,0] THEN
        RAISE WARNING 'pgvector % es anterior a 0.5.0: el indice HNSW de 002 va a fallar. Actualizar la extension.', v_version;
    END IF;
END
$$;
