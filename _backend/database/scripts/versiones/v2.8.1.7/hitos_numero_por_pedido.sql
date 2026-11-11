-- v2.8.1.7 — cada pedido de trabajo numera sus hitos 1, 2, 3 (pedido del PM, 2026-11-11).
-- `numero` sigue siendo el código que carga el usuario; `nro` es el número del hito dentro de su
-- pedido. Lo asigna el alta del hito (TARDataService setHito). Los hitos existentes se numeran por
-- orden de alta (hito_id), contando también los eliminados para que el número no se reutilice.
-- Análisis aprobado por el PM el 2026-11-11: doc/analisis/impacto-alta-empresa-pedidos-trabajo.md.
-- Idempotente. Rollback: hitos_numero_por_pedido.rollback.sql.

ALTER TABLE tst.hitos ADD COLUMN IF NOT EXISTS nro integer;

UPDATE tst.hitos h
SET nro = n.nro
FROM (
    SELECT hito_id, row_number() OVER (PARTITION BY petr_id ORDER BY hito_id) AS nro
    FROM tst.hitos
) n
WHERE h.hito_id = n.hito_id
  AND h.nro IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS hitos_petr_nro_un ON tst.hitos (petr_id, nro);
