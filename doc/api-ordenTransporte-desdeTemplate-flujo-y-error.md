# API POST /ordenTransporte/desdeTemplate — Secuencia de ejecución y análisis de error

Este documento describe la secuencia completa del API **ordenTransporte/desdeTemplate**, los objetos de base de datos involucrados y el análisis del error `RECI_NO_VACIO_IGUAL_ART_LOTE` y relacionados que estás viendo en `tools_prod_t` (2026-02-25).

---

## 1. Secuencia del API (toolsLogAPI.xml)

El recurso está definido en **`_backend/api/toolsLogAPI.xml`** (aprox. líneas 847-616). Flujo resumido:

| Paso | Acción | URL / Recurso | Tablas / Objetos BD |
|------|--------|----------------|----------------------|
| 1 | Configuración | Registry `conf:tools/apiconfig.xml` | — |
| 2 | **POST orden de transporte** | `POST {dataservices_url}/ordenTransporte` | `log.ordenes_transporte` |
| 3 | Set ID en hijos (script) | `setIdEnHijos.js` | Mapea `ordenTransporte.contenedores[]` → ortr_id |
| 4 | **PUT contenedores retirados (batch)** | `PUT {dataservices_url}/_put_contenedores_retirados_batch_req` | `log.contenedores_entregados` ← **aquí se dispara el error** |
| 5 | GET empr_id del solicitante | `GET LOGDataService/solicitanteTransporte/{sotr_id}/emprId` | `log.solicitantes_transporte` |
| 6 | GET nicks OT | `GET LOGDataService/ordenTransporte/nicks/{ortr_id}` | `log.ordenes_transporte`, `seg.users` |
| 7 | POST instancia BPM | `POST {api_url}/bpm/proceso/instancia` (TERSU-BPM03) | — |
| 8 | PUT case_id en OT | `PUT {dataservices_url}/ordenTransporte/caseid` | `log.ordenes_transporte` |

En caso de error en pasos 4–8, se hace **DELETE ordenTransporte** (soft delete: `eliminado=1`) y, si aplica, borrado de la instancia BPM.

---

## 2. Objetos de base de datos involucrados

### 2.1 Dataservice (semaresiduosDS)

- **POST ordenTransporte**  
  - Query: `ordTransSet`  
  - SQL: `INSERT INTO log.ordenes_transporte (fec_retiro, estado, difi_id, sotr_id, equi_id, chof_id, teot_id, tran_id, usuario_app) ... RETURNING ortr_id`

- **PUT contenedores retirados (cada elemento del batch)**  
  - Recurso: `PUT /contenedores/retirados`  
  - Query: `contenedoresRetiradosUpdate`  
  - SQL:
    ```sql
    UPDATE log.contenedores_entregados
    SET ortr_id = CAST(:ortr_id AS INTEGER)
    WHERE cont_id = CAST(:cont_id AS INTEGER)
      AND ortr_id IS NULL
    ```
  - Este `UPDATE` dispara el trigger **`log.crear_batch_contenedor_retirado_trg()`**.

- **PUT ordenTransporte/caseid**  
  - Query: `ordenTransporteCaseidUpdate`  
  - SQL: `UPDATE log.ordenes_transporte SET case_id = :case_id WHERE ortr_id = CAST(:ortr_id AS INTEGER)`

### 2.2 Cadena de triggers y funciones (según el stack del error)

1. **`log.crear_batch_contenedor_retirado_trg()`**  
   - Se ejecuta **AFTER UPDATE** en `log.contenedores_entregados` cuando se setea `ortr_id`.  
   - En la línea 69 del trigger se llama a **`prd.crear_lote_noco(...)`** con, entre otros, el `reci_id` del contenedor (ej. 1867).  
   - *No está en el repo; hay que revisarlo en la BD.*

2. **`prd.crear_lote_noco(...)`**  
   - Definida en **`_backend/database/scripts/versiones/v1.5/crear_lote_noco.sql`**.  
   - Valida estado del recipiente (`prd.recipientes`), crea/actualiza lote en `prd.lotes`, actualiza `prd.recipientes`, hace **`INSERT INTO prd.lotes_hijos`** (aprox. línea 319) y luego **`CALL prd.audit_lote(...)`** (aprox. línea 508).

3. **`int.synch_lotes_hijos_trg()`**  
   - Trigger sobre **`prd.lotes_hijos`** (probablemente AFTER INSERT).  
   - En el error hace un **INSERT** en `prd.lotes_hijos` y en la línea 60 hace un **SELECT INTO** que no devuelve filas → **P0002 (NO_DATA_FOUND)**.  
   - *No está en el repo; hay que revisarlo en la BD.*

4. **`prd.audit_lote(batch_id, mensaje, step)`**  
   - Se llama desde `crear_lote_noco` con un mensaje construido por concatenación.  
   - Si algún argumento es NULL, en PostgreSQL `NULL || 'texto'` → NULL, y la tabla de auditoría exige **mensaje NOT NULL** → error que ves.  
   - *Definición de `audit_lote` no está en el repo.*

---

## 3. Análisis del error que estás viendo

### 3.1 Orden de los mensajes en el log

1. **LOGCREABATCH**  
   - ortr_id 168, tipo_carga RSU, cont 162, empr_id 87, arti_id 2625, **reci_id 1867**.

2. **DEBUG RECIPIENTE 1867 ESTADO LEIDO VACIO**  
   - Primera vez que se procesa el contenedor: `prd.crear_lote_noco` ve el recipiente 1867 como **VACIO**.  
   - Crea lote, inserta en `prd.lotes`, marca recipiente como **LLENO**, e intenta **INSERT** en `prd.lotes_hijos`.

3. **SYNCHINT - synch_lotes_hijos_trg - error extremo: P0002: la consulta no regresó filas**  
   - El trigger **`int.synch_lotes_hijos_trg`** sobre `prd.lotes_hijos` hace una consulta (SELECT INTO o similar) que no devuelve filas.  
   - La excepción se lanza en el mismo flujo que creó el lote y puso el recipiente en LLENO.

4. **audit_lote: error al auditar lote 23502: el valor null para la columna «mensaje» viola la restricción not null**  
   - Se intenta auditar el batch 23502 con un **mensaje NULL**.  
   - En `crear_lote_noco` el mensaje se arma con algo como:  
     `'batch generado: '||v_batch_id||' lote:'||p_lote_id||' batch padre:'||p_batch_id_padre||...`  
   - Si algún término es NULL (p. ej. `p_recu_id`, `p_noco_list`), toda la expresión resulta NULL.

5. **DEBUG RECIPIENTE 1867 ESTADO LEIDO LLENO**  
   - Segunda vez que se procesa el **mismo** recipiente (mismo contenedor o reintento): el recipiente ya quedó **LLENO** por el intento anterior (aunque el INSERT en `lotes_hijos` haya fallado después).

6. **RECI_NO_VACIO_IGUAL_ART_LOTE - reci_id=1867-arti_id=2625-lote_id=168-162**  
   - `crear_lote_noco` con `p_forzar_agregar='false'` no permite crear otro lote en un recipiente ya LLENO con el mismo artículo y mismo lote.  
   - Es el error final que devuelve el API.

### 3.2 Conclusión del flujo

- El **fallo real** es el **trigger `int.synch_lotes_hijos_trg`**: una consulta que no devuelve filas (P0002).  
- Eso hace que falle el INSERT en `prd.lotes_hijos` y que no se llegue a `audit_lote` en condiciones normales; si aun así se llama `audit_lote` (p. ej. desde un bloque de manejo de errores o en otro punto), el mensaje puede ser NULL por concatenación con NULL.  
- Como el lote **sí** se creó y el recipiente **sí** se pasó a LLENO antes del INSERT en `lotes_hijos`, un segundo intento (mismo contenedor o mismo reci) ve el recipiente LLENO y lanza **RECI_NO_VACIO_IGUAL_ART_LOTE**.

---

## 4. Qué revisar en la base de datos (10.142.0.13:5432 tools_prod_t)

Conectado a la BD, conviene:

### 4.1 Trigger y función que fallan

```sql
-- Definición del trigger sobre contenedores_entregados
SELECT pg_get_triggerdef(oid) FROM pg_trigger WHERE tgname LIKE '%crear_batch_contenedor_retirado%';

-- Código del trigger (esquema log)
\sf log.crear_batch_contenedor_retirado_trg

-- Código del trigger que lanza P0002 (esquema int)
\sf int.synch_lotes_hijos_trg

-- Código de audit_lote (por si tiene validación de mensaje)
\sf prd.audit_lote
```

En **`int.synch_lotes_hijos_trg`** buscar la línea 60 y la sentencia SQL que hace SELECT INTO (o equivalente) y por qué no devuelve filas en el contexto de un contenedor retirado desde template (ortr_id 168, reci_id 1867, arti_id 2625, lote_id 168-162).

### 4.2 Datos del caso

```sql
-- Recipiente y contenedor
SELECT reci_id, estado, depo_id FROM prd.recipientes WHERE reci_id = 1867;
SELECT cont_id, reci_id, codigo FROM log.contenedores WHERE reci_id = 1867;

-- Contenedores entregados con ortr_id 168
SELECT coen_id, cont_id, ortr_id, tica_id, batch_id
FROM log.contenedores_entregados
WHERE ortr_id = 168 OR (cont_id IN (SELECT cont_id FROM log.contenedores WHERE reci_id = 1867));

-- Lotes en ese recipiente
SELECT batch_id, lote_id, reci_id, estado FROM prd.lotes WHERE reci_id = 1867;

-- Lotes_hijos del batch 23502 (si existe)
SELECT * FROM prd.lotes_hijos WHERE batch_id = 23502 OR batch_id_padre = 23502;
```

### 4.3 Posibles causas del P0002 en synch_lotes_hijos_trg

- Una tabla de integración (`int.*`) que no tiene fila para el nuevo batch/ortr/reci.  
- Un SELECT sobre una vista o tabla que filtra por empresa, establecimiento o otro dato que en “orden desde template” no coincide.  
- Un RETURNING o SELECT sobre la fila recién insertada en `prd.lotes_hijos` que en tu versión de Postgres o del trigger no devuelve fila.

Corregir el trigger para que no use SELECT INTO strict cuando pueda no haber filas, o para que rellene/valide los datos que espera antes de hacer la consulta.

---

## 5. Correcciones recomendadas (resumen)

1. **Corregir `int.synch_lotes_hijos_trg`**  
   - Evitar SELECT INTO STRICT si la consulta puede no devolver filas en este flujo; usar SELECT INTO variable y comprobar FOUND, o usar una lógica que no dependa de una fila obligatoria cuando el contexto es “contenedor retirado desde template”.

2. **Evitar mensaje NULL en `prd.audit_lote`**  
   - En `crear_lote_noco`, usar COALESCE en la construcción del mensaje, por ejemplo:  
     `COALESCE(v_batch_id::text,'')`, `COALESCE(p_lote_id,'')`, etc.  
   - O en la función `prd.audit_lote`: si el parámetro `mensaje` es NULL, asignar algo por defecto (p. ej. `'[sin mensaje]'`) antes del INSERT en la tabla de auditoría.

3. **Consistencia transaccional**  
   - Si `synch_lotes_hijos_trg` no puede garantizar éxito en el flujo “orden desde template”, considerar que todo el flujo (UPDATE contenedores_entregados + crear_lote_noco + lotes_hijos) se ejecute en la misma transacción para que, ante fallo, se haga rollback también del estado del recipiente y no se quede 1867 en LLENO y luego falle el segundo intento con RECI_NO_VACIO_IGUAL_ART_LOTE.

Cuando tengas el código de `log.crear_batch_contenedor_retirado_trg` e `int.synch_lotes_hijos_trg` desde la BD, se puede bajar a la causa exacta del P0002 y proponer el parche concreto (o revisar si el template está asociando más de una vez el mismo contenedor/recipiente al mismo ortr_id).
