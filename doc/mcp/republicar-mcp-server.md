# Republicar el MCP Server tras agregar o cambiar tools

## Objetivo

Procedimiento operativo para **actualizar un MCP Server que ya está publicado y funcionando**
cuando se agregan tools nuevas, se cambian parámetros de una tool existente, o se modifican sus
descripciones. Está escrito para ejecutarse de punta a punta sin depender de ningún otro documento:
cada paso dice **dónde** se ejecuta (SSH a la VM, navegador, terminal local).

**Cuándo leerlo:** cada vez que se mergea un cambio a `toolsMCPAPI.xml` y/o a
`doc/api/trazalog-operaciones.yaml` y hay que llevarlo a un ambiente donde el MCP Server ya existe.

**Qué NO cubre:** la publicación **inicial** del MCP Server (crear la API, generarlo por primera
vez, suscribir la aplicación) — eso está en [`../v3/deployment-gcp.md`](../v3/deployment-gcp.md)
§6.3. Tampoco cubre la configuración de identidad/OAuth, que es §6.0 y §7 del mismo documento.

| | |
|---|---|
| **Ambientes** | Aplica igual a DEV y a la VM de GCP (`mcp.cloudtrazalog.com`) — cambian los hosts, no los pasos |
| **Duración típica** | 15-25 min, la mayor parte esperando el arranque del MI |
| **Requiere** | Acceso SSH a la VM y credenciales de `admin` del Publisher |

---

## 0. El principio que explica todo el procedimiento

**Hay tres artefactos separados, y ninguno se actualiza solo cuando cambia otro:**

```
toolsMCPAPI.xml  ──►  el .car en el MI        (paso A)
                          │
trazalog-operaciones.yaml ──►  la API en el APIM   (paso B)
                          │
                          └──►  el MCP Server      (paso C)  ← NO hereda de la API
```

Generar el MCP Server desde la API **no** crea un vínculo vivo: es una copia puntual. Si después
agregás una operación a la API, el MCP Server sigue exponiendo la lista de tools vieja. Ese es el
error que más tiempo hace perder, porque nada falla — sencillamente la tool nueva no aparece en
`tools/list`.

Y sobre los dos artefactos del APIM: **guardar no alcanza**. El gateway sirve la última *revisión
desplegada*, no lo que está guardado en el Publisher. Sin desplegar una revisión nueva, los cambios
existen pero no se ven.

---

## 1. Antes de empezar — saber exactamente qué cambió

💻 **En tu máquina local**, en el repo:

```bash
cd <repo>/traz-tools

# Tools implementadas en el MI
grep -o 'uri-template="/mcp/[^"]*"' \
  _backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/apis/toolsMCPAPI.xml \
  | sed 's/uri-template="//;s/"//' | sort -u

# Tools declaradas en la OpenAPI
grep -E '^\s+operationId:' doc/api/trazalog-operaciones.yaml | awk '{print $2}' | sort
```

Las dos listas tienen que tener la misma cantidad. Si no coinciden, **parar acá**: publicar una
OpenAPI que declara una tool que el MI no implementa produce una tool visible que siempre falla.

Anotar tres cosas, porque determinan qué pasos hacen falta:

| Qué cambió | Pasos necesarios |
|---|---|
| Sólo `toolsMCPAPI.xml` (comportamiento interno, mismo contrato) | A, E |
| Tool **nueva** (o `operationId` nuevo) | A, B, C, D, E, F |
| Parámetros o descripción de una tool existente | A, B, D, E, F |
| Sólo texto de `description` en la OpenAPI | B, D, E |

---

## 2. Paso A — Actualizar el MI (el `.car`)

> **Primero el MI, siempre.** El APIM apunta al MI como backend: si publicás la tool en el APIM
> antes de que el MI tenga la ruta, la tool nueva devuelve error aunque el Publisher esté perfecto.

### A.1 ⚠️ Revisar las IPs antes de buildear

💻 **SSH a la VM**, en el clone del repo:

El `.car` **empaqueta la IP del ambiente** en cuatro archivos. Buildear desde un checkout limpio
deja el MI apuntando a la base de desarrollo, **sin fallar de forma visible** (las tools responden
`200` con datos del ambiente equivocado). Ver `deployment-gcp.md` §6.1-bis para el detalle:

| Archivo (bajo `src/main/wso2mi/`) | Qué define | ¿Tocarlo? |
|---|---|---|
| `artifacts/data-sources/ToolsDataSource.xml` | PostgreSQL de tools | **sí** |
| `artifacts/data-sources/AssetPlannerDataSource.xml` | MySQL `assetv2` | **sí** |
| `resources/conf/tools/bpmconf.xml` → `bpm_url` | Bonita | **sí** |
| `resources/conf/tools/apiconfig.xml` | `api_url` / `dataservices_url` | **no** — es el MI llamándose a sí mismo, `localhost` es correcto |

> ⚠️ **Editar siempre `resources/conf/tools/`.** Existe una segunda copia en
> `resources/registry/conf/` que **no se empaqueta** (`resources/artifact.xml` apunta a
> `conf/tools/`) y que tiene valores distintos — es fácil editar la equivocada y no ver ningún
> efecto. Detalle en `deployment-gcp.md` §6.1-bis.

### A.2 Buildear y desplegar

💻 **SSH a la VM**:

```bash
cd ~/traz-tools
git checkout develop-v3 && git pull origin develop-v3
cd _backend/api/ToolsAPIProject/ToolsAPIProject

mvn clean install          # usar el maven del sistema: ./mvnw no viaja en el clone

# verificar que el CAR trae lo esperado ANTES de copiarlo
mkdir -p /tmp/car && unzip -qo target/ToolsAPIProject_1.0.0.car -d /tmp/car
grep -rho 'uri-template="/mcp/[^"]*"' /tmp/car | sed 's/uri-template="//;s/"//' | sort -u
grep -rh "jdbc:" /tmp/car | sed 's/^[[:space:]]*//'     # confirmar el ambiente
rm -rf /tmp/car

sudo systemctl stop wso2mi
sudo cp target/ToolsAPIProject_1.0.0.car \
        $MI_HOME/repository/deployment/server/carbonapps/
sudo systemctl start wso2mi
```

### A.3 Esperar el arranque — no saltearse esto

El MI tarda **~40 segundos**. Cualquier llamada en esa ventana devuelve `101503 Error connecting to
the back end`, que parece un problema de configuración y no lo es.

💻 **SSH a la VM**:

```bash
sudo tail -f $MI_HOME/repository/logs/wso2carbon.log | grep -m1 "started in"
# WSO2 Micro Integrator started in NN seconds
```

### A.4 Probar el MI directo, salteando el APIM

💻 **SSH a la VM** — esto aísla si un problema posterior es del MI o del APIM:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8290/tools/mcp/mcp/alm/stock
# 503 con cuerpo identity_missing = CORRECTO: el MI está sano y la ruta existe.
# (503 es la respuesta esperada sin el header de identidad que inyecta el APIM)
# 404 = la ruta no está en el CAR desplegado -> volver a A.2
```

Repetir con la ruta de cada tool nueva, ej. `/tools/mcp/mcp/man/lecturas`.

---

## 3. Paso B — Actualizar la API en el Publisher

> **Todo lo que sigue está tomado de la documentación oficial de WSO2 API Manager, rama `4.6.0`**
> (repositorio [`wso2/docs-apim`](https://github.com/wso2/docs-apim/tree/4.6.0)). Los nombres de los
> ítems del menú son los que usa esa documentación, no una reconstrucción.

🌐 **Navegador.** Si el Publisher no está expuesto, abrir primero un túnel SSH desde tu máquina:

```bash
ssh -L 9443:localhost:9443 <usuario>@<vm>
# y después entrar a https://localhost:9443/publisher
```

**No hay ningún botón `Edit`.** Al abrir una API se entra directamente a su vista de trabajo y se
navega por el menú de la izquierda.

1. **`APIs`** → abrir la API (ej. `Trazalog MCP`)
2. **`API definition`** — abre la definición en el editor Swagger integrado. Ahí se sube el
   `doc/api/trazalog-operaciones.yaml` actualizado.
3. Guardar.

> Fuente: [*Edit an API by modifying the API
> Definition*](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/tutorials/edit-an-api-by-modifyng-the-api-definition.md)
> — *"Click on **API definition** to view the API Definition in the swagger UI."*

### B.2 Desplegar una revisión de la API

Guardar la definición **no** la publica en el gateway. Hay que desplegar una revisión nueva:

1. Ir a la sección **`Deploy`** y hacer clic en **`Deployments`**
2. Clic en **`Deploy New Revision`**
3. Opcionalmente, una descripción para la revisión
4. Seleccionar los **API Gateways** donde desplegarla
5. Clic en **`Deploy`**

> **Máximo 5 revisiones.** Al llegar al límite hay que borrar una antes de crear otra.
>
> Fuente: [*deploy-revision*](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/includes/design/deploy-revision.md),
> el include oficial que la documentación reusa en todas las páginas de despliegue.

### B.3 Qué confirmar después de re-importar

- **`Enable Subscription Validation` sigue desactivado.** Sin `azp` (consumerKey) en el JWT de
  Dnato, con la validación activa el gateway responde `403` aunque la firma sea válida.
- **El selector de Key Managers no se toca.** Dnato **no está registrado como Key Manager** — APIM
  4.6.0 no tiene conector genérico para IdPs custom. La validación la resuelve
  `[[apim.jwt.issuer]]` en el `deployment.toml`. Ver
  [`virtual-mcp-unificado.md`](virtual-mcp-unificado.md) §2.4.

> Re-importar **reemplaza** la definición: lo editado a mano en el Publisher sobre operaciones se
> pierde. La fuente de verdad es el YAML del repo.

---

## 4. Paso C — Agregar las tools nuevas al MCP Server

**Acá está la respuesta a "¿cómo le digo al MCP que tome esa revisión?": no se le dice.**

El MCP Server **no toma revisiones de la API**. El vínculo con la API existe **una sola vez, al
crearlo**: en ese momento se eligen qué operaciones se convierten en tools. Después son dos
artefactos independientes, cada uno con sus propias revisiones y sus propios despliegues.

Por eso, una operación nueva en la API **no aparece sola** como tool: hay que agregarla a mano.

🌐 **Navegador**, mismo Publisher:

1. **`MCP Servers`** → abrir el server (ej. `Trazalog MCP Server`)
2. En el menú de la izquierda: **`API Configurations`** → **`Tools`**
   *(esta vista lista todas las tools generadas a partir de los recursos de la API)*
3. Clic en **`Add New Tool`**
4. Completar los campos:

   | Campo | Qué va |
   |---|---|
   | **`Operation`** | el recurso de la API sobre el que se basa la tool |
   | **`Description`** | contexto suficiente para que el LLM entienda qué hace |
   | **`Tool Name`** | único; usar el mismo `operationId` del YAML |

5. Guardar los cambios.

> Fuente: [*Updating Tools and Deploying the MCP
> Server*](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/ai-gateway/mcp-gateway/update-and-deploy-mcp-server.md)
> — *"In the left navigation menu, go to **API Configurations** → **Tools**"*, *"Click **Add New
> Tool**"*, con los campos **Operation**, **Description** y **Tool Name**.

**Por eso el paso B va antes que este:** el desplegable **`Operation`** ofrece los recursos de la
API, así que la operación tiene que existir ahí primero.

> La documentación oficial **no aclara** si además hace falta que la revisión de la API esté
> desplegada para que la operación aparezca en ese desplegable. Si no aparece, hacer B.2 y volver.

---

## 5. Paso D — Desplegar el MCP Server

Es un despliegue **propio del MCP Server**, aparte del de la API:

1. En el menú de la izquierda: **`Deploy`** → **`Deployments`**
2. Elegir el **`Gateway`** donde desplegarlo
3. Clic en **`Deploy`**
4. Esperar el mensaje de confirmación

> Fuente: *Updating Tools and Deploying the MCP Server*, sección **2. Deploying the MCP Server**
> — *"In the left menu, go to **Deploy** → **Deployments**"*, *"Choose the **Gateway**"*,
> *"Click **Deploy**"*.

### D.2 Publicar, si el estado lo pide

1. **`Publish`** → **`Lifecycle`**
2. Revisar que los nombres y descripciones de las tools estén finalizados
3. Clic en **`Publish`**

> Fuente: misma página, sección **4. Publishing the MCP Server**.

### D.3 Si el endpoint no se deja editar desde la UI

En 4.6.0 el `endpointConfig` del MCP Server puede aparecer deshabilitado o no persistirse. En ese
caso va por el **Publisher REST API**: procedimiento completo y **verificado contra esta VM el
2026-08-11** en `deployment-gcp.md` §6.3-ter.

---

## 6. Paso E — Verificar

### E.0 MCP Playground — la verificación más rápida, sin JWT ni curl

El Publisher trae un cliente MCP incorporado. Es la forma más directa de ver si la tool nueva quedó
expuesta:

1. En el menú de la izquierda: **`Test`** → **`MCP Playground`**
2. Clic en **`Connect`** para establecer sesión con el MCP Server
3. Probar las tools disponibles con valores de ejemplo

> Fuente: *Updating Tools and Deploying the MCP Server*, sección **3. Testing with the MCP
> Playground** — *"The MCP Playground in the Publisher Portal allows you to test tools without
> publishing them."*

Si la tool nueva **no aparece acá**, el problema es el paso C o el D, y no tiene sentido seguir con
los curls de abajo.

💻 **Terminal local.** Para los curls de abajo hace falta un JWT real emitido por el Dnato **de ese
mismo ambiente**.

### E.1 ¿Aparece la tool nueva?

```bash
HOST="mcp.cloudtrazalog.com"
CONTEXTO="trazalog/mcp"        # el que se haya elegido al publicar
JWT="<JWT real de Dnato>"

curl -s -X POST "https://$HOST/$CONTEXTO/1.0/mcp" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $JWT" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}' \
  | python3 -c "import sys,json;[print(' ',t['name']) for t in json.load(sys.stdin)['result']['tools']]"
```

La lista tiene que coincidir con los `operationId` del YAML. **Si la tool nueva no aparece acá, el
problema es el paso C o el D** — no siguas al E.2.

### E.2 ¿Devuelve datos?

```bash
curl -s -X POST "https://$HOST/$CONTEXTO/1.0/mcp" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $JWT" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"<tool_nueva>","arguments":{}},"id":2}'
```

Los tres errores que aparecen acá y qué significan (detalle en `deployment-gcp.md` §6.3-bis):

| Error | Causa | Paso a rehacer |
|---|---|---|
| `403` / `900908` | la aplicación no está suscripta **al MCP Server** (la API no alcanza) | DevPortal → Subscriptions |
| `404` | `endpointConfig` en `null` | C / D |
| `101503` | el MI arrancando, o endpoint inalcanzable | esperar 40 s (A.3), si no revisar el endpoint |

### E.3 Aislamiento multi-tenant

Repetir E.2 con un JWT de **otra empresa** y confirmar que los datos son distintos y que ninguna ve
los de la otra. Con las tools de lectura nuevas esto es obligatorio: una query MCP sin filtro por
empresa es una fuga silenciosa.

💻 **Terminal local**, alternativa automatizada:

```bash
python3 scripts/dev/mcp_escenarios.py        # escenarios encadenados
python3 scripts/dev/verify-mcp-isolation.py  # aislamiento entre empresas
```

---

## 7. Paso F — Refrescar el conector en Claude

El cliente **cachea la lista de tools** de cuando se conectó. Después de republicar, una sesión ya
abierta puede seguir sin ver la tool nueva aunque `tools/list` por `curl` la devuelva.

🌐 **En Claude** (claude.ai o la app): abrir una **conversación nueva** y preguntar por la tool
nueva. Si sigue sin aparecer, ir a **Configuración → Conectores**, **desconectar** el conector de
Trazalog y **volver a conectarlo**.

> Desconectar y reconectar dispara el flujo OAuth completo de nuevo. Si ahí aparece un error de
> login, el problema es de identidad y no de esta republicación — ver `deployment-gcp.md` §6.2-ter.

---

## 8. Checklist

```
[ ] OpenAPI e implementación con la misma cantidad de tools (paso 1)
[ ] IPs del .car revisadas para el ambiente correcto (A.1)
[ ] mvn clean install en verde y .car verificado por dentro (A.2)
[ ] MI arrancado ("started in NN seconds") (A.3)
[ ] curl directo al MI: 503 identity_missing en cada ruta nueva (A.4)
[ ] OpenAPI re-importada en API definition + guardada (B.1)
[ ] Revisión nueva de la API desplegada: Deploy > Deployments > Deploy New Revision (B.2)
[ ] Enable Subscription Validation sigue DESACTIVADO (B.3)
[ ] Tools nuevas agregadas: API Configurations > Tools > Add New Tool (C)
[ ] MCP Server desplegado: Deploy > Deployments > Deploy (D)
[ ] MCP Playground muestra la tool nueva (E.0)
[ ] tools/list muestra la tool nueva (E.1)
[ ] tools/call devuelve datos reales (E.2)
[ ] Aislamiento verificado con dos empresas (E.3)
[ ] Conector reconectado y la tool aparece en Claude (F)
```

---

## 9. Fuentes y estado de verificación

### De dónde sale cada paso

| Paso | Fuente |
|---|---|
| B.1 — `API definition` | [*Edit an API by modifying the API Definition*](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/tutorials/edit-an-api-by-modifyng-the-api-definition.md) (docs-apim, rama 4.6.0) |
| B.2 — `Deploy` → `Deployments` → `Deploy New Revision` | [*deploy-revision*](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/includes/design/deploy-revision.md) |
| C — `API Configurations` → `Tools` → `Add New Tool` | [*Updating Tools and Deploying the MCP Server*](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/ai-gateway/mcp-gateway/update-and-deploy-mcp-server.md) §1 |
| D — `Deploy` → `Deployments` → `Deploy` | misma página, §2 |
| D.2 — `Publish` → `Lifecycle` | misma página, §4 |
| E.0 — `Test` → `MCP Playground` → `Connect` | misma página, §3 |
| El MCP Server no hereda de la API | [*Create a MCP Server Using an Existing API*](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/ai-gateway/mcp-gateway/create-from-api.md) — la selección de operaciones ocurre **sólo al crearlo** |
| A — build, deploy del CAR, arranque, curl directo | verificado contra la VM real (`deployment-gcp.md` §6.1-bis, §6.2) |
| Los 3 errores de E.2 (`403`/`404`/`101503`) | verificados en el despliegue del 2026-08-11 (`deployment-gcp.md` §6.3-bis) |
| D.3 — endpoint por REST API | verificado contra la VM el 2026-08-11 (`deployment-gcp.md` §6.3-ter) |

> El sitio `apim.docs.wso2.com` responde `403` a las descargas automatizadas. La fuente usada es el
> repositorio del que se genera esa documentación, [`wso2/docs-apim`](https://github.com/wso2/docs-apim),
> **rama `4.6.0`**, que es exactamente la versión que corre en esta instalación.

### Lo que la documentación oficial NO dice

- **Si la revisión de la API tiene que estar desplegada** para que su operación aparezca en el
  desplegable `Operation` al agregar una tool. Si no aparece, hacer B.2 y volver a intentar.
- **Si hace falta reconectar el conector en Claude** (paso F) o alcanza con una conversación nueva.
  Lo del paso F es comportamiento del cliente MCP, no del Publisher.

### Corregido tras revisión de Rodolfo

- **2026-08-15** — se decía confirmar la asociación al *Key Manager Dnato* y se hablaba de un botón
  **`Edit`** en las APIs. Las dos cosas eran falsas, arrastradas de `openapi-publish-procedure.md`
  (arquitectura anterior).
- **2026-08-18** — los pasos B, C y D estaban reconstruidos por analogía en vez de tomados de la
  documentación. Se reescribieron con los nombres exactos de la documentación oficial de la rama
  `4.6.0`, con el link a cada página en la tabla de arriba.
