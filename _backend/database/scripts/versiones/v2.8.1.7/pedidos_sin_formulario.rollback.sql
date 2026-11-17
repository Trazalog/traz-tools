-- Rollback de v2.8.1.7/pedidos_sin_formulario.sql.
-- ATENCIÓN: falla si ya hay pedidos sin formulario. Para verlos:
--   select petr_id, cod_proyecto, empr_id from pro.pedidos_trabajo where info_id is null;

ALTER TABLE pro.pedidos_trabajo ALTER COLUMN info_id SET NOT NULL;
