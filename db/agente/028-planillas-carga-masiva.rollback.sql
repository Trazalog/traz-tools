-- Rollback de 028-planillas-carga-masiva.sql
\set ON_ERROR_STOP on

UPDATE agente.agente
   SET tools_configuracion = array_remove(tools_configuracion, 'kuntur_carga_masiva'),
       fec_mod = now()
 WHERE clave = 'kuntur';

UPDATE agente.carga_propuesta SET estado = 'vencida', fec_respuesta = now()
 WHERE estado = 'propuesta' AND tool = 'kuntur_carga_masiva';

DELETE FROM agente.tool WHERE nombre = 'kuntur_carga_masiva';
DROP TABLE IF EXISTS agente.planilla;

DELETE FROM agente.schema_version WHERE script = '028-planillas-carga-masiva';
