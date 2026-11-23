-- Rollback de 034. Borra los temas sumados que todavia no tienen nada capturado
-- (los que ya tienen hechos quedan, para no perder conocimiento) y vuelve a
-- 'general' los de mineria.
\set ON_ERROR_STOP on
BEGIN;
DELETE FROM agente.tema t
 WHERE t.vertical IN ('oil_gas', 'electricidad')
   AND t.nombre IN ('Bombeo mecánico y pozos', 'Compresores', 'Separadores, tanques y baterías', 'Integridad de ductos',
                    'Gas sulfhídrico y atmósferas explosivas', 'Transformadores y subestaciones',
                    'Líneas de transmisión y distribución', 'Protecciones y maniobras',
                    'Trabajo con tensión y arco eléctrico', 'Generación: grupos electrógenos y turbinas')
   AND NOT EXISTS (SELECT 1 FROM agente.sesion_entrevista s WHERE s.tema_id = t.tema_id);
DELETE FROM agente.tema t
 WHERE t.nombre IN ('Oil & gas', 'Electricidad')
   AND NOT EXISTS (SELECT 1 FROM agente.tema h WHERE h.tema_padre_id = t.tema_id)
   AND NOT EXISTS (SELECT 1 FROM agente.sesion_entrevista s WHERE s.tema_id = t.tema_id);
UPDATE agente.tema SET vertical = 'general' WHERE nombre IN ('Chancado y molienda', 'Chancadoras', 'Molinos');
DELETE FROM agente.schema_version WHERE script = '034-taxonomia-verticales';
COMMIT;
