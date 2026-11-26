# WSO2 en Trazalog — instalar y redesplegar

## Objetivo

Qué es: todo lo de WSO2 (API Manager y Micro Integrator) que no es de un ambiente en particular: cómo se instala en una máquina de desarrollo (parte 1) y cómo se redespliega un artefacto después de un cambio (parte 2). Para quién: quien desarrolle o pruebe artefactos de WSO2, incluido Claude Code. Cuándo leerlo: al armar una máquina nueva o después de cambiar una API, una secuencia o un servicio de datos. Qué NO cubre: qué ambiente usar para qué ni el servidor compartido de DEV ([`ambientes.md`](ambientes.md)), ni el despliegue en Google Cloud ([`deployment-gcp.md`](../v3/deployment-gcp.md)).

---

## Parte 1 — Instalación de WSO2 API Manager 4.6.0 en DEV

Procedimiento real ejecutado en la workstation del PM (Ubuntu 24).
Referencia para reproducir en entornos TEST y PROD (ver notas al final).

---

### Entorno

| Item | Valor |
|---|---|
| OS | Ubuntu 24 |
| Path de instalación | `/mnt/win/dev/wso2am-4.6.0/` |
| Java | Temurin OpenJDK 21 |
| JAVA_HOME | configurado en `/etc/profile.d/jdk21.sh` |
| Modo | All-in-one (single node, sin profileSetup) |
| Base de datos | H2 embebida (solo DEV — ver sección de notas) |

> **Por qué no `/opt/`**: espacio en disco insuficiente en la partición del sistema.
> La partición montada en `/mnt/win/dev/` tiene el espacio disponible.

---

### 1. Prerequisito: Java 21 Temurin

WSO2 APIM 4.6.0 requiere JDK 21. Verificar antes de continuar:

```bash
java -version
# openjdk version "21.x.x" ...

echo $JAVA_HOME
# /usr/lib/jvm/temurin-21-amd64  (o equivalente)
```

Si `JAVA_HOME` no está seteado, crearlo en `/etc/profile.d/jdk21.sh`:

```bash
export JAVA_HOME=/usr/lib/jvm/temurin-21-amd64
export PATH=$JAVA_HOME/bin:$PATH
```

Luego `source /etc/profile.d/jdk21.sh` o reiniciar la sesión.

---

### 2. Descarga e instalación

```bash
# Descargar el zip oficial desde wso2.com/api-platform/api-manager/
# (requiere cuenta gratuita en wso2.com)

# Descomprimir en el path de destino
cd /mnt/win/dev/
unzip wso2am-4.6.0.zip

# El directorio resultante es /mnt/win/dev/wso2am-4.6.0/

# Dar permisos de ejecución al script principal
chmod +x /mnt/win/dev/wso2am-4.6.0/bin/api-manager.sh
```

---

### 3. Configuración (deployment.toml)

Path: `/mnt/win/dev/wso2am-4.6.0/repository/conf/deployment.toml`

Cambios aplicados sobre el archivo default. Solo se listan las secciones modificadas;
el resto queda con los valores default de WSO2:

```toml
[server]
hostname = "localhost"
mode = "single"

[super_admin]
username = "admin"
password = "admin"
create_admin_account = true

[user_store]
type = "database_unique_id"

[database.apim_db]
type = "h2"

[database.shared_db]
type = "h2"

[[apim.gateway.environment]]
name = "Default"
# todos los endpoints apuntan a localhost (valores default de la instalación)

[apim.analytics]
enable = false
```

> La configuración completa está en el kickoff doc del proyecto.
> H2 es la base embebida de WSO2 — válida solo en DEV, sin datos persistentes entre
> reinstalaciones. Para TEST y PROD usar PostgreSQL (ver E0-INF-05).

---

### 4. Arranque

```bash
cd /mnt/win/dev/wso2am-4.6.0
./bin/api-manager.sh start
```

Seguir los logs durante el primer arranque (~3-4 minutos):

```bash
tail -f repository/logs/wso2carbon.log
```

El servidor está listo cuando aparece en el log:

```
[INFO] WSO2 API Manager started in X seconds
```

Otros comandos útiles:

```bash
./bin/api-manager.sh stop
./bin/api-manager.sh restart
./bin/api-manager.sh status
```

---

### 5. Smoke test ejecutado y validado

#### Consolas web

| Endpoint | URL | Estado |
|---|---|---|
| Publisher | https://localhost:9443/publisher | OK |
| Developer Portal | https://localhost:9443/devportal | OK |
| Admin Console | https://localhost:9443/carbon | OK |

Credenciales: `admin` / `admin`

El browser muestra advertencia de certificado self-signed — aceptar la excepción
para continuar (solo en DEV).

#### Gateway (puerto 8243)

El Gateway usa HTTPS con certificado self-signed. Validar con curl, no con el browser:

```bash
curl -k https://localhost:8243
# Respuesta: "Welcome to WSO2 API Manager" (o similar)
```

#### API HelloWorld

Se creó una API de prueba desde el Publisher, se publicó y se consumió exitosamente
desde el Developer Portal — flujo completo validado.

#### Tunnel ngrok

```bash
ngrok http https://localhost:8243
```

URL pública generada y accesible desde internet — smoke test completo del flujo
MCP end-to-end confirmado.

---

### 6. Notas para reproducir en TEST / PROD

**Puerto 8243 es HTTPS — ngrok requiere esquema explícito:**

```bash
# CORRECTO
ngrok http https://localhost:8243

# INCORRECTO — rompe el handshake SSL
ngrok http 8243
```

**Certificado self-signed en localhost:8243:**
El browser bloquea la conexión directa al Gateway. Usar siempre `curl -k` para
validar el Gateway en DEV. En TEST/PROD configurar un certificado válido.

**Base de datos:**
H2 es solo para DEV. Para TEST y PROD reemplazar las secciones `[database.*]` en
`deployment.toml` con la configuración PostgreSQL correspondiente (ver E0-INF-05).

**Permisos en filesystem NTFS (Windows/WSL):**
Si los scripts `.sh` pierden el bit de ejecución después de descomprimir en una
partición NTFS montada desde Windows:

```bash
find /mnt/win/dev/wso2am-4.6.0/bin -name "*.sh" -exec chmod +x {} \;
```

---

## Parte 2 — Redesplegar artefactos después de un cambio

Este documento responde una sola pregunta: **cambié algo en una API, sequence o
DataService del MI, o en una spec OpenAPI publicada en el APIM — ¿cómo hago
para que ese cambio se vea reflejado en el servidor donde estoy probando?**

Está pensado para vos (Rodolfo) cuando volvés a este proyecto después de un
tiempo y no te acordás el paso exacto, y para Claude Code cuando necesita
verificar un cambio en el MI local antes de abrir un PR. No cubre cómo
instalar WSO2 desde cero (eso es `wso2-install.md`) ni cómo desplegar a la
VM de GCP (eso es `doc/v3/deployment-gcp.md`).

Hay **dos niveles** de artefactos, con mecanismos de redespliegue totalmente
distintos — la confusión más común es tratar de resolver uno con el
procedimiento del otro:

| Nivel | Ejemplos | Vive en | Redespliegue |
|---|---|---|---|
| **MI** (Micro Integrator) | APIs (`toolsMANAPI`, `toolsMCPAPI`, `toolsALMAPI`, `toolsBPMAPI`, `toolsCOREAPI`), sequences (`emprIdFromHeader`, `toolsFault`), DataServices (`ALMDataService`, `MANDataService`, etc.) | `_backend/api/ToolsAPIProject/` (Maven project, este repo) | Recompilar el `.car` y copiarlo al MI — **script**, ver §1 |
| **APIM** (API Manager / Publisher) | APIs publicadas (`Trazalog Operaciones`, `EquiposAPI-TrazalogMCP`), Virtual MCP Servers (`trazalog-operaciones`, `trazalog-equipos`) | Consola del Publisher (`:9443/publisher`) | Re-importar la spec OpenAPI — **manual, consola**, ver §2 |

---

### 1. Redesplegar artefactos del MI (APIs, sequences, DataServices)

**Cuándo:** cambiaste cualquier archivo bajo
`_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/` (por ejemplo,
agregaste una tool a `toolsMCPAPI.xml`, o una query a `ALMDataService.dbs`).

**Script (recomendado):**

```bash
./scripts/dev/rebuild-and-deploy-mi.sh
```

Hace las tres cosas en orden: compila (`./mvnw clean install`), copia el
`.car` resultante a `$MI_HOME/repository/deployment/server/carbonapps/`, y
reinicia el MI (para que tome el `.car` nuevo — copiarlo solo no alcanza si
el MI ya está corriendo).

Usar `--no-restart` si vas a copiar más de un cambio antes de reiniciar, o
si preferís reiniciar el MI vos mismo en otro momento.

**Manual, paso a paso** (si el script no te sirve por algún motivo, o para
entender qué hace):

```bash
cd _backend/api/ToolsAPIProject/ToolsAPIProject
./mvnw clean install
# el .car queda en target/ToolsAPIProject_1.0.0.car

MI_HOME=~/.wso2-mi/micro-integrator/wso2mi-4.5.0   # ajustar si es otro path
cp target/ToolsAPIProject_1.0.0.car "$MI_HOME/repository/deployment/server/carbonapps/"

# reiniciar (copiar el .car con el MI corriendo NO alcanza)
"$MI_HOME/bin/micro-integrator.sh" stop
"$MI_HOME/bin/micro-integrator.sh" start
```

**Cómo confirmar que el redespliegue funcionó:**

```bash
tail -f "$MI_HOME/repository/logs/wso2carbon.log"
```

Buscar `Successfully deployed the Carbon Application : ToolsAPIProject_1.0.0`.
Si en cambio aparece `Undeploying Carbon Application` con un error de
conexión a base de datos, es casi siempre que algún DataService (`.dbs`) no
pudo conectar a su BD al arrancar — el deploy del `.car` es **atómico**: una
sola DataService que falle tira abajo todo el paquete, incluidas las APIs
que no tienen nada que ver con esa BD. No es un bug del cambio que hiciste;
es una característica del CAR de WSO2 MI a tener presente.

**Nota sobre `scripts/dev/setup-mi-b4-car-deploy.sh`:** ese script es
anterior a este documento — quedó de una tarea puntual (ADR-008, bloqueante
B4) y **asume que el `.car` ya está compilado** (no corre Maven). Si lo usás
directamente, compilá primero a mano o usá `rebuild-and-deploy-mi.sh`, que
cubre el ciclo completo.

---

### 2. Redesplegar una API publicada en el APIM (Publisher)

**Cuándo:** cambiaste una spec OpenAPI ya publicada (por ejemplo, agregaste
una operación nueva a `doc/api/trazalog-operaciones.yaml`, o cambiaste una
descripción).

> **Si el cambio agrega o modifica tools de un MCP Server ya publicado, usar
> [`../mcp/republicar-mcp-server.md`](../mcp/republicar-mcp-server.md)** — es el
> procedimiento completo y autocontenido (MI → API → MCP Server → revisión →
> verificación → conector), e incluye los pasos que el resumen de abajo no cubre:
> desplegar revisión, y que el MCP Server **no hereda** las operaciones nuevas de
> la API. Lo de acá abajo alcanza sólo para una API REST común.

Esto **no tiene script** — es un procedimiento de consola, porque el
Publisher de WSO2 APIM no tiene una CLI/API pública simple para esto en este
entorno. Pasos (ya documentados en detalle en
[`openapi-publish-procedure.md`](../api/openapi-publish-procedure.md) §7,
resumidos acá):

1. `https://localhost:9443/publisher` (o el host del APIM correspondiente)
2. Abrir la API (ej. `Trazalog Operaciones`) → **`Edit`**
3. **`API Definition`** → **`Import`** → subir el archivo `.yaml` actualizado
4. **`Save`**
5. Si se agregaron o cambiaron `paths`/`operationId` (no solo texto de
   `description`): hace falta **`Publish`** de nuevo para que el gateway
   tome los cambios.
6. Si el cambio agregó una operación nueva y ya existe un Virtual MCP Server
   generado desde esta API: el MCP Server **no se actualiza solo** — hay que
   ir a **`MCP Servers`** → el server correspondiente → **`Tools`** → agregar
   la tool nueva a mano (o regenerarlo, según qué tan grande sea el cambio).
7. Confirmar que la API sigue asociada al Key Manager **Dnato** después de
   re-importar — re-importar no debería desasociarlo, pero conviene
   verificarlo.

**Cómo confirmar que el redespliegue funcionó:** `tools/list` contra el
Virtual MCP Server debe reflejar el cambio (nueva tool, descripción
actualizada, etc.) — ver el smoke test de
[`virtual-mcp-unificado.md`](../mcp/virtual-mcp-unificado.md) §4 como
plantilla de verificación.

---

### 3. Los dos niveles a la vez

Si el cambio toca ambos (ej: agregaste una tool nueva en `toolsMCPAPI.xml`
**y** la sumaste a `trazalog-operaciones.yaml`), hacer primero **§1** (MI) y
recién después **§2** (APIM) — el Publisher apunta al MI como backend, así
que si el MI todavía no tiene la ruta nueva, la operación nueva del APIM
va a devolver error aunque esté bien configurada del lado del Publisher.

## De dónde salió este documento

Fusionado el 2026-11-26 (unificación de documentación, `DOC-UNIF-2`) a partir de:

- `doc/infra/wso2.md`
- `doc/infra/wso2.md`

El texto se juntó sin reescribirlo; solo se bajaron niveles de título y se ajustaron enlaces. La historia de cada parte está en `git log --follow` de los archivos originales.
