# Casos de uso de operación minera y gaps de tools

## Objetivo

Qué le va a preguntar a Claude un proveedor de servicios mineros, qué se puede responder **hoy**,
y qué falta construir. Cruza los casos de alto impacto identificados en
[`investigacion-sector-minero-trazalog-v3-2.md`](../v3/investigacion-sector-minero-trazalog-v3-2.md)
con el relevamiento de modelos de
[`codeigniter-models-survey.md`](../api/codeigniter-models-survey.md) y con lo que realmente hay
en las bases.

Escrito para decidir qué tools construir y en qué orden. No documenta lo ya construido — eso está
en [`escenarios-de-uso-y-regresion.md`](escenarios-de-uso-y-regresion.md).

| | |
|---|---|
| **Fecha** | 2026-08-11 |
| **Relevado contra** | `assetv2` (Asset Planner) y `tools_prod_t` (Almacenes), base de desarrollo |
| **Resultado** | 21 casos · **12 cubiertos** · 9 con gap |

> **Sobre los datos de prueba:** la base de desarrollo tiene datos agrícolas y de laboratorio, no
> mineros. Los equipos sí incluyen maquinaria real (generador, autoelevador, equipo de corte,
> turbina) y las tareas preventivas son textualmente de maquinaria pesada. Los casos son válidos
> funcionalmente; los ejemplos con insumos mineros son ilustrativos.

---

## 1. Hallazgos que cambian el plan

Tres cosas encontradas en este relevamiento que no estaban en el análisis anterior:

### 1.1. Los KPIs ya están implementados como DataService

`MANDataService.dbs` **ya tiene** las queries de los KPIs que el documento de minería lista como
críticos, con sus resources publicados:

| Query existente | KPI | Benchmark del sector |
|---|---|---|
| `getKPIDisponibiidadPorFecha` (+ `PorEquipo`) | Disponibilidad % | >92% |
| `getKPIMttrporFecha` (+ `xEquipo`) | MTTR | <6 hs |
| `getKPIMttfporFecha` (+ `porEquipo`) | MTTF | varía |
| `getCantidadFallos` (+ `xEquipo`) | Frecuencia de fallas | — |

**No hay que calcular nada: hay que exponerlas como tools.** Esto contradice la suposición previa
de que los KPIs vivían solo en el frontend PHP.

### 1.2. …pero la tabla que leen está vacía, y hace 2 años

Los KPIs leen de **`historial_lecturas_mem`**, una tabla `ENGINE=MEMORY` (se vacía al reiniciar
MySQL) que puebla un evento programado:

```
event_scheduler = OFF
ejecutar_historial_lecturas_mem  ·  cada 1 MINUTE  ·  LAST_EXECUTED: 2024-09-12
```

**El event scheduler de MySQL está apagado**, así que la tabla tiene 0 filas y cualquier KPI
devuelve vacío hoy. Es un problema de infraestructura de la base, no de las queries.

> ✅ **Confirmado por el PM (2026-08-12): en producción los KPIs se usan activamente** — el
> dashboard de Asset Planner muestra Disponibilidad, MTBF y el donut Correctivo/Preventivo/Backlog
> con datos reales. O sea que allá el evento sí corre y la tabla se puebla. **El problema es solo
> del ambiente de desarrollo**, y no bloquea exponer los KPIs como tools: hay que prender el
> scheduler en desarrollo para poder probarlas.

### 1.3. `orden_trabajo.tipo` — resuelto por código y datos

El catálogo no existe como tabla; está en el `switch` de `Calendarios.php::getInfoTareaProgram()`
y se confirma cruzando con los datos:

| `tipo` | OTs | Verificación en datos | Significado |
|---|---|---|---|
| **3** | 684 | 684 con plan preventivo asociado | **Preventivo** |
| **2** | 130 | 130 con solicitud correctiva | **Correctivo** |
| **4** | 20 | 20 con plan preventivo | **Backlog** |
| 1 y 10 | 132 | sin origen | OT directa desde menú |

Con esto el ratio preventivo/correctivo es calculable **hoy**: la empresa 6 tiene
**84,4% de mantenimiento planificado** (704 planificadas / 130 correctivas), contra el benchmark
world-class de >85%.

---

## 2. Lo que el modelo soporta

### Mantenimiento (`assetv2`)

| Concepto | Tabla | Volumen | Relevante para |
|---|---|---|---|
| Plan preventivo | `preventivo` | 130 planes | M1, M2, M3 |
| Periodicidad | `periodo` | Diario · Semanal · Mensual · Semestral · Anual · **Horas · Km · Ciclos** | M2 |
| **Predictivo** | `predictivo` | 7 planes, 5 equipos | M8 |
| **Backlog** | `tbl_back` | 37 ítems | M9 |
| **Bill of materials del PM** | `tbl_preventivoinsumos` | 6 (prevId + artId + cantidad) | **C1** |
| Herramientas del PM | `tbl_preventivoherramientas` | 14 | C1 |
| Lecturas | `historial_lecturas` | 534, con trigger que actualiza `equipos.ultima_lectura` | M2, M4 |
| Criticidad | `criticidad` | Muy Alta 8 · Alta 39 · Media 15 · Baja 20 | M3 |
| KPIs | `historial_lecturas_mem` | **0 filas** (ver §1.2) | K1-K4 |

Tareas preventivas cargadas, textuales:

> *"Cambiar Aceite de Diferencial Delantero y Trasero (cada 1000 hs según horómetro, utilizar
> aceite SAE50)"* · *"Cambie el Aceite de Motor (15W40)"* · *"Apriete los Tornillos de los
> Pasadores de Expansión de los Cilindros"*

### Almacenes (`tools_prod_t`)

| Concepto | Dónde | Query existente |
|---|---|---|
| Stock por depósito | `alm_lotes.depo_id` | `getStockXArticuloYDeposito` ✅ |
| Tipo de artículo | `core.tablas` | `getArticulosXTipo` ✅ |
| Vencimientos | `alm_lotes.fec_vencimiento` | `getLotesVencimientos` ✅ (ya clasifica Crítico/Advertencia) |
| Consumo | `alm.movimientos` | `getHistoricoMovimientos` ✅ |
| Punto de pedido | `alm_articulos.punto_pedido` | — |

### Decisiones tomadas con el PM (2026-08-11)

1. **Estado del preventivo**: usar `estadoprev` tal cual, sin recalcular.
2. **Lectura actual**: leer de `historial_lecturas`. El trigger `actualizaLectura` sí mantiene
   `equipos.ultima_lectura`, pero refleja la **última lectura insertada**, y las últimas cargas
   fueron con valor `0` ("Verificación Masiva Informe Servicio") — por eso está en 0. Para
   horómetros conviene tomar el **máximo**, que es monotónico creciente.
3. **Artículos críticos**: no se agrega nada al modelo. **Claude aporta el conocimiento de
   dominio** — releva qué insumos son clave en minería y consulta por esos. Las tools solo tienen
   que permitir buscarlos.

---

## 3. Casos por área

Los marcados con ⭐ son los de **impacto ALTO** según la investigación del sector minero.

### Mantenimiento

| # | Caso | Pregunta del usuario | Estado |
|---|---|---|---|
| M1 | Equipos sin plan preventivo | «¿Qué equipos no tienen preventivo cargado?» | ✅ cubierto (2026-08-12) |
| M2 ⭐ | Preventivos vencidos | «¿Qué mantenimientos tengo vencidos?» | ✅ cubierto (2026-08-12) |
| M3 ⭐ | Priorizar por criticidad | «De esos, ¿cuáles son críticos?» | ✅ cubierto |
| M4 | Equipos sin lecturas | «¿A qué equipos no les toman el horómetro?» | ✅ cubierto (2026-08-12) |
| M5 | Backlog por antigüedad | «¿Qué OTs llevan más de una semana abiertas?» | ✅ cubierto |
| M6 ⭐ | Equipos que más fallan | «¿Qué equipo me dio más problemas?» | ✅ cubierto |
| **M7** ⭐ | Ratio preventivo/correctivo | «¿Estoy previniendo o apagando incendios?» | ❌ gap (datos ✅, ver §1.3) |
| **M8** | Planes predictivos | «¿Qué predictivos tengo programados?» | ❌ gap |
| **M9** | Cola de backlog | «¿Qué trabajo pendiente tengo priorizado?» | ❌ gap |

**Verificado con datos** (empresa 8): **60 de 68 equipos sin plan preventivo**, de los cuales
**31 son criticidad Alta y 6 Muy Alta**. Y 47 equipos sin lectura en 90 días.

M3 **sí está cubierto**: `man_get_equipos` devuelve `criticidad` y `sector` en el listado (una
revisión anterior lo dio por faltante por haber truncado la salida al inspeccionarla).

### KPIs (el diferencial competitivo del sector)

| # | KPI | Benchmark | Query | Estado |
|---|---|---|---|---|
| **K1** ⭐ | Disponibilidad | >92% | `getKPIDisponibiidadPorFecha` ✅ | ❌ sin tool + tabla vacía |
| **K2** | MTTR | <6 hs | `getKPIMttrporFecha` ✅ | ❌ sin tool + tabla vacía |
| **K3** | MTTF / MTBF | >800 hs | `getKPIMttfporFecha` ✅ | ❌ sin tool + tabla vacía |
| **K4** | Frecuencia de fallas | — | `getCantidadFallos` ✅ | ❌ sin tool + tabla vacía |
| **K5** | **PM Compliance** | >95% | — | ❌ calculable con lo que hay |
| K6 | OEE | >85% | — | ❌ requiere datos de performance y calidad |
| K7 | MC/RAV | 2-6% | — | ❌ requiere valor de reposición del activo |

K5 (PM Compliance = % de preventivos completados a tiempo) es **calculable hoy** cruzando
`preventivo.ultimo` con las OTs de tipo 3 — no necesita datos nuevos.

### Almacenes

| # | Caso | Pregunta | Estado |
|---|---|---|---|
| I1 ⭐ | Bajo punto de pedido | «¿Qué tengo que reponer?» | ✅ cubierto (E1) |
| I2 | Stock por tipo y depósito | «¿Cuántos insumos hay en Zaranda?» | ✅ cubierto (2026-08-12) |
| I3 ⭐ | Insumos clave por nombre | «¿Tengo filtros y aceite hidráulico?» | ✅ cubierto (2026-08-12) |
| I4 | Lotes por vencer | «¿Qué se vence este mes?» | ✅ cubierto (2026-08-12) |
| **I5** | Consumo histórico | «¿Cuántos filtros usamos el mes pasado?» | ❌ gap (query ✅) |
| I6 | Stock inmovilizado | «¿Qué no se mueve hace un año?» | ❌ gap (depende de I5) |

I3 se resolvió agregando el parámetro `buscar` a `alm_get_stock`, en vez de que el agente traiga
el catálogo entero y filtre —que funciona con 311 artículos pero no escala a miles.

Verificado: 58 lotes vencidos con stock en la empresa 1.

### Cruzados — donde está el valor real de la capa MCP

| # | Caso | Por qué importa | Estado |
|---|---|---|---|
| C2 | Falla → OT → pedido | flujo diario | ✅ cubierto (E2+E1) |
| **C1** ⭐ | **Repuestos para los PMs que vienen** | evita el stockout que para una máquina | ❌ bloqueado por M2 |
| **C3** ⭐ | **Informe para la minera** | hoy se arma a mano en 2-3 hs | ❌ bloqueado por K1-K4 |

**C1** es el caso que mejor justifica toda la arquitectura: requiere leer la tarea preventiva en
lenguaje natural (*"cambiar aceite de motor 15W40"*), inferir qué insumo necesita, y buscarlo en
el catálogo. Ninguna consulta SQL hace eso. Y **el bill of materials ya existe**
(`tbl_preventivoinsumos`), así que para los PMs que lo tengan cargado el cruce es directo.

> ⚠️ **Obstáculo conocido para C1:** `tbl_preventivoinsumos.artId` apunta al **almacén legacy de
> Asset Planner** (`articles`), no a `alm_articulos` de Tools. Es la deuda técnica de almacenes
> duplicados que ya documenta la investigación del sector (§ "Deuda técnica crítica"). Para el
> piloto, la estrategia validada es **fuentes separadas**: mantenimiento desde Asset Planner,
> inventario desde Tools, y el cruce lo hace el agente por descripción, no por ID.

**C3** («armame el informe semanal para Barrick») es el de mayor wow-factor comercial según la
investigación. Necesita K1-K4 expuestos, que a su vez necesitan la tabla `_mem` poblada.

---

## 4. Plan propuesto, por valor

### Ola 1 — desbloquea 6 casos

**`man_get_preventivos`** — M1, M2, M3 y desbloquea C1.

Es el único gap donde **no existe ninguna query previa**: ningún DataService toca la tabla
`preventivo` (confirmado). El survey de modelos ya lo anticipaba como `MANPreventivoDataService`
(nuevo).

Devuelve por equipo: tarea, componente, periodicidad, intervalo, última ejecución, `estadoprev`,
**criticidad del equipo** y la **lectura actual** desde `historial_lecturas`. Con parámetros para
filtrar por estado y para traer los equipos **sin** plan (M1).

### Ola 2 — reutiliza queries existentes, costo bajo

| Tool | Habilita | Reutiliza |
|---|---|---|
| Parámetros `depo_id` / `tipo` / `buscar` en `alm_get_stock` | I2, I3 | `getStockXArticuloYDeposito`, `getArticulosXTipo` |
| `alm_get_vencimientos` | I4 | `getLotesVencimientos` (ya clasifica) |
| `man_get_lecturas` | M4 | `historial_lecturas` |
| Criticidad en `man_get_equipos` | M3 completo | ajuste de una query |

> Para I2/I3 conviene **enriquecer la tool existente** en vez de crear nuevas: menos tools que
> elegir para el agente, misma semántica. Los parámetros tienen que ser **opcionales** para no
> romper la suite de regresión.

### Ola 3 — KPIs (requiere destrabar la infraestructura)

`man_get_kpis` envolviendo las 4 queries existentes. **Bloqueado hasta resolver §1.2**
(event scheduler apagado). Habilita K1-K4 y desbloquea C3, el informe para la minera.

K5 (PM Compliance) se puede calcular sin esa dependencia, cruzando `preventivo` con OTs tipo 3.

### Ola 4

`man_get_predictivos` (M8), `man_get_backlog` (M9), `alm_get_movimientos` (I5, I6).

---

## 5. Pendientes de confirmar

1. **Event scheduler de MySQL en producción** — si está apagado como en desarrollo, los KPIs del
   dashboard de Asset Planner tampoco estarían funcionando hoy. Es una verificación de 1 minuto
   (`SHOW VARIABLES LIKE 'event_scheduler'`) con impacto directo en qué se puede prometer.
2. **`getHistoricoMovimientos`** — confirmar si registra todos los tipos de movimiento (entradas,
   salidas, ajustes, transferencias) antes de exponerlo para I5/I6.
3. **Estados `CE`, `PL`, `AS`, `M` de `estadoprev`** — se devuelven tal cual (decisión tomada),
   pero conviene documentar qué significan para que el agente los explique en palabras en vez de
   mostrar la sigla.
