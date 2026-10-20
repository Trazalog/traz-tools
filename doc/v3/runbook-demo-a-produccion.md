# Runbook — desplegar en DEMO y promover la VM a producción

## Objetivo

Los nueve pasos para desplegar en el DEMO las tools nuevas y la selección multiempresa, probarlas, y
después **repuntar esta misma VM a la base de producción** (`10.142.0.2`) y dejar un DEMO nuevo
clonado. Está escrito para ejecutarlo de punta a punta: cada paso dice **dónde** se corre y **cómo se
verifica** que salió bien.

Todo el código ya está mergeado — de acá en adelante es **despliegue y configuración**. El único
bloqueante son las tres passwords de producción (paso 6).

**No cubre** la instalación inicial de WSO2 ([`deployment-gcp.md`](deployment-gcp.md) §4) ni el
detalle de cada tool ([`../mcp/escenarios-de-uso-y-regresion.md`](../mcp/escenarios-de-uso-y-regresion.md)).

| | |
|---|---|
| **Fecha** | 2026-10-15 · reescrito 2026-10-20 (una sola numeración, y el `.car` se arma siempre igual: apéndice A) |
| **Estado objetivo** | **25 operaciones** MCP en el APIM, el selector de empresa andando, y el MI leyendo producción |
| **VM del MCP** | `mcp-trazalog`, `e2-medium`, Rocky Linux 9, `us-east1-b`, sirve `mcp.cloudtrazalog.com` vía Caddy. **No se mueve ni cambia de dominio**: pasa a ser la productiva |
| **Checkout en las VMs** | `~/git/traz-tools` · 🏠 en tu máquina es `/mnt/win/dev/git/traz-tools` |
| **Credenciales** | Nunca se editan archivos versionados. Van a `deploy/gcp/.env.car.demo` y `.env.car.prod`, los dos gitignoreados — apéndice A |

---

## Los 9 pasos

Cada paso es una sección de este documento, con el mismo número. **No ejecutes desde esta tabla**:
usala para saber dónde estás.

| # | Dónde | Qué | Estado |
|---|---|---|---|
| **1** | 🌐 GitHub | Mergear `develop` a `master` en `traz-tools` | ⬜ **falta** |
| **2** | 💻 `vm-demo-trazalog` | El selector de empresa en el Dnato del DEMO | ⬜ |
| **3** | 💻 `mcp-trazalog` | El `.car` y las 25 operaciones en el DEMO | ⬜ |
| **4** | 🌐 navegador | Probar con un usuario de dos empresas | ⬜ |
| **5** | 💻 🏠 | Las dos suites automáticas | ⬜ |
| **6** | 🏠 vos | Las tres passwords de producción | 🔴 **bloquea del 7 al 9** |
| **7** | 💻 `mcp-trazalog` | Repuntar el MCP a producción | ⬜ |
| **8** | 💻 config del APIM | Reapuntar la cadena de identidad al Dnato de producción | ⬜ |
| **9** | ⌨️ Cloud Shell | Clonar la VM como DEMO nuevo y devolverlo a desarrollo | ⬜ |

**Del 2 al 5 se puede hacer hoy.** El 6 es lo único que frena el resto. El razonamiento del orden
está en el [apéndice B](#apéndice-b--por-qué-el-orden-es-ese).

**Lo que ya está hecho y no hay que volver a hacer:**

| | Cuándo |
|---|---|
| ✅ `traz-comp-dnato` #45 mergeado, tagueado **`v2.5.0.11`** y en `master` | 2026-10-19 |
| ✅ **`v2.5.0.11` desplegado en el Dnato de producción** | 2026-10-20 |
| ✅ `traz-tools` #550, #551 y #553 mergeados a `develop` | 2026-10-19/20 |

El detalle de qué commit es cada cosa y cómo se verificó está en el
[apéndice C](#apéndice-c--qué-se-verificó-del-código).

### Dónde se ejecuta cada paso

| | |
|---|---|
| 🖥️ | Consola web de GCP (`console.cloud.google.com`) |
| ⌨️ | Cloud Shell (el botón `>_` de la consola) |
| 💻 | SSH **dentro** de una VM — siempre se aclara cuál |
| 🌐 | Navegador: GitHub, Publisher de WSO2, panel de DNS, Claude.ai |
| 🏠 | Tu máquina local (con VPN para llegar a las bases) |

### Las VMs

| VM | IP interna | Network tags | Qué corre |
|---|---|---|---|
| `mcp-trazalog` | `10.142.0.18` | `deny-ingress`, **`mcp-gateway`** | MI + APIM de la fachada MCP — la VM de los pasos 3, 7, 8 |
| `vm-demo-trazalog` | `10.142.0.11` | `deny-ingress`, **`vm-demo`** | Bonita DEMO, **Dnato del DEMO**, base de test — paso 2 |
| `vm-production-assetplanner-inst1` | `10.142.0.2` | `deny-ingress`, **`vm-prod`** | Bases y Bonita de **producción** — destino del paso 7 |
| (base de desarrollo) | `10.142.0.13` | — | PostgreSQL `tools_prod_t`, MySQL `assetv2`, Bonita de DEV |

### Las tres cosas que fallan en silencio

Sin un solo error en el log:

1. **El `.car` apuntando a la base equivocada.** Las tools responden `200`, con estructura correcta,
   y datos de otro ambiente. Por eso el apéndice A verifica el `.car` **antes** de desplegarlo, y
   compara host **y** nombre de base: en un mismo host conviven varias bases con esquema equivalente.
2. **El `bpm_url` apuntando al Bonita equivocado.** `alm_crear_pedido_materiales` y `man_create_ot`
   crean pedidos, OTs e instancias de proceso **reales** donde no deberían.
3. **Dnato resolviendo el `empr_id` contra una base distinta de la que lee el MI.** El `empr_id` no
   sale del MCP: sale del JWT que emite Dnato. Devuelve datos de otra empresa, o vacío — paso
   [8.3](#83--que-dnato-y-el-mi-lean-la-misma-base).

---

## 1. Mergear develop a master en traz-tools

En `traz-comp-dnato` el código ya llegó a `master`. En `traz-tools` **todavía no**: falta **una sola
operación**, `/mcp/core/empresa` — o sea `core_get_empresa_actual`, la tool que contesta *"¿con qué
empresa estoy conectado?"*. Sin ella el selector del paso 2 funciona, pero la prueba del paso 4 no se
puede cerrar.

| Rama | Operaciones MCP |
|---|---|
| `develop` | **25** — las 11 `man_`, 9 `alm_`, 4 `pan_` y `core_get_empresa_actual` |
| `master` | **24** — todo eso **menos** `core_get_empresa_actual` |

Lo demás ya está en `master`: las 4 tools de Herramientas, `toolsPANAPI.xml`, `toolsCOREAPI.xml` y
las 48 queries de `PANDataservice.dbs`.

**Verificalo vos** — 💻 en la VM, o 🏠 local cambiando la ruta por `/mnt/win/dev/git/traz-tools`:

```bash
R=~/git/traz-tools && \
F=_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/apis/toolsMCPAPI.xml && \
git -C $R fetch origin && \
echo "master  : $(git -C $R show origin/master:$F  | grep -c 'uri-template="/mcp/')" && \
echo "develop : $(git -C $R show origin/develop:$F | grep -c 'uri-template="/mcp/')"
```

🌐 El PR está abierto: [**#554**](https://github.com/Trazalog/traz-tools/pull/554).

> ⚠️ **Mirá los 17 commits antes de aprobarlo.** El merge no lleva solo la tool: `develop` tiene 17
> commits que `master` no, y van a producción juntos.
>
> | Commit | Qué es |
> |---|---|
> | `e4a6385e` | **La tool** `core_get_empresa_actual` — lo que buscamos |
> | `dba11e71` | actualización dataservice bandeja |
> | `6247f048` | mejoras UI herramientas |
> | `310242cb` | fix doctest: login de 2 pasos |
> | los otros 13 | documentación (este runbook) y merge commits |
>
> Los tres del medio no son de esta tarea y no los analicé: **son decisión de release.** Si no querés
> que entren todavía, la alternativa es un cherry-pick de `e4a6385e` solo — pero `master` y `develop`
> siguen divergiendo y el próximo merge arrastra lo mismo.

**Después del merge, el tag.** `traz-tools` usa su propia serie **`v2.5.1.X`** (el último es
`v2.5.1.16`, del 2026-10-09), no la `v2.5.0.X` de `dnato`: correspondería **`v2.5.1.17`**.

---

## 2. El selector de empresa en el Dnato del DEMO

Lo que entra son **3 archivos** que llegan con un `git pull`: la vista de selección, la ruta y el
método del controller. Sin esto, un usuario con varias empresas no puede conectar el MCP: el login
corta con *"Su cuenta tiene múltiples empresas asignadas. Contacte al administrador..."*.

> El selector del login **web** ya estaba desde antes. El que falta es el del login **OAuth/MCP**,
> que es el que usa Claude: son dos pantallas distintas y **que la web funcione no dice nada sobre el
> MCP** (apéndice C).

### 2.1 — Diagnóstico: qué hay hoy

💻 SSH a `vm-demo-trazalog` (el servidor de Dnato del DEMO, **no** la VM del MCP):

```bash
cd /var/www/html/traz-comp-dnato && \
git rev-parse --abbrev-ref HEAD && \
ls -la application/views/oauth/login_empresa.php 2>&1 && \
grep -c "oauth/login/empresa" application/config/routes.php && \
git status --short
```

| Salida | Significa |
|---|---|
| la rama | Si es `develop-v3`, el selector **ya está** y podés saltar a 2.3 |
| la vista existe o no | Es la pantalla de selección. Si falta, falta el cambio |
| `1` en el `grep` | La ruta está registrada. Un `0` quiere decir que falta, aunque la vista esté |
| el `git status` | **Leelo antes de hacer cualquier pull** — ver el aviso |

> ⚠️ **Si el `git status` muestra archivos modificados, no los descartes a ciegas.**
>
> - **`.htaccess`**: es normal y **no se toca**. Ahí viven los `SetEnv` del ambiente
>   (`DNATO_ISSUER`, `JWT_PRIVATE_KEY_PATH`, …). Está versionado, pero es idéntico en `develop` y
>   `develop-v3` y el cambio no lo toca, así que el pull no lo pisa.
> - **`application/controllers/Oauthlogin.php`**: son los parches de compatibilidad PHP 5.6 que se
>   aplicaron a mano en el servidor (`random_bytes`, dos `??`). **Ya están en el repo**, en las dos
>   ramas. Comparalos antes de descartarlos con `git diff application/controllers/Oauthlogin.php`:
>   si el diff es solo eso, `git checkout -- application/controllers/Oauthlogin.php` y seguí. Si trae
>   algo más, **pará y mandámelo** — es un parche de servidor que no está en el repo, y el pull lo
>   pierde.

### 2.2 — Traer el código

💻 En `vm-demo-trazalog`:

```bash
cd /var/www/html/traz-comp-dnato && \
git fetch origin && \
git checkout develop && \
git pull origin develop
```

Confirmar que llegaron las tres piezas:

```bash
ls -la application/views/oauth/login_empresa.php && \
grep -n "oauth/login/empresa" application/config/routes.php && \
grep -n "public function empresa()" application/controllers/Oauthlogin.php && \
php -l application/controllers/Oauthlogin.php
```

Las cuatro tienen que dar algo: la vista, la ruta, el método y *"No syntax errors detected"*.

> **Lo que este despliegue NO necesita** — para no perder tiempo buscando pasos que no existen:
> `composer install` (no agrega dependencias), migración de base (no hay tabla ni columna nueva),
> tocar `.htaccess` o `deployment.toml` (ninguna variable nueva), claves RS256 nuevas, ni reiniciar
> Apache — PHP se recarga por request.
>
> **La única excepción es OPcache.** Si ese servidor tiene `validate_timestamps=0`, el pull no surte
> efecto hasta recargar:
>
> ```bash
> php -i | grep -E "opcache.enable|validate_timestamps"
> ```
>
> Si `opcache.validate_timestamps` está en `0`, corré `sudo systemctl reload httpd`.

### 2.3 — Verificar que la ruta responde

💻 Desde `vm-demo-trazalog`:

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://demo.cloudtrazalog.com/traz-comp-dnato/oauth/login/empresa
```

| Código | Qué significa |
|---|---|
| **302** | Correcto. Sin sesión OAuth activa el controller redirige — es lo que tiene que hacer |
| **404** | Mirá **cuál**: si es el de CodeIgniter (página HTML *"404 Page Not Found"*), falta la ruta → volver a 2.2. Si es el de Apache, el problema es el vhost, no este cambio |
| **500** | Error de PHP: `sudo tail -50 /var/log/httpd/error_log`. Si menciona sintaxis, es compatibilidad 5.6 |

---

## 3. El .car y las 25 operaciones en el DEMO

Lo que entra: las **4 tools de Herramientas** (`pan_get_herramientas`, `pan_get_herramienta`,
`pan_get_movimientos`, `pan_get_certificaciones`) más la capa `toolsPANAPI`, y
`core_get_empresa_actual`. El APIM pasa a **25 operaciones**.

Son tres cosas en orden, y el orden importa: primero el `.car` en el MI, después la OpenAPI en el
APIM, y al final recrear el MCP Server.

### 3.1 — El `.car` en el MI

💻 En `mcp-trazalog`, traer el código:

```bash
cd ~/git/traz-tools && \
git fetch origin && \
git checkout develop && \
git pull origin develop
```

Y buildear y desplegar con el procedimiento del [**apéndice A**](#apéndice-a--buildear-y-desplegar-el-car),
usando el `.env` de **desarrollo** (`deploy/gcp/.env.car.demo`).

> **Para el DEMO el `.env` no cambia ningún valor**: los de desarrollo son exactamente los que están
> commiteados en los datasources, así que el `.car` queda igual al de un `mvn clean install` a secas.
> Se usa igual, por la verificación: el apéndice A te dice a qué base apunta el `.car`
> **antes** de que lo copies a `carbonapps/`.

Cuando el MI ya reinició, confirmar que la ruta nueva existe:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8290/tools/mcp/mcp/pan/herramientas
```

Un **503** acá es la respuesta correcta: `toolsMCPAPI` está desplegado y solo falta el JWT del
gateway. Un **404** significa que la ruta no entró en el `.car`.

### 3.2 — La OpenAPI en el Publisher

🌐 Publisher de la VM, **por túnel SSH** — el 9443 nunca se expone:

```bash
ssh -L 9443:localhost:9443 <usuario>@<ip-vm>
```

Y en el navegador, `https://localhost:9443/publisher` → la API *Trazalog MCP API* → **API
Definition** → subir `doc/api/trazalog-operaciones.yaml` → **Save**.

Tiene que quedar en **25 operaciones**.

### 3.3 — Recrear la API y el MCP Server

💻 En `mcp-trazalog`, primero el dry-run, que no toca nada e imprime cuántas operaciones espera:

```bash
cd ~/git/traz-tools && \
bash scripts/dev/recrear-api-y-mcp.sh
```

Si el plan se ve bien:

```bash
bash scripts/dev/recrear-api-y-mcp.sh --apply
```

> ⚠️ **Esto va después de 3.2, no antes.** El script exporta la API tal como está en el APIM y la
> reimporta: corrido antes, la recrea con las operaciones viejas. Es el paso B.2 de
> [`../mcp/republicar-mcp-server.md`](../mcp/republicar-mcp-server.md), y va después de B.1.

Al terminar queda el último tramo, que no se puede automatizar. 🌐 Publisher → **MCP Servers** →
**Create MCP Server** → *Start from Existing API* → *Trazalog MCP API* → seleccionar **las 25
operaciones** → Create → Deploy → Publish. Y después, DevPortal → el MCP Server → **Subscribe to an
application**.

---

## 4. Probar con un usuario de dos empresas

### 4.1 — Conseguir el usuario

🏠 Desde tu máquina, con VPN, contra la PostgreSQL del DEMO:

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

> **Hay una asimetría a propósito**: la lista que se **muestra** sale de PostgreSQL, pero la que
> **autoriza** sale de Bonita (`oauth_memberships`). Si la consulta devuelve dos empresas pero en
> Bonita el usuario tiene una sola membresía, **va a ver una sola tarjeta**. No es un bug: es la
> protección de que solo se ofrezca lo que Bonita autoriza.

### 4.2 — La prueba

🌐 Desde Claude, con ese usuario, conectar el conector del MCP:

1. Credenciales → tiene que aparecer **la pantalla de tarjetas**, una por empresa, con logo y nombre.
2. Elegir una y completar la autorización.
3. *"¿con qué empresa estoy conectado?"* → `core_get_empresa_actual` tiene que responder **la que
   elegiste**.
4. *"listame los equipos"* → tienen que ser los de **esa** empresa.
5. Desconectar, volver a conectar eligiendo **la otra**, y repetir 3 y 4. Los datos tienen que
   cambiar.

**El paso 5 es el que realmente prueba multiempresa.** Del 1 al 4 se prueba que la pantalla aparece;
el 5 prueba que la elección **se propaga hasta el dato**.

> Probá también con un usuario de **una sola** empresa: el selector no tiene que aparecer, se
> resuelve solo y el flujo queda igual que antes. Eso confirma que el cambio no rompió el caso común.

### 4.3 — Si algo falla

| Síntoma | Causa más probable |
|---|---|
| *"Su cuenta tiene múltiples empresas asignadas"* | El código viejo sigue activo: el pull no entró, o OPcache lo tiene cacheado (2.2) |
| Aparece la pantalla pero **sin tarjetas** | PostgreSQL no devolvió coincidencias para ese email. Corré la consulta de 4.1 con ese email exacto. El código tiene un fallback que arma las tarjetas con los datos de Bonita: si no se ve ninguna, tampoco hay membresías |
| *"La empresa seleccionada no es válida"* | El `empr_id` elegido no está en `oauth_memberships` de la sesión. Es la validación funcionando: revisá las membresías en Bonita |
| `core_get_empresa_actual` da `404` | La operación no se seleccionó al recrear el MCP Server (3.3) |
| Elige empresa pero los datos son de la otra | Acá sí hay un problema real. Correr el escenario **E15** (paso 5): aísla si el `empr_id` sale del token o quedó fijo |

---

## 5. Las dos suites automáticas

Prueban cosas distintas. **Correr las dos.**

### 5.1 — Las tools por el camino real

Cliente → Caddy → APIM → MI. Es la única que reproduce lo que hace Claude, y necesita un **JWT real
emitido por Dnato**: el emitido por CLI queda con `iss=http://localhost/oauth` y el gateway lo
rechaza con `900901`.

💻 En `mcp-trazalog`:

```bash
cd ~/git/traz-tools && \
python3 scripts/dev/validar-tools-e2e.py --desde-log
```

`--desde-log` saca el token del `api.log` del APIM, que tiene que estar en nivel FULL. Si preferís
pasarlo a mano, `--jwt "$JWT"`.

Descubre las tools solo vía `tools/list`, así que las 5 nuevas entran sin tocar el script. Verifica,
por tool: el status HTTP **en el cable**, que el JSON-RPC sea válido y sin `isError`, y que el
contenido no venga vacío.

> Las dos tools que **escriben** (`alm_crear_pedido_materiales`, `man_create_ot`) solo corren con
> `--escrituras`, y crean registros reales e instancian procesos en Bonita. En el DEMO está bien.
> **Nunca con `--escrituras` cuando esta VM sea producción.**

### 5.2 — Los escenarios encadenados

Prueban que las tools se puedan **encadenar**, que es donde aparecen los huecos. Son **16**: el
**E16** de Herramientas y el **E15**, que es el que verifica multiempresa del lado del dato — que
`core_get_empresa_actual` devuelva la empresa **del token** y no un valor fijo, probándolo con dos
tokens de empresas distintas.

🏠 Desde tu máquina, con VPN:

```bash
cd /mnt/win/dev/git/traz-tools && \
MI_URL=https://mcp.cloudtrazalog.com python3 scripts/dev/mcp_escenarios.py
```

Tiene que dar **16/16**. El contrato OpenAPI ↔ MI se puede chequear solo, sin MI ni base:

```bash
python3 scripts/dev/mcp_escenarios.py --solo E7
```

### 5.3 — Si algo falla

| Síntoma | Dónde mirar |
|---|---|
| `900901` | El JWT no es de Dnato, o el issuer no coincide — `[[apim.jwt.issuer]]` del `deployment.toml` (paso 8) |
| `503 identity_missing` | El backend JWT del APIM no llega al MI: revisar `apim.jwt.enable` |
| `404` en una tool nueva | La operación no entró al MCP Server: volver a 3.3 |
| La tool responde `200` pero vacía | La IP del datasource dentro del `.car`: apéndice A |
| `core_get_empresa_actual` devuelve otra empresa | El `empr_id` no sale del JWT. Correr el **E15**, que lo prueba con dos tokens distintos |

---

## 6. Las tres passwords de producción

🔴 **Es lo único que falta, y bloquea los pasos 7, 8 y 9.** Hosts, puertos, bases y usuarios ya están
confirmados por el PM (2026-10-19) y ya vienen cargados en `deploy/gcp/.env.car.example`.

| | PostgreSQL (tools) | MariaDB (Asset Planner) | Bonita |
|---|---|---|---|
| **Host** | `10.142.0.2` | `10.142.0.2` | `10.142.0.2` |
| **Puerto** | **`5434`** ← no es el 5432 | `3306` | `8080` |
| **Base** | **`trazalog_tools`** | **`asp2tecn`** | — |
| **Usuario** | `postgres` | **`root`** | `admin` |
| **Password** | ⬜ **falta** | ⬜ **falta** | ⬜ **falta** |
| En desarrollo era | `10.142.0.13:5432/tools_prod_t` | `10.142.0.13:3306/assetv2`, user `rootremote` | `10.142.0.13:8080` |

Las dos de base, pedilas a quien administre `vm-production-assetplanner-inst1`; la de Bonita, a quien
administre Bonita de producción.

**Qué se cae si le errás a cada una** — los síntomas son distintos y conviene saber cuál mirar:

| Si está mal… | Se caen | Por qué |
|---|---|---|
| PostgreSQL `trazalog_tools` | las **9 `alm_*`**, las **4 `pan_*`** y `core_get_empresa_actual` | `ALMDataService`, `PANDataservice` y el `getEmpresaById` de `COREDataService` usan `ToolsDataSource` |
| MariaDB `asp2tecn` | las **11 `man_*`** (equipos, OTs, lecturas, preventivos y los 4 KPI) | `MANDataService` y `MANEquiposDataService` usan `AssetPlannerDataSource` |
| Bonita | `alm_crear_pedido_materiales` y `man_create_ot` | son las dos únicas que instancian proceso |

> ⚠️ **No uses los valores de los DataServices viejos del repo**
> (`application/modules/traz-prod-trazasoft/scripts/Server DS backup/`). Dicen
> `jdbc:postgresql://10.142.0.2:5432/tools` — **host correcto, puerto y base equivocados**. Es
> exactamente el caso que falla en silencio.

> ✅ **Lo que ya verifiqué y no te va a dar problema:** que la base MariaDB cambie de nombre
> (`assetv2` → `asp2tecn`) **no rompe ninguna query**. Revisé los `.dbs` y los APIs del `.car`: no
> hay una sola referencia calificada tipo `assetv2.tabla` — las únicas menciones a `assetv2` son
> comentarios. Lo mismo con `tools_prod_t`, que aparece solo en el `<url>` del datasource. Alcanza
> con cambiar las URLs.

> **Si falta cualquiera de las tres, pará acá.** El script del apéndice A se niega a buildear con una
> variable vacía, a propósito: el MI arranca igual con una password inventada, el datasource falla
> recién en la primera query, y el síntoma es *"la tool devuelve vacío"* — que se confunde con un
> problema de datos.

---

## 7. Repuntar el MCP a producción

La VM **no se toca de lugar ni de dominio**: ya es `mcp.cloudtrazalog.com` y ese pasa a ser el
dominio productivo. Lo único que cambia es **a qué datos apunta**, y eso vive adentro del `.car`.

### 7.1 — Fotografiar a dónde apunta hoy

Se hace **primero** y se guarda la salida: es el estado al que volvés si hay rollback. 💻 En
`mcp-trazalog`:

```bash
cd /tmp && rm -rf car-antes && mkdir car-antes && \
unzip -qo /opt/wso2/wso2mi-4.5.0/repository/deployment/server/carbonapps/ToolsAPIProject_1.0.0.car -d car-antes && \
grep -rh "jdbc:" car-antes | sed 's/^[[:space:]]*//' && \
grep -rh "bpm_url" car-antes | sed 's/^[[:space:]]*//'
```

### 7.2 — Probar la conectividad ANTES de buildear

Las tres VMs tienen el tag `deny-ingress`, y en GCP **a igual prioridad el `deny` gana**. Que la VM
del MCP llegue hoy a desarrollo **no implica** que llegue a producción.

💻 En `mcp-trazalog`:

```bash
for p in 5434 3306 8080; do \
  timeout 5 bash -c "</dev/tcp/10.142.0.2/$p" 2>/dev/null \
  && echo "10.142.0.2:$p ABIERTO" || echo "10.142.0.2:$p CERRADO"; \
done
```

Los tres tienen que decir `ABIERTO`. El `8080` ya debería estar, por la regla
`allow-bonita-desde-mcp`. Los otros dos **probablemente no**.

⌨️ Si falta alguno, en Cloud Shell:

```bash
gcloud compute firewall-rules create allow-bases-desde-mcp --network=default --direction=INGRESS --action=ALLOW --rules=tcp:5434,tcp:3306 --source-tags=mcp-gateway --target-tags=vm-prod --priority=900 --description="PostgreSQL 5434 y MariaDB 3306 de PROD desde mcp-trazalog"
```

> **La prioridad `900` no es decorativa.** Con la default (1000) la regla se crea y **no habilita
> nada**, porque empata con el `deny-ingress` y el deny gana. Si el comando se parte en varias líneas
> y el `--priority` queda suelto, pasa exactamente eso. Se arregla con
> `gcloud compute firewall-rules update allow-bases-desde-mcp --priority=900`.

Después de crear la regla, **volver a correr el `for`** hasta que los tres digan `ABIERTO`.

### 7.3 — Buildear y desplegar

💻 En `mcp-trazalog`, traer el código ya mergeado a `master` (paso 1):

```bash
cd ~/git/traz-tools && \
git fetch origin && \
git checkout master && \
git pull origin master
```

Y el mismo procedimiento del [**apéndice A**](#apéndice-a--buildear-y-desplegar-el-car), esta vez con
el `.env` de **producción** (`deploy/gcp/.env.car.prod`).

### 7.4 — Confirmar que los datos son de producción

💻 En `mcp-trazalog`:

```bash
cd ~/git/traz-tools && \
python3 scripts/dev/smoke-tools-mi.py --base http://localhost:8290/tools/mcp --empresa <empr_id_mysql_de_prod> --empresa-pg <empr_id_de_prod>
```

**Sin `--escrituras`. Nunca con `--escrituras` contra producción.**

> **Los dos ids de empresa no son intercambiables**: las `man_*` filtran por `empr_id_mysql` (Asset
> Planner) y las `alm_*`/`pan_*` por `empr_id` (PostgreSQL). Si un grupo trae datos y el otro viene
> vacío, es el id — o un datasource que quedó apuntando a otro ambiente.
>
> **`smoke-tools-mi.py` tiene la lista de tools hardcodeada y está vieja**: cubre 16 rutas
> `man_`/`alm_` y **ninguna `pan_`**. Para ejercitar las de Herramientas usá `validar-tools-e2e.py`,
> que las descubre solo (5.1).

### 7.5 — Si hay que volver atrás

El `.car` es el único artefacto que cambió: el rollback no toca ni el APIM ni el DNS. 💻 En
`mcp-trazalog`, buscar el backup que guardaste en [A.3](#a3--desplegar) y volver a ponerlo:

```bash
ls -lt ~/ToolsAPIProject_1.0.0.car.antes-de-*
```

```bash
sudo cp ~/ToolsAPIProject_1.0.0.car.antes-de-<fecha> \
  /opt/wso2/wso2mi-4.5.0/repository/deployment/server/carbonapps/ToolsAPIProject_1.0.0.car && \
sudo systemctl restart wso2mi
```

Y verificar con el mismo `grep "jdbc:"` de 7.1 que volvió a las IPs de antes.

---

## 8. Reapuntar la cadena de identidad al Dnato de producción

Hay **dos Dnato, uno por ambiente, y ninguno se mueve**: el del DEMO sigue sirviendo el DEMO y el de
producción sigue sirviendo producción. Lo que cambia al promover esta VM es **a qué Dnato le cree los
tokens**. No viaja en el `.car`: son dos archivos de config del APIM.

### 8.1 — El selector en el Dnato de producción

✅ **Hecho el 2026-10-20**: el Dnato de producción corre **`v2.5.0.11`**, el primer tag que contiene
el selector. Si hace falta confirmarlo, 💻 SSH al servidor de Dnato de **producción** (el que sirve
`cloudtrazalog.com`, **no** `vm-demo-trazalog`):

```bash
cd /var/www/html/traz-comp-dnato && \
git describe --tags 2>/dev/null && \
grep -c "oauth/login/empresa" application/config/routes.php && \
ls application/views/oauth/
```

Tiene que decir `v2.5.0.11`, `1`, y que `login_empresa.php` esté en la lista. Si falta, el despliegue
es `git fetch origin --tags && git checkout v2.5.0.11`, y valen **las mismas advertencias del
`git status` de 2.1**: ahí viven los `SetEnv` del ambiente y los parches PHP 5.6.

### 8.2 — Los tres lugares del issuer

El issuer tiene que decir **exactamente lo mismo en los tres**. Si difieren aunque sea en la barra
final, el flujo falla con *issuer mismatch* o con un 404 en el discovery
([`deployment-gcp.md`](deployment-gcp.md) §7.0, §7.1):

| # | Dónde | Qué tiene que decir | ¿Cambiarlo? |
|---|---|---|---|
| 1 | `.htaccess` del Dnato de producción | `DNATO_ISSUER` = su propia URL pública + `/oauth` | **No** — ya es el suyo. Solo leerlo: es el valor de los otros dos |
| 2 | `JAVA_OPTS` del APIM (systemd `wso2am`) | `-Dtrazalog.dnato.oauth.url=<ese issuer>` | **Sí** — hoy dice el del DEMO |
| 3 | `[[apim.jwt.issuer]]` del `deployment.toml` del APIM | `name` y `jwks.url` del Dnato de producción | **Sí** — hoy dice el del DEMO |

**Leer el valor bueno.** 💻 En el servidor de Dnato de producción:

```bash
grep DNATO_ISSUER /var/www/html/traz-comp-dnato/.htaccess
```

**Confirmar que ese issuer responde**, y de paso que hay conectividad y TLS desde la VM del MCP. 💻 En
`mcp-trazalog`, reemplazando `<ISSUER_PROD>`:

```bash
curl -s <ISSUER_PROD>/.well-known/oauth-authorization-server | python3 -m json.tool
```

Tiene que traer `authorization_endpoint`, `token_endpoint`, `jwks_uri` y `registration_endpoint`. Si
devuelve el 404 **de CodeIgniter** (la página HTML), faltan las rutas `oauth/*` en ese servidor.

**Ver a qué Dnato le cree hoy el APIM.** 💻 En `mcp-trazalog`:

```bash
sudo systemctl cat wso2am | grep -n "trazalog.dnato.oauth.url" && \
sudo grep -nA 6 "^\[\[apim.jwt.issuer\]\]" /opt/wso2/wso2am-4.6.0/repository/conf/deployment.toml
```

Los dos van a decir el issuer del DEMO. El primero se cambia con `sudo systemctl edit --full wso2am`
(la línea `Environment="JAVA_OPTS=..."`, dejando **`trazalog.mcp.resource.url` como está**: el
dominio del MCP no cambia); el segundo, editando el `deployment.toml`. Después:

```bash
sudo systemctl daemon-reload && \
sudo systemctl restart wso2am
```

> ⚠️ **Los tokens vigentes dejan de servir.** Al cambiar el issuer, los JWT que emitió el Dnato del
> DEMO pasan a ser inválidos: todo cliente ya conectado tiene que **reconectar** el conector en
> Claude. No es un bug, es lo que tiene que pasar — conviene avisarlo antes.

### 8.3 — Que Dnato y el MI lean la misma base

Acá está el riesgo silencioso. El `empr_id` con el que filtran las tools **no sale del MCP**: sale
del JWT que emite Dnato, y Dnato lo resuelve contra **su** PostgreSQL. Si el MI lee
`trazalog_tools` pero Dnato resuelve contra otra base, el resultado no es un error: son **datos de la
empresa equivocada, o vacío**.

💻 En el servidor de Dnato de producción:

```bash
grep -nE "hostname|'database'|'port'" /var/www/html/traz-comp-dnato/application/config/database.php
```

Tiene que dar los **mismos tres valores** del `.env.car.prod`: `10.142.0.2`, `5434`,
`trazalog_tools`. Si da otra cosa, pará y revisalo **antes** de abrir el MCP a un usuario — no lo vas
a detectar por un log.

> `database.php` está versionado pero cada ambiente tiene el suyo modificado localmente, igual que el
> `.htaccess`. Lo que dice el repo (`10.142.0.13:5432/tools_prod_t`) es el de **desarrollo** y no
> dice nada sobre lo que corre en producción: hay que mirarlo en el servidor.

### 8.4 — Lo que NO cambia

Para no perder tiempo buscándolo: **el dominio** sigue siendo `mcp.cloudtrazalog.com`, así que los
conectores ya dados de alta en Claude siguen funcionando. **El PRM, el `https_endpoint` y el
`trazalog.mcp.resource.url`** ya dicen ese dominio. **Los `redirect_uris` de Dnato**
(`oauth_clients.php`) son de `claude.ai`, no del MCP. Y **la API y el MCP Server del APIM**: cambiar
de base no cambia el contrato, así que no hay que volver a subir la OpenAPI ni recrear el MCP Server
— eso solo hace falta cuando cambian las **operaciones**.

---

## 9. Clonar la VM como DEMO nuevo y devolverlo a desarrollo

La VM actual se queda con `mcp.cloudtrazalog.com` y es la productiva; el clon toma
**`mcp-demo.cloudtrazalog.com`**. Así los conectores ya configurados en Claude siguen funcionando sin
que nadie los toque.

> ⚠️ **El clon se hace de un snapshot del disco, así que hereda el `.car` tal como esté.** Clonando
> **después** del paso 7 —que es el plan—, el DEMO nuevo arranca **apuntando a producción**. Hasta
> que se lo devuelva a desarrollo (9.5), ese "DEMO" **escribe en producción**: pedidos, OTs e
> instancias de Bonita reales. Clonar **antes** del paso 7 ahorra ese trabajo.

### 9.1 — Snapshot y VM nueva

⌨️ Cloud Shell:

```bash
gcloud compute disks snapshot <disco-de-la-vm-mcp> \
  --snapshot-names=mcp-snapshot-$(date +%Y%m%d) \
  --zone=us-east1-b
```

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

> Los **tags de red** importan: las reglas de firewall se aplican por tag. Sin ellos, la VM nueva no
> puede hablar con Dnato ni con la base. Copialos con
> `gcloud compute instances describe mcp-trazalog --zone=us-east1-b --format="value(tags.items)"`.

### 9.2 — DNS

Reservar la IP estática primero, o al apagar y prender la VM cambia:

```bash
gcloud compute addresses create mcp-demo-ip --region=us-east1
```

🌐 Y en el panel de DNS de `cloudtrazalog.com`, crear el registro **A** de `mcp-demo` apuntando a esa
IP.

### 9.3 — El dominio en la VM nueva

💻 SSH a `mcp-demo`. Hay **tres** lugares y los tres tienen que decir lo mismo:

| Dónde | Qué cambiar |
|---|---|
| `deploy/gcp/.env` | `MCP_DOMAIN=mcp-demo.cloudtrazalog.com` y `MCP_RESOURCE_URL=https://mcp-demo.cloudtrazalog.com/trazalog/mcp/1.0/mcp` |
| `systemd/wso2am.service` → `JAVA_OPTS` | `-Dtrazalog.mcp.resource.url=https://mcp-demo.cloudtrazalog.com/trazalog/mcp/1.0/mcp` |
| `deployment.toml` del APIM | `https_endpoint = "https://mcp-demo.cloudtrazalog.com"` |

El PRM que Claude consulta **no está hardcodeado**: el `.car` de discovery lo arma desde la system
property `trazalog.mcp.resource.url`. Por eso alcanza con el `JAVA_OPTS` — ese `.car` no se
rebuildea. Después:

```bash
sudo systemctl daemon-reload && \
sudo systemctl restart wso2am && \
sudo systemctl restart caddy
```

### 9.4 — El issuer, al revés que el paso 8

Este clon es el DEMO, así que su cadena de identidad vuelve al **Dnato del DEMO**. Son los mismos dos
archivos de [8.2](#82--los-tres-lugares-del-issuer), con el issuer de `vm-demo-trazalog` en lugar del
de producción.

### 9.5 — Devolverlo a desarrollo 🔴

**Es obligatorio y es el paso que se olvida.** El mismo procedimiento del
[apéndice A](#apéndice-a--buildear-y-desplegar-el-car) con `deploy/gcp/.env.car.demo` — no hay un
procedimiento inverso: es el mismo comando con el otro `.env`.

```bash
bash ~/git/traz-tools/scripts/deploy/build-car-env.sh deploy/gcp/.env.car.demo
```

La verificación del script sirve igual, invirtiendo qué IP esperás: tiene que decir `10.142.0.13` y
**no quedar rastro de `10.142.0.2`**. Hasta que el `CAR OK` lo confirme, no se lo pases a nadie.

### 9.6 — Que Let's Encrypt emita el certificado ANTES de apagarla

⚠️ **El otro paso que se olvida.** Caddy pide el certificado la primera vez que el dominio resuelve y
le llega tráfico. Si la VM se apaga antes, el día que la prendas no vas a tener TLS y vas a estar
depurando eso en vez de usar el DEMO.

Con el DNS ya propagado, desde cualquier lado:

```bash
curl -s https://mcp-demo.cloudtrazalog.com/.well-known/oauth-protected-resource | python3 -m json.tool
```

Tiene que responder con certificado válido, y el campo `resource` tiene que decir
`https://mcp-demo.cloudtrazalog.com/...`. Si dice el dominio viejo, falta el `JAVA_OPTS` de 9.3.

### 9.7 — Apagar

⌨️ Cloud Shell:

```bash
gcloud compute instances stop mcp-demo --zone=us-east1-b
```

> Apagada no cobra vCPU ni RAM, pero **el disco se sigue pagando** (~30 GB).

---

## Después — endurecer la VM productiva

| | Por qué |
|---|---|
| Bajar el `api.log` de FULL | En FULL quedan los JWT completos en el log. Está así para que `validar-tools-e2e.py --desde-log` pueda sacarlos |
| Sacar los wire logs si quedaron | `org.apache.synapse.transport.http.wire` en DEBUG genera muchísimo log y expone headers |
| Nunca `--escrituras` | Crea pedidos y OTs reales, con instancia en Bonita de producción |
| Snapshot antes de cada despliegue | `recrear-api-y-mcp.sh` es destructivo sobre la API. Hace backups solo, pero el snapshot es el que te salva |
| Revisar el TTL del token | Son 24 h sin `refresh_token`: el usuario va a tener que reconectar a diario hasta que se implemente (TODO en `jwt.php:69`) |
| Borrar las carpetas de build | `~/.cache/traz-car-build/*` tiene el `.env` ya expandido, con las passwords en texto plano |

---

## Apéndice A — Buildear y desplegar el `.car`

**Este es el único procedimiento del `.car`, y es el mismo para los tres casos**: desplegar en el
DEMO (paso 3), repuntar a producción (paso 7) y devolver el clon a desarrollo (paso 9.5). Lo único
que cambia es **qué `.env` se le pasa**.

El `.car` no es agnóstico del ambiente: empaqueta los datasources y el `bpmconf` tal como están
commiteados, apuntando a desarrollo. `build-car-env.sh` los reescribe sobre una **copia** del
proyecto, así que **el checkout nunca se toca** (`git status` queda limpio) y las credenciales viven
solo en el `.env`, que está gitignoreado.

### A.1 — El `.env` del ambiente, una sola vez

💻 En la VM, un archivo por ambiente:

```bash
cd ~/git/traz-tools && \
cp deploy/gcp/.env.car.example deploy/gcp/.env.car.demo && \
cp deploy/gcp/.env.car.example deploy/gcp/.env.car.prod && \
chmod 600 deploy/gcp/.env.car.demo deploy/gcp/.env.car.prod
```

El `.example` trae **los dos juegos de valores**, con el de desarrollo descomentado. En cada archivo
dejás descomentado el bloque que corresponde y comentás el otro:

| Archivo | Qué bloque | Qué falta completar |
|---|---|---|
| `.env.car.demo` | **DESARROLLO** (`10.142.0.13`) | nada: ya vienen las passwords, son las que están commiteadas en los datasources |
| `.env.car.prod` | **PRODUCCIÓN** (`10.142.0.2`) | `PG_PASS`, `MY_PASS` y `BPM_PASS` — paso 6 |

El `chmod 600` no es opcional: el script se niega a correr si el archivo tiene otros permisos, porque
lleva credenciales en texto plano. Y se niega a buildear si falta alguna de las 13 variables.

> Los dos archivos están gitignoreados (`deploy/gcp/.env.car*`, menos el `.example`). Verificalo con
> `git check-ignore -v deploy/gcp/.env.car.prod`.

### A.2 — Buildear

```bash
bash ~/git/traz-tools/scripts/deploy/build-car-env.sh deploy/gcp/.env.car.prod
```

El script **muestra a dónde va a apuntar el `.car` y pide confirmación** antes de hacer nada.
Después:

1. Copia el proyecto Maven a `~/.cache/traz-car-build/<fecha>` — el checkout queda intacto.
2. Reescribe en esa copia el `<url>`, `<username>` y `<password>` de los dos datasources y los tres
   campos de `bpmconf.xml`. Reemplazo textual quirúrgico: no reformatea el resto del archivo.
3. Buildea con `mvn clean install`.
4. Descomprime el `.car` resultante y **verifica** que contenga las tres URLs del `.env`, que siga el
   `localhost:8290` del MI, y que **no haya quedado ninguna IP del ambiente anterior**.
5. Deja el `.car` en tu `$HOME` con permisos `600` y te imprime los comandos de A.3.

Termina con `CAR OK` —y las tres URLs que quedaron adentro— o con `CAR MAL`. **Si dice `CAR MAL`, no
sigas**: te dice qué faltó y sale con código distinto de cero, sin dejar nada desplegado.

```
=============== CAR OK ===============

  Apunta a donde dice el .env, y no quedo nada del ambiente anterior:

    PostgreSQL  10.142.0.2:5434/trazalog_tools
    MariaDB     10.142.0.2:3306/asp2tecn
    Bonita      http://10.142.0.2:8080/bonita

  Archivo : /home/ruiz_rodolfo/ToolsAPIProject_1.0.0-20261020-143000.car
```

> **Por qué el script no despliega solo.** Copiar el `.car` a `carbonapps/` y reiniciar el MI es el
> único paso irreversible de todo esto. Lo hace una persona, después de leer el `CAR OK` — no un
> script que podría estar corriendo con el `.env` equivocado.

### A.3 — Desplegar

El script imprime estos dos comandos ya con la ruta del `.car` que generó y la fecha del build. 💻
Primero **guardar el que está andando** — esto es el rollback:

```bash
sudo cp /opt/wso2/wso2mi-4.5.0/repository/deployment/server/carbonapps/ToolsAPIProject_1.0.0.car \
  ~/ToolsAPIProject_1.0.0.car.antes-de-$(date +%Y%m%d-%H%M%S)
```

Después desplegar, reemplazando `<CAR>` por la ruta que imprimió el script:

```bash
sudo cp <CAR> \
  /opt/wso2/wso2mi-4.5.0/repository/deployment/server/carbonapps/ToolsAPIProject_1.0.0.car && \
sudo systemctl restart wso2mi
```

Y confirmar el deploy:

```bash
sudo journalctl -u wso2mi -n 60 | grep -iE "Successfully Deployed|ERROR|datasource"
```

No tiene que haber errores de datasource.

### A.4 — Qué NO se configura, y por qué

| | Por qué |
|---|---|
| `apiconfig.xml` (`api_url`, `dataservices_url`) | Es el MI **llamándose a sí mismo**: `localhost:8290` vale en todos los ambientes, y el script verifica que siga ahí |
| El `dataservices_url` de `bpmconf.xml` | Igual que arriba |
| El query string de la URL de MariaDB (`?useSSL=false&...`) | Es igual en todos los ambientes. El script lo **conserva** tal cual del archivo |
| El `driverClassName` de las dos bases | No cambia: `com.mysql.cj.jdbc.Driver` funciona contra MariaDB |
| Cualquier cosa bajo `resources/registry/conf/` | **Esa carpeta es huérfana y no entra al `.car`.** Tiene valores contradictorios con `conf/tools/`: editarla no produce ningún efecto y hace perder una tarde |

---

## Apéndice B — Por qué el orden es ese

- El **1** es lo único que falta del lado del código, y es decisión tuya porque arrastra 3 commits
  que no son de esta tarea.
- El **2** y el **3** son independientes entre sí —servidores distintos— pero el **4** necesita los
  dos: la pantalla sale del servidor de Dnato y la respuesta de *"¿con qué empresa estoy conectado?"*
  sale de la VM del MCP.
- El **5** va después del 4 porque el escenario E15 asume la tool desplegada.
- El **6** es lo único que frena del 7 en adelante. Todo lo demás de producción ya está confirmado.
- El **8 va después del 7**: una vez que esta VM lee producción, los tokens los tiene que emitir el
  Dnato de producción. Si hacés el 7 sin el 8, el MCP lee producción pero sigue validando tokens del
  Dnato del DEMO — anda, pero el `empr_id` lo resuelve la base equivocada (8.3).
- El **9 es el último y arrastra trabajo**: el clon hereda el `.car` apuntando a producción y hay que
  devolverlo a desarrollo (9.5) antes de que lo use alguien. Clonar **antes** del 7 ahorra ese
  trabajo, pero el orden es decisión tuya.

---

## Apéndice C — Qué se verificó del código

Esto ya está hecho y mergeado; está acá para no tener que volver a averiguarlo.

### El selector multiempresa (`traz-comp-dnato`)

Son **3 archivos, 385 inserciones / 15 borrados**, en **un solo commit** que existe en dos copias con
el mismo diff: **`b5bdf3e3`** (rama `feat/oauth-seleccion-empresa-develop`, head del PR
[#45](https://github.com/Trazalog/traz-comp-dnato/pull/45)) y **`2c45c9ef`** (el original, en
`develop-v3`). Fecha: 2026-09-02.

```
application/config/routes.php              +1 ruta: $route['oauth/login/empresa']
application/controllers/Oauthlogin.php     +metodo empresa(), + resolucion server-side
application/views/oauth/login_empresa.php  nuevo, 256 lineas
```

| Verificación | Resultado |
|---|---|
| `master` vs `develop` en esos 3 archivos | **Idénticos** |
| Padre de `b5bdf3e3` | `055c8ae`, que es el tag `v2.5.0.10`: el PR está apoyado sobre la última release |
| Cherry-pick de `b5bdf3e3` sobre `master` | **Limpio** — 3 archivos, 385/15 |
| Dependencias del código nuevo en `master` | Ya estaban las tres: `getEmpresasDeUsuario`, `oauth_memberships`, `_resolveCompany` |
| Rutas `oauth/*` en `master` | Ya estaban las 9. Lo único que faltaba era la vista y la ruta décima |
| Diff `v2.5.0.10..v2.5.0.11` | **Exactamente ese commit** — ningún otro commit funcional. No toca el login web, ni la registración, ni nada de v2 |

**La trampa que costó una vuelta:** `v2.5.0.10` **sí** tiene el selector del login **web**
(`application/views/login_empresa.php`), y por eso parecía que multiempresa ya estuviera en
producción. El del login **OAuth/MCP** (`application/views/oauth/login_empresa.php`) **no** estaba:
en su lugar había un corte duro en `Oauthlogin.php:140`. Son dos pantallas distintas — que la web
funcione no dice nada sobre el MCP.

### La tool `core_get_empresa_actual` (`traz-tools`)

PR [#551](https://github.com/Trazalog/traz-tools/pull/551), mergeado a `develop` el 2026-10-19. **No
es un cherry-pick**: el directo de `develop-v3` conflictúa en 4 archivos, porque `develop` tiene las 4
tools de Pañol que `develop-v3` no tiene y viceversa. Se portó bloque por bloque — 221 inserciones,
0 borrados. `mvn clean install` OK, el `.car` contiene los dos recursos nuevos, el escenario **E7**
(contrato OpenAPI ↔ MI) pasa con 25 operaciones, y `COREDataService.dbs` **no se toca**.

### El build por `.env`

PR [#553](https://github.com/Trazalog/traz-tools/pull/553), mergeado a `develop` el 2026-10-20.
Reemplaza el procedimiento viejo de editar tres archivos versionados a mano —que dejaba las
credenciales de producción en texto plano adentro del checkout, con el `git status` sucio para
siempre.

El reemplazo es **textual, no por DOM**, y eso es deliberado: `bpmconf.xml` arranca con la
declaración XML **comentada** (`<!--?xml version="1.0"...?-->`) y los dos datasources no tienen
declaración y usan indentación distinta entre sí. Un round-trip por `minidom` "corrige" las tres
cosas, o sea modifica archivos que hoy funcionan en producción sin ninguna necesidad. Probado con
`diff` byte a byte contra los archivos reales, y con passwords que llevan `&`, `<`, `>` y `"`: solo
cambian los valores pedidos, los tres siguen parseando como XML.

### Una corrección a `deployment-gcp.md` §7.0-bis

Ese documento dice que los commits de emisión de JWT, login OAuth y JWKS están **solo en
`develop-v3`** de `traz-comp-dnato`. **Ya no es cierto**: `develop` tiene hoy las 9 rutas `oauth/*`.
La única diferencia que quedaba era `oauth/login/empresa`, que es justo lo que trajo el PR #45.

Importa para el paso 2: **el Dnato del DEMO puede estar corriendo `develop` perfectamente** y tener
el MCP funcionando. No asumas que si funciona el MCP entonces corre `develop-v3`.
