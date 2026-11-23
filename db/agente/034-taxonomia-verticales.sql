-- =============================================================================
-- 034 - Temas de Faustino por industria (ADR-A11, gate de textos AGENTE-M-07)
-- =============================================================================
-- Idempotente. Rollback: 034-taxonomia-verticales.rollback.sql
--
-- La taxonomia inicial (010) se armo solo para mineria y quedo toda marcada
-- 'general'. Este script:
--   * marca como 'mineria' lo que es propio de la mineria (chancado y molienda);
--   * suma temas de oil & gas y de electricidad, para que Faustino tambien
--     entreviste a expertos de esas industrias.
--
-- DECIDIDO POR CLAUDE CODE EL 2026-11-22, por pedido del PM ("si tenes que tomar
-- decisiones hacelo y documenta"). Pendiente de revision del PM:
-- doc/agente/decisiones-2026-11-24.md, decision 23. Corregir es editar este
-- archivo y volver a aplicarlo: actualiza por nombre y no toca el estado de un
-- tema ya cubierto (agente.upsert_tema, de 010).
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- Lo propio de la mineria
UPDATE agente.tema SET vertical = 'mineria', fec_mod = now()
 WHERE nombre IN ('Chancado y molienda', 'Chancadoras', 'Molinos') AND vertical <> 'mineria';

-- Oil & gas
SELECT agente.upsert_tema('Oil & gas', 'Mantenimiento',
    'Equipos e instalaciones de producción de petróleo y gas.', 'man', NULL, NULL, 0);
SELECT agente.upsert_tema('Bombeo mecánico y pozos', 'Oil & gas',
    'Aparatos individuales de bombeo, varillas, bombas de fondo y mantenimiento de pozos.', 'man', 'aib', 'mantenimiento', 85);
SELECT agente.upsert_tema('Compresores', 'Oil & gas',
    'Compresores alternativos y centrífugos de gas: fallas típicas, lubricación y paradas.', 'man', 'compresor', 'mantenimiento', 80);
SELECT agente.upsert_tema('Separadores, tanques y baterías', 'Oil & gas',
    'Separadores, tanques de almacenaje y baterías: inspección, corrosión y limpieza.', 'man', 'separador', 'mantenimiento', 70);
SELECT agente.upsert_tema('Integridad de ductos', 'Oil & gas',
    'Corrosión, protección catódica, inspección y reparación de ductos y líneas de conducción.', 'man', 'ducto', 'mantenimiento', 80);
SELECT agente.upsert_tema('Gas sulfhídrico y atmósferas explosivas', 'Oil & gas',
    'Detección de gas sulfhídrico, clasificación de áreas y trabajo seguro en atmósferas explosivas.', 'general', NULL, NULL, 95);

-- Electricidad
SELECT agente.upsert_tema('Electricidad', 'Mantenimiento',
    'Equipos e instalaciones de generación, transmisión y distribución eléctrica.', 'man', NULL, NULL, 0);
SELECT agente.upsert_tema('Transformadores y subestaciones', 'Electricidad',
    'Ensayos de aceite, termografía, mantenimiento de interruptores y celdas.', 'man', 'transformador', 'mantenimiento', 85);
SELECT agente.upsert_tema('Líneas de transmisión y distribución', 'Electricidad',
    'Inspección de líneas, aisladores, puesta a tierra y poda de servidumbre.', 'man', 'linea', 'mantenimiento', 75);
SELECT agente.upsert_tema('Protecciones y maniobras', 'Electricidad',
    'Relés de protección, coordinación y maniobras seguras.', 'man', NULL, NULL, 75);
SELECT agente.upsert_tema('Trabajo con tensión y arco eléctrico', 'Electricidad',
    'Distancias de seguridad, consignación, ropa ignífuga y riesgo de arco eléctrico.', 'general', NULL, NULL, 95);
SELECT agente.upsert_tema('Generación: grupos electrógenos y turbinas', 'Electricidad',
    'Grupos electrógenos, turbinas y sus servicios auxiliares.', 'man', 'generador', 'mantenimiento', 70);

UPDATE agente.tema SET vertical = 'oil_gas', fec_mod = now()
 WHERE nombre IN ('Oil & gas', 'Bombeo mecánico y pozos', 'Compresores', 'Separadores, tanques y baterías',
                  'Integridad de ductos', 'Gas sulfhídrico y atmósferas explosivas');
UPDATE agente.tema SET vertical = 'electricidad', fec_mod = now()
 WHERE nombre IN ('Electricidad', 'Transformadores y subestaciones', 'Líneas de transmisión y distribución',
                  'Protecciones y maniobras', 'Trabajo con tensión y arco eléctrico',
                  'Generación: grupos electrógenos y turbinas');

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('034-taxonomia-verticales', 'Temas de Faustino por industria: mineria marcada, oil & gas y electricidad sumados')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();

COMMIT;
