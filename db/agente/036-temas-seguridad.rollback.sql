-- Rollback de 036: los dos temas vuelven a quedar 'descartado' si siguen pendientes
-- (no se borran: lo capturado se conserva).
\set ON_ERROR_STOP on
BEGIN;
UPDATE agente.tema SET estado = 'descartado', fec_mod = now()
 WHERE nombre IN ('Gas sulfhídrico y atmósferas explosivas', 'Trabajo con tensión y arco eléctrico')
   AND estado = 'pendiente';
DELETE FROM agente.schema_version WHERE script = '036-temas-seguridad';
COMMIT;
