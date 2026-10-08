# Bandeja de entrada 2: paginado y búsqueda en la base

## Objetivo

Cómo probar y desplegar la **bandeja de entrada 2** (`traz-comp-bpm/Proceso2`). Es la misma bandeja de siempre, pero pagina y busca en la base en vez de traer y enriquecer todas las tareas, así la búsqueda es rápida desde la primera vez. Convive con la bandeja actual (`traz-comp-bpm/Proceso`), que no se tocó, para poder comparar las dos.

Está escrito para el **developer** que la prueba funcionalmente en su máquina (secciones 1 a 3) y para el **PM**, que la despliega en demo y producción detrás de un punto de menú visible solo para un usuario especial de Yudica (secciones 4 a 6). No cubre el reemplazo definitivo de la bandeja vieja: eso se decide después de esta prueba.

- **Rama:** `feat/bandeja-paginado-real`, en `traz-tools` y en el submódulo `application/modules/traz-comp-bpm`. Sale de `develop` y solo agrega los cambios de la bandeja.
- **Camino a producción:** OK del developer → merge de la rama a `develop` → despliegue en **DEMO** → OK en DEMO → merge de `develop` a `master` → despliegue en **producción** (sección 4.5).
- **Clase de riesgo:** 🔴. Lee la base de Bonita y agrega un DataService, un servidor dblink y un ítem de menú. No modifica ningún objeto existente.
- **Desarrollado y verificado en:** TEST `10.142.0.13` (base `tools_prod_t`, Bonita 7.7.0), 2026-10-07/08

---

## 1. Qué es y qué cambia

### Bandeja vieja (`Proceso`) y bandeja 2 (`Proceso2`)

| | Bandeja vieja | Bandeja 2 |
|---|---|---|
| Menú | "Mis Tareas" | "Mis Tareas 2 (prueba)" (sección 5) |
| URL | `traz-comp-bpm/Proceso` | `traz-comp-bpm/Proceso2` |
| Archivos (submódulo `traz-comp-bpm`) | `controllers/Proceso.php`, `models/Procesos.php`, `views/bandeja_entrada.php`: **sin cambios** | `controllers/Proceso2.php`, `models/Procesos2.php`, `views/bandeja_entrada2.php`: **nuevos** |
| Cómo pagina | Trae hasta 1000 tareas de Bonita, valida la empresa y enriquece **todas** las tareas, una por una, con varias llamadas HTTP | Una consulta en la base devuelve solo la página, ya filtrada por empresa y búsqueda; se enriquecen solo las filas que se ven |
| Primera búsqueda (Yudica, 117 tareas, por VPN) | ~50 s | ~3,5 s |
| Abrir y cambiar de página | ~51-109 s | ~6 s |

`Proceso2` y `Procesos2` **heredan** de `Proceso` y `Procesos`: solo redefinen el paginado y la búsqueda. Abrir, tomar, soltar, comentar y cerrar una tarea usan exactamente el mismo código que la bandeja vieja. Al cerrar una tarea desde la bandeja 2, se vuelve a la bandeja 2.

### Cómo resuelve la consulta

```
Proceso2 → Procesos2::listarPaginaServerSide()
  └─ GET REST_BANDEJA/bandeja/tareas/usuario/{bonita_user_id}/empresa/{empr_id}/offset/{n}/limit/{m}?buscar=...&procesos=...
       └─ BandejaDataService (MI) → base de Tools
            ├─ dblink('bonita_bpm') → base de Bonita: tareas pendientes del usuario
            │   (misma lógica que humanTask?f=user_id=X: asignadas a él + candidatas por actor/grupo/rol)
            ├─ core.case_empresa: solo los casos de la empresa activa (igual que la bandeja vieja)
            └─ texto buscable de cada tarea, armado en SQL desde las mismas tablas que leen los map()
               de cada proceso; "contiene", sin distinguir mayúsculas, igual que la bandeja vieja
```

### Archivos de la rama

| Archivo | Qué es |
|---|---|
| `application/modules/traz-comp-bpm/controllers/Proceso2.php` | Controller de la bandeja 2 (nuevo) |
| `application/modules/traz-comp-bpm/models/Procesos2.php` | Modelo de la bandeja 2 (nuevo) |
| `application/modules/traz-comp-bpm/views/bandeja_entrada2.php` | Vista de la bandeja 2 (nueva, copia de la vieja con otras URLs) |
| `_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/data-services/BandejaDataService.dbs` | DataService nuevo (no toca ningún DataService existente) |
| `_backend/database/scripts/versiones/bandeja_bonita_dblink.sql` | Servidor dblink `bonita_bpm` en la base de Tools |
| `_backend/database/scripts/versiones/bandeja2_menu_prueba.sql` | Ítem de menú "Mis Tareas 2 (prueba)" y su permiso para un usuario |
| `application/config/constants.php` | 1 línea nueva: `REST_BANDEJA` (con guarda `defined()`) |

---

## 2. Para el developer: bajar la rama

**En tu terminal local, en la carpeta de tu clon de `traz-tools`:**

1. Confirmá que no tenés cambios sin commitear. Si `git status` muestra cambios, guardalos con `git stash` antes de seguir:

   ```bash
   git status
   ```

2. Bajá la rama y poné el submódulo `traz-comp-bpm` en el commit de la rama:

   ```bash
   git fetch origin && git checkout feat/bandeja-paginado-real && git submodule update --init application/modules/traz-comp-bpm
   ```

3. Verificá que quedaste en la rama, con los archivos nuevos:

   ```bash
   git log --oneline -3 && ls application/modules/traz-comp-bpm/controllers/Proceso2.php application/modules/traz-comp-bpm/models/Procesos2.php
   ```

Para volver a como estabas: `git checkout develop && git submodule update application/modules/traz-comp-bpm` (y `git stash pop` si guardaste cambios).

## 3. Para el developer: probar en tu máquina

Tu Tools local (Apache + PHP) apunta a los servicios de TEST (`HOST` = `http://10.142.0.13:8280` en `application/config/constants.php`), así que necesitás la VPN. La bandeja 2 necesita el `BandejaDataService`. Hay dos formas:

### 3.A. Usar el DataService de TEST (recomendada)

Sirve si el PM ya hizo la sección 4 en TEST. Para saberlo, **en tu terminal local**, este comando tiene que devolver `{"tareas":...}`:

```bash
curl -s -H "Accept: application/json" "http://10.142.0.13:8280/services/BandejaDataService/bandeja/tareas/usuario/623/empresa/777/offset/0/limit/1?buscar=&procesos=%7B%7D"
```

Si responde, no hay nada más que configurar: `REST_BANDEJA` apunta por defecto a `HOST/services/BandejaDataService`.

### 3.B. Levantar un MI local con el DataService

Sirve si TEST todavía no lo tiene. Todo esto se hace **en tu terminal local** y requiere Java 21.

1. Bajá y descomprimí WSO2 MI 4.5.0, y agregale el driver de PostgreSQL:

   ```bash
   curl -L -o wso2mi-4.5.0.zip https://github.com/wso2/micro-integrator/releases/download/v4.5.0/wso2mi-4.5.0.zip && unzip -q wso2mi-4.5.0.zip
   curl -L -o wso2mi-4.5.0/lib/postgresql-42.7.4.jar https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.4/postgresql-42.7.4.jar
   ```

2. Editá `wso2mi-4.5.0/conf/deployment.toml`:
   - En `[server]`, descomentá `offset` y ponelo en `20`. El HTTP queda en el puerto **8300**, sin chocar con otros MI.
   - Al final del archivo, agregá el datasource con las credenciales de `tools_prod_t` que ya usás en tu `application/config/database.php`:

   ```toml
   [[datasource]]
   id = "ToolsDataSource"
   url = "jdbc:postgresql://10.142.0.13:5432/tools_prod_t"
   username = "postgres"
   password = "<la misma de database.php>"
   driver = "org.postgresql.Driver"
   ```

3. Copiá el DataService y arrancá el MI:

   ```bash
   mkdir -p wso2mi-4.5.0/repository/deployment/server/dataservices && cp <tu clon>/_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/data-services/BandejaDataService.dbs wso2mi-4.5.0/repository/deployment/server/dataservices/
   JAVA_HOME=<ruta a tu JDK 21> wso2mi-4.5.0/bin/micro-integrator.sh
   ```

4. Hacé que **solo** la bandeja 2 use tu MI local. Creá el archivo `application/config/<ENTORNO>/constants.php` en tu clon, donde `<ENTORNO>` es el valor de `CI_ENV` de tu Apache (si no lo seteás, es `production`), con este contenido:

   ```php
   <?php
   define('REST_BANDEJA', 'http://localhost:8300/services/BandejaDataService');
   ```

   CodeIgniter carga ese archivo antes que `constants.php`. **No lo commitees**: agregalo a `.git/info/exclude`.

### 3.C. Qué probar

Entrá a Tools como siempre (vía DNATO), con un usuario de una empresa que tenga tareas. En TEST, Yudica es la empresa 777. Para ver la bandeja 2 hay dos caminos:
- crear el punto de menú en TEST, como en la sección 5 (pedíselo al PM), o
- en la consola del navegador, ejecutar `linkTo('traz-comp-bpm/Proceso2')`.

⏱️ **Al medir tiempos:** al entrar, Tools abre sola la bandeja vieja ("Mis Tareas"). PHP atiende **de a un pedido por sesión**, así que si abrís la bandeja 2 mientras la vieja todavía carga, la 2 espera a que termine (en TEST, con VPN, se vio a la 2 tardar 100 s por eso, aunque su consulta tardó 6 s). Esperá a que "Mis Tareas" termine de cargar y recién ahí abrí la bandeja 2 y medí. Lo mismo vale para el usuario especial en producción.

Compará siempre la **bandeja vieja** ("Mis Tareas") con la **bandeja 2**, con el mismo usuario y la misma empresa:

| # | Prueba | Resultado esperado |
|---|---|---|
| 1 | Abrir las dos bandejas | Misma cantidad total ("de un total de N registros"), mismas tareas en el mismo orden, misma info en cada fila (proceso, tarea, case, descripción, etiquetas) |
| 2 | Pasar de página, y cambiar a 25/50 registros | Mismo contenido por página; en la bandeja 2 cada página tarda lo mismo que la primera |
| 3 | Buscar apenas se entra: un n° de pedido, un estado, un nombre de tarea, un case, una fecha parcial (`2025/`) | Mismas filas en las dos; en la bandeja 2 la **primera** búsqueda es rápida |
| 4 | Buscar algo que no existe | Las dos dicen 0 registros |
| 5 | Borrar la búsqueda con la ✕ | Vuelve la bandeja completa |
| 6 | Abrir una tarea desde la bandeja 2 | Se abre el mismo detalle que en la vieja |
| 7 | Tomar y soltar una tarea desde la bandeja 2 | Funciona igual; el ícono de asignado cambia |
| 8 | Cerrar una tarea desde la bandeja 2 | Se cierra y se vuelve a la **bandeja 2**, sin esa tarea |
| 9 | Cambiar de empresa (si el usuario tiene varias) | Cada bandeja muestra solo las tareas de la empresa activa |

⚠️ En TEST, tomar, soltar y cerrar tareas **cambian datos reales del ambiente**. Usá tareas de prueba.

Reportá cualquier diferencia entre las dos bandejas con: usuario, empresa, texto buscado, y qué tarea aparece en una y no en la otra (con su case).

---

## 4. Para el PM: configurar un ambiente (TEST, demo, producción)

Demo y producción tienen la misma configuración. Hay que hacer esto **una vez por ambiente**. En TEST el paso 4.3 ya está hecho (2026-10-07, con el usuario `bonita` en lugar del de solo lectura del 4.2); falta el 4.4 (MI) para que los developers usen la opción 3.A.

### 4.1. Relevar el ambiente

Anotá estos cuatro datos antes de empezar:

| Dato | Dónde se ve | Valor en TEST |
|---|---|---|
| Base de Tools (host, puerto, base, usuario) | **Servidor de la app (SSH):** `application/config/database.php`, grupo de conexión de Postgres (`'hostname'`, `'database'`, `'username'`) | `10.142.0.13:5432/tools_prod_t`, `postgres` |
| Usuario con el que el MI se conecta a esa base | **Servidor del MI (SSH):** el datasource `ToolsDataSource` del MI | `postgres` |
| Base de Bonita | **Servidor de Bonita (SSH):** `grep -h "jdbc:" <tomcat>/conf/Catalina/localhost/bonita.xml` | `localhost:6432/bonita` (PostgreSQL 9.4, misma VM) |
| MI | **Servidor de la app (SSH):** `HOST` en `application/config/constants.php` | `http://10.142.0.13:8280` |

Según `doc/v3/deployment-gcp.md`, Bonita de demo corre en `10.142.0.11` y la de producción en `10.142.0.2`. Hay que confirmar si la base de Tools está en la **misma VM** que la base de Bonita. Si está en otra, el PostgreSQL de Bonita tiene que aceptar conexiones desde el host de la base de Tools: hay que revisar `pg_hba.conf` y `listen_addresses` en la VM de Bonita.

### 4.2. Base de Bonita: usuario de solo lectura (recomendado en demo y producción)

En TEST se usó el usuario `bonita`. En demo y producción conviene un usuario que **solo pueda leer** las tablas que usa la bandeja. **En el servidor de Bonita (SSH)**, con el puerto que relevaste en 4.1:

```bash
psql -h 127.0.0.1 -p 6432 -U postgres -d bonita -v ON_ERROR_STOP=1 \
  -c "CREATE ROLE bandeja_ro LOGIN PASSWORD '<clave>'" \
  -c "GRANT CONNECT ON DATABASE bonita TO bandeja_ro" \
  -c "GRANT SELECT ON flownode_instance, pending_mapping, actormember, user_membership TO bandeja_ro"
```

Si en 4.3 la base de Tools se conecta por red, y no por `127.0.0.1`, agregá en `pg_hba.conf` de Bonita una línea `host bonita bandeja_ro <IP de la base de Tools>/32 md5` y recargá PostgreSQL.

### 4.3. Base de Tools: servidor dblink hacia Bonita

1. **En tu PC**, editá en `_backend/database/scripts/versiones/bandeja_bonita_dblink.sql`:
   - `CREATE SERVER`: `host`, `port` y `dbname` de Bonita (de 4.1).
   - `CREATE USER MAPPING FOR postgres`: cambiá `postgres` por el usuario del MI (de 4.1), y en `OPTIONS` poné `user 'bandeja_ro', password '<clave>'`. Si el usuario del MI no es superusuario, la clave es obligatoria.

   No commitees la clave.
2. **En tu PC (terminal local, con VPN), desde la raíz del repo:** aplicá el script en la base de Tools, con un superusuario:

   ```bash
   psql -h <host base Tools> -U postgres -d <base Tools> \
     -v ON_ERROR_STOP=1 \
     -f _backend/database/scripts/versiones/bandeja_bonita_dblink.sql
   ```

3. **Mismo lugar:** verificá que llega a Bonita. Tiene que devolver la versión del PostgreSQL de Bonita:

   ```bash
   psql -h <host base Tools> -U postgres -d <base Tools> -Atc "SELECT * FROM dblink('bonita_bpm', 'select version()') AS t(v text)"
   ```

4. **Mismo lugar:** revisá `core.case_empresa`. Tiene que tener índice o PK por `(case_id, empr_id)`. En TEST es `integer` con PK. Si no tiene, pedí crearlo antes de producción:

   ```bash
   psql -h <host base Tools> -U postgres -d <base Tools> -c "\d core.case_empresa"
   ```

### 4.4. MI: desplegar `BandejaDataService`

1. **En tu PC:** copiá el archivo al servidor del MI:

   ```bash
   scp _backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/data-services/BandejaDataService.dbs \
     <usuario>@<servidor MI>:/tmp/
   ```

2. **En el servidor del MI (SSH):** dejalo en la carpeta de dataservices del MI. Se despliega solo, sin reiniciar:

   ```bash
   cp /tmp/BandejaDataService.dbs <MI_HOME>/repository/deployment/server/dataservices/
   ```

   Si el MI del ambiente se despliega por `.car`, el `.dbs` ya está dentro del proyecto `ToolsAPIProject`: se arma con `./mvnw clean install` y se despliega como siempre.
3. **En tu PC (con VPN):** verificá el recurso, con el `HOST` del ambiente. Tiene que devolver `{"tareas":...}` con `total` y `filtered`:

   ```bash
   curl -s -H "Accept: application/json" \
     "<HOST>/services/BandejaDataService/bandeja/tareas/usuario/1/empresa/1/offset/0/limit/1?buscar=&procesos=%7B%7D"
   ```

### 4.5. App: llevar el código a DEMO y a producción (flujo normal de ramas)

El código llega a cada ambiente por el flujo habitual: `develop` es lo que se despliega en DEMO y `master` lo que se despliega en producción. La rama sale de `develop` y solo agrega archivos **nuevos** y una línea en `constants.php`, así que la bandeja vieja no cambia. **Los pasos 4.2 a 4.4 y el menú (sección 5) se hacen en cada ambiente antes de que el código llegue**, para que la bandeja 2 funcione apenas se despliega.

1. **Merge a `develop`, después del OK del developer.** Lo hace el developer, en los **dos** repos, como cualquier rama de v2:
   - **Submódulo:** en `traz-comp-bpm`, PR de `feat/bandeja-paginado-real` contra `develop`. Agrega `Proceso2.php`, `Procesos2.php` y `bandeja_entrada2.php`.
   - **`traz-tools`:** PR de `feat/bandeja-paginado-real` contra `develop`. Agrega el DataService, los scripts, el doc, la línea de `constants.php` y el puntero del submódulo `traz-comp-bpm`.

   Mergeá primero el PR del submódulo. Después, en el PR de `traz-tools`, confirmá que el puntero de `traz-comp-bpm` apunta a un commit que esté en `develop` del submódulo.

   **En tu PC**, antes de mergear, confirmá que la rama solo trae cambios de la bandeja. El primer comando tiene que mostrar solo commits de la bandeja; el segundo, solo los archivos listados en la sección 1:

   ```bash
   git fetch origin && git log --oneline origin/develop..origin/feat/bandeja-paginado-real
   git diff --stat origin/develop origin/feat/bandeja-paginado-real
   ```

2. **Desplegar `develop` en DEMO**, con el procedimiento habitual. Probá con el usuario especial (sección 5) y la tabla de la sección 3.C.
3. **Con el OK en DEMO:** merge de `develop` a `master` (en los dos repos, submódulo primero) y despliegue en **producción** con el procedimiento habitual.

### 4.6. Volver atrás

- **App:** como solo agrega archivos nuevos, alcanza con sacar el ítem de menú (abajo): sin menú nadie llega a la bandeja 2. Para sacar el código, revertí el merge en la rama del ambiente (`develop` para DEMO, `master` para producción) en los dos repos y volvé a desplegar.
- **Menú (en tu PC):** los 3 `DELETE` del encabezado de `bandeja2_menu_prueba.sql`.
- **MI (servidor del MI, SSH):** borrá `<MI_HOME>/repository/deployment/server/dataservices/BandejaDataService.dbs`.
- **Base de Tools (en tu PC):**

  ```bash
  psql -h <host base Tools> -U postgres -d <base Tools> -c "DROP USER MAPPING IF EXISTS FOR postgres SERVER bonita_bpm; DROP SERVER IF EXISTS bonita_bpm;"
  ```

Nada de esto afecta a la bandeja vieja.

---

## 5. Punto de menú "Mis Tareas 2 (prueba)" para un usuario especial de Yudica

La idea es que en producción la bandeja 2 la vea **un solo usuario**, con los datos reales de Yudica (la empresa con más tareas y la que más sufre con la búsqueda), mientras el resto sigue con la bandeja vieja.

### Cómo funciona el permiso de menú en Tools

- Los ítems del menú están en `seg.menues`.
- Un ítem se muestra si hay una fila en `seg.memberships_menues` (grupo, rol, ítem) cuyo grupo y rol el usuario tiene en `seg.memberships_users` (email, grupo, rol), para el grupo de la empresa activa en la sesión.
- El script crea un **rol propio, "Prueba Bandeja 2", que existe solo en esas tablas de Tools**. Ese rol no existe en Bonita y no cambia qué tareas ve el usuario.

### Pasos (por ambiente)

1. **Crear el usuario especial (DNATO):** dalo de alta con el flujo habitual de DNATO, en la empresa Yudica y con el **mismo rol** de los operadores de Yudica cuya bandeja se quiere probar. Por ejemplo, en TEST el usuario `recepcion@yudica.com.ar` tiene el rol "Recepcion Yudica". Ese rol en Bonita es lo que hace que vea las mismas tareas que ellos.

2. **En tu PC (con VPN):** averiguá el nombre exacto del grupo de Yudica en la base de Tools del ambiente. Es el valor de `group`; en TEST es `Yudica`:

   ```bash
   psql -h <host base Tools> -U postgres -d <base Tools> -c "SELECT DISTINCT \"group\", role FROM seg.memberships_users WHERE \"group\" ILIKE '%yudi%'"
   ```

3. **En tu PC (con VPN), desde la raíz del repo:** creá el ítem y el permiso para el usuario:

   ```bash
   psql -h <host base Tools> -U postgres -d <base Tools> -v ON_ERROR_STOP=1 \
     -v email='<email del usuario especial>' -v grupo='<grupo del paso 2>' \
     -f _backend/database/scripts/versiones/bandeja2_menu_prueba.sql
   ```

   Al final, el script muestra una fila con el usuario. Si dice que el email no existe en `users`, falta el paso 1.

4. **En el navegador:** entrá con el usuario especial y elegí la empresa Yudica. En el menú aparece "Mis Tareas 2 (prueba)" debajo de "Mis Tareas". Cualquier otro usuario no lo ve.

⚠️ **En producción, el usuario especial opera sobre tareas reales de Yudica.** Abrir y buscar no cambia nada, pero tomar, soltar o cerrar una tarea sí, igual que en la bandeja vieja. Coordiná con Yudica qué tareas se pueden accionar durante la prueba.

### Recorrido sugerido

1. **Developer, en su máquina** (secciones 2 y 3): pruebas funcionales de la tabla 3.C contra TEST.
2. **DEMO**, después del merge a `develop` (secciones 4 y 5): mismo recorrido, con el usuario especial.
3. **Producción**, después del merge a `master` (secciones 4 y 5): usuario especial de Yudica, comparando "Mis Tareas" contra "Mis Tareas 2 (prueba)" con datos reales.
4. Con el OK de producción, se decide cómo reemplazar la bandeja vieja.

---

## 6. Cómo se verificó y qué tener en cuenta

### Verificación (TEST)

- **Tareas del usuario:** la consulta a Bonita devuelve los mismos task_id que `API/bpm/humanTask?f=user_id=X` para 4 usuarios (191, 121, 122 y 79 tareas).
- **Texto buscable:** para las 414 tareas vivas, el texto que arma SQL coincide carácter por carácter con el que arma PHP con los `map()` de cada proceso. Coinciden las 414.
- **Bandeja vieja contra bandeja 2:**
  - Sin búsqueda: cantidad, orden y contenido enriquecido completo iguales, en 5 combinaciones de usuario y empresa.
  - Con búsqueda: 38 términos × 4 combinaciones (152 casos), todos con las mismas tareas y en el mismo orden. Los términos incluyeron palabras, cases, fechas parciales, rótulos, acentos, mayúsculas, `0`, `%`, `_` y textos sin coincidencias.
- **Convivencia:** con las dos bandejas desplegadas a la vez, la vieja sigue funcionando igual. El detalle abierto desde cada bandeja vuelve a su propia bandeja al cerrar.

### Mantenimiento: el texto buscable está duplicado en SQL

El texto que arma cada `map()` en PHP (por ejemplo `Yudiproctareas::map`, `Almtareas::map` o `Tsttareas::map`) también existe en SQL, en el CTE `tx` de `BandejaDataService.dbs`, con un bloque por modelo. **Si cambia lo que muestra un `map()`, o se agrega a `BPM_PROCESS` un proceso con modelo propio, hay que actualizar ese bloque en el mismo PR.** Si no, la búsqueda de la bandeja 2 no encuentra lo nuevo. El `.dbs` documenta las rarezas de PHP que el SQL copia a propósito para dar los mismos resultados.

### Antes de producción

- **El SQL sigue la versión de los submódulos de `develop`.** Ejemplo: el `map()` de órdenes de transporte en `traz-tools-resi` dice "Sector de Descarga:" en `develop` y "Deposito:" en el `master` de hoy. La bandeja 2 tiene que llegar a cada ambiente **junto con** los submódulos de `develop`, que es lo que pasa con el flujo normal `develop` → DEMO → `master` → producción. No hay que llevarla sola a un ambiente que tenga submódulos más viejos: la búsqueda daría distinto en esas etiquetas.

- **Formato de fecha de las solicitudes de retiro:** en TEST, el MI serializa `log.solicitudes_retiro.fec_alta` como `YYYY-MM-DDTHH:MI:SS.mmm-03:00`, corrida 3 horas, y el SQL lo replica. Si el MI de producción tiene otra zona horaria, buscar por esa fecha puede dar distinto.
- **Versión de Bonita:** la consulta lee tablas internas del engine. Sirve para Bonita 7.x (verificado en 7.7.0; las columnas son las mismas hasta 10.1). Desde **Bonita 10.3** desaparece la columna `tenantid` y hay que ajustarla.

### Comportamientos que se mantienen igual a propósito

- **Las tareas de casos sin fila en `core.case_empresa` no aparecen**, igual que en la bandeja vieja. `case_empresa` se implementó después que muchos procesos; en TEST son 98 de las 414 tareas vivas.
- **Un caso cargado en varias empresas aparece en todas.**
- **`filtrarbyDepo()` se aplica después de paginar**, igual que antes. Una página puede mostrar menos filas que las pedidas.
- **Particularidades de la búsqueda que ya existían:**
  - Distingue acentos en mayúscula: `REVISIÓN` no encuentra "Revisión".
  - Buscar `0` equivale a no buscar.
  - Una búsqueda de solo espacios no encuentra nada.
