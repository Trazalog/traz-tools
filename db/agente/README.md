# Esquema de base de datos del Agente Minero

## Objetivo

Acá viven **todos los scripts SQL del Agente Minero**, versionados, numerados e idempotentes, cada uno con su rollback. Este README explica en qué orden se aplican, cómo verificar que quedaron bien y qué decisiones de diseño hay detrás. Está escrito para que cualquiera pueda montar el esquema desde cero sin conocer el historial del proyecto.

**Qué NO cubre:** no explica la arquitectura del agente (eso está en `doc/v3/AGENTE_MINERO_ARQUITECTURA_TECNICA.md`) ni cómo instalar los componentes de infraestructura como el Streaming Integrator (eso está en `doc/agente/instalacion.md`).

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
| 002 | `002-conocimiento-compartido.sql` | `fuente` y `chunk` — la base de conocimiento minero compartida entre clientes |
| 003 | `003-memoria-cliente.sql` | `memoria`, particionada por `empr_id`, con RLS y la función para dar de alta una empresa |
| 004 | `004-cola-candidatos.sql` | `candidato` — la cola de conocimiento propuesto que espera curaduría humana |
| 005 | `005-feedback.sql` | `interaccion` y `feedback` — el registro de cada consulta y su calificación |
| 006 | `006-entrevistador.sql` | `tema`, `sesion_entrevista`, `hecho` y `validacion_cruzada` — la captura de conocimiento experto |
| 007 | `007-notificaciones.sql` | `dispositivo`, `notificacion` y `envio` — el puente de alertas de la Opción C |
| 008 | `008-destinatarios-alerta.sql` | `destinatario_alerta` — quién recibe cada tipo de alerta, configurable por empresa |

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

`chunk` es la base de conocimiento minero curado — el activo del producto. El flujo de consulta **nunca escribe ahí**: el rol `agente_app` tiene `SELECT` y nada más. Lo que el agente aprende de un cliente va a `memoria` (privada de esa empresa) y, si un patrón se repite, se propone en `candidato`. Solo el rol `agente_curador` puede promover un candidato a `chunk`.

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

### Dos cosas que aparecieron al probar y están corregidas

1. **El índice de deduplicación no podía usar `now()`.** PostgreSQL exige que las funciones del predicado de un índice sean `IMMUTABLE`; la primera versión fallaba con `functions in index predicate must be marked IMMUTABLE`. Se resolvió metiendo la ventana temporal **dentro** de la `dedupe_key`, lo que además la vuelve determinista.
2. **El test de aislamiento daba falso verde corriendo como `postgres`.** Ver la advertencia sobre superusuarios más arriba — fue el primer resultado que dio al escribirlo, y es la razón por la que ahora hace `SET ROLE agente_app`.

---

## Estado de aplicación por ambiente

| Ambiente | Base | Estado |
|---|---|---|
| **Desarrollo** | `agente_minero` en el PostgreSQL 16.15 local (`127.0.0.1:5432`) | ✅ **Aplicado y verificado el 2026-09-02.** Usuario `agente_orq` creado con el rol `agente_app` |
| Demo | a definir | ⏳ pendiente |
| Producción | a definir | ⏳ pendiente |

> **Por qué una base aparte y no la de producción.** El agente **no necesita** que su base y la productiva sean la misma, ni que estén federadas: los datos del cliente (equipos, OTs, KPIs) los obtiene **vía MCP Gateway** (ADR-A3), nunca por SQL directo. Lo único que vive en esta base es la capa vectorial — conocimiento, memoria, feedback, entrevistas y notificaciones. Son dos caminos independientes, sin joins entre ellos.
>
> Eso permitió dejar intacto el PostgreSQL productivo (`10.142.0.13`), que es **11.18** y no tiene pgvector disponible — además, la última versión de pgvector que soporta PG 11 es la 0.5.1. **No hay ninguna migración de producción involucrada.**
>
> Las credenciales de desarrollo del usuario `agente_orq` quedaron en `~/.agente-minero.env` (permisos 600), **fuera del repo**. Para demo y producción se generan por ambiente.
