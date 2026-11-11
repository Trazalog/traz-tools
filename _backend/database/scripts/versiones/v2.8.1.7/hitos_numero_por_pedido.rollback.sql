-- Rollback de v2.8.1.7/hitos_numero_por_pedido.sql. Se pierde el número de cada hito en su pedido.
-- Antes de aplicarlo, volver a desplegar el TARDataService sin la columna nro.

DROP INDEX IF EXISTS tst.hitos_petr_nro_un;
ALTER TABLE tst.hitos DROP COLUMN IF EXISTS nro;
