# Metas de pedido y de hito sobre los KPI de la empresa (TAR-METAS)

## Objetivo

Qué es: el diseño y el análisis de impacto de las **metas medibles** de un pedido de trabajo y de sus hitos, por ejemplo "mejorar la disponibilidad de equipos un 30 %, hasta llegar a 70 %". Para quién: el PM, que aprueba el cambio en la base, y quien lo instale o lo pruebe. Cuándo leerlo: antes de aplicar `v2.8.1.8/kpi_metas_pedido_hito.sql` en cualquier base. Qué NO cubre: el motor de KPIs ni las metas generales de la empresa, que están en [`doc/agente/analisis-impacto-kpi-objetivos.md`](../agente/analisis-impacto-kpi-objetivos.md). Tampoco el campo `objetivo` de pedidos e hitos: es una duración, no una meta.

**Estado:** el PM decidió el diseño el 2026-11-12 (las 4 decisiones de la sección 2). Falta que apruebe aplicar el script en la base compartida de desarrollo.
**Comparado contra:** `traz-tools` `develop-v3.5`. `kpi.objetivos` y `kpi.objetivo_guardar()` son las de v2.8.1.6, sin cambios desde entonces.

---

## 1. Qué hay hoy

| Pieza | Estado |
|---|---|
| `kpi.objetivos` (v2.8.1.6) | Metas sobre KPIs: `kpi`, `operador` (`>=` o `<=`), `meta`, `desde`/`hasta`, `responsable`, `estado`. Tiene la columna **`petr_id`, que nunca se llena**. No conoce los hitos ni guarda el valor de partida. |
| `kpi.objetivo_guardar()` | La única forma de grabar una meta. Permite **una sola meta vigente por KPI y empresa**. |
| Pantalla | `Objetivos` (Tablero). **Solo la usa el administrador.** |
| KPIs elegibles | Los del Tablero (`application/config/dashboard.php`): 3 de Tools (almacén y herramientas) y la **Disponibilidad de equipos** (Mantenimiento, sale de AssetPlanner). |
| `pro.pedidos_trabajo.objetivo` y `tst.hitos.objetivo` | Una duración (número más unidad de tiempo). No se usa en ningún cálculo. **No se toca.** |

## 2. Decisiones del PM (2026-11-12)

1. **Dónde:** el pedido tiene metas y, opcionalmente, cada hito tiene las suyas.
2. **Cómo se carga:** el valor a alcanzar y la fecha límite. El sistema guarda solo el valor del indicador en ese momento (**línea base**) y muestra cuánto se avanzó y cuánto falta.
3. **Quién:** quien planifica el pedido, desde la misma pantalla de planificación. Las metas generales de la empresa siguen siendo del administrador.
4. **Varias metas:** sigue habiendo una sola meta **general** vigente por indicador. Cada pedido o hito puede tener la suya, aunque mida el mismo indicador.

## 3. Qué cambia

### 3.1 Base de datos — `v2.8.1.8/kpi_metas_pedido_hito.sql`

- `kpi.objetivos`: columnas nuevas **`hito_id`**, **`linea_base`** y **`linea_base_fecha`**, todas opcionales, más un índice parcial por `petr_id`.
- `kpi.objetivo_guardar()`: suma `p_petr_id`, `p_hito_id` y `p_linea_base`, todos con default `null`.
  - Las llamadas de hoy no cambian: el Tablero, el DataService y Kuntur, que no graba.
  - Valida que el pedido sea de la empresa y que el hito sea de ese pedido.
  - La regla "una vigente por KPI" queda **solo para metas sin pedido**.
  - La línea base es la que manda quien llama (Mantenimiento) o el valor de hoy en `kpi.cache` (KPIs de Tools).
  - La firma cambia, así que el script borra la vieja (`DROP FUNCTION`) para no dejar dos versiones.
- Función nueva **`kpi.objetivos_de_pedido(empr_id, petr_id)`**: las metas no canceladas del pedido y de sus hitos, con línea base, valor actual (solo de Tools) y si se cumple.
- **No cambian:** `kpi.objetivos_de()`, `kpi.desvios()`, `kpi.objetivo_cancelar()`, `kpi.publicar()` ni el cron.

### 3.2 DataService — `ToolsKPIDataService.dbs`

- `POST /objetivo` (`guardarObjetivo`): parámetros opcionales nuevos `petr_id`, `hito_id` y `linea_base`.
- Nuevo `GET /objetivos/pedido/{petr_id}/emprid/{empr_id}` (`getObjetivosPedido`).

### 3.3 PHP

- `application/models/Objetivos_model.php`:
  - `guardar()` manda los campos nuevos;
  - nuevos `dePedido()`, que completa el valor de Mantenimiento y calcula el avance, `avance()` y `kpisDisponibles()`.
- `traz-comp-bpm`, `Pedidotrabajo`: `metas/{petr_id}` (vista), `guardarMeta/{petr_id}` y `cancelarMeta/{petr_id}/{objetivo_id}`. Solo se pueden cancelar metas de ese pedido.
- Vista `pedidos_trabajo/metas_pedido.php`: el recuadro **"Metas del pedido"** de la pantalla de planificación (`Pedidotrabajo/dash`). Se carga al elegir un pedido.

### 3.4 Cómo se mide el avance

`avance = (valor de hoy − línea base) / (meta − línea base) × 100`

Funciona para metas que suben y que bajan. Ejemplo: partida 54 %, meta 70 %, hoy 62 % → avance 50 %. Si el indicador empeoró, el avance es negativo y la barra se pinta en rojo. Sin línea base o sin valor de hoy se muestra "Sin datos para medir".

> ⚠️ **Supuesto propio:** para la Disponibilidad, el "valor de hoy" es el mismo que muestra el Tablero, el **promedio de los meses que tiene AssetPlanner** (hasta 12). No es el valor del último mes, así que se mueve despacio. Si se quiere el último mes, hay que cambiar la consulta `getManKPI`, que también usa el Tablero.

## 4. Qué lo consume y qué se rompe si se toca

| Consumidor | Efecto |
|---|---|
| Tablero del administrador (`Objetivos`) | Graba igual. Su lista (`objetivos_de`) ahora **también muestra las metas de pedido**, sin indicar de qué pedido son. |
| Kuntur (`kpi_get_objetivos`, `kpi_get_desvios`) | Ve también las metas de pedido como metas de la empresa. Supuesto propio: es lo deseable, porque el plan del Coach es un pedido (ADR-A9). |
| Metas generales ya cargadas | Sin cambio: no tienen pedido y siguen bajo la regla de una vigente por KPI. |
| Una meta general nueva con una de pedido vigente para el mismo KPI | Antes del cambio no podía pasar, porque nadie cargaba metas de pedido. Ahora se permite. |

**Rollback:** `kpi_metas_pedido_hito.rollback.sql`. Vuelve la función a v2.8.1.6 y borra la nueva. Las metas de pedido ya cargadas quedan en la tabla.

**Orden de despliegue:**
1. Script de base.
2. CAR (DataService).
3. PHP: Tools más `traz-comp-bpm`.

Si el PHP llega antes que el CAR, el recuadro de metas sale vacío y no se puede grabar. El resto de la pantalla no se ve afectado.

## 5. Cómo se prueba

DocTest `TAR-CP-025-*` (`doctest/tests/e2e/specs/tar/TAR-UC-025.metas-de-pedido.spec.ts`):
- cargar una meta para todo el pedido y otra para un hito;
- ver la línea base, la meta y el estado;
- rechazar una fecha vencida o un valor no numérico;
- que otra empresa no vea las metas;
- cancelar una meta.
