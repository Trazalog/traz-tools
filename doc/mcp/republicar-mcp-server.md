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

### B.2 Desplegar una revisión de la API — **el paso que más se saltea**

#### `Publish` y `Deploy` son cosas distintas, y hacen falta las dos

Esta es la confusión que costó tres republicaciones fallidas. La documentación oficial lo dice sin
ambigüedad:

> *"**API Deploying** is the process of making the API available for invocation via a Gateway. […]
> To invoke an API, it needs to be **published on the Developer Portal as well as deployed on a
> Gateway environment**. You need to create a revision of an API in order to deploy it."*
>
> — [*Deploy an API*](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/api-design-manage/deploy-and-publish/deploy-on-gateway/deploy-api/deploy-an-api.md)

| Acción | Qué hace | Qué NO hace |
|---|---|---|
| **`Publish`** (`Publish` → `Lifecycle`) | la hace visible en el Developer Portal | **no** la pone en el gateway |
| **`Deploy New Revision`** (`Deploy` → `Deployments`) | congela la definición actual en una revisión y **la pone en el gateway** | no cambia su estado de ciclo de vida |

Una API puede figurar como `PUBLISHED` y tener en el gateway una revisión vieja de hace meses. Es
exactamente lo que pasó: `lifeCycleStatus: PUBLISHED`, 17 recursos en el Publisher, **9 en el
gateway**.

**Importar la OpenAPI + `Save` + `Publish` no lleva un solo recurso nuevo al gateway.** Hace falta
`Deploy New Revision`.

#### Los pasos

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

---

### C-bis · La alternativa: borrar el MCP Server y regenerarlo

No hace falta agregar las tools de a una. Se puede **eliminar el MCP Server y volver a crearlo**
desde la API, que regenera todas las tools de golpe.

**Cuándo conviene regenerar** (que es nuestro caso habitual):

- hay **varias** tools nuevas
- cambiaron **descripciones** en el YAML — al regenerar se toman de la API automáticamente, mientras
  que agregando a mano hay que copiar cada descripción a mano en el campo `Description`

**Cuándo conviene agregar a mano:** una sola tool nueva, y el resto de la configuración del server
ya está afinada.

#### Qué se pierde al regenerar — y hay que rehacer sí o sí

El MCP Server nuevo es **otro artefacto**, con otro ID. Esto está **verificado en nuestro
despliegue** (`deployment-gcp.md` §6.3-bis), no es teoría:

| Se pierde | Síntoma si te olvidás | Dónde se repone |
|---|---|---|
| **`endpointConfig`** | **`404`** en todas las tools | `deployment-gcp.md` §6.3-bis (error 2) y §6.3-ter si la UI no lo deja editar |
| **Suscripción de la aplicación** | **`403`** / `900908` en todas las tools | DevPortal → `Applications` → tu app → `Subscriptions` → suscribir **el MCP Server** (no la API) |
| Deploy y Publish | la URL no responde | pasos D y D.2 |

#### ⚠️ El prerrequisito que descubrimos por las malas (2026-08-20)

**Antes de crear o recrear el MCP Server, la API tiene que tener su revisión
DESPLEGADA con todos los recursos** — no alcanza con que el Publisher los muestre.

El Publisher muestra la **working copy**. El gateway sirve la **revisión desplegada**. Si se
agregaron recursos y no se desplegó una revisión nueva, para el gateway esos recursos **no existen**,
y cualquier tool que los referencie queda con `apiOperationMapping` en `null` — silenciosamente.

Así se veía el caso real:

| | |
|---|---|
| Working copy de `Trazalog MCP API` | **17 recursos** |
| Revisión desplegada | **9 recursos** |
| Tools del MCP Server que funcionaban | **las 9 de esa revisión, exactamente** |

Verificarlo antes de tocar nada:

```bash
bash scripts/dev/diag-api-revisiones.sh
```

Si la revisión desplegada tiene menos recursos que la working copy:

**`APIs` → la API → `Deploy` → `Deployments` → `Deploy New Revision`**

Y recién después crear o recrear el MCP Server.

#### Reparar el mapping por REST API no funciona

Se intentó dos veces completar el `apiOperationMapping` con un `PUT` al Publisher REST API, la
segunda con los 17 recursos ya desplegados en el gateway. **El APIM acepta el `PUT` con HTTP 200 y
guarda `null` igual.** No es un problema del payload: el servidor descarta el mapping entrante.

Mientras no esté aplicado el fix [carbon-apimgt#13889](https://github.com/wso2/carbon-apimgt/pull/13889),
**la única vía es recrear el MCP Server** desde la API. `scripts/dev/fix-mcp-mapping.py` sigue
sirviendo para el paso de desplegar la revisión de la API, que sí funciona.

#### Qué son esas dos cosas que hay que reponer, y por qué

Al regenerar, el MCP Server nuevo **nace vacío de configuración propia**. Dos cosas que tenía el
anterior no se heredan, y sin ellas ninguna tool funciona. No son trámites: son las dos piezas que
hacen que una llamada **llegue a destino** y **tenga permiso**.

##### 1. El endpoint — *"¿a dónde mando la llamada?"*

El MCP Server **no ejecuta nada**: es una fachada. Cuando Claude invoca `man_get_kpi_mttr`, el
gateway tiene que reenviar esa llamada al Micro Integrator, que es quien consulta la base.

El **endpoint** es esa dirección de reenvío. El artefacto nuevo no la tiene: sabe qué tools expone,
pero no a qué servidor mandarlas.

| | |
|---|---|
| **Si falta** | todas las tools devuelven **`404`** |
| **Por qué ese código** | el gateway recibe la llamada, no tiene a dónde reenviarla, y contesta "no encontrado" |
| **Valor en esta VM** | `http://localhost:8290/tools/mcp` |
| **Dónde se pone** | **Publisher** → el MCP Server → `API Configurations` → `Endpoints` |

`localhost` porque el APIM y el MI conviven en la misma máquina. Puerto `8290`, que es el del MI —
no el del gateway. Contexto `/tools/mcp`, que es la fachada `toolsMCPAPI` — no `/tools/man` ni
`/tools/alm`. Va en **Production** y en **Sandbox**.

##### 2. La suscripción — *"¿quién tiene permiso para usarlo?"*

En APIM quien consume no es una persona sino una **Application**: un registro que representa al
cliente y que tiene asociadas las credenciales OAuth. Acá, la Application es la identidad con la que
**el conector de Claude** se conecta (ej. `TrazalogDnatoMCP-GCP`).

Una Application no puede usar cualquier cosa: tiene que estar **suscripta** a cada producto que
consume. La suscripción *es* el permiso.

El punto es este: la suscripción vieja quedó apuntando al **MCP Server anterior**, que ya no existe.
La Application conserva sus credenciales y su token sigue siendo válido — pero ya no está suscripta
a nada que exista.

| | |
|---|---|
| **Si falta** | todas las tools devuelven **`403`** (código `900908`) |
| **Por qué ese código** | el token es válido y la firma verifica; lo que falla es el permiso |
| **Cómo reconocerlo** | en el log del APIM aparece el `appName`. Que aparezca es **buena señal**: la identidad funcionó, sólo falta la suscripción |
| **Dónde se hace** | **DevPortal**, no el Publisher |

**Son dos portales distintos.** El endpoint se configura en el **Publisher**
(`:9443/publisher`); la suscripción se hace en el **DevPortal** (`:9443/devportal`).

Pasos, según la documentación oficial:

1. Entrar al **Developer Portal** (`https://<host>:9443/devportal`)
2. Clic en el MCP Server (ej. `Trazalog MCP Server`) para ir a su vista general
3. Clic en **`SUBSCRIBE TO AN APPLICATION`**
4. Elegir la **Application** que ya usa el conector y la **throttling policy** (`Unlimited`)
5. Clic en **`Subscribe`**

> Fuente: [*Subscribe to a MCP
> Server*](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/ai-gateway/mcp-gateway/subscribe-to-a-mcp-server.md)
> — *"You have to **subscribe** to a published MCP Server before using its tools in your
> applications."*

**Suscribí el MCP Server, no la API.** Son dos productos distintos del catálogo y el conector
consume el MCP Server. Estar suscripto a la API no alcanza: es el error más repetido.

##### Cómo verificar que las dos quedaron bien

💻 Desde tu máquina, sin token:

```bash
python3 scripts/dev/mcp-smoke-tools.py
```

| Lo que devuelve | Qué falta |
|---|---|
| **`401` en todas** | **nada** — están bien. El `401` es sólo que no mandaste token |
| `404` en todas | el **endpoint** (punto 1) |
| `500 SIN MAPEO` | las tools quedaron sin operación asociada — ver E.0-ter |

El `403` **no se ve sin token**: sin `Authorization` el gateway corta antes con `401`. Para
distinguirlos hace falta un JWT real (`--jwt "$JWT"`).

#### Mantener Name, Context y Version idénticos

La URL del MCP Server sale del **Context** y la **Version**. Si los repetís exactamente, la URL no
cambia y **el conector de Claude sigue apuntando al mismo lugar**. Si cambiás cualquiera de los dos,
hay que reconfigurar el conector.

> **No verificado:** si APIM permite reusar el mismo `Context` inmediatamente después de borrar el
> server anterior. Si lo rechaza por duplicado, confirmar primero que el borrado se completó.

#### Por línea de comandos (apictl)

La documentación oficial expone estas operaciones en `apictl`, lo que permite hacerlo sin la UI:

```bash
# listar los MCP Servers del entorno (devuelve ID, NAME, VERSION, CONTEXT, STATUS)
apictl get mcp-servers -e <environment>

# ver las revisiones de uno
apictl get mcp-server-revisions -n <nombre> -v <version> -e <environment>
apictl get mcp-server-revisions -n <nombre> -v <version> -q deployed:true -e <environment>

# borrarlo
apictl delete mcp-server -n <nombre> -v <version> -e <environment>

# importarlo desde un proyecto versionado
apictl import mcp-server -f <path al proyecto> -e <environment>
apictl import mcp-server --file <path> --environment <env> --rotate-revision
```

> Fuentes: [*Managing MCP
> Servers*](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/apiops/cli/managing-mcp-servers/managing-mcp-servers.md)
> e [*Importing MCP Servers Via Dev First
> Approach*](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/apiops/cli/managing-mcp-servers/importing-mcp-servers-via-dev-first-approach.md)
> (docs-apim, rama 4.6.0).
>
> **`apictl` no está en uso en este proyecto todavía** — requiere instalarlo e inicializar el
> entorno. Queda anotado como el camino a futuro para que la republicación deje de ser un
> procedimiento de consola: con `import mcp-server` sobre un proyecto versionado, el MCP Server se
> vuelve reproducible desde el repo igual que el `.car`.

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

### E.0-bis Smoke test de las 17 tools, sin necesidad de token

💻 **Terminal local** (el MCP Server es público, no hace falta VPN ni SSH):

```bash
python3 scripts/dev/mcp-smoke-tools.py
python3 scripts/dev/mcp-smoke-tools.py --jwt "$JWT"      # ademas valida datos reales
```

Llama `tools/call` sobre **cada** tool y clasifica la respuesta. **Sin token alcanza para detectar
el error más común de una republicación**, porque el código de respuesta ya distingue los dos casos:

| Respuesta | Significa |
|---|---|
| **`401`** | la tool está **bien mapeada** — el gateway llegó a pedir autenticación |
| **`500`** con `existingAPIOperationMapping is null` | la tool **existe en el MCP Server pero no tiene asociada la operación del backend** |

Ese `500` es el síntoma de una tool agregada sin completar el campo **`Operation`**, o agregada
cuando la API todavía no tenía esa operación desplegada en el gateway. Desde el cliente MCP se ve
como *"The connector's server isn't responding"*, que no orienta a nada.

**Caso real (2026-08-18):** tras la primera republicación, las **9 tools originales** respondían
`401` y las **8 agregadas después** daban `500` sin mapeo — `man_get_lecturas`,
`man_get_preventivos`, `alm_get_depositos`, `alm_get_vencimientos` y las 4 de KPI. El corte fue
exacto entre las que existían al crear el MCP Server y las posteriores. **El paso C no es viable en este estado**: la pantalla `Tools` del Publisher no abre (ver E.0-ter),
así que no hay forma de asociar la `Operation` desde la UI. La salida es **C-bis** — regenerar el
MCP Server desde la API, después de confirmar que la API tiene las 17 operaciones **y** una revisión
desplegada.

---

### E.0-ter El bug de WSO2 detrás de esto — issue #5106

Si al abrir **`API Configurations`** → **`Tools`** el Publisher muestra una pantalla rota con:

```text
TypeError: Cannot read properties of undefined (reading 'toLowerCase')
    at ab (ToolDetails.jsx:229:82)
```

no es un problema de la instalación: es
[**wso2/api-manager#5106**](https://github.com/wso2/api-manager/issues/5106), `Type/Bug`, reportado
contra **4.6.0** y cerrado el 2026-07-09.

**Qué explica el issue.** `findMatchingTemplate()` en `ApiMgtDAO` no encuentra un resource template
que coincida con la operación de la tool, así que el GET del MCP Server devuelve
`apiOperationMapping` en **`null`**. De ahí salen los dos síntomas a la vez:

| Síntoma | Dónde se ve |
|---|---|
| La pantalla `Tools` revienta con el `toLowerCase` | Publisher |
| `500` — *"Cannot invoke `APIOperationMapping.getBackendOperation()` because `existingAPIOperationMapping` is null"* | al invocar la tool |
| *"The connector's server isn't responding"* | en Claude |

**El matching es por `target` + `verb`.** Alcanza con que el verbo o el path de la tool no
correspondan **exactamente** a un recurso de la API referenciada para que el mapping quede en
`null`.

**El fix**
([carbon-apimgt#13889](https://github.com/wso2/carbon-apimgt/pull/13889), mergeado el 2026-06-30)
agrega `validateMCPBackendOperations`, que valida cada backend operation contra los recursos de la
API referenciada y **rechaza las inválidas antes de persistirlas**. Sin ese fix, APIM **deja
guardar** un mapping roto sin avisar. Va por update level (`patch`); mientras no esté aplicado, el
procedimiento de acá abajo evita el problema.

#### ⚠️ Nuestro propio §6.3-ter puede ser el disparador

Los pasos para reproducirlo, según el issue, son: crear el MCP Server desde una API existente y
después **actualizarlo por el Publisher REST API**.

`deployment-gcp.md` §6.3-ter hace exactamente eso: `GET` del MCP Server, agregarle `endpointConfig`,
`PUT`. **Si en ese ciclo el `apiOperationMapping` de alguna tool se pierde o se altera, el `PUT` lo
guarda roto y no protesta.**

Por eso, cada vez que se toque el MCP Server por REST API:

```bash
# ANTES del PUT — guardar el artefacto tal cual esta
curl -s -k "https://localhost:9443/api/am/publisher/v4/mcp-servers/<id>" \
  -H "Authorization: Bearer $TOKEN" > /tmp/mcp-antes.json

# DESPUES del PUT — ninguna tool debe haber quedado sin mapping
curl -s -k "https://localhost:9443/api/am/publisher/v4/mcp-servers/<id>" \
  -H "Authorization: Bearer $TOKEN" \
  | python3 -c "import sys,json;d=json.load(sys.stdin);ops=d.get('operations',[]);\
b=[o.get('target') for o in ops if not o.get('apiOperationMapping')];\
print(f'{len(ops)} tools, {len(b)} sin mapping'); print(b)"
```

Y correr el smoke test de E.0-bis, que detecta lo mismo desde afuera y sin token.

---

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
[ ] Tools nuevas: agregadas a mano (C) O el MCP Server regenerado (C-bis)
[ ]   si se regenero: endpointConfig repuesto (C-bis)
[ ]   si se regenero: aplicacion re-suscripta al MCP Server (C-bis)
[ ]   si se regenero: Name/Context/Version identicos, o conector reconfigurado
[ ] MCP Server desplegado: Deploy > Deployments > Deploy (D)
[ ] MCP Playground muestra la tool nueva (E.0)
[ ] mcp-smoke-tools.py: 0 tools con SIN MAPEO (E.0-bis)
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
| C-bis — `apictl get/delete/import mcp-server` | [*Managing MCP Servers*](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/apiops/cli/managing-mcp-servers/managing-mcp-servers.md) e [*Importing MCP Servers Via Dev First Approach*](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/apiops/cli/managing-mcp-servers/importing-mcp-servers-via-dev-first-approach.md) |
| E.0-ter — bug del `toLowerCase` / mapping null | [wso2/api-manager#5106](https://github.com/wso2/api-manager/issues/5106) y su fix [carbon-apimgt#13889](https://github.com/wso2/carbon-apimgt/pull/13889) |
| C-bis — qué se pierde al regenerar | verificado en el despliegue del 2026-08-11 (`deployment-gcp.md` §6.3-bis) |
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
- **Si se puede reusar el mismo `Context`** inmediatamente después de borrar un MCP Server (C-bis).

### Corregido tras revisión de Rodolfo

- **2026-08-15** — se decía confirmar la asociación al *Key Manager Dnato* y se hablaba de un botón
  **`Edit`** en las APIs. Las dos cosas eran falsas, arrastradas de `openapi-publish-procedure.md`
  (arquitectura anterior).
- **2026-08-18** — los pasos B, C y D estaban reconstruidos por analogía en vez de tomados de la
  documentación. Se reescribieron con los nombres exactos de la documentación oficial de la rama
  `4.6.0`, con el link a cada página en la tabla de arriba.
