-- =============================================================================
-- Test de estructura del esquema del Agente Minero
-- =============================================================================
-- Verifica que todo lo que los scripts 001..007 dicen crear, existe de verdad.
-- No inserta ni modifica datos: es seguro correrlo contra cualquier ambiente.
--
--   psql -h <host> -U <usuario> -d <base> -v ON_ERROR_STOP=1 -f tests/test-estructura.sql
--
-- Imprime una linea por control y termina con un resumen. Si algo falla, sale
-- con excepcion (codigo distinto de cero), asi sirve en CI.
-- =============================================================================

\set ON_ERROR_STOP on
\pset pager off

-- Cada control deja su resultado en esta tabla temporal; al final se imprimen
-- todos juntos y se corta si hubo alguna falla.
CREATE TEMP TABLE IF NOT EXISTS _resultado (
    control text,
    ok      boolean,
    detalle text
) ON COMMIT PRESERVE ROWS;

TRUNCATE _resultado;

-- ---------------------------------------------------------------------------
-- 001 - extensiones, esquema y roles
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'extension vector instalada',
       EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'vector'),
       coalesce((SELECT extversion FROM pg_extension WHERE extname = 'vector'), 'ausente');

INSERT INTO _resultado
SELECT 'extension pgcrypto instalada',
       EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto'), '';

INSERT INTO _resultado
SELECT 'esquema agente existe',
       EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'agente'), '';

INSERT INTO _resultado
SELECT 'rol ' || r,
       EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r), ''
FROM unnest(ARRAY['agente_app', 'agente_curador']) AS r;

-- ---------------------------------------------------------------------------
-- Tablas de 002 a 007
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'tabla agente.' || t,
       EXISTS (
           SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname = 'agente' AND c.relname = t AND c.relkind IN ('r', 'p')
       ), ''
FROM unnest(ARRAY[
    'schema_version', 'fuente', 'chunk', 'memoria', 'candidato',
    'interaccion', 'feedback', 'tema', 'experto', 'sesion_entrevista',
    'hecho', 'validacion_cruzada', 'dispositivo', 'notificacion', 'envio',
    'destinatario_alerta'
]) AS t;

-- ---------------------------------------------------------------------------
-- Vistas
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'vista agente.' || v,
       EXISTS (
           SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname = 'agente' AND c.relname = v AND c.relkind = 'v'
       ), ''
FROM unnest(ARRAY['v_feedback_negativo', 'v_hechos_para_validar']) AS v;

-- ---------------------------------------------------------------------------
-- Funciones
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'funcion agente.' || f,
       EXISTS (
           SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'agente' AND p.proname = f
       ), ''
FROM unnest(ARRAY[
    'crear_particion_empresa', 'expandir_envios', 'tg_set_fec_mod', 'tg_validacion_no_autovalida',
    'destinatarios_de'
]) AS f;

-- ---------------------------------------------------------------------------
-- Columnas de embedding con la dimension correcta (1024)
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'agente.' || t || '.embedding es vector(1024)',
       EXISTS (
           SELECT 1
           FROM pg_attribute a
           JOIN pg_class c ON c.oid = a.attrelid
           JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname = 'agente' AND c.relname = t AND a.attname = 'embedding'
             AND format_type(a.atttypid, a.atttypmod) = 'vector(1024)'
       ), 'si cambio el modelo de embeddings, ver README'
FROM unnest(ARRAY['chunk', 'memoria', 'candidato', 'hecho']) AS t;

-- ---------------------------------------------------------------------------
-- memoria tiene que estar PARTICIONADA por empr_id
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'agente.memoria esta particionada',
       EXISTS (
           SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname = 'agente' AND c.relname = 'memoria' AND c.relkind = 'p'
       ), '';

INSERT INTO _resultado
SELECT 'agente.memoria particiona por empr_id',
       EXISTS (
           SELECT 1
           FROM pg_partitioned_table pt
           JOIN pg_class c ON c.oid = pt.partrelid
           JOIN pg_namespace n ON n.oid = c.relnamespace
           JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = pt.partattrs[0]
           WHERE n.nspname = 'agente' AND c.relname = 'memoria' AND a.attname = 'empr_id'
       ), '';

-- ---------------------------------------------------------------------------
-- RLS activo donde tiene que estarlo
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'RLS activo en agente.' || t,
       coalesce((
           SELECT c.relrowsecurity AND c.relforcerowsecurity
           FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname = 'agente' AND c.relname = t
       ), false), 'aislamiento multi-tenant'
FROM unnest(ARRAY['memoria', 'notificacion', 'destinatario_alerta']) AS t;

INSERT INTO _resultado
SELECT 'policy de aislamiento en agente.' || t,
       EXISTS (
           SELECT 1 FROM pg_policies
           WHERE schemaname = 'agente' AND tablename = t
       ), ''
FROM unnest(ARRAY['memoria', 'notificacion', 'destinatario_alerta']) AS t;

-- ---------------------------------------------------------------------------
-- ADR-A4: agente_app NO puede escribir el conocimiento compartido
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'agente_app puede LEER agente.chunk',
       has_table_privilege('agente_app', 'agente.chunk', 'SELECT'), 'ADR-A4';

INSERT INTO _resultado
SELECT 'agente_app NO puede ' || priv || ' agente.chunk',
       NOT has_table_privilege('agente_app', 'agente.chunk', priv), 'ADR-A4'
FROM unnest(ARRAY['INSERT', 'UPDATE', 'DELETE']) AS priv;

INSERT INTO _resultado
SELECT 'agente_curador puede escribir agente.chunk',
       has_table_privilege('agente_curador', 'agente.chunk', 'INSERT'), 'ADR-A4';

INSERT INTO _resultado
SELECT 'agente_app NO puede UPDATE agente.candidato (solo propone)',
       NOT has_table_privilege('agente_app', 'agente.candidato', 'UPDATE'), 'ADR-A4';

-- ---------------------------------------------------------------------------
-- Indices vectoriales HNSW
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'indice HNSW en agente.' || t,
       EXISTS (
           SELECT 1 FROM pg_index i
           JOIN pg_class ic ON ic.oid = i.indexrelid
           JOIN pg_class tc ON tc.oid = i.indrelid
           JOIN pg_namespace n ON n.oid = tc.relnamespace
           JOIN pg_am am ON am.oid = ic.relam
           WHERE n.nspname = 'agente' AND tc.relname = t AND am.amname = 'hnsw'
       ), 'requiere pgvector >= 0.5.0'
FROM unnest(ARRAY['chunk', 'candidato', 'hecho']) AS t;

-- ---------------------------------------------------------------------------
-- Deduplicacion de notificaciones
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'indice unico de dedupe en agente.notificacion',
       EXISTS (
           SELECT 1 FROM pg_indexes
           WHERE schemaname = 'agente' AND tablename = 'notificacion'
             AND indexname = 'notificacion_dedupe_uk'
       ), 'evita repetir el mismo hallazgo en cada corrida';

-- ---------------------------------------------------------------------------
-- Todos los scripts registrados
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'script ' || s || ' registrado en schema_version',
       EXISTS (SELECT 1 FROM agente.schema_version WHERE script = s), ''
FROM unnest(ARRAY[
    '001-extensiones', '002-conocimiento-compartido', '003-memoria-cliente',
    '004-cola-candidatos', '005-feedback', '006-entrevistador', '007-notificaciones',
    '008-destinatarios-alerta'
]) AS s;

-- ---------------------------------------------------------------------------
-- Resultado
-- ---------------------------------------------------------------------------
\echo ''
\echo '=== TEST DE ESTRUCTURA — Agente Minero ==='
SELECT CASE WHEN ok THEN 'OK    ' ELSE 'FALLA ' END || control
       || CASE WHEN detalle <> '' THEN '  [' || detalle || ']' ELSE '' END AS resultado
FROM _resultado
ORDER BY ok, control;

\echo ''
SELECT count(*) FILTER (WHERE ok)       AS pasaron,
       count(*) FILTER (WHERE NOT ok)   AS fallaron,
       count(*)                         AS total
FROM _resultado;

DO $$
DECLARE
    v_fallas int;
BEGIN
    SELECT count(*) INTO v_fallas FROM _resultado WHERE NOT ok;
    IF v_fallas > 0 THEN
        RAISE EXCEPTION 'TEST DE ESTRUCTURA FALLIDO: % control(es) no pasaron. Ver el detalle arriba.', v_fallas;
    END IF;
    RAISE NOTICE 'TEST DE ESTRUCTURA: todo en verde.';
END
$$;
