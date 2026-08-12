# Casos de uso de operación minera y gaps de tools

## Objetivo

Qué le va a preguntar a Claude un jefe de mantenimiento o de almacén de una empresa de servicios
mineros, según buenas prácticas de gestión de activos e inventarios; cuáles de esas preguntas se
pueden responder **hoy** con las tools existentes; y qué falta para cubrir el resto.

Escrito para decidir qué tools construir a continuación y en qué orden. Es el análisis previo a
implementar — no la documentación de lo ya construido, que está en
[`escenarios-de-uso-y-regresion.md`](escenarios-de-uso-y-regresion.md).

| | |
|---|---|
| **Fecha** | 2026-08-11 |
| **Relevado contra** | `assetv2` (mantenimiento) y `tools_prod_t` (almacenes), base de desarrollo |
| **Resultado** | 15 casos · 5 cubiertos · 10 con gap · 4 tools nuevas propuestas |

> **Sobre los datos de prueba:** la base de desarrollo tiene datos **agrícolas y de laboratorio**
> (ajo, insumos enológicos, artículos "test"), no mineros. Los casos de abajo son válidos
> funcionalmente y la mecánica se puede verificar, pero los ejemplos con nombres de insumos
> mineros son ilustrativos. Los equipos sí incluyen maquinaria real (generador eléctrico,
> autoelevador, equipo de corte, turbina) y las tareas preventivas son textualmente de
> maquinaria pesada.

---

## 1. Lo que el modelo de datos sí soporta

Relevamiento previo, porque los casos solo valen si hay datos detrás.

### Mantenimiento (`assetv2`)

| Concepto | Tabla | Contenido real |
|---|---|---|
| Plan preventivo | `preventivo` | 130 planes: equipo, tarea, componente, periodicidad, intervalo, última ejecución |
| Periodicidad | `periodo` | Diario · Semanal · Mensual · Semestral · Anual · **Horas · Kilómetros · Ciclos** (por empresa) |
| Uso del equipo | `historial_lecturas` | 534 lecturas de horómetro/km con fecha, operario y turno |
| Criticidad | `criticidad` | Muy Alta (8 equipos) · Alta (39) · Media (15) · Baja (20) |
| Correctivo | `solicitud_reparacion` + `orden_trabajo` | 279 solicitudes, 956 OTs |

Las tareas preventivas cargadas son de maquinaria pesada real:

> *"Cambiar Aceite de Diferencial Delantero y Trasero (cada 1000 hs según horómetro, utilizar
> aceite SAE50)"* · *"Cambie el Aceite de Motor (15W40)"* · *"Apriete los Tornillos de los
> Pasadores de Expansión de los Cilindros"*

### Almacenes (`tools_prod_t`)

| Concepto | Dónde | Contenido |
|---|---|---|
| Tipo de artículo | `core.tablas` (`tipo_articulo`) | Insumo · Materia Prima · Producto · En Proceso · Final · Scrap |
| Stock por depósito | `alm_lotes.depo_id` | ej. Playa 31 art. · Zaranda 18 · Productivo 19 |
| Punto de pedido | `alm_articulos.punto_pedido` | cargado en parte del catálogo |
| Vencimiento | `alm_lotes.fec_vencimiento` | 58 lotes vencidos con stock en la empresa 1 |
| Consumo | `alm.movimientos` | vía `getHistoricoMovimientos` |

### Decisiones tomadas con el PM (2026-08-11)

1. **Estado del preventivo**: se usa `estadoprev` tal como está en la base, sin recalcularlo.
2. **Lectura actual del equipo**: se lee de `historial_lecturas` (la más reciente por fecha).
   `equipos.ultima_lectura` está en `0` para 7 de 8 equipos con preventivo activo, así que no
   sirve como fuente.
3. **Artículos críticos**: no se agrega ningún campo al modelo. **Claude aporta el conocimiento
   de dominio** — releva qué insumos son clave para una operación minera y después le pregunta a
   Trazalog por esos. Las tools solo tienen que permitir **buscarlos**.

---

## 2. Casos de mantenimiento

### M1 · ¿Qué equipos no tienen plan de mantenimiento preventivo?

> «¿Qué equipos no tienen ningún preventivo cargado?»

Es la pregunta de cobertura del plan: el primer indicador de madurez de una gestión de activos.

**Datos:** ✅ `equipos` LEFT JOIN `preventivo`.
**Hoy:** ❌ `man_get_equipos` no dice nada de preventivos.
**Verificado:** en la empresa 8, **60 de 68 equipos activos no tienen plan**.

---

### M2 · ¿Qué preventivos están vencidos o por vencer?

> «¿Qué mantenimientos tengo vencidos?» · «¿Cuáles vencen este mes?»

**Datos:** ✅ `preventivo.estadoprev` + `periodo` + `cantidad` + última lectura.
**Hoy:** ❌ ninguna tool expone la tabla `preventivo`.

---

### M3 · ¿Cuáles de esos son en equipos críticos?

> «De los equipos sin preventivo, ¿cuáles son los críticos?»

Priorización por criticidad — la base de cualquier plan de mantenimiento serio.

**Datos:** ✅ `criticidad` ya está poblada.
**Hoy:** ⚠️ parcial. `man_get_equipo` (detalle) devuelve criticidad, pero `man_get_equipos`
(listado) **no**, así que el agente tendría que pedir el detalle de cada equipo uno por uno.
**Verificado:** de los 60 sin plan, **31 son criticidad Alta y 6 Muy Alta**.

---

### M4 · ¿A qué equipos no se les está tomando la lectura?

> «¿Qué equipos no tienen lectura de horómetro hace más de 3 meses?»

Sin lectura no hay forma de saber si un preventivo por horas venció. Es un control de proceso
sobre el propio plan.

**Datos:** ✅ `historial_lecturas` con fecha.
**Hoy:** ❌ no hay tool de lecturas.
**Verificado:** 47 de 68 equipos de la empresa 8 sin lectura en 90 días.

---

### M5 · ¿Qué órdenes de trabajo llevan más tiempo abiertas?

> «¿Qué OTs tengo abiertas hace más de una semana?»

Backlog por antigüedad.

**Datos:** ✅ `f_solicitado` viene en la respuesta.
**Hoy:** ✅ **cubierto** — `man_get_ots` trae fecha y estado; el agente ordena y filtra.

---

### M6 · ¿Qué equipos fallan más seguido?

> «¿Qué equipo me dio más problemas este año?»

Candidatos a análisis de causa raíz o reemplazo.

**Datos:** ✅ solicitudes agrupadas por equipo.
**Hoy:** ✅ **cubierto** — `man_get_ots` trae `id_equipo` y `equipo`; el agente agrupa y cuenta.

---

### M7 · ¿Cuánto de mi mantenimiento es correctivo vs preventivo?

> «¿Estoy apagando incendios o previniendo?»

Indicador clásico de madurez (la meta habitual es ≥70% preventivo).

**Datos:** ⚠️ parcial. `orden_trabajo.tipo` tiene 5 valores (3:684, 2:130, 1:104, 10:28, 4:20)
pero **no encontré el catálogo que los traduce**. Sin eso no se puede clasificar.
**Hoy:** ❌ — y además requiere confirmar la semántica de `tipo` (pendiente con el PM).

---

## 3. Casos de inventario

### I1 · ¿Qué artículos están por debajo del punto de pedido?

> «¿Qué tengo que reponer?»

**Hoy:** ✅ **cubierto** — `alm_get_stock` devuelve `stock` y `punto_pedido`; el agente compara.
Es el escenario E1 de la suite de regresión.

---

### I2 · ¿Cuánto stock de tal tipo de artículo tengo en tal depósito?

> «¿Cuántos insumos tengo en el depósito de Zaranda?»

Caso operativo cotidiano: el stock total no sirve si el material está en otra faena.

**Datos:** ✅ `alm_lotes` tiene `depo_id`; existe la query `getStockXArticuloYDeposito`.
**Hoy:** ❌ `alm_get_stock` **agrega el stock de todos los depósitos** y no devuelve el desglose.
**Verificado:** el desglose por tipo × depósito da resultados coherentes (Zaranda/Materia Prima
5010 · Productivo/Insumo 3799 · Playa/Producto 3791).

---

### I3 · ¿Tengo stock de los insumos clave para la operación?

> «¿Tengo filtros de aire y aceite hidráulico para los equipos de la faena?»

**Este es el caso donde Claude aporta el conocimiento de dominio**: releva qué insumos son
críticos para una operación minera (filtros, lubricantes, correas, rodamientos, elementos de
desgaste) y después consulta el stock de esos.

**Datos:** ✅ `descripcion` de los artículos.
**Hoy:** ⚠️ parcial. `alm_get_stock` trae el catálogo completo (311 artículos en la empresa de
prueba) y el agente filtra por texto. Funciona, pero **no escala**: con catálogos de miles de
artículos se desperdicia contexto y se corre riesgo de truncamiento.

---

### I4 · ¿Qué lotes están por vencer?

> «¿Qué se me vence este mes?»

Aplica a lubricantes, adhesivos, reactivos y elementos con vida útil.

**Datos:** ✅ `alm_lotes.fec_vencimiento`; **la query `getLotesVencimientos` ya existe** y
clasifica en Crítico/Advertencia.
**Hoy:** ❌ no está expuesta como tool.
**Verificado:** 58 lotes vencidos con stock en la empresa 1.

---

### I5 · ¿Cuánto consumimos de este artículo?

> «¿Cuántos filtros usamos el mes pasado?»

Base para dimensionar el punto de pedido y detectar consumos anómalos.

**Datos:** ✅ **`getHistoricoMovimientos` ya existe**.
**Hoy:** ❌ no está expuesta.

---

### I6 · ¿Qué stock está inmovilizado?

> «¿Qué tengo en el depósito que no se mueve hace un año?»

Capital inmovilizado — típico hallazgo de auditoría de inventarios.

**Datos:** ✅ derivable de movimientos + stock.
**Hoy:** ❌ depende de I5.

---

## 4. Casos cruzados (mantenimiento + almacenes)

Son los de mayor valor: **ninguna pantalla de la app v2 los resuelve hoy**, porque cruzan dos
módulos.

### C1 · ¿Tengo los repuestos para los preventivos que vencen?

> «Los mantenimientos que vencen este mes, ¿tengo con qué hacerlos?»

Encadena `man_get_preventivos` (M2) → interpretación de la tarea → `alm_get_stock` (I3) →
`alm_crear_pedido_materiales`.

**Hoy:** ❌ bloqueado por M2.

**Es el caso que mejor justifica la capa MCP**: requiere leer la tarea preventiva en lenguaje
natural (*"cambiar aceite de motor 15W40"*), inferir qué insumo necesita, y buscarlo en el
catálogo. Ninguna consulta SQL hace eso.

---

### C2 · Equipo en falla → repuestos → pedido

> «Se rompió la bomba, abrí la OT y pedí lo que haga falta»

**Hoy:** ✅ **cubierto** — escenarios E2 + E1 de la suite.

---

## 5. Resumen de cobertura

| Caso | Área | Estado |
|---|---|---|
| M5 · OTs por antigüedad | Mantenimiento | ✅ cubierto |
| M6 · Equipos que más fallan | Mantenimiento | ✅ cubierto |
| I1 · Bajo punto de pedido | Almacenes | ✅ cubierto |
| C2 · Falla → OT → pedido | Cruzado | ✅ cubierto |
| M3 · Priorizar por criticidad | Mantenimiento | ⚠️ parcial (falta criticidad en el listado) |
| I3 · Insumos clave por nombre | Almacenes | ⚠️ parcial (no escala) |
| **M1 · Equipos sin preventivo** | Mantenimiento | ❌ gap |
| **M2 · Preventivos vencidos** | Mantenimiento | ❌ gap |
| **M4 · Equipos sin lecturas** | Mantenimiento | ❌ gap |
| **I2 · Stock por depósito** | Almacenes | ❌ gap |
| **I4 · Lotes por vencer** | Almacenes | ❌ gap |
| **I5 · Consumo histórico** | Almacenes | ❌ gap |
| I6 · Stock inmovilizado | Almacenes | ❌ gap (depende de I5) |
| **C1 · Repuestos para preventivos** | Cruzado | ❌ gap (depende de M2) |
| M7 · Correctivo vs preventivo | Mantenimiento | ❌ falta semántica de `orden_trabajo.tipo` |

---

## 6. Tools propuestas, en orden de valor

### 1. `man_get_preventivos` — habilita M1, M2, M3 y desbloquea C1

La de mayor impacto: **es el único gap que no tiene ninguna query previa** — no existe ni un
DataService que toque la tabla `preventivo`. Todo lo demás se apoya en algo ya construido.

Devuelve, por equipo: tarea, componente, periodicidad, intervalo, última ejecución, estado
(`estadoprev` tal cual, según lo decidido) y **la lectura actual desde `historial_lecturas`**.
Con un parámetro para traer solo los que no tienen plan (M1).

### 2. Enriquecer `alm_get_stock` con desglose y filtros — habilita I2 y I3

En vez de una tool nueva, agregar parámetros opcionales a la existente:
`?depo_id=` (desglose por depósito), `?tipo=`, `?buscar=` (texto sobre la descripción).
Reutiliza `getStockXArticuloYDeposito` y `getArticulosXTipo`, que ya existen.

> Cambiar una tool existente tiene menos costo para el agente que sumar una nueva: menos tools
> que elegir, misma semántica. Hay que verificar que los parámetros nuevos sean **opcionales**
> para no romper las llamadas actuales ni la suite de regresión.

### 3. `alm_get_vencimientos` — habilita I4

Envuelve `getLotesVencimientos`, que ya existe y ya clasifica Crítico/Advertencia.

### 4. `man_get_lecturas` — habilita M4

Historial de lecturas de un equipo, y detección de los que no reportan hace N días.

### Fuera de alcance por ahora

- **I5/I6 (consumo e inmovilizado)**: `getHistoricoMovimientos` existe, pero hay que confirmar
  qué registra exactamente antes de exponerlo.
- **M7 (correctivo vs preventivo)**: bloqueado hasta saber qué significan los valores de
  `orden_trabajo.tipo`.

---

## 7. Pendientes de confirmar con el PM

1. **`orden_trabajo.tipo`** — 5 valores (1, 2, 3, 4, 10) sin catálogo encontrado. Sin la
   semántica no se puede calcular el ratio correctivo/preventivo (M7), que es el indicador que
   más suele pedir una gerencia.
2. **`getHistoricoMovimientos`** — confirmar si registra todos los movimientos (entradas,
   salidas, ajustes, transferencias) o solo algunos, antes de exponerlo para I5.
3. **Estados `CE`, `PL`, `AS`, `M` de `estadoprev`** — se van a devolver tal cual, pero conviene
   documentar qué significan para que el agente los pueda explicar al usuario en vez de mostrar
   la sigla.
