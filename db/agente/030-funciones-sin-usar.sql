-- =============================================================================
-- 030 - Funciones de Tools que la empresa no usa (AGENTE-CO-08)
-- =============================================================================
-- Idempotente. Rollback: 030-funciones-sin-usar.rollback.sql
--
-- Kuntur le recomienda al administrador partes de Tools que su empresa no esta
-- usando (por ejemplo: herramientas cargadas pero sin certificaciones, equipos
-- sin planes preventivos, ninguna meta). Igual que el siguiente paso de
-- Quirqui (017), lo deciden REGLAS sobre lo que devuelven las tools de lectura
-- (agente/funciones.py), no el modelo, y cada cifra viene de una tool (R4).
--
-- Reusa agente.propuesta con un tipo nuevo. Diferencia con 017: un "no me
-- interesa" vale para TODA la empresa (no se le vuelve a recomendar a ningun
-- administrador por unos dias), porque la funcion es de la empresa, no del
-- usuario. Eso lo resuelve el codigo; aca solo se habilita el tipo.
-- =============================================================================

\set ON_ERROR_STOP on

ALTER TABLE agente.propuesta DROP CONSTRAINT IF EXISTS propuesta_tipo_ck;
ALTER TABLE agente.propuesta ADD CONSTRAINT propuesta_tipo_ck
    CHECK (tipo IN ('stock_bajo', 'lote_vencido', 'lote_critico',
                    'certificacion_por_vencer', 'funcion_sin_usar'));

COMMENT ON TABLE agente.propuesta IS
    'Siguiente paso que Quirqui le propuso a un usuario (AGENTE-AS-02) y funciones sin usar que Kuntur le recomendo al administrador (AGENTE-CO-08), y que hizo con cada una.';

-- Para el "no me interesa" por empresa: buscar descartadas por empresa y clave.
CREATE INDEX IF NOT EXISTS propuesta_descartada_empresa_ix
    ON agente.propuesta (empr_id, clave, fec_respuesta DESC) WHERE estado = 'descartada';

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('030-funciones-sin-usar', 'Kuntur recomienda funciones de Tools que la empresa no usa (AGENTE-CO-08)')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();
