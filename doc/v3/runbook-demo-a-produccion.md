# Runbook — desplegar en DEMO y promover la VM actual a producción

## Objetivo

Los cinco procedimientos para: desplegar las tools nuevas en el DEMO, **llevar la selección
multiempresa al DEMO** (los dos cambios que la componen, en los dos repos y los dos servidores),
correr las pruebas automáticas contra lo desplegado, clonar la VM actual como nuevo DEMO
(`mcp-demo.cloudtrazalog.com`, apagada), y **redesplegar el MCP apuntando a la base de producción
`10.142.0.2`**.
Está escrito para ejecutarlo de punta a punta, y cada paso dice **dónde** se corre.

Es **la única guía** que hace falta para los tres cambios — las tools de Herramientas, el login
multiempresa y el repunte a producción. El §0.4 es el índice de qué se toca en cada repo y en cada
servidor; si tenés que empezar por algo, empezá por ahí.

**No cubre** la instalación inicial de WSO2 (está en [`deployment-gcp.md`](deployment-gcp.md) §4) ni
el detalle de cada tool ([`../mcp/escenarios-de-uso-y-regresion.md`](../mcp/escenarios-de-uso-y-regresion.md)).
Es el mapa de ejecución; los documentos canónicos siguen siendo `deployment-gcp.md` y
[`../mcp/republicar-mcp-server.md`](../mcp/republicar-mcp-server.md).

| | |
|---|---|
| **Fecha** | 2026-10-15 · actualizado 2026-10-19 (§5 con el repunte a producción; estado de los PRs al día) |
| **Bases de producción** | PostgreSQL `10.142.0.2:5434/trazalog_tools` (user `postgres`) · MariaDB `10.142.0.2:3306/asp2tecn` (user `root`) · Bonita `10.142.0.2:8080`. Confirmado por el PM el 2026-10-19 — detalle en §5 |
| **Estado de partida** | `develop` con **24 operaciones** (11 `man_`, 9 `alm_`, 4 `pan_`); el APIM del DEMO tiene las de antes |
| **Estado objetivo** | **25 operaciones** — las 24 más `core_get_empresa_actual`, ya mergeada en `develop` |
| **VM del MCP** | `e2-medium`, Rocky Linux 9, `us-east1-b`, sirve `mcp.cloudtrazalog.com` vía Caddy |
| **Servidores de Dnato** | Son **dos, uno por ambiente, y cada uno se queda donde está**. DEMO: `vm-demo-trazalog` (`10.142.0.11`), checkout en `/var/www/html/traz-comp-dnato`, sirve `https://demo.cloudtrazalog.com/traz-comp-dnato`. Producción: el que sirve `cloudtrazalog.com` — el selector también tiene que llegar ahí (§5 paso 7) |
| **Lo único que falta mergear** | traz-comp-dnato **#45** (el selector de empresa). Los de `traz-tools` — **#550** este runbook y **#551** la tool `core_get_empresa_actual` — se mergearon a `develop` el 2026-10-19 |

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

### 0.1 Multiempresa son DOS cambios, en DOS repos — y falta mergear uno

"La selección multiempresa" no es una sola cosa. Son dos piezas que se necesitan mutuamente, y las
dos estaban **solo en `develop-v3`**. Verificado archivo por archivo:

| Pieza | Repo | Qué hace | Estado en `develop` |
|---|---|---|---|
| Pantalla de selección en el login OAuth | `traz-comp-dnato` | Que un usuario con varias empresas **pueda** conectar el MCP y elija cuál | ❌ falta — **PR #45 abierto** |
| Tool `core_get_empresa_actual` | `traz-tools` | Que el agente pueda **contestar** con qué empresa quedó conectado | ✅ mergeada el 2026-10-19 (PR #551) |

Sin la primera, el login corta con *"Su cuenta tiene múltiples empresas asignadas"* y el usuario no
entra. Sin la segunda, entra y elige, pero **no hay forma de verificar qué eligió** — y por lo tanto
tampoco de dar por buena la prueba del §3.

El selector del login **web** (`views/login_empresa.php`) sí estaba en las dos ramas desde antes. El
que faltaba es el del login **OAuth/MCP** (`views/oauth/login_empresa.php`), que es el que usa Claude.

Los dos PRs se verificaron igual; **de los dos, el único que queda pendiente de merge es el #45**:

| PR | Repo | Base | Estado | Cómo se verificó |
|---|---|---|---|---|
| [#45](https://github.com/Trazalog/traz-comp-dnato/pull/45) | `traz-comp-dnato` | `develop` | 🟡 **abierto** | Cherry-pick limpio de `2c45c9ef`; `php -l` OK; sin sintaxis de PHP 7.x; las 4 dependencias del código nuevo verificadas una por una en `develop`; **sin migración de base ni cambio de config** |
| [#551](https://github.com/Trazalog/traz-tools/pull/551) | `traz-tools` | `develop` | ✅ mergeado | `mvn clean install` OK y el `.car` contiene los dos recursos nuevos; escenario **E7** (contrato OpenAPI ↔ MI) **PASA** con 25 operaciones; el `COREDataService.dbs` **no se toca** (el recurso que consume ya existía, idéntico en las dos ramas) |

> **Por qué #551 no es un cherry-pick.** El cherry-pick directo del commit de `develop-v3` conflictúa
> en 4 archivos, porque `develop` tiene las 4 tools de Pañol que `develop-v3` no tiene y viceversa.
> Se portó bloque por bloque: **221 inserciones, 0 borrados**.

### 0.1-bis El commit del selector: cuál es, en qué rama está, y qué tag lo lleva

El mismo cambio tiene que llegar al Dnato del DEMO y al de producción. Es **un solo commit**, y
existe en dos copias con el mismo diff:

| | |
|---|---|
| **Commit para la línea `develop` / `master`** | **`b5bdf3e3`** — rama `feat/oauth-seleccion-empresa-develop`, que es el head del **PR #45** |
| **Commit original** | **`2c45c9ef`** — ramas `develop-v3` y `feat/oauth-seleccion-empresa` |
| **Fecha de los dos** | 2026-09-02 |
| **Tamaño** | 3 archivos, **385 inserciones / 15 borrados** — **idéntico** en las dos copias |
| **¿Tag?** | **Ninguno.** Ni `2c45c9ef` ni `b5bdf3e3` están en ningún tag del repo |

Los tres archivos que toca:

```
application/config/routes.php              +1 ruta: $route['oauth/login/empresa']
application/controllers/Oauthlogin.php     +metodo empresa(), + resolucion server-side
application/views/oauth/login_empresa.php  nuevo, 256 lineas
```

**El mismo commit sirve para el DEMO y para producción** — no hay que portar nada dos veces.
Verificado:

| Verificación | Resultado |
|---|---|
| `master` vs `develop` en esos 3 archivos | **Idénticos** — el `git diff` da vacío |
| Padre de `b5bdf3e3` | `055c8ae`, que es **el tag `v2.5.0.10`**: el PR #45 está apoyado exactamente sobre la última release |
| Cherry-pick de `b5bdf3e3` sobre `master` | **Limpio**, probado: 3 archivos, 385/15, sin conflictos |
| Dependencias del código nuevo en `master` | Ya están las tres: `getEmpresasDeUsuario`, `oauth_memberships`, `_resolveCompany` |
| Rutas `oauth/*` en `master` | Ya están **las 9**. Lo único que le falta es la vista y la ruta décima — que es justo lo que agrega el commit |

**Cómo llega a cada ambiente.** Siguiendo el patrón de release del propio repo — `v2.5.0.10` se
tagueó sobre `develop` (`055c8ae` = merge del PR #44) y después `master` mergió el tag:

```
1. Mergear el PR #45            -> develop            <- habilita el DEMO  (§2)
2. Taguear develop              -> v2.5.0.11
3. Mergear el tag en master     -> master             <- habilita produccion (§5 paso 7)
```

> **En producción lo que manda es el tag, no la rama.** El último es **`v2.5.0.10`** (2026-10-03,
> `055c8ae`, que fue el merge del PR #44 — `fix/reset-password-design`) y **no tiene el selector**.
> Mientras no exista un tag que lo contenga, el Dnato de producción no puede mostrar la pantalla de
> selección, por más que el MCP ya esté apuntando a la base de producción.
>
> ⚠️ **El selector del login web SÍ está en `v2.5.0.10`, y por eso parece que ya estuviera hecho.**
> Son dos pantallas distintas y solo una está en producción:
>
> | Selector | Archivo | ¿En `v2.5.0.10`? |
> |---|---|---|
> | Login **web** (navegador) | `application/views/login_empresa.php` | ✅ **sí** |
> | Login **OAuth/MCP** (el que usa Claude) | `application/views/oauth/login_empresa.php` | ❌ **no** |
>
> O sea: hoy en producción un usuario de varias empresas entra por la web y elige, pero al conectar
> el MCP toma el otro camino y se come el corte duro de `Oauthlogin.php:140` — *"Su cuenta tiene
> múltiples empresas asignadas. Contacte al administrador..."*. **Que la web funcione no dice nada
> sobre el MCP.**
>
> Verificado en el tag: `application/views/oauth/` tiene solo `login_error.php` y `login_step1.php`,
> y `oauth/login/empresa` da **0** ocurrencias en `routes.php`. El único dato que decide es ese `0`:
>
> ```bash
> cd /var/www/html/traz-comp-dnato && \
> git describe --tags && \
> grep -c "oauth/login/empresa" application/config/routes.php && \
> ls application/views/oauth/
> ```

> **`master` está 1 commit adelante de `develop`** (`50d7b95 Merge tag 'v2.5.0.10'`), y `develop`
> está enteramente contenido en `master`. No hay divergencia que resolver entre las dos líneas.

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

### 0.4 Mapa: qué se toca, en qué repo y en qué servidor

Los tres cambios que este runbook despliega — las tools de Pañol, el login multiempresa y el repunte
a producción — toman **dos repos** y **dos servidores**. Esta tabla es el índice: quién toca qué y en
qué capítulo está el procedimiento.

| Cambio | Repo | Servidor donde se despliega | Qué se edita a mano | Capítulo |
|---|---|---|---|---|
| 4 tools de Herramientas (`pan_*`) + capa `toolsPANAPI` | `traz-tools` — ya en `develop` | `mcp-trazalog` (VM del MCP) | nada: viene todo en el `.car` | **§1** |
| Tool `core_get_empresa_actual` | `traz-tools` — ya en `develop` (PR #551) | `mcp-trazalog`, el **mismo** `.car` | nada | **§1** |
| Pantalla de selección de empresa en el login OAuth | `traz-comp-dnato` — **PR #45, falta mergear** | `vm-demo-trazalog` (servidor de Dnato) | nada: 3 archivos que llegan con el `git pull` | **§2** |
| Repunte de las bases a producción | `traz-tools` — **no se commitea** | `mcp-trazalog` | **3 archivos** del proyecto Maven, en el checkout de la VM | **§5** pasos 4-6 |
| El selector, otra vez, en el Dnato de **producción** | `traz-comp-dnato` — **falta el tag `v2.5.0.11`** | servidor de Dnato de producción | nada: `git checkout` del tag | **§5** paso 7.a |
| Cadena de identidad del MCP → Dnato de producción | ninguno: es **config**, no código | `mcp-trazalog` | **2 archivos** de config del APIM (`JAVA_OPTS` y `deployment.toml`) | **§5** paso 7.b |

> **¿Hay que tocar Dnato? Sí: el mismo commit, en dos servidores distintos.**
>
> Hay dos instancias de Dnato, una por ambiente, y **ninguna se mueve**: la del DEMO sigue sirviendo
> el DEMO y la de producción sigue sirviendo producción. Lo que viaja es el commit del selector:
>
> | | Qué se hace | Qué lo habilita | Riesgo |
> |---|---|---|---|
> | Dnato del **DEMO** (§2) | `git pull origin develop` | Mergear el **PR #45** | Bajo: aditivo, sin migración ni config nueva |
> | Dnato de **producción** (§5 paso 7.a) | `git checkout` del tag | Taguear `v2.5.0.11` y mergearlo a `master` | Bajo: es el mismo commit, y el cherry-pick sobre `master` ya se probó limpio |
>
> El commit exacto, su rama y por qué todavía no hay tag: **§0.1-bis**.
>
> Lo que **sí** cambia al promover el MCP es a qué Dnato le pide los tokens: son 2 archivos de config
> del APIM, en la VM del MCP, no en Dnato (§5 paso 7.b). Y queda una verificación silenciosa que no
> hay que saltear: que ese Dnato y el MI lean **la misma base** (§5 paso 7.c).

---

## 1. Desplegar las tools nuevas en el DEMO

Lo que entra: las **4 tools de Herramientas** (`pan_get_herramientas`, `pan_get_herramienta`,
`pan_get_movimientos`, `pan_get_certificaciones`) más la capa `toolsPANAPI`, y la tool
`core_get_empresa_actual` del PR #551. El APIM pasa de las operaciones que tenga hoy a **25**.

### Paso 0 — Nada que mergear acá

El PR #551 (`core_get_empresa_actual`) **ya está en `develop`** desde el 2026-10-19, junto con las 4
tools de Pañol que ya estaban. O sea: todo lo que necesita este capítulo sale de un `git pull` de
`develop`, sin ningún merge previo. El PR #45 es de **otro repo** y se usa en el §2, no acá.

El paso 1 trae el código; el chequeo de que llegó está en el paso 2.

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

> Acá los valores son los del ambiente que estás desplegando. **Los de producción están en §5 paso
> 2**, con número de línea, y ahí también está por qué no alcanza con cambiar el host.

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

> ⚠️ **El clon hereda el `.car` con las IPs que la VM tenga en ese momento.** Se hace de un
> snapshot del disco, así que el orden cambia el trabajo:
>
> | Orden | Qué pasa |
> |---|---|
> | Clonar **antes** del §5 | El DEMO nuevo arranca con las IPs de desarrollo que ya tenía. **No hay que deshacer nada** |
> | Clonar **después** del §5 (el plan del PM) | El DEMO nuevo arranca apuntando a **producción**, y hay que **devolverlo** a desarrollo antes de dejárselo a nadie |
>
> Si clonás después — que es el plan — el paso extra es obligatorio y no es opcional: en el clon hay
> que repetir el §5 pasos 4-6 **al revés**, poniendo de vuelta `10.142.0.13:5432/tools_prod_t`,
> `10.142.0.13:3306/assetv2` (user `rootremote`) y `http://10.142.0.13:8080/bonita`, rebuildear y
> redesplegar el `.car`. Hasta que eso esté hecho, **ese "DEMO" escribe en producción**: las tools
> `alm_crear_pedido_materiales` y `man_create_ot` crean pedidos, OTs e instancias de Bonita reales.
> El chequeo automático del §5 paso 5 sirve igual, invirtiendo qué IP esperás encontrar.

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

## 5. Redesplegar el MCP apuntando a producción (`10.142.0.2`)

La VM **no se toca de lugar ni de dominio**: ya es `mcp.cloudtrazalog.com` y ese pasa a ser el
dominio productivo. Lo único que cambia es **a qué datos apunta**, y eso vive adentro del `.car`.

**Decisión tomada (2026-10-19): producción es `10.142.0.2`.**

> ⚠️ **Lo que puede salir mal y no se ve.** Un `.car` con la IP equivocada **no falla**: las tools
> responden `200`, con estructura correcta, y datos del ambiente equivocado. Y al revés: un `bpm_url`
> equivocado **crea casos reales en Bonita de producción** sin que nada avise. Por eso cada paso de
> acá tiene su verificación, y la verificación compara **host Y nombre de base** — en un mismo host
> conviven varias bases con esquema equivalente, así que acertarle al host no alcanza.

### Mapa de las VMs (de `deployment-gcp.md` §6.1-ter)

| VM | IP interna | Network tags | Qué corre |
|---|---|---|---|
| `mcp-trazalog` | `10.142.0.18` | `deny-ingress`, **`mcp-gateway`** | **Esta VM**: MI + APIM de la fachada MCP |
| `vm-demo-trazalog` | `10.142.0.11` | `deny-ingress`, **`vm-demo`** | Bonita DEMO, **Dnato**, base de test |
| `vm-production-assetplanner-inst1` | `10.142.0.2` | `deny-ingress`, **`vm-prod`** | Bonita **PRODUCCIÓN** |
| (base de desarrollo) | `10.142.0.13` | — | PostgreSQL `tools_prod_t`, MySQL `assetv2`, Bonita de DEV |

---

### Paso 1 — Fotografiar a dónde apunta HOY, antes de tocar nada

💻 SSH a `mcp-trazalog`. Esto se hace **primero** y se guarda la salida: es el estado al que vas a
volver si hay que rollback.

```bash
cd /tmp && rm -rf car-antes && mkdir car-antes && \
unzip -qo /opt/wso2/wso2mi-4.5.0/repository/deployment/server/carbonapps/ToolsAPIProject_1.0.0.car -d car-antes && \
grep -rh "jdbc:" car-antes | sed 's/^[[:space:]]*//' && \
grep -rh "bpm_url" car-antes | sed 's/^[[:space:]]*//'
```

Anotá las tres líneas que salen. Son el antes.

💻 Y el backup del `.car` que está corriendo:

```bash
sudo cp /opt/wso2/wso2mi-4.5.0/repository/deployment/server/carbonapps/ToolsAPIProject_1.0.0.car \
  ~/ToolsAPIProject_1.0.0.car.antes-de-produccion
```

---

### Paso 2 — Los datos de producción (confirmados por el PM, 2026-10-19)

**Nada de esto coincide con desarrollo. Ni el puerto, ni el nombre de la base, ni el usuario.**

| | PostgreSQL (tools) | MariaDB (Asset Planner) | Bonita |
|---|---|---|---|
| **Host** | `10.142.0.2` | `10.142.0.2` | `10.142.0.2` |
| **Puerto** | **`5434`** ← no es el 5432 | `3306` | `8080` |
| **Base** | **`trazalog_tools`** | **`asp2tecn`** | — |
| **Usuario** | `postgres` | **`root`** | `admin` |
| **Password** | ⬜ falta | ⬜ falta | ⬜ falta |
| En desarrollo era | `10.142.0.13:5432/tools_prod_t`, user `postgres` | `10.142.0.13:3306/assetv2`, user `rootremote` | `10.142.0.13:8080`, pass `123traza` |

Las **tres passwords** son lo único que falta. Las dos de base, pedilas a quien administre
`vm-production-assetplanner-inst1`; la de Bonita, a quien administre Bonita de producción.

> ⚠️ **No uses los valores de los DataServices viejos que están en el repo**
> (`application/modules/traz-prod-trazasoft/scripts/Server DS backup/`). Dicen
> `jdbc:postgresql://10.142.0.2:5432/tools` — **host correcto, puerto y base equivocados**. Están
> viejos. Es justo el caso que esta sección avisa: host bien, base mal, y nada falla a la vista.

**Qué deja de funcionar si le errás a cada una** — porque los síntomas son distintos y conviene saber
cuál mirar:

| Si está mal… | Se caen | Son |
|---|---|---|
| PostgreSQL `trazalog_tools` | las **9 `alm_*`**, las **4 `pan_*`** y `core_get_empresa_actual` | `ALMDataService`, `PANDataservice` y el `getEmpresaById` de `COREDataService` usan `ToolsDataSource` |
| MariaDB `asp2tecn` | las **11 `man_*`** (equipos, OTs, lecturas, preventivos y los 4 KPI) | `MANDataService` y `MANEquiposDataService` usan `AssetPlannerDataSource` |
| Bonita | `alm_crear_pedido_materiales` y `man_create_ot` | son las dos únicas que instancian proceso |

> ✅ **Lo que ya verifiqué y no te va a dar problema:** que la base MariaDB cambie de nombre
> (`assetv2` → `asp2tecn`) **no rompe ninguna query**. Revisé los `.dbs` y los APIs del CAR: no hay
> una sola referencia calificada tipo `assetv2.tabla` — las únicas menciones a `assetv2` son
> comentarios. Lo mismo con `tools_prod_t`: aparece únicamente en el `<url>` del datasource. Alcanza
> con cambiar las URLs.

> **Si falta cualquiera de las tres passwords, pará acá.** Buildear con un dato inventado es peor que
> no buildear: el MI arranca igual, el datasource falla recién en la primera query, y el síntoma es
> "la tool devuelve vacío" — que se confunde con un problema de datos.

---

### Paso 3 — Probar la conectividad ANTES de buildear

Las tres VMs tienen el tag `deny-ingress`, y en GCP **a igual prioridad el `deny` gana**. Que la
VM del MCP llegue hoy a desarrollo **no implica** que llegue a producción.

💻 Desde `mcp-trazalog`:

```bash
for p in 5434 3306 8080; do \
  timeout 5 bash -c "</dev/tcp/10.142.0.2/$p" 2>/dev/null \
  && echo "10.142.0.2:$p ABIERTO" || echo "10.142.0.2:$p CERRADO"; \
done
```

Los tres tienen que decir `ABIERTO`. El `8080` ya debería estar, por la regla
`allow-bonita-desde-mcp` (§6.1-ter de `deployment-gcp.md`). Los otros dos **probablemente no**, y
hacen falta.

⌨️ Si falta alguno, en **Cloud Shell**:

```bash
gcloud compute firewall-rules create allow-bases-desde-mcp --network=default --direction=INGRESS --action=ALLOW --rules=tcp:5434,tcp:3306 --source-tags=mcp-gateway --target-tags=vm-prod --priority=900 --description="PostgreSQL 5434 y MariaDB 3306 de PROD desde mcp-trazalog"
```

> **La prioridad `900` no es decorativa.** Con la default (1000) la regla se crea y **no habilita
> nada**, porque empata con el `deny-ingress` y el deny gana. Si el comando se parte en varias
> líneas y el `--priority` queda suelto, pasa exactamente eso. Se arregla con:
>
> ```bash
> gcloud compute firewall-rules update allow-bases-desde-mcp --priority=900
> ```

Después de crear la regla, **volver a correr el `for` de arriba** hasta que los tres digan `ABIERTO`.

---

### Paso 4 — Editar los tres archivos (y solo esos tres)

💻 En `mcp-trazalog`, primero traer el código:

```bash
cd ~/traz-tools && \
git fetch origin && \
git checkout develop && \
git pull origin develop
```

Los archivos están bajo
`~/traz-tools/_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/`:

| Archivo | Línea | Valor hoy (desarrollo) | Valor para producción |
|---|---|---|---|
| `artifacts/data-sources/ToolsDataSource.xml` | **10** `<url>` | `jdbc:postgresql://10.142.0.13:5432/tools_prod_t` | `jdbc:postgresql://10.142.0.2:5434/trazalog_tools` |
| ↑ mismo archivo | **11** `<username>` | `postgres` | `postgres` (igual) |
| ↑ mismo archivo | **12** `<password>` | (de desarrollo) | la password de producción |
| `artifacts/data-sources/AssetPlannerDataSource.xml` | **6** `<url>` | `jdbc:mysql://10.142.0.13:3306/assetv2?useSSL=false&amp;allowPublicKeyRetrieval=true&amp;useUnicode=true&amp;characterEncoding=UTF-8` | `jdbc:mysql://10.142.0.2:3306/asp2tecn?useSSL=false&amp;allowPublicKeyRetrieval=true&amp;useUnicode=true&amp;characterEncoding=UTF-8` |
| ↑ mismo archivo | **7** `<username>` | `rootremote` | `root` |
| ↑ mismo archivo | **8** `<password>` | (de desarrollo) | la password de producción |
| `resources/conf/tools/bpmconf.xml` | **3** `<bpm_url>` | `http://10.142.0.13:8080/bonita` | `http://10.142.0.2:8080/bonita` |
| ↑ mismo archivo | **5** `<password>` | `123traza` | la de admin de Bonita producción |

**Los tres cambios que más fácil se pasan por alto**, porque en desarrollo son otra cosa y uno copia
el patrón de memoria:

| | En desarrollo | En producción |
|---|---|---|
| Puerto de PostgreSQL | `5432` (el default) | **`5434`** |
| Nombre de la base de Asset Planner | `assetv2` | **`asp2tecn`** |
| Usuario de MariaDB | `rootremote` | **`root`** |

En el de MariaDB cambian **host, base y usuario** — los parámetros `?useSSL=false&...` quedan
exactamente igual, y el `driverClassName` también (`com.mysql.cj.jdbc.Driver` funciona contra
MariaDB; es lo que ya se usa hoy).

**Qué NO tocar:**

| Archivo / línea | Por qué |
|---|---|
| `resources/conf/tools/apiconfig.xml` (`api_url`, `dataservices_url`) | Es el MI **llamándose a sí mismo**. `localhost:8290` es correcto en todos los ambientes |
| `bpmconf.xml` línea 6 (`dataservices_url`) | Igual que arriba: `localhost:8290` está bien |
| Cualquier cosa bajo `resources/registry/conf/` | **Esa carpeta es huérfana y no entra al `.car`.** Tiene valores distintos y contradictorios con `conf/tools/` — editarla no produce ningún efecto y hace perder una tarde. La que se empaqueta es `conf/tools/`, y lo dice `resources/artifact.xml` |

> 🛑 **No commitear estos cambios.** Son credenciales de producción en texto plano. Quedan como
> modificación local en la VM, y el `git status` te lo va a recordar en cada pull. Si en algún
> momento esto se parametriza (perfiles de Maven), deja de ser manual — hoy no lo está, y está
> anotado como pendiente en `deployment-gcp.md` §6.1-bis.

---

### Paso 5 — Buildear y verificar el `.car` ANTES de copiarlo

💻 En `mcp-trazalog`:

```bash
cd ~/traz-tools/_backend/api/ToolsAPIProject/ToolsAPIProject && \
mvn clean install && \
rm -rf /tmp/car-nuevo && mkdir /tmp/car-nuevo && \
unzip -qo target/ToolsAPIProject_1.0.0.car -d /tmp/car-nuevo && \
echo "--- jdbc ---" && grep -rh "jdbc:" /tmp/car-nuevo | sed 's/^[[:space:]]*//' && \
echo "--- bonita ---" && grep -rh "bpm_url" /tmp/car-nuevo | sed 's/^[[:space:]]*//'
```

**Leé esa salida.** Tienen que aparecer **exactamente** estas tres, sin una letra de diferencia:

```
jdbc:postgresql://10.142.0.2:5434/trazalog_tools
jdbc:mysql://10.142.0.2:3306/asp2tecn?useSSL=false&allowPublicKeyRetrieval=true&useUnicode=true&characterEncoding=UTF-8
http://10.142.0.2:8080/bonita
```

Si querés el chequeo sin leer a ojo, 💻 en la misma VM:

```bash
grep -rhq "jdbc:postgresql://10.142.0.2:5434/trazalog_tools" /tmp/car-nuevo && \
grep -rhq "jdbc:mysql://10.142.0.2:3306/asp2tecn" /tmp/car-nuevo && \
grep -rhq "http://10.142.0.2:8080/bonita" /tmp/car-nuevo && \
! grep -rhq "10.142.0.13" /tmp/car-nuevo && \
echo "CAR OK: las tres apuntan a produccion y no quedo nada de desarrollo" || \
echo "CAR MAL: NO desplegar, volver al paso 4"
```

Si dice `CAR MAL`, **no sigas**. Lo primero a revisar: que no hayas editado la copia huérfana de
`registry/conf/` en vez de `conf/tools/`.

---

### Paso 6 — Desplegar y confirmar contra la base real

💻 En `mcp-trazalog`:

```bash
cp target/ToolsAPIProject_1.0.0.car /opt/wso2/wso2mi-4.5.0/repository/deployment/server/carbonapps/ && \
sudo systemctl restart wso2mi
```

Esperar el deploy y confirmar:

```bash
sudo journalctl -u wso2mi -n 60 | grep -iE "Successfully Deployed|ERROR|datasource"
```

No tiene que haber errores de datasource. Después, la prueba que de verdad importa — **que los datos
sean de producción**:

```bash
cd ~/traz-tools && \
python3 scripts/dev/smoke-tools-mi.py --base http://localhost:8290/tools/mcp --empresa <empr_id_mysql_de_prod> --empresa-pg <empr_id_de_prod>
```

**Sin `--escrituras`.** Nunca con `--escrituras` contra producción.

> **Los dos ids de empresa no son intercambiables**: las tools `man_*` filtran por `empr_id_mysql`
> (assetv2) y las `alm_*`/`pan_*` por `empr_id` (PostgreSQL). Si un grupo trae datos y el otro viene
> vacío, es el id — o un datasource que quedó apuntando a otro ambiente.
>
> **`smoke-tools-mi.py` tiene la lista de tools hardcodeada y está vieja**: cubre 16 rutas `man_`/
> `alm_` y **no incluye ninguna `pan_`**. Para ejercitar las de Herramientas hay que usar
> `validar-tools-e2e.py`, que las descubre solo (§3.1).

---

### Paso 7 — Dnato: el de producción, no el del DEMO

> **Corrección (2026-10-19).** La primera versión de este paso lo planteaba como una decisión 🔴 de
> arquitectura: *"apuntar el Dnato existente a producción o levantar uno nuevo"*. **Estaba mal.** Ya
> hay **dos Dnato, uno por ambiente**, y cada uno se queda donde está: el del DEMO sigue sirviendo el
> DEMO y el de producción sigue sirviendo producción. No hay nada que decidir — hay que desplegar el
> mismo commit en el otro servidor y reapuntar la cadena de identidad del MCP.

Lo que cambia al promover esta VM: el MCP deja de validar los tokens del Dnato del DEMO y pasa a
validar los del Dnato de **producción**. No es automático y **no viaja en el `.car`**: son dos
archivos de config del APIM.

#### 7.a — Que el selector esté en el Dnato de producción

Necesita un tag que lo contenga, y el último (`v2.5.0.10`) **no lo tiene** — ver §0.1-bis para el
commit exacto y la secuencia merge → tag → `master`.

💻 SSH al servidor de Dnato de **producción** (el que sirve `cloudtrazalog.com`, **no**
`vm-demo-trazalog`):

```bash
cd /var/www/html/traz-comp-dnato && \
git rev-parse --abbrev-ref HEAD && \
git describe --tags 2>/dev/null && \
ls -la application/views/oauth/login_empresa.php 2>&1 && \
grep -c "oauth/login/empresa" application/config/routes.php && \
git status --short
```

Se lee igual que el diagnóstico del §2 paso 1, y **valen las mismas advertencias**: si el
`git status` muestra `.htaccess` o `Oauthlogin.php` modificados, no los descartes a ciegas — ahí
viven los `SetEnv` del ambiente y los parches de compatibilidad PHP 5.6. Leelos antes.

Si falta el selector, el despliegue es el mismo del §2 paso 2, cambiando el `git pull origin develop`
por el checkout del tag:

```bash
cd /var/www/html/traz-comp-dnato && \
git fetch origin --tags && \
git checkout v2.5.0.11
```

> **Ese tag todavía no existe.** Hay que crearlo después de mergear el PR #45 a `develop` (§0.1-bis).
> Si el servidor de producción no sigue tags sino la rama `master`, el equivalente es
> `git checkout master && git pull origin master` **después** de que el tag se haya mergeado ahí.

#### 7.b — Reapuntar la cadena de identidad del MCP

El issuer tiene que decir **exactamente lo mismo en tres lugares**. Si difieren aunque sea en la
barra final, el flujo falla con *issuer mismatch* o con un 404 en el discovery (`deployment-gcp.md`
§7.0, §7.1):

| # | Dónde | Qué tiene que decir | ¿Hay que cambiarlo? |
|---|---|---|---|
| 1 | `.htaccess` del Dnato de producción | `DNATO_ISSUER` = su propia URL pública + `/oauth` | **No** — ya es el suyo. Solo leerlo, porque es el valor de los otros dos |
| 2 | `JAVA_OPTS` del APIM (systemd) | `-Dtrazalog.dnato.oauth.url=<ese issuer>` | **Sí** — hoy dice el del DEMO |
| 3 | `[[apim.jwt.issuer]]` del `deployment.toml` del APIM | `name` y `jwks.url` del Dnato de producción | **Sí** — hoy dice el del DEMO |

**Primero, leer el valor bueno.** 💻 En el servidor de Dnato de producción:

```bash
grep DNATO_ISSUER /var/www/html/traz-comp-dnato/.htaccess
```

**Confirmar que ese issuer responde**, y de paso que hay conectividad y TLS desde la VM del MCP.
💻 En `mcp-trazalog`, reemplazando `<ISSUER_PROD>` por lo que devolvió el comando anterior:

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

Los dos van a decir el issuer del DEMO. Cambiar el primero con `sudo systemctl edit --full wso2am`
(la línea `Environment="JAVA_OPTS=..."`, dejando `trazalog.mcp.resource.url` **como está**: el
dominio del MCP no cambia) y el segundo editando el `deployment.toml`. Después:

```bash
sudo systemctl daemon-reload && \
sudo systemctl restart wso2am
```

> ⚠️ **Los tokens vigentes dejan de servir.** Al cambiar el issuer, los JWT que emitió el Dnato del
> DEMO pasan a ser inválidos: todo cliente ya conectado tiene que **reconectar** el conector en
> Claude. No es un bug — es lo que tiene que pasar, y conviene avisarlo antes.

#### 7.c — Que Dnato y el MI lean la misma base

Acá está el riesgo real, y es silencioso. El `empr_id` con el que filtran las tools **no sale del
MCP**: sale del JWT que emite Dnato, y Dnato lo resuelve contra **su** PostgreSQL. Si el MI lee
`trazalog_tools` pero Dnato resuelve el `empr_id` contra otra base, el resultado no es un error: son
**datos de la empresa equivocada, o vacío**.

💻 En el servidor de Dnato de producción:

```bash
grep -nE "hostname|'database'|'port'" /var/www/html/traz-comp-dnato/application/config/database.php
```

Tiene que dar los **mismos tres valores** que le pusiste al `ToolsDataSource` en el paso 4:
`10.142.0.2`, `5434`, `trazalog_tools`. Si da otra cosa, pará y revisalo antes de abrir el MCP a un
usuario — no lo vas a detectar por un log.

> `database.php` está versionado pero cada ambiente tiene el suyo modificado localmente, igual que el
> `.htaccess`. Lo que dice el repo (`10.142.0.13:5432/tools_prod_t`) es el de **desarrollo** y no
> dice nada sobre lo que corre en producción: hay que mirarlo en el servidor.

---

### Paso 8 — Lo que no cambia (para no perder tiempo buscándolo)

- **El dominio.** Sigue siendo `mcp.cloudtrazalog.com`, así que los conectores ya dados de alta en
  Claude siguen funcionando sin tocar nada.
- **El PRM, el `https_endpoint` y el `JAVA_OPTS`.** Ya dicen `mcp.cloudtrazalog.com`.
- **Los `redirect_uris` de Dnato** (`oauth_clients.php`) son de `claude.ai`, no del MCP: no dependen
  del dominio del servidor.
- **La API y el MCP Server del APIM.** Cambiar de base no cambia el contrato: no hay que volver a
  subir la OpenAPI ni recrear el MCP Server. Eso solo hace falta cuando cambian las **operaciones**.

---

### Paso 9 — Endurecer

| | Por qué |
|---|---|
| Bajar el `api.log` de FULL | En FULL quedan los JWT completos en el log. Está así para que `validar-tools-e2e.py --desde-log` pueda sacarlos |
| Sacar los wire logs si quedaron | `org.apache.synapse.transport.http.wire` en DEBUG genera muchísimo log y expone headers |
| Nunca `--escrituras` | Crea pedidos y OTs reales, con instancia en Bonita de producción |
| Snapshot de la VM antes de cada despliegue | `recrear-api-y-mcp.sh` es destructivo sobre la API. Hace backups solos, pero el snapshot es el que te salva |
| Revisar el TTL del token | Son 24 h sin `refresh_token`: el usuario va a tener que reconectar a diario hasta que se implemente (TODO en `jwt.php:69`) |

---

### Paso 10 — Rollback

Si algo sale mal, volver al `.car` del paso 1. 💻 En `mcp-trazalog`:

```bash
sudo cp ~/ToolsAPIProject_1.0.0.car.antes-de-produccion \
  /opt/wso2/wso2mi-4.5.0/repository/deployment/server/carbonapps/ToolsAPIProject_1.0.0.car && \
sudo systemctl restart wso2mi
```

Y verificar con el mismo `grep "jdbc:"` del paso 1 que volvió a las IPs de antes. El rollback no
requiere tocar el APIM ni el DNS: el `.car` es el único artefacto que cambió.

---

## 6. El orden en que conviene hacerlo

```
 1. Mergear dnato #45 -> develop                          (§0.1-bis)     <- decision tuya
 2. Desplegar el selector en vm-demo-trazalog             (§2 pasos 1-3)
 3. Desplegar el .car + la OpenAPI en la VM del MCP       (§1)
 4. Verificar multiempresa con un usuario de 2 empresas   (§2 paso 4)
 5. Correr las dos suites                                 (§3)           <- 16/16
 6. Conseguir las 3 passwords de produccion               (§5 paso 2)    <- lo unico que falta
 7. Repuntar la VM a produccion 10.142.0.2                (§5 pasos 3-6) <- esta VM YA ES produccion
 8. Taguear develop como v2.5.0.11 y mergearlo a master   (§0.1-bis)
 9. Selector + cadena de identidad en el Dnato de prod    (§5 paso 7)
10. Clonar la VM como mcp-demo y DEVOLVERLA a desarrollo  (§4)           <- paso extra obligatorio
```

**Por qué en ese orden.**

- El **1** es el único merge que queda: los de `traz-tools` (#550, #551) se mergearon el 2026-10-19,
  así que el **3** no espera nada — sale de un `git pull` de `develop`.
- El **2** y el **3** son independientes entre sí —servidores distintos— pero el **4** necesita los
  dos puestos: la pantalla sale del servidor de Dnato y la respuesta de *"¿con qué empresa estoy
  conectado?"* sale de la VM del MCP.
- El **5** va después del 4 porque el escenario E15 asume que la tool está desplegada.
- Del **1 al 5 se puede hacer con lo que hay hoy.** El **6** es lo único que frena el resto: hosts,
  puertos, bases y usuarios ya están confirmados (§5 paso 2); faltan las **tres passwords**.
- El **8 y el 9 van juntos**, y después del 7: una vez que esta VM es producción, los tokens los
  tiene que emitir el Dnato de producción, y para eso el selector tiene que estar ahí. Si hacés el 7
  sin el 9, el MCP lee producción pero sigue validando tokens del Dnato del DEMO — anda, pero el
  `empr_id` lo resuelve la base equivocada (§5 paso 7.c).
- El **10 es el último y arrastra trabajo**: el clon hereda el `.car` apuntando a producción, así que
  **hay que devolverlo a desarrollo antes de que lo use alguien** — §5 pasos 4-6 al revés. Mientras
  eso no esté hecho, ese "DEMO" escribe pedidos y OTs reales. Clonar **antes** del 7 ahorra ese
  trabajo, pero el orden es decisión tuya y el §4 cubre los dos casos.
