# Despliegue del Tablero del Administrador (v2.5) — DEMO y PROD

## Objetivo

Qué es: el runbook para **pasar el Tablero del Administrador a un ambiente** (primero DEMO, después
PROD). Lista, en orden, cada componente y **dónde se ejecuta cada paso** (server web, server WSO2,
BD Postgres por SSH, BD AssetPlanner). Para quién: quien haga el despliegue (PM). Cuándo leerlo:
antes de cada pasaje. Qué NO cubre: el diseño/arquitectura (eso está en
`doc/analisis/dashboard-administrador-landing.md`).

## Componentes del feature (qué se despliega)

| # | Componente | Dónde vive | Cómo se despliega |
|---|---|---|---|
| 1 | Código PHP (controllers/Dash, models/Dashs, config/dashboard.php, config/constants.php, views/dashboard/, lib/props/dashboard_kpis.js, helpers/sesion_helper) | repo, rama `feat/admin-dashboard-landing` | git pull en el htdocs |
| 2 | `ToolsKPIDataService.dbs` (nuevo) + `COREDataService.dbs` (query `getEsAdminXEmailEmpresa` nueva) | `_backend/api/ToolsAPIProject/.../data-services/` | rebuild `.car` + deploy a WSO2 |
| 3 | Motor de caché KPI en Postgres (schema `kpi.*`) + definiciones de los 3 KPIs de ALM/HER | `_backend/database/scripts/versiones/v2.8.1.4/` | `psql -f` en la BD Postgres |
| 4 | Scheduler de la caché Postgres (cron del SO que corre `kpi.correr()`) | server de Postgres | crontab (ver §5) |
| 5 | KPI de MAN "Disponibilidad" en AssetPlanner (registro + event) | `_backend/database/scripts/assetplanner/kpi-disponibilidad.sql` | `mysql <` en la BD AssetPlanner |

> **Nada de esto rompe v2**: el código PHP solo agrega el aterrizaje del admin (degrada a la vista
> actual si el endpoint no está); los `.dbs` son aditivos; los objetos de BD son nuevos.

---

## Orden de despliegue (mismo para DEMO y PROD)

### Paso 1 — Código PHP  *(en el server web, en el htdocs)*
```
cd <htdocs>          # p.ej. /var/www/html
sh traz-tools/scripts/deploy/deploytools.sh <rama-o-tag> traz-tools
```
Ese script actualiza el código y **también** despliega los DataServices y artefactos Synapse (paso 2).
Si preferís hacerlo por separado, hacé `git pull` del código y seguí con el paso 2 a mano.

### Paso 2 — WSO2 DataServices  *(en el server WSO2)*
Rebuild del proyecto y despliegue del `.car` (incluye `ToolsKPIDataService` y `COREDataService`):
```
cd _backend/api/ToolsAPIProject/ToolsAPIProject
./mvnw clean install
```
El `.car` queda en `target/`. Desplegarlo (lo hace `deploytools.sh`, o a mano copiando los `.dbs` a
`repository/deployment/server/dataservices/` del WSO2). **Verificar** que respondan (con `Accept: application/json`):
```
curl -s -H "Accept: application/json" "<HOST>/services/COREDataService/usuario/esadmin/porEmail/<un-admin>/empresa/<empr_id>"
curl -s -H "Accept: application/json" "<HOST>/services/ToolsKPIDataService/kpis/emprid/<empr_id>"
```

### Paso 3 — Postgres Tools  *(por SSH al server de Postgres, con psql)*
```
psql -h <host> -U <user> -d <base> -v ON_ERROR_STOP=1 -f _backend/database/scripts/versiones/v2.8.1.4/kpi_cache_engine.sql
psql -h <host> -U <user> -d <base> -v ON_ERROR_STOP=1 -f _backend/database/scripts/versiones/v2.8.1.4/kpi_definiciones.sql
```
Primera carga inmediata de la caché (si no, espera al cron del paso 4):
```
psql -h <host> -U <user> -d <base> -c "select kpi.correr();"
```

### Paso 4 — Scheduler de la caché Postgres  *(por SSH al server de Postgres)*
`pg_cron` NO está disponible, así que va por **cron del SO**. Procedimiento completo (rol `kpi_cron`,
`~/.pgpass`, línea de crontab) en `doc/analisis/dashboard-administrador-landing.md` §6-bis. Resumen:
```
*/5 * * * * psql -h 127.0.0.1 -U kpi_cron -d <base> -c "select kpi.correr();"
```

### Paso 5 — AssetPlanner (KPI Disponibilidad)  *(conectado a la BD de AssetPlanner, MariaDB)*
Registra el KPI en el mecanismo de eventos de AssetPlanner y asegura el event:
```
mysql -h <host> -u <user> -p <base_assetplanner> < _backend/database/scripts/assetplanner/kpi-disponibilidad.sql
```
Primera carga inmediata (si no, espera al event cada 10 min):
```
mysql -h <host> -u <user> -p -e "CALL <base_assetplanner>.kpi_calcular_queries_cacheados();"
```
Requisitos: `event_scheduler = ON` (verificar con `SHOW VARIABLES LIKE 'event_scheduler';`). El
procedure escribe **directo a `kpi_cache`** (una sola fase). El `ToolsKPIDataService` lee de ahí via
`AssetPlannerDataSource`, mapeando el `empr_id` de Tools a `core.empresas.empr_id_mysql`.

### Paso 6 — Verificación funcional
Entrar como **Administrador** de una empresa → debe aterrizar en el tablero, con el sector Suscripción
y las 4 cajas KPI (ALM reorder, ALM movimientos, HER en tránsito, MAN disponibilidad).

---

## Particularidades por ambiente

### DEMO (hecho)
- Se sembraron datos de prueba en la empresa **191** (ALM/PAN, marcados `(demo)`) y se la **mapeó a
  AssetPlanner id_empresa 8** (`core.empresas.empr_id_mysql = 8`) para que la disponibilidad muestre
  números reales con el usuario de prueba `agenteminero`.
- En AssetPlanner (dev) los events se dejaron **DISABLED** para no cargar la BD compartida; la caché
  se pobló con una corrida manual del procedure. En PROD los events van **ENABLED**.

### PROD
- **No** sembrar datos demo ni tocar `empr_id_mysql`: las empresas reales ya tienen su vínculo y sus
  datos en ALM/PAN/AssetPlanner.
- Dejar el event `kpi_correr_cache` **ENABLED** (ya existe en prod) y el cron de Postgres activo.
- Correr los `.sql` una sola vez; son idempotentes (CREATE OR REPLACE / ON CONFLICT / ON DUPLICATE KEY).

## Rollback
- Código PHP: revertir el merge/rama.
- `.dbs`: son aditivos (queries/servicios nuevos); no hace falta revertir, pero se puede redeployar la versión anterior.
- Postgres: `DROP SCHEMA kpi CASCADE;` + quitar la línea del crontab.
- AssetPlanner: `UPDATE kpi_queries_a_cachear SET habilitado=0 WHERE nombre='getDisponibilidad';` (o DELETE).
