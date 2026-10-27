# Refresco de caché de KPIs (Tablero del Administrador) — cron del SO

## Objetivo

Qué es: la documentación **técnica y operativa** de cómo se refresca la caché de KPIs del Tablero del
Administrador en los servidores (un cron del SO que ejecuta la función PostgreSQL `kpi.correr()`), y la
referencia para cualquier **trabajo de infraestructura** sobre ese mecanismo. Para quién: quien opere o
toque la infra de PostgreSQL de tools (prod/demo). Cuándo leerlo: antes de tocar el cron, la base
`trazalog_tools` o las instancias PostgreSQL de esos hosts. Qué NO cubre: el diseño del motor KPI
(ver [`doc/analisis/dashboard-administrador-landing.md`](../analisis/dashboard-administrador-landing.md)),
ni el KPI de **Mantenimiento (Disponibilidad)**, que se refresca por el evento propio de AssetPlanner.

---

Estado: **en producción y en demo** desde 2026-10-24 (misma configuración en ambos).
Alcance: KPIs de **Almacenes / Herramientas** (`kpi.definiciones`). El KPI de Mantenimiento
(Disponibilidad) **no** se refresca por este mecanismo: va por el evento propio de AssetPlanner.

## Resumen

La función PostgreSQL `kpi.correr()` recalcula los KPIs habilitados y los escribe en `kpi.cache`.
Como `pg_cron` no está disponible, se ejecuta desde el cron del sistema operativo cada 5 minutos.

| Ítem | Valor |
|---|---|
| Hosts | Producción tools — 10.142.0.2 (`vm-production-assetplanner-inst1`)<br>Demo tools — 10.142.0.11 (`vm-demo-trazalog`)<br>Ambos CentOS 7.9 |
| Instancia PostgreSQL | **11.7**, puerto **5434** (`/var/lib/pgsql/11/data`) |
| Base | **`trazalog_tools`** |
| Cliente psql | `/usr/pgsql-11/bin/psql` |
| Usuario del SO | `postgres` (home `/var/lib/pgsql`) |
| Frecuencia | cada 5 minutos |
| Log | `/var/lib/pgsql/kpi_cron.log` |

### Línea de crontab (`crontab -l -u postgres`)

```cron
*/5 * * * * /usr/pgsql-11/bin/psql -p 5434 -d trazalog_tools -c "select kpi.correr();" >> /var/lib/pgsql/kpi_cron.log 2>&1
```

Es la única línea del crontab de `postgres`, idéntica en ambos servidores.

## Particularidades de los servidores (leer antes de tocar)

En **producción** corren **tres instancias de PostgreSQL**:

| Puerto | Versión | Binarios | Data dir |
|---|---|---|---|
| 5432 | 9.2.24 | `/usr/bin` | `/var/lib/pgsql/data` |
| **5434** | **11.7** | `/usr/pgsql-11/bin` | `/var/lib/pgsql/11/data` |
| 6432 | 9.4.26 | `/usr/pgsql-9.4/bin` | `/var/lib/pgsql/9.4/data` |

- `psql` en el PATH es `/usr/bin/psql` (cliente **9.2**) y por defecto conecta al puerto **5432 (9.2)**.
  Un `sudo -u postgres psql -d trazalog_tools` sin `-p 5434` **no** llega a la base correcta.
  Usar siempre `/usr/pgsql-11/bin/psql -p 5434`.
- El motor `kpi.*` vive en `trazalog_tools`. En la misma instancia existe `tools_prod_t`, que **no**
  tiene el esquema `kpi`.
- Las marcas de tiempo de la base están en **UTC**; el SO está en **America/Argentina (-03)**.

En **demo** hay dos instancias: **11.7 en 5434** (con `trazalog_tools` y el mismo motor `kpi.*`) y
9.4.26 en 6432. No hay instancia en 5432, así que un `psql` sin `-p 5434` falla directamente.

## Objetos del motor KPI (`trazalog_tools`, esquema `kpi`)

- Funciones: `kpi.correr()`, `kpi.publicar()`, `kpi.recalcular(p_nombre varchar DEFAULT NULL)`
- Tablas: `kpi.cache`, `kpi.cache_tmp`, `kpi.definiciones`, `kpi.event_log`
- Definiciones habilitadas al momento del alta:

| nombre | refresh_seg |
|---|---|
| `alm_reorder` | 300 |
| `alm_mov_sin_entregar` | 300 |
| `her_transito` | 600 |

### Cómo decide qué recalcular (importante para leer la frescura)

`kpi.correr()` = `kpi.recalcular()` + `kpi.publicar()`. `recalcular()` recorre cada definición
habilitada × cada empresa de `core.empresas` (salvo la 9000, plantilla) y **saltea** la fila si
`kpi.cache.vence_en > now()`, con `vence_en = calculado_en + refresh_seg`.

Como `refresh_seg` (300) es igual al período del cron (5 min), la comparación depende de milisegundos:
si un ciclo arranca un poco antes, dentro del segundo, que el anterior, la fila todavía no venció y
**se saltea hasta el ciclo siguiente**. En la práctica:

- KPIs de 300 s: se refrescan cada 5 min, y ocasionalmente cada 10.
- KPIs de 600 s: cada 10 min, y ocasionalmente cada 15.

Se observó el 2026-10-24 en demo: cálculo a las 18:20:02.04 y cron a las 18:25:01, así que no recalculó nada.

**Mejora sugerida (no aplicada):** dar un margen en la comparación de frescura, por ejemplo
`c.vence_en > now() + interval '30 seconds'`, o bajar `refresh_seg` por debajo del período del cron
(por ejemplo 270 / 570).

## Decisiones de diseño

**Se ejecuta como `postgres`, sin rol dedicado `kpi_cron`.** El plan original proponía un rol de bajo
privilegio con solo `EXECUTE` sobre `kpi.correr()`. Se descartó porque `kpi.correr()` **no es
`SECURITY DEFINER`** (owner `postgres`, `prosecdef = false`): corre con los permisos de quien la invoca,
así que un rol con solo `EXECUTE` fallaría con *permission denied* al escribir `kpi.cache` y al leer
las tablas de origen. Darle esos permisos (o convertir la función a `SECURITY DEFINER`) implicaba más
cambios en la base sin una ganancia real de seguridad con la configuración actual de autenticación local.
Conexión: socket Unix local, sin contraseña ni `.pgpass`.

Si a futuro se quiere un rol dedicado, la vía recomendada es:

```sql
ALTER FUNCTION kpi.correr() SECURITY DEFINER;
ALTER FUNCTION kpi.correr() SET search_path = kpi, public, pg_temp;
CREATE ROLE kpi_cron LOGIN PASSWORD '...';
GRANT USAGE ON SCHEMA kpi TO kpi_cron;
REVOKE EXECUTE ON FUNCTION kpi.correr() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION kpi.correr() TO kpi_cron;
```

## Operación

Ejecución manual:

```bash
sudo -u postgres /usr/pgsql-11/bin/psql -p 5434 -d trazalog_tools -c "SELECT kpi.correr();"
```

Verificación:

```bash
# últimas corridas del cron
sudo tail -n 20 /var/lib/pgsql/kpi_cron.log
sudo grep '(postgres) CMD' /var/log/cron | tail

# frescura de la caché (calculado_en en UTC)
sudo -u postgres /usr/pgsql-11/bin/psql -p 5434 -d trazalog_tools \
  -c "SELECT nombre, count(*), max(calculado_en) FROM kpi.cache GROUP BY nombre;"

# errores
sudo -u postgres /usr/pgsql-11/bin/psql -p 5434 -d trazalog_tools \
  -c "SELECT * FROM kpi.event_log WHERE estado='ERROR' ORDER BY fecha DESC LIMIT 20;"
```

`crond` está activo y habilitado en el arranque (`systemctl is-enabled crond` → `enabled`).

**Log:** cada corrida exitosa agrega 29 bytes (~8 KB/día, ~3 MB/año) y el archivo no tiene rotación
configurada. Pendiente: agregar una regla en `/etc/logrotate.d/`.

## ⚠️ Nota de seguridad de infraestructura (hallazgo, fuera del alcance de esta tarea)

Al dar de alta el cron se detectó, en la instancia PostgreSQL 11 (`pg_hba.conf`) e **igual en
producción y en demo**:

- Las conexiones locales y por `127.0.0.1` / `::1` usan **`trust`**: cualquier usuario del sistema
  puede entrar como cualquier rol, incluido `postgres`, **sin contraseña**. (Es, de hecho, lo que
  permite que este cron corra como `postgres` sin `.pgpass`.)
- La instancia escucha en todas las interfaces (`listen_addresses = '*'`) y acepta conexiones con
  contraseña (`md5`) **desde cualquier IP** (`0.0.0.0/0`).

Esto **no** se modificó en esta tarea. Recomendación: abrir una tarea de endurecimiento
(pasar a `md5`/`scram`, restringir orígenes en `pg_hba.conf`, revisar las reglas de firewall de GCP),
coordinada con las aplicaciones que hoy se conectan sin contraseña. Es un cambio de seguridad sobre
producción → clase 🔴, requiere workshop previo antes de tocarlo.

## Rollback

```bash
sudo crontab -r -u postgres            # el crontab de postgres solo contiene esta línea
sudo rm -f /var/lib/pgsql/kpi_cron.log
```

No se crearon roles, usuarios ni objetos de base de datos para este cambio.

En demo, la configuración anterior (ver registro) se puede restaurar como usuario `ruiz_rodolfo` con
`crontab -e`, si se revierte el cambio.

## Registro del alta en producción (2026-10-24)

1. Prueba manual de `SELECT kpi.correr();`: OK en 0,27 s; 75 filas de `kpi.cache` actualizadas;
   `kpi.event_log` sin errores. (La caché estaba sin refrescar desde 2026-10-06.)
2. Alta del crontab de `postgres` (18:17 -03).
3. Verificación del primer ciclo automático: ver sección siguiente.

### Verificación del primer ciclo

- `/var/log/cron`: `Oct 24 18:20:01 ... CROND[5219]: (postgres) CMD (/usr/pgsql-11/bin/psql -p 5434 -d trazalog_tools -c "select kpi.correr();" ...)`
- `/var/lib/pgsql/kpi_cron.log`: salida normal de psql (`correr` / `(1 row)`), sin errores de conexión.
- `kpi.cache` por KPI tras el ciclo (UTC):

| nombre | filas | calculado_en |
|---|---|---|
| `alm_mov_sin_entregar` | 25 | 2026-10-24 21:20:01 |
| `alm_reorder` | 25 | 2026-10-24 21:20:01 |
| `her_transito` | 25 | 2026-10-24 21:14:50 |

  `her_transito` no se recalculó en ese ciclo porque su `refresh_seg` es 600: `kpi.correr()` respeta
  el intervalo de cada definición, así que ese KPI se actualiza cada 10 minutos aunque el cron corra cada 5.
- `kpi.event_log`: 0 errores.

## Registro del alta en demo (2026-10-24)

Demo ya tenía un refresco funcionando, en el crontab personal de `ruiz_rodolfo`:

```cron
## actualización de kpis
*/5 * * * * psql -h 127.0.0.1 -U postgres -p 5434 -d trazalog_tools -c "select kpi.correr();"
```

Usaba `psql` del PATH y no tenía log (la salida iba al mail local y se perdía). Se igualó a producción:

1. Alta del crontab de `postgres` con la línea estándar (18:24 -03).
2. Baja del crontab de `ruiz_rodolfo` (`crontab -r`; esa línea era todo su contenido).

### Verificación en demo

- 18:25:01: el cron de `postgres` corrió OK (log sin errores), pero no recalculó: las filas todavía no
  vencían por milisegundos (ver "Cómo decide qué recalcular").
- 18:30:01: recalculó los tres KPIs (58 filas cada uno, `calculado_en` 21:30:01 UTC).
- `kpi.event_log`: 0 errores.
