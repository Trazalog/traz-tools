-- ─────────────────────────────────────────────────────────────────────────────
-- Seed manual de DocTest TAR: proceso de negocio PROCESO-STANDAR para las empresas de test.
--
-- Por qué existe: el alta de Pedido de Trabajo lee pro.procesos de la empresa (estado inicial,
-- formulario, si lanza el caso de Bonita y si permite planificar tareas). Una empresa creada por
-- la registración no tiene ninguna fila, y el alta falla sin decir por qué (ver TAR-CP-002-01).
-- No hay pantalla para cargarlo: por eso es SQL, manual y revisado (README de seeds, regla 4).
--
-- Qué hace: copia la fila PROCESO-STANDAR de una empresa "modelo" que ya la use, cambiando la
-- empresa, sin formulario (el de la modelo es de otra empresa) y con BPM y planificación activos.
-- Copia todas las columnas tal cual (el DDL vigente no está en el repo, hallazgo B-09 del spec).
-- Es idempotente: si la empresa ya tiene PROCESO-STANDAR, no hace nada.
--
-- Dónde se ejecuta: PC con VPN, contra la base de Tools del DEMO (nunca producción).
--   psql -h <host base DEMO> -U postgres -d <base Tools DEMO> -v ON_ERROR_STOP=1 \
--     -v modelo=<empr_id de la empresa modelo> -v empresa=27 \
--     -f doctest/tests/e2e/seeds/tar/pro-procesos-empresas-test.sql
-- y lo mismo con -v empresa=28.
-- ─────────────────────────────────────────────────────────────────────────────

BEGIN;

CREATE TEMP TABLE tmp_proceso_tar ON COMMIT DROP AS
SELECT *
FROM pro.procesos
WHERE proc_id = 'PROCESO-STANDAR'
  AND empr_id = :modelo
  AND NOT eliminado;

DO $$
BEGIN
  IF (SELECT count(*) FROM tmp_proceso_tar) <> 1 THEN
    RAISE EXCEPTION 'La empresa modelo no tiene exactamente una fila PROCESO-STANDAR activa';
  END IF;
END $$;

UPDATE tmp_proceso_tar
SET empr_id = :empresa,
    form_id = NULL,
    lanzar_bpm = 'true',
    planificar_tareas = 'true';

INSERT INTO pro.procesos
SELECT t.*
FROM tmp_proceso_tar t
WHERE NOT EXISTS (
  SELECT 1 FROM pro.procesos p
  WHERE p.proc_id = 'PROCESO-STANDAR' AND p.empr_id = :empresa AND NOT p.eliminado
);

SELECT proc_id, empr_id, nombre_bpm, lanzar_bpm, planificar_tareas, esin_id, form_id
FROM pro.procesos
WHERE proc_id = 'PROCESO-STANDAR' AND empr_id = :empresa AND NOT eliminado;

COMMIT;
