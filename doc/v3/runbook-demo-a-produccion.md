# Runbook — desplegar en DEMO y promover la VM actual a producción

## Objetivo

Los cinco procedimientos para: desplegar las tools nuevas en el DEMO, verificar que la selección
multiempresa esté arriba, correr las pruebas automáticas contra lo desplegado, clonar la VM actual
como nuevo DEMO (`mcp-demo.cloudtrazalog.com`, apagada), y promover la VM actual a producción.
Está escrito para ejecutarlo de punta a punta, y cada paso dice **dónde** se corre.

**No cubre** la instalación inicial de WSO2 (está en [`deployment-gcp.md`](deployment-gcp.md) §4) ni
el detalle de cada tool ([`../mcp/escenarios-de-uso-y-regresion.md`](../mcp/escenarios-de-uso-y-regresion.md)).
Es el mapa de ejecución; los documentos canónicos siguen siendo `deployment-gcp.md` y
[`../mcp/republicar-mcp-server.md`](../mcp/republicar-mcp-server.md).

| | |
|---|---|
| **Fecha** | 2026-10-15 |
| **Estado de partida** | `develop` con **24 operaciones** (11 `man_`, 9 `alm_`, 4 `pan_`); el APIM del DEMO tiene las de antes |
| **VM actual** | `e2-medium`, Rocky Linux 9, `us-east1-b`, sirve `mcp.cloudtrazalog.com` vía Caddy |

### Leyenda de dónde se ejecuta cada paso

| | |
|---|---|
| 🖥️ | Consola web de GCP (`console.cloud.google.com`) |
| ⌨️ | Cloud Shell (el botón `>_` de la consola) |
| 💻 | SSH **dentro** de la VM |
| 🌐 | Navegador: Publisher de WSO2, panel de DNS, Claude.ai |
| 🏠 | Tu máquina local |

---

## ⚠️ Antes de empezar: dos cosas que te van a frenar

**1. El selector multiempresa del login OAuth NO está en `develop`.**

Verificado hoy en `traz-comp-dnato`:

| | `develop` | `develop-v3` |
|---|---|---|
| Selector del **login web** (`views/login_empresa.php`) | ✅ | ✅ |
| Selector del **login OAuth / MCP** (`views/oauth/login_empresa.php`) | ❌ | ✅ |

Si el Dnato del DEMO corre `develop`, un usuario con **más de una empresa no puede conectar el MCP**:
el login corta con *"Su cuenta tiene múltiples empresas asignadas"*. Es el punto 2 de este runbook y
hay que resolverlo **antes** de probar (§2).

**2. El `.car` lleva adentro la IP de la base.**

No es agnóstico del ambiente: empaqueta los datasources tal como están commiteados, apuntando a
desarrollo. Hay que revisarlos antes de buildear (§1, paso 2). Es la causa número uno de "desplegué
y quedó apuntando a la base equivocada".

---

## 1. Desplegar las tools nuevas en el DEMO

Lo que entra: las **4 tools de Herramientas** (`pan_get_herramientas`, `pan_get_herramienta`,
`pan_get_movimientos`, `pan_get_certificaciones`) más la capa `toolsPANAPI`. El APIM pasa de las
operaciones que tenga hoy a **24**.

### Paso 1 — Traer el código

💻 SSH a la VM:

```bash
cd ~/traz-tools && \
git fetch origin && \
git checkout develop && \
git pull origin develop
```

### Paso 2 — Revisar las IPs ANTES de buildear

💻 En la VM, mirar estos tres archivos bajo
`_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/`:

| Archivo | Qué define | ¿Tocarlo? |
|---|---|---|
| `artifacts/data-sources/ToolsDataSource.xml` | PostgreSQL de tools | **SÍ** — poner la IP del ambiente |
| `artifacts/data-sources/AssetPlannerDataSource.xml` | MySQL `assetv2` | **SÍ** — idem |
| `resources/conf/tools/bpmconf.xml` → `bpm_url` | Bonita | **SÍ** — idem |
| `resources/conf/tools/apiconfig.xml` → `api_url`, `dataservices_url` | el MI llamándose a sí mismo | **NO** — `localhost:8290` es correcto en todos los ambientes |

### Paso 3 — Buildear y desplegar el CAR

💻 En la VM:

```bash
cd ~/traz-tools/_backend/api/ToolsAPIProject/ToolsAPIProject && \
mvn clean install && \
unzip -qo target/ToolsAPIProject_1.0.0.car -d /tmp/car-check && \
grep -rh "jdbc:" /tmp/car-check | sed 's/^[[:space:]]*//'
```

Leer esa última salida: **son las IPs que van a quedar en el MI.** Si no son las del ambiente,
volver al paso 2. Recién después:

```bash
cp target/ToolsAPIProject_1.0.0.car /opt/wso2/wso2mi-4.5.0/repository/deployment/server/carbonapps/ && \
sudo systemctl restart wso2mi
```

Confirmar el despliegue y que la ruta nueva existe:

```bash
sudo journalctl -u wso2mi -n 40 | grep -i "Successfully Deployed"
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8290/tools/mcp/mcp/pan/herramientas
```

Un **503** acá es la respuesta correcta: significa que `toolsMCPAPI` está desplegado y solo falta el
JWT del gateway. Un **404** significa que la ruta no entró en el CAR — volver al paso 3.

### Paso 4 — Actualizar la API en el Publisher

🌐 Publisher de la VM (por túnel SSH; 9443 **nunca** se expone):

```bash
ssh -L 9443:localhost:9443 <usuario>@<ip-vm>
```

Y en el navegador, `https://localhost:9443/publisher` → la API *Trazalog MCP API* →
**API Definition** → subir `doc/api/trazalog-operaciones.yaml` → **Save**.

Tiene que quedar en **24 operaciones**.

### Paso 5 — Desplegar revisión y recrear el MCP Server

💻 En la VM:

```bash
cd ~/traz-tools && \
bash scripts/dev/recrear-api-y-mcp.sh
```

Eso es el **dry-run**: no toca nada e imprime cuántas operaciones espera (las cuenta de la OpenAPI
del repo). Si el plan se ve bien:

```bash
bash scripts/dev/recrear-api-y-mcp.sh --apply
```

> **El orden importa.** El script exporta la API tal como está en el APIM y la reimporta: si se corre
> **antes** del paso 4, recrea la API con las operaciones viejas. Es el paso B.2 de
> `republicar-mcp-server.md`, y va después de B.1.

Al terminar, el script deja instrucciones para el último tramo manual, que no se puede automatizar:

🌐 Publisher → **MCP Servers** → **Create MCP Server** → *Start from Existing API* → elegir
*Trazalog MCP API* → seleccionar **las 24 operaciones** → Create → Deploy → Publish.
Después, DevPortal → el MCP Server → **Subscribe to an application**.

---

## 2. Asegurar que la selección multiempresa esté desplegada

### Paso 1 — Ver qué rama corre el Dnato del DEMO

💻 SSH al servidor de Dnato:

```bash
cd /var/www/html/traz-comp-dnato && \
git rev-parse --abbrev-ref HEAD && \
ls application/views/oauth/login_empresa.php
```

- Si el archivo **existe** → el selector OAuth está. Ir al paso 3.
- Si **no existe** → falta, y hay que resolver el paso 2.

### Paso 2 — Llevar el selector OAuth a `develop`

El selector del login OAuth se mergeó solo a `develop-v3` (PR #36 de `traz-comp-dnato`). Hay dos
caminos, y **la elección es tuya**:

| | Qué implica |
|---|---|
| **A. Cherry-pick a `develop`** | Traer solo ese cambio: la vista `views/oauth/login_empresa.php`, el método `empresa()` de `Oauthlogin.php` y la ruta `oauth/login/empresa`. Acotado y reversible |
| **B. Desplegar `develop-v3` en el Dnato del DEMO** | Trae todo lo de v3 de una. Más simple de ejecutar, pero mete en el DEMO cambios que no están validados en la línea de v2 |

Si el DEMO tiene que seguir espejando `develop`, la **A** es la que corresponde. Avisame y la preparo
como PR.

### Paso 3 — Verificar en pantalla

🌐 Con un usuario que tenga **dos o más empresas**, conectar el MCP desde Claude. Después de las
credenciales tiene que aparecer la pantalla de tarjetas con una empresa por tarjeta.

Y con la conexión hecha, preguntarle a Claude *"¿con qué empresa estoy conectado?"* — la tool
`core_get_empresa_actual` tiene que responder la que elegiste.

> Si el usuario tiene **una sola** empresa, el selector no aparece a propósito: se resuelve solo. Para
> probar esto hace falta un usuario con dos.

---

## 3. Ejecutar las pruebas automáticas contra lo desplegado

Hay dos suites y prueban cosas distintas. **Correr las dos.**

### 3.1 Las tools por el camino real (cliente → Caddy → APIM → MI)

Es la única que reproduce lo que hace Claude. Necesita un **JWT real emitido por Dnato**: el emitido
por CLI no sirve, queda con `iss=http://localhost/oauth` y el gateway lo rechaza con `900901`.

💻 En la VM:

```bash
cd ~/traz-tools && \
python3 scripts/dev/validar-tools-e2e.py --desde-log
```

`--desde-log` saca el token del `api.log` del APIM, que tiene que estar en nivel FULL. Si preferís
pasarlo a mano:

```bash
python3 scripts/dev/validar-tools-e2e.py --jwt "$JWT"
```

Descubre las tools solas vía `tools/list`, así que las 4 nuevas de Herramientas entran sin tocar el
script. Verifica, por tool: el status HTTP **en el cable**, que el JSON-RPC sea válido y sin
`isError`, y que el contenido no venga vacío.

> Las dos tools que **escriben** (`alm_crear_pedido_materiales` y `man_create_ot`) solo corren con
> `--escrituras`, y crean registros reales e instancian procesos en Bonita. En el DEMO está bien;
> pensalo dos veces cuando esta VM sea producción.

### 3.2 Los escenarios encadenados

Prueban que las tools se puedan **encadenar**, que es donde aparecen los huecos. Hoy son **15**,
incluido el **E16** de Herramientas.

🏠 Desde tu máquina, con VPN y la base accesible:

```bash
cd /mnt/win/dev/git/traz-tools && \
MI_URL=https://mcp.cloudtrazalog.com python3 scripts/dev/mcp_escenarios.py
```

Tiene que dar **15/15**. Y antes de cualquier cosa, el contrato, que no necesita ni MI ni base:

```bash
python3 scripts/dev/mcp_escenarios.py --solo E7
```

### 3.3 Qué mirar si algo falla

| Síntoma | Dónde mirar |
|---|---|
| `900901` | el JWT no es de Dnato o el issuer no coincide — `[[apim.jwt.issuer]]` del `deployment.toml` |
| `503 identity_missing` | el backend JWT del APIM no llega al MI; revisar `apim.jwt.enable` |
| `404` en una tool nueva | la operación no entró al MCP Server: volver a §1 paso 5 |
| La tool responde 200 pero vacía | mirar la IP del datasource en el CAR (§1 paso 2) |

---

## 4. Clonar la VM como nuevo DEMO, apagada

La idea: la VM actual se queda con `mcp.cloudtrazalog.com` y pasa a ser **producción** (§5); el clon
nuevo toma **`mcp-demo.cloudtrazalog.com`**. Así los conectores ya configurados en Claude siguen
funcionando sin que nadie los toque.

### Paso 1 — Snapshot de la VM actual

⌨️ Cloud Shell:

```bash
gcloud compute disks snapshot <disco-de-la-vm-mcp> \
  --snapshot-names=mcp-snapshot-$(date +%Y%m%d) \
  --zone=us-east1-b
```

### Paso 2 — Crear la VM nueva desde el snapshot

⌨️ Cloud Shell:

```bash
gcloud compute disks create mcp-demo-disk \
  --source-snapshot=mcp-snapshot-$(date +%Y%m%d) \
  --zone=us-east1-b && \
gcloud compute instances create mcp-demo \
  --zone=us-east1-b \
  --machine-type=e2-medium \
  --disk=name=mcp-demo-disk,boot=yes,auto-delete=yes \
  --tags=<los-mismos-tags-de-red-de-la-vm-actual>
```

> Los **tags de red** importan: las reglas de firewall del proyecto se aplican por tag. Si la VM nueva
> no los lleva, no va a poder hablar con Dnato ni con la base. Copiarlos de la VM actual con
> `gcloud compute instances describe <vm-mcp> --zone=us-east1-b --format="value(tags.items)"`.

### Paso 3 — DNS

🌐 En el panel de DNS de `cloudtrazalog.com`: crear el registro **A** de `mcp-demo` apuntando a la IP
externa de la VM nueva. Conviene **reservarla como estática** antes, o al apagar y prender la VM
cambia:

```bash
gcloud compute addresses create mcp-demo-ip --region=us-east1
```

### Paso 4 — Cambiar el dominio en la VM nueva

💻 SSH a `mcp-demo`. Hay **tres** lugares, y los tres tienen que decir lo mismo:

| Dónde | Qué cambiar |
|---|---|
| `deploy/gcp/.env` | `MCP_DOMAIN=mcp-demo.cloudtrazalog.com` y `MCP_RESOURCE_URL=https://mcp-demo.cloudtrazalog.com/trazalog/mcp/1.0/mcp` |
| `systemd/wso2am.service` → `JAVA_OPTS` | `-Dtrazalog.mcp.resource.url=https://mcp-demo.cloudtrazalog.com/trazalog/mcp/1.0/mcp` |
| `deployment.toml` del APIM | `https_endpoint = "https://mcp-demo.cloudtrazalog.com"` |

El PRM que Claude consulta **no está hardcodeado**: el CAR de discovery lo arma desde la system
property `trazalog.mcp.resource.url`. Por eso alcanza con el `JAVA_OPTS` — no hay que rebuildear ese CAR.

Después:

```bash
sudo systemctl daemon-reload && \
sudo systemctl restart wso2am && \
sudo systemctl restart caddy
```

### Paso 5 — Que Let's Encrypt emita el certificado ANTES de apagarla

⚠️ **Este es el paso que se olvida.** Caddy pide el certificado la primera vez que el dominio se
resuelve y le llega tráfico. Si la VM se apaga antes, el día que la prendas no vas a tener TLS y vas
a estar depurando eso en vez de usar el DEMO.

Con el DNS ya propagado, desde cualquier lado:

```bash
curl -sI https://mcp-demo.cloudtrazalog.com/.well-known/oauth-protected-resource | head -3
```

Tiene que responder **200** y con certificado válido. Verificar también que el PRM diga el dominio
nuevo:

```bash
curl -s https://mcp-demo.cloudtrazalog.com/.well-known/oauth-protected-resource
```

El campo `resource` tiene que ser `https://mcp-demo.cloudtrazalog.com/...`. Si dice el dominio viejo,
falta el `JAVA_OPTS` del paso 4.

### Paso 6 — Apagar

⌨️ Cloud Shell:

```bash
gcloud compute instances stop mcp-demo --zone=us-east1-b
```

> Apagada no cobra vCPU ni RAM, pero **el disco se sigue pagando** (~30 GB de persistent disk).

---

## 5. Promover la VM actual a producción

La VM **no se toca de lugar ni de dominio**: ya es `mcp.cloudtrazalog.com`, y ese pasa a ser el
dominio productivo. Lo que cambia es a **qué datos** apunta y con qué cuidados se la trata.

### Paso 1 — Decidir la base de producción

**Esta es la decisión que define todo el resto, y es tuya.** Hoy la VM apunta a una IP de base que
está dentro del `.car`. Las opciones:

| | Implicancia |
|---|---|
| **Producción usa la base actual** | No hay que tocar datasources. El DEMO clonado queda apuntando **a la misma base**, así que lo que se pruebe en DEMO escribe en producción — hay que separarlos sí o sí |
| **Producción estrena base propia** | Hay que cambiar las IPs del `.car` (§1 paso 2), rebuildear y redesplegar, y migrar los datos |

Mientras las dos VMs apunten a la misma base, el DEMO **no es un ambiente separado**: es una segunda
puerta a los mismos datos. Las tools de escritura (`alm_crear_pedido_materiales`, `man_create_ot`)
crean registros reales e instancian procesos en Bonita.

### Paso 2 — Si cambia la base: rebuildear y redesplegar

💻 En la VM de producción, repetir §1 pasos 2 y 3 con las IPs de producción.

### Paso 3 — Revisar lo que apunta al dominio

Como el dominio **no cambia**, esto queda igual y no hay que tocar nada:

- Los conectores ya dados de alta en Claude siguen funcionando.
- El PRM, el `https_endpoint` y el `JAVA_OPTS` ya dicen `mcp.cloudtrazalog.com`.
- Los `redirect_uris` de Dnato (`oauth_clients.php`) son de `claude.ai`, no del MCP: no dependen del
  dominio del servidor.

### Paso 4 — Lo que sí hay que endurecer al pasar a producción

| | Por qué |
|---|---|
| Bajar el `api.log` de FULL | En FULL quedan los JWT completos en el log. Está así para que `validar-tools-e2e.py --desde-log` pueda sacarlos |
| Sacar los wire logs si quedaron | `org.apache.synapse.transport.http.wire` en DEBUG genera muchísimo log y expone headers |
| No correr `--escrituras` | Crea pedidos y OTs reales, con instancia en Bonita |
| Backup antes de cada despliegue | `recrear-api-y-mcp.sh` es destructivo sobre la API: hace backups solo, pero conviene snapshot de la VM |
| Revisar el TTL del token | Son 24 h sin `refresh_token`: en producción el usuario va a tener que reconectar a diario hasta que se implemente (TODO en `jwt.php:69`) |

### Paso 5 — Verificar

Correr §3 completo contra `mcp.cloudtrazalog.com`, **sin `--escrituras`**.

---

## 6. El orden en que conviene hacerlo

```
1. Resolver el selector OAuth multiempresa            (§2 paso 2)   ← bloquea la prueba
2. Desplegar las tools en el DEMO actual              (§1)
3. Correr las dos suites                              (§3)
4. Con todo verde: clonar la VM como mcp-demo         (§4)
5. Decidir la base de producción                      (§5 paso 1)   ← decisión tuya
6. Endurecer la VM actual como producción             (§5 paso 4)
```

Los pasos 1 a 3 se pueden hacer hoy. El 4 depende de que el 3 dé verde —no tiene sentido clonar una
VM con algo roto adentro— y el 5 es una decisión que conviene tomar antes de clonar, porque define si
las dos VMs comparten datos.
