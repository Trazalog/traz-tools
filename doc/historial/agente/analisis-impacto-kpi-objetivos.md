# Análisis de impacto — Historia, objetivos y desvíos sobre el motor de KPIs (KPI-HIST, KPI-OBJ, KPI-TOOLS)

## Objetivo

Qué es: el análisis de impacto **obligatorio** (CLAUDE.md, "Sistema PRODUCTIVO") antes de tocar el motor de KPIs (`kpi.*`) y `ToolsKPIDataService`, que **ya corren en producción**, para que Kuntur pueda fijar objetivos, detectar desvíos y medir planes (ADR-A9). Para quién: el PM, que lo aprueba o lo corrige; sin su aprobación no se escribe código. Cuándo leerlo: antes de implementar KPI-HIST, KPI-OBJ y KPI-TOOLS, y antes de la Fase 5 (Kuntur). Qué NO cubre: los KPIs nuevos por industria (KPI-VERT, sale del documento de KPIs del PM) ni el módulo de tareas.

**Estado:** **aprobado por el PM el 2026-10-29**, con las recomendaciones de la sección 7, e **implementado** el mismo día (rama `feat/AGENTE-fase4-token-kpi` de `traz-tools`). Cómo se instala: [`instalacion-token-y-metas.md`](instalacion-token-y-metas.md).
**Comparado contra:** `traz-tools` `origin/master` (producción). El motor es **idéntico** en `master` y en `develop-v3.5`.

---

## 1. Por qué hace falta

Kuntur necesita tres cosas que el motor de hoy no tiene:

1. **Historia.** `kpi.cache` guarda **un valor** por KPI y empresa, y cada corrida lo pisa. Sin serie no se puede decir "cayó respecto del mes pasado" ni medir si un plan movió el KPI (R10: un plan sin medición no se puede proponer).
2. **Objetivos.** No existe dónde guardar "cumplimiento del preventivo ≥ 85 % al 31/12, responsable X". Es el objeto central del Coach.
3. **Acceso por MCP.** Kuntur lee datos **solo por MCP** (ADR-A3), y hoy ninguna tool expone `kpi.cache`. Las `man_get_kpi_*` leen otra cosa (AssetPlanner).

## 2. Cómo está hoy en producción (`master`)

| Pieza | Cómo funciona | Dónde |
|---|---|---|
| Definiciones | `kpi.definiciones`: nombre, módulo, `sql_template` con `$1 = empr_id`, `refresh_seg`. Hoy 3: `alm_reorder`, `alm_mov_sin_entregar`, `her_transito` | `_backend/database/scripts/versiones/v2.8.1.4/kpi_definiciones.sql` |
| Cálculo | `kpi.correr()` = `kpi.recalcular()` (cada definición × cada empresa, en `cache_tmp`, un error no frena al resto: va a `event_log`) + `kpi.publicar()` (copia `cache_tmp` a `cache`) | `kpi_cache_engine.sql` |
| Disparo | **Cron del sistema operativo cada 5 minutos**, en prod (10.142.0.2) y demo (10.142.0.11). PostgreSQL **11.7**, base `trazalog_tools` | [`doc/infra/kpi-cron-refresh.md`](../infra/kpi-cron-refresh.md) |
| Lectura | `ToolsKPIDataService`: `/kpi/{nombre}/emprid/{empr_id}` y `/kpis/emprid/{empr_id}` sobre `kpi.cache`; `/man/{nombre}/emprid/{empr_id}` sobre `kpi_cache` de **AssetPlanner (MySQL)** | `.../data-services/ToolsKPIDataService.dbs` |
| Consumidor | El **Tablero del Administrador**: `Dash.php` → `Dashs` → DataService, con el `empr_id` de la sesión PHP | `application/controllers/Dash.php`, `lib/props/dashboard_kpis.js` |
| KPI de Mantenimiento | La Disponibilidad **no está en `kpi.*`**: la calcula AssetPlanner en su MySQL y se refresca por un evento propio | `doc/infra/kpi-cron-refresh.md` (encabezado) |

**Por qué quedó así:** el motor nació para el Tablero (v2.5), que solo muestra el valor actual. Leer siempre de la caché, nunca del dato vivo, fue una decisión de rendimiento ([`doc/analisis/dashboard-administrador-landing.md`](../analisis/dashboard-administrador-landing.md) §2.3).

## 3. Qué cambia (propuesta)

### 3.1 KPI-HIST — la serie

- **Tabla `kpi.historico`** (`nombre`, `empr_id`, `fecha` date, `valor`, `valor_json`, `calculado_en`), PK (`nombre`, `empr_id`, `fecha`).
- **Una fila por KPI, empresa y día**, no por corrida: el cron corre cada 5 minutos y guardar cada corrida serían 288 filas diarias por KPI y empresa. `kpi.publicar()` hace **upsert del día** (el último valor del día pisa al anterior del mismo día).
- **El upsert va dentro de su propio `BEGIN … EXCEPTION`**: si la historia falla, la publicación a `kpi.cache` —que es lo que usa el Tablero hoy— **sigue igual** y el error va a `kpi.event_log`.
- Tamaño estimado: 3 KPIs × empresas × 365 días. Con 200 empresas, ~220.000 filas al año. Se propone retener **2 años** (un `DELETE` en el mismo `publicar()`, una vez por día).

### 3.2 KPI-OBJ — los objetivos y los desvíos

- **Tabla `kpi.objetivos`**: `objetivo_id`, `empr_id`, `kpi` (nombre), `fuente` (`tools` = `kpi.*`, `man` = AssetPlanner), `operador` (`>=` o `<=`), `meta`, `desde`, `hasta`, `responsable`, `petr_id` (el pedido de trabajo del plan, ADR-A9), `estado` (`vigente`, `cumplido`, `vencido`, `cancelado`), `propuesto_por` (`kuntur` o el usuario), `fec_alta`.
- **Quién la escribe: el administrador, no el agente.** Kuntur **propone** el objetivo y el administrador lo confirma desde una pantalla de Tools. Eso graba por un recurso nuevo del DataService, llamado desde PHP como el resto de Tools. Es lo que pide ADR-A8 ("dicen cómo, no hacen"). El plan decía que el objetivo "termina en `kpi.objetivos`"; esto aclara **quién** lo graba.
- **Función `kpi.desvios(empr_id)`**: los objetivos vigentes de fuente `tools` cuyo último valor en `kpi.cache` no cumple la meta, con el valor, la meta y la tendencia de los últimos 30 días (desde `kpi.historico`).
- **Los objetivos sobre KPIs de Mantenimiento** (fuente `man`) no se pueden evaluar en SQL: el valor está en el MySQL de AssetPlanner. Los evalúa el job de Kuntur con `man_get_kpi_*`. Cuando Mantenimiento migre a `traz-tools-man`, pasan al motor.

### 3.3 KPI-TOOLS — las tools MCP

Cuatro recursos **de lectura** nuevos en la fachada `toolsMCPAPI` (patrón de ADR-013: el `empr_id` sale del JWT, nunca es parámetro), ruteados a `ToolsKPIDataService`:

| Tool | Devuelve |
|---|---|
| `kpi_get_valor` | Valor actual de un KPI (o de todos) de la empresa, de `kpi.cache` |
| `kpi_get_historico` | La serie diaria de un KPI entre dos fechas |
| `kpi_get_objetivos` | Los objetivos vigentes de la empresa |
| `kpi_get_desvios` | Lo que devuelve `kpi.desvios()` |

Se suman al contrato `doc/api/trazalog-operaciones.yaml` y al catálogo de los agentes (`agente.tool`, módulo `kpi`, clase `lectura`). El test que compara el catálogo con el contrato (AGENTE-M-02) obliga a catalogarlas.

## 4. Qué lo consume (todos los caminos)

| Quién | Usa | Qué le pasa con el cambio |
|---|---|---|
| Tablero del Administrador | `kpi.cache` vía `/kpi/...` y `/kpis/...` | **Nada**: `cache` y sus recursos no cambian |
| Cron de prod y demo | `kpi.correr()` | Sigue igual; `publicar()` suma el upsert del día, **aislado** para que no pueda frenarlo |
| `/man/{nombre}/...` (AssetPlanner) | MySQL de AssetPlanner | **Nada** |
| Agentes | — (hoy no leen KPIs del motor) | **Nuevo**: las 4 tools |
| Administrador | — | **Nuevo**: confirma objetivos desde Tools |

## 5. Qué se rompe si se hace mal

| Riesgo | Cómo se previene |
|---|---|
| Que `publicar()` falle y el Tablero deje de actualizarse **en producción** | El upsert de historia va en su propio bloque de excepción; un test lo fuerza a fallar y verifica que `kpi.cache` se publica igual |
| SQL que no corre en PostgreSQL 11 (prod es 11.7) | Probar en un PostgreSQL 11 descartable antes de DEV |
| Que la historia crezca sin límite | Una fila por día; retención de 2 años |
| Un `empr_id` como parámetro en las tools nuevas = fuga entre empresas | Patrón ADR-013 (del JWT); tests Hurl de aislamiento entre dos empresas, como los de las tools actuales |
| Desplegar el `.car` con un DataService que no conecta revierte el CAR **completo** (nota operativa de E2-MCP-11) | Verificar las conexiones del ambiente antes del despliegue |

## 6. Cómo se prueba

1. En un PostgreSQL 11 descartable: aplicar el motor actual, correr `kpi.correr()` y guardar `kpi.cache` como referencia.
2. Aplicar el cambio: `kpi.cache` tiene que quedar **igual** que la referencia; `kpi.historico` con una fila por KPI y empresa; una segunda corrida el mismo día **no** suma filas.
3. Forzar un error en la historia: `kpi.cache` se publica igual y el error queda en `kpi.event_log`.
4. Objetivos y desvíos con datos sembrados: un objetivo incumplido aparece en `kpi.desvios()` y uno cumplido no.
5. Las 4 tools por el gateway en DEV, con dos empresas: cada una ve solo lo suyo.

## 7. Lo que necesito que decidas

1. **¿Aprobás el diseño?** (sección 3).
2. **Granularidad diaria de la historia** y **retención de 2 años**.
3. **Los objetivos los graba el administrador desde Tools, no el agente** (3.2). Lo propongo por ADR-A8. Implica una pantalla de objetivos en Tools, que hoy no está en el plan.
4. **Objetivos sobre KPIs de Mantenimiento:** se evalúan desde el job de Kuntur con `man_get_kpi_*` hasta que Mantenimiento migre.
