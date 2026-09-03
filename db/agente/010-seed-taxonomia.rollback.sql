-- Rollback de 010-seed-taxonomia.sql
--
-- Borra los temas del seed. Los que ya tengan sesiones de entrevista asociadas
-- NO se borran: perder la trazabilidad de una entrevista es peor que dejar un
-- tema huerfano. El script avisa cuales quedaron.
\set ON_ERROR_STOP on

\echo '--- temas con entrevistas, que NO se borran ---'
SELECT t.nombre, count(s.sesion_id) AS sesiones
FROM agente.tema t JOIN agente.sesion_entrevista s ON s.tema_id = t.tema_id
GROUP BY t.nombre ORDER BY 2 DESC;

DELETE FROM agente.tema t
WHERE NOT EXISTS (SELECT 1 FROM agente.sesion_entrevista s WHERE s.tema_id = t.tema_id);

DROP FUNCTION IF EXISTS agente.upsert_tema(text, text, text, text, text, text, numeric);

DELETE FROM agente.schema_version WHERE script = '010-seed-taxonomia';
