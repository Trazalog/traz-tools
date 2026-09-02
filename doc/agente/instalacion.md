# Instalación de los componentes del Agente Minero — por ambiente

## Objetivo

Este documento es el **instructivo paso a paso para instalar y dejar operativos los componentes de infraestructura del Agente Minero** en cada ambiente (desarrollo, demo, producción). Está escrito para que cualquiera pueda seguirlo sin conocer el historial del proyecto: cada paso dice explícitamente dónde se ejecuta y cómo verificar que salió bien.

**Qué NO cubre:** no explica por qué se eligió esta arquitectura (eso está en `doc/agente/analisis-alertas-assetplanner.md` §6) ni la operación diaria — variables de entorno, jobs, troubleshooting — que va en `doc/agente/operacion.md`. Tampoco cubre todavía el orquestador Python ni el esquema de base de datos: se agregan a este mismo documento cuando esas etapas se construyan (E1 y E2).

---

## Estado de este documento

| Componente | Desarrollo | Demo | Producción |
|---|---|---|---|
| **WSO2 Streaming Integrator** | ✅ §1 — instalado y verificado 2026-09-02 | ⏳ §2 — pendiente | ⏳ pendiente |
| Esquema PostgreSQL del agente | ⏳ E1 | ⏳ | ⏳ |
| Orquestador Python/FastAPI | ⏳ E2 | ⏳ | ⏳ |
| `FirebaseConnectorAPI` en el MI | ⏳ (hoy no está desplegado en el MI local) | — ya existe | — ya existe |

---

## 1. WSO2 Streaming Integrator — ambiente de desarrollo

El SI es el transporte entre la cola de notificaciones del agente y el conector Firebase del MI (Opción C del análisis de E0). Todos los comandos de esta sección se ejecutan en **la terminal local de la máquina de desarrollo** (Ubuntu 24.04).

### 1.1 Requisitos previos

- **JDK 21** — verificado funcionando con Temurin 21. La ruta usada acá es `/usr/lib/jvm/temurin-21-jdk-amd64`; si en tu máquina está en otro lado, ajustá `JAVA_HOME` en todos los comandos.
- **~600 MB libres en disco** — el zip son 111 MB y la instalación desplegada ocupa ~150 MB, más logs.
- Conexión a internet para bajar el instalable y dos drivers JDBC de Maven Central.

### 1.2 Descarga e instalación

```
mkdir -p ~/wso2 && cd ~/wso2
```
```
curl -L -o /tmp/wso2si-4.4.0.zip \
  https://github.com/wso2/product-integrator-si/releases/download/v4.4.0/wso2si-4.4.0.zip
```
```
cd ~/wso2 && unzip -q /tmp/wso2si-4.4.0.zip && rm -f /tmp/wso2si-4.4.0.zip
```

Queda instalado en `~/wso2/wso2si-4.4.0`.

### 1.3 Offset de puertos — obligatorio

**Por qué:** el SI usa el puerto **9443** por defecto, que es el mismo puerto de administración de WSO2 API Manager 4.6.0. Si algún día los dos corren en la misma máquina, chocan. Se le aplica un offset de 10 al SI, así APIM se queda con sus puertos nativos.

Editá a mano el archivo `~/wso2/wso2si-4.4.0/conf/server/deployment.yaml`. En el bloque `wso2.carbon:` → `ports:` (alrededor de la línea 28) cambiá:

```
    offset: 0
```

por:

```
    offset: 10
```

Con el offset aplicado, los puertos del SI quedan así:

| Servicio | Puerto por defecto | Con offset 10 |
|---|---|---|
| API REST del servidor (la usa el extension-installer) | 9090 | **9100** |
| HTTPS de administración | 9443 | **9453** |
| Transporte HTTP | 7070 | 7080 |
| Transporte HTTPS | 7443 | 7453 |

**Segundo paso, imprescindible:** el CLI del extension-installer tiene el puerto hardcodeado en su propia configuración y no lee el offset. Si no lo ajustás, cualquier comando del installer falla con `java.net.ConnectException: Conexión rehusada`. Editá `~/wso2/wso2si-4.4.0/wso2/tools/extension-installer/conf/config.properties` y cambiá la última línea:

```
server.port = 9090
```

por:

```
server.port = 9100
```

### 1.4 Drivers JDBC — hay que convertirlos a bundles OSGi

**Por qué:** el SI no trae drivers JDBC, y no alcanza con copiar el `.jar` a `lib/`: el runtime es OSGi y necesita que el jar sea un bundle. La herramienta `jartobundle.sh` que viene con el producto hace la conversión.

PostgreSQL es el que necesita el agente; MySQL sirve para probar contra la base de AssetPlanner.

```
mkdir -p /tmp/jdbc-raw && cd /tmp/jdbc-raw
```
```
curl -L -o postgresql-42.7.4.jar \
  https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.4/postgresql-42.7.4.jar
```
```
curl -L -o mysql-connector-j-8.4.0.jar \
  https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.4.0/mysql-connector-j-8.4.0.jar
```
```
cd ~/wso2/wso2si-4.4.0 && export JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64 && \
  ./bin/jartobundle.sh /tmp/jdbc-raw/postgresql-42.7.4.jar lib/ && \
  ./bin/jartobundle.sh /tmp/jdbc-raw/mysql-connector-j-8.4.0.jar lib/
```

Verificá que aparezcan los dos bundles generados (el nombre cambia, con guiones bajos):

```
ls -lh ~/wso2/wso2si-4.4.0/lib/ | grep -iE "postgresql_|mysql_connector"
```

⚠️ **No dejes también los `.jar` originales en `lib/`** — quedarían duplicados. Los originales viven en `/tmp/jdbc-raw`, no se copian a `lib/`.

### 1.5 Arreglar `siddhi-io-cdc` — sin esto el CDC no funciona

**El problema:** el `siddhi-io-cdc-2.1.1.jar` que viene dentro de la distribución de SI 4.4.0 **no tiene `META-INF/MANIFEST.MF`**. Es un defecto de empaquetado del producto — el mismo jar publicado en Maven Central tiene el mismo problema. Sin manifest, el runtime no lo carga como bundle OSGi y cualquier app que use `@source(type='cdc', ...)` falla al desplegar con:

```
No extension exist for source:cdc. Please check the required dependencies exist.
```

Al arrancar, el síntoma previo es esta advertencia (fácil de pasar por alto entre el resto del log):

```
Error when loading the OSGi bundle information from .../lib/siddhi-io-cdc-2.1.1.jar
java.io.IOException: Invalid OSGi bundle found in the lib folder
```

**El arreglo** es agregarle un manifest mínimo y después convertirlo con `jartobundle.sh`, que genera los headers OSGi. Con el servidor **detenido**:

```
mv ~/wso2/wso2si-4.4.0/lib/siddhi-io-cdc-2.1.1.jar /tmp/jdbc-raw/
```
```
cd /tmp/jdbc-raw && cp siddhi-io-cdc-2.1.1.jar cdc-fix.jar && \
  printf 'Manifest-Version: 1.0\nCreated-By: jartobundle-fix\n\n' > MANIFEST.MF
```
```
/usr/lib/jvm/temurin-21-jdk-amd64/bin/jar --update --file /tmp/jdbc-raw/cdc-fix.jar \
  --manifest=/tmp/jdbc-raw/MANIFEST.MF
```
```
cd ~/wso2/wso2si-4.4.0 && export JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64 && \
  ./bin/jartobundle.sh /tmp/jdbc-raw/cdc-fix.jar lib/
```

Queda `lib/cdc_fix_1.0.0.jar` (~20 MB) y el original ya no está en `lib/`.

> **Lo que NO funciona, para no perder tiempo:** `./bin/extension-installer.sh install cdc` responde `Configuration for extension: cdc was not found` — el catálogo del installer en 4.4.0 no incluye CDC. Y `jartobundle.sh` sobre el jar original falla con `NoSuchFileException: /META-INF/MANIFEST.MF`, porque la herramienta necesita un manifest para determinar si el jar ya es un bundle. Por eso el manifest se agrega antes.

### 1.6 Arrancar y verificar

```
cd ~/wso2/wso2si-4.4.0 && export JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64 && \
  nohup ./bin/server.sh > /tmp/si.log 2>&1 &
```

Arranca en unos 7 segundos. La línea que confirma el arranque:

```
grep "Streaming Integrator started" /tmp/si.log
```

**Para detenerlo** (no uses `pkill -f wso2si` desde un script: el patrón matchea el propio comando y te mata la shell):

```
for p in $(ps -eo pid,args | grep "wso2si-4.4.0" | grep -v grep | awk '{print $1}'); do kill "$p"; done
```

### 1.7 Prueba de humo del CDC

Verifica que el source `cdc` en modo polling levanta y lee filas nuevas de una tabla. Las apps Siddhi se despliegan copiando el archivo a `~/wso2/wso2si-4.4.0/wso2/server/deployment/siddhi-files/` — el servidor las toma en caliente, sin reiniciar.

Creá ahí un archivo `PruebaCDC.siddhi` con una app que solo lea y loguee, **sin escribir en ninguna tabla**: un `@source(type='cdc', mode='polling', polling.column='<columna de fecha o id>', jdbc.driver.name='org.postgresql.Driver', url=..., table.name=...)` conectado a un `@sink(type='log', prefix='PRUEBA-CDC >>')`.

En el log del servidor tenés que ver:

```
Siddhi App PruebaCDC deployed successfully
```

El CDC en modo polling **arranca desde el final de la tabla**: solo emite filas nuevas, no las históricas. Para comprobar que lee de verdad hay que insertar una fila después de que la app esté desplegada, esperar el intervalo de polling y buscar el evento en el log:

```
grep "PRUEBA-CDC" /tmp/si.log
```

Cuando termines, **borrá la fila de prueba y el archivo `.siddhi`** — el archivo lleva credenciales de base en claro y no debe quedar en el servidor.

> Un warning que **se puede ignorar**: `The following extensions are required for Siddhi app '...': [cdc-mysql]. Please use the Extension Installer to install them.` Lo emite el installer al chequear su propio catálogo, no el runtime. Si la línea siguiente dice `deployed successfully`, la app está corriendo.

### 1.8 Verificado en desarrollo el 2026-09-02

| Qué | Resultado |
|---|---|
| SI 4.4.0 con JDK 21 (Temurin) | ✅ arranca en 6,8 s |
| Offset de puertos 10 | ✅ 9100 / 9453 / 7080 / 7453 |
| Drivers PostgreSQL y MySQL como bundles OSGi | ✅ |
| `siddhi-io-cdc` con el arreglo del manifest | ✅ el source `cdc` carga |
| App con CDC polling desplegada | ✅ `deployed successfully` |
| Captura de una fila nueva | ✅ evento capturado con su `data_json` |

La prueba de captura se hizo insertando una fila marcada en `assetv2.synch_notificacion_queue` (base de desarrollo) y **borrándola inmediatamente después**; la tabla quedó con las mismas 434 filas y el mismo último id (562) que antes de la prueba.

---

## 2. WSO2 Streaming Integrator — ambiente de demo

⏳ **Pendiente.** Se documenta cuando se despliegue. Los pasos son los mismos de §1 con tres diferencias a resolver:

1. **Puertos:** verificar qué ocupa la VM antes de elegir el offset (en la VM de GCP corren APIM y MI nativos, según ADR-011).
2. **Credenciales de base:** en la app Siddhi del agente **no van en claro** en el `.siddhi` — se resuelven por el `deployment.yaml` del SI / secure vault. Las apps de AssetPlanner en `traz-int` tienen usuario y contraseña embebidos; ese patrón no se replica.
3. **Arranque como servicio:** en la VM el SI tiene que levantar solo (unidad systemd), no con `nohup`.

---

## 3. Producción

⏳ **Pendiente.** Solo documentación en esta versión; el pase real lo decide el PM.
