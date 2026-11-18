-- v2.8.1.7 — un pedido de trabajo se puede crear sin formulario (H-110).
-- El formulario es opcional: si la empresa quiere uno, lo asocia por Lista de Valores. La pantalla
-- ya contempla pedidos sin formulario ("Aún no se completó formulario asociado").
-- Análisis aprobado por el PM el 2026-11-11: doc/analisis/impacto-alta-empresa-pedidos-trabajo.md.
-- Idempotente. Rollback: pedidos_sin_formulario.rollback.sql.

ALTER TABLE pro.pedidos_trabajo ALTER COLUMN info_id DROP NOT NULL;
