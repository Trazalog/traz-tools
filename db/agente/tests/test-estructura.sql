-- =============================================================================
-- Test de estructura del esquema de los agentes de IA
-- =============================================================================
-- Verifica que todo lo que los scripts 001..019 dicen crear, existe de verdad.
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
-- Alcance: el agente cubre mantenimiento Y almacenes (009)
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'agente.' || t || ' tiene columna modulo',
       EXISTS (
           SELECT 1 FROM information_schema.columns
           WHERE table_schema = 'agente' AND table_name = t AND column_name = 'modulo'
       ), 'mantenimiento / almacenes / general'
FROM unnest(ARRAY['chunk', 'candidato', 'hecho', 'tema']) AS t;

INSERT INTO _resultado
SELECT 'notificacion acepta el tipo de alerta ' || tipo,
       pg_get_constraintdef(c.oid) LIKE '%' || tipo || '%',
       'alertas de almacenes'
FROM unnest(ARRAY['stock_critico', 'material_por_vencer', 'pedido_demorado']) AS tipo,
     pg_constraint c
WHERE c.conname = 'notificacion_tipo_ck';

INSERT INTO _resultado
SELECT 'destinatario_alerta acepta el tipo ' || tipo,
       pg_get_constraintdef(c.oid) LIKE '%' || tipo || '%',
       'destinatarios de alertas de almacenes'
FROM unnest(ARRAY['stock_critico', 'material_por_vencer', 'pedido_demorado']) AS tipo,
     pg_constraint c
WHERE c.conname = 'destinatario_tipo_ck';

-- ---------------------------------------------------------------------------
-- 011 - configuracion de los agentes (ADR-A7)
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'tabla agente.agente existe',
       to_regclass('agente.agente') IS NOT NULL, 'configuracion por agente';

INSERT INTO _resultado
SELECT 'agente ' || c || ' configurado',
       EXISTS (SELECT 1 FROM agente.agente WHERE clave = c), ''
FROM unnest(ARRAY['kuntur', 'quirqui', 'faustino']) AS c;

INSERT INTO _resultado
SELECT 'el coach exige acceso admin (R1)',
       NOT EXISTS (SELECT 1 FROM agente.agente WHERE rol = 'coach' AND acceso <> 'admin')
       AND EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'agente_coach_admin_ck'),
       'constraint agente_coach_admin_ck';

INSERT INTO _resultado
SELECT 'autonomia fija en proponer (R5)',
       EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'agente_autonomia_ck'), '';

INSERT INTO _resultado
SELECT 'ninguna tool de escritura en las listas (ADR-A8)',
       NOT EXISTS (
           SELECT 1 FROM agente.agente, unnest(tools_permitidas) AS t
           WHERE t IN ('man_create_ot', 'alm_crear_pedido_materiales')
              OR t LIKE '%crear%' OR t LIKE '%create%' OR t = '*'
       ), 'las tools permitidas son solo de lectura';

INSERT INTO _resultado
SELECT 'agente_app solo lee agente.agente',
       has_table_privilege('agente_app', 'agente.agente', 'SELECT')
       AND NOT has_table_privilege('agente_app', 'agente.agente', 'INSERT')
       AND NOT has_table_privilege('agente_app', 'agente.agente', 'UPDATE')
       AND NOT has_table_privilege('agente_app', 'agente.agente', 'DELETE'),
       'la configuracion la edita Trazalog, no el runtime';

-- ---------------------------------------------------------------------------
-- 012 - catalogo de tools y lista blanca efectiva (ADR-A8)
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'tabla agente.tool existe', to_regclass('agente.tool') IS NOT NULL, 'catalogo de tools';

INSERT INTO _resultado
SELECT 'funcion agente.tools_permitidas existe',
       to_regprocedure('agente.tools_permitidas(text)') IS NOT NULL, '';

INSERT INTO _resultado
SELECT 'la tool ' || n || ' esta catalogada como accion',
       EXISTS (SELECT 1 FROM agente.tool WHERE nombre = n AND clase = 'accion'), 'escribe en el sistema'
FROM unnest(ARRAY['man_create_ot', 'alm_crear_pedido_materiales']) AS n;

INSERT INTO _resultado
SELECT 'ningun agente alcanza una tool de accion (ADR-A8)',
       NOT EXISTS (
           SELECT 1
           FROM agente.agente a
           CROSS JOIN LATERAL agente.tools_permitidas(a.clave) AS p(nombre)
           JOIN agente.tool t ON t.nombre = p.nombre
           WHERE t.clase = 'accion'
       ), 'aunque un patron como man_* las cubriera';

INSERT INTO _resultado
SELECT 'un patron amplio (man_*) no alcanza las de accion',
       NOT EXISTS (
           SELECT 1 FROM agente.tools_por_patrones(ARRAY['man_*', 'alm_*', '*']) AS p(nombre)
           JOIN agente.tool t ON t.nombre = p.nombre WHERE t.clase = 'accion'
       )
       AND EXISTS (SELECT 1 FROM agente.tools_por_patrones(ARRAY['man_*']) AS p(nombre)
                   WHERE p.nombre = 'man_get_equipos'),
       'el filtro de clase vale aunque el patron sea demasiado amplio';

INSERT INTO _resultado
SELECT 'el _ de un patron no es comodin',
       NOT ('manXgetXequipos' LIKE replace(replace('man_get_*', '_', '\_'), '*', '%'))
       AND ('man_get_equipos' LIKE replace(replace('man_get_*', '_', '\_'), '*', '%')),
       'man_get_* no deja pasar manXgetX...';

INSERT INTO _resultado
SELECT 'agente_app solo lee agente.tool',
       has_table_privilege('agente_app', 'agente.tool', 'SELECT')
       AND NOT has_table_privilege('agente_app', 'agente.tool', 'INSERT')
       AND NOT has_table_privilege('agente_app', 'agente.tool', 'UPDATE')
       AND NOT has_table_privilege('agente_app', 'agente.tool', 'DELETE'),
       'el catalogo lo edita Trazalog';

-- ---------------------------------------------------------------------------
-- 013 - corrida auditable (R8) y RLS de interaccion/feedback
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'interaccion tiene la columna ' || c,
       EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'agente' AND table_name = 'interaccion' AND column_name = c),
       'R8'
FROM unnest(ARRAY['agente', 'disparador', 'costo_usd', 'controles', 'incidentes']) AS c;

INSERT INTO _resultado
SELECT 'tabla agente.tool_llamada existe', to_regclass('agente.tool_llamada') IS NOT NULL,
       'lo que vio el modelo de cada tool';

INSERT INTO _resultado
SELECT 'agente.' || t || ' tiene RLS forzado',
       coalesce((SELECT c.relrowsecurity AND c.relforcerowsecurity
                 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                 WHERE n.nspname = 'agente' AND c.relname = t), false),
       'datos de la empresa (013)'
FROM unnest(ARRAY['interaccion', 'feedback', 'tool_llamada']) AS t;

INSERT INTO _resultado
SELECT 'v_feedback_negativo corre con los permisos de quien consulta',
       coalesce((SELECT 'security_invoker=true' = ANY (c.reloptions)
                 FROM pg_class c WHERE c.oid = 'agente.v_feedback_negativo'::regclass), false),
       'si no, un dueño superusuario se saltea el RLS';

INSERT INTO _resultado
SELECT 'agente_app inserta y lee tool_llamada, pero no corrige ni borra',
       has_table_privilege('agente_app', 'agente.tool_llamada', 'SELECT')
       AND has_table_privilege('agente_app', 'agente.tool_llamada', 'INSERT')
       AND NOT has_table_privilege('agente_app', 'agente.tool_llamada', 'UPDATE')
       AND NOT has_table_privilege('agente_app', 'agente.tool_llamada', 'DELETE'),
       'la traza no se altera desde el runtime';

-- ---------------------------------------------------------------------------
-- 014 - tool web_buscar
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'web_buscar catalogada como lectura de costo externo',
       EXISTS (SELECT 1 FROM agente.tool
               WHERE nombre = 'web_buscar' AND clase = 'lectura' AND costo = 'externo'),
       'sale a buscadores de terceros';

INSERT INTO _resultado
SELECT 'web_buscar: la tiene Quirqui y no Faustino',
       EXISTS (SELECT 1 FROM agente.tools_permitidas('quirqui') AS t WHERE t = 'web_buscar')
       AND NOT EXISTS (SELECT 1 FROM agente.tools_permitidas('faustino') AS t WHERE t = 'web_buscar'),
       'lista blanca';

-- ---------------------------------------------------------------------------
-- 015 - fuentes del producto
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'fuente acepta el tipo ' || t,
       pg_get_constraintdef(c.oid) LIKE '%' || t || '%', 'AGENTE-M-06'
FROM unnest(ARRAY['ayuda', 'caso_uso']) AS t, pg_constraint c
WHERE c.conname = 'fuente_tipo_ck';

INSERT INTO _resultado
SELECT 'indice sobre chunk.metadata (caso de uso por controlador)',
       EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'agente' AND indexname = 'chunk_metadata_gin_ix'),
       'AGENTE-AS-01';

-- ---------------------------------------------------------------------------
-- 016 - multi-vertical (ADR-A11)
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'agente.' || t || ' tiene columna vertical con CHECK',
       EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'agente' AND table_name = t AND column_name = 'vertical')
       AND EXISTS (SELECT 1 FROM pg_constraint WHERE conname = t || '_vertical_ck'),
       'mineria / oil_gas / electricidad / general'
FROM unnest(ARRAY['chunk', 'tema']) AS t;

INSERT INTO _resultado
SELECT 'perfil_empresa con RLS forzado y solo lectura para el runtime',
       coalesce((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
                 WHERE oid = to_regclass('agente.perfil_empresa')), false)
       AND has_table_privilege('agente_app', 'agente.perfil_empresa', 'SELECT')
       AND NOT has_table_privilege('agente_app', 'agente.perfil_empresa', 'INSERT')
       AND NOT has_table_privilege('agente_app', 'agente.perfil_empresa', 'UPDATE'),
       'la industria la carga Trazalog (y despues Kuntur)';

-- ---------------------------------------------------------------------------
-- 017 - propuestas de siguiente paso
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'propuesta con RLS forzado; el runtime no la borra',
       coalesce((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
                 WHERE oid = to_regclass('agente.propuesta')), false)
       AND has_table_privilege('agente_app', 'agente.propuesta', 'INSERT')
       AND NOT has_table_privilege('agente_app', 'agente.propuesta', 'DELETE'),
       'AGENTE-AS-02';

INSERT INTO _resultado
SELECT 'una sola propuesta pendiente por usuario y cosa',
       EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'agente' AND indexname = 'propuesta_pendiente_uk'),
       'volver a abrir el panel no duplica';

-- ---------------------------------------------------------------------------
-- 018 - avisos proactivos
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'credencial_empresa con RLS forzado; el runtime no la escribe',
       coalesce((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
                 WHERE oid = to_regclass('agente.credencial_empresa')), false)
       AND has_table_privilege('agente_app', 'agente.credencial_empresa', 'SELECT')
       AND NOT has_table_privilege('agente_app', 'agente.credencial_empresa', 'INSERT')
       AND NOT has_table_privilege('agente_app', 'agente.credencial_empresa', 'DELETE'),
       'ADR-A10';

INSERT INTO _resultado
SELECT 'el secreto se guarda cifrado (bytea)',
       EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'agente'
               AND table_name = 'credencial_empresa' AND column_name = 'secreto_cifrado'
               AND data_type = 'bytea'),
       'pgp_sym_encrypt';

INSERT INTO _resultado
SELECT 'agente.' || t || ' identifica al usuario por nick',
       EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'agente' AND table_name = t AND column_name = 'usuario'),
       'el JWT de Dnato no trae usr_id'
FROM unnest(ARRAY['notificacion', 'destinatario_alerta', 'dispositivo']) AS t;

INSERT INTO _resultado
SELECT 'notificacion acepta certificacion_por_vencer',
       pg_get_constraintdef(c.oid) LIKE '%certificacion_por_vencer%', 'Pañol'
FROM pg_constraint c WHERE c.conname = 'notificacion_tipo_ck';

-- ---------------------------------------------------------------------------
-- 019 - contrato Kuntur <-> Quirqui
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'agente.' || t || ' con RLS forzado; el runtime no la borra',
       coalesce((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
                 WHERE oid = to_regclass('agente.' || t)), false)
       AND NOT has_table_privilege('agente_app', 'agente.' || t, 'DELETE'),
       'AS-04'
FROM unnest(ARRAY['medicion_pedida', 'medicion_resultado', 'avance_plan']) AS t;

-- R3 por construccion: en el contrato no puede viajar lo que se converso.
-- Los unicos text permitidos son identificadores o estados con CHECK.
INSERT INTO _resultado
SELECT 'R3: el contrato no tiene texto libre (solo ' || coalesce(string_agg(c.table_name || '.' || c.column_name, ', '), 'nada') || ')',
       coalesce(bool_and(c.table_name || '.' || c.column_name = ANY (ARRAY[
           'medicion_pedida.indicador', 'medicion_pedida.alcance', 'medicion_pedida.alcance_id',
           'medicion_pedida.frecuencia', 'medicion_pedida.estado', 'medicion_pedida.pedida_por',
           'medicion_resultado.tool',
           'avance_plan.estado', 'avance_plan.responsable', 'avance_plan.resultado'])), true),
       'un campo text nuevo en estas tablas exige revisar R3'
FROM information_schema.columns c
WHERE c.table_schema = 'agente' AND c.data_type = 'text'
  AND c.table_name IN ('medicion_pedida', 'medicion_resultado', 'avance_plan');

-- ---------------------------------------------------------------------------
-- Todos los scripts registrados
-- ---------------------------------------------------------------------------
INSERT INTO _resultado
SELECT 'script ' || s || ' registrado en schema_version',
       EXISTS (SELECT 1 FROM agente.schema_version WHERE script = s), ''
FROM unnest(ARRAY[
    '001-extensiones', '002-conocimiento-compartido', '003-memoria-cliente',
    '004-cola-candidatos', '005-feedback', '006-entrevistador', '007-notificaciones',
    '008-destinatarios-alerta', '009-alcance-almacenes', '010-seed-taxonomia',
    '011-agentes', '012-tools', '013-corrida', '014-tool-web', '015-fuentes-producto',
    '016-vertical', '017-propuestas', '018-avisos', '019-contrato-coach'
]) AS s;

-- ---------------------------------------------------------------------------
-- Resultado
-- ---------------------------------------------------------------------------
\echo ''
\echo '=== TEST DE ESTRUCTURA — agentes de IA ==='
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
