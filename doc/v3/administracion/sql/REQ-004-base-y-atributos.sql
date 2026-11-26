-- REQ-004 · Módulo Administración — base y atributos
-- Estructura M-1 (aditiva) + carga de datos M-2, M-5, M-6 y M-7.
--
-- Dónde se ejecuta: en desarrollo (DEV). NUNCA directo en
-- producción. Idempotente: se puede correr más de una vez sin efecto adicional.
-- Vuelta atrás: REQ-004-base-y-atributos-vuelta-atras.sql
--
-- Aprobaciones (2026-11-24): Rodolfo aprobó el análisis de impacto de la barra de Tools
-- y las cargas M-2 y M-6. M-1 (estructura), M-5 y M-7 los decide el equipo (regla de
-- Rodolfo del 2026-11-10: aditivo).
--
-- Antes de correr:
--   1) Búsqueda de usos de las tablas tocadas (INSERT sin lista de columnas / SELECT *)
--      en DataServices, DNATO, Tools y AssetPlanner (ver el PR).
--   2) Reemplazar <CORREO_TOOLS_ADMIN> de la sección M-6 por el correo del ambiente.
--   3) Revisar los valores de M-7 (los corrige Rodolfo).
--
-- Ejecución (psql, un solo archivo):
--   psql -h <host> -p <puerto> -U <usuario> -d <base> -f REQ-004-base-y-atributos.sql

BEGIN;

-- ============================================================================
-- PARTE 1 — ESTRUCTURA (M-1). Solo agrega: columnas optativas, tablas nuevas,
-- una función, un disparador y la ampliación del CHECK de seg.menues.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1.1  Columnas nuevas en core.empresas (todas optativas o con valor por defecto)
-- ---------------------------------------------------------------------------
ALTER TABLE core.empresas
    ADD COLUMN IF NOT EXISTS plan_id            integer,
    ADD COLUMN IF NOT EXISTS estado             varchar(20) NOT NULL DEFAULT 'activa',
    ADD COLUMN IF NOT EXISTS estado_motivo      text,
    ADD COLUMN IF NOT EXISTS estado_plan        varchar(20) NOT NULL DEFAULT 'vigente',
    ADD COLUMN IF NOT EXISTS plan_pedido_id     integer,
    ADD COLUMN IF NOT EXISTS plan_vence         date,
    ADD COLUMN IF NOT EXISTS uso_plan_gratuito  boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS contacto_admin     varchar(255);

COMMENT ON COLUMN core.empresas.estado IS 'activa / suspendida (RF-03/04).';
COMMENT ON COLUMN core.empresas.estado_plan IS 'vigente / pendiente / vencido.';
COMMENT ON COLUMN core.empresas.uso_plan_gratuito IS 'Ya usó un plan gratuito o de prueba.';

-- ---------------------------------------------------------------------------
-- 1.2  Columnas nuevas en seg.users
-- ---------------------------------------------------------------------------
ALTER TABLE seg.users
    ADD COLUMN IF NOT EXISTS superusuario      boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS cambiar_password  boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN seg.users.superusuario IS 'Marca de superusuario (R7, C-5). Reemplaza a TOOLS_ADMIN_USER dentro del módulo.';

-- ---------------------------------------------------------------------------
-- 1.3  Columnas nuevas en seg.menues
-- ---------------------------------------------------------------------------
ALTER TABLE seg.menues
    ADD COLUMN IF NOT EXISTS tipo               varchar(20) NOT NULL DEFAULT 'pantalla',
    ADD COLUMN IF NOT EXISTS texto_presentacion text,
    ADD COLUMN IF NOT EXISTS ayuda              text,
    ADD COLUMN IF NOT EXISTS publicacion        varchar(20) NOT NULL DEFAULT 'publicada';

COMMENT ON COLUMN seg.menues.tipo IS 'pantalla / accion / tool_mcp.';
COMMENT ON COLUMN seg.menues.publicacion IS 'sin_publicar / publicada / despublicada.';

-- ---------------------------------------------------------------------------
-- 1.4  Ampliar el CHECK de seg.menues.modulo para admitir 'MCP'
--      (hoy: PRD, CORE, ALM, MAN, TAR, PAN, LOG, SEG, TRZ, PRO, FIS, BPM, RESI)
-- ---------------------------------------------------------------------------
ALTER TABLE seg.menues DROP CONSTRAINT IF EXISTS menues_check;
ALTER TABLE seg.menues ADD CONSTRAINT menues_check
    CHECK (modulo::text IN ('PRD','CORE','ALM','MAN','TAR','PAN','LOG','SEG','TRZ','PRO','FIS','BPM','RESI','MCP'));

-- ---------------------------------------------------------------------------
-- 1.5  Tablas nuevas (todas en el schema seg)
-- ---------------------------------------------------------------------------

-- Estado de la membresía: UNO por (correo, empresa). La membresía de
-- seg.memberships_users tiene una fila por rol; el estado no depende del rol.
CREATE TABLE IF NOT EXISTS seg.membresias_estado (
    email         varchar(100) NOT NULL,
    "group"       varchar(255) NOT NULL,
    estado        varchar(20)  NOT NULL DEFAULT 'activo',   -- invitado / activo / baneado / baja
    motivo        text,
    fecha_cambio  timestamp    NOT NULL DEFAULT now(),
    quien         varchar(100) NOT NULL DEFAULT CURRENT_USER,
    PRIMARY KEY (email, "group")
);

CREATE TABLE IF NOT EXISTS seg.planes (
    plan_id          serial       PRIMARY KEY,
    codigo           varchar(50)  NOT NULL UNIQUE,
    nombre           varchar(100) NOT NULL,
    icono            varchar(255),
    orden            integer      NOT NULL DEFAULT 0,
    tope_usuarios    integer,                                -- NULL = ilimitado
    cuota_mcp        integer      NOT NULL DEFAULT 0,        -- 0 = sin IA; NULL = ilimitado
    periodo          varchar(20)  NOT NULL DEFAULT 'mes',    -- semana / mes
    dia_renovacion   integer,
    base             boolean      NOT NULL DEFAULT false,    -- plan base del registro
    precio           varchar(50),                            -- texto o 'Consultar'
    gratuito         boolean      NOT NULL DEFAULT false,
    vencimiento_dias integer,
    activo           boolean      NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS seg.planes_funcionalidades (
    plan_id integer     NOT NULL REFERENCES seg.planes(plan_id) ON DELETE CASCADE,
    modulo  varchar(4)  NOT NULL,
    opcion  varchar(255) NOT NULL,
    PRIMARY KEY (plan_id, modulo, opcion)
);

CREATE TABLE IF NOT EXISTS seg.empresas_funcionalidades (
    empr_id integer     NOT NULL,
    modulo  varchar(4)  NOT NULL,
    opcion  varchar(255) NOT NULL,
    activa  boolean     NOT NULL DEFAULT true,
    orden   integer     NOT NULL DEFAULT 0,
    PRIMARY KEY (empr_id, modulo, opcion)
);

CREATE TABLE IF NOT EXISTS seg.menus_custom (
    menu_id     serial       PRIMARY KEY,
    empr_id     integer      NOT NULL,
    nombre      varchar(100) NOT NULL,
    descripcion text,
    UNIQUE (empr_id, nombre)
);

CREATE TABLE IF NOT EXISTS seg.menus_custom_items (
    item_id         serial       PRIMARY KEY,
    menu_id         integer      NOT NULL REFERENCES seg.menus_custom(menu_id) ON DELETE CASCADE,
    tipo            varchar(10)  NOT NULL,                   -- grupo / opcion
    modulo          varchar(4),
    opcion          varchar(255),
    etiqueta        varchar(100),
    etiqueta_icono  varchar(255),
    orden           integer      NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS seg.menus_asignaciones (
    asignacion_id serial       PRIMARY KEY,
    menu_id       integer      NOT NULL REFERENCES seg.menus_custom(menu_id) ON DELETE CASCADE,
    empr_id       integer      NOT NULL,
    "group"       varchar(255),                              -- asignación por rol
    role          varchar(255),
    email         varchar(100),                              -- asignación por persona
    fecha         timestamp    NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS seg.cuota_periodos (
    periodo_id       serial    PRIMARY KEY,
    empr_id          integer   NOT NULL,
    inicio           timestamp NOT NULL,
    fin              timestamp NOT NULL,
    cuota            integer   NOT NULL DEFAULT 0,
    bonificacion     integer   NOT NULL DEFAULT 0,
    consumidas       integer   NOT NULL DEFAULT 0,
    avisos_enviados  text,
    UNIQUE (empr_id, inicio)
);

CREATE TABLE IF NOT EXISTS seg.consumos_mcp (
    consumo_id  bigserial    PRIMARY KEY,
    empr_id     integer      NOT NULL,
    usuario     varchar(100) NOT NULL,
    herramienta varchar(100) NOT NULL,
    fecha       timestamp    NOT NULL DEFAULT now(),
    resultado   varchar(20)  NOT NULL                        -- ok / sin_cuota / fuera_plan / sin_acceso
);

CREATE TABLE IF NOT EXISTS seg.pedidos_plan (
    pedido_id        serial       PRIMARY KEY,
    empr_id          integer      NOT NULL,
    plan_actual_id   integer,
    plan_pedido_id   integer,
    motivo           text,
    estado           varchar(20)  NOT NULL DEFAULT 'pendiente',
    quien_pidio      varchar(100),
    cuando_pidio     timestamp    NOT NULL DEFAULT now(),
    quien_resolvio   varchar(100),
    cuando_resolvio  timestamp,
    motivo_resolucion text
);

CREATE TABLE IF NOT EXISTS seg.intereses (
    interes_id serial       PRIMARY KEY,
    empr_id    integer      NOT NULL,
    usuario    varchar(100) NOT NULL,
    modulo     varchar(4)   NOT NULL,
    opcion     varchar(255) NOT NULL,
    fecha      timestamp    NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS seg.eventos_registro (
    evento_id    bigserial    PRIMARY KEY,
    fecha        timestamp    NOT NULL DEFAULT now(),
    tipo         varchar(30)  NOT NULL,
    empr_id      integer,
    administrador varchar(100),
    plan_id      integer,
    origen       varchar(30),
    aprobacion   varchar(20),
    canal        varchar(20),
    resultado    varchar(20),
    reintentos   integer      NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS seg.cargas_resultados (
    carga_id    bigserial    PRIMARY KEY,
    empr_id     integer      NOT NULL,
    usuario     varchar(100) NOT NULL,
    entidad     varchar(100) NOT NULL,
    fecha       timestamp    NOT NULL DEFAULT now(),
    filas_bien  integer      NOT NULL DEFAULT 0,
    filas_error integer      NOT NULL DEFAULT 0,
    detalle     text
);

-- Auditoría: solo inserción. El disparador (1.7) impide modificar o borrar.
CREATE TABLE IF NOT EXISTS seg.auditoria (
    auditoria_id bigserial    PRIMARY KEY,
    fecha        timestamp    NOT NULL DEFAULT now(),
    quien        varchar(100) NOT NULL,
    empr_id      integer,
    accion       varchar(100) NOT NULL,
    entidad      varchar(100),
    identificador varchar(255),
    detalle      jsonb
);

CREATE TABLE IF NOT EXISTS seg.variables_historial (
    historial_id    bigserial    PRIMARY KEY,
    clave           varchar(255) NOT NULL,
    valor_anterior  text,
    valor_nuevo     text,
    quien           varchar(100) NOT NULL,
    fecha           timestamp    NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- 1.6  Función de cambio de variable: valor + historial + auditoría en UNA operación
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS seg.cambiar_variable(varchar, text, varchar);

CREATE OR REPLACE FUNCTION seg.cambiar_variable(p_clave varchar, p_valor text, p_quien varchar)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
    v_anterior text;
BEGIN
    SELECT valor INTO v_anterior
      FROM core.tablas
     WHERE tabla = p_clave AND empr_id IS NULL AND eliminado = false
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Variable de sistema desconocida: %', p_clave;
    END IF;

    UPDATE core.tablas
       SET valor = p_valor
     WHERE tabla = p_clave AND empr_id IS NULL AND eliminado = false;

    INSERT INTO seg.variables_historial (clave, valor_anterior, valor_nuevo, quien)
    VALUES (p_clave, v_anterior, p_valor, p_quien);

    INSERT INTO seg.auditoria (quien, empr_id, accion, entidad, identificador, detalle)
    VALUES (p_quien, NULL, 'variable_sistema', 'core.tablas', p_clave,
            jsonb_build_object('anterior', v_anterior, 'nuevo', p_valor));

    RETURN 'ok';
END;
$$;

-- ---------------------------------------------------------------------------
-- 1.7  Disparador que impide modificar o borrar filas de seg.auditoria (G5/CP-101)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION seg.auditoria_solo_insercion()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'seg.auditoria es de solo insercion (no se puede %)', TG_OP;
END;
$$;

DROP TRIGGER IF EXISTS auditoria_solo_insercion ON seg.auditoria;
CREATE TRIGGER auditoria_solo_insercion
    BEFORE UPDATE OR DELETE ON seg.auditoria
    FOR EACH ROW EXECUTE PROCEDURE seg.auditoria_solo_insercion();

-- 1.8  Permisos de base: el rol de WSO2 no puede modificar ni borrar la auditoría.
--      El disparador ya lo impide; esto es la segunda capa. El nombre del rol lo
--      define cada ambiente (se completa antes de correr; por defecto se deja
--      comentado para no fallar en copias de DEMO sin ese rol).
--      REVOKE UPDATE, DELETE ON seg.auditoria FROM <rol_wso2>;

-- ============================================================================
-- PARTE 2 — CARGA DE DATOS
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 2.1  M-2: herramientas del agente como opciones del módulo MCP (tipo tool_mcp)
--      NO se cargan opciones del módulo SEG (RF-44). No se agregan permisos, así que
--      la regla "si ningún hijo está habilitado se muestran todos" no puede hacerlas
--      aparecer en el menú: el módulo MCP queda 'habilitado = false' para todos.
--      Si aun así el menú de un usuario cambia, M-2 se difiere a REQ-005/011.
-- ---------------------------------------------------------------------------
INSERT INTO seg.menues
    (modulo, opcion, texto, url, orden, url_icono, texto_onmouseover,
     opcion_padre, tipo, publicacion, usuario_app)
VALUES
    -- fila de nivel 1: el módulo
    ('MCP', 'herramientas_ia', 'Herramientas del agente', '', 950, 'fa fa-robot',
     'Herramientas del agente', NULL, 'tool_mcp', 'publicada', ''),
    -- filas de nivel 2: las tools
    ('MCP', 'man_get_equipos',               'IA: listar equipos',                 '', 1, 'fa fa-robot', 'IA: listar equipos',               'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'man_get_equipo',                'IA: ver un equipo',                  '', 2, 'fa fa-robot', 'IA: ver un equipo',                'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'man_get_ots',                   'IA: listar órdenes de trabajo',      '', 3, 'fa fa-robot', 'IA: listar órdenes de trabajo',    'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'man_get_ot',                    'IA: ver una orden de trabajo',       '', 4, 'fa fa-robot', 'IA: ver una orden de trabajo',     'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'man_create_ot',                 'IA: crear una orden de trabajo',     '', 5, 'fa fa-robot', 'IA: crear una orden de trabajo',   'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'man_get_lecturas',              'IA: ver lecturas de equipos',        '', 6, 'fa fa-robot', 'IA: ver lecturas de equipos',      'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'man_get_preventivos',           'IA: ver planes preventivos',         '', 7, 'fa fa-robot', 'IA: ver planes preventivos',       'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'man_get_kpi_disponibilidad',    'IA: KPI de disponibilidad',          '', 8, 'fa fa-robot', 'IA: KPI de disponibilidad',        'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'man_get_kpi_mttr',              'IA: KPI de MTTR',                    '', 9, 'fa fa-robot', 'IA: KPI de MTTR',                  'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'man_get_kpi_mttf',              'IA: KPI de MTTF',                    '', 10, 'fa fa-robot', 'IA: KPI de MTTF',                 'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'man_get_kpi_fallas',            'IA: KPI de fallas',                  '', 11, 'fa fa-robot', 'IA: KPI de fallas',               'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'core_get_empresa_actual',       'IA: ver la empresa actual',          '', 12, 'fa fa-robot', 'IA: ver la empresa actual',       'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'pan_get_herramientas',          'IA: listar herramientas',            '', 13, 'fa fa-robot', 'IA: listar herramientas',         'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'pan_get_herramienta',           'IA: ver una herramienta',            '', 14, 'fa fa-robot', 'IA: ver una herramienta',         'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'pan_get_movimientos',           'IA: ver movimientos del pañol',      '', 15, 'fa fa-robot', 'IA: ver movimientos del pañol',   'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'pan_get_certificaciones',       'IA: ver certificaciones',            '', 16, 'fa fa-robot', 'IA: ver certificaciones',         'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'alm_get_stock',                 'IA: ver stock',                      '', 17, 'fa fa-robot', 'IA: ver stock',                   'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'alm_get_depositos',             'IA: listar depósitos',               '', 18, 'fa fa-robot', 'IA: listar depósitos',            'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'alm_get_vencimientos',          'IA: ver vencimientos',               '', 19, 'fa fa-robot', 'IA: ver vencimientos',            'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'alm_get_movimientos',           'IA: ver movimientos de almacén',     '', 20, 'fa fa-robot', 'IA: ver movimientos de almacén',  'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'alm_get_entregas',              'IA: ver entregas',                   '', 21, 'fa fa-robot', 'IA: ver entregas',                'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'alm_get_movimientos_internos',  'IA: ver movimientos internos',       '', 22, 'fa fa-robot', 'IA: ver movimientos internos',    'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'alm_get_pedidos_materiales',    'IA: listar pedidos de materiales',   '', 23, 'fa fa-robot', 'IA: listar pedidos de materiales','herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'alm_get_pedido_material',       'IA: ver un pedido de materiales',    '', 24, 'fa fa-robot', 'IA: ver un pedido de materiales', 'herramientas_ia', 'tool_mcp', 'publicada', ''),
    ('MCP', 'alm_crear_pedido_materiales',   'IA: crear pedido de materiales',     '', 25, 'fa fa-robot', 'IA: crear pedido de materiales',  'herramientas_ia', 'tool_mcp', 'publicada', '')
ON CONFLICT (modulo, opcion) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2.2  M-5: una fila 'activo' por (correo, "group") de la membresía existente
-- ---------------------------------------------------------------------------
INSERT INTO seg.membresias_estado (email, "group", estado, quien)
SELECT DISTINCT mu.email, mu."group", 'activo', 'migracion_m5'
  FROM seg.memberships_users mu
 WHERE mu.email IS NOT NULL AND mu."group" IS NOT NULL
ON CONFLICT (email, "group") DO NOTHING;

-- REPORTE M-5 (para Rodolfo; no se ejecuta, se corre aparte para el listado de B.4):
--   SELECT DISTINCT mu."group"
--     FROM seg.memberships_users mu
--    WHERE NOT EXISTS (
--            SELECT 1 FROM core.empresas e
--             WHERE e.nombre = mu."group" AND e.eliminado = false);

-- ---------------------------------------------------------------------------
-- 2.3  M-6: marca de superusuario al correo del ambiente (NO va escrito en el repo)
--      Reemplazar <CORREO_TOOLS_ADMIN> antes de correr. Si no existe el usuario,
--      no marca a nadie y avisa.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    v_email text := '<CORREO_TOOLS_ADMIN>';
BEGIN
    IF v_email NOT LIKE '%@%' THEN
        RAISE EXCEPTION 'M-6: configurar el correo del superusuario antes de correr el script';
    END IF;

    UPDATE seg.users SET superusuario = true WHERE lower(email) = lower(v_email);

    IF NOT FOUND THEN
        RAISE NOTICE 'M-6: no existe un usuario con el correo %; no se marco a nadie', v_email;
    END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- 2.4  M-7: variables de sistema en core.tablas sin empresa (valores de la
--      especificación; Rodolfo los corrige antes de correr). descripcion = Grupo.
--      Los precio_plan_<codigo> se cargan con REQ-005 (cuando existan los planes).
-- ---------------------------------------------------------------------------
INSERT INTO core.tablas (tabla, valor, descripcion, empr_id)
SELECT v.tabla, v.valor, v.descripcion, NULL
  FROM (VALUES
        ('texto_suspension_empresa',   'Tu empresa está momentáneamente suspendida. Comunicate con soporte: {contacto}', 'Suspensión'),
        ('texto_suspension_miembro',   'Tu acceso a {empresa} está suspendido. Comunicate con el administrador de tu empresa: {correo del administrador}', 'Suspensión'),
        ('contacto_soporte',           'soporte@trazalog.com', 'Soporte'),
        ('validez_invitacion_dias',    '7', 'Invitaciones'),
        ('validez_recuperacion_horas', '24', 'Contraseña'),
        ('aviso_cuota_porcentaje',     '80', 'Cuota'),
        ('zona_horaria_cuotas',        'America/Argentina/San_Juan', 'Cuota'),
        ('remitente_correo',           'register@trazalog.com', 'Correo'),
        ('monedas_permitidas',         'ARS, USD', 'Moneda')
       ) AS v(tabla, valor, descripcion)
 WHERE NOT EXISTS (
        SELECT 1 FROM core.tablas t
         WHERE t.tabla = v.tabla AND t.empr_id IS NULL);

COMMIT;
