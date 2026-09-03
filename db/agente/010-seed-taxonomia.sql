-- =============================================================================
-- 010 - Taxonomia inicial de temas del entrevistador
-- =============================================================================
-- Idempotente. Rollback: 010-seed-taxonomia.rollback.sql
--
-- Esta es la AGENDA con la que el agente entrevistador arranca: de que temas va
-- a preguntarle a un experto. No es un cuestionario fijo -- es una lista
-- priorizada, y la prioridad se recalcula despues cruzandola con los datos
-- reales de la plataforma (que equipos generan mas OTs, que consultas se
-- quedaron sin respuesta).
--
-- ⚠️ PROPUESTA PARA QUE EL PM CORRIJA (gate 🔴 de E4).
--
-- La armo desde el dominio general de mantenimiento minero y desde las dos
-- areas que el agente cubre hoy. Lo que NO puedo saber sin vos:
--
--   * si falta alguna familia de equipos que sea comun en los clientes de San
--     Juan y aca no este;
--   * si alguno de estos temas no aplica al perfil de proveedor de servicios
--     mineros y solo agrega ruido;
--   * el peso inicial: puse prioridades de arranque razonables, pero vos sabes
--     que duele mas hoy en la operacion de un cliente.
--
-- Corregir es editar este archivo y volver a aplicarlo: el script actualiza los
-- temas existentes por nombre, asi que no duplica ni pierde lo capturado.
--
-- El peso 'seed' de origen_prioridad es solo el punto de partida. Cuando corra
-- el recalculo con datos MCP, se le suman las otras fuentes.
-- =============================================================================

\set ON_ERROR_STOP on

-- ---------------------------------------------------------------------------
-- Alta o actualizacion por nombre. Si el tema ya existe se actualizan sus
-- atributos pero NO se toca el estado: un tema ya cubierto sigue cubierto.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION agente.upsert_tema(
    p_nombre text, p_padre text, p_descripcion text, p_modulo text,
    p_tipo_equipo text, p_situacion text, p_prioridad numeric
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_padre_id bigint;
    v_id       bigint;
BEGIN
    IF p_padre IS NOT NULL THEN
        SELECT tema_id INTO v_padre_id FROM agente.tema WHERE nombre = p_padre;
        IF v_padre_id IS NULL THEN
            RAISE EXCEPTION 'El tema padre "%" no existe todavia (revisar el orden del seed)', p_padre;
        END IF;
    END IF;

    INSERT INTO agente.tema (nombre, tema_padre_id, descripcion, modulo,
                             tipo_equipo, situacion, prioridad, origen_prioridad)
    VALUES (p_nombre, v_padre_id, p_descripcion, p_modulo,
            p_tipo_equipo, p_situacion, p_prioridad,
            jsonb_build_object('seed', p_prioridad))
    ON CONFLICT (nombre) DO UPDATE SET
        tema_padre_id    = EXCLUDED.tema_padre_id,
        descripcion      = EXCLUDED.descripcion,
        modulo           = EXCLUDED.modulo,
        tipo_equipo      = EXCLUDED.tipo_equipo,
        situacion        = EXCLUDED.situacion,
        -- La prioridad se actualiza solo en la parte 'seed': lo que haya
        -- aportado el recalculo con datos reales se conserva.
        origen_prioridad = agente.tema.origen_prioridad || jsonb_build_object('seed', EXCLUDED.prioridad)
    RETURNING tema_id INTO v_id;

    RETURN v_id;
END
$$;

COMMENT ON FUNCTION agente.upsert_tema(text, text, text, text, text, text, numeric) IS
    'Alta o actualizacion de un tema de la agenda, por nombre. No pisa el estado ni la prioridad calculada con datos reales.';

-- ===========================================================================
-- MANTENIMIENTO
-- ===========================================================================
SELECT agente.upsert_tema('Mantenimiento', NULL,
    'Raíz del área de mantenimiento de equipos.', 'man', NULL, NULL, 0);

-- --- Chancado y molienda: donde se concentra la criticidad en planta -------
SELECT agente.upsert_tema('Chancado y molienda', 'Mantenimiento',
    'Equipos de reducción de tamaño: chancadoras y molinos.', 'man', NULL, NULL, 0);

SELECT agente.upsert_tema('Chancadoras', 'Chancado y molienda',
    'Mantenimiento de chancadoras primarias, secundarias y cónicas: muelas, mantos, regulación de setting, lubricación.',
    'man', 'chancadora', 'mantenimiento', 90);

SELECT agente.upsert_tema('Molinos', 'Chancado y molienda',
    'Molinos SAG y de bolas: revestimientos, carga de bolas, corona y piñón, sistema de lubricación.',
    'man', 'molino', 'mantenimiento', 85);

-- --- Transporte de material -----------------------------------------------
SELECT agente.upsert_tema('Transporte de material', 'Mantenimiento',
    'Equipos que mueven mineral y estéril.', 'man', NULL, NULL, 0);

SELECT agente.upsert_tema('Cintas transportadoras', 'Transporte de material',
    'Correas, polines, poleas, tensado, empalmes, desalineación y sistemas de limpieza.',
    'man', 'cinta', 'mantenimiento', 80);

SELECT agente.upsert_tema('Equipos móviles', 'Transporte de material',
    'Camiones, cargadores y equipo pesado: motor, transmisión, sistema hidráulico, neumáticos.',
    'man', 'equipo_movil', 'mantenimiento', 75);

-- --- Sistemas transversales de planta -------------------------------------
SELECT agente.upsert_tema('Bombeo e hidráulica', 'Mantenimiento',
    'Bombas de pulpa y de agua, sellos, impulsores, sistemas hidráulicos.',
    'man', 'bomba', 'mantenimiento', 70);

SELECT agente.upsert_tema('Sistemas eléctricos y de potencia', 'Mantenimiento',
    'Motores, tableros, variadores, protecciones y puesta a tierra.',
    'man', NULL, 'mantenimiento', 65);

SELECT agente.upsert_tema('Lubricación', 'Mantenimiento',
    'Plan de lubricación, tipos de lubricante, frecuencias, contaminación y control.',
    'man', NULL, 'mantenimiento', 70);

-- --- Practicas de mantenimiento, no equipos -------------------------------
SELECT agente.upsert_tema('Mantenimiento predictivo', 'Mantenimiento',
    'Análisis de vibraciones, análisis de aceite, termografía: qué medir, cada cuánto y cómo interpretarlo.',
    'man', NULL, 'predictivo', 75);

SELECT agente.upsert_tema('Planificación y programación', 'Mantenimiento',
    'Armado del plan preventivo, backlog, ventanas de parada, criticidad de equipos.',
    'man', NULL, 'planificacion', 60);

SELECT agente.upsert_tema('Diagnóstico de fallas', 'Mantenimiento',
    'Síntomas típicos y su causa probable, por familia de equipo. Es el conocimiento que más se consulta en el momento del problema.',
    'man', NULL, 'falla', 85);

-- ===========================================================================
-- ALMACENES
-- ===========================================================================
SELECT agente.upsert_tema('Almacenes', NULL,
    'Raíz del área de almacenes y materiales.', 'alm', NULL, NULL, 0);

SELECT agente.upsert_tema('Repuestos críticos', 'Almacenes',
    'Qué repuestos conviene tener en stock según criticidad del equipo, y cómo se define el punto de pedido.',
    'alm', NULL, 'stock', 80);

SELECT agente.upsert_tema('Recepción y control de materiales', 'Almacenes',
    'Verificación contra el pedido, control de calidad de recepción, documentación y rechazo.',
    'alm', NULL, 'recepcion', 55);

SELECT agente.upsert_tema('Almacenamiento de sustancias peligrosas', 'Almacenes',
    'Lubricantes, combustibles, reactivos: segregación, contención, ventilación y normativa aplicable.',
    'alm', NULL, 'seguridad', 70);

SELECT agente.upsert_tema('Trazabilidad de materiales', 'Almacenes',
    'Lotes, vencimientos, y a qué equipo u orden se aplicó cada material.',
    'alm', NULL, 'trazabilidad', 60);

SELECT agente.upsert_tema('Pedidos y reposición', 'Almacenes',
    'Cuándo pedir, plazos de proveedores, pedidos de urgencia y su costo real.',
    'alm', NULL, 'pedidos', 55);

-- ===========================================================================
-- TRANSVERSALES — aplican a las dos areas
-- ===========================================================================
SELECT agente.upsert_tema('General', NULL,
    'Raíz de los temas que aplican a las dos áreas.', 'general', NULL, NULL, 0);

SELECT agente.upsert_tema('Seguridad en tareas de mantenimiento', 'General',
    'Bloqueo y etiquetado de energías, permisos de trabajo, espacios confinados, trabajo en altura. Es lo primero que el agente tiene que saber bien.',
    'general', NULL, 'seguridad', 95);

SELECT agente.upsert_tema('Normativa y cumplimiento', 'General',
    'Requisitos que las grandes mineras le exigen a un proveedor: ISO, registros, evidencia. Es el motivo por el que muchos clientes contratan.',
    'general', NULL, 'normativa', 85);

SELECT agente.upsert_tema('Documentación y auditorías', 'General',
    'Qué registrar y cómo, para que una auditoría no encuentre huecos.',
    'general', NULL, 'normativa', 60);

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('010-seed-taxonomia', 'Taxonomia inicial de temas del entrevistador (mantenimiento, almacenes y transversales)')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();
