-- Migración: formalizar core.empresas.empr_id_mysql (vínculo Postgres ↔ assetv2/MySQL)
--
-- Contexto: la columna se asume existente en toda la cadena de identidad (ADR-009,
-- COREDataService.getEmpresaById / updateEmpresaAssetId / getEmpresaByMysqlId) pero
-- nunca tuvo migración formal — faltó en TEST y hubo que agregarla a mano
-- (doc/v3/deployment-gcp.md §7.0-quinquies, bloqueo en doc/v3/STATE.md).
--
-- Dónde se ejecuta: manualmente, con psql, contra la base PostgreSQL de cada
-- ambiente (DEV 10.142.0.13:5432 / TEST-GCP 10.142.0.11:5434 / futuro PROD),
-- en la base que contenga el esquema `core` de ese ambiente:
--   psql -h <host> -p <puerto> -U postgres -d <base> -f 2026-08-core-empresas-empr-id-mysql.sql
--
-- Idempotente: se puede correr más de una vez sin efecto adicional.
-- Verificado en DEV el 2026-08-12: columna ya existente (integer), 0 duplicados
-- entre los valores no nulos, por lo que el índice único parcial es seguro.

-- 1) La columna (no-op donde ya existe)
ALTER TABLE core.empresas
    ADD COLUMN IF NOT EXISTS empr_id_mysql integer;

COMMENT ON COLUMN core.empresas.empr_id_mysql IS
    'Id de la misma empresa en la base assetv2 (MySQL/MariaDB de AssetPlanner). '
    'Lo escribe la registración freemium (updateEmpresaAssetId). NULL = empresa sin '
    'contraparte en asset. Lookup inverso: COREDataService.getEmpresaByMysqlId.';

-- 2) Unicidad parcial: un id de asset no puede apuntar a dos empresas de tools.
--    Parcial para permitir múltiples NULL (empresas sin vínculo).
CREATE UNIQUE INDEX IF NOT EXISTS empresas_empr_id_mysql_uk
    ON core.empresas (empr_id_mysql)
    WHERE empr_id_mysql IS NOT NULL;

-- 3) Verificación post-aplicación (debe devolver 0 filas):
-- SELECT empr_id_mysql, count(*) FROM core.empresas
--   WHERE empr_id_mysql IS NOT NULL GROUP BY 1 HAVING count(*) > 1;
