-- ============================================================================
-- AssetPlanner (MariaDB) — El número de serie del equipo pasa a ser texto (H53, MIG-EI65).
--
-- Objetivo: que se pueda guardar un número de serie con letras ("SN-123", "AB45-X"). Hoy
-- `equipos.numero_serie` es DOUBLE:
--   · asset escribe directo en la base y, sin modo estricto, MariaDB guarda 0 y solo avisa: el dato se pierde;
--   · Mantenimiento en tools escribe por MANDataService (conector JDBC de MySQL), que convierte ese aviso en
--     error, y el alta del equipo falla ("Data truncation: Incorrect double value").
-- La pantalla de asset ya lo trata como texto (input de texto, se muestra tal cual) y `ficha_equipo.numero_serie`
-- ya es VARCHAR. Excepción al congelamiento del esquema de assetv2, aprobada por el PM el 2026-11-18.
--
-- DÓNDE SE EJECUTA: conectado a la base de AssetPlanner (MariaDB) de cada instalación, con un cliente de MySQL.
--   DEMO: base asp2sim. Producción: la base de asset de producción. Desarrollo: assetv2.
-- Es idempotente: si la columna ya es texto, el ALTER no cambia nada.
--
-- CÓMO SE DESHACE: ALTER TABLE equipos MODIFY numero_serie DOUBLE NULL DEFAULT NULL;
--   ⚠️ los números de serie con letras quedan en 0 (se pierden).
-- ============================================================================

-- 1) Antes: cómo está la columna y qué valores tienen decimales o son muy grandes. Al pasar a texto se escriben
--    como los muestra MariaDB (por ejemplo 1.5e15): revisarlos a mano si aparece alguno.
SELECT COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT
  FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'equipos' AND COLUMN_NAME = 'numero_serie';

SELECT id_equipo, id_empresa, codigo, numero_serie
  FROM equipos
 WHERE numero_serie IS NOT NULL
   AND (numero_serie <> FLOOR(numero_serie) OR ABS(numero_serie) >= 1e15);

-- 2) El cambio
ALTER TABLE equipos MODIFY numero_serie VARCHAR(255) NULL DEFAULT NULL;

-- 3) Después: tiene que decir varchar(255)
SELECT COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT
  FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'equipos' AND COLUMN_NAME = 'numero_serie';
