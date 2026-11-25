-- =============================================================================
-- 036 - Vuelven los dos temas de seguridad por industria (AGENTE-M-07)
-- =============================================================================
-- Idempotente. Rollback: 036-temas-seguridad.rollback.sql
--
-- 035 cargo la tabla del PM, que no traia estos dos temas (los habia sumado
-- Claude Code en 034), y quedaron 'descartado'. El PM pidio volver a ponerlos
-- el 2026-11-25 (decision 44 de doc/agente/decisiones-2026-11-24.md). Van como
-- temas raiz de su industria, con la misma prioridad que la seguridad general.
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

SELECT agente.upsert_tema('Gas sulfhídrico y atmósferas explosivas', NULL,
    'Detección de gas sulfhídrico, clasificación de áreas y trabajo seguro en atmósferas explosivas', 'general', NULL, NULL, 95);
SELECT agente.upsert_tema('Trabajo con tensión y arco eléctrico', NULL,
    'Distancias de seguridad, consignación, ropa ignífuga y riesgo de arco eléctrico', 'general', NULL, NULL, 95);

UPDATE agente.tema SET vertical = 'oil_gas', fec_mod = now()
 WHERE nombre = 'Gas sulfhídrico y atmósferas explosivas';
UPDATE agente.tema SET vertical = 'electricidad', fec_mod = now()
 WHERE nombre = 'Trabajo con tensión y arco eléctrico';

-- Reabre los que 035 habia descartado y recalcula la prioridad como en 035.
UPDATE agente.tema
   SET estado = CASE WHEN estado = 'descartado' THEN 'pendiente' ELSE estado END,
       prioridad = round((origen_prioridad->>'seed')::numeric
                         + COALESCE((origen_prioridad->>'ots')::numeric, 0)
                         + COALESCE((origen_prioridad->>'huecos')::numeric, 0), 2),
       fec_mod = now()
 WHERE nombre IN ('Gas sulfhídrico y atmósferas explosivas', 'Trabajo con tensión y arco eléctrico');

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('036-temas-seguridad', 'Vuelven los temas de gas sulfhídrico y de trabajo con tensión (pedido del PM)')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();

COMMIT;
