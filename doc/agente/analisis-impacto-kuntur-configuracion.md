# Análisis de impacto — herramientas de configuración para Kuntur

## Objetivo

Qué es: el análisis de impacto que exige el `CLAUDE.md` antes de tocar el núcleo (APIs de WSO2 y servicios de datos), para darle a Kuntur las herramientas con las que carga la configuración inicial de una empresa (ADR-A12, etapa 2 de [`kuntur-entrevista-configuracion.md`](kuntur-entrevista-configuracion.md)). Para quién: el PM, que lo aprueba o lo corrige; sin su aprobación no se programa nada de esto. Cuándo leerlo: antes de aprobar la etapa 2. Qué NO cubre: el mecanismo de "Kuntur propone, el administrador toca Cargar" (ya está hecho y no toca el núcleo, ver `agente/cargas.py`) ni los menús y roles de Dnato v3, que van contra servicios simulados (§6).

| Campo | Valor |
|---|---|
| Fecha | 2026-11-11 |
| Tarea | AGENTE-CO-09 (carga inicial) |
| Estado | **Para aprobar** |
| Comparado contra | `origin/master` (producción) y `origin/develop-v3.5`, el 2026-11-11 |

---

## 1. Resumen en una línea por lote

| Lote | Qué | Toca el núcleo | Riesgo | Propuesta |
|---|---|---|---|---|
| 1 | Alta de establecimiento, depósito y valores de listas (unidades de medida, tipos de artículo, tipos de herramienta) | **Sí, solo se suman** recursos nuevos a la fachada MCP (`toolsMCPAPI.xml`). Los servicios de datos que llaman **no se modifican** | Bajo | Hacerlo ya |
| 2 | Carga de artículos y herramientas de a muchos (con la planilla del cliente) | **Sí: una función nueva** en la base (`sta.carga_masiva_filas`), que reutiliza los procedimientos de la carga masiva de Dnato sin cambiarlos | Medio | Hacerlo después del lote 1 |
| 3 | ABM de Mantenimiento: sectores, áreas, criticidades, grupos, marcas, familias | No por ahora: esos servicios **solo existen en la rama de la migración** de AssetPlanner a Mantenimiento (`feat/MIG-ASSET-2-informes`, otra sesión) | — | Esperar a que esa rama llegue a `develop-v3.5` |
| 4 | Menús, roles y administradores (Dnato v3) | No: servicios **simulados** dentro del motor de los agentes (decisión del PM, deuda técnica) | Bajo | Hacerlo ya |

---

## 2. Lote 1 — establecimiento, depósito y listas de valores

### 2.1 Qué cambia

Tres recursos nuevos en la fachada MCP (`_backend/api/.../apis/toolsMCPAPI.xml`), igual que los de lectura que ya hay. Cada uno toma la empresa **del token** (ADR-013), nunca de un parámetro, y llama a un recurso del servicio de datos que **ya existe y no se toca**:

| Herramienta nueva | Recurso MCP | Llama a (sin cambios) | Graba en |
|---|---|---|---|
| `core_alta_establecimiento` | `POST /mcp/core/establecimiento` | `COREDataService` `POST /establecimiento` (`setEstablecimiento`) | `prd.establecimientos` |
| `alm_alta_deposito` | `POST /mcp/alm/deposito` | `COREDataService` `POST /deposito/establecimiento` (`setDepositoPorEstablecimiento`) | `alm.alm_depositos` |
| `core_alta_valor` | `POST /mcp/core/valor` | `COREDataService` `POST /tablas` (`setTabla`) | `core.tablas` |

Detalles:

- `core_alta_valor` solo acepta tres listas: `unidades_medida`, `tipo_articulo` y `tipos_herramienta`. El nombre que se graba sigue la convención de la pantalla Lista de Valores (`<empr_id>-<lista>`, `application/models/core/Valores.php:97-107`), armado con el `empr_id` del token. Nunca graba en una lista global (`999999`).
- `alm_alta_deposito` exige un establecimiento **de la misma empresa**: antes de grabar, lee el establecimiento y verifica que sea suyo. El servicio de datos no lo controla.
- Los encargados del depósito **no entran en esta primera versión**: en la pantalla son una segunda llamada sin transacción y requieren usuarios ya creados.
- Las tres responden `200` con el id creado, no `202` (decisión del 2026-08-21: con `202` el cliente MCP descarta el cuerpo).

### 2.2 Comparación contra producción

- `COREDataService.dbs` es **idéntico en `master` y en `develop-v3.5`**. Las tres consultas (`setEstablecimiento`, `setDepositoPorEstablecimiento`, `setTabla`) son las que usan hoy las pantallas de producción.
- No se modifica ninguna: el cambio es **solo sumar** recursos a la fachada MCP.

### 2.3 Quién más usa lo que se toca

- **Los servicios de datos:** las pantallas `core/Establecimiento.php` (`guardarEstablecimiento`, `guardarDeposito`) y `core/Valor.php` (`guardarValor`). No cambian.
- **La fachada MCP:** hoy la usan Claude (conector) y los agentes. Los recursos nuevos no cambian los existentes. Ojo: sumar herramientas a un servidor MCP del gateway **obliga a recrear la API** en el Publisher (decisión del 2026-08-20). Es un paso del despliegue.

### 2.4 Qué se puede romper y cómo se evita

| Riesgo | Cómo se evita |
|---|---|
| Que un cliente MCP cualquiera (Claude, por ejemplo) graba con estas herramientas | Son de clase `configuracion`. El motor de los agentes **nunca las ejecuta sin confirmación** (ADR-A12). Para clientes externos, el gateway las expone solo a la aplicación de los agentes (suscripción aparte). *A verificar en el despliegue* |
| Que el token de máquina grabe | El MI ya rechaza las escrituras con token de máquina (commit `972d9a8d`). Se suma una prueba para estas tres |
| Grabar en otra empresa | La empresa sale del token; el depósito verifica el establecimiento |
| Valores repetidos en una lista | La pantalla tampoco lo impide. La herramienta lee la lista antes de grabar y, si el valor ya está, devuelve el existente sin grabar |

### 2.5 Cómo se prueba

- **Pruebas en mi máquina:** con el MI copia, desconectado de DEV, contra la base de prueba. El MI del PM no se toca.
- **Por cada herramienta:**
  - graba en la empresa del token;
  - rechaza el token de máquina;
  - rechaza un establecimiento de otra empresa;
  - no repite un valor de lista.
- **En el panel:** el circuito completo, desde la propuesta de Kuntur, pasando por "Cargar", hasta el dato en la pantalla de Tools.

### 2.6 Cómo se vuelve atrás

Sacar los tres recursos de `toolsMCPAPI.xml` y volver a desplegar el CAR. No hay cambios en la base.

---

## 3. Lote 2 — carga de muchas filas (artículos y herramientas)

### 3.1 El problema

La carga masiva de Dnato (`sta.ejecutar_carga_masiva(procedimiento, url_archivo, empr_id)`, en `traz-comp-dnato/scripts/sql/sta/`) lee un **archivo que tiene que estar en el servidor de la base** (`COPY`). Una herramienta MCP no puede dejar un archivo ahí.

### 3.2 La propuesta

- **Una función nueva:** `sta.carga_masiva_filas(procedimiento, filas jsonb, empr_id)`. Hace lo mismo que la actual, pero toma las filas como datos:
  1. las vuelca en la misma tabla temporal que usa hoy el `COPY`;
  2. llama al **mismo procedimiento** (`sta.bulkload_articulos`, `sta.bulkload_herramientas`);
  3. devuelve el mismo texto de resultado.
  
  Es todo o nada, igual que hoy.
- **Una herramienta:** `alm_carga_articulos` / `pan_carga_herramientas`, sobre un recurso nuevo de servicio de datos que llama a esa función.
- **La planilla del cliente:**
  - El orquestador la lee y le pasa al modelo **solo los encabezados y unas 20 filas** (decisión P-8 del PM).
  - El modelo devuelve qué columna del cliente corresponde a cada columna de la plantilla.
  - La transformación de todas las filas la hace **el código, no el modelo**, así que no puede inventar datos.
  - La tarjeta muestra las primeras 10 filas ya transformadas y el total.

### 3.3 Qué hay que confirmar antes (comparación contra producción)

- La función y los procedimientos `sta.*` son de **Dnato** y viven en la base de Tools. Hay que comparar contra lo desplegado en producción: el inventario solo los vio en el repo, y **las filas de `sta.entidades_negocio` dependen de cada ambiente**.
- La nueva versión de Dnato mantiene la carga masiva (entrega E11) y suma validaciones. La función nueva tiene que quedar dentro de ese diseño. **Hay que avisarle a ese frente.**

**Propuesta:** aprobar el lote 2 como dirección. El análisis detallado de la función nueva lo escribo cuando el lote 1 esté hecho.

---

## 4. Lote 3 — ABM de Mantenimiento

- **Sectores, áreas, criticidades, grupos (lo más cercano a "tipo de equipo"), marcas y familias** tienen servicio de datos (`MANDataService` `POST /abm/*`, `/area`). Graban en **MySQL de AssetPlanner** por `id_empresa` (`empr_id_mysql`).
- **Esos recursos solo existen en la rama de la migración** (`traz-tools-mig`, `feat/MIG-ASSET-2-informes`, 380 recursos). En `develop-v3.5` el servicio tiene 38 y ninguno de estos. La migración la lleva otra sesión y **no se toca** desde acá.
- **Propuesta:** cuando esa rama llegue a `develop-v3.5`, sumar las herramientas encima, con el mismo patrón del lote 1.
- **Riesgo a tener en cuenta:** si la empresa nueva no tiene `empr_id_mysql`, Mantenimiento no puede dar de alta nada. La puesta en marcha tiene que verificarlo primero.
- **Preventivos:** no se cargan el primer día (pedido del PM). Kuntur va a **proponer una tarea** del tipo "Generar los preventivos de estos equipos", como pedido de trabajo en estado propuesta (ADR-A9). Depende del módulo de Tareas.

---

## 5. Lo que queda afuera a propósito

- **Artículos y proveedores de a uno.** El alta de artículos de la pantalla **graba directo en la base sin servicio de datos** (`ALM/models/Articulos.php:72`), y la edición no filtra por empresa. No se expone como herramienta. Los artículos entran por el lote 2.
- **Equipos.** Hay dos tablas distintas (`core.equipos` en PostgreSQL y la de Mantenimiento en MySQL), con riesgo de duplicarlos. Se decide después de la migración.
- **Encargados de depósito y pañoles.** Requieren usuarios creados y varias llamadas sin transacción.

---

## 6. Lote 4 — Dnato v3 simulado (no toca el núcleo)

Por decisión del PM, hasta que la nueva versión de Dnato exista, Kuntur trabaja contra **servicios simulados** dentro del motor de los agentes:

| Herramienta | Qué simula |
|---|---|
| `dnato_get_funcionalidades` | Lo que el plan de la empresa permite y lo que está activo (RF-50 a 53) |
| `dnato_activar_funcionalidad` | Activar una funcionalidad del plan (CU-31) |
| `dnato_asignar_menu_rol` | Dar o quitar una opción del menú a uno de los 5 roles fijos (`seg.memberships_menues`, CU-40). El rol Administrador no se edita |
| `dnato_asignar_rol_usuario` | Dar un rol a un usuario de la empresa (CU-38) |
| `dnato_get_administradores` | Los administradores de la empresa, para avisarles a todos (no existe en el diseño de v3: se le pide a ese frente) |

- Lo que "graban" queda en tablas propias del esquema `agente`, marcadas como simulación, y la tarjeta lo dice.
- **Deuda técnica:** reemplazarlas por los servicios de datos reales de Dnato v3 cuando existan. Queda anotada en `STATE.md`.

---

## 7. Lo que necesito que apruebe el PM

| # | Qué | Propuesta |
|---|---|---|
| A-1 | Lote 1: las tres herramientas sobre servicios de datos existentes, sin modificarlos | Aprobar |
| A-2 | Lote 2: la dirección (función nueva `sta.carga_masiva_filas` que reutiliza los procedimientos de Dnato), con su análisis detallado más adelante | Aprobar la dirección |
| A-3 | Lote 3: esperar a la migración de Mantenimiento | Aprobar |
| A-4 | Lote 4: servicios simulados de Dnato v3, como deuda técnica | Aprobar |
