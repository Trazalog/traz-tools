-- =============================================================================
-- 023 - Kuntur activo: charla de metas y avisos de desvio (AGENTE-CO-01, CO-03, CO-07)
-- =============================================================================
-- Idempotente. Rollback: 023-kuntur-metas.rollback.sql
--
-- Desde aca Kuntur, el Coach, se puede usar. Solo lo ven los administradores
-- (R1: acceso 'admin' en 011, verificado por la API en /agentes y /consulta).
-- Hace dos cosas, sin escribir nada en Tools (ADR-A8):
--
--   * Charla de metas: cuando acuerda una con el administrador, la PROPONE con
--     kpi_proponer_meta. Es una tool del motor (agente/metas.py), no del
--     gateway: valida la propuesta y la devuelve como tarjeta. La graba el
--     administrador desde el panel, con su sesion (Objetivos/guardar).
--   * Seguimiento: el trabajo programado agente/coach.py avisa a quien cargo
--     una meta cuando deja de cumplirse.
--
-- kpi_proponer_meta es de clase 'generacion': no lee datos de la empresa ni
-- cambia nada; arma una propuesta. Por eso es reversible y de riesgo bajo.
--
-- 011 ya trae a Kuntur activo y con la tool en su lista; este script repite
-- ese cambio para las bases que tienen 011 aplicado de antes.
-- =============================================================================

\set ON_ERROR_STOP on

INSERT INTO agente.tool (nombre, modulo, clase, riesgo, reversible, descripcion)
VALUES ('kpi_proponer_meta', 'kpi', 'generacion', 'bajo', true,
        'Kuntur propone una meta sobre un indicador. No la graba: la carga el administrador')
ON CONFLICT (nombre) DO UPDATE SET
    modulo      = EXCLUDED.modulo,
    clase       = EXCLUDED.clase,
    riesgo      = EXCLUDED.riesgo,
    reversible  = EXCLUDED.reversible,
    descripcion = EXCLUDED.descripcion,
    fec_mod     = now();

UPDATE agente.agente
   SET activo = true,
       tools_permitidas = CASE WHEN 'kpi_proponer_meta' = ANY (tools_permitidas) THEN tools_permitidas
                               ELSE tools_permitidas || 'kpi_proponer_meta'::text END,
       fec_mod = now()
 WHERE clave = 'kuntur';

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('023-kuntur-metas', 'Kuntur activo: tool kpi_proponer_meta y seguimiento de metas')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();
