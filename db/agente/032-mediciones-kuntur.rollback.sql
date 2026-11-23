-- Rollback de 032-mediciones-kuntur.sql: Kuntur deja de poder pedir mediciones.
-- Las mediciones ya pedidas quedan en agente.medicion_pedida (son de 019).
\set ON_ERROR_STOP on
UPDATE agente.agente
   SET tools_permitidas = array_remove(tools_permitidas, 'kuntur_pedir_medicion'),
       fec_mod = now()
 WHERE clave = 'kuntur';
DELETE FROM agente.tool WHERE nombre = 'kuntur_pedir_medicion';
DROP INDEX IF EXISTS agente.avance_plan_tarea_uk;
DELETE FROM agente.schema_version WHERE script = '032-mediciones-kuntur';
