-- v2.8.1.4 — Motor de caché de KPIs (PostgreSQL) para el Tablero del Administrador (v2.5).
--
-- Objetivo: replicar (y mejorar) el mecanismo de caché de AssetPlanner (MySQL) en Postgres.
-- El tablero lee SIEMPRE de esta caché (kpi.cache) vía el KPIDataService, NUNCA del dato vivo.
--
-- Mejoras sobre AssetPlanner (que guarda un solo `valor float`):
--   * `valor_json` (jsonb) además del escalar -> habilita desglose (por depósito, etc.) y drill-down.
--   * `refresh_seg` por KPI + `vence_en` -> cada KPI se recalcula a su propio ritmo.
--   * Registro declarativo (kpi.definiciones) -> agregar un KPI es un INSERT, no tocar código.
--   * Dos fases (cache_tmp -> cache) -> nunca se sirve un dato a medio calcular.
--
-- Idempotente: CREATE ... IF NOT EXISTS / CREATE OR REPLACE. Reejecutable.
-- Ver doc/analisis/dashboard-administrador-landing.md (Fase 2, supuestos A12/A13).

CREATE SCHEMA IF NOT EXISTS kpi;

-- ---------------------------------------------------------------------------
-- Registro de KPIs a cachear.
-- sql_template: query que, dado el parámetro empr_id ($1), devuelve UNA fila con
--               columnas `valor` (numeric, opcional) y `valor_json` (jsonb, opcional).
--               Debe aliasarlas EXACTAMENTE así. Usar $1 para el empr_id (se puede repetir).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS kpi.definiciones (
    nombre        varchar(64)  PRIMARY KEY,
    descripcion   varchar(255),
    modulo        varchar(16),
    sql_template  text         NOT NULL,
    refresh_seg   integer      NOT NULL DEFAULT 300,
    habilitado    boolean      NOT NULL DEFAULT true,
    fec_alta      timestamp    NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Caché publicada: lo que lee el KPIDataService (una fila por KPI x empresa).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS kpi.cache (
    nombre        varchar(64)  NOT NULL,
    empr_id       integer      NOT NULL,
    valor         numeric,
    valor_json    jsonb,
    calculado_en  timestamp    NOT NULL DEFAULT now(),
    vence_en      timestamp,
    PRIMARY KEY (nombre, empr_id)
);

-- Staging: se calcula acá y recién al final se publica a kpi.cache.
CREATE TABLE IF NOT EXISTS kpi.cache_tmp (
    nombre        varchar(64)  NOT NULL,
    empr_id       integer      NOT NULL,
    valor         numeric,
    valor_json    jsonb,
    calculado_en  timestamp    NOT NULL DEFAULT now(),
    vence_en      timestamp,
    PRIMARY KEY (nombre, empr_id)
);

-- Log de corridas (para diagnosticar KPIs que fallan sin tumbar el resto).
CREATE TABLE IF NOT EXISTS kpi.event_log (
    id       serial PRIMARY KEY,
    nombre   varchar(64),
    empr_id  integer,
    estado   varchar(16),   -- OK | ERROR | SKIP
    detalle  text,
    fecha    timestamp DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- kpi.recalcular(p_nombre) — recalcula los KPIs habilitados (o el indicado) para
-- todas las empresas, respetando refresh_seg (salta lo que todavía está fresco).
-- Escribe en kpi.cache_tmp. Cada (KPI, empresa) va en su propio BEGIN/EXCEPTION:
-- si un cálculo falla, se loguea y se sigue con el resto.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION kpi.recalcular(p_nombre varchar DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    d       record;
    e       record;
    v_valor numeric;
    v_json  jsonb;
    v_fresh boolean;
BEGIN
    FOR d IN
        SELECT * FROM kpi.definiciones
        WHERE habilitado AND (p_nombre IS NULL OR nombre = p_nombre)
    LOOP
        FOR e IN
            SELECT empr_id FROM core.empresas
            WHERE empr_id <> 9000            -- 9000 es la empresa plantilla, no operativa
            -- AND <filtro de baja lógica si core.empresas suma una columna de estado>  (ver A-baja)
        LOOP
            -- ¿sigue fresco en la caché publicada? entonces no recalcular.
            SELECT (c.vence_en IS NOT NULL AND c.vence_en > now())
              INTO v_fresh
              FROM kpi.cache c
             WHERE c.nombre = d.nombre AND c.empr_id = e.empr_id;

            IF v_fresh THEN
                CONTINUE;
            END IF;

            BEGIN
                v_valor := NULL; v_json := NULL;
                EXECUTE 'SELECT valor, valor_json FROM (' || d.sql_template || ') q'
                   INTO v_valor, v_json
                  USING e.empr_id;

                INSERT INTO kpi.cache_tmp(nombre, empr_id, valor, valor_json, calculado_en, vence_en)
                VALUES (d.nombre, e.empr_id, v_valor, v_json, now(),
                        now() + make_interval(secs => d.refresh_seg))
                ON CONFLICT (nombre, empr_id) DO UPDATE
                   SET valor = excluded.valor, valor_json = excluded.valor_json,
                       calculado_en = excluded.calculado_en, vence_en = excluded.vence_en;
            EXCEPTION WHEN others THEN
                INSERT INTO kpi.event_log(nombre, empr_id, estado, detalle)
                VALUES (d.nombre, e.empr_id, 'ERROR', sqlstate || ' - ' || sqlerrm);
            END;
        END LOOP;
    END LOOP;
END;
$function$;

-- ---------------------------------------------------------------------------
-- kpi.publicar() — publica cache_tmp -> cache (fase 2). Sólo lo recién calculado.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION kpi.publicar()
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN
    INSERT INTO kpi.cache(nombre, empr_id, valor, valor_json, calculado_en, vence_en)
    SELECT nombre, empr_id, valor, valor_json, calculado_en, vence_en FROM kpi.cache_tmp
    ON CONFLICT (nombre, empr_id) DO UPDATE
       SET valor = excluded.valor, valor_json = excluded.valor_json,
           calculado_en = excluded.calculado_en, vence_en = excluded.vence_en;

    -- limpio el staging ya publicado
    DELETE FROM kpi.cache_tmp;
END;
$function$;

-- ---------------------------------------------------------------------------
-- kpi.correr() — recalcular + publicar. Es lo que dispara el scheduler.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION kpi.correr()
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN
    PERFORM kpi.recalcular();
    PERFORM kpi.publicar();
END;
$function$;

-- ===========================================================================
-- SCHEDULER (supuesto A13).
-- OJO: se había aprobado pg_cron, pero se verificó contra la BD (tools_prod_t, PG 11.18)
-- que pg_cron NO está instalado ni disponible (extensiones presentes: dblink, pgcrypto,
-- plpgsql). Así que el scheduler NO va dentro de Postgres. Dos opciones (elegir una):
--
--   (A) cron del SO en el server de Postgres — una línea de crontab, cada 5 min:
--       */5 * * * *  psql -h 127.0.0.1 -U postgres -d tools_prod_t -c "select kpi.correr();"
--       (con ~/.pgpass para la clave; usuario de bajo privilegio con EXECUTE sobre kpi.correr()).
--
--   (B) Tarea programada de WSO2 (ScheduledTask) que invoque un recurso del DataService
--       que corra kpi.correr(). Mantiene todo en la capa de integración (coherente con MCP/APIM),
--       pero requiere exponer un resource de escritura y versionarlo. Ver doc de análisis.
--
-- Mientras se define/instala el scheduler, la caché se puede poblar a mano para demo:
--       SELECT kpi.correr();
-- ===========================================================================
