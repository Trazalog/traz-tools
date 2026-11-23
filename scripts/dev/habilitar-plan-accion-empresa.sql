-- =============================================================================
-- Habilita el plan de acción de Kuntur en UNA empresa existente (ESCRIBE).
--
-- Por qué: las empresas creadas antes de v2.8.1.7 no tienen el Proceso Estándar
-- ni el tipo de pedido "General", y sin eso Kuntur no puede crear el pedido del
-- plan (lo dice y no crea nada). Verificado en DEV el 2026-11-22: solo 2 empresas
-- de prueba los tienen; Yudica, DDPE y el resto, no.
--
-- Es lo MISMO que hace el alta de empresa desde v2.8.1.7
-- (_backend/database/scripts/versiones/v2.8.1.7/configuracion_inicial_empresa_trg_func.sql),
-- aplicado a mano a una empresa. Idempotente: si ya lo tiene, no duplica.
--
-- ⚠️ NÚCLEO (pro.procesos, core.tablas): se corre solo con aprobación del PM y
-- empresa por empresa (las que activen Kuntur). Efecto visible: en la pantalla
-- de alta de pedido aparece la opción "Proceso Estándar" y el tipo "General".
-- No toca los procesos propios de la empresa (por ejemplo, el de Yudica).
--
-- Dónde se corre: terminal local, con la VPN, reemplazando 191 por la empresa:
--   psql -h 10.142.0.13 -U postgres -d tools_prod_t -v empr_id=191 -f scripts/dev/habilitar-plan-accion-empresa.sql
-- =============================================================================
\set ON_ERROR_STOP on
BEGIN;

INSERT INTO pro.procesos (proc_id, nombre, descripcion, lanzar_bpm, planificar_tareas, nombre_bpm,
                          esin_id, empr_id, form_id, usuario_app)
SELECT 'PROCESO-STANDAR', 'Proceso Estándar', 'Pedido de trabajo con planificación de tareas',
       false, true, null, 'estados_procesosPROC_EN_CURSO', :empr_id, null, 'core'
 WHERE NOT EXISTS (SELECT 1 FROM pro.procesos p
                    WHERE p.proc_id = 'PROCESO-STANDAR' AND p.empr_id = :empr_id AND NOT p.eliminado);

INSERT INTO core.tablas (tabla, valor, descripcion, empr_id)
SELECT 'tipos_pedidos_trabajo', 'General', 'General', :empr_id
 WHERE NOT EXISTS (SELECT 1 FROM core.tablas t
                    WHERE t.empr_id = :empr_id AND t.tabla ILIKE '%tipos_pedidos_trabajo%' AND t.valor = 'General');

\echo 'Clientes activos de la empresa (el plan usa el primero; si no hay, cargá uno desde Tools):'
SELECT clie_id, nombre FROM core.clientes WHERE empr_id = :empr_id AND estado = 'ACTIVO' ORDER BY clie_id LIMIT 5;

COMMIT;
