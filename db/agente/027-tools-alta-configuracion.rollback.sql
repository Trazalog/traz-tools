-- Rollback de 027-tools-alta-configuracion.sql
\set ON_ERROR_STOP on

UPDATE agente.agente
   SET tools_configuracion = ARRAY(SELECT t FROM unnest(tools_configuracion) t
                                   WHERE t NOT IN ('core_alta_establecimiento', 'alm_alta_deposito', 'core_alta_valor')),
       fec_mod = now()
 WHERE clave = 'kuntur';

UPDATE agente.carga_propuesta SET estado = 'vencida', fec_respuesta = now()
 WHERE estado = 'propuesta' AND tool IN ('core_alta_establecimiento', 'alm_alta_deposito', 'core_alta_valor');

DELETE FROM agente.tool WHERE nombre IN ('core_alta_establecimiento', 'alm_alta_deposito', 'core_alta_valor');

DELETE FROM agente.schema_version WHERE script = '027-tools-alta-configuracion';
