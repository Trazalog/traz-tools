# Instalar el MCP en un ambiente nuevo

## Objetivo

Poner en pie la fachada MCP de Trazalog en un ambiente donde **no existe todavía**: la VM, WSO2, la
identidad en Dnato, el despliegue y la publicación, hasta que un conector de Claude se conecta y las
tools devuelven datos. Está escrito para ejecutarlo de corrido; cada paso dice dónde se corre.

**Cuándo leerlo:** una sola vez por ambiente. Para subir una versión nueva a un ambiente que ya
funciona, es [`desplegar-version.md`](desplegar-version.md). Para diagnosticar algo que dejó de
andar, [`soporte-y-diagnostico.md`](soporte-y-diagnostico.md).

**Qué NO cubre:** el diseño de las tools ([`virtual-mcp-unificado.md`](virtual-mcp-unificado.md)) ni
la publicación en directorios públicos ([`publicacion-en-directorios.md`](publicacion-en-directorios.md)).

| | |
|---|---|
| **Duración** | medio día, repartido entre esperas de DNS, de arranques y de descargas |
| **Verificado** | producción (`mcp.cloudtrazalog.com` → `cloudtrazalog.com`), 2026-10-24 |

---

## El mapa

Son **cuatro piezas en tres máquinas**, y el orden importa: cada una necesita que la anterior
funcione.

```
   [ VM del MCP ]                         [ servidor de Dnato ]      [ bases ]
   ┌──────────────────────────┐           ┌──────────────────┐       ┌──────────┐
   │ Caddy :443               │           │ Dnato            │       │ Postgres │
   │   └─ APIM :8243 gateway  │◄─ token ──│  emite los JWT   │       │ MariaDB  │
   │        └─ MI :8290       │───────────┼──────────────────┼──────►│ Bonita   │
   └──────────────────────────┘           └──────────────────┘       └──────────┘
     parte A + C + E                         parte B                   parte D
```

| | Parte | Qué se instala o configura |
|---|---|---|
| **A** | La VM y WSO2 | Rocky Linux, JDK 21, APIM 4.6.0, MI 4.5.0, Caddy |
| **B** | **Dnato del ambiente** | el Authorization Server: código, dependencias, claves RS256, variables, tabla de códigos |
| **C** | El APIM | el CAR de discovery, el issuer, el `https_endpoint` |
| **D** | El MI | el `.env` del ambiente, el `.car`, el firewall a bases y Bonita |
| **E** | Publicación | la API, el MCP Server, el endpoint en los dos, la suscripción |

> 🔴 **La parte B es la que más se subestima.** Desplegar el código de Dnato **no** alcanza: hay
> cuatro cosas más que no viajan con `git` y sin las cuales el login no funciona. Es la que costó
> una tarde entera la primera vez.

---

## Parte A — La VM y WSO2

### A.1 Crear la VM

🖥️ **Consola de GCP** → `Compute Engine` → `VM instances` → `Create instance`.

| | |
|---|---|
| Tipo | `e2-medium` |
| Zona | la misma que Dnato y las bases |
| SO | **Rocky Linux 9** — no la 10: la [matriz de compatibilidad de WSO2 4.6.0](https://apim.docs.wso2.com/en/4.6.0/install-and-setup/setup/reference/product-compatibility/) solo lista 8.7 y 9.3 |
| Disco | 20 GB `pd-standard` |

### A.2 IP estática y DNS

⌨️ **Cloud Shell** — promover la IP efímera a estática para que el DNS no se rompa en el próximo
reinicio:

```bash
gcloud compute instances describe <VM> --zone=<ZONA> \
  --format="get(networkInterfaces[0].accessConfigs[0].natIP)"
```

```bash
gcloud compute addresses create <nombre>-ip --region=<REGION> --addresses=<LA_IP>
```

🌐 **Panel de DNS del dominio** — registro `A` de `mcp.<dominio>` a esa IP. Verificar:

```bash
dig +short mcp.<dominio>
```

### A.3 Firewall: abrir 80/443 solo a esta VM

⌨️ **Cloud Shell:**

```bash
gcloud compute instances add-tags <VM> --zone=<ZONA> --tags=mcp-gateway
```

```bash
gcloud compute firewall-rules create allow-mcp-http-https --network=default \
  --direction=INGRESS --action=ALLOW --rules=tcp:80,tcp:443 \
  --source-ranges=0.0.0.0/0 --target-tags=mcp-gateway
```

> **El 9443 nunca se expone.** Es la consola de administración del APIM. GCP deniega por defecto, así
> que alcanza con no crear la regla. Al Publisher y al DevPortal se entra por túnel SSH (§E.1).

### A.4 JDK 21

💻 **SSH a la VM:**

```bash
sudo tee /etc/yum.repos.d/adoptium.repo <<'EOF'
[Adoptium]
name=Adoptium
baseurl=https://packages.adoptium.net/artifactory/rpm/rhel/$releasever/$basearch
enabled=1
gpgcheck=1
gpgkey=https://packages.adoptium.net/artifactory/api/gpg/key/public
EOF
```

```bash
sudo dnf install -y temurin-21-jdk && java -version
```

> En el `baseurl` va **`rhel`, no `rocky`**: Adoptium no publica `rpm/rocky/9/` y da 404. Rocky 9 es
> compatible 1:1 con RHEL 9.

### A.5 Subir los instaladores de WSO2

WSO2 no permite bajarlos con `wget`: hay que pasar por el formulario web.

🌐 **En tu computadora**, desde [wso2.com/products/downloads](https://wso2.com/products/downloads/) →
"Previous Releases": **API Manager 4.6.0** y **Micro Integrator 4.5.0**.

💻 **En la ventana de SSH** → engranaje ⚙️ → `Upload file`, uno por vez. Después:

```bash
sudo mkdir -p /opt/wso2/dist && \
sudo mv ~/wso2am-4.6.0.zip ~/wso2mi-4.5.0.zip /opt/wso2/dist/ && \
ls /opt/wso2/dist/
```

### A.6 Instalar

💻 **En la VM:**

```bash
mkdir -p ~/git && cd ~/git && \
git clone --recurse-submodules https://github.com/Trazalog/traz-tools.git
```

```bash
cd ~/git/traz-tools/deploy/gcp && cp .env.example .env
```

Completar el `.env` con las rutas de los zip y los valores del ambiente, y después:

```bash
sudo ./install-apim.sh && \
sudo ./install-mi.sh && \
sudo ./setup-reverse-proxy.sh && \
sudo systemctl start wso2am && \
sudo systemctl start wso2mi
```

> **Si `systemctl start` falla con `Permission denied`**, es SELinux: los scripts descomprimen en un
> temporal y mueven a `/opt/wso2`, y el `mv` no actualiza la etiqueta. Se arregla con
> `sudo restorecon -Rv /opt/wso2/wso2am-4.6.0` (y lo mismo para el MI).

### A.7 Verificar

💻 **En la VM:**

```bash
sudo systemctl status wso2am wso2mi --no-pager && \
sudo ss -tlnp | grep -E ':(9443|8280|8243|8290|8253|9164)\b'
```

Seis puertos escuchando: tres del APIM y tres del MI. Y desde afuera:

```bash
curl -I https://mcp.<dominio>
```

Tiene que responder con certificado de **Let's Encrypt**, no self-signed. Si no, Caddy no levantó o
el DNS no propagó.

> El `Caddyfile` **no es un passthrough**: lleva dos parches sin los cuales las tools que escriben
> fallan en el cliente aunque el backend ande. Están explicados en
> [`soporte-y-diagnostico.md`](soporte-y-diagnostico.md). Para validarlo hay que cargar el entorno
> primero, o `caddy validate` falla en una línea que despista:
>
> ```bash
> sudo bash -c 'set -a; source /etc/caddy/gcp.env; caddy validate --config /etc/caddy/Caddyfile'
> ```

---

## Parte B — Dnato del ambiente

Dnato emite los tokens, y de ahí sale el `empr_id` con el que filtran **todas** las tools. Son cinco
cosas, todas 💻 **en el servidor de Dnato de ese ambiente** — que no es la VM del MCP.

### B.1 El código

Tag **`v2.5.0.12` o posterior** (el primero con la pantalla de selección de empresa del login OAuth,
más el `empr_id_mysql`). Verificar:

```bash
git -C /var/www/html/traz-comp-dnato log --oneline -1 && \
grep -c "oauth/" /var/www/html/traz-comp-dnato/application/config/routes.php
```

Tienen que aparecer las rutas `oauth/authorize`, `oauth/token`, `oauth/register`,
`oauth/.well-known/*` y `oauth/login/*`.

Y su `application/config/database.php` tiene que apuntar a **la misma base** que va a usar el MI
(parte D). Si no, el `empr_id` se resuelve contra otra base y las tools devuelven datos de otra
empresa **sin un solo error en ningún log**.

### B.2 Las dependencias (`vendor/`)

El login firma los JWT con `firebase/php-jwt`, que es la única dependencia de Composer y **no está en
git**. Sin ella, `Oauth.php` muere con `500`.

```bash
cd /var/www/html/traz-comp-dnato && composer install --no-dev --optimize-autoloader
```

> ⚠️ **Si el server corre PHP 5.6**, Composer 2.3+ no arranca (exige PHP ≥ 7.2.5). Instalá la LTS:
> `curl -sS https://getcomposer.org/installer | php -- --2.2`
>
> Alternativa sin instalar nada en el server: armar `vendor/` en otra máquina y copiarlo. El
> `composer.json` tiene `platform.php` fijado, así que resuelve igual, y `firebase/php-jwt` es PHP
> puro. Verificar después en el server, con **su** PHP:
> `find .../vendor -name '*.php' -exec php -l {} \; | grep -v "No syntax errors"`

Y que CodeIgniter lo cargue — `application/config/config.php`:

```php
$config['composer_autoload'] = FCPATH . 'vendor/autoload.php';
```

> **Ese archivo es por ambiente** (`deploytools.sh` lo respalda y lo restaura en cada despliegue), así
> que el valor del repo no llega solo. Comentarlo **no** es lo mismo que setearlo: si la clave no
> existe, CodeIgniter ni intenta cargar el autoload.

### B.3 Las claves RS256

```bash
cd /var/www/html/traz-comp-dnato && \
mkdir -p application/config/keys && \
openssl genrsa -out application/config/keys/jwt_private.pem 2048 && \
openssl rsa -in application/config/keys/jwt_private.pem -pubout -out application/config/keys/jwt_public.pem && \
chmod 600 application/config/keys/jwt_private.pem && \
chmod 644 application/config/keys/jwt_public.pem && \
chown -R apache:apache application/config/keys
```

> 🔴 **Generalas en ese servidor. Nunca copies las de otro ambiente**: si dos ambientes firman con la
> misma clave privada, un token de demo vale en producción.

Esa es la ruta por defecto que busca `application/config/jwt.php`, así que con generarlas ahí alcanza.

### B.4 La tabla de authorization codes

El login guarda el código de un solo uso en `seg.oauth_codes`. La migración del repo
(`doc/identity/migrations/001_...sql`) **no trae la columna `empr_id_mysql`**, que el código sí
escribe. En la base del ambiente:

```sql
CREATE SCHEMA IF NOT EXISTS seg;
```

Correr `001_create_seg_oauth_codes.sql`, y después:

```sql
ALTER TABLE seg.oauth_codes ADD COLUMN IF NOT EXISTS empr_id_mysql INTEGER NULL;
```

Las columnas que el modelo escribe son diez: `id_code`, `email`, `empr_id`, `empr_id_mysql`,
`code_challenge`, `redirect_uri`, `useridbpm`, `groupbpm`, `created_at` y `used_at`. Verificalas
antes de seguir:

```sql
select column_name, data_type, is_nullable from information_schema.columns
where table_schema='seg' and table_name='oauth_codes' order by ordinal_position;
```

### B.5 Las variables de entorno

💻 En el `.htaccess` de Dnato, como `SetEnv`:

```apache
SetEnv DNATO_ISSUER https://<dominio-de-dnato>/traz-comp-dnato/oauth
SetEnv JWT_AZP <consumer-key-de-la-Application-del-APIM>
```

| Variable | Para qué | Si falta |
|---|---|---|
| `DNATO_ISSUER` | el claim `iss` del JWT | se deriva de `base_url`; suele quedar bien, pero depende de la autodetección |
| `JWT_AZP` | el claim `azp`, con el que el APIM encuentra la Application | **cae a un default hardcodeado de otro ambiente** y el gateway no resuelve la suscripción |

El `JWT_AZP` sale de 🌐 **DevPortal** → `Applications` → la app → `Production Keys` → **Consumer
Key**. Como esa Application se crea en la parte E, podés volver acá después — pero no te olvides.

`JWT_PRIVATE_KEY_PATH` y `JWT_PUBLIC_KEY_PATH` solo hacen falta si las claves no están en la ruta por
defecto de B.3.

### B.6 El backend de Dnato — la segunda instancia de WSO2

**Hay dos instancias de WSO2 en juego, en dos VMs distintas, y es fácil confundirlas:**

| Instancia | Puerto | VM | Quién la consume |
|---|---|---|---|
| MI de la fachada MCP | `8290` | la del MCP | el APIM (gateway MCP) |
| **WSO2 del backend de Dnato** | `8283` | la de Dnato | **Dnato**, vía `REST_CORE` |

El login OAuth **no pasa por la fachada MCP**: `Oauthlogin.php` llama a su propio backend en
`localhost:8283`. Actualizar el `.car` en la VM del MCP **no actualiza este otro**.

💻 En la VM de Dnato, `COREDataService` tiene que exponer `/empresa/{empr_id}` — lo usa
`Empresas::getEmpresaById()` para resolver el `empr_id_mysql` que va como claim del JWT:

```bash
curl http://localhost:8283/services/COREDataService/empresa/<un-empr_id-real>
```

Si da `404` o `Invalid URL`, ese CAR está atrasado: hay que reconstruirlo y redesplegarlo ahí
también, no parchear el `.dbs` a mano.

#### `core.empresas.empr_id_mysql` tiene que existir **y estar poblada**

```sql
ALTER TABLE core.empresas ADD COLUMN IF NOT EXISTS empr_id_mysql integer;
```

```sql
UPDATE core.empresas SET empr_id_mysql = <id_empresa en assetv2> WHERE empr_id = <empr_id>;
```

> 🔴 **Con la columna creada pero en `NULL`, el login se completa igual** —el código lo tolera y deja
> un `WARN`— pero el JWT sale con ese claim vacío. Y la consecuencia es sutil, porque *parece* que
> todo anda:
>
> - las tools **`alm_*` funcionan**: filtran por el `empr_id` de PostgreSQL;
> - las tools **`man_*` devuelven vacío, sin error**: filtran por `id_empresa` en `assetv2`, que es
>   exactamente el valor que falta.
>
> **No existe migración para esta columna en ningún repositorio.** Se asume existente en
> `COREDataService.dbs` y en toda la cadena de identidad, pero nunca se formalizó. Verificala a mano
> en cada ambiente.

#### Cosmético: el logo no aparece en el login

`Oauthlogin::_getLogo()` lee el logo de `configuraciones_ui` y ante cualquier excepción devuelve
`''`; la vista lo omite. Que no se vea significa que esa tabla no tiene el registro en la base de ese
ambiente. Se ve también como `base64_encode() expects parameter 1 to be string` en el log. **No
bloquea el login.**

### B.7 Verificar la parte B

⌨️ Desde cualquier lado, son públicos. Los dos tienen que dar `200`:

```bash
curl -s https://<dominio-de-dnato>/traz-comp-dnato/oauth/.well-known/oauth-authorization-server | python3 -m json.tool
```

```bash
curl -s https://<dominio-de-dnato>/traz-comp-dnato/oauth/.well-known/jwks.json | python3 -m json.tool
```

El primero **tiene que traer `registration_endpoint`** — sin eso Claude no puede registrarse. El
segundo, una clave RS256. **Anotá el `issuer` que devuelve**: es el valor exacto que va en la parte C.

Si da `500`, el error está en `application/logs/log-<fecha>.php` del propio Dnato:

```bash
grep -a "ERROR" /var/www/html/traz-comp-dnato/application/logs/log-$(date +%Y-%m-%d).php | tail -10
```

---

## Parte C — El APIM

💻 **En la VM del MCP.**

### C.1 El CAR de OAuth discovery

WSO2 APIM **no sirve el Protected Resource Metadata en el path que define la RFC 9728**, que es el
único que Claude consulta. Lo cubre un CAR aparte:

```bash
cd ~/git/traz-tools/_backend/api/ApimDiscoveryProject && mvn clean install
```

Y el `.car` va a `carbonapps/` del **APIM** (no del MI — son dos productos distintos).

### C.2 Las system properties

```bash
sudo systemctl edit --full wso2am
```

En `[Service]`, debajo de `JAVA_HOME`:

```ini
Environment="JAVA_OPTS=-Dtrazalog.mcp.resource.url=https://mcp.<dominio>/<contexto>/<version>/mcp -Dtrazalog.dnato.oauth.url=<el issuer de B.6>"
```

> `trazalog.mcp.resource.url` es la URL pública **completa**, **sin el puerto 8243**: hacia afuera se
> entra siempre por el 443 de Caddy. Anunciar el 8243 en el PRM rompe el flujo desde cualquier
> cliente externo.

### C.3 El `deployment.toml`

```bash
sudo grep -nA 8 "^\[\[apim.jwt.issuer\]\]" /opt/wso2/wso2am-4.6.0/repository/conf/deployment.toml
```

```toml
[[apim.jwt.issuer]]
name = "<el mismo issuer de B.6, exacto>"
consumer_key_claim = "azp"
scopes_claim = "scope"
jwks.url = "<issuer>/.well-known/jwks.json"

[[apim.jwt.issuer.claim_mapping]]
remote_claim = "empr_id"
local_claim = "empr_id"
[[apim.jwt.issuer.claim_mapping]]
remote_claim = "empr_id_mysql"
local_claim = "empr_id_mysql"
```

Y en el mismo archivo:

```toml
https_endpoint = "https://mcp.<dominio>"
```

> **`name` tiene que ser idéntico al `iss` que emite Dnato, carácter por carácter.** Una barra final
> de más y el gateway rechaza todos los tokens con "issuer mismatch", con todo lo demás bien.

### C.4 Reiniciar y verificar

```bash
sudo systemctl daemon-reload && sudo systemctl restart wso2am
```

Tarda **60-90 s**. Después, ⌨️ desde afuera, los dos tienen que devolver lo mismo:

```bash
curl -s https://mcp.<dominio>/.well-known/oauth-protected-resource | python3 -m json.tool
```

```bash
curl -s https://mcp.<dominio>/.well-known/oauth-protected-resource/<contexto>/<version>/mcp | python3 -m json.tool
```

```json
{
  "resource": "https://mcp.<dominio>/<contexto>/<version>/mcp",
  "authorization_servers": ["<el issuer de Dnato de ESTE ambiente>"],
  "scopes_supported": []
}
```

> 🔴 **Este es el chequeo que dice a qué ambiente manda a loguearse el MCP.** Si `authorization_servers`
> apunta al Dnato de otro ambiente, el `empr_id` se resuelve contra otros usuarios y las tools
> devuelven datos cruzados sin fallar. Miralo siempre que repuntes un ambiente.

---

## Parte D — El MI

### D.1 El `.env` del ambiente

💻 **En la VM del MCP:**

```bash
cd ~/git/traz-tools && \
cp deploy/gcp/.env.car.example deploy/gcp/.env.car && \
chmod 600 deploy/gcp/.env.car
```

Dejá el bloque de **este** servidor y completá las credenciales. Está gitignoreado. Las comillas son
opcionales: el script lo lee como datos, no lo ejecuta, así que una password con `"`, `<`, `>`, `&`,
`$` o espacios entra tal cual.

### D.2 Firewall a las bases y a Bonita

Las VMs suelen tener el tag `deny-ingress`, y **en GCP, a igual prioridad, el `deny` gana**. 💻 Desde
la VM del MCP, los tres tienen que decir `ABIERTO`:

```bash
for p in 5434 3306 8080; do \
  timeout 5 bash -c "</dev/tcp/<IP_BASES>/$p" 2>/dev/null \
  && echo "<IP_BASES>:$p ABIERTO" || echo "<IP_BASES>:$p CERRADO"; \
done
```

⌨️ Si falta alguno, en Cloud Shell — **con `--priority=900`**, no la default:

```bash
gcloud compute firewall-rules create allow-bases-desde-mcp --network=default --direction=INGRESS --action=ALLOW --rules=tcp:5434,tcp:3306,tcp:8080 --source-tags=mcp-gateway --target-tags=<tag-de-la-vm-destino> --priority=900
```

> Con la prioridad por defecto (1000) la regla se crea y **no habilita nada**, porque empata con el
> `deny-ingress`. Se corrige con `gcloud compute firewall-rules update <nombre> --priority=900`.

El `8080` es Bonita: `alm_crear_pedido_materiales` y `man_create_ot` instancian procesos ahí. Sin
conectividad fallan, y fallan feo — el pedido queda creado sin `case_id`, porque el rollback también
depende de Bonita.

### D.3 Desplegar el `.car`

```bash
sh ~/git/traz-tools/scripts/deploy/deploymcp.sh origin/master
```

El detalle está en [`desplegar-version.md`](desplegar-version.md). Tiene que cerrar en
`DESPLIEGUE OK`, y antes de empezar te va a mostrar a qué bases va a quedar apuntando el MCP: leé
esas tres líneas.

### D.4 Verificar el MI directo

💻 En la VM, una por cada ruta, salteando el APIM:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8290/<contexto-mi>/mcp/core/empresa
```

**`503` es el resultado correcto**: la sequence de identidad no encuentra el `empr_id` porque no hay
token, y contesta `identity_missing`. Que llegue esa respuesta prueba que la ruta existe y la
sequence está enganchada. `404` es el problema.

---

## Parte E — Publicar la API y el MCP Server

### E.1 Entrar al Publisher

El 9443 no se expone. ⌨️ Desde tu máquina:

```bash
gcloud compute ssh <VM> --zone=<ZONA> --tunnel-through-iap -- -L 9443:localhost:9443
```

Y después `https://localhost:9443/publisher` en tu navegador (certificado self-signed, el aviso es
esperado).

### E.2 La API

`APIs` → `Create API` → **Import Open API** → subir `doc/api/trazalog-operaciones.yaml`.

### E.3 El MCP Server

`MCP Servers` → `Create MCP Server` → **Start from Existing API** → elegir la API → seleccionar
**todas** las operaciones → Name / Context / Version → `Create`.

> **Contá las operaciones que te ofrece.** Si son menos que las de la OpenAPI, la API no quedó bien
> importada y el MCP Server va a nacer con tools rotas.

### E.4 Los tres pasos que el Publisher no hace solo

Son los que aparecen **siempre**, en este orden, y recién cuando todo lo demás ya funciona. Hacelos de
entrada:

| # | Qué | Dónde | Si falta |
|---|---|---|---|
| 1 | **El endpoint, en LOS DOS artefactos** — `http://localhost:8290/<contexto-mi>` | `API Configurations` → `Endpoints`, en la API **y** en el MCP Server | `404` en `tools/call` con el conector ya autenticado |
| 2 | **`Deploy` + `Publish`, en los dos** | `Deployments` → `Deploy`, y `Lifecycle` → `Publish` | `404` en todas: no hay revisión en el gateway |
| 3 | **La suscripción** | DevPortal → `Applications` → la app → `Subscriptions` → **el MCP Server**, policy `Unlimited` | `403` / `900908` en todas |

> **La causa común de los tres: el MCP Server es un artefacto SEPARADO de la API.** Generarlo desde
> ella no copia ni el endpoint ni las suscripciones. Tiene su propio id y su propia configuración.
>
> `localhost` porque el APIM y el MI conviven en la misma VM. Puerto **8290** (HTTP passthrough del
> MI), no 8280. Y después de cambiar el endpoint hay que **desplegar una revisión nueva**: guardarlo
> no alcanza.

### E.5 Lo que no se toca

- **`Enable Subscription Validation`: desactivado.** Con la validación activa el gateway responde
  `403` aunque la firma del JWT sea válida.
- **El selector de Key Managers: no se toca.** Dnato no se registra como Key Manager — APIM 4.6.0 no
  tiene conector genérico para IdPs custom. La validación la resuelve `[[apim.jwt.issuer]]` de C.3.

### E.6 Volvé a B.5

Ahora que la Application existe, copiá su **Consumer Key** y ponelo en el `JWT_AZP` del `.htaccess` de
Dnato. Sin eso, el token es válido pero el gateway no encuentra a qué Application pertenece.

---

## Parte F — Conectar el primer cliente

🌐 En Claude, `Agregar conector personalizado`:

| | |
|---|---|
| URL | `https://mcp.<dominio>/<contexto>/<version>/mcp` |
| Autenticación | **Iniciar sesión ahora** |
| Cliente OAuth | **Registrar automáticamente** (DCR) |
| Encabezados | vacíos |

> Claude puede mostrar **`Detectado`** sobre "Sin inicio de sesión". Es una detección equivocada y hay
> que ignorarla: `initialize` y `tools/list` pasan sin token, y Claude sondea con esos. Solo
> `tools/call` pide autenticación.
>
> **No elijas "Usar la identidad publicada de Claude"** aunque diga *Recomendado*: eso es CIMD y Dnato
> no lo soporta.

💻 Mientras conectás, mirá el log de Dnato — en CentOS con `mod_ssl` el tráfico HTTPS va a
`ssl_access_log`, no a `access_log`:

```bash
sudo tail -f /var/log/httpd/ssl_access_log | grep -E "oauth/(authorize|login|token|register)"
```

Tienen que aparecer, en orden: `register`, `authorize`, el login, y `token`.

### Verificación final

⌨️ Desde tu máquina:

```bash
python3 scripts/dev/mcp-smoke-tools.py
```

**Todas en `401`, 0 rotas.** Y después, en Claude, pedile que use una tool: tiene que devolver datos
reales del ambiente.

---

## Checklist

```
    PARTE A — VM y WSO2
[ ] VM Rocky Linux 9, e2-medium, en la zona de Dnato y las bases
[ ] IP estatica reservada y registro A de mcp.<dominio> propagado
[ ] Firewall: 80/443 solo con target-tag mcp-gateway. 9443 NO expuesto
[ ] JDK 21 Temurin (baseurl rhel, no rocky)
[ ] install-apim.sh + install-mi.sh + setup-reverse-proxy.sh
[ ] 6 puertos escuchando y https://mcp.<dominio> con cert de Let's Encrypt

    PARTE B — Dnato
[ ] Tag v2.5.0.12+ y las rutas oauth/* en routes.php
[ ] database.php apunta a la MISMA base que el .env del MI
[ ] composer install (vendor/) + composer_autoload con la ruta, sin comentar
[ ] Claves RS256 generadas EN ESE SERVIDOR, chown apache
[ ] seg.oauth_codes con las 10 columnas, incluida empr_id_mysql
[ ] core.empresas.empr_id_mysql existe Y esta poblada (si no, las man_* vienen vacias)
[ ] COREDataService del backend de Dnato (:8283) expone /empresa/{empr_id}
[ ] SetEnv DNATO_ISSUER y JWT_AZP en el .htaccess
[ ] AS metadata 200 con registration_endpoint, y JWKS 200

    PARTE C — APIM
[ ] CAR de ApimDiscoveryProject desplegado en el APIM
[ ] JAVA_OPTS con resource.url (sin :8243) y dnato.oauth.url
[ ] [[apim.jwt.issuer]] con name identico al iss de Dnato, y jwks.url
[ ] https_endpoint = https://mcp.<dominio>
[ ] Los dos PRM anuncian el issuer de ESTE ambiente

    PARTE D — MI
[ ] .env.car completo, chmod 600
[ ] Puertos 5434 / 3306 / 8080 ABIERTOS, regla con --priority=900
[ ] deploymcp.sh cerro en DESPLIEGUE OK
[ ] curl directo al MI: 503 en cada ruta

    PARTE E — Publicacion
[ ] API importada desde trazalog-operaciones.yaml
[ ] MCP Server creado desde la API, ofreciendo TODAS las operaciones
[ ] Endpoint http://localhost:8290/<contexto-mi> en LOS DOS artefactos
[ ] Deploy + Publish en LOS DOS
[ ] Application suscripta AL MCP SERVER en el DevPortal
[ ] Enable Subscription Validation desactivado
[ ] JWT_AZP del .htaccess = Consumer Key de esa Application

    PARTE F — Cliente
[ ] Conector creado: Iniciar sesion ahora + Registrar automaticamente
[ ] ssl_access_log de Dnato muestra register/authorize/login/token
[ ] mcp-smoke-tools.py: todas en 401, 0 rotas
[ ] Una tool devuelve datos reales en Claude
```
