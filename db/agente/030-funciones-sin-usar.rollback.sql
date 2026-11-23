-- Rollback de 030-funciones-sin-usar.sql
--
-- Borra las recomendaciones de funciones sin usar y vuelve el tipo de
-- propuesta a lo que dejo 017. Kuntur deja de recomendar funciones.
\set ON_ERROR_STOP on

DELETE FROM agente.propuesta WHERE tipo = 'funcion_sin_usar';
DROP INDEX IF EXISTS agente.propuesta_descartada_empresa_ix;
ALTER TABLE agente.propuesta DROP CONSTRAINT IF EXISTS propuesta_tipo_ck;
ALTER TABLE agente.propuesta ADD CONSTRAINT propuesta_tipo_ck
    CHECK (tipo IN ('stock_bajo', 'lote_vencido', 'lote_critico', 'certificacion_por_vencer'));
COMMENT ON TABLE agente.propuesta IS 'Siguiente paso que Quirqui le propuso a un usuario, y que hizo con el (AGENTE-AS-02).';
DELETE FROM agente.schema_version WHERE script = '030-funciones-sin-usar';
