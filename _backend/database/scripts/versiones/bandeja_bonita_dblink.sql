-- =============================================================================
-- Bandeja de entrada con paginado real: acceso de solo lectura a la BD de Bonita
-- =============================================================================
-- Qué hace: registra en la base de Tools un servidor dblink ("bonita_bpm") que
-- apunta a la base del engine de Bonita. Lo usa BandejaDataService
-- (query getBandejaTareas) para resolver en UNA query las tareas pendientes del
-- usuario + el filtro por empresa (core.case_empresa) + paginado y total.
--
-- Dónde se ejecuta: en la base de Tools de CADA ambiente (la misma a la que
-- apunta ToolsDataSource), con un usuario superuser (postgres). Ejemplo en
-- TEST: psql -h 10.142.0.13 -U postgres -d tools_prod_t -f bandeja_bonita_dblink.sql
--
-- Antes de ejecutar: ajustar host/port/dbname/user al ambiente. Están en el
-- servidor de Bonita, archivo
--   <tomcat>/conf/Catalina/localhost/bonita.xml  (url="jdbc:postgresql://HOST:PORT/DB")
-- En TEST (10.142.0.13) la base de Bonita es un PostgreSQL 9.4 en la misma VM:
-- localhost:6432/bonita, usuario bonita (auth trust desde localhost).
--
-- Es aditivo e idempotente: no toca ningún objeto existente. Para revertir:
--   DROP USER MAPPING IF EXISTS FOR postgres SERVER bonita_bpm;
--   DROP SERVER IF EXISTS bonita_bpm;
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS dblink;

CREATE SERVER IF NOT EXISTS bonita_bpm
  FOREIGN DATA WRAPPER dblink_fdw
  OPTIONS (host '127.0.0.1', port '6432', dbname 'bonita');

-- El usuario de la izquierda es el de ToolsDataSource (el que ejecuta la query).
-- Si la base de Bonita pide password, agregar: , password '<pass>'
CREATE USER MAPPING IF NOT EXISTS FOR postgres
  SERVER bonita_bpm
  OPTIONS (user 'bonita');

-- Verificación (debe devolver la versión del PostgreSQL de Bonita):
-- SELECT * FROM dblink('bonita_bpm', 'select version()') AS t(v text);
