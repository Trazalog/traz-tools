-- =============================================================================
-- 028 - Planillas del cliente y carga masiva por Kuntur (ADR-A12, lote 2)
-- =============================================================================
-- Idempotente. Rollback: 028-planillas-carga-masiva.rollback.sql
--
-- El administrador sube su planilla como la tiene (CSV o Excel .xlsx). Se guarda
-- aca, por empresa, para que Kuntur la mire (encabezados y unas 20 filas, P-8) y
-- proponga como pasarla a la plantilla de la Carga Masiva. La transformacion de
-- TODAS las filas la hace el codigo (agente/planillas.py), no el modelo.
--
-- kuntur_carga_masiva es una tool del MOTOR, no del gateway: al confirmar,
-- manda el CSV a la Carga Masiva de Dnato (POST /bulkload_api/cargar,
-- traz-comp-dnato#50) con el token del administrador. Es la misma carga que la
-- pantalla: mismos motores, mismas validaciones, todo o nada.
-- Aprobado por el PM el 2026-11-11 (doc/agente/analisis-impacto-kuntur-configuracion.md, A-2).
-- =============================================================================

\set ON_ERROR_STOP on

CREATE TABLE IF NOT EXISTS agente.planilla (
    planilla_id  uuid        PRIMARY KEY,
    empr_id      integer     NOT NULL,
    usuario      text        NOT NULL,
    nombre       text        NOT NULL,   -- nombre del archivo, para mostrar
    encabezados  jsonb       NOT NULL,   -- ["Código", "Detalle", ...]
    filas        jsonb       NOT NULL,   -- [["A1", "Guante"], ...] tal como vienen
    total_filas  integer     NOT NULL CHECK (total_filas BETWEEN 1 AND 5000),
    fec_alta     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS planilla_empresa_ix ON agente.planilla (empr_id, fec_alta DESC);

COMMENT ON TABLE agente.planilla IS
    'Planilla que subio un administrador para que Kuntur la pase a la Carga Masiva (ADR-A12). '
    'Al modelo solo le llegan los encabezados y unas 20 filas.';

ALTER TABLE agente.planilla ENABLE ROW LEVEL SECURITY;
ALTER TABLE agente.planilla FORCE  ROW LEVEL SECURITY;
DROP POLICY IF EXISTS planilla_aislamiento ON agente.planilla;
CREATE POLICY planilla_aislamiento ON agente.planilla
    USING (empr_id = NULLIF(current_setting('agente.empr_id', true), '')::integer)
    WITH CHECK (empr_id = NULLIF(current_setting('agente.empr_id', true), '')::integer);
GRANT SELECT, INSERT, DELETE ON agente.planilla TO agente_app;
GRANT SELECT ON agente.planilla TO agente_curador;

INSERT INTO agente.tool (nombre, modulo, clase, riesgo, reversible, descripcion)
VALUES ('kuntur_carga_masiva', 'dnato', 'configuracion', 'alto', false,
        'Carga masiva de una planilla (artículos, herramientas o equipos)')
ON CONFLICT (nombre) DO UPDATE SET
    modulo      = EXCLUDED.modulo,
    clase       = EXCLUDED.clase,
    riesgo      = EXCLUDED.riesgo,
    reversible  = EXCLUDED.reversible,
    descripcion = EXCLUDED.descripcion,
    fec_mod     = now();

UPDATE agente.agente
   SET tools_configuracion = ARRAY(SELECT DISTINCT unnest(tools_configuracion || ARRAY['kuntur_carga_masiva']) ORDER BY 1),
       fec_mod = now()
 WHERE clave = 'kuntur';

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('028-planillas-carga-masiva', 'Planillas del cliente y carga masiva por Kuntur (ADR-A12, lote 2)')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();
