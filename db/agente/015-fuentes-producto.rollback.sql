-- Rollback de 015-fuentes-producto.sql
--
-- Borra las fuentes de tipo ayuda y caso_uso (y sus chunks, en cascada) y
-- vuelve el CHECK a los tipos de antes.
\set ON_ERROR_STOP on

DELETE FROM agente.fuente WHERE tipo IN ('ayuda', 'caso_uso');
DROP INDEX IF EXISTS agente.chunk_metadata_gin_ix;
ALTER TABLE agente.fuente DROP CONSTRAINT IF EXISTS fuente_tipo_ck;
ALTER TABLE agente.fuente ADD CONSTRAINT fuente_tipo_ck
    CHECK (tipo IN ('documento', 'experto', 'operativo', 'normativa', 'manual'));

DELETE FROM agente.schema_version WHERE script = '015-fuentes-producto';
