-- =============================================================================
-- v2.8.1.5 - Esquema ntf: el mecanismo unico de avisos de Tools (ADR-015)
-- =============================================================================
-- Base: trazalog_tools (la de Tools). Compatible con PostgreSQL 11 (produccion
-- es 11.7). Idempotente: se puede aplicar mas de una vez.
-- Rollback: ntf_avisos.rollback.sql
--
-- Que es (detalle en doc/notificaciones/diseno-avisos-tools.md):
--
--   ntf.aviso        un aviso, una vez
--   ntf.destino      a quien le llega y si lo leyo (la campanita)
--   ntf.suscripcion  quien recibe cada tipo cuando el emisor no dice a quien
--   ntf.dispositivo  los navegadores y celulares de cada usuario (token FCM)
--   ntf.envio        un push por dispositivo, con su estado
--
--   ntf.publicar()      la UNICA forma de crear un aviso (la usan el API, los
--                       agentes y el puente de MariaDB)
--   ntf.tomar_envios()  el transporte toma un lote marcandolo 'enviando' en
--                       la misma sentencia: nunca se manda dos veces
--   ntf.marcar_envio()  el transporte informa el resultado (con reintentos)
--   ntf.depurar()       la cola no crece sin limite
--
-- El usuario es el NICK de Dnato (el `sub` del JWT). Los avisos que vienen de
-- AssetPlanner, cuyo usuario no tiene correspondencia con Dnato, usan
-- 'asset:<user_id>' y traen el token del dispositivo en envio.token_directo.
--
-- Acceso: por DataServices con el empr_id del JWT (patron de Tools, ADR-009),
-- no por RLS. El transporte (Siddhi) usa un rol propio, ntf_transporte, que
-- solo puede EJECUTAR las funciones del transporte: no ve las tablas.
-- =============================================================================

\set ON_ERROR_STOP on

CREATE SCHEMA IF NOT EXISTS ntf;
COMMENT ON SCHEMA ntf IS 'Avisos de Tools: campanita y push (ADR-015).';

-- -----------------------------------------------------------------------------
-- Tablas
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ntf.aviso (
    aviso_id      bigserial   PRIMARY KEY,
    empr_id       integer     NOT NULL,
    origen        text        NOT NULL,
    tipo          text        NOT NULL,
    titulo        text        NOT NULL,
    cuerpo        text        NOT NULL DEFAULT '',
    severidad     text        NOT NULL DEFAULT 'info',
    enlace        text,
    entidad_tipo  text,
    entidad_id    text,
    emisor        text,
    dedupe_key    text,
    fec_alta      timestamptz NOT NULL DEFAULT now(),
    vence_en      timestamptz,
    CONSTRAINT aviso_origen_ck    CHECK (origen ~ '^[a-z][a-z0-9_]{1,20}$'),
    CONSTRAINT aviso_tipo_ck      CHECK (tipo ~ '^[a-z][a-z0-9_]{1,60}$'),
    CONSTRAINT aviso_titulo_ck    CHECK (length(btrim(titulo)) > 0),
    CONSTRAINT aviso_severidad_ck CHECK (severidad IN ('info', 'aviso', 'critica'))
);
-- El mismo aviso no se crea dos veces (el emisor arma la clave; si quiere
-- repetirlo por dia, pone la fecha en la clave).
CREATE UNIQUE INDEX IF NOT EXISTS aviso_dedupe_uk
    ON ntf.aviso (empr_id, dedupe_key) WHERE dedupe_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS aviso_empresa_fecha_ix ON ntf.aviso (empr_id, fec_alta DESC);

CREATE TABLE IF NOT EXISTS ntf.destino (
    aviso_id     bigint      NOT NULL REFERENCES ntf.aviso(aviso_id) ON DELETE CASCADE,
    empr_id      integer     NOT NULL,
    usuario      text        NOT NULL,
    leido        boolean     NOT NULL DEFAULT false,
    fec_lectura  timestamptz,
    PRIMARY KEY (aviso_id, usuario),
    CONSTRAINT destino_lectura_ck CHECK (leido = false OR fec_lectura IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS destino_campanita_ix ON ntf.destino (empr_id, usuario, leido);

CREATE TABLE IF NOT EXISTS ntf.suscripcion (
    empr_id   integer     NOT NULL,
    tipo      text        NOT NULL,       -- un tipo de aviso, o '*' para todos
    usuario   text        NOT NULL,
    activo    boolean     NOT NULL DEFAULT true,
    fec_alta  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (empr_id, tipo, usuario)
);

CREATE TABLE IF NOT EXISTS ntf.dispositivo (
    dispositivo_id  bigserial   PRIMARY KEY,
    empr_id         integer     NOT NULL,
    usuario         text        NOT NULL,
    token           text        NOT NULL,
    plataforma      text        NOT NULL DEFAULT 'web',
    activo          boolean     NOT NULL DEFAULT true,
    fec_alta        timestamptz NOT NULL DEFAULT now(),
    fec_ultimo_uso  timestamptz,
    CONSTRAINT dispositivo_token_uk UNIQUE (token),
    CONSTRAINT dispositivo_plataforma_ck CHECK (plataforma IN ('web', 'android', 'ios'))
);
CREATE INDEX IF NOT EXISTS dispositivo_usuario_ix ON ntf.dispositivo (empr_id, usuario) WHERE activo;

CREATE TABLE IF NOT EXISTS ntf.envio (
    envio_id         bigserial   PRIMARY KEY,
    aviso_id         bigint      NOT NULL REFERENCES ntf.aviso(aviso_id) ON DELETE CASCADE,
    dispositivo_id   bigint      REFERENCES ntf.dispositivo(dispositivo_id) ON DELETE SET NULL,
    token_directo    text,
    estado           text        NOT NULL DEFAULT 'pendiente',
    intentos         integer     NOT NULL DEFAULT 0,
    proximo_intento  timestamptz NOT NULL DEFAULT now(),
    ultimo_error     text,
    fec_alta         timestamptz NOT NULL DEFAULT now(),
    fec_tomado       timestamptz,
    fec_envio        timestamptz,
    CONSTRAINT envio_estado_ck  CHECK (estado IN ('pendiente', 'enviando', 'enviado', 'fallido', 'descartado')),
    -- Tiene que haber a donde mandarlo.
    CONSTRAINT envio_destino_ck CHECK (dispositivo_id IS NOT NULL OR token_directo IS NOT NULL),
    -- 'enviado' sin fecha es el agujero de AssetPlanner (fec_realizado nunca escrita).
    CONSTRAINT envio_fecha_ck   CHECK (estado <> 'enviado' OR fec_envio IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS envio_pendientes_ix ON ntf.envio (proximo_intento, envio_id) WHERE estado = 'pendiente';
CREATE INDEX IF NOT EXISTS envio_tomados_ix    ON ntf.envio (fec_tomado) WHERE estado = 'enviando';

-- -----------------------------------------------------------------------------
-- ntf.publicar: la unica forma de crear un aviso
-- -----------------------------------------------------------------------------
-- En una transaccion: el aviso, un destino por destinatario y un envio por
-- cada dispositivo activo de cada uno. Si la dedupe_key ya existe, no crea
-- nada y devuelve el aviso existente.
CREATE OR REPLACE FUNCTION ntf.publicar(
    p_empr_id        integer,
    p_origen         text,
    p_tipo           text,
    p_titulo         text,
    p_cuerpo         text    DEFAULT '',
    p_destinatarios  text[]  DEFAULT NULL,   -- NULL = los suscriptos al tipo
    p_severidad      text    DEFAULT 'info',
    p_enlace         text    DEFAULT NULL,
    p_entidad_tipo   text    DEFAULT NULL,
    p_entidad_id     text    DEFAULT NULL,
    p_emisor         text    DEFAULT NULL,
    p_dedupe_key     text    DEFAULT NULL,
    p_vence_en       timestamptz DEFAULT NULL,
    p_token_directo  text    DEFAULT NULL    -- solo el puente de AssetPlanner
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_aviso   bigint;
    v_destinos text[];
BEGIN
    INSERT INTO ntf.aviso (empr_id, origen, tipo, titulo, cuerpo, severidad, enlace,
                           entidad_tipo, entidad_id, emisor, dedupe_key, vence_en)
    VALUES (p_empr_id, p_origen, p_tipo, p_titulo, coalesce(p_cuerpo, ''),
            coalesce(p_severidad, 'info'), p_enlace, p_entidad_tipo, p_entidad_id,
            p_emisor, p_dedupe_key, p_vence_en)
    ON CONFLICT (empr_id, dedupe_key) WHERE dedupe_key IS NOT NULL DO NOTHING
    RETURNING aviso_id INTO v_aviso;

    IF v_aviso IS NULL THEN
        -- Ya existia: no se duplica nada.
        SELECT aviso_id INTO v_aviso FROM ntf.aviso
        WHERE empr_id = p_empr_id AND dedupe_key = p_dedupe_key;
        RETURN v_aviso;
    END IF;

    v_destinos := coalesce(p_destinatarios, ARRAY(
        SELECT DISTINCT s.usuario FROM ntf.suscripcion s
        WHERE s.empr_id = p_empr_id AND s.activo AND s.tipo IN (p_tipo, '*')));

    INSERT INTO ntf.destino (aviso_id, empr_id, usuario)
    SELECT DISTINCT v_aviso, p_empr_id, u FROM unnest(v_destinos) AS u
    WHERE u IS NOT NULL AND btrim(u) <> '';

    INSERT INTO ntf.envio (aviso_id, dispositivo_id)
    SELECT v_aviso, d.dispositivo_id
    FROM ntf.dispositivo d
    JOIN ntf.destino x ON x.aviso_id = v_aviso AND x.usuario = d.usuario
    WHERE d.empr_id = p_empr_id AND d.activo;

    IF p_token_directo IS NOT NULL AND btrim(p_token_directo) <> '' THEN
        INSERT INTO ntf.envio (aviso_id, token_directo) VALUES (v_aviso, p_token_directo);
    END IF;

    RETURN v_aviso;
END
$$;

-- -----------------------------------------------------------------------------
-- ntf.tomar_envios: el transporte toma un lote, sin duplicados
-- -----------------------------------------------------------------------------
-- Lo tomado pasa a 'enviando' en la misma sentencia (FOR UPDATE SKIP LOCKED):
-- aunque corran dos transportes, ninguno toma lo del otro. Lo que quedo
-- 'enviando' mas de 10 minutos (el transporte se cayo a mitad) vuelve a la cola.
CREATE OR REPLACE FUNCTION ntf.tomar_envios(p_lote integer DEFAULT 50)
RETURNS TABLE (envio_id bigint, token text, titulo text, cuerpo text, enlace text,
               emisor text, severidad text, tipo text, aviso_id bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ntf, pg_temp
AS $$
BEGIN
    UPDATE ntf.envio e SET estado = 'pendiente'
    WHERE e.estado = 'enviando' AND e.fec_tomado < now() - interval '10 minutes';

    RETURN QUERY
    WITH tomados AS (
        UPDATE ntf.envio e
        SET estado = 'enviando', fec_tomado = now(), intentos = e.intentos + 1
        WHERE e.envio_id IN (
            SELECT p.envio_id FROM ntf.envio p
            WHERE p.estado = 'pendiente' AND p.proximo_intento <= now()
            ORDER BY p.envio_id
            LIMIT greatest(p_lote, 1)
            FOR UPDATE SKIP LOCKED)
        RETURNING e.envio_id, e.aviso_id, e.dispositivo_id, e.token_directo
    )
    SELECT t.envio_id, coalesce(t.token_directo, d.token), a.titulo, a.cuerpo, a.enlace,
           a.emisor, a.severidad, a.tipo, a.aviso_id
    FROM tomados t
    JOIN ntf.aviso a ON a.aviso_id = t.aviso_id
    LEFT JOIN ntf.dispositivo d ON d.dispositivo_id = t.dispositivo_id
    ORDER BY t.envio_id;
END
$$;

-- -----------------------------------------------------------------------------
-- ntf.marcar_envio: el transporte informa el resultado
-- -----------------------------------------------------------------------------
--   enviado     listo, con fecha.
--   fallido     reintenta a 1, 5 y 30 minutos; al cuarto intento queda fallido.
--   descartado  el token ya no existe en Firebase: se desactiva el dispositivo.
-- Solo cambia envios que estan 'enviando': una respuesta tardia o repetida no
-- pisa nada.
CREATE OR REPLACE FUNCTION ntf.marcar_envio(p_envio_id bigint, p_resultado text,
                                            p_error text DEFAULT NULL)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ntf, pg_temp
AS $$
DECLARE
    v_intentos integer;
    v_disp     bigint;
    v_estado   text;
BEGIN
    IF p_resultado NOT IN ('enviado', 'fallido', 'descartado') THEN
        RAISE EXCEPTION 'resultado invalido: %', p_resultado;
    END IF;

    SELECT e.intentos, e.dispositivo_id INTO v_intentos, v_disp
    FROM ntf.envio e WHERE e.envio_id = p_envio_id AND e.estado = 'enviando'
    FOR UPDATE;
    IF NOT FOUND THEN
        RETURN 'ignorado';
    END IF;

    IF p_resultado = 'enviado' THEN
        UPDATE ntf.envio SET estado = 'enviado', fec_envio = now(), ultimo_error = NULL
        WHERE envio_id = p_envio_id;
        UPDATE ntf.dispositivo SET fec_ultimo_uso = now() WHERE dispositivo_id = v_disp;
        v_estado := 'enviado';
    ELSIF p_resultado = 'descartado' THEN
        UPDATE ntf.envio SET estado = 'descartado', ultimo_error = left(p_error, 500)
        WHERE envio_id = p_envio_id;
        UPDATE ntf.dispositivo SET activo = false WHERE dispositivo_id = v_disp;
        v_estado := 'descartado';
    ELSIF v_intentos >= 4 THEN
        UPDATE ntf.envio SET estado = 'fallido', ultimo_error = left(p_error, 500)
        WHERE envio_id = p_envio_id;
        v_estado := 'fallido';
    ELSE
        UPDATE ntf.envio SET estado = 'pendiente', ultimo_error = left(p_error, 500),
            proximo_intento = now() + CASE v_intentos WHEN 1 THEN interval '1 minute'
                                                       WHEN 2 THEN interval '5 minutes'
                                                       ELSE interval '30 minutes' END
        WHERE envio_id = p_envio_id;
        v_estado := 'reintenta';
    END IF;
    RETURN v_estado;
END
$$;

-- -----------------------------------------------------------------------------
-- ntf.depurar: la cola no crece sin limite (una vez por dia)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ntf.depurar(p_dias_envio integer DEFAULT 30,
                                       p_dias_leido integer DEFAULT 90)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ntf, pg_temp
AS $$
DECLARE
    n_envios integer;
    n_avisos integer;
BEGIN
    DELETE FROM ntf.envio
    WHERE estado IN ('enviado', 'descartado', 'fallido')
      AND fec_alta < now() - make_interval(days => p_dias_envio);
    GET DIAGNOSTICS n_envios = ROW_COUNT;

    -- Un aviso se va cuando vencio, o cuando todos sus destinatarios lo leyeron
    -- hace mas de p_dias_leido y no le queda nada por mandar.
    DELETE FROM ntf.aviso a
    WHERE (a.vence_en IS NOT NULL AND a.vence_en < now())
       OR (a.fec_alta < now() - make_interval(days => p_dias_leido)
           AND NOT EXISTS (SELECT 1 FROM ntf.destino d WHERE d.aviso_id = a.aviso_id AND NOT d.leido)
           AND NOT EXISTS (SELECT 1 FROM ntf.envio e WHERE e.aviso_id = a.aviso_id
                           AND e.estado IN ('pendiente', 'enviando')));
    GET DIAGNOSTICS n_avisos = ROW_COUNT;

    RETURN n_envios + n_avisos;
END
$$;

-- -----------------------------------------------------------------------------
-- El rol del transporte: solo las funciones, nunca las tablas
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ntf_transporte') THEN
        CREATE ROLE ntf_transporte NOLOGIN;
    END IF;
END
$$;
GRANT USAGE ON SCHEMA ntf TO ntf_transporte;
-- PostgreSQL le da EXECUTE a PUBLIC sobre toda funcion nueva: se saca, asi
-- publicar solo lo ejecuta el duenio del esquema (el usuario de los
-- DataServices de Tools) y el transporte solo lo suyo.
REVOKE ALL ON FUNCTION ntf.publicar(integer, text, text, text, text, text[], text, text, text,
                                    text, text, text, timestamptz, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ntf.tomar_envios(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION ntf.marcar_envio(bigint, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ntf.depurar(integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ntf.tomar_envios(integer) TO ntf_transporte;
GRANT EXECUTE ON FUNCTION ntf.marcar_envio(bigint, text, text) TO ntf_transporte;
GRANT EXECUTE ON FUNCTION ntf.depurar(integer, integer) TO ntf_transporte;
