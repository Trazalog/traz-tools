-- =============================================================================
-- 014 - Catalogo: la tool web_buscar (AGENTE-M-05)
-- =============================================================================
-- Idempotente. Rollback: 014-tool-web.rollback.sql
--
-- web_buscar no viene del MCP Gateway: la implementa el motor contra SearXNG
-- autoalojado (agente/web.py). Igual pasa por el catalogo y la lista blanca
-- de 012, como cualquier tool: sin esta fila, ningun agente la puede usar
-- aunque la tenga en su configuracion.
--
-- Clase 'lectura' (no cambia nada) con costo 'externo': la consulta sale a
-- buscadores de terceros. Por eso el riesgo es 'medio' y no 'bajo': si el
-- modelo metiera datos de la empresa en la consulta, saldrian afuera. Lo
-- mitigan el prompt y la descripcion de la tool.
-- =============================================================================

\set ON_ERROR_STOP on

INSERT INTO agente.tool (nombre, modulo, clase, riesgo, costo, reversible, descripcion)
VALUES ('web_buscar', 'web', 'lectura', 'medio', 'externo', true,
        'Busqueda en internet sobre SearXNG autoalojado. Toda cifra que salga de aca va con su URL (R4)')
ON CONFLICT (nombre) DO UPDATE SET
    modulo      = EXCLUDED.modulo,
    clase       = EXCLUDED.clase,
    riesgo      = EXCLUDED.riesgo,
    costo       = EXCLUDED.costo,
    reversible  = EXCLUDED.reversible,
    descripcion = EXCLUDED.descripcion,
    fec_mod     = now();

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('014-tool-web', 'Catalogo: tool web_buscar sobre SearXNG')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();
