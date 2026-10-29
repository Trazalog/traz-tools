-- Rollback de 021-drop-avisos-agente.sql: vuelve a crear la cola de avisos del
-- agente, VACIA (los datos borrados no vuelven), re-aplicando los scripts que
-- la crearon. Correr desde db/agente/ o con psql -f (\ir resuelve la ruta
-- relativa a este archivo).
\set ON_ERROR_STOP on
\ir 007-notificaciones.sql
\ir 008-destinatarios-alerta.sql
\ir 009-alcance-almacenes.sql
\ir 018-avisos.sql
\ir 020-cola-envio.sql
DELETE FROM agente.schema_version WHERE script = '021-drop-avisos-agente';
