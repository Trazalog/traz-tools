# Runbook — desplegar en DEMO y promover la VM actual a producción

## Objetivo

Los cinco procedimientos para: desplegar las tools nuevas en el DEMO, **llevar la selección
multiempresa al DEMO** (los dos cambios que la componen, en los dos repos y los dos servidores),
correr las pruebas automáticas contra lo desplegado, clonar la VM actual como nuevo DEMO
(`mcp-demo.cloudtrazalog.com`, apagada), y promover la VM actual a producción.
Está escrito para ejecutarlo de punta a punta, y cada paso dice **dónde** se corre.

**No cubre** la instalación inicial de WSO2 (está en [`deployment-gcp.md`](deployment-gcp.md) §4) ni
el detalle de cada tool ([`../mcp/escenarios-de-uso-y-regresion.md`](../mcp/escenarios-de-uso-y-regresion.md)).
Es el mapa de ejecución; los documentos canónicos siguen siendo `deployment-gcp.md` y
[`../mcp/republicar-mcp-server.md`](../mcp/republicar-mcp-server.md).

| | |
|---|---|
| **Fecha** | 2026-10-15 |
| **Estado de partida** | `develop` con **24 operaciones** (11 `man_`, 9 `alm_`, 4 `pan_`); el APIM del DEMO tiene las de antes |
| **Estado objetivo** | **25 operaciones** — las 24 más `core_get_empresa_actual`, que llega con el PR #551 |
| **VM del MCP** | `e2-medium`, Rocky Linux 9, `us-east1-b`, sirve `mcp.cloudtrazalog.com` vía Caddy |
| **Servidor de Dnato (DEMO)** | `vm-demo-trazalog` (`10.142.0.11`), Apache, checkout en `/var/www/html/traz-comp-dnato`, sirve `https://demo.cloudtrazalog.com/traz-comp-dnato` |
| **PRs que hay que mergear antes** | traz-tools **#551** · traz-comp-dnato **#45** (los dos ya abiertos, ver §0) |

### Leyenda de dónde se ejecuta cada paso

| | |
|---|---|
| 🖥️ | Consola web de GCP (`console.cloud.google.com`) |
| ⌨️ | Cloud Shell (el botón `>_` de la consola) |
| 💻 | SSH **dentro** de la VM |
| 🌐 | Navegador: Publisher de WSO2, panel de DNS, Claude.ai |
| 🏠 | Tu máquina local |

---

## 0. Antes de empezar

### 0.1 Multiempresa son DOS cambios, en DOS repos, y ninguno está en `develop`

"La selección multiempresa" no es una sola cosa. Son dos piezas que se necesitan mutuamente, y las
dos estaban **solo en `develop-v3`**. Verificado archivo por archivo:

| Pieza | Repo | Qué hace | ¿Estaba en `develop`? | PR que lo trae |
|---|---|---|---|---|
| Pantalla de selección en el login OAuth | `traz-comp-dnato` | Que un usuario con varias empresas **pueda** conectar el MCP y elija cuál | ❌ | **#45** |
| Tool `core_get_empresa_actual` | `traz-tools` | Que el agente pueda **contestar** con qué empresa quedó conectado | ❌ | **#551** |

Sin la primera, el login corta con *"Su cuenta tiene múltiples empresas asignadas"* y el usuario no
entra. Sin la segunda, entra y elige, pero **no hay forma de verificar qué eligió** — y por lo tanto
tampoco de dar por buena la prueba del §3.

El selector del login **web** (`views/login_empresa.php`) sí estaba en las dos ramas desde antes. El
que faltaba es el del login **OAuth/MCP** (`views/oauth/login_empresa.php`), que es el que usa Claude.

Los dos PRs **ya están abiertos y verificados**; lo único que falta es tu aprobación y el merge:

| PR | Repo | Base | Cómo se verificó |
|---|---|---|---|
| [#45](https://github.com/Trazalog/traz-comp-dnato/pull/45) | `traz-comp-dnato` | `develop` | Cherry-pick limpio de `2c45c9ef`; `php -l` OK; sin sintaxis de PHP 7.x; las 4 dependencias del código nuevo verificadas una por una en `develop`; **sin migración de base ni cambio de config** |
| [#551](https://github.com/Trazalog/traz-tools/pull/551) | `traz-tools` | `develop` | `mvn clean install` OK y el `.car` contiene los dos recursos nuevos; escenario **E7** (contrato OpenAPI ↔ MI) **PASA** con 25 operaciones; el `COREDataService.dbs` **no se toca** (el recurso que consume ya existía, idéntico en las dos ramas) |

> **Por qué #551 no es un cherry-pick.** El cherry-pick directo del commit de `develop-v3` conflictúa
> en 4 archivos, porque `develop` tiene las 4 tools de Pañol que `develop-v3` no tiene y viceversa.
> Se portó bloque por bloque: **221 inserciones, 0 borrados**.

### 0.2 El `.car` lleva adentro la IP de la base

No es agnóstico del ambiente: empaqueta los datasources tal como están commiteados, apuntando a
desarrollo. Hay que revisarlos antes de buildear (§1, paso 2). Es la causa número uno de "desplegué
y quedó apuntando a la base equivocada".

### 0.3 Una corrección a `deployment-gcp.md` §7.0-bis

Ese documento dice que los commits de emisión de JWT, login OAuth y JWKS están **solo en
`develop-v3`** de `traz-comp-dnato`. **Ya no es cierto**: `develop` tiene hoy las 9 rutas de
`oauth/*` (`authorize`, `token`, `jwks.json`, `oauth-authorization-server`, `openid-configuration`,
`register`, `login`, `login/credentials`, `resume`). La **única** diferencia que quedaba entre las
dos ramas en el flujo OAuth era `oauth/login/empresa`, que es exactamente lo que trae el PR #45.

Importa para el §2: **el Dnato del DEMO puede estar corriendo `develop` perfectamente** y tener el
MCP funcionando. No asumas que si funciona el MCP entonces corre `develop-v3`.

---

## 1. Desplegar las tools nuevas en el DEMO

Lo que entra: las **4 tools de Herramientas** (`pan_get_herramientas`, `pan_get_herramienta`,
`pan_get_movimientos`, `pan_get_certificaciones`) más la capa `toolsPANAPI`, y la tool
`core_get_empresa_actual` del PR #551. El APIM pasa de las operaciones que tenga hoy a **25**.

### Paso 0 — Mergear el PR #551 (🌐 GitHub)

Antes de tocar la VM. Si decidís desplegar sin él, todo el resto de este runbook funciona igual pero
con **24 operaciones** en lugar de 25, y el §2 paso 4 queda sin forma de verificarse: ajustá los
números y saltealo.

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

Tiene que quedar en **25 operaciones**.

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
*Trazalog MCP API* → seleccionar **las 25 operaciones** → Create → Deploy → Publish.
Después, DevPortal → el MCP Server → **Subscribe to an application**.

---

## 2. Llevar la selección multiempresa al DEMO

Son dos despliegues independientes, en dos servidores distintos: la **pantalla** va en el servidor de
Dnato, la **tool** va en la VM del MCP junto con el resto del `.car` (§1). Este capítulo cubre el de
Dnato; el otro ya quedó cubierto por el §1.

### Paso 1 — Diagnóstico: ver qué hay hoy en el servidor de Dnato

💻 SSH a `vm-demo-trazalog` (el servidor de Dnato del DEMO, **no** la VM del MCP):

```bash
cd /var/www/html/traz-comp-dnato && \
git rev-parse --abbrev-ref HEAD && \
ls -la application/views/oauth/login_empresa.php 2>&1 && \
grep -c "oauth/login/empresa" application/config/routes.php && \
git status --short
```

Qué dice cada línea:

| Salida | Significa |
|---|---|
| la rama (`develop`, `develop-v3`, …) | Sobre qué línea está el DEMO. Si es `develop-v3`, el selector **ya está** y el paso 2 no hace falta: pasá al paso 3 |
| el archivo de la vista existe o no | Es la pantalla de selección. Si falta, falta el cambio |
| `1` en el `grep` | La ruta está registrada. Un `0` quiere decir que falta, aunque la vista esté |
| el `git status` | **Leelo con atención antes de hacer cualquier pull** — ver el aviso de abajo |

> ⚠️ **Si el `git status` muestra archivos modificados, no los descartes a ciegas.**
>
> - **`.htaccess` modificado**: es normal y **no se toca**. Ahí viven los `SetEnv` del ambiente
>   (`DNATO_ISSUER`, `JWT_PRIVATE_KEY_PATH`, …). El archivo está versionado, pero es **idéntico en
>   `develop` y `develop-v3`** y el PR #45 no lo toca, así que el pull no lo va a pisar.
> - **`application/controllers/Oauthlogin.php` modificado**: son los parches de compatibilidad PHP
>   5.6 que en su momento se aplicaron a mano en el servidor y nunca volvieron al repo
>   (`random_bytes`, dos `??`). **Ya están en el repo**, en las dos ramas — verificado. Comparalos
>   antes de descartarlos:
>
>   ```bash
>   git diff application/controllers/Oauthlogin.php
>   ```
>
>   Si el diff es solo eso, `git checkout -- application/controllers/Oauthlogin.php` y seguí. Si trae
>   algo más, **pará y mandámelo** — es un parche de servidor que todavía no está en el repo, y el
>   pull lo pierde.

### Paso 2 — Desplegar el selector (solo si falta)

**2.a** 🌐 En GitHub: mergear el PR [#45](https://github.com/Trazalog/traz-comp-dnato/pull/45) a
`develop` de `traz-comp-dnato`.

**2.b** 💻 En `vm-demo-trazalog`, traer el código:

```bash
cd /var/www/html/traz-comp-dnato && \
git fetch origin && \
git checkout develop && \
git pull origin develop
```

**2.c** 💻 Confirmar que llegaron las tres piezas:

```bash
ls -la application/views/oauth/login_empresa.php && \
grep -n "oauth/login/empresa" application/config/routes.php && \
grep -n "public function empresa()" application/controllers/Oauthlogin.php && \
php -l application/controllers/Oauthlogin.php
```

Las cuatro tienen que dar algo: la vista, la ruta, el método, y *"No syntax errors detected"*.

> **Lo que este despliegue NO necesita** — verificado en el PR #45, y vale la pena saberlo para no
> perder tiempo buscando pasos que no existen:
>
> | | Por qué no |
> |---|---|
> | `composer install` | El cambio no agrega dependencias; `composer.json` y `composer.lock` son idénticos entre las dos ramas |
> | Migración de base | No hay tabla ni columna nueva. `seg.memberships_users` y `core.empresas` ya existen |
> | Tocar `.htaccess` ni `deployment.toml` | Ninguna variable de ambiente nueva |
> | Claves RS256 nuevas | Las de JWT ya están y no cambian |
> | Reiniciar Apache | PHP se recarga por request. **Salvo** que ese servidor tenga OPcache con `validate_timestamps=0` — ahí sí: `sudo systemctl reload httpd` |
>
> Para saber si estás en ese caso de OPcache, 💻 en `vm-demo-trazalog`:
>
> ```bash
> php -i | grep -E "opcache.enable|validate_timestamps"
> ```
>
> Si `opcache.validate_timestamps` está en `0`, recargá Apache después del pull. Si está en `1` o
> OPcache no está habilitado, no hace falta.

### Paso 3 — Verificar que la ruta responde, antes de probar con un usuario

💻 Desde `vm-demo-trazalog` mismo:

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://demo.cloudtrazalog.com/traz-comp-dnato/oauth/login/empresa
```

| Código | Qué significa |
|---|---|
| **302** | Correcto. Sin sesión OAuth activa, el controller redirige — es exactamente lo que tiene que hacer |
| **404** | Mirá **cuál** 404: si es el de CodeIgniter (página HTML *"404 Page Not Found"*), falta la ruta → volver al paso 2.c. Si es el de Apache, el problema es el vhost, no este cambio |
| **500** | Error de PHP. `sudo tail -50 /var/log/httpd/error_log` — y si menciona sintaxis, es compatibilidad 5.6 |

### Paso 4 — Probar con un usuario real de dos empresas

Primero **conseguir el usuario**. 🏠 Desde tu máquina, con VPN, contra la PostgreSQL del DEMO:

```sql
SELECT LOWER(TRIM(mu.email)) AS email, count(DISTINCT e.empr_id) AS empresas
  FROM seg.memberships_users mu
  INNER JOIN core.empresas e
          ON ((TRIM(e.nombre)      <> '' AND UPPER(TRIM(e.nombre))      = UPPER(TRIM(mu."group")))
           OR (TRIM(e.descripcion) <> '' AND UPPER(TRIM(e.descripcion)) = UPPER(TRIM(mu."group"))))
 WHERE TRIM(mu."group") <> ''
   AND e.eliminado = false
 GROUP BY 1
HAVING count(DISTINCT e.empr_id) > 1
 ORDER BY 2 DESC;
```

Es la misma consulta que usa `User_model::getEmpresasDeUsuario()`, así que lo que devuelva es
exactamente lo que el usuario va a ver en pantalla.

> **Ojo con una asimetría del diseño**: la lista que se **muestra** sale de PostgreSQL, pero la que
> **autoriza** sale de Bonita (`oauth_memberships`). Si esta consulta devuelve dos empresas pero en
> Bonita el usuario tiene una sola membresía, **va a ver una sola tarjeta**. Eso no es un bug: es la
> protección de que solo se ofrezca lo que Bonita autoriza.

Después, la prueba en sí. 🌐 Desde Claude, con ese usuario, conectar el conector del MCP:

1. Credenciales → tiene que aparecer **la pantalla de tarjetas**, una por empresa, con logo y nombre.
2. Elegir una y completar la autorización.
3. Preguntarle a Claude: *"¿con qué empresa estoy conectado?"* → `core_get_empresa_actual` tiene que
   responder **la que elegiste**. Este paso necesita el PR #551 desplegado (§1).
4. Pedirle algo con datos: *"listame los equipos"* → tienen que ser los de **esa** empresa.
5. Desconectar y volver a conectar eligiendo **la otra** empresa, y repetir 3 y 4. Los datos tienen
   que cambiar.

El paso 5 es el que realmente prueba multiempresa. Los pasos 1-4 prueban que la pantalla aparece; el
5 prueba que la elección **se propaga hasta el dato**, que es lo que importa.

> Con un usuario de **una sola** empresa el selector no aparece, a propósito: se resuelve solo y el
> flujo queda igual que antes. Eso también conviene probarlo, para confirmar que el cambio no rompió
> el caso común.

### Paso 5 — Si algo falla

| Síntoma | Causa más probable |
|---|---|
| *"Su cuenta tiene múltiples empresas asignadas"* | El código viejo sigue activo: el pull no entró, o OPcache lo tiene cacheado (paso 2) |
| Aparece la pantalla pero **sin tarjetas** | PostgreSQL no devolvió coincidencias para ese email. La consulta del paso 4, con ese email exacto. El código tiene un fallback que arma las tarjetas con los datos de Bonita, así que si no se ve ninguna, tampoco hay membresías |
| *"La empresa seleccionada no es válida"* | El `empr_id` elegido no está en `oauth_memberships` de la sesión. Es la validación funcionando: revisá las membresías en Bonita |
| Elige empresa pero los datos son de la otra | Acá sí hay un problema real. Correr el escenario **E15** (§3.2): aísla si el `empr_id` sale del token o quedó fijo |

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

Descubre las tools solas vía `tools/list`, así que las 5 nuevas (4 de Herramientas más
`core_get_empresa_actual`) entran sin tocar el
script. Verifica, por tool: el status HTTP **en el cable**, que el JSON-RPC sea válido y sin
`isError`, y que el contenido no venga vacío.

> Las dos tools que **escriben** (`alm_crear_pedido_materiales` y `man_create_ot`) solo corren con
> `--escrituras`, y crean registros reales e instancian procesos en Bonita. En el DEMO está bien;
> pensalo dos veces cuando esta VM sea producción.

### 3.2 Los escenarios encadenados

Prueban que las tools se puedan **encadenar**, que es donde aparecen los huecos. Con el PR #551
mergeado son **16**: el **E16** de Herramientas y el **E15**, que es el que verifica multiempresa del
lado del dato — que `core_get_empresa_actual` devuelva la empresa **del token** y no un valor fijo,
probándolo con dos tokens de empresas distintas.

> Si no mergeaste el #551, son **15** y el E15 no existe.

🏠 Desde tu máquina, con VPN y la base accesible:

```bash
cd /mnt/win/dev/git/traz-tools && \
MI_URL=https://mcp.cloudtrazalog.com python3 scripts/dev/mcp_escenarios.py
```

Tiene que dar **16/16**. Y antes de cualquier cosa, el contrato, que no necesita ni MI ni base:

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
| `core_get_empresa_actual` da `404` | el PR #551 no está desplegado, o la operación no se seleccionó al recrear el MCP Server (§1 paso 5) |
| `core_get_empresa_actual` devuelve otra empresa | el `empr_id` no sale del JWT. Correr el **E15**, que lo prueba con dos tokens distintos |

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
1. Mergear los dos PRs: dnato #45 y tools #551          (§0.1)        ← decisión tuya
2. Desplegar el selector en vm-demo-trazalog            (§2 pasos 1-3)
3. Desplegar el .car + la OpenAPI en la VM del MCP      (§1)
4. Verificar multiempresa con un usuario de 2 empresas  (§2 paso 4)
5. Correr las dos suites                                (§3)          ← 16/16
6. Con todo verde: clonar la VM como mcp-demo           (§4)
7. Decidir la base de producción                        (§5 paso 1)   ← decisión tuya
8. Endurecer la VM actual como producción               (§5 paso 4)
```

**Por qué en ese orden.** El 2 y el 3 son independientes entre sí —servidores distintos— pero el 4
necesita los dos puestos: la pantalla sale del servidor de Dnato y la respuesta de *"¿con qué empresa
estoy conectado?"* sale de la VM del MCP. El 5 va después del 4 porque el escenario E15 asume que la
tool está desplegada.

Los pasos 1 a 5 se pueden hacer hoy. El 6 depende de que el 5 dé verde —no tiene sentido clonar una
VM con algo roto adentro— y el 7 es una decisión que conviene tomar **antes** de clonar, porque define
si las dos VMs comparten datos.
