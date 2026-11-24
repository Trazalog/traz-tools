-- Vuelta atrás de REQ-004-base-y-atributos.sql
-- Borra SOLO lo que agregó el script. Correr en la misma copia, en orden inverso.
--
-- Antes de correr: reemplazar <CORREO_TOOLS_ADMIN> por el mismo correo usado en M-6.
-- OJO: seg.auditoria no admite UPDATE ni DELETE (el disparador lo impide); sus filas
--       se van con el DROP TABLE de más abajo, no con un DELETE.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Datos cargados
-- ---------------------------------------------------------------------------
DELETE FROM seg.menues WHERE modulo = 'MCP';

DELETE FROM seg.membresias_estado;

UPDATE seg.users SET superusuario = false
 WHERE lower(email) = lower('<CORREO_TOOLS_ADMIN>');

DELETE FROM core.tablas
 WHERE empr_id IS NULL
   AND tabla IN ('texto_suspension_empresa','texto_suspension_miembro','contacto_soporte',
                 'validez_invitacion_dias','validez_recuperacion_horas','aviso_cuota_porcentaje',
                 'zona_horaria_cuotas','remitente_correo','monedas_permitidas');

-- ---------------------------------------------------------------------------
-- 2) Disparador y función de auditoría
-- ---------------------------------------------------------------------------
DROP TRIGGER IF EXISTS auditoria_solo_insercion ON seg.auditoria;
DROP FUNCTION IF EXISTS seg.auditoria_solo_insercion();

-- ---------------------------------------------------------------------------
-- 3) Función de variables
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS seg.cambiar_variable(varchar, text, varchar);

-- ---------------------------------------------------------------------------
-- 4) Tablas nuevas (orden inverso a las dependencias)
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS seg.variables_historial;
DROP TABLE IF EXISTS seg.auditoria;
DROP TABLE IF EXISTS seg.cargas_resultados;
DROP TABLE IF EXISTS seg.eventos_registro;
DROP TABLE IF EXISTS seg.intereses;
DROP TABLE IF EXISTS seg.pedidos_plan;
DROP TABLE IF EXISTS seg.consumos_mcp;
DROP TABLE IF EXISTS seg.cuota_periodos;
DROP TABLE IF EXISTS seg.menus_asignaciones;
DROP TABLE IF EXISTS seg.menus_custom_items;
DROP TABLE IF EXISTS seg.menus_custom;
DROP TABLE IF EXISTS seg.empresas_funcionalidades;
DROP TABLE IF EXISTS seg.planes_funcionalidades;
DROP TABLE IF EXISTS seg.planes;
DROP TABLE IF EXISTS seg.membresias_estado;

-- ---------------------------------------------------------------------------
-- 5) CHECK de seg.menues de vuelta a la lista original (sin MCP)
-- ---------------------------------------------------------------------------
ALTER TABLE seg.menues DROP CONSTRAINT IF EXISTS menues_check;
ALTER TABLE seg.menues ADD CONSTRAINT menues_check
    CHECK (modulo::text IN ('PRD','CORE','ALM','MAN','TAR','PAN','LOG','SEG','TRZ','PRO','FIS','BPM','RESI'));

-- ---------------------------------------------------------------------------
-- 6) Columnas nuevas
-- ---------------------------------------------------------------------------
ALTER TABLE seg.menues
    DROP COLUMN IF EXISTS tipo,
    DROP COLUMN IF EXISTS texto_presentacion,
    DROP COLUMN IF EXISTS ayuda,
    DROP COLUMN IF EXISTS publicacion;

ALTER TABLE seg.users
    DROP COLUMN IF EXISTS superusuario,
    DROP COLUMN IF EXISTS cambiar_password;

ALTER TABLE core.empresas
    DROP COLUMN IF EXISTS plan_id,
    DROP COLUMN IF EXISTS estado,
    DROP COLUMN IF EXISTS estado_motivo,
    DROP COLUMN IF EXISTS estado_plan,
    DROP COLUMN IF EXISTS plan_pedido_id,
    DROP COLUMN IF EXISTS plan_vence,
    DROP COLUMN IF EXISTS uso_plan_gratuito,
    DROP COLUMN IF EXISTS contacto_admin;

COMMIT;
