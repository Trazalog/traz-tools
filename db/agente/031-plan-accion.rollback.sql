-- Rollback de 031-plan-accion.sql
\set ON_ERROR_STOP on

UPDATE agente.agente
   SET tools_permitidas = array_remove(tools_permitidas, 'kuntur_proponer_plan'),
       fec_mod = now()
 WHERE clave = 'kuntur';

DELETE FROM agente.tool WHERE nombre IN ('kuntur_proponer_plan', 'tar_alta_pedido', 'tar_alta_hito',
                                         'tar_alta_tarea', 'tar_baja_pedido', 'tar_baja_tarea');

DROP TABLE IF EXISTS agente.plan_propuesta;

DELETE FROM agente.schema_version WHERE script = '031-plan-accion';
