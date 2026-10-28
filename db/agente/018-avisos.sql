-- =============================================================================
-- 018 - Avisos proactivos: credenciales de maquina y destinatarios por usuario
-- =============================================================================
-- Idempotente. Rollback: 018-avisos.rollback.sql
--
-- AGENTE-AS-03: Quirqui avisa sin que nadie este conectado (una orden por
-- vencer, un lote vencido, una certificacion que vence). Para eso hacen falta
-- tres cosas que el esquema no tenia:
--
-- 1. Credenciales de maquina por empresa (ADR-A10). El job pide a Dnato un
--    token por client_credentials con el client_id y el secreto de cada
--    empresa. El secreto se guarda CIFRADO con pgcrypto, con una clave que
--    vive en una variable de entorno del orquestador (AGENTE_CLAVE_CREDENCIALES),
--    nunca en la base. Sin la clave, lo que hay en la tabla no sirve.
--    La emision del lado de Dnato espera la aprobacion de
--    doc/agente/analisis-impacto-token-maquina.md.
--
-- 2. Identificar al usuario por su NICK. Las notificaciones, los destinatarios
--    y los dispositivos usaban usr_id (numero), pero el JWT de Dnato no trae
--    ese dato: trae `sub` (el nick). Sin esto, la campanita no podria saber de
--    quien es cada aviso. Se suma la columna `usuario`; usr_id queda para
--    compatibilidad y basta con uno de los dos.
--
-- 3. El tipo de aviso de Panol (certificaciones de herramientas).
-- =============================================================================

\set ON_ERROR_STOP on

-- -----------------------------------------------------------------------------
-- 1. Credenciales de maquina
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agente.credencial_empresa (
    empr_id          integer     PRIMARY KEY,
    client_id        text        NOT NULL,
    secreto_cifrado  bytea       NOT NULL,
    activo           boolean     NOT NULL DEFAULT true,
    fec_alta         timestamptz NOT NULL DEFAULT now(),
    fec_mod          timestamptz NOT NULL DEFAULT now(),
    fec_ultimo_uso   timestamptz,
    CONSTRAINT credencial_client_id_ck CHECK (client_id ~ '^[A-Za-z0-9._:-]{3,120}$')
);

COMMENT ON TABLE  agente.credencial_empresa IS
    'Cliente de maquina de cada empresa en Dnato (ADR-A10). El secreto va cifrado; la clave esta en AGENTE_CLAVE_CREDENCIALES.';
COMMENT ON COLUMN agente.credencial_empresa.secreto_cifrado IS
    'pgp_sym_encrypt(secreto, clave). Se descifra solo en el orquestador, con la clave del entorno.';

ALTER TABLE agente.credencial_empresa ENABLE ROW LEVEL SECURITY;
ALTER TABLE agente.credencial_empresa FORCE  ROW LEVEL SECURITY;
DROP POLICY IF EXISTS credencial_aislamiento_empresa ON agente.credencial_empresa;
CREATE POLICY credencial_aislamiento_empresa ON agente.credencial_empresa
    USING (empr_id = NULLIF(current_setting('agente.empr_id', true), '')::integer)
    WITH CHECK (empr_id = NULLIF(current_setting('agente.empr_id', true), '')::integer);

-- El runtime lee la de una empresa por vez (con su contexto) y registra el
-- ultimo uso. El alta y la baja las hace Trazalog (curador).
REVOKE ALL ON agente.credencial_empresa FROM agente_app;
GRANT SELECT ON agente.credencial_empresa TO agente_app;
GRANT UPDATE (fec_ultimo_uso) ON agente.credencial_empresa TO agente_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON agente.credencial_empresa TO agente_curador;

-- El job necesita saber QUE empresas recorrer sin tener el contexto de
-- ninguna. Esta funcion devuelve solo los ids, nunca un secreto, y corre con
-- los permisos de su duenio para poder ver todas las filas.
CREATE OR REPLACE FUNCTION agente.empresas_con_credencial()
RETURNS SETOF integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = agente, pg_temp
AS $$
    SELECT empr_id FROM agente.credencial_empresa WHERE activo ORDER BY empr_id
$$;
REVOKE ALL ON FUNCTION agente.empresas_con_credencial() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agente.empresas_con_credencial() TO agente_app, agente_curador;

-- -----------------------------------------------------------------------------
-- 2. El usuario por su nick
-- -----------------------------------------------------------------------------
ALTER TABLE agente.destinatario_alerta ADD COLUMN IF NOT EXISTS usuario text;
ALTER TABLE agente.destinatario_alerta ALTER COLUMN usr_id DROP NOT NULL;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'destinatario_quien_ck') THEN
        ALTER TABLE agente.destinatario_alerta ADD CONSTRAINT destinatario_quien_ck
            CHECK (usr_id IS NOT NULL OR usuario IS NOT NULL);
    END IF;
END
$$;

-- La unicidad de 008 es por usr_id; la misma regla por nick.
CREATE UNIQUE INDEX IF NOT EXISTS destinatario_usuario_uk
    ON agente.destinatario_alerta (empr_id, tipo_alerta, usuario) WHERE usuario IS NOT NULL;

ALTER TABLE agente.notificacion ADD COLUMN IF NOT EXISTS usuario text;
ALTER TABLE agente.notificacion DROP CONSTRAINT IF EXISTS notificacion_destinatario_ck;
ALTER TABLE agente.notificacion ADD CONSTRAINT notificacion_destinatario_ck
    CHECK (usr_id IS NOT NULL OR usuario IS NOT NULL OR rol_destino IS NOT NULL);
CREATE INDEX IF NOT EXISTS notificacion_usuario_ix
    ON agente.notificacion (empr_id, usuario, fec_alta DESC);

ALTER TABLE agente.dispositivo ADD COLUMN IF NOT EXISTS usuario text;
ALTER TABLE agente.dispositivo ALTER COLUMN usr_id DROP NOT NULL;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'dispositivo_quien_ck') THEN
        ALTER TABLE agente.dispositivo ADD CONSTRAINT dispositivo_quien_ck
            CHECK (usr_id IS NOT NULL OR usuario IS NOT NULL);
    END IF;
END
$$;

-- Destinatarios de un tipo de aviso, con el nick. La version de 008
-- (destinatarios_de) sigue existiendo para no romper a quien la use.
CREATE OR REPLACE FUNCTION agente.destinatarios(p_empr_id integer, p_tipo_alerta text)
RETURNS TABLE (usr_id integer, usuario text, etiqueta text)
LANGUAGE sql
STABLE
AS $$
    SELECT DISTINCT d.usr_id, d.usuario, d.etiqueta
    FROM agente.destinatario_alerta d
    WHERE d.activo
      AND d.empr_id = p_empr_id
      AND d.tipo_alerta IN (p_tipo_alerta, '*')
    ORDER BY d.usuario, d.usr_id;
$$;
GRANT EXECUTE ON FUNCTION agente.destinatarios(integer, text) TO agente_app, agente_curador;

-- -----------------------------------------------------------------------------
-- 3. Tipo de aviso de Panol
--
-- OJO: 008 y 009 recrean estos CHECK cada vez que se aplican. Aplicando todo
-- en orden (001..018) queda bien, porque 018 es el ultimo. Re-aplicar 008 o
-- 009 sueltos DESPUES de 018 saca 'certificacion_por_vencer': hay que volver
-- a aplicar 018.
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['notificacion', 'destinatario_alerta'] LOOP
        EXECUTE format('ALTER TABLE agente.%I DROP CONSTRAINT IF EXISTS %I', t,
                       CASE t WHEN 'notificacion' THEN 'notificacion_tipo_ck' ELSE 'destinatario_tipo_ck' END);
    END LOOP;
END
$$;
ALTER TABLE agente.notificacion ADD CONSTRAINT notificacion_tipo_ck CHECK (tipo IN (
    'mtbf_deterioro', 'ot_critica_atrasada',
    'stock_critico', 'material_por_vencer', 'pedido_demorado',
    'certificacion_por_vencer',
    'hallazgo', 'sistema'));
ALTER TABLE agente.destinatario_alerta ADD CONSTRAINT destinatario_tipo_ck CHECK (tipo_alerta IN (
    '*',
    'mtbf_deterioro', 'ot_critica_atrasada',
    'stock_critico', 'material_por_vencer', 'pedido_demorado',
    'certificacion_por_vencer',
    'hallazgo', 'sistema'));

-- El disparador 'evento_operativo' y el canal 'scheduler' ya existen (005/013).

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('018-avisos', 'Avisos proactivos: credenciales de maquina, destinatarios por nick, tipo certificacion_por_vencer (AGENTE-AS-03)')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();
