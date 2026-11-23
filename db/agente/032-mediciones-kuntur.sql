-- =============================================================================
-- 032 - Kuntur pide mediciones a Quirqui (AGENTE-CO-06, AGENTE-AS-04)
-- =============================================================================
-- Idempotente. Rollback: 032-mediciones-kuntur.rollback.sql
--
-- La tool kuntur_pedir_medicion es del motor (agente/mediciones.py), no del
-- gateway: deja una fila activa en agente.medicion_pedida (019). No escribe
-- nada en Tools; el administrador la ve y la cancela en /kuntur/mediciones
-- (R11). Clase 'generacion', como kpi_proponer_meta: no lee datos de la
-- empresa ni cambia nada fuera de la base del agente.
--
-- Un indice para que el trabajo programado refresque el avance de una tarea
-- de plan sin duplicarla (agente.avance_plan no tenia clave natural).
-- =============================================================================

\set ON_ERROR_STOP on

INSERT INTO agente.tool (nombre, modulo, clase, riesgo, reversible, descripcion)
VALUES ('kuntur_pedir_medicion', 'kpi', 'generacion', 'bajo', true,
        'Kuntur le pide a Quirqui que mida un indicador cada cierto tiempo (contrato R3)')
ON CONFLICT (nombre) DO UPDATE SET
    modulo      = EXCLUDED.modulo,
    clase       = EXCLUDED.clase,
    riesgo      = EXCLUDED.riesgo,
    reversible  = EXCLUDED.reversible,
    descripcion = EXCLUDED.descripcion,
    fec_mod     = now();

UPDATE agente.agente
   SET tools_permitidas = CASE WHEN 'kuntur_pedir_medicion' = ANY (tools_permitidas) THEN tools_permitidas
                               ELSE tools_permitidas || 'kuntur_pedir_medicion'::text END,
       fec_mod = now()
 WHERE clave = 'kuntur';

CREATE UNIQUE INDEX IF NOT EXISTS avance_plan_tarea_uk
    ON agente.avance_plan (empr_id, petr_id, tarea_id);

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('032-mediciones-kuntur', 'Kuntur pide mediciones a Quirqui: tool kuntur_pedir_medicion')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();
