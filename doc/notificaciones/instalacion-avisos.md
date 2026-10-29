# Avisos de Tools — cómo se instala y se verifica

## Objetivo

Procedimiento para poner en marcha el mecanismo único de avisos (ADR-015, esquema `ntf`): base, API, conector de Firebase, transporte y puente en el Streaming Integrator, campanita de Tools y agentes. Está escrito para el PM o quien despliegue, y se sigue leyendo solo este archivo, en orden. No explica el porqué del diseño: eso está en [`diseno-avisos-tools.md`](diseno-avisos-tools.md) y en [`ADR-015`](../adr/ADR-015-avisos-tools.md). Las decisiones tomadas al construirlo están en [`decisiones-para-revisar.md`](../agente/decisiones-para-revisar.md) (D-71 a D-85).

- **Versión de la base:** `v2.8.1.5` (`_backend/database/scripts/versiones/v2.8.1.5/ntf_avisos.sql`)
- **Probado:** PostgreSQL 11.22, MI 4.5.0, SI 4.4.0, MariaDB 10.6, todo local, el 2026-10-28. **No probado** contra DEV, TEST ni producción (sin VPN), ni contra Firebase real.

---

## 0. Antes de empezar

| Qué | Dónde se consigue |
|---|---|
| Acceso `psql` a la base de Tools (`trazalog_tools`) con el usuario dueño de los esquemas | El servidor de base del ambiente |
| Acceso a la base de AssetPlanner (`assetv2`, MariaDB) con un usuario que pueda crear usuarios | El servidor de MariaDB del ambiente |
| Acceso al MI (carpeta `carbonapps`) y al SI (`deployment.yaml` y `siddhi-files`) | Los servidores de integración |
| JDK 21 Temurin y Maven en la máquina de build | Terminal local de la máquina de desarrollo |

**Orden obligatorio:** base → MI → SI → Tools → agentes. El paso 5.4 (sacar el Siddhi viejo de AssetPlanner y poner el puente) va **en el mismo momento**: si conviven, el push de AssetPlanner sale dos veces.

**Antes de producción:** rotar las credenciales que quedaron expuestas (decisión D-83 y STATE): la clave de la cuenta de servicio de Firebase del conector, la clave privada VAPID, la server key legacy de FCM, y el usuario root de la base que está en claro en `traz-int/siddhi/notificaciones/produccion/NotificacionesAssetSynch.siddhi`.

---

## 1. Base de Tools (PostgreSQL)

**Dónde:** terminal con `psql` conectada al servidor de base del ambiente, parado en la raíz del repo `traz-tools`.

1.1. Aplicar el esquema (es idempotente: se puede correr dos veces):

```bash
psql -h <host-base> -U <usuario-dueño> -d trazalog_tools \
  -v ON_ERROR_STOP=1 \
  -f _backend/database/scripts/versiones/v2.8.1.5/ntf_avisos.sql
```

1.2. Crear el usuario con el que el Streaming Integrator entra a la base. Solo tiene el rol `ntf_transporte`: no ve tablas, solo ejecuta las funciones del transporte y del puente. Elegir una contraseña y guardarla en el gestor de secretos (no en el repo):

```bash
psql -h <host-base> -U <usuario-dueño> -d trazalog_tools \
  -c "CREATE ROLE si_avisos LOGIN PASSWORD '<contraseña>' IN ROLE ntf_transporte"
```

1.3. Verificar:

```bash
psql -h <host-base> -U <usuario-dueño> -d trazalog_tools \
  -c "select count(*) from pg_proc where pronamespace = 'ntf'::regnamespace"
```

Tiene que dar **10** funciones.

**Rollback:** `_backend/database/scripts/versiones/v2.8.1.5/ntf_avisos.rollback.sql` (borra el esquema con todos los avisos). Antes, volver a desplegar el Siddhi viejo de AssetPlanner si se había sacado.

---

## 2. Micro Integrator

### 2.1 API de avisos (`ToolsAPIProject`)

**Dónde:** terminal local de la máquina de desarrollo, en la raíz del repo.

```bash
cd _backend/api/ToolsAPIProject/ToolsAPIProject && \
  JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64 mvn clean install -DskipTests
```

Copiar `target/ToolsAPIProject_1.0.0.car` a `<MI_HOME>/repository/deployment/server/carbonapps/` **del servidor del MI**. Trae: `NTFDataService`, `toolsNTFAPI` (`/tools/ntf`) y las sequences `usuarioFromHeader`, `ntfMarcarLeido` y `ntfDispositivo`.

### 2.2 Conector de Firebase (`FirebaseConnectorAPI`)

**Dónde:** terminal local de la máquina de desarrollo, en la raíz del repo.

```bash
cd _backend/api/FirebaseConnectorAPI/FirebaseConnectorAPICompositeExporter && \
  JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64 mvn clean install -DskipTests && \
  git checkout -- tmp
```

(El `git checkout -- tmp` deshace el borrado de la carpeta `tmp/` versionada que hace `clean`.)

Copiar `target/FirebaseConnectorAPICompositeExporter_1.0.0-SNAPSHOT.car` a `carbonapps` del MI y **reiniciar el MI** (el conector no se registra en caliente). Si el MI nunca tuvo el conector, ver la sección del SDK de Firebase en `doc/agente/instalacion.md`.

### 2.3 Verificar en el MI

**Dónde:** terminal del servidor del MI (o con acceso a su puerto HTTP).

```bash
curl -s -H Accept:application/json \
  http://localhost:8290/services/NTFDataService/avisos/noleidos/emprid/1/nick/nadie
```

Tiene que responder `{"no_leidos":{"cantidad":"0"}}`. **Sin** `Content-Type` en los GET: con ese encabezado el DataService ignora los parámetros de la URL.

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  -H Content-Type:application/json \
  -X POST http://localhost:8290/tools/firebase/send \
  -d '{"xformValues":{"registrationToken":"token-que-no-existe"}}'
```

Tiene que responder **410** (antes respondía 200). Esto sí llega a Firebase, con un token falso: no manda nada a nadie.

---

## 3. API Manager (solo para los agentes)

**Dónde:** Publisher del APIM (`https://<apim>:9443/publisher`).

Publicar `toolsNTFAPI` con backend `http://<mi>:8290/tools/ntf`, con el mismo Key Manager (Dnato) y el **backend JWT** que ya usan las APIs MCP: sin el claim `empr_id` responde 503 y sin `sub` también. Recursos: `POST /avisos`, `GET /avisos/mios`, `GET /avisos/no-leidos`, `POST /avisos/{aviso_id}/leido`, `POST /avisos/leidos`, `POST /dispositivos`, `DELETE /dispositivos/{token}`.

Este paso **no está probado**: no tengo acceso al APIM. La campanita de Tools no lo necesita (va directo al DataService).

---

## 4. Base de AssetPlanner (MariaDB)

**Dónde:** cliente `mysql`/`mariadb` conectado al servidor de MariaDB del ambiente.

Crear el usuario del puente, que solo toca la cola. **No se crea ningún objeto en la base**, solo un usuario:

```bash
mariadb -h <host-mariadb> -u <usuario-admin> -p assetv2 \
  -e "CREATE USER 'si_puente'@'<ip-del-si>' IDENTIFIED BY '<contraseña>'; GRANT SELECT, UPDATE, DELETE ON assetv2.synch_notificacion_queue TO 'si_puente'@'<ip-del-si>';"
```

---

## 5. Streaming Integrator

**Dónde:** servidor del SI, archivo `<SI_HOME>/conf/server/deployment.yaml`.

5.1. Hacer una copia del `deployment.yaml`. Después, debajo de `wso2.datasources:` → `dataSources:`, agregar dos datasources con este formato (las contraseñas, las de los pasos 1.2 y 4). **`isAutoCommit: true` es obligatorio**: sin eso, lo que toma `ntf.tomar_envios` se deshace al cerrar la conexión.

```yaml
    - name: NTF_DB
      description: "Avisos de Tools (ntf) - rol ntf_transporte"
      definition:
        type: RDBMS
        configuration:
          jdbcUrl: "jdbc:postgresql://<host-base>:5432/trazalog_tools"
          username: si_avisos
          password: <contraseña del paso 1.2>
          driverClassName: org.postgresql.Driver
          maxPoolSize: 5
          connectionTestQuery: "SELECT 1"
          isAutoCommit: true
    - name: ASSET_DB
      description: "AssetPlanner - solo synch_notificacion_queue"
      definition:
        type: RDBMS
        configuration:
          jdbcUrl: "jdbc:mysql://<host-mariadb>:3306/assetv2?useSSL=false&allowPublicKeyRetrieval=true"
          username: si_puente
          password: <contraseña del paso 4>
          driverClassName: com.mysql.cj.jdbc.Driver
          maxPoolSize: 5
          connectionTestQuery: "SELECT 1"
          isAutoCommit: true
```

5.2. Al final del mismo archivo, habilitar `rdbms:cud` (lo usa el puente para marcar y depurar):

```yaml
siddhi:
  extensions:
    -
      extension:
        name: cud
        namespace: rdbms
        properties:
          perform.CUD.operations: true
```

5.3. Variables de entorno del proceso del SI (en el servicio o script que lo arranca), y reiniciar el SI:

| Variable | Valor |
|---|---|
| `NTF_FIREBASE_URL` | `http://<mi>:8290/tools/firebase/send` |
| `NTF_ICONOS_URL` | URL pública de la carpeta de íconos, sin barra final (ej. `https://<tools>/assets/agentes/iconos`). Tiene que tener `quirqui.png`, `kuntur.png`, `faustino.png` y `trazalog.png` |

5.4. **En el mismo momento:** sacar `NotificacionesAssetSynch.siddhi` de `<SI_HOME>/deployment/siddhi-files/` y copiar ahí `_backend/siddhi/AvisosPush.siddhi` y `_backend/siddhi/PuenteAsset.siddhi` del repo.

5.5. Verificar en `<SI_HOME>/wso2/server/logs/carbon.log`: las dos apps dicen `deployed successfully` y no hay errores de datasource.

---

## 6. Tools (PHP)

**Dónde:** el despliegue habitual de Tools.

Va con el código: la campanita en el encabezado (`application/views/layout/perfil.php`), `application/controllers/Avisos.php`, `lib/props/avisos.js`, `lib/props/firebase_config.js`, `lib/props/firebase_web_config.js` y **`firebase-messaging-sw.js` en la raíz de Tools** (sin él no llegan push con Tools cerrado). El servidor tiene que servir Tools por **HTTPS** para que el navegador permita el push.

Verificar con un usuario cualquiera: aparece la campanita; al abrirla dice "No tenés avisos nuevos" y ofrece "Recibir avisos en este navegador".

---

## 7. Agentes

**Dónde:** el entorno del orquestador (`.env` o el servicio que lo arranca).

`AGENTE_AVISOS_URL` = el recurso `POST /avisos` de `toolsNTFAPI` en el gateway (paso 3). Vacía, el monitoreo no publica y deja los hallazgos en la corrida. Para que un aviso de un tipo le llegue a alguien, ese usuario tiene que estar suscripto (`ntf.suscripcion`, por ahora con un `INSERT` a mano, ver D-84).

---

## 8. Prueba de punta a punta

**Dónde:** terminal con `psql` a la base de Tools.

1. Con un usuario de prueba, aceptar "Recibir avisos en este navegador" en Tools.
2. Publicar un aviso para ese usuario:

```bash
psql -h <host-base> -U <usuario-dueño> -d trazalog_tools \
  -c "select ntf.publicar(p_empr_id => <empr_id>, p_origen => 'alm', p_tipo => 'prueba_avisos', p_titulo => 'Prueba de avisos', p_destinatarios => ARRAY['<nick>'])"
```

3. En menos de 15 segundos tiene que llegar el push y aparecer en la campanita. El envío queda así:

```bash
psql -h <host-base> -U <usuario-dueño> -d trazalog_tools \
  -c "select estado, intentos, ultimo_error from ntf.envio order by envio_id desc limit 5"
```

`enviado` es el resultado esperado; `descartado` quiere decir que Firebase no reconoció el token.

---

## 9. Pruebas automáticas (sin servidores)

**Dónde:** terminal local de la máquina de desarrollo, en la raíz del repo, con un PostgreSQL 11 descartable.

```bash
docker run -d --name ntf-pg11-prueba \
  -e POSTGRES_PASSWORD=prueba -e POSTGRES_DB=trazalog_tools \
  -p 127.0.0.1:55411:5432 postgres:11
```

```bash
psql "host=127.0.0.1 port=55411 dbname=trazalog_tools user=postgres password=prueba" \
  -v ON_ERROR_STOP=1 \
  -f _backend/database/scripts/versiones/v2.8.1.5/ntf_avisos.sql
```

```bash
NTF_TEST_DSN="host=127.0.0.1 port=55411 dbname=trazalog_tools user=postgres password=prueba" \
  .venv-agente/bin/python -m pytest tests/test_ntf.py -q
```

Tienen que pasar los 29. Con un MI de prueba que tenga desplegados el DataService y el API, `tests/ntf/probar_dss.sh` y `tests/ntf/probar_api.sh` prueban los recursos de punta a punta (instrucciones al principio de cada script).
