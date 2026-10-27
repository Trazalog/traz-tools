-- =============================================================================
-- 015 - Fuentes del producto: ayudas y casos de uso (AGENTE-M-06)
-- =============================================================================
-- Idempotente. Rollback: 015-fuentes-producto.rollback.sql
--
-- La base de conocimiento suma el material del propio producto (D1 del plan):
--
--   ayuda      las ayudas de Tools (ayuda/*.html), una seccion por fragmento,
--              con su link en chunk.metadata->>'ayuda'.
--   caso_uso   el catalogo de DocTest (doctest/catalogo/**/*.yaml), un caso
--              validado por fragmento, con sus pantallas y controladores en
--              chunk.metadata: es lo que usa el Asistente para saber que se
--              hace en la pantalla donde esta el usuario.
--
-- Se suman al CHECK de fuente.tipo. La ingesta las reconoce sola por el tipo
-- de archivo, y re-ingestarlas reemplaza en vez de duplicar.
-- =============================================================================

\set ON_ERROR_STOP on

ALTER TABLE agente.fuente DROP CONSTRAINT IF EXISTS fuente_tipo_ck;
ALTER TABLE agente.fuente ADD CONSTRAINT fuente_tipo_ck
    CHECK (tipo IN ('documento', 'experto', 'operativo', 'normativa', 'manual',
                    'ayuda', 'caso_uso'));

-- Para encontrar el caso de uso de una pantalla por su controlador, sin
-- recorrer todos los chunks (AGENTE-AS-01).
CREATE INDEX IF NOT EXISTS chunk_metadata_gin_ix ON agente.chunk USING gin (metadata jsonb_path_ops);

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('015-fuentes-producto', 'Tipos de fuente ayuda y caso_uso, e indice sobre chunk.metadata')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();
