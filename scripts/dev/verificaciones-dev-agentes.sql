-- =============================================================================
-- Verificaciones en la base de DESARROLLO antes de desplegar los agentes
-- (anexo A de doc/historial/agente/analisis-impacto-plan-accion-kuntur.md, decisiones 15,
-- 21 y 26 de doc/agente/decisiones-2026-11-24.md).
--
-- SOLO LEE: corre dentro de una transaccion de solo lectura. No cambia nada.
--
-- Donde se corre: terminal local, con la conexion segura (VPN) a desarrollo:
--   psql -h 10.142.0.13 -U postgres -d tools_prod_t -f scripts/dev/verificaciones-dev-agentes.sql
--
-- Que mirar en cada resultado esta escrito arriba de cada consulta.
-- =============================================================================
BEGIN TRANSACTION READ ONLY;

\echo '1. Proceso Estandar: ninguna empresa deberia tenerlo con lanzar_bpm = true (esperado: 0 filas)'
SELECT empr_id, lanzar_bpm, planificar_tareas
  FROM pro.procesos
 WHERE proc_id = 'PROCESO-STANDAR' AND NOT coalesce(eliminado, false) AND lanzar_bpm::text = 'true';

\echo '2. Empresas SIN Proceso Estandar (Kuntur no podria crear el pedido: lo dice y no crea nada)'
SELECT e.empr_id, e.descripcion
  FROM core.empresas e
 WHERE NOT EXISTS (SELECT 1 FROM pro.procesos p
                    WHERE p.empr_id = e.empr_id AND p.proc_id = 'PROCESO-STANDAR'
                      AND NOT coalesce(p.eliminado, false))
 ORDER BY e.empr_id;

\echo '3a. Unidades de tiempo que usan hoy los pedidos (la lista real; tiene que haber una de Semanas)'
SELECT DISTINCT t.tabla, t.valor, t.descripcion
  FROM pro.pedidos_trabajo p JOIN core.tablas t ON t.tabl_id = p.umti_id
 ORDER BY 1, 2;

\echo '3b. Valores de Semanas en cualquier lista de unidades de tiempo (decision 15 / anexo A)'
SELECT tabl_id, tabla, valor, descripcion, empr_id
  FROM core.tablas
 WHERE tabla ILIKE '%tiempo%' AND (valor ILIKE '%semana%' OR descripcion ILIKE '%semana%');

\echo '4. Empresas sin cliente activo (el pedido del plan usa el primer cliente activo; sin cliente no se crea)'
SELECT e.empr_id, e.descripcion
  FROM core.empresas e
 WHERE NOT EXISTS (SELECT 1 FROM core.clientes c
                    WHERE c.empr_id = e.empr_id AND c.estado = 'ACTIVO')
 ORDER BY e.empr_id;

\echo '5. Empresas sin el tipo de pedido General (lo crea el alta desde v2.8.1.7)'
SELECT e.empr_id, e.descripcion
  FROM core.empresas e
 WHERE NOT EXISTS (SELECT 1 FROM core.tablas t
                    WHERE t.empr_id = e.empr_id AND t.tabla ILIKE '%tipos_pedidos_trabajo%' AND t.valor ILIKE 'General')
 ORDER BY e.empr_id;

\echo '6. Pedidos sin empresa (con los arreglos de aislamiento de Tareas sus hitos dejan de verse; esperado: 0)'
SELECT count(*) FILTER (WHERE empr_id IS NULL) AS sin_empresa, count(*) AS total
  FROM pro.pedidos_trabajo WHERE NOT coalesce(eliminado, false);

\echo '7. Quien recibe hoy el aviso de fin de plan (decision 21; si sale vacio, no le llega a nadie)'
SELECT empr_id, usuario, activo FROM ntf.suscripcion
 WHERE tipo IN ('plan_accion_resultado', '*') ORDER BY empr_id, usuario;

ROLLBACK;

-- -----------------------------------------------------------------------------
-- (Opcional, ESTE SI ESCRIBE) Suscribir a un administrador al aviso de fin de plan.
-- Reemplazar <EMPR_ID> y <USUARIO> (el mismo usuario con el que entra a Tools)
-- y correrlo aparte, una vez por administrador:
--
--   INSERT INTO ntf.suscripcion (empr_id, tipo, usuario)
--   VALUES (<EMPR_ID>, 'plan_accion_resultado', '<USUARIO>')
--   ON CONFLICT (empr_id, tipo, usuario) DO UPDATE SET activo = true;
-- -----------------------------------------------------------------------------
