# Verificación de las queries MCP contra datos reales

## Objetivo

Registro de la verificación de que las **9 tools MCP devuelven datos completos, sin duplicados
y sin fugas entre empresas**, ejecutando las queries reales de los DataServices contra las bases
de desarrollo. Escrito para quien tenga que re-verificar esto tras un cambio en un `.dbs`, o
diagnosticar por qué una tool devuelve vacío o datos raros.

**No cubre** el despliegue de la fachada MCP ni la configuración de identidad — eso está en
[`doc/v3/deployment-gcp.md`](../v3/deployment-gcp.md) §6 y §7.

| | |
|---|---|
| **Fecha** | 2026-08-11 |
| **Ejecutado contra** | `tools_prod_t` @ `10.142.0.13:5432` (PostgreSQL 11.18) y `assetv2` @ `10.142.0.13:3306` (MariaDB 10.1.48) |
| **Scripts** | `scripts/dev/verify-mcp-queries.py`, `scripts/dev/verify-mcp-isolation.py` |
| **Resultado** | 23/23 completitud OK · 19/19 aislamiento OK · 18/18 en la pasada exhaustiva |
| **Confirmado en GCP** | 2026-08-11 — `alm_get_stock` devuelve datos reales desde Claude vía `mcp.cloudtrazalog.com` (Barra de acero 50.0, Barra de acero cortada 307.0, Eje 51.0) |

---

## 1. Antes de mirar las queries: contra qué base está apuntando el MI

**Es lo primero a descartar cuando una tool devuelve `{}` vacío**, y lo que más tiempo costó
diagnosticar: la query puede estar perfecta y aun así no devolver nada si corre contra la base
equivocada.

Los datasources viven **embebidos en el `.car`** (`src/main/wso2mi/artifacts/data-sources/`), así
que cada instancia necesita su propia copia del repo con las URLs de su ambiente. Verificar cuál
quedó realmente desplegada — no alcanza con mirar el XML del repo:

```bash
cd /tmp && cp /opt/wso2/wso2mi-4.5.0/repository/deployment/server/carbonapps/ToolsAPIProject_1.0.0.car tap.zip
unzip -o tap.zip >/dev/null
cat ToolsDataSource_1.0.0/ToolsDataSource-1.0.0.xml
cat AssetPlannerDataSource_1.0.0/AssetPlannerDataSource-1.0.0.xml
```

> **Ojo con el nombre de la base, no solo con el host.** En TEST conviven en el **mismo servidor y
> puerto** (`10.142.0.11:5434`) más de una base con esquema equivalente. Un datasource apuntando a
> la base equivocada del servidor correcto da exactamente el mismo síntoma que un host equivocado:
> HTTP 200 con la estructura vacía. Comparar el `<url>` completo contra la base donde realmente se
> ven los datos.

**Y las dos URLs para probar, que es fácil confundir:**

| URL | API | ¿JWT? | `empr_id` |
|---|---|---|---|
| `/tools/mcp/mcp/alm/stock` | `toolsMCPAPI` (fachada MCP) | **Sí** — sin él, `503 identity_missing` | Derivado del `X-JWT-Assertion` |
| `/tools/alm/stock/{empr_id}` | `toolsALMAPI` (orquestación) | No | **Explícito en la URL** |

El doble `/mcp/mcp` de la primera no es un error de tipeo: el contexto de la API es `/tools/mcp` y
sus resources están prefijados por módulo (`/mcp/man/…`, `/mcp/alm/…`) por decisión de ADR-013.

```bash
# 1) ¿está viva la fachada MCP?  -> 503 identity_missing es la respuesta CORRECTA sin JWT
curl -i http://localhost:8290/tools/mcp/mcp/alm/stock

# 2) ¿la cadena orquestación -> DataService -> base devuelve datos? (saltea identidad)
curl -s http://localhost:8290/tools/alm/stock/<empr_id-con-datos>
```

- (1) da `503` y (2) devuelve datos → la plomería está bien; si la tool igual falla, el problema
  está en la identidad (JWT, `empr_id` mal resuelto, `empr_id_mysql` en NULL).
- (2) devuelve vacío con un `empr_id` que **sabés** que tiene datos → base equivocada o query.
- **(2) responde `main sequence executed for call to non-existent`** en el log del MI → la API no
  está desplegada: el CAR se construyó incompleto o su deploy falló. Revisar
  `Successfully Deployed Carbon Application` / `Error occurred while deploying` en el log.

> **Nota sobre credenciales:** los datasources llevan usuario y contraseña en texto plano dentro
> del artefacto versionado (ya señalado en `deployment-gcp.md` §5). Sacarlos del `.car` — WSO2 MI
> soporta `[[datasource]]` en su `deployment.toml`, que además permitiría config por ambiente sin
> tocar el artefacto — es una mejora pendiente de decisión (🔴).

---

## 2. Set de datos de referencia (base de desarrollo)

Empresas con datos suficientes para probar cada tool:

### PostgreSQL — `tools_prod_t` (tools `alm_*`)

| `empr_id` | Empresa | Artículos activos | Lotes c/stock | Pedidos |
|---|---|---|---|---|
| **1** | Empresa_Test | 311 | 350 | 371 |
| 9 | descri232323 | 836 | 0 | 0 |
| 4 | Isola Asti | 640 | 0 | 0 |
| 777 | Yudica | 13 | 5 | 140 |
| 87 | SEADS | 7 | 30 | 1 |

**`empr_id = 1` es la mejor para pruebas end-to-end**: es la única con artículos, lotes con stock
y pedidos a la vez.

### MySQL/MariaDB — `assetv2` (tools `man_*`)

| `id_empresa` | Equipos activos | Solicitudes |
|---|---|---|
| **8** | 68 | 27 |
| 6 | 12 | 197 |
| 1 | 4 | 52 |
| 17 | 3 | 0 |
| 9 | 1 | 1 |

> Ojo: el `id_empresa` de `assetv2` **no** es el `empr_id` de PostgreSQL. La correspondencia la
> da `core.empresas.empr_id_mysql` (ver `deployment-gcp.md` §7.0-quinquies).

---

## 3. Bugs encontrados y corregidos

Los cuatro se detectaron comparando lo que devuelve cada query contra un conteo de control
independiente sobre la tabla base.

### 3.1 `alm_get_stock` sumaba stock de otras empresas 🔴

`getArticulos2` filtraba el artículo por empresa, pero unía los lotes **sin** filtrarlos:

```sql
LEFT JOIN alm.alm_lotes C ON C.arti_id = A.arti_id     -- ← sin condición de empresa
WHERE A.empr_id = cast(:empr_id as integer)
```

En desarrollo había 6 lotes cuyo `empr_id` no coincide con el del artículo, y eso inflaba el
stock reportado:

| Empresa | Artículo | Reportaba | Real | Ajeno |
|---|---|---|---|---|
| 87 | Residuos Organicos | 5982 | 2981 | **3001** |
| 1 | Prueba 5 MODIF | 181.5 | 38 | **143.5** |
| 87 | Residuos Urbanos | 1552 | 1551 | 1 |

**Fix:** `... ON C.arti_id = A.arti_id AND C.empr_id = A.empr_id`. No cambia el número de filas
devueltas, solo el valor de `stock`.

### 3.2 `man_get_equipos` ocultaba equipos con catálogos incompletos

`getEquipos` hacía `INNER JOIN` contra 6 catálogos descriptivos (marca, sector, grupo,
criticidad, área, proceso). Un equipo con cualquiera de esos IDs inválido **desaparecía del
inventario**.

En desarrollo, 2 equipos de la empresa 8 tienen `id_grupo` en `-1` y `0` (valores centinela que
no existen en `grupo`), y ambos están en estado **`RE` (en reparación)** — justo el caso de uso
que la descripción de la tool declara cubrir. 68 equipos reales, 66 devueltos.

**Fix:** los 6 catálogos pasan a `LEFT JOIN`. `empresas` queda como `INNER JOIN` (de ahí sale el
`empr_id`, y ningún equipo tiene empresa inválida). Mismo criterio aplicado a `getEquipoIsolated`
(`man_get_equipo`), que tenía el mismo patrón.

### 3.3 `man_get_ots` perdía y duplicaba solicitudes a la vez

Dos defectos que se compensaban parcialmente, por eso el total parecía casi correcto:

- **Perdía**: `INNER JOIN equipos` descartaba las solicitudes con `id_equipo = -1` (equipo
  borrado). En la empresa 6 eran 2, ambas en estado `S` (solicitado) — OTs abiertas invisibles.
- **Duplicaba**: `LEFT JOIN orden_trabajo ON sr.case_id = ot.case_id` asume 1:1, pero el modelo
  admite **varias OT por `case_id`** (`orden_trabajo.id_orden` es la PK). 3 solicitudes de la
  empresa 6 aparecían dos veces.

Neto: 197 reales → 198 devueltas.

**Fix:** `equipos`/`sector` pasan a `LEFT JOIN`, y la unión a `orden_trabajo` se desambigua
tomando la orden más reciente del caso:

```sql
LEFT JOIN orden_trabajo ot
       ON ot.case_id = sr.case_id
      AND ot.id_orden = (SELECT MAX(ot2.id_orden) FROM orden_trabajo ot2
                          WHERE ot2.case_id = sr.case_id)
```

(subconsulta correlacionada porque MariaDB 10.1 no tiene window functions)

### 3.4 `man_get_ot` devolvía la misma solicitud dos veces

`getSolicitudServicioById` tenía el mismo problema 1:N con `orden_trabajo`. Para la solicitud 75
devolvía 2 filas. Mismo fix.

---

## 4. Cómo re-verificar

```bash
export MCP_DB_HOST=10.142.0.13
export MCP_MYSQL_PASS='...'   # usuario rootremote de assetv2
export MCP_PG_PASS='...'      # usuario postgres de tools_prod_t

python3 scripts/dev/verify-mcp-queries.py     # completitud: filas devueltas vs control
python3 scripts/dev/verify-mcp-isolation.py   # aislamiento: ninguna fila de otra empresa
```

Los scripts **extraen el SQL directamente de los `.dbs`** y lo ejecutan, así que verifican el
código real del repo, no una copia. Devuelven exit code distinto de 0 si algo falla, o sea que
sirven para CI.

> **Al contar filas, no cuentes líneas de salida.** Los campos de texto pueden tener saltos de
> línea embebidos (la solicitud 121 de la empresa 6, por ejemplo) y eso infla el conteo. Los
> scripts envuelven cada query en `SELECT count(*) FROM (...) _c`. Un falso positivo por esto
> costó una vuelta entera de diagnóstico.

---

## 5. Resultado

**Completitud** — cada query devuelve exactamente las filas que existen en la tabla base:

```
man_get_equipos   empresas 8, 6, 1, 17, 9        OK (68, 12, 4, 3, 1)
man_get_ots       empresas 8, 6, 1, 17, 9        OK (27, 197, 52, 0, 1)
man_get_ot        solicitudes 75, 117, 127       OK (1 fila cada una)
man_get_equipo    equipos 2 y 3 (grupo roto)     OK (1 fila cada uno)
alm_get_stock     empresas 1, 87, 777, 9, 4      OK (311, 7, 13, 836, 640)
alm_get_pedidos   empresas 1, 777, 87            OK (371, 140, 1)
```

**Aislamiento (ADR-012)** — ninguna query devuelve filas de otra empresa, y el `stock` reportado
coincide exactamente con la suma de los lotes propios. Verificado además que pedir un recurso
ajeno por ID (equipo de la empresa 8 solicitado por la 6, solicitud de la 6 pedida por la 8)
devuelve 0 filas.

**Pasada exhaustiva** — no solo el set de muestra: se corrió cada query contra **todas** las
empresas que tienen datos, verificando completitud y ausencia de filas ajenas en cada una.

| Query | Empresas verificadas | Resultado |
|---|---|---|
| `getEquipos` | 1, 6, 8, 9, 17 | 5/5 OK |
| `getOTsByEmpresa` | 1, 6, 8, 9 | 4/4 OK |
| `getArticulos2` | 1, 2, 3, 4, 9, 87, 99, 181, 777 | 9/9 OK |

---

## 6. 🔴 Requiere decisión: solicitudes que apuntan a equipos de otra empresa

**Encontrado el 2026-08-11. No se corrigió — necesita una definición de negocio antes de tocar
nada.**

En `assetv2` hay **203 solicitudes de reparación cuyo equipo pertenece a otra empresa**:

| Empresa de la solicitud | Equipos de la empresa | Cantidad |
|---|---|---|
| 1 | 8 | 48 |
| 6 | 8 | 155 |

Como `man_get_ots` y `man_get_ot` unen `solicitud_reparacion` con `equipos` para traer el código,
sector y ubicación, **la empresa 6 termina viendo el código y la ubicación de 155 equipos de la
empresa 8**. Las queries filtran correctamente por `sr.id_empresa` (las solicitudes SÍ son
propias), pero los campos del equipo salen del registro ajeno.

**Por qué no se corrigió por cuenta propia:** hay dos lecturas posibles y llevan a soluciones
opuestas.

- **Si son datos sucios** (lo más probable dado que las 203 apuntan a la misma empresa 8, con
  aspecto de carga de prueba mal hecha): hay que limpiar los datos, y además blindar la query con
  `AND e.id_empresa = sr.id_empresa` en el join para que el aislamiento no dependa de la calidad
  del dato.
- **Si es un caso de negocio legítimo** — una empresa de servicios haciendo mantenimiento sobre
  equipos de un cliente, que es exactamente el modelo de los proveedores mineros al que apunta
  v3 — entonces la query está bien y lo que falta es modelar esa relación explícitamente.

Blindar el join sin resolver esa pregunta haría desaparecer el equipo de 203 OTs que hoy se ven,
en ambas lecturas por el motivo equivocado.

**Riesgo asociado, independiente de la respuesta:** `man_create_ot` **no valida que el
`equipo_id` recibido pertenezca a la empresa del JWT**. Toma el valor del payload del agente y lo
inserta con el `id_empresa` del token, sin chequeo previo (`toolsMCPAPI.xml`, resource
`POST /mcp/man/ot`). Un agente puede crear una OT sobre un equipo ajeno y disparar el proceso BPM
correspondiente. `toolsMANAPI` sí tiene el patrón de validación (`getEquipoIsolated`), pero la
fachada MCP no lo aplica antes del INSERT.

Además, el paso 2 de ese flujo usa:

```sql
select max(sr.id_solicitud) sose_id, sr.id_equipo equiid
  from solicitud_reparacion sr where sr.id_equipo = :equi_id
```

que **no filtra por empresa** y recupera el ID con un `max()` — susceptible a race condition si
dos altas concurrentes tocan el mismo equipo. El patrón correcto sería que el INSERT devuelva la
clave generada (`returnGeneratedKeys="true"`, ya usado en `setEmpresa` del mismo DataService) en
vez de releerla después.

No se tocó ninguna de las dos cosas porque `man_create_ot` es la única tool de escritura: probarla
crea registros reales e instancia procesos en Bonita.

---

## 7. Lo que queda pendiente

- **`alm_crear_pedido_materiales` no se verificó**: es la única tool de escritura y probarla
  crea registros reales + instancia un proceso en Bonita. Requiere decidir contra qué ambiente
  se prueba y cómo se limpia después.
- **16 queries de `ALMDataService` que usa el PHP de v2** tienen el mismo patrón de join a
  `alm_lotes` sin filtro de empresa que el bug 3.1 (`getArticulos`, `getArticulo`,
  `getArticulosXTipo`, `getStock`, `getStockValorizado`, …). **No se tocaron** porque están fuera
  del alcance MCP y no se pueden probar sin la app v2. Vale la pena revisarlas: si el dato de
  stock que muestra v2 sale de esas queries, tiene el mismo sesgo.
- **`ALMDataService.dbs` tiene dos resources con el mismo path** `/articulos/{empr_id}` (líneas
  569 → `getArticulos` y 633 → `getArticulos2`), con wrappers JSON distintos (`articulos` vs
  `materias`). Hoy gana el segundo, que es el que `toolsALMAPI` espera — pero depende de cuál
  resuelve primero el DSS. Conviene eliminar el duplicado; no se hizo porque `getArticulos`
  podría estar en uso por v2.
