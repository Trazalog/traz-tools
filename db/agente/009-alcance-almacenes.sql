-- =============================================================================
-- 009 - Ampliar el alcance del agente a Almacenes
-- =============================================================================
-- Idempotente. Rollback: 009-alcance-almacenes.rollback.sql
--
-- Correccion de alcance detectada por el PM (2026-09-02): el esquema de E1 se
-- escribio pensando solo en Mantenimiento, pero la capa MCP expone las DOS
-- areas -- 11 tools man_* y 9 tools alm_* (stock, depositos, movimientos,
-- entregas, vencimientos, pedidos de materiales). El agente ya podia consultar
-- almacenes; lo que no podia era notificar ni etiquetar conocimiento sobre eso.
--
-- Este script:
--   1. Amplia los tipos de alerta con los de almacenes.
--   2. Agrega la columna `modulo` al conocimiento, a los candidatos, a los
--      hechos capturados y a la agenda del entrevistador, para poder filtrar y
--      priorizar por area.
--
-- Panol y Tareas quedan para una version posterior; cuando sus tools existan,
-- alcanza con sumar sus valores a los CHECK de aca.
-- =============================================================================

\set ON_ERROR_STOP on

-- ---------------------------------------------------------------------------
-- 1. Tipos de alerta
--
-- Los de mantenimiento ya estaban. Los de almacenes son los tres que tienen
-- sentido con las tools disponibles hoy:
--   stock_critico       un articulo por debajo de su minimo
--   material_por_vencer un articulo proximo a vencer (o vencido) todavia en stock
--   pedido_demorado     un pedido de materiales que lleva demasiado sin avanzar
-- ---------------------------------------------------------------------------
ALTER TABLE agente.notificacion DROP CONSTRAINT IF EXISTS notificacion_tipo_ck;
ALTER TABLE agente.notificacion ADD CONSTRAINT notificacion_tipo_ck
    CHECK (tipo IN (
        -- Mantenimiento
        'mtbf_deterioro', 'ot_critica_atrasada',
        -- Almacenes
        'stock_critico', 'material_por_vencer', 'pedido_demorado',
        -- Transversales
        'hallazgo', 'sistema'
    ));

COMMENT ON COLUMN agente.notificacion.tipo IS
    'Tipo de alerta. Mantenimiento: mtbf_deterioro, ot_critica_atrasada. Almacenes: stock_critico, material_por_vencer, pedido_demorado. Transversales: hallazgo, sistema.';

-- ---------------------------------------------------------------------------
-- 2. Modulo al que pertenece cada pieza de conocimiento
--
-- Sin esto, una consulta sobre stock recupera fragmentos de mantenimiento con
-- la misma probabilidad que los propios, y al reves. El filtro por modulo hace
-- que la recuperacion sea del area que corresponde.
--
-- 'general' es para lo que aplica a las dos (seguridad, normativa transversal):
-- ese conocimiento se recupera siempre, sin importar el area de la consulta.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['chunk', 'candidato', 'hecho', 'tema'] LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'agente' AND table_name = t AND column_name = 'modulo'
        ) THEN
            EXECUTE format(
                'ALTER TABLE agente.%I ADD COLUMN modulo text NOT NULL DEFAULT ''general''', t
            );
            EXECUTE format(
                'ALTER TABLE agente.%I ADD CONSTRAINT %I CHECK (modulo IN (''man'', ''alm'', ''general''))',
                t, t || '_modulo_ck'
            );
        END IF;
    END LOOP;
END
$$;

COMMENT ON COLUMN agente.chunk.modulo     IS 'Area a la que aplica: man (mantenimiento), alm (almacenes) o general (transversal: seguridad, normativa). El conocimiento general se recupera siempre.';
COMMENT ON COLUMN agente.candidato.modulo IS 'Area del conocimiento propuesto. Ver agente.chunk.modulo.';
COMMENT ON COLUMN agente.hecho.modulo     IS 'Area del hecho capturado al experto. Ver agente.chunk.modulo.';
COMMENT ON COLUMN agente.tema.modulo      IS 'Area del tema de entrevista. Permite priorizar la agenda por area segun donde haya mas huecos.';

CREATE INDEX IF NOT EXISTS chunk_modulo_ix ON agente.chunk (modulo) WHERE vigente;
CREATE INDEX IF NOT EXISTS tema_modulo_ix  ON agente.tema (modulo, prioridad DESC)
    WHERE estado = 'pendiente';

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('009-alcance-almacenes',
        'Tipos de alerta de almacenes y columna modulo en chunk, candidato, hecho y tema')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();
