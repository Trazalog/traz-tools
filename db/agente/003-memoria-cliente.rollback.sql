-- Rollback de 003-memoria-cliente.sql
-- ATENCION: borra la memoria de TODOS los clientes, con sus particiones.
-- El DROP de la tabla particionada se lleva las particiones por empresa.
\set ON_ERROR_STOP on

DROP FUNCTION IF EXISTS agente.crear_particion_empresa(integer);
DROP TABLE    IF EXISTS agente.memoria;

DELETE FROM agente.schema_version WHERE script = '003-memoria-cliente';
