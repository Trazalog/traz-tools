# Dashboard / Landing del Administrador (v2.5)

## Objetivo

Qué es: la arquitectura, los supuestos y el plan por fases del **tablero que ve el Administrador
apenas se registra y en cada login**. Dos sectores: (A) SUSCRIPCIÓN (datos fijos de la cuenta) y
(B) KPIs (cajas con gráficos que leen de una **caché**, no del DataService normal). Escrito para
que Rodolfo/Mauricio lo lean antes de aprobar el backend, y para que yo lo implemente sin depender
del chat.
Para quién: PM (Mauricio y Rodolfo).
Cuándo leerlo: antes de aprobar/desplegar la parte 🔴 (caché KPI en Postgres + su scheduler).
Qué NO cubre: no define pantallas de administración para configurar el tablero (eso es de una
versión futura; ver §"Configurabilidad"). No cambia el flujo de login/registración salvo **a qué
vista aterriza** el admin.

## Metadata

- **Fecha:** 2026-09-24
- **Rama:** `feat/admin-dashboard-landing` (desde el tip de `develop`, para salir con **v2.5**).
- **Clase de riesgo:** mixta.
  - 🟢/🟡 Fase 1 (frontend del landing + sector Suscripción): vista nueva + hook de aterrizaje +
    una query aditiva de conteo de usuarios. No rompe nada existente.
  - 🔴 Fase 2 (caché KPI en Postgres + scheduler + KPIDataService): schema nuevo + mecanismo
    periódico. **Requiere OK del PM antes de desplegar** (regla de sistema productivo).
- **Directiva del PM (2026-09-24):** "desarrollo rápido; si tenés que asumir cosas, hacelo y
  anotalas, después lo modificamos". Este doc es esa lista de supuestos.

---

## 1. Cómo aterriza hoy el usuario (verificado)

- `config/constants.php`: `default_controller` efectivo → `Dash`; `DEF_VIEW = BPM.'Proceso'`.
- `Dash::index()` (`application/controllers/Dash.php`) arma la **cáscara**: memberships, menú,
  copyright y logo (de `core.tablas`), y hace `load->view('layout/Admin', $data)`.
- `layout/Admin.php:497` ejecuta `linkTo('<?php echo DEF_VIEW ?>')`.
- `lib/props/navegacion.js`: `linkTo(link)` hace `$('#content').load(link)` — carga el **fragmento**
  del controller por AJAX dentro de `#content`. Así funciona toda la navegación de Tools.

**Conclusión de diseño:** para que el admin aterrice en el tablero, NO hay que tocar login ni
registración: alcanza con cambiar **qué ruta recibe `linkTo`** en `Admin.php`, según el rol.

## 2. Arquitectura elegida

### 2.1 Hook de aterrizaje (Fase 1)
- En `Dash::index()` se calcula `$data['landing']`:
  - Si el usuario es **Administrador** → `'Dash/dashboard'`.
  - Si no → `DEF_VIEW` (comportamiento actual, intacto).
- `Admin.php:497` pasa a `linkTo('<?php echo $landing ?>')`.
- Detección de admin: **SUPUESTO A1** — se considera admin si alguna de sus memberships tiene
  `role` que empieza con `"Administrador "` (así los crea el SP `configuracion_inicial_empresa_trg`,
  línea 38: `'Administrador '||new.nombre`). Se encapsula en helper `esAdministrador($memberships)`.

### 2.2 El tablero es un fragmento en el core (Fase 1)
- Método nuevo `Dash::dashboard()` → `load->view('dashboard/admin_dashboard', $data)`.
- Vive en el **core** (controller `Dash`, vista `application/views/dashboard/`), no en un módulo
  nuevo: es transversal a la empresa y no cuelga de un permiso de módulo.
- La vista se arma desde una **config declarativa** (§4), pensada para que mañana la fuente sea
  dinámica sin reescribir la vista.

### 2.3 Los KPIs leen de una caché, nunca del dato vivo (Fase 2)
Igual que AssetPlanner (estudiado en `/mnt/win/dev/Trazalog/kpi`):
- Un **registro** de queries a cachear + un **proceso periódico** que las calcula por empresa y las
  deja en una tabla de caché. El tablero lee SOLO de esa caché vía un **KPIDataService** dedicado.
- Mejora respecto de AssetPlanner: AssetPlanner guarda **un solo `valor float`** por
  (nombre, período, empresa) — insuficiente para KPIs con desglose (artículos bajo punto de pedido
  *por establecimiento/depósito*, herramientas en tránsito vs total, etc.) ni para graficar. La
  versión Postgres guarda **`valor_json` (jsonb)** además del escalar, y un **intervalo de refresco
  por KPI**. Ver §5.

---

## 3. Sector A — SUSCRIPCIÓN (Fase 1)

| # | Dato | Fuente en Fase 1 | Supuesto / Nota |
|---|---|---|---|
| 0 | Nombre del usuario + fecha de hoy + saludo | sesión (`first_name`/`last_name`/`usernick`) + `date()` PHP + constante | **A2**: el saludo es una constante `DASH_WELCOME_MSG`. La fecha se arma en PHP (server), formato es-AR. |
| 1 | Nombre empresa + logo | nombre: sesión/`empresa()`; logo: `core.tablas` `configuraciones_uitoolsLogoNavbar` (ya lo carga `Dash::index`) | **A3**: se reusa el logo del navbar. Si la empresa tuviera logo propio distinto, se cambia después. |
| 2 | Cantidad de usuarios generados | query **aditiva** nueva en `COREDataService` (COUNT sobre los usuarios de la empresa) | **A4**: cuenta usuarios vinculados a la empresa (por `seg.users_business`/memberships). Query nueva = cambio de API aditivo → **requiere deploy de la API** (el script de deploy no lo hace solo). |
| 3 | Tipo de suscripción | regla por fecha de alta de empresa: **Freemium** si alta ≥ 2026-09-01, **Full** si es anterior | **A5**: hoy es informativo/constante (el PM lo pidió así). Si consigo la fecha de alta de la empresa la aplico; si no, muestro `Freemium` por defecto. No hay lógica de facturación detrás todavía. |
| 4 | Módulos habilitados | constante: 3 cuadros **MAN, ALM, HER** | **A6**: fijo por ahora (pedido del PM). `HER` = Herramientas (Pañol). El mapeo real a módulos de Tools se define en una versión futura. |
| 5 | Timeline corto de actividad/estado por módulo | placeholder con estructura para dato futuro | **A7**: en Fase 1 muestra estado estático ("Operativo") por módulo. La estructura ya contempla ítems con fecha+texto para cuando haya fuente. |

Tono (pedido del PM): el admin tiene que **sentir que controla** su cuenta. Diseño moderno,
contenido corto y directo. Sin scroll (o mínimo). Performance: el sector A es todo dato liviano
(sesión + 1 query), se pinta instantáneo.

---

## 4. Configurabilidad (sin pantalla de admin todavía)

Cada caja se declara en una config (Fase 1: archivo PHP `config/dashboard.php` como default).
Estructura por caja, pensada para que la fuente futura (core.tablas / pantalla admin) la reemplace
sin tocar la vista:

```php
[
  'id'          => 'kpi_reorder',
  'sector'      => 'kpi',            // 'suscripcion' | 'kpi'
  'titulo'      => 'Artículos bajo punto de pedido',
  'orden'       => 10,               // posición
  'ancho'       => 4,                // columnas bootstrap (col-md-N)
  'alto'        => 260,              // px
  'refresh_seg' => 300,             // refresco (Fase 2, KPIs)
  'color'       => '#2b6cb0',
  'kpi_nombre'  => 'alm_reorder',   // clave del KPI en la caché (Fase 2)
  'chart'       => 'bar',            // tipo de gráfico (Fase 2)
]
```

**SUPUESTO A8:** en v2.5 esta config es un default en código. No se construyen pantallas de
administración (refresco/posición/tamaño/colores) — es de una versión futura, pero la estructura ya
las contempla.

---

## 5. Sector B — KPIs (Fase 2, 🔴 requiere OK)

### 5.1 KPIs pedidos
1. **ALM** — artículos bajo punto de pedido, **por establecimiento/depósito** (desglose → `valor_json`).
2. **ALM** — cantidad de movimientos internos **sin entregar** (escalar).
3. **HER** — herramientas **en tránsito vs total** (dos valores → `valor_json`).
4. **MAN** — disponibilidad + **1 KPI más de MAN** (a definir; candidato: OTs abiertas / vencidas).

### 5.2 Fuentes de dato (multi-fuente) — **SUPUESTOS a confirmar**
- **A9 (ALM):** salen de Postgres de Tools (schema `alm.`) → caché **nueva en Postgres**.
- **A10 (MAN):** MAN ya tiene caché en AssetPlanner (MariaDB) y un `MANKPIDataService.dbs` que la
  lee. Se **reutiliza** esa caché para los KPIs de MAN, no se recalculan en Postgres.
- **A11 (HER/Herramientas):** viven en el módulo Pañol (`traz-comp-pan`). **A confirmar dónde está
  el dato** (Postgres Tools vs otra base) antes de escribir su query.

### 5.3 Caché Postgres (mejora sobre AssetPlanner)
Tablas nuevas en un schema `kpi` (o `core`, a confirmar — **A12**):
- `kpi.definiciones` (registro): `nombre` PK, `sql_template`, `refresh_seg`, `habilitado`.
- `kpi.cache`: `(nombre, empr_id, calculado_en)`, `valor numeric`, `valor_json jsonb`,
  `vence_en`. Dos fases (tmp → publish) como AssetPlanner para no servir datos a medio calcular.
- Guardar `valor_json` habilita desglose y drill-down sin ir al dato vivo.

### 5.4 Scheduler — **A13 (RESUELTO por verificación contra la BD)**
Se había aprobado `pg_cron`, pero se verificó contra `tools_prod_t` (PostgreSQL **11.18**) que
**pg_cron NO está instalado ni disponible** (extensiones presentes: `dblink`, `pgcrypto`,
`plpgsql`). Así que el scheduler **no puede vivir dentro de Postgres**. Queda elegir entre:
- **(A) cron del SO** en el server de Postgres: `*/5 * * * * psql ... -c "select kpi.correr();"`
  (con `~/.pgpass` y un usuario con `EXECUTE` sobre `kpi.correr()`). Simple, una línea.
- **(B) Tarea programada de WSO2** (ScheduledTask) que invoque un recurso del DataService que corra
  `kpi.correr()`. Coherente con la capa de integración/MCP, pero requiere exponer un resource de
  escritura y versionarlo.

El motor (`kpi_cache_engine.sql`) ya documenta las dos en su sección SCHEDULER. **Mientras se define,
la caché se puebla a mano con `SELECT kpi.correr();`** (sirve para demo).

### 5.5 KPIDataService (Tools/Postgres)
`.dbs` nuevo, espejo de `MANKPIDataService`, contra el datasource Postgres de Tools. Expone
`GET /kpi/{nombre}/emprid/{empr_id}` devolviendo `valor` + `valor_json`. El tablero llama SIEMPRE a
este DataService, nunca a los DataService de negocio.

### 5.6 Frontend KPI (Fase 2)
- Cada caja pide su KPI por AJAX al arrancar y se auto-refresca según `refresh_seg`.
- Gráfico con **Chart.js** (barras/dona/línea según la caja) — **A14**, salvo que prefieras la libr.
  que ya use Tools.
- **Drill-down:** click en la caja abre el detalle (usa `valor_json`, o navega a la pantalla del
  módulo con el filtro correspondiente).
- En Fase 1 las cajas KPI se renderizan como **scaffolding** ("Datos en preparación — Fase 2") para
  que se vea el layout completo sin backend.

---

## 6. Plan por fases

- **Fase 1 (esta rama, ya):** hook de aterrizaje + `Dash::dashboard()` + vista + config default +
  sector Suscripción completo (con supuestos A1–A8) + cajas KPI como scaffolding. Demoable sin
  tocar backend 🔴. La query de conteo de usuarios (A4) es el único cambio de API (aditivo).
- **Fase 2 (implementada en esta rama):** motor de caché Postgres (`kpi.*`) + definiciones de los
  3 KPIs de Tools (verificadas contra la BD) + `ToolsKPIDataService.dbs` + endpoint `Dash/kpi` +
  frontend con gráficos propios (canvas) + drill-down. Falta: elegir/activar el scheduler (A13, §5.4)
  y el wiring del KPI de MAN (lee de AssetPlanner, no de Postgres — supuesto A10).

### Estado de verificación (Fase 2)
- Las 3 queries de Tools se **corrieron read-only contra `tools_prod_t`** (empr_id=1) y dieron datos
  reales: reorder = 4 filas por depósito; movs sin entregar = 10; herramientas 16 en tránsito / 37.
- KPI reorder: stock = `SUM(alm_lotes.cantidad)` de lotes `estado='AC'`, comparado contra
  `alm_articulos.punto_pedido` (global por artículo, no por depósito). Borde: artículo con
  `punto_pedido>0` pero sin lotes en un depósito (stock 0) no aparece.
- El motor aísla cada cálculo en su `BEGIN/EXCEPTION`: un KPI que falle no rompe al resto (queda en
  `kpi.event_log`). Igual, **probar en dev antes de desplegar** (regla de sistema productivo).
- Deploy: `ToolsKPIDataService.dbs` lo sube el script de deploy (es DataService, no API). Los 2 `.sql`
  de `v2.8.1.4/` se corren en Postgres a mano. Rebuild del `.car` con `./mvnw clean install`.

## 6-bis. Puesta en marcha del scheduler (cron del SO) — decidido por el PM

> Todo esto se ejecuta **por SSH en el servidor de PostgreSQL** (el host de `tools_prod_t`), NO en
> tu máquina ni en la consola web. Se hace **una sola vez** por ambiente.

**Paso 1 — Crear un usuario de BD de bajo privilegio para el cron** (en `psql` como `postgres`,
en el server de Postgres). Que solo pueda ejecutar la función, no tocar datos:

```sql
CREATE ROLE kpi_cron LOGIN PASSWORD 'PONER_UNA_CLAVE';
GRANT USAGE ON SCHEMA kpi TO kpi_cron;
GRANT EXECUTE ON FUNCTION kpi.correr() TO kpi_cron;
```

**Paso 2 — Guardar la clave en `~/.pgpass`** del usuario del SO que corre el cron (shell del server
de Postgres), para no ponerla en el crontab. Formato `host:port:db:user:password`:

```
127.0.0.1:5432:tools_prod_t:kpi_cron:PONER_UNA_CLAVE
```

Y darle permisos restringidos al archivo:

```bash
chmod 600 ~/.pgpass
```

**Paso 3 — Agregar la línea al crontab** (shell del server de Postgres, `crontab -e`). Cada 5
minutos corre `kpi.correr()`, que recalcula solo lo vencido (respeta `refresh_seg`) y publica:

```
*/5 * * * * psql -h 127.0.0.1 -U kpi_cron -d tools_prod_t -c "select kpi.correr();" >> /var/log/kpi_cron.log 2>&1
```

**Verificación** (en `psql`): que la caché se esté poblando y no haya errores acumulados:

```sql
SELECT nombre, empr_id, valor, calculado_en FROM kpi.cache ORDER BY calculado_en DESC LIMIT 20;
SELECT * FROM kpi.event_log WHERE estado = 'ERROR' ORDER BY fecha DESC LIMIT 20;
```

Para una primera carga inmediata (sin esperar al cron), correr a mano: `SELECT kpi.correr();`.

## 7. Compatibilidad y rollback

- **Compat v2:** cero cambios en contratos existentes. El hook de aterrizaje solo agrega una rama
  para admins; todo lo demás aterriza igual que hoy. La query de conteo es **aditiva**.
- **Rollback Fase 1:** revertir `Dash.php`, `Admin.php`, borrar la vista y la config. Sin migración.
- **Rollback Fase 2:** los objetos `kpi.*` son nuevos; `DROP` reversible. El scheduler se apaga.

## 8. Pendiente de confirmación (resumen de supuestos)

| ID | Supuesto | Impacto si cambia |
|---|---|---|
| A1 | Admin = role que empieza con "Administrador " | detección de aterrizaje |
| A4 | Conteo de usuarios por `users_business`/memberships | query del sector A |
| A5 | Freemium ≥ 2026-09-01, si no Full | etiqueta de suscripción |
| A6 | Módulos fijos MAN/ALM/HER | sector A item 4 |
| A11 | Dato de Herramientas en Pañol | KPI 3 |
| A12 | Schema `kpi` para la caché | Fase 2 (implementado) |
| **A13** | ~~pg_cron~~ **NO disponible en la BD** → cron del SO (rec.) o tarea WSO2 | **Falta elegir/activar (§5.4)** |
| A14 | Gráficos con Chart.js | Fase 2 frontend |
