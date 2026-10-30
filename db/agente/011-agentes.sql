-- =============================================================================
-- 011 - Configuracion de los agentes: Kuntur, Quirqui y Faustino
-- =============================================================================
-- Idempotente. Rollback: 011-agentes.rollback.sql
--
-- ADR-A7 (decision del PM, 2026-10-27): un motor unico de agentes y una
-- CONFIGURACION por agente. Cada fila de agente.agente convierte al motor
-- generico en el Coach, el Asistente o el Entrevistador. Agregar un cuarto
-- agente es agregar una fila, no un servicio.
--
-- La configuracion es GLOBAL, no por empresa (D10: "configurable solo por
-- nosotros, igual para todos los clientes"). Por eso esta tabla no lleva
-- empr_id ni RLS, y el runtime (agente_app) solo la puede LEER: los agentes
-- los configura Trazalog editando este archivo y volviendolo a aplicar.
--
-- Que significa cada columna:
--
--   clave             identificador estable; lo usan el codigo, la API y la
--                     carpeta de avatares. No cambia nunca.
--   nombre            como se presenta ante el usuario. Se puede cambiar.
--   rol               coach | asistente | entrevistador.
--   personalidad      como habla; se le inyecta al modelo antes del prompt.
--   acceso            quien lo puede usar:
--                       admin    -> solo administradores de Dnato (role = 1). R1.
--                       usuario  -> cualquier usuario de la empresa.
--                       curador  -> expertos y curadores de Trazalog.
--   prompt            archivo dentro de prompts/ con las instrucciones.
--   tools_permitidas  patrones de tools MCP que el agente puede usar
--                     (man_get_* = todas las que empiezan asi). Los aplica la
--                     lista blanca de AGENTE-M-02; ninguna tool de escritura
--                     entra aca (ADR-A8).
--   disparadores      que lo pone en marcha (consulta, desvio_kpi, ...).
--   fuentes           que conocimiento lee (industria, empresa, planes).
--   autonomia         'proponer' es el unico valor permitido en esta version.
--   avatar            carpeta en assets/agentes/ con sus imagenes por estado.
--   activo            false = existe pero todavia no se puede usar.
-- =============================================================================

\set ON_ERROR_STOP on

CREATE TABLE IF NOT EXISTS agente.agente (
    clave            text        PRIMARY KEY,
    nombre           text        NOT NULL,
    rol              text        NOT NULL,
    personalidad     text        NOT NULL,
    acceso           text        NOT NULL,
    prompt           text        NOT NULL,
    tools_permitidas text[]      NOT NULL DEFAULT '{}',
    disparadores     text[]      NOT NULL DEFAULT '{}',
    fuentes          text[]      NOT NULL DEFAULT '{}',
    autonomia        text        NOT NULL DEFAULT 'proponer',
    avatar           text        NOT NULL,
    activo           boolean     NOT NULL DEFAULT true,
    fec_alta         timestamptz NOT NULL DEFAULT now(),
    fec_mod          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT agente_clave_ck    CHECK (clave ~ '^[a-z][a-z0-9_]{1,30}$'),
    CONSTRAINT agente_rol_ck      CHECK (rol IN ('coach', 'asistente', 'entrevistador')),
    CONSTRAINT agente_acceso_ck   CHECK (acceso IN ('admin', 'usuario', 'curador')),
    -- Solo nombres de archivo dentro de prompts/: nada de rutas ni "..".
    CONSTRAINT agente_prompt_ck   CHECK (prompt ~ '^[a-z0-9_-]+\.md$'),
    CONSTRAINT agente_avatar_ck   CHECK (avatar ~ '^[a-z0-9_-]+$'),
    -- R5: en esta version los agentes solo proponen. Subir de nivel exige un
    -- cambio de diseño aprobado, no una fila editada.
    CONSTRAINT agente_autonomia_ck CHECK (autonomia = 'proponer'),
    -- R1 por construccion: el Coach no puede quedar abierto a cualquiera.
    CONSTRAINT agente_coach_admin_ck CHECK (rol <> 'coach' OR acceso = 'admin')
);

COMMENT ON TABLE agente.agente IS
    'Configuracion de cada agente (ADR-A7). Global, igual para todos los clientes. '
    'El runtime solo la lee; se edita desde 011-agentes.sql.';

-- El runtime lee, no escribe. Que un bug del orquestador no pueda cambiar
-- quien accede al Coach.
REVOKE ALL ON agente.agente FROM agente_app;
GRANT SELECT ON agente.agente TO agente_app, agente_curador;

-- -----------------------------------------------------------------------------
-- Seed. Editar aca y volver a aplicar actualiza por clave.
-- -----------------------------------------------------------------------------
INSERT INTO agente.agente
    (clave, nombre, rol, personalidad, acceso, prompt,
     tools_permitidas, disparadores, fuentes, avatar, activo)
VALUES
(
    'quirqui', 'Quirqui', 'asistente',
    'Sos Quirqui, un quirquincho que trabaja en la operacion, codo a codo con el '
    'equipo. Hablas en español argentino, de vos, calido y practico, con frases '
    'cortas. Siempre ofreces el siguiente paso concreto.',
    'usuario', 'quirqui.md',
    ARRAY['man_get_*', 'alm_get_*', 'pan_get_*', 'core_get_*', 'tar_get_*',
          'kpi_get_valor', 'web_buscar'],
    ARRAY['consulta', 'apertura_pantalla', 'evento_operativo', 'medicion_pedida'],
    ARRAY['industria', 'empresa'],
    'quirqui', true
),
(
    'kuntur', 'Kuntur', 'coach',
    'Sos Kuntur, un condor que ve la operacion desde arriba y acompaña al '
    'administrador. Hablas en español argentino, de vos, directo y con datos, sin '
    'rodeos. Propones, nunca ordenas; y cuando algo no funciono, lo decis.',
    'admin', 'kuntur.md',
    ARRAY['kpi_get_*', 'kpi_proponer_meta', 'tar_get_*', 'man_get_*', 'alm_get_*',
          'pan_get_*', 'core_get_*', 'web_buscar'],
    ARRAY['consulta', 'primer_ingreso_admin', 'cambio_contexto', 'desvio_kpi',
          'cierre_medicion'],
    ARRAY['industria', 'empresa', 'planes'],
    -- Activo desde 023 (Fase 5, metas): charla de metas y avisos de desvio. El
    -- plan de accion espera al modulo de tareas.
    'kuntur', true
),
(
    'faustino', 'Faustino', 'entrevistador',
    'Sos Faustino, un entrevistador con oficio de maestro: curioso, respetuoso y '
    'paciente. Hablas en español argentino, de vos. Repreguntas y pedis ejemplos '
    'concretos; nunca apuras ni completas lo que el experto no dijo.',
    'curador', 'faustino.md',
    ARRAY['man_get_ots', 'man_get_equipos'],
    ARRAY['sesion_experto'],
    ARRAY['industria'],
    'faustino', true
)
ON CONFLICT (clave) DO UPDATE SET
    nombre           = EXCLUDED.nombre,
    rol              = EXCLUDED.rol,
    personalidad     = EXCLUDED.personalidad,
    acceso           = EXCLUDED.acceso,
    prompt           = EXCLUDED.prompt,
    tools_permitidas = EXCLUDED.tools_permitidas,
    disparadores     = EXCLUDED.disparadores,
    fuentes          = EXCLUDED.fuentes,
    avatar           = EXCLUDED.avatar,
    activo           = EXCLUDED.activo,
    fec_mod          = now();

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('011-agentes', 'Configuracion de los agentes Kuntur, Quirqui y Faustino (ADR-A7)')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();
