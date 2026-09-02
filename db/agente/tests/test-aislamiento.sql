-- =============================================================================
-- Test de aislamiento multi-tenant — el que no puede fallar nunca
-- =============================================================================
-- Verifica que una empresa NO puede leer ni escribir la memoria ni las
-- notificaciones de otra, ni siquiera con un SELECT sin WHERE.
--
--   psql -h <host> -U <usuario> -d <base> -v ON_ERROR_STOP=1 -f tests/test-aislamiento.sql
--
-- El test crea dos empresas de prueba (900001 y 900002), les mete datos, hace
-- las comprobaciones y BORRA TODO al final, incluidas las particiones. Es
-- seguro correrlo contra cualquier ambiente: los ids de prueba son altos a
-- proposito para no colisionar con empresas reales.
--
-- Si algo falla, sale con excepcion (codigo distinto de cero) y hace rollback.
--
-- IMPORTANTE -- por que el test hace SET ROLE agente_app:
--
--   Un SUPERUSUARIO SE SALTEA ROW LEVEL SECURITY SIEMPRE, incluso con FORCE ROW
--   LEVEL SECURITY activo (FORCE solo alcanza al propietario de la tabla, no a
--   los superusuarios ni a los roles con BYPASSRLS). Si este test corriera como
--   postgres, todos los controles darian falso verde: se verian las filas de
--   todas las empresas y el test lo reportaria como que el aislamiento anda.
--
--   Por eso los controles se hacen con SET ROLE agente_app, que es el rol con
--   el que se conecta el orquestador. La consecuencia operativa es directa:
--   EL ORQUESTADOR NUNCA DEBE CONECTARSE COMO postgres NI COMO EL PROPIETARIO
--   DEL ESQUEMA. Si lo hace, el aislamiento multi-tenant es decorativo.
-- =============================================================================

\set ON_ERROR_STOP on
\pset pager off

\set EMPRESA_A 900001
\set EMPRESA_B 900002

BEGIN;

-- ---------------------------------------------------------------------------
-- El test corre como un rol con los mismos permisos que el orquestador. El
-- propietario del esquema se saltea RLS salvo que la tabla tenga FORCE, que es
-- por lo que 003 y 007 lo activan. Igual se verifica explicitamente.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'agente' AND c.relname = 'memoria' AND c.relforcerowsecurity
    ) THEN
        RAISE EXCEPTION 'agente.memoria no tiene FORCE ROW LEVEL SECURITY: el propietario se saltearia el aislamiento.';
    END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- Preparacion: dos empresas con su particion y una fila cada una
-- ---------------------------------------------------------------------------
SELECT agente.crear_particion_empresa(:EMPRESA_A);
SELECT agente.crear_particion_empresa(:EMPRESA_B);

SET LOCAL agente.empr_id = :'EMPRESA_A';
INSERT INTO agente.memoria (empr_id, contenido, origen)
VALUES (:EMPRESA_A, 'SECRETO DE LA EMPRESA A: la chancadora 7 falla los martes', 'consulta');

INSERT INTO agente.notificacion (empr_id, usr_id, tipo, titulo, cuerpo)
VALUES (:EMPRESA_A, 1, 'hallazgo', 'Alerta privada de A', 'cuerpo A');

INSERT INTO agente.destinatario_alerta (empr_id, tipo_alerta, usr_id, etiqueta)
VALUES (:EMPRESA_A, 'mtbf_deterioro', 11, 'Jefe de mantenimiento de A');

SET LOCAL agente.empr_id = :'EMPRESA_B';
INSERT INTO agente.memoria (empr_id, contenido, origen)
VALUES (:EMPRESA_B, 'SECRETO DE LA EMPRESA B: el molino 3 consume de mas', 'consulta');

INSERT INTO agente.notificacion (empr_id, usr_id, tipo, titulo, cuerpo)
VALUES (:EMPRESA_B, 1, 'hallazgo', 'Alerta privada de B', 'cuerpo B');

INSERT INTO agente.destinatario_alerta (empr_id, tipo_alerta, usr_id, etiqueta)
VALUES (:EMPRESA_B, 'mtbf_deterioro', 22, 'Jefe de mantenimiento de B');

CREATE TEMP TABLE _resultado (control text, ok boolean, detalle text) ON COMMIT DROP;
GRANT ALL ON _resultado TO agente_app;

-- ---------------------------------------------------------------------------
-- A partir de aca los controles corren como agente_app, el rol del
-- orquestador. Sin esto el test daria falso verde (ver encabezado).
-- ---------------------------------------------------------------------------
SET LOCAL ROLE agente_app;

INSERT INTO _resultado
SELECT 'el rol de los controles NO es superusuario',
       NOT coalesce((SELECT rolsuper FROM pg_roles WHERE rolname = current_user), true),
       'un superusuario se saltea RLS y daria falso verde';

-- ---------------------------------------------------------------------------
-- CONTROL 1 — Con el contexto de A, un SELECT SIN WHERE solo devuelve filas de A
--
-- Este es el control central: simula el olvido del filtro en el codigo de la
-- aplicacion, que es de donde salen las fugas entre clientes en la practica.
-- ---------------------------------------------------------------------------
SET LOCAL agente.empr_id = :'EMPRESA_A';

INSERT INTO _resultado
SELECT 'memoria: con contexto A, SELECT sin WHERE no trae filas de B',
       NOT EXISTS (SELECT 1 FROM agente.memoria WHERE empr_id = :EMPRESA_B),
       'RLS';

INSERT INTO _resultado
SELECT 'memoria: con contexto A, SELECT sin WHERE trae la fila de A',
       EXISTS (SELECT 1 FROM agente.memoria WHERE contenido LIKE 'SECRETO DE LA EMPRESA A%'),
       'RLS';

INSERT INTO _resultado
SELECT 'memoria: con contexto A, el contenido de B es invisible',
       NOT EXISTS (SELECT 1 FROM agente.memoria WHERE contenido LIKE '%EMPRESA B%'),
       'fuga de datos entre clientes';

INSERT INTO _resultado
SELECT 'notificacion: con contexto A, las de B son invisibles',
       NOT EXISTS (SELECT 1 FROM agente.notificacion WHERE titulo LIKE '%de B'),
       'RLS';

INSERT INTO _resultado
SELECT 'destinatario_alerta: con contexto A, los de B son invisibles',
       NOT EXISTS (SELECT 1 FROM agente.destinatario_alerta WHERE usr_id = 22),
       'configuracion de alertas de otra empresa';

-- La resolucion de destinatarios tampoco puede cruzar empresas: preguntar por
-- la empresa B desde el contexto de A no debe devolver a su jefe de
-- mantenimiento.
INSERT INTO _resultado
SELECT 'destinatarios_de(): con contexto A, preguntar por B no devuelve nada',
       NOT EXISTS (SELECT 1 FROM agente.destinatarios_de(900002, 'mtbf_deterioro')),
       'resolucion de destinatarios aislada';

INSERT INTO _resultado
SELECT 'destinatarios_de(): con contexto A, devuelve al destinatario de A',
       EXISTS (SELECT 1 FROM agente.destinatarios_de(900001, 'mtbf_deterioro') WHERE usr_id = 11),
       'la funcion sigue sirviendo dentro de la empresa';

-- ---------------------------------------------------------------------------
-- CONTROL 2 — Simetrico: con el contexto de B, A es invisible
-- ---------------------------------------------------------------------------
SET LOCAL agente.empr_id = :'EMPRESA_B';

INSERT INTO _resultado
SELECT 'memoria: con contexto B, el contenido de A es invisible',
       NOT EXISTS (SELECT 1 FROM agente.memoria WHERE contenido LIKE '%EMPRESA A%'),
       'fuga de datos entre clientes';

INSERT INTO _resultado
SELECT 'memoria: con contexto B, se ve la fila de B',
       EXISTS (SELECT 1 FROM agente.memoria WHERE contenido LIKE 'SECRETO DE LA EMPRESA B%'),
       'RLS';

-- ---------------------------------------------------------------------------
-- CONTROL 3 — Sin contexto seteado, no se ve NADA (falla cerrado)
--
-- Es la diferencia entre un bug que expone datos y uno que rompe visiblemente.
-- ---------------------------------------------------------------------------
SET LOCAL agente.empr_id = '';

INSERT INTO _resultado
SELECT 'memoria: sin contexto de empresa no se ve ninguna fila (falla cerrado)',
       NOT EXISTS (SELECT 1 FROM agente.memoria),
       'no debe devolver todo';

INSERT INTO _resultado
SELECT 'notificacion: sin contexto de empresa no se ve ninguna fila (falla cerrado)',
       NOT EXISTS (SELECT 1 FROM agente.notificacion),
       'no debe devolver todo';

INSERT INTO _resultado
SELECT 'destinatario_alerta: sin contexto de empresa no se ve ninguna fila (falla cerrado)',
       NOT EXISTS (SELECT 1 FROM agente.destinatario_alerta),
       'no debe devolver todo';

-- ---------------------------------------------------------------------------
-- CONTROL 4 — Con el contexto de A no se puede ESCRIBIR como B
-- ---------------------------------------------------------------------------
SET LOCAL agente.empr_id = :'EMPRESA_A';

DO $$
DECLARE
    v_rechazado boolean := false;
BEGIN
    BEGIN
        INSERT INTO agente.memoria (empr_id, contenido, origen)
        VALUES (900002, 'INTENTO DE ESCRITURA CRUZADA', 'consulta');
    EXCEPTION WHEN insufficient_privilege THEN
        v_rechazado := true;
    END;

    INSERT INTO _resultado
    VALUES ('memoria: con contexto A no se puede insertar como B', v_rechazado, 'WITH CHECK de la policy');
END
$$;

-- ---------------------------------------------------------------------------
-- CONTROL 5 — Una empresa sin particion no puede recibir filas
-- ---------------------------------------------------------------------------
SET LOCAL agente.empr_id = '900999';

DO $$
DECLARE
    v_rechazado boolean := false;
BEGIN
    BEGIN
        INSERT INTO agente.memoria (empr_id, contenido, origen)
        VALUES (900999, 'EMPRESA SIN PARTICION', 'consulta');
    EXCEPTION WHEN OTHERS THEN
        v_rechazado := true;
    END;

    INSERT INTO _resultado
    VALUES ('memoria: una empresa sin particion creada no puede insertar', v_rechazado, 'particionado por LIST');
END
$$;

-- ---------------------------------------------------------------------------
-- CONTROL 6 — El conocimiento compartido SI es visible para todas (ADR-A4)
--
-- El aislamiento es de la memoria del cliente, no del conocimiento comun.
-- ---------------------------------------------------------------------------
SET LOCAL agente.empr_id = :'EMPRESA_A';

INSERT INTO _resultado
SELECT 'chunk: el conocimiento compartido no tiene RLS (es comun a todos)',
       NOT coalesce((
           SELECT c.relrowsecurity FROM pg_class c
           JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname = 'agente' AND c.relname = 'chunk'
       ), false),
       'ADR-A4: compartido, de solo lectura';

-- ---------------------------------------------------------------------------
-- Resultado
-- ---------------------------------------------------------------------------
RESET ROLE;

\echo ''
\echo '=== TEST DE AISLAMIENTO MULTI-TENANT — Agente Minero ==='
SELECT CASE WHEN ok THEN 'OK    ' ELSE 'FALLA ' END || control
       || CASE WHEN detalle <> '' THEN '  [' || detalle || ']' ELSE '' END AS resultado
FROM _resultado
ORDER BY ok, control;

\echo ''
SELECT count(*) FILTER (WHERE ok)     AS pasaron,
       count(*) FILTER (WHERE NOT ok) AS fallaron,
       count(*)                       AS total
FROM _resultado;

DO $$
DECLARE
    v_fallas int;
BEGIN
    SELECT count(*) INTO v_fallas FROM _resultado WHERE NOT ok;
    IF v_fallas > 0 THEN
        RAISE EXCEPTION 'AISLAMIENTO MULTI-TENANT ROTO: % control(es) fallaron. NO exponer el agente a ningun cliente hasta resolverlo.', v_fallas;
    END IF;
    RAISE NOTICE 'AISLAMIENTO MULTI-TENANT: todo en verde.';
END
$$;

-- ---------------------------------------------------------------------------
-- Limpieza: se hace rollback de todo, asi no queda nada de la prueba. Las
-- particiones creadas por crear_particion_empresa() tambien desaparecen,
-- porque el CREATE TABLE es transaccional en PostgreSQL.
-- ---------------------------------------------------------------------------
ROLLBACK;

\echo 'Datos de prueba revertidos (ROLLBACK): la base quedo como estaba.'
