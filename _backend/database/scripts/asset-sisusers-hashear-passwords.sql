-- ===========================================================================
--  Hashear las contraseñas que quedaron en texto plano en sisusers
-- ===========================================================================
--
--  QUÉ ES
--    Corrección de datos que acompaña al fix de la query `setUserAsset`
--    (issue #489 / hallazgo H-049). Hasta ese fix, el alta de usuario por API
--    guardaba la contraseña SIN hashear en `sisusers.usrPassword`, mientras
--    AssetPlanner la compara contra MD5 — así que esos usuarios nunca pudieron
--    entrar. Este script arregla las filas ya creadas.
--
--  DÓNDE SE EJECUTA
--    Contra la base MariaDB/MySQL de AssetPlanner (`assetv2`), del ambiente que
--    se esté corrigiendo. Por DBeaver conectado a esa base, o por SSH al server
--    y `mysql -u <usuario> -p assetv2`.
--
--  CUÁNDO
--    DESPUÉS de desplegar el CAR con `setUserAsset` corregida. Si se corre
--    antes, los usuarios que se creen entre medio vuelven a quedar en plano.
--
--  ORDEN: ejecutar los pasos 1 y 2 y LEER el resultado antes de correr el 3.
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- PASO 1 · Cuántas filas están afectadas
--   Un MD5 son 32 caracteres hexadecimales. Todo lo que no tenga esa forma
--   está en texto plano.
-- ---------------------------------------------------------------------------
SELECT
    count(*)                                                          AS total_usuarios,
    sum(usrPassword REGEXP '^[0-9a-f]{32}$')                          AS ya_hasheadas,
    sum(NOT (usrPassword REGEXP '^[0-9a-f]{32}$'))                    AS en_texto_plano,
    sum(usrPassword IS NULL OR usrPassword = '')                      AS vacias
FROM sisusers;


-- ---------------------------------------------------------------------------
-- PASO 2 · Cuáles son, para revisarlas antes de tocarlas
--   Mirar esta lista. Si aparece alguna contraseña que NO debería estar en
--   claro (una de un usuario que se creó por otro camino), frenar y revisar.
-- ---------------------------------------------------------------------------
SELECT usrId, usrNick, usrName, usrLastName, usrPassword
FROM sisusers
WHERE NOT (usrPassword REGEXP '^[0-9a-f]{32}$')
  AND usrPassword IS NOT NULL
  AND usrPassword <> ''
ORDER BY usrId;


-- ---------------------------------------------------------------------------
-- PASO 3 · La corrección
--
--   OJO: es irreversible — después de correrlo ya no se puede saber cuál era
--   la contraseña original. Sacar un backup de la tabla primero:
--
--       CREATE TABLE sisusers_bkp_20260826 AS SELECT * FROM sisusers;
--
--   El filtro por REGEXP hace que sea seguro correrlo dos veces: una fila ya
--   hasheada no vuelve a hashearse.
--
--   Las filas con contraseña NULL o vacía quedan afuera a propósito: hashear
--   una cadena vacía daría un MD5 válido y le habilitaría el ingreso a alguien
--   dejando la contraseña en blanco. Esos usuarios necesitan que se les
--   asigne una contraseña, no que se les hashee la que no tienen.
-- ---------------------------------------------------------------------------
UPDATE sisusers
   SET usrPassword = MD5(usrPassword)
 WHERE NOT (usrPassword REGEXP '^[0-9a-f]{32}$')
   AND usrPassword IS NOT NULL
   AND usrPassword <> '';


-- ---------------------------------------------------------------------------
-- PASO 4 · Verificar que quedó bien
--   `en_texto_plano` tiene que dar 0. Si quedaron `vacias`, son las del
--   comentario de arriba: hay que asignarles contraseña a mano.
-- ---------------------------------------------------------------------------
SELECT
    count(*)                                                          AS total_usuarios,
    sum(usrPassword REGEXP '^[0-9a-f]{32}$')                          AS ya_hasheadas,
    sum(NOT (usrPassword REGEXP '^[0-9a-f]{32}$'))                    AS en_texto_plano,
    sum(usrPassword IS NULL OR usrPassword = '')                      AS vacias
FROM sisusers;


-- ---------------------------------------------------------------------------
-- PASO 5 · Probar el ingreso
--   Con un usuario de la lista del paso 2, entrar a AssetPlanner con la
--   contraseña que figuraba ahí en claro. Tiene que dejar entrar.
-- ---------------------------------------------------------------------------
