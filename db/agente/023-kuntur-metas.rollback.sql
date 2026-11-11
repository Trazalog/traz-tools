-- Rollback de 023-kuntur-metas.sql: Kuntur vuelve a quedar inactivo y sin la tool de proponer metas.
-- Ojo: si despues se vuelve a aplicar 011 tal como esta en el repo, Kuntur queda activo de nuevo.
\set ON_ERROR_STOP on
UPDATE agente.agente
   SET activo = false,
       tools_permitidas = array_remove(tools_permitidas, 'kpi_proponer_meta'),
       fec_mod = now()
 WHERE clave = 'kuntur';
DELETE FROM agente.tool WHERE nombre = 'kpi_proponer_meta';
DELETE FROM agente.schema_version WHERE script = '023-kuntur-metas';
