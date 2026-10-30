-- v2.8.1.6 — Historia, objetivos y desvíos sobre el motor de KPIs (KPI-HIST, KPI-OBJ).
--
-- Lo necesita Kuntur, el Coach de los agentes (ADR-A9): fijar objetivos sobre los KPIs de la
-- empresa, detectar cuándo no se cumplen y medir si un plan los movió. Análisis de impacto
-- aprobado por el PM el 2026-10-29: doc/agente/analisis-impacto-kpi-objetivos.md.
--
-- Qué NO cambia: kpi.cache, kpi.recalcular(), kpi.correr() y lo que lee el Tablero del
-- Administrador. kpi.publicar() suma la historia en un bloque de excepción propio: si la
-- historia falla, kpi.cache se publica igual y el error queda en kpi.event_log.
--
-- Requiere v2.8.1.4 (kpi_cache_engine.sql). Idempotente. Probado en PostgreSQL 11.
-- Rollback: kpi_objetivos.rollback.sql (vuelve publicar() a la versión de v2.8.1.4).

-- ---------------------------------------------------------------------------
-- KPI-HIST — una fila por KPI, empresa y día (no por corrida: el cron corre cada 5 minutos).
-- El último valor del día pisa al anterior del mismo día. Se retienen 2 años.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS kpi.historico (
    nombre        varchar(64)  NOT NULL,
    empr_id       integer      NOT NULL,
    fecha         date         NOT NULL,
    valor         numeric,
    valor_json    jsonb,
    calculado_en  timestamp    NOT NULL,
    PRIMARY KEY (nombre, empr_id, fecha)
);
CREATE INDEX IF NOT EXISTS historico_fecha_ix ON kpi.historico (fecha);

COMMENT ON TABLE kpi.historico IS
    'Serie diaria de cada KPI por empresa (el ultimo valor del dia). La escribe kpi.publicar(); retencion 2 anos.';

-- ---------------------------------------------------------------------------
-- KPI-OBJ — objetivos. Los graba el ADMINISTRADOR desde Tools (ADR-A8: Kuntur los propone,
-- no los graba). fuente 'tools' = un KPI de kpi.definiciones; 'man' = un KPI de
-- Mantenimiento que todavía calcula AssetPlanner (lo evalúa el job de Kuntur por MCP).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS kpi.objetivos (
    objetivo_id    serial        PRIMARY KEY,
    empr_id        integer       NOT NULL,
    kpi            varchar(64)   NOT NULL,
    fuente         varchar(8)    NOT NULL DEFAULT 'tools',
    operador       varchar(2)    NOT NULL,
    meta           numeric       NOT NULL,
    desde          date          NOT NULL DEFAULT current_date,
    hasta          date          NOT NULL,
    responsable    varchar(255),
    petr_id        integer,                    -- pedido de trabajo del plan (TAR, ADR-A9)
    estado         varchar(16)   NOT NULL DEFAULT 'vigente',
    propuesto_por  varchar(64)   NOT NULL DEFAULT 'usuario',  -- 'kuntur' o 'usuario'
    usuario_alta   varchar(255)  NOT NULL,     -- quien lo confirmo (nick)
    fec_alta       timestamp     NOT NULL DEFAULT now(),
    usuario_baja   varchar(255),
    fec_baja       timestamp,
    CONSTRAINT objetivos_fuente_ck   CHECK (fuente IN ('tools', 'man')),
    CONSTRAINT objetivos_operador_ck CHECK (operador IN ('>=', '<=')),
    CONSTRAINT objetivos_estado_ck   CHECK (estado IN ('vigente', 'cumplido', 'vencido', 'cancelado')),
    CONSTRAINT objetivos_fechas_ck   CHECK (hasta >= desde)
);
CREATE INDEX IF NOT EXISTS objetivos_empresa_ix ON kpi.objetivos (empr_id, estado);

COMMENT ON TABLE kpi.objetivos IS
    'Objetivos sobre KPIs. Los confirma el administrador desde Tools; Kuntur solo los propone (ADR-A8, ADR-A9).';
COMMENT ON COLUMN kpi.objetivos.estado IS
    'vigente | cancelado se guardan. vencido se calcula (hasta < hoy) en kpi.objetivos_de(); cumplido lo decide quien cierra el objetivo.';

-- ---------------------------------------------------------------------------
-- kpi.publicar() — igual que en v2.8.1.4 más la historia del día, aislada.
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

    -- Historia (KPI-HIST). En su propio bloque: si falla, lo de arriba (lo que lee el
    -- Tablero) queda publicado igual y el error va al log.
    BEGIN
        INSERT INTO kpi.historico(nombre, empr_id, fecha, valor, valor_json, calculado_en)
        SELECT nombre, empr_id, calculado_en::date, valor, valor_json, calculado_en FROM kpi.cache_tmp
        ON CONFLICT (nombre, empr_id, fecha) DO UPDATE
           SET valor = excluded.valor, valor_json = excluded.valor_json,
               calculado_en = excluded.calculado_en
         WHERE excluded.calculado_en >= kpi.historico.calculado_en;

        DELETE FROM kpi.historico WHERE fecha < current_date - 730;
    EXCEPTION WHEN others THEN
        INSERT INTO kpi.event_log(nombre, empr_id, estado, detalle)
        VALUES ('kpi.historico', NULL, 'ERROR', sqlstate || ' - ' || sqlerrm);
    END;

    -- limpio el staging ya publicado
    DELETE FROM kpi.cache_tmp;
END;
$function$;

-- ---------------------------------------------------------------------------
-- kpi.objetivos_de(empr_id) — los objetivos de la empresa con el estado efectivo (un vigente
-- cuyo plazo pasó se informa como vencido) y el valor actual si el KPI es de tools.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION kpi.objetivos_de(p_empr_id integer, p_solo_vigentes boolean DEFAULT true)
RETURNS TABLE (objetivo_id integer, kpi varchar, descripcion varchar, fuente varchar, operador varchar,
               meta numeric, desde date, hasta date, responsable varchar, petr_id integer,
               estado varchar, propuesto_por varchar, usuario_alta varchar, fec_alta timestamp,
               valor_actual numeric, calculado_en timestamp, cumple boolean)
LANGUAGE sql
STABLE
AS $function$
    SELECT o.objetivo_id, o.kpi, d.descripcion, o.fuente, o.operador, o.meta, o.desde, o.hasta,
           o.responsable, o.petr_id,
           (CASE WHEN o.estado = 'vigente' AND o.hasta < current_date THEN 'vencido' ELSE o.estado END)::varchar,
           o.propuesto_por, o.usuario_alta, o.fec_alta,
           c.valor, c.calculado_en,
           CASE WHEN c.valor IS NULL THEN NULL
                WHEN o.operador = '>=' THEN c.valor >= o.meta
                ELSE c.valor <= o.meta END
      FROM kpi.objetivos o
      LEFT JOIN kpi.definiciones d ON d.nombre = o.kpi AND o.fuente = 'tools'
      LEFT JOIN kpi.cache c ON o.fuente = 'tools' AND c.nombre = o.kpi AND c.empr_id = o.empr_id
     WHERE o.empr_id = p_empr_id
       AND (NOT p_solo_vigentes OR (o.estado = 'vigente' AND o.hasta >= current_date))
     ORDER BY o.hasta, o.objetivo_id;
$function$;

-- ---------------------------------------------------------------------------
-- kpi.desvios(empr_id) — los objetivos vigentes de fuente 'tools' que hoy no se cumplen,
-- con el valor de hace 30 días (el más cercano anterior en la historia) para ver la tendencia.
-- Los de fuente 'man' no están: el valor vive en AssetPlanner y los evalúa el job de Kuntur.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION kpi.desvios(p_empr_id integer)
RETURNS TABLE (objetivo_id integer, kpi varchar, operador varchar, meta numeric, hasta date,
               responsable varchar, valor_actual numeric, calculado_en timestamp,
               valor_hace_30 numeric, fecha_hace_30 date, tendencia varchar)
LANGUAGE sql
STABLE
AS $function$
    SELECT o.objetivo_id, o.kpi, o.operador, o.meta, o.hasta, o.responsable,
           c.valor, c.calculado_en, h.valor, h.fecha,
           (CASE WHEN h.valor IS NULL OR c.valor IS NULL THEN 'sin_historia'
                 WHEN c.valor = h.valor THEN 'igual'
                 WHEN (o.operador = '>=') = (c.valor > h.valor) THEN 'mejora'
                 ELSE 'empeora' END)::varchar
      FROM kpi.objetivos o
      JOIN kpi.cache c ON c.nombre = o.kpi AND c.empr_id = o.empr_id
      LEFT JOIN LATERAL (
            SELECT hh.valor, hh.fecha FROM kpi.historico hh
             WHERE hh.nombre = o.kpi AND hh.empr_id = o.empr_id AND hh.fecha <= current_date - 30
             ORDER BY hh.fecha DESC LIMIT 1) h ON true
     WHERE o.empr_id = p_empr_id
       AND o.fuente = 'tools'
       AND o.estado = 'vigente'
       AND current_date BETWEEN o.desde AND o.hasta
       AND c.valor IS NOT NULL
       AND NOT (CASE WHEN o.operador = '>=' THEN c.valor >= o.meta ELSE c.valor <= o.meta END)
     ORDER BY o.hasta, o.objetivo_id;
$function$;

-- ---------------------------------------------------------------------------
-- kpi.objetivo_guardar(...) — alta de un objetivo, confirmada por el administrador.
-- Valida lo que un CHECK no puede: que el KPI de tools exista y que no haya otro objetivo
-- vigente para el mismo KPI en la empresa (uno por KPI, para que el desvío sea claro).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION kpi.objetivo_guardar(
    p_empr_id integer, p_kpi varchar, p_fuente varchar, p_operador varchar, p_meta numeric,
    p_desde date, p_hasta date, p_responsable varchar, p_propuesto_por varchar, p_usuario varchar)
RETURNS integer
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id integer;
BEGIN
    IF p_empr_id IS NULL OR p_empr_id <= 0 THEN
        RAISE EXCEPTION 'empr_id invalido';
    END IF;
    IF coalesce(p_usuario, '') = '' THEN
        RAISE EXCEPTION 'falta el usuario que confirma el objetivo';
    END IF;
    IF coalesce(p_fuente, 'tools') = 'tools'
       AND NOT EXISTS (SELECT 1 FROM kpi.definiciones WHERE nombre = p_kpi) THEN
        RAISE EXCEPTION 'el KPI % no existe', p_kpi;
    END IF;
    IF EXISTS (SELECT 1 FROM kpi.objetivos
                WHERE empr_id = p_empr_id AND kpi = p_kpi AND estado = 'vigente'
                  AND hasta >= current_date) THEN
        RAISE EXCEPTION 'ya hay un objetivo vigente para %: cancelalo antes de cargar otro', p_kpi;
    END IF;

    INSERT INTO kpi.objetivos (empr_id, kpi, fuente, operador, meta, desde, hasta, responsable,
                               propuesto_por, usuario_alta)
    VALUES (p_empr_id, p_kpi, coalesce(p_fuente, 'tools'), p_operador, p_meta,
            coalesce(p_desde, current_date), p_hasta, nullif(p_responsable, ''),
            CASE WHEN p_propuesto_por = 'kuntur' THEN 'kuntur' ELSE 'usuario' END, p_usuario)
    RETURNING objetivo_id INTO v_id;
    RETURN v_id;
END;
$function$;

-- kpi.objetivo_cancelar(...) — baja lógica. Solo de la empresa indicada.
CREATE OR REPLACE FUNCTION kpi.objetivo_cancelar(p_empr_id integer, p_objetivo_id integer, p_usuario varchar)
RETURNS integer
LANGUAGE sql
AS $function$
    WITH c AS (
        UPDATE kpi.objetivos SET estado = 'cancelado', usuario_baja = p_usuario, fec_baja = now()
         WHERE objetivo_id = p_objetivo_id AND empr_id = p_empr_id AND estado = 'vigente'
        RETURNING 1)
    SELECT count(*)::integer FROM c;
$function$;
