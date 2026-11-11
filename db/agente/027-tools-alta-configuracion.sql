-- =============================================================================
-- 027 - Herramientas de alta de configuracion para Kuntur (ADR-A12, lote 1)
-- =============================================================================
-- Idempotente. Rollback: 027-tools-alta-configuracion.rollback.sql
--
-- Las tres primeras herramientas REALES de clase configuracion (las de 026 son
-- simuladas): establecimiento, deposito y valores de listas. Son recursos de la
-- fachada MCP (toolsMCPAPI) sobre los servicios de datos que ya usan las
-- pantallas, sin modificarlos. Analisis de impacto aprobado por el PM el
-- 2026-11-11 (doc/agente/analisis-impacto-kuntur-configuracion.md, A-1).
--
-- Kuntur las PROPONE; se ejecutan solo cuando el administrador toca "Cargar",
-- con su token (agente/cargas.py). Con token de maquina el gateway responde 403.
-- =============================================================================

\set ON_ERROR_STOP on

INSERT INTO agente.tool (nombre, modulo, clase, riesgo, reversible, descripcion)
VALUES
    ('core_alta_establecimiento', 'core', 'configuracion', 'medio', false, 'Alta de un establecimiento de la empresa'),
    ('alm_alta_deposito',         'alm',  'configuracion', 'medio', false, 'Alta de un depósito en un establecimiento'),
    ('core_alta_valor',           'core', 'configuracion', 'medio', false, 'Alta de una unidad de medida, tipo de artículo o tipo de herramienta')
ON CONFLICT (nombre) DO UPDATE SET
    modulo      = EXCLUDED.modulo,
    clase       = EXCLUDED.clase,
    riesgo      = EXCLUDED.riesgo,
    reversible  = EXCLUDED.reversible,
    descripcion = EXCLUDED.descripcion,
    fec_mod     = now();

UPDATE agente.agente
   SET tools_configuracion = ARRAY(SELECT DISTINCT unnest(tools_configuracion || ARRAY[
           'core_alta_establecimiento', 'alm_alta_deposito', 'core_alta_valor']) ORDER BY 1),
       fec_mod = now()
 WHERE clave = 'kuntur';

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('027-tools-alta-configuracion', 'Herramientas reales de alta de configuracion para Kuntur (ADR-A12, lote 1)')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();
