-- REQ-005 · Módulo Administración — vuelta atrás
-- Deshace solo lo que agregó REQ-005-catalogo-y-planes.sql.
--
-- Dónde se ejecuta: en desarrollo (DEV). NUNCA directo en producción.
-- Se corre en el ambiente de prueba para validar que desaparece solo lo agregado.
--
-- Ejecución (psql, un solo archivo):
--   psql -h <host> -p <puerto> -U <usuario> -d <base> -f REQ-005-catalogo-y-planes-vuelta-atras.sql

BEGIN;

-- 1. Funciones de escritura atómica
DROP FUNCTION IF EXISTS seg.plan_guardar(integer, varchar, varchar, varchar, integer, integer, integer, varchar, integer, boolean, boolean, integer, varchar, varchar, varchar);
DROP FUNCTION IF EXISTS seg.plan_base(integer, varchar);
DROP FUNCTION IF EXISTS seg.plan_baja(integer, varchar);
DROP FUNCTION IF EXISTS seg.plan_copiar(integer, varchar, varchar);
DROP FUNCTION IF EXISTS seg.plan_funcionalidad(integer, varchar, varchar, boolean, varchar);
DROP FUNCTION IF EXISTS seg.catalogo_opcion_crear(varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar);
DROP FUNCTION IF EXISTS seg.catalogo_opcion_editar(varchar, varchar, varchar, varchar, varchar, varchar, text, text, varchar);
DROP FUNCTION IF EXISTS seg.catalogo_publicacion(varchar, varchar, boolean, varchar);
DROP FUNCTION IF EXISTS seg.catalogo_orden(varchar, varchar, text, varchar);

-- 2. Índice único parcial del plan base
DROP INDEX IF EXISTS seg.planes_un_base;

-- 3. Columna del vencimiento (y se restaura el NOT NULL de cuota_mcp)
ALTER TABLE seg.planes DROP COLUMN IF EXISTS vencimiento_unidad;
ALTER TABLE seg.planes ALTER COLUMN cuota_mcp SET NOT NULL;

-- 4. Reconciliación: vuelve al estado de REQ-004 (todo 'publicada')
UPDATE seg.menues
   SET publicacion = 'publicada'
 WHERE publicacion = 'despublicada';

COMMIT;
