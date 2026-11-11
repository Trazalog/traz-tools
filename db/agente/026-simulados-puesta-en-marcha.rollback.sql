-- Rollback de 026-simulados-puesta-en-marcha.sql
-- OJO: borra lo que se "cargo" en las simulaciones.
\set ON_ERROR_STOP on

UPDATE agente.agente
   SET tools_permitidas = array_remove(tools_permitidas, 'dnato_get_*'),
       tools_configuracion = ARRAY(SELECT t FROM unnest(tools_configuracion) t
                                   WHERE t NOT LIKE 'man\_alta\_%' AND t NOT LIKE 'dnato\_%'),
       fec_mod = now()
 WHERE clave = 'kuntur';

UPDATE agente.carga_propuesta SET estado = 'vencida', fec_respuesta = now()
 WHERE estado = 'propuesta' AND (tool LIKE 'man\_alta\_%' OR tool LIKE 'dnato\_%');

DELETE FROM agente.tool WHERE nombre IN (
    'man_alta_sector', 'man_alta_area', 'man_alta_proceso', 'man_alta_criticidad', 'man_alta_grupo',
    'man_alta_marca', 'man_alta_equipo', 'man_get_configuracion', 'dnato_get_funcionalidades',
    'dnato_get_administradores', 'dnato_activar_funcionalidad', 'dnato_asignar_menu_rol',
    'dnato_asignar_rol_usuario');

DROP TABLE IF EXISTS agente.simulacion;

DELETE FROM agente.schema_version WHERE script = '026-simulados-puesta-en-marcha';
