# Esquema de base de datos de los agentes de IA de Trazalog

## Objetivo

Acá viven **todos los scripts SQL de los agentes de IA de Trazalog**, versionados, numerados e idempotentes, cada uno con su rollback. Este README explica en qué orden se aplican, cómo verificar que quedaron bien y qué decisiones de diseño hay detrás. Está escrito para que cualquiera pueda montar el esquema desde cero sin conocer el historial del proyecto.

**Qué NO cubre:** no explica la arquitectura del agente (eso está en `doc/v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md`) ni cómo instalar los componentes de infraestructura como el Streaming Integrator (eso está en `doc/agente/instalacion.md`).

---

## Requisitos

| Requisito | Detalle |
|---|---|
| **PostgreSQL 13 o superior** | Recomendado 16. Los scripts usan particionado declarativo, RLS y `gen_random_uuid()` de `pgcrypto`. |
| **pgvector 0.5.0 o superior** | Necesario para el índice **HNSW**. En Debian/Ubuntu: `sudo apt install postgresql-16-pgvector`. La extensión se crea en `001`, pero el paquete tiene que estar instalado en el servidor primero — eso requiere acceso root a la máquina de la base, no se resuelve por SQL. |
| **Un rol propietario** | Los scripts se ejecutan con un rol que pueda crear esquemas y extensiones (típicamente `postgres`). |

Para verificar que pgvector está disponible **antes** de empezar:

```
psql -h <host> -U <usuario> -d <base> -c "SELECT name, default_version FROM pg_available_extensions WHERE name = 'vector';"
```

Si no devuelve ninguna fila, falta instalar el paquete en el servidor.

---

## Orden de aplicación

Los scripts se aplican **en orden numérico** y todos son idempotentes: correrlos dos veces no rompe nada ni duplica datos.

| # | Script | Qué crea |
|---|---|---|
| 001 | `001-extensiones.sql` | Extensiones `vector` y `pgcrypto`, esquema `agente`, y los roles `agente_app` / `agente_curador` |
| 002 | `002-conocimiento-compartido.sql` | `fuente` y `chunk` — la base de conocimiento de la industria compartida entre clientes |
| 003 | `003-memoria-cliente.sql` | `memoria`, particionada por `empr_id`, con RLS y la función para dar de alta una empresa |
| 004 | `004-cola-candidatos.sql` | `candidato` — la cola de conocimiento propuesto que espera curaduría humana |
| 005 | `005-feedback.sql` | `interaccion` y `feedback` — el registro de cada consulta y su calificación |
| 006 | `006-entrevistador.sql` | `tema`, `sesion_entrevista`, `hecho` y `validacion_cruzada` — la captura de conocimiento experto |
| 007 | `007-notificaciones.sql` | `dispositivo`, `notificacion` y `envio` — el puente de alertas de la Opción C |
| 008 | `008-destinatarios-alerta.sql` | `destinatario_alerta` — quién recibe cada tipo de alerta, configurable por empresa |
| 009 | `009-alcance-almacenes.sql` | Tipos de alerta de Almacenes y columna `modulo` en el conocimiento |
| 010 | `010-seed-taxonomia.sql` | Taxonomía inicial de temas del entrevistador (propuesta para que el PM la corrija) |
| 011 | `011-agentes.sql` | `agente` — la configuración de Kuntur, Quirqui y Faustino (ADR-A7): quién lo usa, prompt, tools permitidas, disparadores, fuentes y avatar. Global, igual para todos los clientes; el runtime solo la lee |
| 012 | `012-tools.sql` | `tool` — el catálogo de las tools del MCP Gateway con su clase (lectura / generación / acción), y `tools_permitidas(clave)`: lo que cada agente puede usar de verdad (ADR-A8) |
| 013 | `013-corrida.sql` | Corrida auditable (R8): columnas `agente`, `disparador`, `costo_usd`, `controles`, `incidentes` en `interaccion`; tabla `tool_llamada` con lo que vio el modelo de cada tool; y **RLS** en `interaccion`, `feedback` y `tool_llamada` |
| 014 | `014-tool-web.sql` | Cataloga `web_buscar` (búsqueda en internet sobre SearXNG): `lectura`, costo `externo`, riesgo `medio` |
| 015 | `015-fuentes-producto.sql` | Tipos de fuente `ayuda` y `caso_uso`, e índice GIN sobre `chunk.metadata` (encontrar el caso de uso de una pantalla por su controlador) |
| 016 | `016-vertical.sql` | Multi-vertical (ADR-A11): `vertical` en `chunk` y `tema`, y la tabla `perfil_empresa` con la industria de cada empresa (RLS, el runtime solo lee) |
| 017 | `017-propuestas.sql` | `propuesta` — el siguiente paso que Quirqui le propuso a cada usuario y qué hizo con él (vista o descartada), con RLS (AGENTE-AS-02) |
| 018 | `018-avisos.sql` | Avisos proactivos (AS-03): `credencial_empresa` (cliente de máquina de cada empresa, secreto **cifrado** con pgcrypto, la clave fuera de la base), `empresas_con_credencial()`, el usuario por **nick** en notificaciones, destinatarios y dispositivos, y el tipo `certificacion_por_vencer`. **Re-aplicar `008` o `009` sueltos después de `018` saca el tipo nuevo: volver a aplicar `018`** |

Aplicación completa, desde el directorio del repo:

```
for f in db/agente/0*.sql; do echo "--- $f"; psql -h <host> -U <usuario> -d <base> -v ON_ERROR_STOP=1 -f "$f" || break; done
```

### Verificación

```
psql -h <host> -U <usuario> -d <base> -v ON_ERROR_STOP=1 -f db/agente/tests/test-estructura.sql
```

Imprime una línea por control con `OK` o `FALLA` y termina con un resumen. Si algo falla, el script sale con código distinto de cero.

El aislamiento multi-tenant tiene su propio test, que es el que **no puede fallar nunca**:

```
psql -h <host> -U <usuario> -d <base> -v ON_ERROR_STOP=1 -f db/agente/tests/test-aislamiento.sql
```

### Rollback

Cada script tiene su `NNN-*.rollback.sql`. Se aplican **en orden inverso** (007 → 001):

```
for f in $(ls -r db/agente/0*.rollback.sql); do echo "--- $f"; psql -h <host> -U <usuario> -d <base> -v ON_ERROR_STOP=1 -f "$f" || break; done
```

⚠️ El rollback de `001` borra los roles `agente_app` y `agente_curador`, que son **objetos del cluster, no de la base**: si otra base del mismo servidor los usa, se ve afectada. El script lo contempla y no falla si los roles tienen dependencias, pero conviene saberlo.

⚠️ El rollback de `002`, `003` y `006` **borra conocimiento**: los chunks ingestados, la memoria de cada cliente y los hechos capturados a expertos. No es una operación de rutina.

---

## ⚠️ El orquestador NUNCA se conecta como superusuario

Es la advertencia más importante de este README, así que va primero.

**Un superusuario de PostgreSQL se saltea Row Level Security siempre**, incluso con `FORCE ROW LEVEL SECURITY` activo — `FORCE` alcanza al propietario de la tabla, no a los superusuarios ni a los roles con `BYPASSRLS`. Si el orquestador se conecta como `postgres`, o como el rol dueño del esquema, **el aislamiento multi-tenant es decorativo**: las policies están, se ven en el catálogo, y no filtran nada.

Por eso:

- El usuario de base del orquestador se crea por ambiente y recibe el rol **`agente_app`**, nunca superusuario.
- Los scripts `001..007` sí se aplican con un rol privilegiado — pero eso es el despliegue, no el runtime.
- `tests/test-aislamiento.sql` hace `SET ROLE agente_app` antes de sus controles justamente por esto, y verifica de forma explícita que el rol con el que corre no sea superusuario. Sin esa precaución el test daría **falso verde**: fue el primer resultado que dio al escribirlo.

Crear el usuario de una instalación (ajustando nombre y contraseña por ambiente, y sin commitear la contraseña):

```
CREATE ROLE agente_orq LOGIN PASSWORD '<...>';
GRANT agente_app TO agente_orq;
```

---

## Decisiones de diseño

### Dimensión de los embeddings: 1024

Las columnas `embedding` son `vector(1024)`, que corresponde a **`cohere/embed-multilingual-v3.0` vía OpenRouter** — buen rendimiento en español técnico y costo bajo. El modelo concreto se configura por variable de entorno en el orquestador (ADR-A1: nunca hardcodeado), **pero la dimensión sí vive en el DDL**, porque en pgvector es parte del tipo de la columna.

Si se cambia a un modelo con otra dimensión (por ejemplo `openai/text-embedding-3-small`, que son 1536), hay que:

1. Alterar el tipo de las columnas `embedding` en `chunk`, `memoria`, `candidato` y `hecho`.
2. Recrear los índices HNSW.
3. **Re-generar todos los embeddings existentes** — los vectores viejos no son comparables con los nuevos.

Ese último punto es inherente a cualquier RAG: cambiar de modelo de embeddings obliga a re-ingestar. Conviene decidir el modelo antes de cargar volumen.

### Por qué la memoria está particionada por `empr_id`

El aislamiento multi-tenant es innegociable, así que hay **dos barreras independientes**:

1. **Partición declarativa por LIST sobre `empr_id`.** Cada empresa vive en su propia partición física. Una consulta con `WHERE empr_id = N` solo toca esa partición, y una empresa sin partición creada no puede recibir filas.
2. **Row Level Security.** Sobre la tabla padre, con una policy que compara contra `current_setting('agente.empr_id')`. Aunque una consulta se olvide del `WHERE`, el motor filtra igual.

La segunda barrera es la que importa: protege del error humano, que es de donde salen las fugas de datos entre clientes. `test-aislamiento.sql` verifica que un `empr_id` no puede leer la memoria de otro **ni siquiera con un `SELECT *` sin filtro**.

Para dar de alta una empresa hay que crear su partición:

```
psql -h <host> -U <usuario> -d <base> -c "SELECT agente.crear_particion_empresa(42);"
```

Es idempotente: si la partición ya existe, no hace nada.

### Por qué el conocimiento compartido es de solo lectura para el agente (ADR-A4)

`chunk` es la base de conocimiento de la industria curado — el activo del producto. El flujo de consulta **nunca escribe ahí**: el rol `agente_app` tiene `SELECT` y nada más. Lo que el agente aprende de un cliente va a `memoria` (privada de esa empresa) y, si un patrón se repite, se propone en `candidato`. Solo el rol `agente_curador` puede promover un candidato a `chunk`.

Es una barrera a nivel de permisos de base, no una convención de código: si mañana un bug del orquestador intenta escribir en `chunk`, la base lo rechaza.

### Por qué `notificacion` y `envio` están separadas

Viene del análisis de E0 (`doc/agente/analisis-alertas-assetplanner.md` §6.3). El mecanismo de AssetPlanner mete el token FCM del dispositivo dentro del mismo JSON que después lee la campanita, y solo notifica a un dispositivo por usuario (`LIMIT 1` sobre los tokens). Acá:

- `notificacion` es **lo que la persona lee** — sin token, sin datos de transporte.
- `envio` es **una fila por dispositivo activo del destinatario**, con el token y el estado del envío. Es la tabla que el Streaming Integrator poletea.

Además, `envio.envio_id` es la columna de polling del CDC: monótona creciente, sin saltos hacia atrás, que es lo que el `@source(type='cdc', mode='polling')` necesita para no perder filas.

### `estado` en `envio` distingue el fallo del éxito

En AssetPlanner el flag es binario (`procesado` 0/1) y el Siddhi lo pone en 1 con cualquier respuesta 2xx. Como el conector Firebase **devuelve 202 aunque el envío falle** (hallazgo verificado, R4 del análisis de E0), un fallo se registra como éxito y la notificación se pierde en silencio. Por eso `envio.estado` tiene cuatro valores (`pendiente`, `enviado`, `fallido`, `descartado`), lleva `intentos` y `ultimo_error`, y `fec_envio` se escribe de verdad — a diferencia del `fec_realizado` de AssetPlanner, que está declarado y nunca se usa.

### Por qué los destinatarios se configuran en el agente y no se heredan

Decisión del PM del 2026-09-02, después de mirar qué roles existen realmente:

- **Dnato**, que es la identidad de Tools, tiene solo `admin` y `user`, y sin empresa. Le llegaría todo al administrador sin importar si es quien decide sobre mantenimiento.
- **AssetPlanner** (`assetv2.sisgroups`) sí tiene roles ricos y por empresa — Administrador, Mantenedor, Planificador, Supervisor de Taller —, pero tiene login propio sin Dnato: no existe un mapeo usuario de Tools ↔ usuario de AssetPlanner, y su esquema está congelado y va a migrar a `traz-tools-man`.

Así que `agente.destinatario_alerta` guarda, por empresa y tipo de alerta, qué usuarios de Tools la reciben, con una `etiqueta` legible ("Jefe de mantenimiento") que sirve para auditar por qué le llegó. La carga inicial de cada cliente se puede sembrar mirando sus roles de AssetPlanner, pero eso es un dato, no una dependencia.

Los tipos cubren **las dos áreas del agente**: mantenimiento (`mtbf_deterioro`, `ot_critica_atrasada`) y almacenes (`stock_critico`, `material_por_vencer`, `pedido_demorado`), más los transversales. Quien recibe un aviso de MTBF en deterioro no es necesariamente quien tiene que enterarse de que un material está por vencer.

`agente.destinatarios_de(empr_id, tipo)` resuelve la lista, sumando los configurados con `'*'`. Si no hay nadie configurado devuelve vacío: el hallazgo **se registra igual** en la memoria del cliente, pero no se notifica — silencio, en vez de un aviso a alguien al azar.

El `rol_destino` de `agente.notificacion` queda como dato informativo (se copia de la etiqueta), no como mecanismo de resolución.

### Por qué la configuración de los agentes no lleva `empr_id` (011)

Los agentes son iguales para todos los clientes (decisión del PM, 2026-10-27): nombre, avatar, prompt y tools los define Trazalog. Por eso `agente.agente` no tiene RLS, y `agente_app` solo tiene `SELECT`: un bug del orquestador no puede, por ejemplo, abrirle el Coach a cualquier usuario. Dos reglas quedan como `CHECK` y no como convención: el Coach exige acceso `admin` (R1) y la autonomía solo puede ser `proponer` (R5). Para cambiar un agente se edita `011-agentes.sql` y se vuelve a aplicar: el seed actualiza por `clave`.

### Por qué hay un catálogo de tools y no alcanza con los patrones (012)

Los patrones de `agente.tools_permitidas` (`man_get_*`) dicen qué *familias* de tools quiere cada agente, pero no saben si una tool escribe. Por eso una tool es usable solo si **está catalogada en `agente.tool`, no es de clase `accion` y entra en un patrón**. Dos consecuencias buscadas:

- **Falla cerrado:** una tool nueva del gateway no la ve ningún agente hasta que alguien la catalogue y decida su clase, aunque entre en `man_get_*`.
- **Un patrón demasiado amplio no abre la escritura:** `man_*` o `*` siguen dejando afuera `man_create_ot` y `alm_crear_pedido_materiales`. Hay un test que lo verifica con esos patrones.

En los patrones, el `_` se escapa antes de pasarlo a `LIKE`, donde es comodín: sin eso, `man_get_*` dejaría pasar `manXgetXalgo`. `tests/test_tools.py` compara además el catálogo contra el contrato del gateway (`doc/api/trazalog-operaciones.yaml`): toda operación publicada tiene que estar catalogada y toda la que no es `GET` tiene que ser `accion`.

**Para agregar una tool nueva:** sumarla al seed de `012-tools.sql` con su clase y volver a aplicarlo.

### Por qué `interaccion` y `feedback` pasaron a tener RLS (013)

Hallazgo del 2026-10-27: desde `005` no tenían RLS, aunque guardan las preguntas y respuestas de cada empresa con datos de sus tools. Las protegía solo el `WHERE empr_id` del código. `013` les aplica la misma policy que a `memoria`, y `tool_llamada` nace con ella. `feedback` no tiene `empr_id`: su policy pasa por la de `interaccion` (una empresa no ve ni califica la interacción de otra). La vista `v_feedback_negativo` pasa a `security_invoker`, porque una vista corre con los permisos de su dueño y, si el dueño es superusuario, se saltea el RLS.

**Consecuencia operativa:** para leer estas tablas con el usuario del orquestador hay que fijar antes `agente.empr_id`. Las consultas de triage que cruzan empresas van con el propietario de la base.

### El agente cubre Mantenimiento y Almacenes

El esquema de E1 se escribió pensando solo en Mantenimiento — un sesgo que el PM detectó el 2026-09-02. La capa MCP expone las **dos** áreas (11 tools `man_*` y 9 `alm_*`), así que el script `009` amplía el esquema:

- **Tipos de alerta de almacenes**: `stock_critico`, `material_por_vencer`, `pedido_demorado`, junto a los de mantenimiento (`mtbf_deterioro`, `ot_critica_atrasada`) y los transversales (`hallazgo`, `sistema`).
- **Columna `modulo`** en `chunk`, `candidato`, `hecho` y `tema`, con valores `man`, `alm` o `general`. El `general` —seguridad, normativa transversal— se recupera siempre, sin importar el área de la consulta.

**Pañol y Tareas quedan para una versión posterior.** Cuando sus tools existan, alcanza con sumar sus valores a los `CHECK` de `009`.

### Deduplicación de hallazgos

`notificacion.dedupe_key` con índice único parcial sobre las no vencidas. Sin esto, el monitoreo programado de E5 notifica el mismo equipo con MTBF en deterioro en cada corrida y el agente se vuelve ruido en dos semanas (R6 del análisis de E0). La clave la arma el orquestador combinando empresa, entidad, tipo de hallazgo y ventana temporal.

---

## Verificación hecha

Aplicado y verificado el **2026-09-02** contra **PostgreSQL 16.15 con pgvector 0.6.0**, en la base `agente_minero` del PostgreSQL local de la máquina de desarrollo.

| Qué se probó | Resultado |
|---|---|
| Aplicar `001..007` sobre base vacía | ✅ los 7 sin error |
| **Idempotencia** — aplicarlos una segunda vez | ✅ los 7 sin error, y los tests siguen en verde después |
| `tests/test-estructura.sql` | ✅ **58 de 58** |
| `tests/test-aislamiento.sql` | ✅ **16 de 16** |
| **Búsqueda vectorial real** — ingesta de 3 chunks y consulta por similitud coseno | ✅ distancia `0.0000` contra sí mismo y `1.0000` contra los ortogonales, usando `chunk_embedding_hnsw_ix` |
| Conexión real como `agente_orq` (rol del orquestador) | ✅ no es superusuario, lee `agente.chunk` y al intentar escribirlo recibe `permission denied for table chunk` |
| **Rollback** en orden inverso `007 → 002`, y luego `001` | ✅ verificado en una corrida previa: deja el esquema y los roles limpios |

O sea que ADR-A4 no es una convención documentada: **se comprobó con el usuario real que el orquestador no puede escribir el conocimiento compartido**.

### Verificación de `011` (2026-10-27, AGENTE-M-01)

Sobre una base **descartable** (contenedor `pgvector/pgvector:0.8.7-pg16`), con `001..011` aplicados desde cero:

| Qué se probó | Resultado |
|---|---|
| Aplicar `011` dos veces | ✅ idempotente |
| `tests/test-estructura.sql` | ✅ **79 de 79** (los controles nuevos: los tres agentes, R1, R5, sin tools de escritura, `agente_app` solo lee) |
| `tests/test-aislamiento.sql` | ✅ **16 de 16** |
| Rollback de `011` y re-aplicación | ✅ borra la tabla y su registro; re-aplicado vuelve a dar 79/79 |
| Conexión como `agente_orq` intentando `UPDATE agente.agente` | ✅ `permission denied` (`tests/test_agentes.py`) |

### Verificación de `012` (2026-10-27, AGENTE-M-02)

Misma base descartable, con `001..012`:

| Qué se probó | Resultado |
|---|---|
| Aplicar `012` dos veces | ✅ idempotente |
| `tests/test-estructura.sql` | ✅ **88 de 88** (catálogo, las dos de escritura como `accion`, ningún agente alcanza una de acción, un patrón amplio tampoco, el `_` no es comodín, `agente_app` solo lee) |
| `tests/test-aislamiento.sql` | ✅ **16 de 16** |
| Rollback de `012` y re-aplicación | ✅ borra tabla, funciones y registro; sin `012` el orquestador no llega al modelo (falla cerrado) |
| **Mutación:** sacar el filtro de clase de la función | ✅ lo detectan 4 tests de pytest y el test de estructura |

### Verificación de `013` (2026-10-27, AGENTE-M-03)

Misma base descartable, con `001..013`:

| Qué se probó | Resultado |
|---|---|
| Aplicar `013` dos veces | ✅ idempotente |
| `tests/test-estructura.sql` | ✅ **100 de 100** (columnas de la corrida, `tool_llamada`, RLS forzado en las tres tablas, la vista con `security_invoker`, `agente_app` no corrige ni borra `tool_llamada`) |
| `tests/test-aislamiento.sql` | ✅ **23 de 23** — 7 controles nuevos sobre `interaccion`, `tool_llamada`, `feedback` y la vista |
| **Mutación:** desactivar el RLS de `interaccion` | ✅ el test de aislamiento marca 4 fallas |
| Rollback de `013` y re-aplicación | ✅ saca columnas, tabla y RLS; re-aplicado vuelve a 23/23 |

### Dos cosas que aparecieron al probar y están corregidas

1. **El índice de deduplicación no podía usar `now()`.** PostgreSQL exige que las funciones del predicado de un índice sean `IMMUTABLE`; la primera versión fallaba con `functions in index predicate must be marked IMMUTABLE`. Se resolvió metiendo la ventana temporal **dentro** de la `dedupe_key`, lo que además la vuelve determinista.
2. **El test de aislamiento daba falso verde corriendo como `postgres`.** Ver la advertencia sobre superusuarios más arriba — fue el primer resultado que dio al escribirlo, y es la razón por la que ahora hace `SET ROLE agente_app`.

---

## Estado de aplicación por ambiente

| Ambiente | Base | Estado |
|---|---|---|
| **Desarrollo** | `agente_minero` en el PostgreSQL 16.15 local (`127.0.0.1:5432`) | ✅ `001..010` **aplicados y verificados el 2026-09-02.** Usuario `agente_orq` creado con el rol `agente_app`. ✅ `011` aplicado por el PM el 2026-10-27. ⏳ **`012` a `017` pendientes de aplicar por el PM**, en orden: sin `012` el orquestador no responde (falla cerrado); sin `013` no registra las corridas; sin `014` no busca en internet; sin `015` no se pueden ingestar las ayudas ni los casos de uso; sin `016` el orquestador no responde (lee la industria de la empresa); sin `017` el panel no propone el siguiente paso |
| Demo | a definir | ⏳ pendiente |
| Producción | a definir | ⏳ pendiente |

> **Por qué una base aparte y no la de producción.** El agente **no necesita** que su base y la productiva sean la misma, ni que estén federadas: los datos del cliente (equipos, OTs, KPIs) los obtiene **vía MCP Gateway** (ADR-A3), nunca por SQL directo. Lo único que vive en esta base es la capa vectorial — conocimiento, memoria, feedback, entrevistas y notificaciones. Son dos caminos independientes, sin joins entre ellos.
>
> Eso permitió dejar intacto el PostgreSQL productivo (`10.142.0.13`), que es **11.18** y no tiene pgvector disponible — además, la última versión de pgvector que soporta PG 11 es la 0.5.1. **No hay ninguna migración de producción involucrada.**
>
> Las credenciales de desarrollo del usuario `agente_orq` quedaron en `~/.agente-minero.env` (permisos 600), **fuera del repo**. Para demo y producción se generan por ambiente.
