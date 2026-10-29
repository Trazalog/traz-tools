-- Rollback de 018-avisos.sql
--
-- Borra las credenciales de maquina (los jobs dejan de poder pedir tokens) y
-- las columnas por nick. Los avisos de tipo certificacion_por_vencer se borran
-- antes de restaurar el CHECK de 009, que no los admite.
\set ON_ERROR_STOP on

DROP FUNCTION IF EXISTS agente.empresas_con_credencial();
DROP TABLE IF EXISTS agente.credencial_empresa;
DROP FUNCTION IF EXISTS agente.destinatarios(integer, text);

DELETE FROM agente.notificacion WHERE tipo = 'certificacion_por_vencer' OR (usr_id IS NULL AND rol_destino IS NULL);
DELETE FROM agente.destinatario_alerta WHERE tipo_alerta = 'certificacion_por_vencer' OR usr_id IS NULL;
DELETE FROM agente.dispositivo WHERE usr_id IS NULL;

ALTER TABLE agente.notificacion DROP CONSTRAINT IF EXISTS notificacion_tipo_ck;
ALTER TABLE agente.notificacion ADD CONSTRAINT notificacion_tipo_ck CHECK (tipo IN (
    'mtbf_deterioro', 'ot_critica_atrasada', 'stock_critico', 'material_por_vencer',
    'pedido_demorado', 'hallazgo', 'sistema'));
ALTER TABLE agente.destinatario_alerta DROP CONSTRAINT IF EXISTS destinatario_tipo_ck;
ALTER TABLE agente.destinatario_alerta ADD CONSTRAINT destinatario_tipo_ck CHECK (tipo_alerta IN (
    '*', 'mtbf_deterioro', 'ot_critica_atrasada', 'stock_critico', 'material_por_vencer',
    'pedido_demorado', 'hallazgo', 'sistema'));

ALTER TABLE agente.notificacion DROP CONSTRAINT IF EXISTS notificacion_destinatario_ck;
ALTER TABLE agente.notificacion ADD CONSTRAINT notificacion_destinatario_ck
    CHECK (usr_id IS NOT NULL OR rol_destino IS NOT NULL);
DROP INDEX IF EXISTS agente.notificacion_usuario_ix;
ALTER TABLE agente.notificacion DROP COLUMN IF EXISTS usuario;

DROP INDEX IF EXISTS agente.destinatario_usuario_uk;
ALTER TABLE agente.destinatario_alerta DROP CONSTRAINT IF EXISTS destinatario_quien_ck;
ALTER TABLE agente.destinatario_alerta DROP COLUMN IF EXISTS usuario;
ALTER TABLE agente.destinatario_alerta ALTER COLUMN usr_id SET NOT NULL;

ALTER TABLE agente.dispositivo DROP CONSTRAINT IF EXISTS dispositivo_quien_ck;
ALTER TABLE agente.dispositivo DROP COLUMN IF EXISTS usuario;
ALTER TABLE agente.dispositivo ALTER COLUMN usr_id SET NOT NULL;

DELETE FROM agente.schema_version WHERE script = '018-avisos';
