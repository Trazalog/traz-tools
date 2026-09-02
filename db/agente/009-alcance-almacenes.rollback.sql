-- Rollback de 009-alcance-almacenes.sql
--
-- Vuelve los tipos de alerta a los de mantenimiento y saca la columna modulo.
-- ATENCION: si hay notificaciones con tipos de almacenes, el ALTER del CHECK
-- va a fallar. Hay que borrarlas o reclasificarlas antes.
\set ON_ERROR_STOP on

DROP INDEX IF EXISTS agente.chunk_modulo_ix;
DROP INDEX IF EXISTS agente.tema_modulo_ix;

DO $$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['chunk', 'candidato', 'hecho', 'tema'] LOOP
        EXECUTE format('ALTER TABLE agente.%I DROP CONSTRAINT IF EXISTS %I', t, t || '_modulo_ck');
        EXECUTE format('ALTER TABLE agente.%I DROP COLUMN IF EXISTS modulo', t);
    END LOOP;
END
$$;

ALTER TABLE agente.notificacion DROP CONSTRAINT IF EXISTS notificacion_tipo_ck;
ALTER TABLE agente.notificacion ADD CONSTRAINT notificacion_tipo_ck
    CHECK (tipo IN ('mtbf_deterioro', 'ot_critica_atrasada', 'hallazgo', 'sistema'));

DELETE FROM agente.schema_version WHERE script = '009-alcance-almacenes';
