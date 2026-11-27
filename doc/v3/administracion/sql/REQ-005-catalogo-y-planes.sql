-- REQ-005 · Módulo Administración — catálogo y planes
-- Ajustes aditivos sobre lo que dejó REQ-004 + funciones de escritura atómica.
--
-- Dónde se ejecuta: en desarrollo (DEV). NUNCA directo en producción.
-- Idempotente: se puede correr más de una vez sin efecto adicional.
-- Vuelta atrás: REQ-005-catalogo-y-planes-vuelta-atras.sql
--
-- Qué hace:
--   1. `seg.planes.vencimiento_unidad` (dias / semanas / meses) — la maqueta pide elegir la unidad.
--   2. Índice único parcial para "un solo plan base".
--   3. Reconciliación de datos de una sola vez: publicación ↔ eliminado.
--   4. Funciones seg.* para escrituras atómicas (cambio + auditoría en una transacción),
--      mismo patrón que seg.cambiar_variable de REQ-004.
--
-- Regla de base (Rodolfo, 2026-11-10): todo lo de acá es aditivo (columna, índice, funciones)
-- salvo la reconciliación del punto 3, que es un ajuste de datos de una sola vez y ya está
-- aprobada como parte del análisis de impacto (doc/v3/administracion/IMPACTO_MENU_TOOLS.md §4.2).
--
-- Ejecución (psql, un solo archivo):
--   psql -h <host> -p <puerto> -U <usuario> -d <base> -f REQ-005-catalogo-y-planes.sql

BEGIN;

-- ============================================================================
-- 1. Columna nueva en seg.planes: unidad del vencimiento
-- ============================================================================
ALTER TABLE seg.planes
    ADD COLUMN IF NOT EXISTS vencimiento_unidad varchar(10) NOT NULL DEFAULT 'dias';

COMMENT ON COLUMN seg.planes.vencimiento_unidad IS 'Unidad del vencimiento: dias / semanas / meses.';

-- REQ-004 dejó `cuota_mcp NOT NULL` pero su propio comentario dice "NULL = ilimitado"
-- (y REQ-005 regla 3: "cuota 0 o más, o ilimitada"). Se relaja para que ilimitado sea NULL.
ALTER TABLE seg.planes ALTER COLUMN cuota_mcp DROP NOT NULL;

-- ============================================================================
-- 2. Índice único parcial: hay un solo plan base
-- ============================================================================
CREATE UNIQUE INDEX IF NOT EXISTS planes_un_base
    ON seg.planes ((base))
    WHERE base;

-- ============================================================================
-- 3. Reconciliación de datos (una sola vez): publicación ↔ eliminado
--    REQ-004 dejó `publicacion = 'publicada'` por defecto en TODAS las filas,
--    incluidas las que tenían `eliminado = 1` (borradas desde DNATO en su momento).
--    Acá se dejan parejas antes de abrir la pantalla del Catálogo.
-- ============================================================================
UPDATE seg.menues
   SET publicacion = 'despublicada'
 WHERE eliminado = 1
   AND publicacion <> 'despublicada';

UPDATE seg.menues
   SET publicacion = 'publicada'
 WHERE eliminado = 0
   AND publicacion <> 'publicada';

-- ============================================================================
-- 4. Funciones de escritura atómica (cambio + auditoría en una transacción)
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 4.1 seg.plan_guardar — crear (plan_id NULL) o editar un plan.
--      Al crear, crea además la variable `precio_plan_<codigo>` en core.tablas.
--      El precio se edita después con el mecanismo de variables (PUT /variable).
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS seg.plan_guardar(integer, varchar, varchar, varchar, integer, integer, integer, varchar, integer, boolean, boolean, integer, varchar, varchar, varchar);
CREATE OR REPLACE FUNCTION seg.plan_guardar(
    p_plan_id          integer,
    p_codigo           varchar,
    p_nombre           varchar,
    p_icono            varchar,
    p_orden            integer,
    p_tope_usuarios    integer,
    p_cuota_mcp        integer,
    p_periodo          varchar,
    p_dia_renovacion   integer,
    p_base             boolean,
    p_gratuito         boolean,
    p_vencimiento_dias integer,
    p_vencimiento_unidad varchar,
    p_precio           varchar,
    p_quien            varchar
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_plan_id integer;
BEGIN
    -- Validaciones de negocio (reglas del requerimiento)
    IF p_tope_usuarios IS NOT NULL AND p_tope_usuarios <= 0 THEN
        RAISE EXCEPTION 'tope_invalido';
    END IF;
    IF p_cuota_mcp IS NOT NULL AND p_cuota_mcp < 0 THEN
        RAISE EXCEPTION 'cuota_invalida';
    END IF;
    IF p_periodo NOT IN ('semana', 'mes') THEN
        RAISE EXCEPTION 'periodo_invalido';
    END IF;
    IF p_vencimiento_unidad NOT IN ('dias', 'semanas', 'meses') THEN
        RAISE EXCEPTION 'vencimiento_unidad_invalida';
    END IF;
    IF p_vencimiento_dias IS NOT NULL AND p_vencimiento_dias <= 0 THEN
        RAISE EXCEPTION 'vencimiento_invalido';
    END IF;
    -- El vencimiento solo existe en planes gratuitos / de prueba
    IF (p_vencimiento_dias IS NOT NULL) AND (p_gratuito IS NULL OR p_gratuito = false) THEN
        RAISE EXCEPTION 'vencimiento_solo_gratuito';
    END IF;

    IF p_plan_id IS NULL THEN
        -- Crear
        INSERT INTO seg.planes
            (codigo, nombre, icono, orden, tope_usuarios, cuota_mcp, periodo,
             dia_renovacion, base, gratuito, vencimiento_dias, vencimiento_unidad, activo)
        VALUES
            (p_codigo, p_nombre, p_icono, p_orden, p_tope_usuarios, p_cuota_mcp, p_periodo,
             p_dia_renovacion, COALESCE(p_base, false), COALESCE(p_gratuito, false),
             p_vencimiento_dias, p_vencimiento_unidad, true)
        RETURNING plan_id INTO v_plan_id;

        -- Variable de precio (la columna precio de REQ-004 no se usa)
        INSERT INTO core.tablas (tabla, valor, descripcion, empr_id)
        VALUES ('precio_plan_' || p_codigo, COALESCE(NULLIF(p_precio, ''), 'Consultar'), 'Planes', NULL);

        INSERT INTO seg.auditoria (quien, empr_id, accion, entidad, identificador, detalle)
        VALUES (p_quien, NULL, 'plan.crear', 'seg.planes', p_codigo,
                jsonb_build_object('nombre', p_nombre, 'gratuito', p_gratuito, 'base', p_base));
    ELSE
        -- Editar (el código no cambia después de creado). La marca de plan base NO se
        -- toca acá: se transfiere con seg.plan_base (PUT /plan/base).
        UPDATE seg.planes
           SET nombre = p_nombre,
               icono = p_icono,
               orden = p_orden,
               tope_usuarios = p_tope_usuarios,
               cuota_mcp = p_cuota_mcp,
               periodo = p_periodo,
               dia_renovacion = p_dia_renovacion,
               gratuito = COALESCE(p_gratuito, false),
               vencimiento_dias = p_vencimiento_dias,
               vencimiento_unidad = p_vencimiento_unidad
         WHERE plan_id = p_plan_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'plan_no_existe';
        END IF;

        v_plan_id := p_plan_id;

        INSERT INTO seg.auditoria (quien, empr_id, accion, entidad, identificador, detalle)
        VALUES (p_quien, NULL, 'plan.editar', 'seg.planes', p_codigo,
                jsonb_build_object('nombre', p_nombre, 'gratuito', p_gratuito, 'base', p_base));
    END IF;

    RETURN v_plan_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- 4.2 seg.plan_base — marcar un plan como base (le quita la marca al anterior).
--      El índice único parcial garantiza que hay uno solo.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS seg.plan_base(integer, varchar);
CREATE OR REPLACE FUNCTION seg.plan_base(p_plan_id integer, p_quien varchar)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_anterior varchar;
BEGIN
    SELECT codigo INTO v_anterior FROM seg.planes WHERE base = true LIMIT 1;

    IF NOT EXISTS (SELECT 1 FROM seg.planes WHERE plan_id = p_plan_id AND activo = true) THEN
        RAISE EXCEPTION 'plan_no_existe';
    END IF;

    -- Le quita la marca a todos (en la práctica hay uno solo)
    UPDATE seg.planes SET base = false WHERE base = true;
    UPDATE seg.planes SET base = true WHERE plan_id = p_plan_id;

    INSERT INTO seg.auditoria (quien, empr_id, accion, entidad, identificador, detalle)
    VALUES (p_quien, NULL, 'plan.base', 'seg.planes', p_plan_id::varchar,
            jsonb_build_object('anterior', v_anterior));
END;
$$;

-- ---------------------------------------------------------------------------
-- 4.3 seg.plan_baja — baja lógica (activo = false). Solo si ninguna empresa lo usa.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS seg.plan_baja(integer, varchar);
CREATE OR REPLACE FUNCTION seg.plan_baja(p_plan_id integer, p_quien varchar)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_codigo varchar;
    v_en_uso integer;
BEGIN
    SELECT codigo INTO v_codigo FROM seg.planes WHERE plan_id = p_plan_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'plan_no_existe';
    END IF;

    SELECT count(*) INTO v_en_uso FROM core.empresas WHERE plan_id = p_plan_id AND eliminado = false;
    IF v_en_uso > 0 THEN
        RAISE EXCEPTION 'plan_en_uso';
    END IF;

    UPDATE seg.planes SET activo = false WHERE plan_id = p_plan_id;

    INSERT INTO seg.auditoria (quien, empr_id, accion, entidad, identificador, detalle)
    VALUES (p_quien, NULL, 'plan.baja', 'seg.planes', v_codigo, NULL);
END;
$$;

-- ---------------------------------------------------------------------------
-- 4.4 seg.plan_copiar — duplicar un plan (datos + matriz), sin la marca de base,
--      con nombre "<nombre> (copia)" y un código nuevo.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS seg.plan_copiar(integer, varchar, varchar);
CREATE OR REPLACE FUNCTION seg.plan_copiar(p_plan_id integer, p_codigo_nuevo varchar, p_quien varchar)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_nuevo_id integer;
    v_origen  seg.planes%ROWTYPE;
BEGIN
    SELECT * INTO v_origen FROM seg.planes WHERE plan_id = p_plan_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'plan_no_existe';
    END IF;

    INSERT INTO seg.planes
        (codigo, nombre, icono, orden, tope_usuarios, cuota_mcp, periodo,
         dia_renovacion, base, gratuito, vencimiento_dias, vencimiento_unidad, activo)
    VALUES
        (p_codigo_nuevo,
         v_origen.nombre || ' (copia)',
         v_origen.icono,
         v_origen.orden,
         v_origen.tope_usuarios,
         v_origen.cuota_mcp,
         v_origen.periodo,
         v_origen.dia_renovacion,
         false,                          -- la copia nunca es plan base
         v_origen.gratuito,
         v_origen.vencimiento_dias,
         v_origen.vencimiento_unidad,
         true)
    RETURNING plan_id INTO v_nuevo_id;

    -- Copia la matriz (plan × funcionalidad)
    INSERT INTO seg.planes_funcionalidades (plan_id, modulo, opcion)
    SELECT v_nuevo_id, modulo, opcion
      FROM seg.planes_funcionalidades
     WHERE plan_id = p_plan_id;

    -- Variable de precio de la copia
    INSERT INTO core.tablas (tabla, valor, descripcion, empr_id)
    VALUES ('precio_plan_' || p_codigo_nuevo, 'Consultar', 'Planes', NULL);

    INSERT INTO seg.auditoria (quien, empr_id, accion, entidad, identificador, detalle)
    VALUES (p_quien, NULL, 'plan.duplicar', 'seg.planes', p_codigo_nuevo,
            jsonb_build_object('origen', v_origen.codigo));

    RETURN v_nuevo_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- 4.5 seg.plan_funcionalidad — marcar / desmarcar una casilla de la matriz.
--      Rechaza marcar una funcionalidad que no está publicada.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS seg.plan_funcionalidad(integer, varchar, varchar, boolean, varchar);
CREATE OR REPLACE FUNCTION seg.plan_funcionalidad(
    p_plan_id integer,
    p_modulo  varchar,
    p_opcion  varchar,
    p_agregar boolean,
    p_quien   varchar
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM seg.planes WHERE plan_id = p_plan_id AND activo = true) THEN
        RAISE EXCEPTION 'plan_no_existe';
    END IF;

    IF p_agregar THEN
        -- Solo funcionalidades publicadas (con dirección o tipo tool_mcp)
        IF NOT EXISTS (
            SELECT 1 FROM seg.menues
             WHERE modulo = p_modulo AND opcion = p_opcion
               AND publicacion = 'publicada'
               AND eliminado = 0
               AND (url IS NOT NULL AND url <> '' OR tipo = 'tool_mcp')
        ) THEN
            RAISE EXCEPTION 'funcionalidad_no_publicada';
        END IF;

        INSERT INTO seg.planes_funcionalidades (plan_id, modulo, opcion)
        VALUES (p_plan_id, p_modulo, p_opcion)
        ON CONFLICT (plan_id, modulo, opcion) DO NOTHING;

        INSERT INTO seg.auditoria (quien, empr_id, accion, entidad, identificador, detalle)
        VALUES (p_quien, NULL, 'plan.funcionalidad.agregar', 'seg.planes_funcionalidades',
                p_modulo || '.' || p_opcion, jsonb_build_object('plan_id', p_plan_id));
    ELSE
        DELETE FROM seg.planes_funcionalidades
         WHERE plan_id = p_plan_id AND modulo = p_modulo AND opcion = p_opcion;

        INSERT INTO seg.auditoria (quien, empr_id, accion, entidad, identificador, detalle)
        VALUES (p_quien, NULL, 'plan.funcionalidad.quitar', 'seg.planes_funcionalidades',
                p_modulo || '.' || p_opcion, jsonb_build_object('plan_id', p_plan_id));
    END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- 4.6 seg.catalogo_opcion_crear — opción nueva del catálogo. Queda SIN PUBLICAR
--      (eliminado = 1) para no aparecer en el menú de Tools. Rechaza clave
--      repetida, padre de otro módulo y padre que no sea opción raíz.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS seg.catalogo_opcion_crear(varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar);
CREATE OR REPLACE FUNCTION seg.catalogo_opcion_crear(
    p_modulo       varchar,
    p_opcion       varchar,
    p_texto        varchar,
    p_url          varchar,
    p_opcion_padre varchar,
    p_url_icono    varchar,
    p_tipo         varchar,
    p_quien        varchar
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_tipo NOT IN ('pantalla', 'accion', 'tool_mcp') THEN
        RAISE EXCEPTION 'tipo_invalido';
    END IF;

    IF EXISTS (SELECT 1 FROM seg.menues WHERE modulo = p_modulo AND opcion = p_opcion) THEN
        RAISE EXCEPTION 'clave_repetida';
    END IF;

    IF p_opcion_padre IS NOT NULL AND p_opcion_padre <> '' THEN
        IF NOT EXISTS (
            SELECT 1 FROM seg.menues
             WHERE modulo = p_modulo AND opcion = p_opcion_padre AND opcion_padre IS NULL
        ) THEN
            RAISE EXCEPTION 'padre_invalido';
        END IF;
    END IF;

    INSERT INTO seg.menues
        (modulo, opcion, texto, url, orden, url_icono, texto_onmouseover,
         opcion_padre, eliminado, usuario_app, tipo, publicacion)
    VALUES
        (p_modulo, p_opcion, p_texto, p_url, 0, COALESCE(p_url_icono, ''), p_texto,
         NULLIF(p_opcion_padre, ''), 1, '', p_tipo, 'sin_publicar');

    INSERT INTO seg.auditoria (quien, empr_id, accion, entidad, identificador, detalle)
    VALUES (p_quien, NULL, 'catalogo.opcion.crear', 'seg.menues', p_modulo || '.' || p_opcion,
            jsonb_build_object('tipo', p_tipo, 'padre', p_opcion_padre));
END;
$$;

-- ---------------------------------------------------------------------------
-- 4.7 seg.catalogo_opcion_editar — textos, ícono, tipo y dirección de una opción.
--      El tipo no se puede pasar a `tool_mcp` ni salir de `tool_mcp` (cambia de módulo).
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS seg.catalogo_opcion_editar(varchar, varchar, varchar, varchar, varchar, varchar, text, text, varchar);
CREATE OR REPLACE FUNCTION seg.catalogo_opcion_editar(
    p_modulo            varchar,
    p_opcion            varchar,
    p_texto             varchar,
    p_url_icono         varchar,
    p_tipo              varchar,
    p_url               varchar,
    p_texto_presentacion text,
    p_ayuda             text,
    p_quien             varchar
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_tipo_actual varchar;
BEGIN
    IF p_tipo NOT IN ('pantalla', 'accion', 'tool_mcp') THEN
        RAISE EXCEPTION 'tipo_invalido';
    END IF;

    SELECT tipo INTO v_tipo_actual FROM seg.menues WHERE modulo = p_modulo AND opcion = p_opcion;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'opcion_no_existe';
    END IF;

    IF (v_tipo_actual = 'tool_mcp') <> (p_tipo = 'tool_mcp') THEN
        RAISE EXCEPTION 'tipo_no_cambia_modulo';
    END IF;

    UPDATE seg.menues
       SET texto = p_texto,
           url_icono = COALESCE(p_url_icono, url_icono),
           tipo = p_tipo,
           url = p_url,
           texto_presentacion = p_texto_presentacion,
           ayuda = p_ayuda
     WHERE modulo = p_modulo AND opcion = p_opcion;

    INSERT INTO seg.auditoria (quien, empr_id, accion, entidad, identificador, detalle)
    VALUES (p_quien, NULL, 'catalogo.opcion.editar', 'seg.menues', p_modulo || '.' || p_opcion,
            jsonb_build_object('tipo', p_tipo, 'texto', p_texto));
END;
$$;

-- ---------------------------------------------------------------------------
-- 4.8 seg.catalogo_publicacion — publicar / despublicar una opción.
--      Publicación y `eliminado` van juntas. Publicar exige nombre, ícono, tipo,
--      texto de presentación y ayuda.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS seg.catalogo_publicacion(varchar, varchar, boolean, varchar);
CREATE OR REPLACE FUNCTION seg.catalogo_publicacion(
    p_modulo  varchar,
    p_opcion  varchar,
    p_publicar boolean,
    p_quien   varchar
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_fila record;
BEGIN
    SELECT * INTO v_fila FROM seg.menues WHERE modulo = p_modulo AND opcion = p_opcion;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'opcion_no_existe';
    END IF;

    IF p_publicar THEN
        IF v_fila.texto IS NULL OR btrim(v_fila.texto) = ''
           OR v_fila.url_icono IS NULL OR btrim(v_fila.url_icono) = ''
           OR v_fila.tipo IS NULL OR btrim(v_fila.tipo) = ''
           OR v_fila.texto_presentacion IS NULL OR btrim(v_fila.texto_presentacion) = ''
           OR v_fila.ayuda IS NULL OR btrim(v_fila.ayuda) = ''
        THEN
            RAISE EXCEPTION 'faltan_datos_publicar';
        END IF;

        UPDATE seg.menues SET publicacion = 'publicada', eliminado = 0
         WHERE modulo = p_modulo AND opcion = p_opcion;

        INSERT INTO seg.auditoria (quien, empr_id, accion, entidad, identificador, detalle)
        VALUES (p_quien, NULL, 'catalogo.publicar', 'seg.menues', p_modulo || '.' || p_opcion, NULL);
    ELSE
        UPDATE seg.menues SET publicacion = 'despublicada', eliminado = 1
         WHERE modulo = p_modulo AND opcion = p_opcion;

        INSERT INTO seg.auditoria (quien, empr_id, accion, entidad, identificador, detalle)
        VALUES (p_quien, NULL, 'catalogo.despublicar', 'seg.menues', p_modulo || '.' || p_opcion, NULL);
    END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- 4.9 seg.catalogo_orden — reordenar los hermanos de un módulo (o las raíces).
--      Renumera con números del mismo largo para que el orden por texto de Tools
--      y el número coincidan, sin tocar la consulta.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS seg.catalogo_orden(varchar, varchar, text, varchar);
CREATE OR REPLACE FUNCTION seg.catalogo_orden(
    p_modulo       varchar,
    p_opcion_padre varchar,
    p_opciones     text,
    p_quien        varchar
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_parts  text[];
    v_n      integer;
    v_start  integer;
    v_max    integer;
    v_i      integer;
    v_opcion varchar;
BEGIN
    v_parts := string_to_array(p_opciones, ',');
    v_n := array_length(v_parts, 1);

    IF v_n IS NULL OR v_n = 0 THEN
        RAISE EXCEPTION 'orden_vacio';
    END IF;

    -- Elige el ancho para que todos los números tengan la misma cantidad de dígitos
    v_start := 10;
    v_max := v_start + 10 * (v_n - 1);
    WHILE v_max >= v_start * 10 LOOP
        v_start := v_start * 10;
        v_max := v_start + 10 * (v_n - 1);
    END LOOP;

    FOR v_i IN 1..v_n LOOP
        v_opcion := btrim(v_parts[v_i]);
        UPDATE seg.menues
           SET orden = v_start + (v_i - 1) * 10
         WHERE modulo = p_modulo
           AND opcion = v_opcion
           AND (opcion_padre = p_opcion_padre
                OR (opcion_padre IS NULL AND p_opcion_padre IS NULL));
    END LOOP;

    INSERT INTO seg.auditoria (quien, empr_id, accion, entidad, identificador, detalle)
    VALUES (p_quien, NULL, 'catalogo.orden', 'seg.menues', p_modulo,
            jsonb_build_object('padre', p_opcion_padre, 'orden', p_opciones));
END;
$$;

COMMIT;
