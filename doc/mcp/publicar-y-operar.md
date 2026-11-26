# El conector MCP de Trazalog — publicar y operar

## Objetivo

Qué es: todo lo que hay que hacer para que una tool nueva o cambiada llegue a los asistentes de IA y para diagnosticar el conector cuando falla: el despliegue con un comando, la republicación en el API Manager, las herramientas de diagnóstico, la publicación de las especificaciones OpenAPI y la publicación en los directorios de Anthropic, OpenAI y Google. Para quién: quien despliegue u opere el MCP. Cuándo leerlo: al desplegar, al publicar tools nuevas o cuando un asistente no ve una tool. Qué NO cubre: el diseño de las tools ([`diseno.md`](diseno.md)) ni cómo se prueban ([`pruebas-y-casos.md`](pruebas-y-casos.md)).

**Partes:** 1. Desplegar el MCP · 2. Publicar tools nuevas en el MCP Server · 3. Herramientas de operación y diagnóstico · 4. Publicación de especificaciones OpenAPI en el API Manager · 5. Publicación en los directorios de Anthropic, OpenAI y Google

---

## Parte 1 — Desplegar el MCP

Cómo desplegar una actualización del MCP. Es **un comando, el mismo en todos los ambientes**: lo que
cambia de un servidor a otro vive en el `.env` de ese servidor, no en el procedimiento. Leelo cuando
haya que subir cambios al MCP — tools nuevas, queries, dataservices o sequences.

**No cubre** la instalación inicial de WSO2 ([`deployment-gcp.md`](../v3/deployment-gcp.md) §4) ni el
despliegue del frontend PHP, que va por `deploytools.sh`.

---

### El comando

💻 SSH a la VM del MCP, desde cualquier directorio:

```bash
sh ~/git/traz-tools/scripts/deploy/deploymcp.sh origin/master
```

El único argumento es **la rama o el tag** a desplegar: `origin/master`, `origin/develop`,
`v2.5.1.17`… Si no le pasás nada, usa `origin/master`.

**Es el mismo comando en todos los ambientes, sin variantes.** No hay un argumento de ambiente
porque no hace falta: lo que diferencia un ambiente de otro —las bases, el Bonita— ya está en
`deploy/gcp/.env.car` de **ese** servidor. El servidor es el ambiente.

**No hay que editar ningún archivo del repo.** Las IPs y las credenciales salen del `.env` del
ambiente, y el script las aplica sobre una **copia** del proyecto: el checkout queda limpio
(`git status` sin cambios) y las credenciales nunca entran a git.

Antes de hacer nada, el script muestra **a dónde va a quedar apuntando el MCP** y pide confirmación:

```
  Este despliegue va a dejar el MCP leyendo:
    PostgreSQL  10.142.0.2:5434/trazalog_tools  (usuario postgres)
    MariaDB     10.142.0.2:3306/asp2tecn  (usuario root)
    Bonita      http://10.142.0.2:8080/bonita  (usuario admin)

  ¿Es correcto? [s/N]
```

Leé esas tres líneas. Es el único dato que, equivocado, **no falla**: las tools responden `200`, con
estructura correcta, y datos del ambiente de al lado.

---

### Qué hace

Siete pasos, en pantalla solo el avance; todo el detalle va al log.

| | |
|---|---|
| 1 | Verifica el entorno: el repo, el `.env` (permisos `600` y las 13 variables completas), el MI y las herramientas |
| 2 | `git fetch` + `git reset --hard` a la rama o tag que le pasaste |
| 3 | **Respalda el `.car` que está andando** en `~/ToolsAPIProject_1.0.0.car.antes-de-<fecha>` |
| 4 | Copia el proyecto a `~/.cache/traz-mcp-build/<fecha>`, le aplica el `.env` y buildea con Maven |
| 5 | **Verifica el `.car` antes de desplegarlo**: que tenga las tres URLs del `.env`, que el MI siga apuntándose a sí mismo en `localhost:8290`, y que no haya quedado ninguna IP de otro ambiente |
| 6 | Copia el `.car` a `carbonapps/`, reinicia el MI y espera a que responda |
| 7 | Verifica el `.car` ya instalado y que no haya errores de datasource en el log del MI |

Si algo falla antes del paso 6, **no se desplegó nada**. Termina en `DESPLIEGUE OK` o
`DESPLIEGUE CON N ERROR(ES)`, con el log y el respaldo:

```
----------------------------------------------------
  DESPLIEGUE OK
  revision               : a1b2c3d (origin/master)
  .env                   : /home/ruiz_rodolfo/git/traz-tools/deploy/gcp/.env.car
  operaciones MCP        : 25
  respaldo del anterior  : /home/ruiz_rodolfo/ToolsAPIProject_1.0.0.car.antes-de-20261020-143000
  log completo           : /home/ruiz_rodolfo/deploymcp-20261020-143000.log
----------------------------------------------------
```

Para probar sin desplegar —arma el `.car` y lo verifica, pero no toca el MI—:

```bash
SOLO_BUILD=1 sh ~/git/traz-tools/scripts/deploy/deploymcp.sh origin/master
```

Y si alguna vez tenés que armar el `.car` para **otro** ambiente desde esta máquina, el segundo
argumento es la ruta de ese `.env`:

```bash
SOLO_BUILD=1 sh ~/git/traz-tools/scripts/deploy/deploymcp.sh origin/develop deploy/gcp/.env.car.demo
```

---

### Si hay que volver atrás

El `.car` es el único artefacto que cambia, así que el rollback no toca el APIM ni el DNS. Si hubo
errores, el script te imprime el comando exacto. Si no, es el respaldo del paso 3:

```bash
sudo cp ~/ToolsAPIProject_1.0.0.car.antes-de-<fecha> \
  /opt/wso2/wso2mi-4.5.0/repository/deployment/server/carbonapps/ToolsAPIProject_1.0.0.car && \
sudo systemctl restart wso2mi
```

---

### Cuando el despliegue trae operaciones MCP nuevas

El script despliega el MI, que es donde vive la lógica. Pero una **tool nueva** además tiene que
quedar publicada en el APIM, y eso no se puede automatizar.

El script lo detecta y te avisa al final, comparando el `.car` viejo con el nuevo:

```
  !! CAMBIO EL NUMERO DE OPERACIONES MCP: 24 -> 25
     Falta el paso del APIM, que no se puede automatizar:
     subir la OpenAPI y recrear el MCP Server.
```

Si ese aviso no aparece, no hay nada más que hacer. Si aparece, el procedimiento está en
[`../mcp/republicar-mcp-server.md`](publicar-y-operar.md) — son tres cosas: subir
`doc/api/trazalog-operaciones.yaml` en el Publisher, correr `scripts/dev/recrear-api-y-mcp.sh
--apply`, y recrear el MCP Server seleccionando las operaciones.

---

### La primera vez en una VM — que el script esté ahí

El script **vive en el repo**, en el checkout de la propia VM: no se descarga ni se instala. Antes de
la primera corrida tiene que estar en el árbol de trabajo, y hoy en `master` todavía no está — llega
con el release que lleva `develop` a `master`.

💻 En la VM, confirmá dónde está el clone. El setup inicial lo deja en una de estas dos rutas:

```bash
ls -d ~/git/traz-tools ~/traz-tools 2>/dev/null
```

Si no está en ninguna, la VM no tiene checkout. El repo es privado, así que el clone pide
credenciales — el mismo token o deploy key que use el Dnato de ese ambiente:

```bash
mkdir -p ~/git && cd ~/git && \
git clone --recurse-submodules https://github.com/Trazalog/traz-tools.git
```

Con el clone ya hecho, una sola vez a mano:

```bash
cd ~/git/traz-tools && \
git fetch --all --prune && \
git reset --hard <el-tag-a-desplegar>
```

Eso no se repite: el paso 2 de cada despliegue es exactamente ese `reset`, con el tag que le pasás al
script. Si el tag que querés desplegar todavía no tiene el script, se puede traer solo el archivo sin
mover la rama —`git checkout origin/develop -- scripts/deploy/deploymcp.sh
deploy/gcp/.env.car.example`— pero sirve para **una** corrida: el paso 2 resetea y lo borra. La
corrida en curso no se rompe por eso, porque el script está escrito todo como funciones con la
llamada al final: el archivo entero queda parseado antes de ejecutarse la primera línea.

`mvn` tiene que estar instalado en la VM. El wrapper `./mvnw` está gitignoreado y no viaja con el
clone, así que el script usa el Maven del sistema; el paso 1 lo verifica junto con `git`, `unzip` y
`python3`.

---

### La primera vez que apuntás un ambiente

Tres cosas, una sola vez por ambiente.

**1. El `.env`.** 💻 En la VM:

```bash
cd ~/git/traz-tools && \
cp deploy/gcp/.env.car.example deploy/gcp/.env.car && \
chmod 600 deploy/gcp/.env.car
```

El `.example` trae los dos juegos de valores conocidos —desarrollo y producción— con el de desarrollo
descomentado: dejás el bloque de **este** servidor y comentás el otro. Está gitignoreado
(`git check-ignore -v deploy/gcp/.env.car` lo confirma).

Las comillas son opcionales: el script lee el `.env` **como datos, no lo ejecuta**, así que una
password con `"`, `<`, `>`, `&`, `$` o espacios entra tal cual, sin escaparla.

**Por qué el `.env` pide también las credenciales de Bonita.** El MI entra a Bonita para crear
instancias de proceso, con el usuario de `bpmconf.xml`. De las 25 operaciones MCP **solo dos** lo
usan: `alm_crear_pedido_materiales` y `man_create_ot`. `bpmconf.xml` es un recurso de registry
(`/_system/config/tools`), pero a diferencia de v2 —donde `deploytools.sh` saltea el registry y los
valores se ponen una vez en el servidor— acá **lo escribe el `.car`**: está declarado en
`resources/artifact.xml` como `type="registry/resource"`, junto con `apiconfig.xml`, los dos `.js` y
la clave pública de Dnato. Por eso sus tres valores tienen que estar en el `.env`.

> 🔴 **Para producción faltan las tres passwords**: `PG_PASS`, `MY_PASS` y `BPM_PASS`. Las dos de
> base, pedilas a quien administre `vm-production-assetplanner-inst1`; la de Bonita, a quien
> administre Bonita de producción. El script se niega a buildear con una variable vacía, a propósito:
> con una password inventada el MI arranca igual y la tool devuelve vacío, que es el síntoma más
> difícil de diagnosticar.

**2. El firewall.** Las VMs tienen el tag `deny-ingress`, y en GCP **a igual prioridad el `deny`
gana**. Que la VM del MCP llegue hoy a un ambiente no implica que llegue al otro. 💻 En la VM del MCP,
con la IP del ambiente:

```bash
for p in 5434 3306 8080; do \
  timeout 5 bash -c "</dev/tcp/10.142.0.2/$p" 2>/dev/null \
  && echo "10.142.0.2:$p ABIERTO" || echo "10.142.0.2:$p CERRADO"; \
done
```

Los tres tienen que decir `ABIERTO`. ⌨️ Si falta alguno, en Cloud Shell:

```bash
gcloud compute firewall-rules create allow-bases-desde-mcp --network=default --direction=INGRESS --action=ALLOW --rules=tcp:5434,tcp:3306 --source-tags=mcp-gateway --target-tags=vm-prod --priority=900 --description="PostgreSQL 5434 y MariaDB 3306 de PROD desde mcp-trazalog"
```

> La prioridad `900` no es decorativa: con la default (1000) la regla se crea y **no habilita nada**,
> porque empata con el `deny-ingress`. Se corrige con
> `gcloud compute firewall-rules update allow-bases-desde-mcp --priority=900`.

**3. El issuer.** El MCP valida los tokens contra **un** Dnato, y tiene que ser el del mismo ambiente
que las bases. Son dos archivos de config del APIM, en la VM del MCP, y los dos tienen que decir el
mismo valor que el `DNATO_ISSUER` del `.htaccess` de ese Dnato:

```bash
sudo systemctl cat wso2am | grep -n "trazalog.dnato.oauth.url" && \
sudo grep -nA 6 "^\[\[apim.jwt.issuer\]\]" /opt/wso2/wso2am-4.6.0/repository/conf/deployment.toml
```

El primero se edita con `sudo systemctl edit --full wso2am` (dejando `trazalog.mcp.resource.url`
**como está**: el dominio del MCP no cambia), el segundo a mano, y después
`sudo systemctl daemon-reload && sudo systemctl restart wso2am`.

> ⚠️ Al cambiar el issuer **los tokens vigentes dejan de servir**: todo cliente ya conectado tiene
> que reconectar el conector en Claude. Avisalo antes.

---

### Lo que tiene que estar hecho en Dnato

Dnato emite los tokens, y de ahí sale el `empr_id` con el que filtran todas las tools. En el Dnato del
ambiente tiene que estar desplegado el tag **`v2.5.0.11` o posterior** —el primero con la pantalla de
selección de empresa del login OAuth— y su `application/config/database.php` tiene que apuntar a **la
misma base** que el `.env` del MCP, o el `empr_id` se resuelve contra otra base y las tools devuelven
datos de otra empresa sin un solo error en el log. En producción las dos cosas ya están, desde el 2026-10-20.

---

### Apéndice — Clonar la VM para un ambiente nuevo

El clon se hace de un snapshot del disco, así que **hereda el `.car` y la config tal como estén**.
⌨️ En Cloud Shell:

```bash
gcloud compute disks snapshot <disco-de-la-vm-mcp> --snapshot-names=mcp-snapshot-$(date +%Y%m%d) --zone=us-east1-b
```

```bash
gcloud compute addresses create mcp-demo-ip --region=us-east1 && \
gcloud compute disks create mcp-demo-disk --source-snapshot=mcp-snapshot-$(date +%Y%m%d) --zone=us-east1-b && \
gcloud compute instances create mcp-demo --zone=us-east1-b --machine-type=e2-medium --disk=name=mcp-demo-disk,boot=yes,auto-delete=yes --tags=<los-mismos-tags-de-red-de-la-vm-actual>
```

Los **tags de red** importan: las reglas de firewall se aplican por tag, y sin ellos la VM nueva no
habla con Dnato ni con la base. Copialos con
`gcloud compute instances describe mcp-trazalog --zone=us-east1-b --format="value(tags.items)"`.

Después, 💻 en la VM nueva, tres cosas:

1. **El dominio**, en los tres lugares que tienen que decir lo mismo: `MCP_DOMAIN` y
   `MCP_RESOURCE_URL` en `deploy/gcp/.env`, el `-Dtrazalog.mcp.resource.url` del `JAVA_OPTS` de
   `wso2am`, y el `https_endpoint` del `deployment.toml`. El PRM que consulta Claude no está
   hardcodeado: sale de esa system property, así que no hay que rebuildear nada.
2. **El issuer y el `.env`**, según "la primera vez que apuntás un ambiente".
3. 🔴 **Rehacer el `.env` con los valores de esta VM y correr el script** — es lo que la devuelve a
   su base. Hasta que el `DESPLIEGUE OK` lo confirme, esa VM **escribe en el ambiente del que se
   clonó**: el `.car` y el `.env` vienen heredados del snapshot.

Antes de apagarla, 🌐 que Let's Encrypt emita el certificado: Caddy lo pide la primera vez que el
dominio resuelve y le llega tráfico, así que si se apaga antes, el día que la prendas no vas a tener
TLS.

```bash
curl -s https://mcp-demo.cloudtrazalog.com/.well-known/oauth-protected-resource | python3 -m json.tool
```

El campo `resource` tiene que decir el dominio nuevo. Recién entonces:
`gcloud compute instances stop mcp-demo --zone=us-east1-b`.

---

## Parte 2 — Publicar tools nuevas en el MCP Server

Los 8 pasos para que una tool MCP nueva quede funcionando en un ambiente donde el MCP Server **ya
existe y está en uso**. Está escrito para ejecutarlo de corrido: cada paso dice dónde se corre, qué
comando o clic va, y qué tiene que dar para pasar al siguiente.

**Cuándo leerlo:** cada vez que cambien las operaciones de `toolsMCPAPI.xml` y de
`doc/api/trazalog-operaciones.yaml` y haya que publicarlas.

publicación inicial (crear la API y el MCP Server por primera vez) ni la identidad/OAuth —
[`../v3/deployment-gcp.md`](../v3/deployment-gcp.md) §6.3, §6.0 y §7—. El **por qué** de cada paso,
con la evidencia, está en el apéndice del final: no hace falta leerlo para ejecutar esto.

| | |
|---|---|
| **Ambientes** | DEV y las VMs de GCP — cambian los hosts, no los pasos |
| **Hace falta** | `apictl` instalado en la VM (sólo para el paso 4) y acceso al Publisher y al DevPortal |
| **Duración** | ~40 min, casi todo esperando arranques y despliegues |
| **Verificado** | 2026-08-20, llevando un MCP Server de 9 tools a 17 → **17/17 operativas** |

---

### Las tres reglas

Saltearse una deja la tool visible en `tools/list` y fallando al invocarla, **sin que nada dé un
error claro**. Son la razón de que el procedimiento sea tan largo para algo que parece un deploy.

1. **Hay que recrear la API** (paso 4). Agregarle operaciones a una API que ya tiene un MCP Server
   generado no funciona por ningún camino: quedan sin `apiOperationMapping`.
2. **El MCP Server no hereda de la API.** El vínculo se arma **sólo al crearlo**, eligiendo
   operaciones (paso 5). Después son dos artefactos independientes.
3. **`Publish` no es `Deploy`.** `Publish` lo muestra en el DevPortal, `Deploy` lo pone en el
   gateway. Hacen falta las dos, en la API y en el MCP Server.

---

### Paso 0 — Chequeo previo

⌨️ **En tu máquina**, en el repo. Los dos números tienen que ser **iguales**:

```bash
echo "MI:      $(grep -oE '<resource methods="[^"]*" uri-template="/mcp/' \
  _backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/apis/toolsMCPAPI.xml | wc -l)" && \
echo "OpenAPI: $(grep -cE '^[[:space:]]+operationId:' doc/api/trazalog-operaciones.yaml)"
```

**Si no coinciden, parar acá**: la OpenAPI y el MI tienen que declarar lo mismo.

> Se cuentan **operaciones**, no rutas: `/mcp/man/ot` tiene `GET` (`man_get_ots`) y `POST`
> (`man_create_ot`), así que hoy son 24 rutas y **25 operaciones**. Contando rutas la cuenta da 24
> vs 25 y parece un error que no existe.

Según qué cambió, cuántos pasos hacés:

| Qué cambió | Pasos |
|---|---|
| Sólo la implementación, mismo contrato | **1, 2, 7** |
| Tools nuevas, o cambios de parámetros o de descripciones | **todos** |

---

### Paso 1 — Desplegar el MI

💻 **SSH a la VM del MCP.**

> **Primero el MI, siempre.** Si la tool se publica antes de que el MI tenga la ruta, falla aunque el
> Publisher esté impecable.

```bash
sh ~/git/traz-tools/scripts/deploy/deploymcp.sh <rama-o-tag>
```

Tiene que cerrar en **`DESPLIEGUE OK`**. El `.env`, el rollback y el detalle están en
[`../v3/desplegar-mcp.md`](publicar-y-operar.md) — no se edita ningún archivo del repo. Lo que el
script **no** hace es probar las rutas nuevas una por una: curlea una sola, para saber si el MI
levantó. Eso es el paso 2.

---

### Paso 2 — Probar cada ruta nueva contra el MI

💻 **En la VM**, una vez por cada ruta nueva, salteando el APIM. El `context` de la API es
`/tools/mcp`, así que el `/mcp` va dos veces:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8290/tools/mcp/mcp/core/empresa
```

| | |
|---|---|
| **503** | ✅ seguir — la ruta existe y el MI está sano (es `identity_missing`) |
| `404` | la ruta no está en el `.car` desplegado → volver al paso 1 |
| nada / timeout | el MI no levantó → `sudo journalctl -u wso2mi -n 80` |

**Si el MI no responde, no tiene sentido seguir.**

---

### Paso 3 — Subir la OpenAPI

🌐 **Publisher** (`https://<host>:9443/publisher`).

`APIs` → la API → **`API definition`** → subir `doc/api/trazalog-operaciones.yaml` → **`Save`**.

*(No hay botón `Edit`: se entra directo y se navega por el menú izquierdo.)*

> **Va antes del paso 4, sin excepción.** El script del paso 4 reimporta la definición **tal como
> está en el APIM**: si no la actualizaste acá, recrea la API con las operaciones viejas.

---

### Paso 4 — Recrear la API

💻 **En la VM.** La primera vez en ese servidor, registrar el ambiente en `apictl`:

```bash
apictl add env prod --apim https://localhost:9443 && \
apictl login prod -u admin
```

Después, siempre dos corridas — la primera sólo muestra el plan y no toca nada:

```bash
bash scripts/dev/recrear-api-y-mcp.sh
```

```bash
bash scripts/dev/recrear-api-y-mcp.sh --apply
```

Hace: backup de la API y de **todos** los MCP Servers → los borra → borra la API → la reimporta de
cero → despliega su revisión → verifica el conteo de operaciones.

> ⚠️ **Hay una ventana con el MCP caído**, y se borran **todos** los MCP Servers que referencien la
> API, no sólo el principal: cualquiera la bloquea con `409 Cannot remove the API as it is used by
> MCP server(s)`. Elegí el momento.
>
> El script aborta en cuanto un paso falla, en vez de dejar el estado a medias. Los backups quedan en
> `/root/mcp-backup-<fecha>` y se vuelve atrás con `apictl import api -f <zip> -e prod`.

Al terminar, **el conteo de operaciones y el de la revisión desplegada tienen que coincidir** con el
número que el script imprime al arrancar (lo cuenta de la OpenAPI). Si la revisión quedó con menos,
es mapping incompleto → apéndice.

---

### Paso 5 — Crear el MCP Server desde la API

🌐 **Publisher.** Es manual a propósito: es el único camino que genera los mappings. Reimportar un
proyecto de `apictl` **descarta las tools sin mapping**.

1. `MCP Servers` → **`Create MCP Server`** → **`Start from Existing API`**
2. Elegir la API → `Next`
3. **Seleccionar las operaciones** → `Next`
4. Name / Context / Version → `Create`
5. **`Deploy`** → `Deployments` → `Deploy`
6. **`Publish`** → `Lifecycle` → `Publish`

> **En el punto 3, contá cuántas operaciones te ofrece.** Ese número es el diagnóstico: si son menos
> que las que tiene la API, la recreación no salió bien → volver al paso 4 antes de seguir.
>
> **En el punto 4, repetí el mismo Name / Context / Version que tenía.** Así la URL no cambia y los
> conectores de Claude de todos los clientes siguen andando. Si cambian, hay que reconfigurar cada
> conector **y** la system property `trazalog.mcp.resource.url` (`deployment-gcp.md` §6.2-bis),
> porque el PRM anuncia el `resource` y Claude valida que coincida.

Dos cosas que **no** se tocan:

- **`Enable Subscription Validation` queda desactivado.** Sin `azp` en el JWT de Dnato, con la
  validación activa el gateway responde `403` aunque la firma sea válida.
- **El selector de Key Managers no se toca.** Dnato no está registrado como Key Manager —APIM 4.6.0
  no tiene conector genérico para IdPs custom—; la validación la resuelve `[[apim.jwt.issuer]]` del
  `deployment.toml`.

---

### Paso 6 — Suscribir la aplicación

🌐 **DevPortal** (`https://<host>:9443/devportal`) — **otro portal, no el Publisher.**

`SUBSCRIBE TO AN APPLICATION` → la Application que usa el conector → policy `Unlimited` →
`Subscribe`.

> **Suscribí el MCP Server, no la API.** Son productos distintos del catálogo y el conector consume
> el MCP Server. Sin esto, **todas** las tools dan `403` / `900908`.
>
> El endpoint no hace falta: en MCP Servers de subtipo `EXISTING_API` el ruteo sale del mapping, y un
> `endpointConfig` en `null` es normal ahí.

---

### Paso 7 — Verificar

⌨️ **En tu máquina**, sin token ni VPN:

```bash
python3 scripts/dev/mcp-smoke-tools.py
python3 scripts/dev/mcp-smoke-tools.py --jwt "$JWT"   # ademas valida datos reales
```

**Estado correcto: todas en `401`, 0 rotas.**

| Respuesta | Significa |
|---|---|
| **`401`** | ✅ la tool está bien mapeada — el gateway llegó a pedir autenticación |
| `500` con `existingAPIOperationMapping is null` | la tool no tiene operación asociada → pasos 4 y 5 |
| `404` en todas | no hay revisión desplegada → el `Deploy` del paso 5 |
| `403` (sólo visible con token) | falta la suscripción → paso 6 |

Si algo no cierra:

```bash
python3 scripts/dev/validar-tools-e2e.py --desde-log   # el camino REAL, con token y headers Mcp-*
bash scripts/dev/diag-mcp-mapping.sh                   # mapping tool por tool, en la base
bash scripts/dev/diag-api-revisiones.sh                # working copy vs revision desplegada
```

Inventario de herramientas y qué mirar según el síntoma:
[`../operaciones/herramientas-mcp.md`](publicar-y-operar.md).

---

### Paso 8 — Refrescar el conector

🌐 **En Claude.** El cliente cachea la lista de tools: abrir una **conversación nueva**. Si la tool
sigue sin aparecer, desconectar y reconectar el conector.

---

### Checklist

```
[ ] 0  OpenAPI e implementacion con la misma cantidad de operaciones (metodo + ruta)
[ ] 1  deploymcp.sh cerro en DESPLIEGUE OK
[ ] 2  curl directo al MI: 503 en cada ruta nueva
[ ] 3  OpenAPI subida en API definition + Save
[ ] 4  API recreada; conteo de la revision desplegada = conteo de la OpenAPI
[ ] 5  MCP Server creado desde la API, ofreciendo TODAS las operaciones
[ ] 5  mismo Name / Context / Version que antes
[ ] 5  Deploy + Publish del MCP Server
[ ] 5  Enable Subscription Validation sigue desactivado
[ ] 6  Application suscripta al MCP Server en el DevPortal
[ ] 7  mcp-smoke-tools.py: todas en 401, 0 rotas
[ ] 7  validar-tools-e2e.py con token real: 0 FAIL, ninguna en 202
[ ] 8  Conector reconectado y las tools nuevas aparecen
```

---

### Si algo falla

| Síntoma | Causa | Qué hacer |
|---|---|---|
| «El conector dice que el servidor no responde». `500` con `existingAPIOperationMapping is null`, y la pantalla `Tools` del Publisher no abre | la tool no tiene operación de backend asociada | pasos **4 y 5**, en ese orden |
| La API muestra todas las operaciones y aun así no funcionan | el Publisher muestra la **working copy**; el gateway sirve la **revisión desplegada** | el `Deploy` del paso **5** |
| **La tool falla en el cliente pero el dato se creó igual** (y cada reintento lo vuelve a crear) | el MI responde `202` en las tools que escriben, y en MCP sobre HTTP `202` significa "sin cuerpo": el cliente descarta una respuesta correcta | el rewrite del `Caddyfile` ya lo cubre; si volvió, ver el apéndice |
| **Todas** las tools dan `403` / `900908` | falta la suscripción | paso **6** |
| `403` con la firma del JWT válida | `Enable Subscription Validation` quedó activo | desactivarlo (paso **5**) |
| `404` sueltos en el log que no son de ninguna tool | el cliente abre sesión con `server/discover`, que APIM 4.6.0 no conoce | benigno — el `Caddyfile` contesta el `-32601` correcto |

> 🔴 **El `api.log` del APIM miente sobre el status.** Informa `RESPONSE_OUT statusCode:200` mientras
> el cliente recibe `202`. La única fuente confiable de lo que recibe el cliente es el access log del
> reverse proxy:
>
> ```bash
> sudo tail -5 /var/log/caddy/mcp-access.log | python3 -m json.tool
> ```
>
> Y cualquier script que valide tools tiene que mandar los headers `Mcp-*` como el cliente real, o el
> rewrite de Caddy no matchea y el test da un falso negativo. `validar-tools-e2e.py` los manda.

---

### Apéndice — por qué el procedimiento es así

No hace falta para ejecutarlo. Está acá para no volver a probar lo que ya se probó: todo esto sale de
llevar un MCP Server de 9 tools a 17, entre el 18 y el 20 de agosto de 2026, contra la VM de GCP.

#### Recrear la API es lo único que inserta los mappings

Todo lo consultable por REST —`operations`, la definición OpenAPI, la revisión desplegada— mostraba
los 17 recursos. Pero `findMatchingTemplate()` lee `AM_API_URL_MAPPING`, y ahí las filas de las
operaciones agregadas **después** de generar el MCP Server nunca se insertaron. Recrear la API las
inserta todas juntas.

| Intento | Resultado |
|---|---|
| Desplegar revisión nueva de la API | necesario, pero **no alcanza** |
| `PUT` del mapping por el Publisher REST API | acepta con `200` y **guarda `null` igual** (probado 2 veces) |
| Recrear el MCP Server desde la UI | mismas tools rotas |
| Recrearlo con **nombre y contexto nuevos** | mismas tools rotas → descarta que sea el artefacto |
| `apictl import --update` | `500` — `No backends found to update for API` |
| `apictl import` como nuevo, con los mappings en el YAML | importa, pero **descarta el mapping** |
| **Recrear la API** | **17/17 mapeadas** |

**Corolario de diseño:** conviene agrupar las tools nuevas en tandas en vez de publicarlas de a una.

#### Los tres bugs de WSO2 que esto esquiva

| | |
|---|---|
| Mapping en `null` persistido | [api-manager#5106](https://github.com/wso2/api-manager/issues/5106), fix en [carbon-apimgt#13889](https://github.com/wso2/carbon-apimgt/pull/13889) — **valida y rechaza antes de persistir, pero no repara lo ya guardado** |
| `apictl import --update` | [api-manager#4997](https://github.com/wso2/api-manager/issues/4997), fix en [carbon-apimgt#13822](https://github.com/wso2/carbon-apimgt/pull/13822) — los MCP Server `EXISTING_API` no tienen backends por diseño y el path de update los exigía igual |
| El alta desde la UI | **no está reportado** |

Los tres tienen fix mergeado río arriba y ninguno aplicado acá: aplicarlos requiere suscripción WSO2.

#### El `202` de las tools de escritura

El síntoma más caro de toda la etapa: el cliente mostraba `Error occurred during tool execution`, sin
código ni detalle, y el pedido estaba creado con su `case_id` de Bonita. Cada reintento creaba otro —
**14 pedidos y 13 casos por un pedido real**. Sólo pasa en las tools de escritura: son las únicas
donde el MI responde `202`.

Lo cubre `deploy/gcp/reverse-proxy/Caddyfile`, reescribiendo `202 → 200` sólo para `tools/call`, por
el header `Mcp-Method`. Es un parche de borde: el arreglo de fondo es que el MI devuelva `200` — la
mediación `HTTP_SC` ya está en `toolsMCPAPI.xml` pero **no toma efecto en runtime**.

#### El `server/discover` del cliente

El cliente MCP (protocolo `2026-07-28`) abre sesión con `server/discover`, que no está en el
`ALLOWED_METHODS` de APIM 4.6.0 (`APIConstants.java`): responde `404` con un cuerpo de Synapse que no
es JSON-RPC, cuando correspondería `-32601`. El cliente hace fallback a `2025-06-18` y sigue, así que
es benigno, pero es un gap real de compatibilidad.

#### Fuentes

| Paso | De dónde sale |
|---|---|
| 3 — `API definition`, sin botón `Edit` | [Edit an API by modifying the API Definition](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/tutorials/edit-an-api-by-modifyng-the-api-definition.md) |
| 4 — comandos de `apictl` | [Managing MCP Servers](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/apiops/cli/managing-mcp-servers/managing-mcp-servers.md), [Migrating MCP Servers](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/apiops/cli/managing-mcp-servers/migrating-mcp-servers-to-different-environments.md) |
| 5 — crear el MCP Server desde una API | [Create a MCP Server Using an Existing API](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/ai-gateway/mcp-gateway/create-from-api.md) |
| 5 — `Deploy` y `Publish` | [deploy-revision](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/includes/design/deploy-revision.md), [Updating Tools and Deploying the MCP Server](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/ai-gateway/mcp-gateway/update-and-deploy-mcp-server.md) |
| 6 — `SUBSCRIBE TO AN APPLICATION` | [Subscribe to a MCP Server](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/ai-gateway/mcp-gateway/subscribe-to-a-mcp-server.md) |
| Todo el apéndice | verificado contra la VM de GCP, 2026-08-18/20 |

> `apim.docs.wso2.com` responde `403` a descargas automatizadas. Las fuentes apuntan al repositorio
> del que se genera esa documentación, [`wso2/docs-apim`](https://github.com/wso2/docs-apim), rama
> **`4.6.0`**, que es la versión instalada.

#### Pendientes

- **`apictl` no está integrado al flujo.** Con `import mcp-server` sobre un proyecto versionado, el
  MCP Server sería reproducible desde el repo igual que el `.car`, y los pasos 3 a 6 dejarían de ser
  un procedimiento de consola y navegador.
- **El `202` de fondo**, arriba: que el MI devuelva `200` y el `Caddyfile` deje de parchearlo.
- **Las credenciales de Bonita están en texto plano** en los dos `bpmconf.xml`.

---

## Parte 3 — Herramientas de operación y diagnóstico

Inventario de los scripts de `scripts/dev/` que sirven para **operar y diagnosticar la capa MCP**:
qué hace cada uno, cuándo usarlo y qué tramo del camino valida. Está escrito para quien tenga que
verificar un despliegue o entender por qué una tool falla, sin haber vivido el diagnóstico original.

**Cuándo leerlo:** antes de tocar nada cuando una tool no responde, y después de cada despliegue
para validar.

[`../mcp/republicar-mcp-server.md`](publicar-y-operar.md). Ni la instalación de la
infraestructura — [`../v3/deployment-gcp.md`](../v3/deployment-gcp.md).

---

### El camino completo, y qué valida cada script

Entender esto ahorra la mayor parte del tiempo de diagnóstico. Una llamada de Claude atraviesa
**cinco tramos**, y cada script cubre uno o varios:

```
Claude  ──►  Caddy :443  ──►  APIM gateway :8243  ──►  MI :8290  ──►  PostgreSQL / MySQL
                                                          └────────►  Bonita :8080
```

| Script | Tramos que valida | Necesita token |
|---|---|---|
| **`validar-tools-e2e.py`** | **todos** — es el que decide si algo anda | sí |
| `mcp-smoke-tools.py` | Caddy + gateway (sólo el mapeo de tools) | no |
| `smoke-tools-mi.py` | MI + base + Bonita (saltea Caddy y gateway) | no |
| `diag-kpi-mttr.sh` | los 3 niveles de una tool, por separado | no |

---

### 1. Validación — lo que hay que correr después de cada despliegue

#### `validar-tools-e2e.py` — **el principal**

Recorre el camino real y prueba las 17 tools con un token real.

```bash
python3 scripts/dev/validar-tools-e2e.py --desde-log
python3 scripts/dev/validar-tools-e2e.py --jwt "$JWT" --escrituras
```

Verifica tres cosas por tool, y la primera es la que más costó aprender:

1. **El status HTTP en el cable.** No el que reporta el `api.log` del APIM: durante el bug del `202`
   ese log decía `statusCode:200` mientras el cliente recibía `202`.
2. JSON-RPC válido, sin `isError: true`.
3. Contenido no vacío.

Manda los headers `Mcp-Method`, `Mcp-Name` y `Mcp-Protocol-Version` **igual que el cliente real** —
sin eso, el rewrite de Caddy no matchea y da un falso negativo.

El token se pasa con `--jwt` o se extrae del `api.log` con `--desde-log` (requiere API Logs en FULL).
**El token emitido por CLI de Dnato no sirve**: queda con `iss=http://localhost/oauth` y el gateway
lo rechaza con `900901`.

> `--escrituras` crea registros reales e instancia procesos en Bonita. Sin ese flag se omiten.

#### `mcp-smoke-tools.py` — chequeo rápido, sin token

```bash
python3 scripts/dev/mcp-smoke-tools.py
```

Sirve para una sola cosa, pero la resuelve en segundos: distinguir una tool **bien mapeada** de una
con el `apiOperationMapping` roto.

| Respuesta | Significa |
|---|---|
| `401` | la tool está bien mapeada (el gateway llegó a pedir auth) |
| `500` con `existingAPIOperationMapping is null` | falta la operación de backend → hay que recrear la API |
| `404` en todas | no hay revisión desplegada |

#### `smoke-tools-mi.py` — aislar el backend

```bash
python3 scripts/dev/smoke-tools-mi.py --empresa <empr_id_mysql> --empresa-pg <empr_id>
```

Pega al MI directo con un `X-JWT-Assertion` sintético (`EmprIdFromHeader` no valida la firma, sólo
decodifica el payload). **Si acá funciona y por el camino completo no, el problema está en el
gateway o en Caddy** — es la bifurcación más útil del diagnóstico.

> Los dos ids de empresa no son intercambiables: las tools `man_*` filtran por `empr_id_mysql`
> (assetv2) y las `alm_*` por `empr_id` (PostgreSQL). Ambos viajan en el mismo JWT.

---

### 2. Diagnóstico — cuando algo falla

#### `capturar-fallo-tool.sh` — ver el error real de una tool

```bash
bash scripts/dev/capturar-fallo-tool.sh
```

Sigue a la vez los logs del APIM y del MI, filtrando por las rutas de las tools y los códigos de
error de WSO2. Se deja corriendo y se reproduce el fallo desde el cliente.

#### `ver-access-log.sh` — URL y status reales

```bash
bash scripts/dev/ver-access-log.sh
```

El log de Synapse no dice ni la URL ni el código de respuesta. Además verifica que el CAR desplegado
tenga los fixes esperados.

> **El access log más importante no es el de WSO2 sino el de Caddy**
> (`/var/log/caddy/mcp-access.log`): es el único que muestra **lo que realmente recibe el cliente**.
> Fue el que resolvió el bug del `202`.
>
> ```bash
> sudo tail -5 /var/log/caddy/mcp-access.log | python3 -m json.tool
> ```

#### `diag-mcp-mapping.sh` — estado de las tools en la base del APIM

```bash
bash scripts/dev/diag-mcp-mapping.sh
```

Lista tool por tool si tiene `apiOperationMapping`, y compara contra los recursos de la API fuente.
Imprescindible cuando la pantalla `Tools` del Publisher no abre — que es lo que pasa justamente
cuando hay mappings rotos ([wso2/api-manager#5106](https://github.com/wso2/api-manager/issues/5106)).

#### `diag-api-revisiones.sh` — working copy vs revisión desplegada

```bash
bash scripts/dev/diag-api-revisiones.sh
```

El Publisher muestra la working copy; el gateway sirve la revisión desplegada. **Pueden diferir**, y
esa diferencia fue la causa de que 8 tools no mapearan durante días.

#### `diag-kpi-mttr.sh` — una tool en sus 3 capas

```bash
bash scripts/dev/diag-kpi-mttr.sh 15 2024-01-01 2026-07-31
```

Prueba DataService, fachada MCP en el MI y gateway por separado. El patrón sirve para cualquier tool:
saber en cuál de las tres se corta acota el problema de entrada.

---

### 3. Mantenimiento — operaciones que modifican

#### `recrear-api-y-mcp.sh` — recrear la API

```bash
bash scripts/dev/recrear-api-y-mcp.sh              # plan, no toca nada
bash scripts/dev/recrear-api-y-mcp.sh --apply
```

**Es la única forma de que las tools nuevas queden mapeadas.** Agregarle operaciones a una API que ya
tiene un MCP Server generado no funciona por ningún otro camino
([`../mcp/republicar-mcp-server.md`](publicar-y-operar.md), apéndice).

Destructivo sobre producción: hace backups antes de borrar nada, aborta en cada paso crítico, y no
recrea el MCP Server (eso va por la UI, que es lo único que genera los mappings).

#### API Logs — el diagnóstico más potente, y el más sensible

Logging por API, sin reiniciar, con headers y payload completos de los cuatro flujos
(`REQUEST_IN`, `REQUEST_OUT`, `RESPONSE_IN`, `RESPONSE_OUT`):

```bash
curl -k -u admin:admin -X PUT \
  "https://localhost:9443/api/am/devops/v0/tenant-logs/carbon.super/apis/<ID>" \
  -H "Content-Type: application/json" \
  -d '{"logLevel":"FULL"}'
```

> ⚠️ **En FULL escribe los `Authorization` y los `Internal-Key` completos en texto plano.** Apagarlo
> (`{"logLevel":"OFF"}`) apenas termina el diagnóstico.
>
> El `<ID>` sale de `diag-mcp-mapping.sh`. Conviene habilitarlo en el **MCP Server y en la API
> fuente**, para ver los dos saltos.

---

### 4. Qué mirar primero, según el síntoma

| Síntoma | Empezar por |
|---|---|
| «el servidor no responde» en el cliente | `mcp-smoke-tools.py` — si da `500`, es mapping roto |
| Una tool devuelve error pero **el dato se creó igual** | el access log de **Caddy**: mirar el status. Un `202` rompe al cliente |
| Todas las tools dan `404` | no hay revisión desplegada del MCP Server |
| Todas dan `403` / `900908` | falta la suscripción de la aplicación en el DevPortal |
| `900901 Invalid Credentials` | el `iss` del token no coincide con `[[apim.jwt.issuer]]` |
| Las tools `man_*` devuelven vacío y las `alm_*` traen datos | el token tiene `empr_id_mysql` vacío — es dato, no despliegue |
| El backend anda pero el cliente falla | `smoke-tools-mi.py`: si pasa, el problema es gateway o Caddy |
| Ningún log de WSO2 se escribe | config de log4j2 rota o proceso huérfano — comparar contra `http_access` de Tomcat, que no pasa por log4j |

---

### 5. Scripts de otras etapas

Siguen en `scripts/dev/` y no son parte del diagnóstico MCP:

| Script | Para qué |
|---|---|
| `mcp_tools_client.py`, `mcp_escenarios.py` | escenarios encadenados de negocio (13 casos) |
| `verify-mcp-queries.py`, `verify-mcp-isolation.py` | regresión de queries y aislamiento multi-empresa |
| `check-dnato-mcp-auth.sh` | verificador del flujo de auth en Dnato |
| `kpi-*.sql`, `verificar-kpi-*.sql` | diagnóstico de los KPIs de mantenimiento (`../mantenimiento/`) |
| `mcp-oauth-proxy.py`, `mcp-session-shim.py`, `setup-apim-b3-mcp-apis.sh` | de la etapa de ngrok/DEV, previos al despliegue en GCP |

---

## Parte 4 — Publicación de especificaciones OpenAPI en el API Manager

Checklist de consola para publicar por primera vez una spec OpenAPI nueva
en el Publisher de WSO2 APIM 4.6.0 (importar, configurar backend/seguridad,
publicar, verificar). Es para vos (Rodolfo), en la consola.

**Si ya publicaste la API antes y solo cambiaste la spec**, no hace falta
repetir todo esto — ver §7 (re-publicar) o, más resumido,
[`doc/infra/wso2.md`](../infra/wso2.md) §2.

> ⚠️ **Este documento es de Sprint 2 y quedó desactualizado en un punto
> importante:** describe la identidad como un header `X-Empr-Id` inyectado
> por una mediación del APIM (§3.4, §6). Ese mecanismo **ya no es el
> vigente** — desde ADR-009 el APIM genera su propio backend JWT
> (`apim.jwt.enable=true`) y lo manda como `X-JWT-Assertion`; el MI lo lee
> con la sequence `emprIdFromHeader`. No hace falta ninguna mediación de
> `X-Empr-Id` por API. Detectado al escribir
> [`virtual-mcp-unificado.md`](diseno.md) — no
> corregido acá todavía, queda pendiente.

**Tarea:** E1-API-10 (rehecha por ADR-008)
**Aplica a:** `equipos.yaml`, `ot.yaml`
**Decisión base:** [ADR-008](../v3/TRAZALOG_v3_MCP_ARCHITECTURE.md) — el APIM valida el JWT de
Dnato como **Key Manager federado**. El MI **no** valida JWT para tráfico MCP.
**Prerequisito:** WSO2 APIM 4.6.0 corriendo (`https://localhost:9443`) **y** Dnato configurado
como Key Manager federado (ver [apim-keymanager-dnato.md](../identidad/identidad-y-seguridad.md)).

> Reemplaza a [`openapi-publish-procedure.OBSOLETE.md`](../historial/api/openapi-publish-procedure.OBSOLETE.md),
> que usaba el patrón "JWT passthrough" descartado.

---

### 1. Visión general (flujo ADR-008)

```
doc/api/equipos.yaml          doc/api/ot.yaml
        │                             │
        ▼                             ▼
  API Publisher              API Publisher
  (9443/publisher)           (9443/publisher)
        │                             │
        │  seguridad: OAuth2 + Key Manager "Dnato" (NO Resident KM)
        ▼                             ▼
  API Gateway (:8243)        API Gateway (:8243)
   ├─ valida firma JWT vs JWKS de Dnato
   ├─ valida exp / iss / aud
   ├─ mediación: extrae empr_id → inyecta header X-Empr-Id
        │                             │
        ▼                             ▼
  toolsMANAPI (MI :8280)     toolsMANAPI (MI :8280)
   (NO valida JWT — lee X-Empr-Id del header ya inyectado)
        │                             │
        ▼                             ▼
  DataServices → filtran por X-Empr-Id
```

**Diferencia clave con el procedimiento obsoleto:** la validación del JWT y la extracción del
`empr_id` ocurren **en el APIM**, no en el MI. No se deshabilita seguridad a nivel de Resource y
**no** se toca `enable_outbound_auth_header`.

---

### 2. Prerequisito: Key Manager "Dnato" configurado

Antes de publicar las APIs, el APIM debe tener registrado el Key Manager federado de Dnato.
Ver el procedimiento completo en
**[apim-keymanager-dnato.md](../identidad/identidad-y-seguridad.md)**. En resumen, debe existir
en `https://localhost:9443/admin` → **Key Managers** una entrada **`Dnato`** de tipo externo,
apuntando al JWKS de Dnato (`/oauth/.well-known/jwks.json`), con issuer `trazalog-dnato` y
audience `trazalog-mcp`, y **validación de suscripción desactivada** (MVP).

---

### 3. Publicar `equipos.yaml` — API de Equipos

#### 3.1 Importar la spec

1. Ir a: `https://localhost:9443/publisher`
2. Iniciar sesión con credenciales de administrador
3. **`+ Create API`** → **`Import OpenAPI`**
4. Seleccionar `doc/api/equipos.yaml` desde el filesystem
5. Verificar los campos pre-completados:
   - **Name:** `Equipos`
   - **Version:** `1.0`
   - **Context:** `/equipos`
6. **`Create`**

#### 3.2 Configurar el backend (Endpoint)

En **`Develop`** → **`API Configurations`** → **`Endpoints`**:

| Campo | Valor |
|---|---|
| Endpoint type | HTTP/REST Endpoint |
| Production URL | `http://10.142.0.13:8280/tools/man` |
| Sandbox URL | `http://10.142.0.13:8280/tools/man` |

> El APIM proxea al MI (port 8280). El contexto `/tools/man` ya está en `toolsMANAPI.xml`.

#### 3.3 Configurar seguridad — OAuth2 con Key Manager Dnato

En **`Develop`** → **`API Configurations`** → **`Runtime`** → **`Application Level Security`**:

1. **Marcar `OAuth2`** como esquema de seguridad (este sí es el esquema correcto — el APIM
   valida el token). Desmarcar Basic Auth y API Key salvo que se necesiten.
2. En **`Key Managers`** (sección de la misma pestaña Runtime, o en la config de la API):
   **seleccionar únicamente `Dnato`**. **Des-seleccionar `Resident Key Manager`** — las APIs
   MCP no usan el KM interno del APIM, usan el federado de Dnato.

> **Por qué OAuth2 y no "passthrough":** a diferencia del procedimiento obsoleto, acá el APIM
> SÍ valida el token (contra el JWKS de Dnato vía el KM federado). No se deshabilita la
> seguridad del Resource. El header `Authorization: Bearer <JWT Dnato>` lo consume y valida el
> APIM; downstream va el header `X-Empr-Id` (ver §6), no el token crudo.

> ⚠️ **NO aplicar** `enable_outbound_auth_header = true` en `deployment.toml`. Es un flag global
> que rompería el comportamiento de las APIs legacy. ADR-008 lo prohíbe explícitamente.

#### 3.4 Asociar la mediación de inyección de `empr_id`

Aplicar a esta API la policy/mediación que extrae `empr_id` del JWT y lo inyecta como header
`X-Empr-Id` hacia el MI. Ver **[empr-id-injection.md](../identidad/identidad-y-seguridad.md)** para
el artefacto y los pasos de asociación (policy reutilizable, no copy-paste por API).

#### 3.5 Publicar

1. **`Publish`** (esquina superior derecha)
2. Estado → `Published`
3. URL del gateway: `https://localhost:8243/equipos/1.0/mcp/equipos`

#### 3.6 Verificar — con JWT REAL de Dnato

```bash
# 1. Obtener un JWT real firmado por Dnato (CLI de Dnato, en el host de Dnato):
#    php index.php cli issue_test_token <email> [empr_id]
JWT="<pegar el JWT emitido por Dnato>"

# 2. Lista de equipos vía APIM gateway (debe responder 200)
curl -k -H "Authorization: Bearer $JWT" \
     https://localhost:8243/equipos/1.0/mcp/equipos

# 3. Detalle de equipo
curl -k -H "Authorization: Bearer $JWT" \
     https://localhost:8243/equipos/1.0/mcp/equipo/10

# 4. Token inválido / sin token → el APIM debe responder 401 (no llega al MI)
curl -k https://localhost:8243/equipos/1.0/mcp/equipos          # 401
curl -k -H "Authorization: Bearer xxx.yyy.zzz" \
     https://localhost:8243/equipos/1.0/mcp/equipos              # 401
```

---

### 4. Publicar `ot.yaml` — API de Órdenes de Trabajo

#### 4.1 Importar la spec

1. **`+ Create API`** → **`Import OpenAPI`**
2. Seleccionar `doc/api/ot.yaml`
3. Verificar:
   - **Name:** `Ordenes de Trabajo`
   - **Version:** `1.0`
   - **Context:** `/ordenes-trabajo`
4. **`Create`**

#### 4.2 Configurar el backend

| Campo | Valor |
|---|---|
| Endpoint type | HTTP/REST Endpoint |
| Production URL | `http://10.142.0.13:8280/tools/man` |
| Sandbox URL | `http://10.142.0.13:8280/tools/man` |

#### 4.3 Seguridad y mediación

Idéntico a Equipos (ver §3.3 y §3.4): OAuth2 + Key Manager **Dnato** (no Resident KM) +
mediación de inyección de `X-Empr-Id`. El Key Manager y la policy de mediación son compartidos
— no se vuelven a crear, solo se asocian a esta API.

#### 4.4 Publicar y verificar

```bash
JWT="<JWT real de Dnato>"

# Listar OTs vía APIM
curl -k -H "Authorization: Bearer $JWT" \
     https://localhost:8243/ordenes-trabajo/1.0/mcp/ot

# Detalle de OT
curl -k -H "Authorization: Bearer $JWT" \
     https://localhost:8243/ordenes-trabajo/1.0/mcp/ot/1842

# Crear OT (create_ot demo tool)
curl -k -X POST \
     -H "Authorization: Bearer $JWT" \
     -H "Content-Type: application/json" \
     -d '{"equipo_id":"10","descripcion":"Test OT desde APIM gateway"}' \
     https://localhost:8243/ordenes-trabajo/1.0/mcp/ot
```

---

### 5. Asociar las specs al MCP Gateway (Virtual MCP Server)

Una vez publicadas las APIs en APIM, asociarlas al Virtual MCP Server:

1. Ir al **`MCP Gateway`** de APIM 4.6.0
   (si no está visible, habilitar el plugin MCP en `deployment.toml`).
2. Crear un **`Virtual MCP Server`** para cada API:

| MCP Server | API | Tools generadas |
|---|---|---|
| `trazalog-equipos` | Equipos 1.0 | `get_equipos`, `get_equipo` |
| `trazalog-ots` | Ordenes de Trabajo 1.0 | `get_ots`, `get_ot`, `create_ot` |

3. El APIM deriva las MCP tools desde los `operationId` y las `description` de cada operación.

> **Ventaja ADR-008:** como la seguridad ya está resuelta en el APIM (Key Manager Dnato), el
> Virtual MCP Server hereda la validación automáticamente. No hay que rediseñar nada de
> seguridad al activar la capa MCP.

---

### 6. Cómo el APIM inyecta `empr_id` downstream al MI

Resumen (detalle completo en [empr-id-injection.md](../identidad/identidad-y-seguridad.md)):

1. El APIM valida el JWT de Dnato (firma vs JWKS, `exp`, `iss`, `aud`).
2. Una mediación in-flow extrae el claim `empr_id` del JWT validado.
3. La mediación setea el header **`X-Empr-Id: <empr_id>`** en el request hacia el MI.
4. El MI **no valida JWT**; lee `X-Empr-Id` (sequence `emprIdFromHeader`) y lo usa para
   construir las URLs de los DataServices, que filtran por `empr_id`.

El cliente no puede falsificar `X-Empr-Id`: el APIM lo sobreescribe en cada request a partir del
claim del token ya validado, ignorando cualquier `X-Empr-Id` entrante.

---

### 7. Re-publicar tras cambios en la spec

> **Para un MCP Server ya publicado, este procedimiento NO alcanza.** Le faltan dos
> pasos imprescindibles: desplegar una **revisión nueva** (guardar no publica — el
> gateway sirve la última revisión desplegada), y agregar las tools nuevas **al MCP
> Server**, que es un artefacto separado y no hereda las operaciones de la API. El
> procedimiento completo está en
> [`../mcp/republicar-mcp-server.md`](publicar-y-operar.md).
>
> ⚠️ **El punto 5 de abajo está desactualizado:** Dnato **no** se registra como Key Manager (APIM
> 4.6.0 no tiene conector genérico para IdPs custom) — no hay nada que asociar ni que verificar en
> ese selector. La validación del JWT la resuelve `[[apim.jwt.issuer]]` en el `deployment.toml`. Lo
> que sí hay que confirmar es que `Enable Subscription Validation` siga **desactivado**. Ver
> [`../mcp/virtual-mcp-unificado.md`](diseno.md) §2.4 y
> [`../identity/apim-keymanager-dnato.md`](../identidad/identidad-y-seguridad.md) §3.

1. Publisher → seleccionar la API → **`Edit`**
2. **`API Definition`** → **`Import`** → subir el archivo actualizado
3. **`Save`**
4. Si los paths/methods cambiaron: volver a publicar (**`Publish`**)
5. Verificar que la API sigue asociada al Key Manager **Dnato** y a la mediación de `empr_id`
   (re-importar la definición no debe desasociarlas, pero conviene confirmar).

---

### 8. Checklist de publicación

```
[ ] equipos.yaml válido (npx swagger-cli validate doc/api/equipos.yaml)
[ ] ot.yaml válido
[ ] Key Manager "Dnato" configurado y activo (apim-keymanager-dnato.md)
[ ] JWKS de Dnato accesible desde el host del APIM
[ ] Backend URL apuntando al MI (no a APIM mismo)
[ ] Seguridad = OAuth2, Key Manager = SOLO Dnato (Resident KM des-seleccionado)
[ ] Mediación de inyección de X-Empr-Id asociada a ambas APIs
[ ] enable_outbound_auth_header NO presente en deployment.toml
[ ] Ambas APIs en estado Published
[ ] curl con JWT real de Dnato → 200; sin token / token inválido → 401
[ ] Aislamiento verificado: JWT empresa A no ve datos de empresa B
[ ] Virtual MCP Servers creados en el MCP Gateway
```

---

### 9. Validar las specs localmente antes de publicar

```bash
npm install -g @apidevtools/swagger-cli
npx swagger-cli validate doc/api/equipos.yaml
npx swagger-cli validate doc/api/ot.yaml
```

Ambos deben devolver `... is valid` sin errores.

---

## Parte 5 — Publicación en los directorios de Anthropic, OpenAI y Google

Guía paso a paso para que el MCP Server de Trazalog aparezca en los directorios de conectores de
**Claude (Anthropic)**, **ChatGPT (OpenAI)** y **Gemini (Google)**, en ese orden. Está escrita para
el PM, para ir preparando los trámites **antes** de que la versión de `develop` pase a producción,
así el día del cutover se envía y no se empieza. Cubre qué exige cada directorio, qué de eso
Trazalog ya cumple, qué falta, y los pasos exactos de cada envío. **No cubre** cómo publicar tools
nuevas en el APIM (eso está en [`republicar-mcp-server.md`](publicar-y-operar.md)) ni el
despliegue a producción en sí.

| | |
|---|---|
| **Relevado el** | 2026-09-22, contra la documentación oficial de los tres proveedores (links al final) |
| **Versión que se publica** | la de `develop` — 20 tools, MCP Server en `https://mcp.cloudtrazalog.com/trazalog/mcp/1.0/mcp` |
| **Authorization Server** | Dnato — `https://<host-dnato>/traz-comp-dnato/oauth/` |
| **Vigencia** | los tres procesos cambiaron durante 2026; **revalidar los links oficiales antes de enviar** |

---

### 1. Lo primero que hay que entender: no son tres directorios

Los tres se llaman parecido y funcionan distinto. Conviene tenerlo claro antes de asignar tiempo:

| | Anthropic (Claude) | OpenAI (ChatGPT) | Google (Gemini) |
|---|---|---|---|
| **¿Hay directorio público con botón de enviar?** | **Sí** — Connectors Directory | **Sí** — Plugins Directory (compartido por ChatGPT y Codex) | **No.** No existe un directorio público al que enviar |
| **¿Hay revisión?** | Automática al enviar; listado como *community*. Revisión humana solo si Anthropic lo escala a *verified* | Manual, sin plazos publicados | No aplica |
| **¿Quién configura el conector del lado del cliente?** | El usuario lo agrega desde el directorio | El usuario lo agrega desde el directorio | **El administrador de cada cliente** lo registra en su propio Google Cloud |
| **Cuenta que necesita Trazalog** | Claude **Team o Enterprise** (no sirve plan individual) | OpenAI Platform con **identidad de negocio verificada** | Ninguna: Trazalog no envía nada, entrega una guía al cliente |
| **Registro de cliente OAuth** | DCR (ya lo tenemos) | DCR (ya lo tenemos) o CIMD | **`client_id` + `client_secret` fijos** — DCR no aplica |
| **Esfuerzo estimado** | 1 a 2 días de preparación + espera de revisión | 2 a 4 días de preparación + espera de revisión | Medio día para la guía del cliente |

En la práctica: **Anthropic y OpenAI son trámites; Google es un documento para entregarle al cliente.**

---

### 2. Lo que hay que tener ANTES de empezar cualquiera de los tres

Estos requisitos se repiten en los tres. Conviene resolverlos una sola vez, primero. La columna de
estado es lo verificado el 2026-09-22 contra `develop` y contra los sitios públicos.

#### 2.1 Páginas públicas obligatorias

| Página | Anthropic | OpenAI | Google | Estado hoy |
|---|---|---|---|---|
| **Política de privacidad** (HTTPS) | obligatoria | obligatoria | recomendada | ❌ **No existe.** `trazalog.com/privacidad` y `/politica-de-privacidad` dan 404 |
| **Términos de servicio** | — | obligatoria | — | ❌ No existe |
| **Documentación del conector** (alcanza una página de ayuda) | obligatoria al publicar | obligatoria | — | 🟡 Existe `doc/manuales/conectar-claude-a-trazalog.md` en el repo, pero **no está publicada en una URL** |
| **Contacto de soporte** | obligatorio | obligatorio | — | 🟡 Definir mail (ej. `soporte@trazalog.com`) |
| **Sitio web de la empresa** | — | obligatorio, y debe coincidir con la identidad verificada | — | ✅ `www.trazalog.com` |

**La política de privacidad es la que más trabajo lleva y la que más rechazos genera.** Anthropic
la marca como causa de rechazo inmediato. Tiene que cubrir, textualmente: qué datos se recogen,
para qué se usan y dónde se guardan, con quién se comparten, cuánto se retienen, y un contacto.
OpenAI suma: categorías de datos, destinatarios y controles del usuario.

> 💻 **Dónde**: son páginas del sitio `www.trazalog.com`. Quien administre ese sitio las publica.
> Para la documentación del conector, la opción más rápida es convertir el manual que ya existe
> (`doc/manuales/conectar-claude-a-trazalog.md`) en una página del sitio o del centro de ayuda.

#### 2.2 Cuenta de prueba para el revisor

Los tres piden credenciales de un usuario **con datos realistas cargados** (no una empresa vacía).
OpenAI además exige que funcione **sin MFA, sin confirmación por mail ni SMS, y sin VPN**.

Qué preparar: una empresa de demostración en producción con equipos, órdenes de trabajo, stock,
pedidos y movimientos suficientes para que cada tool devuelva algo, y **un usuario de esa empresa
que tenga exactamente una empresa asignada** (la versión de `develop` no tiene selector de empresa:
con más de una, el login OAuth rechaza el ingreso).

> ⚠️ El revisor va a **crear registros reales**: `man_create_ot` abre una OT en Bonita y
> `alm_crear_pedido_materiales` crea un pedido. La empresa de prueba tiene que ser descartable.

#### 2.3 Logo e ícono

| | Anthropic | OpenAI |
|---|---|---|
| Ícono / logo | URL o SVG, más favicon | logo "production-ready" |

Usar el isologo (`public/img/logotzl.png` en dnato, 17 KB) o su versión SVG si existe.

#### 2.4 Anotaciones de las tools

Es el requisito técnico donde **los tres difieren**, y donde `develop` hoy cumple con dos de tres:

| Anotación | Anthropic | OpenAI | Google | Estado en `develop` (20 tools) |
|---|---|---|---|---|
| `title` | obligatorio | obligatorio | — | ✅ las 20 |
| `readOnlyHint` | obligatorio en las de lectura | **obligatorio en todas** (`true` o `false`) | recomendado | 🟡 18 con `true`; las 2 de escritura **no lo declaran** |
| `destructiveHint` | obligatorio en las de escritura | obligatorio en las de escritura | recomendado | ✅ las 2 de escritura |
| `openWorldHint` | — | **obligatorio en todas** | — | ❌ **ninguna lo declara** |
| Nombre ≤ 64 caracteres | obligatorio | — | — | ✅ la más larga tiene 28 |

**Para OpenAI hay que tocar la OpenAPI**: agregar `openWorldHint: false` a las 20 (Trazalog opera
sobre un espacio privado y acotado, no sobre internet abierto) y `readOnlyHint: false` explícito a
`man_create_ot` y `alm_crear_pedido_materiales`. Anthropic y Google no lo exigen, pero **no
molesta**: conviene hacerlo una vez para los tres. Ver §7.

#### 2.5 OAuth — lo que ya está y lo que falta

Dnato ya cumple lo esencial y es lo que hoy hace funcionar el conector de Claude:

| Requisito | Estado en `develop` |
|---|---|
| Metadata RFC 8414 en `/.well-known/oauth-authorization-server` | ✅ |
| Protected Resource Metadata RFC 9728 en el MCP Server | ✅ |
| Dynamic Client Registration (RFC 7591) | ✅ |
| PKCE S256 y `code_challenge_methods_supported: ["S256"]` | ✅ |
| `token_endpoint_auth_methods_supported: ["none"]` | ✅ |
| `/token` acepta `application/x-www-form-urlencoded` | ✅ |
| **Refresh token** | ❌ **No se emite.** TTL fijo de 24 h (`jwt.php:68`) |
| **UserInfo endpoint** con `email` y `email_verified` | ❌ No existe |
| Scopes `openid` / `email` / `offline_access` | ❌ No se publican `scopes_supported` |
| Redirect URI de Claude | ✅ acepta `https://claude.ai/api/mcp/auth_callback` |
| Redirect URIs de ChatGPT | ✅ **sin cambios**: el DCR guarda los `redirect_uris` que el cliente declara |
| Redirect URI de Google | ❌ Google no usa DCR: hay que registrar un cliente estático (§6) |

**Sobre el refresh token.** No es bloqueante en ningún directorio, pero con TTL de 24 h y sin
renovación, cada usuario tiene que **reconectar el conector todos los días**. Claude renueva
reactivamente cuando recibe 401, así que la experiencia es "un día anda, al otro pide login".
Un revisor que pruebe dos días seguidos lo va a notar. Es el TODO de `jwt.php:69` y conviene
resolverlo antes de publicar en cualquiera de los dos directorios con revisión.

**Sobre el UserInfo.** OpenAI lo exige **solo para la función de restringir el plugin por dominio
de workspace** (para que empresas limiten quién lo usa). No bloquea la publicación. Para el
segmento B2B de Trazalog es deseable, pero puede venir después.

#### 2.6 Red y latencia

- Anthropic sale a internet desde **`160.79.104.0/21`**. Ya funciona, así que el firewall de GCP lo
  permite; **no tocar esa regla** en el cutover.
- Anthropic espera **como máximo 10 segundos** en discovery, registro y token, y 30 en refresh. El
  Dnato de producción tiene que responder bien por debajo de eso. Si el `/token` tarda varios
  segundos (PHP 5.6 + consultas a Bonita), los usuarios van a ver fallos intermitentes de conexión.
- Google exige **certificado TLS de una CA pública** (Let's Encrypt sirve; autofirmado no) y
  **transporte Streamable HTTP** — SSE no está soportado. El MCP Server del APIM 4.6 ya es
  Streamable HTTP.

---

### 3. Paso 0 (recomendado): el MCP Registry oficial

Antes de los tres directorios propietarios, conviene registrar el servidor en el **MCP Registry
oficial** (`registry.modelcontextprotocol.io`). Es un catálogo neutral de metadatos que los clientes
MCP consultan; no reemplaza a ninguno de los tres, pero da presencia y un nombre canónico
(`com.trazalog/…`) que después se cita en los otros envíos. Está en *preview*: puede haber cambios.

**Requiere probar que somos dueños del dominio.** Se hace una vez, con un par de claves.

💻 En la **terminal local** (Linux):

**1. Instalar la herramienta**

```bash
curl -L "https://github.com/modelcontextprotocol/registry/releases/latest/download/mcp-publisher_$(uname -s | tr '[:upper:]' '[:lower:]')_$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/').tar.gz" | tar xz mcp-publisher && \
sudo mv mcp-publisher /usr/local/bin/ && \
mcp-publisher --help
```

**2. Generar la clave y el registro DNS**

```bash
MY_DOMAIN="trazalog.com" && \
openssl genpkey -algorithm Ed25519 -out mcp-registry-key.pem && \
PUBLIC_KEY="$(openssl pkey -in mcp-registry-key.pem -pubout -outform DER | tail -c 32 | base64)" && \
echo "${MY_DOMAIN}. IN TXT \"v=MCPv1; k=ed25519; p=${PUBLIC_KEY}\""
```

Guardar `mcp-registry-key.pem` en un lugar seguro (**no en el repo**): es la clave privada con la
que se firma cada publicación futura.

**3. Cargar el registro TXT** — 🌐 en el **panel del proveedor DNS de `trazalog.com`**: agregar un
registro **TXT** en el dominio raíz con el valor que imprimió el paso anterior
(`v=MCPv1; k=ed25519; p=…`). Esperar la propagación (minutos a una hora).

**4. Crear `server.json`** — en una carpeta local, no hace falta que sea el repo:

```json
{
  "$schema": "https://static.modelcontextprotocol.io/schemas/2025-12-11/server.schema.json",
  "name": "com.trazalog/tools",
  "title": "Trazalog Tools",
  "description": "Mantenimiento y almacenes para proveedores de servicios mineros: equipos, órdenes de trabajo, preventivos, stock, pedidos y trazabilidad de movimientos.",
  "version": "2.5.0",
  "websiteUrl": "https://www.trazalog.com",
  "remotes": [
    {
      "type": "streamable-http",
      "url": "https://mcp.cloudtrazalog.com/trazalog/mcp/1.0/mcp"
    }
  ]
}
```

La `version` debe seguir a la de producción en cada republicación.

**5. Autenticar y publicar**

```bash
MY_DOMAIN="trazalog.com" && \
PRIVATE_KEY="$(openssl pkey -in mcp-registry-key.pem -noout -text | grep -A3 "priv:" | tail -n +2 | tr -d ' :\n')" && \
mcp-publisher login dns --domain "${MY_DOMAIN}" --private-key "${PRIVATE_KEY}" && \
mcp-publisher publish
```

**6. Verificar**

```bash
curl -s "https://registry.modelcontextprotocol.io/v0.1/servers?search=com.trazalog" | python3 -m json.tool | head -30
```

Tiene que aparecer `"name": "com.trazalog/tools"`.

---

### 4. Anthropic — Connectors Directory de Claude

#### 4.1 Cómo funciona la revisión

Al enviar, el servidor se escanea automáticamente y **queda listado como *community connector***.
Anthropic puede escalarlo a **revisión *verified*** (humana, más lenta) si lo considera útil para
muchos usuarios; eso no se pide, lo deciden ellos. La etiqueta es una señal de calidad para el
usuario, no cambia cómo funciona el conector. Los criterios son los mismos en ambos casos.

#### 4.2 Prerrequisitos administrativos

1. **Organización Claude Team o Enterprise.** El portal de envío vive en la configuración de la
   organización; los planes individuales no lo tienen. Si Trazalog no tiene una, hay que crearla.
2. **Rol con acceso al directorio.** Por defecto solo *Owner* y *Primary owner*. En Team no hay
   roles custom, así que lo envía un Owner.
3. Aceptar los [Anthropic Software Directory Terms](https://support.claude.com/en/articles/13145338-anthropic-software-directory-terms)
   y la [Directory Policy](https://support.claude.com/en/articles/13145358-anthropic-software-directory-policy).

#### 4.3 Antes de enviar — lo que el revisor prueba

Esto es lo que Anthropic publica como causas más comunes de rechazo, cruzado con Trazalog:

| Criterio | Trazalog |
|---|---|
| Tools de lectura y escritura **separadas** (nada de un `api_request` con parámetro `method`) | ✅ 18 de lectura, 2 de escritura, separadas |
| `title` + `readOnlyHint` / `destructiveHint` en todas | ✅ |
| Nombres ≤ 64 caracteres | ✅ |
| Descripciones que digan qué hace la tool y cuándo usarla, **sin decirle a Claude cómo comportarse** | 🟡 Ver nota abajo |
| Toda tool responde bien con parámetros válidos; errores con detalle, no "Internal Server Error" | ✅ suite de escenarios 14/14 |
| El servidor llama a **APIs propias** y el dominio del MCP coincide con el servicio | ✅ `mcp.cloudtrazalog.com` |
| No transfiere dinero ni genera imágenes/audio/video con IA | ✅ |
| Cuenta de prueba **completamente poblada** | ⏳ preparar (§2.2) |
| Documentación pública al momento de publicar | ⏳ preparar (§2.1) |
| Probado con MCP Inspector **y** como conector custom en Claude | ✅ ya funciona como conector custom |

**Nota sobre las descripciones.** El criterio dice: *"Describe what the tool does. Do not tell
Claude how to behave."* Varias descripciones de la OpenAPI de Trazalog incluyen instrucciones de
comportamiento —por ejemplo *"No preguntarle al usuario el ID del depósito: consultarlo acá"*. Son
útiles y no son inyección, pero un revisor estricto puede objetarlas. Antes de enviar, releer las
20 descripciones y reformular las órdenes directas como descripción de uso (*"Devuelve los
depósitos con su ID, que `alm_crear_pedido_materiales` necesita"*).

#### 4.4 Los pasos del portal

🌐 En **Claude.ai** → `https://claude.ai/admin-settings/directory/submissions/new` (logueado como
Owner de la organización). El progreso se guarda solo en el navegador.

| Paso | Qué se completa | Qué poner para Trazalog |
|---|---|---|
| **Introduction** | lectura | — |
| **Connection** | URL del servidor (`https://`), transporte, y si es URL única / varias / patrón | `https://mcp.cloudtrazalog.com/trazalog/mcp/1.0/mcp` · Streamable HTTP · **Universal URL** |
| **Tools** | se sincronizan solas desde el servidor, agrupadas por lectura/escritura | Verificar que aparezcan las 20 y que ninguna esté marcada por falta de `title` o anotación |
| **Listing** | nombre (≤100), tagline (≤55), descripción (≤2000), 1–5 categorías, URL de docs, URL de privacidad, contacto de soporte, ícono, **slug permanente** | Nombre: `Trazalog Tools` · slug: `trazalog` (no se puede cambiar después) |
| **Use cases** | casos de uso principales, qué necesita el usuario antes de conectar, si lee/escribe/ambos | Ambos. Necesita: cuenta en Trazalog con una empresa asignada |
| **Company** | nombre y sitio de la empresa, contacto para la revisión | — |
| **Authentication** | tipo de OAuth | **OAuth con Dynamic Client Registration** (es lo que ya funciona) |
| **Data handling** | si la API es propia, proxy autorizado o de terceros; datos de salud; contenido patrocinado | Propia · No · No |
| **Test & launch** | instrucciones y credenciales para que el revisor use el servidor de punta a punta; confirmar que probaste cada tool | Credenciales de §2.2 + pasos del manual |
| **Compliance** | **7 declaraciones** de política (directorio, API propia, transacciones financieras, generación de medios, inyección de prompts, datos de conversación, docs públicas) | Todas obligatorias |
| **Review** | lectura final; muestra avisos de calidad (ej. respuestas muy cortas) | Enviar |

Después: estado y comentarios del revisor en `https://claude.ai/admin-settings/directory/submissions`.
Escalaciones: `mcp-review@anthropic.com`.

#### 4.5 Una recomendación de Anthropic que afecta a Dnato

> *"For servers expecting high traffic from the directory, prefer CIMD or `oauth_anthropic_creds`
> over DCR. DCR causes Claude to register a new client on every fresh connection."*

Con DCR, **cada conexión nueva crea un registro de cliente en Dnato**. Con decenas de usuarios no
importa; con cientos, la tabla de clientes OAuth crece sin límite. No es bloqueante para publicar,
pero hay que tenerlo en el radar: la alternativa más simple para Trazalog es `oauth_anthropic_creds`
(crear un `client_id`/`client_secret` fijo en Dnato y mandárselo a `mcp-review@anthropic.com`).

---

### 5. OpenAI — Plugins Directory de ChatGPT

#### 5.1 Cómo funciona

Desde 2026 las apps de ChatGPT se envían como **plugins**. Un MCP remoto es un plugin "With MCP".
La revisión es **manual y sin plazos publicados**. Aprobado el plugin, **lo publicás vos** desde el
portal cuando quieras, y aparece en el directorio compartido por ChatGPT y Codex.

Después de publicado, OpenAI **relee las tools periódicamente**: las borradas desaparecen solas y
las nuevas o cambiadas entran después de un chequeo automático. Cambios en la ficha o los skills sí
requieren nueva versión y nueva revisión.

#### 5.2 Prerrequisitos administrativos

1. 🌐 **Verificar la identidad de negocio** en OpenAI Platform: `https://platform.openai.com` →
   organización → configuración → verificación individual o de empresa. *"Reviewers may reject
   submissions that use an unverified or mismatched publisher identity."* La empresa verificada
   tiene que coincidir con el sitio web y las URLs legales que se declaran.
2. 🌐 **Rol con Apps Management = Write**:
   `https://platform.openai.com/settings/organization/people/roles` → rol del que envía →
   **Apps Management** → **Write** → asignar. Recargar `https://platform.openai.com/plugins`.

#### 5.3 Prerrequisitos técnicos — lo que OpenAI exige de más

| Requisito | Estado | Qué hacer |
|---|---|---|
| **Las tres anotaciones explícitas** en cada tool: `readOnlyHint`, `openWorldHint`, `destructiveHint` | ❌ falta `openWorldHint` en las 20 y `readOnlyHint: false` en las 2 de escritura | Cambio en la OpenAPI, §7 |
| **Verificación de dominio**: un endpoint `https://mcp.cloudtrazalog.com/.well-known/openai-apps-challenge` que devuelva **solo el token** (texto plano, sin JSON) que OpenAI muestra durante el envío | ❌ no existe | El Caddy/APIM que sirve `mcp.cloudtrazalog.com` tiene que responder esa ruta con el token. Se hace en el momento del envío, cuando OpenAI revela el token |
| Redirect URI de ChatGPT aceptado | ✅ vía DCR | Ninguna. Si más adelante se pasa a cliente estático, registrar `https://chatgpt.com/connector_platform_oauth_redirect` (y el `https://chatgpt.com/connector/oauth/{callback_id}` que muestre el portal) |
| Respuestas de las tools **sin identificadores internos ni datos de más** | 🟡 | Ver nota abajo |
| Credenciales de prueba sin MFA, mail, SMS ni VPN | ⏳ §2.2 | — |
| Términos de servicio públicos | ❌ §2.1 | — |
| UserInfo endpoint con `email` + `email_verified: true`, scopes `openid` y `email` | ❌ | **Solo para restricción por dominio de workspace.** No bloquea. Deseable para clientes enterprise |

**Nota sobre identificadores internos.** OpenAI pide: *"Remove unnecessary personal data, auth
secrets, debug payloads, internal identifiers, and undisclosed user-related fields from tool
responses."* Las tools de Trazalog devuelven IDs como `pema_id`, `demi_id`, `empr_id_mysql`,
`case_id`. Son necesarios para encadenar tools (un ID que una tool devuelve y otra recibe), así que
**no son "innecesarios"** — pero conviene que las descripciones lo expliquen (ej. *"`pema_id`: se
usa para consultar el detalle con `alm_get_pedido_material`"*), para que el revisor vea que cada
campo tiene función.

#### 5.4 Políticas que hay que tener presentes

De las guidelines, las que tocan a Trazalog:

- **"Trial or demo plugins will not be accepted."** El plugin tiene que ser el producto real, no
  una demo. La cuenta de prueba es para el revisor; el plugin apunta a producción.
- **"Cannot display subscription plans or initiate new subscriptions."** Trazalog es freemium: el
  plugin **no puede** mostrar planes ni empujar el upgrade desde ChatGPT. Ninguna tool ni
  descripción debe mencionar tiers ni precios.
- Las descripciones no pueden favorecer al plugin sobre otros ni disparar en exceso
  (*"overly broad triggering beyond the explicit user intent"*).
- Apto para mayores de 13. Sin problema.
- Sin publicidad. Sin problema.

#### 5.5 Los pasos del portal

🌐 En **`https://platform.openai.com/plugins`** → **Create plugin** → **With MCP**.

| Pestaña | Qué se completa | Qué poner para Trazalog |
|---|---|---|
| **Info** | nombre, descripciones, identidad verificada, logo, categoría, URLs de sitio / soporte / privacidad / términos | Nombre: `Trazalog Tools`. Las 4 URLs públicas de §2.1 |
| **MCP** | tipo de URL, URL del servidor, autenticación y credenciales del revisor, **CSP** (solo si hay UI), **verificación de dominio**, **Scan Tools** | **Universal** · `https://mcp.cloudtrazalog.com/trazalog/mcp/1.0/mcp` · OAuth. Sin UI, así que sin CSP. Cargar el token en `/.well-known/openai-apps-challenge` y verificar. Después **Scan Tools**: tienen que salir las 20 sin errores de metadata |
| **Skills** | solo si el servidor exporta skills | No aplica |
| **Prompts** | prompts de inicio que muestren los flujos de más valor | Ver ejemplos abajo |
| **Testing** | **mínimo 5 casos positivos y 3 negativos** | Ver §5.6 |
| **Global** | países donde estará disponible | Argentina, y los de LatAm donde haya soporte. La selección tiene que reflejar dónde hay *"support process and legal terms"* |
| **Submit** | release notes + declaraciones de política | Notas: qué hace, envío inicial, cómo usar la cuenta de prueba |

**Prompts de inicio sugeridos** (específicos pero adaptables):

- "¿Qué equipos tengo en reparación y cuáles tienen la criticidad más alta?"
- "Mostrame los artículos que están por debajo del punto de pedido y armá un pedido de reposición"
- "¿Qué lotes se vencen en los próximos 30 días?"
- "¿Qué traslados entre depósitos están en tránsito y hace cuánto salieron?"
- "Resumime las órdenes de trabajo abiertas de esta semana"

#### 5.6 Los ocho casos de prueba

Cada positivo lleva: prompt, tool esperada, forma del resultado, datos que necesita. Cada negativo:
prompt, comportamiento esperado (rechazo / pregunta / fallback) y por qué.

| # | Tipo | Prompt | Esperado |
|---|---|---|---|
| P1 | positivo | "¿Cuánto stock hay de filtros de aceite?" | `alm_get_stock` con `buscar=filtro`; lista con `stock` y `punto_pedido` |
| P2 | positivo | "Listá los equipos en estado RE" | `man_get_equipos`, filtrado por el modelo; equipos con criticidad |
| P3 | positivo | "Abrí una OT para el generador GEN-001 por vibración" | `man_get_equipos` para resolver el ID → `man_create_ot`; devuelve `ot_id` y `case_id` |
| P4 | positivo | "¿Qué se vence en los próximos 10 días?" | `alm_get_vencimientos`; filas con `estado_vencimiento` = Crítico |
| P5 | positivo | "Necesito reponer el artículo X, armá el pedido" | `alm_get_depositos` → `alm_crear_pedido_materiales`; devuelve `pema_id` |
| N1 | negativo | "Mostrame el stock de la empresa Minera Andes" (otra empresa) | El modelo explica que solo ve la empresa conectada; no existe forma de consultar otra |
| N2 | negativo | "Borrá la orden de trabajo 293" | No hay tool de borrado; el modelo lo dice y no intenta otra cosa |
| N3 | negativo | "Transferime el saldo del depósito a…" | Fuera del alcance; rechazo sin llamar tools |

Todos tienen que pasar **en ChatGPT web y en la app móvil**.

---

### 6. Google — Gemini

#### 6.1 Lo que existe y lo que no

**No hay un directorio público de MCP para Gemini al que enviar.** Verificado contra la
documentación oficial y análisis independientes al 2026-09-22. Hay tres superficies distintas:

| Superficie | Qué es | ¿Sirve para Trazalog? |
|---|---|---|
| **Gemini app (consumidor)** — "Connected Apps" | Desde mediados de 2026 un usuario con **cuenta personal** puede pegar la URL de un MCP custom. Sin formulario, sin revisión, sin listado | Marginal: los usuarios de Trazalog son empresas |
| **Gemini app — partners nombrados** (Canva, OpenTable…) | Acuerdos comerciales negociados con Google. No hay formulario ni programa público de intake | Solo con un contacto de partnerships de Google |
| **Gemini Enterprise — Custom MCP Server** | **El administrador de cada empresa cliente** registra el servidor de Trazalog en su propio Google Cloud. Sin revisión de Google, sin directorio | **Sí. Es el camino para el segmento B2B** |
| Gemini CLI extensions gallery | Deprecado para usuarios free/Pro/Ultra desde el 18-jun-2026; reemplazado por Antigravity CLI | No |

Conclusión: **para Gemini, Trazalog no envía nada. Prepara una guía para que el cliente conecte
el MCP en su Gemini Enterprise**, y ajusta Dnato para que ese flujo funcione.

#### 6.2 Lo que Gemini Enterprise exige del lado de Trazalog

| Requisito | Estado | Qué hacer |
|---|---|---|
| Transporte **Streamable HTTP** (SSE no soportado) | ✅ | — |
| TLS de **CA pública** | ✅ (verificar que producción no use autofirmado) | — |
| OAuth 2.0 con **`client_id` y `client_secret` fijos** — Google no hace DCR | ❌ | Crear un cliente estático en `oauth_clients.php` de Dnato para Gemini |
| Redirect URI `https://vertexaisearch.cloud.google.com/oauth-redirect` en la lista blanca de ese cliente | ❌ | Mismo cambio |
| Authorization URL y Token URL públicas | ✅ | `…/oauth/authorize` y `…/oauth/token` |
| PKCE | opcional (checkbox del lado del cliente) | Dnato ya lo soporta |
| `readOnlyHint` / `destructiveHint` en las tools | ✅ | Con `readOnlyHint`, la tool corre sin confirmación; con `destructiveHint`, pide confirmación |
| Máximo **100 acciones** habilitadas por data store | ✅ (20) | — |

**El `client_secret`** es el punto delicado: cada cliente que configure Gemini Enterprise va a
necesitar el `client_id` y el `client_secret` de Trazalog. Dos opciones: (a) un único cliente
Gemini compartido por todos, o (b) un cliente por empresa cliente. La (a) es más simple; la (b)
permite revocar a uno sin afectar al resto. **Decisión pendiente del PM.**

#### 6.3 La guía para el administrador del cliente

Esto es lo que hay que entregarle a la empresa cliente. Lo ejecuta **su** administrador, en **su**
Google Cloud.

**Prerrequisitos del cliente:** proyecto de Google Cloud con Gemini Enterprise habilitado, y el rol
**Discovery Engine Editor** (`roles/discoveryengine.editor`) para quien configura.

🌐 En la **consola de Google Cloud** del cliente:

1. **Gemini Enterprise** → **Data Stores** → **Create data store**.
2. Buscar y elegir **Custom MCP Server** → **Add MCP server**.
3. Completar:
   - **MCP Server URL**: `https://mcp.cloudtrazalog.com/trazalog/mcp/1.0/mcp`
   - **Autenticación**: OAuth 2.0
   - **Authorization URL**: `https://<host-dnato>/traz-comp-dnato/oauth/authorize`
   - **Token URL**: `https://<host-dnato>/traz-comp-dnato/oauth/token`
   - **Client ID** y **Client Secret**: los que Trazalog le entregue
   - **PKCE**: marcar
   - **Scopes**: los que se definan (hoy Dnato no publica `scopes_supported`; ver §7)
4. **Verify Auth** — abre el login de Dnato; ingresar con un usuario de la empresa.
5. Elegir región **multi-region**, ponerle nombre al conector, **Create**.
6. **Actions → Reload custom actions** → habilitar las tools que la empresa quiera usar.

Conviene entregarla como documento con capturas, igual que el manual de Claude.

---

### 7. Cambios de código que salen de todo esto

Consolidado de lo que hay que tocar en los repos, ordenado por qué desbloquea. Ninguno es grande.

| # | Cambio | Repo / archivo | Desbloquea | Prioridad |
|---|---|---|---|---|
| 1 | `openWorldHint: false` en las 20 tools y `readOnlyHint: false` explícito en `man_create_ot` y `alm_crear_pedido_materiales` | `traz-tools` · `doc/api/trazalog-operaciones.yaml` (+ verificar que el MCP Server del APIM las emita) | OpenAI (obligatorio). Anthropic y Google, indiferente | 🔴 antes de OpenAI |
| 2 | Servir `/.well-known/openai-apps-challenge` con el token de verificación | Caddy o APIM de `mcp.cloudtrazalog.com` | OpenAI | 🔴 en el momento del envío |
| 3 | **Refresh token** en `/oauth/token` (grant `refresh_token`, rotación, `offline_access` en `scopes_supported`) | `traz-comp-dnato` · `Oauth.php`, `jwt.php` | Que el usuario no reconecte todos los días. Anthropic renueva solo si existe | 🟡 antes de publicar en cualquiera |
| 4 | Cliente OAuth estático para Gemini con redirect `https://vertexaisearch.cloud.google.com/oauth-redirect` | `traz-comp-dnato` · `oauth_clients.php` | Google Enterprise | 🟡 antes de entregar la guía al primer cliente |
| 5 | Releer las 20 descripciones y reformular órdenes directas como descripción de uso | `traz-tools` · `doc/api/trazalog-operaciones.yaml` | Reduce riesgo de rechazo en Anthropic | 🟡 antes de Anthropic |
| 6 | Explicar en las descripciones para qué sirve cada ID interno que se devuelve | mismo archivo | Reduce riesgo de rechazo en OpenAI | 🟢 |
| 7 | UserInfo endpoint (`email`, `email_verified`) + scopes `openid`/`email` | `traz-comp-dnato` · `Oauth.php` | Restricción por dominio de workspace en ChatGPT | 🟢 después |
| 8 | Cliente estático para Anthropic (`oauth_anthropic_creds`) para no acumular registros DCR | `traz-comp-dnato` · `oauth_clients.php` + mail a `mcp-review@anthropic.com` | Escala en Anthropic | 🟢 cuando haya volumen |

El #1 y el #5 son el mismo archivo y conviene hacerlos juntos. Como la versión de `develop` va a
producción antes que `develop-v3`, **estos cambios van a `develop`** y después se sincronizan.

---

### 8. Orden sugerido

```
AHORA (antes del cutover)
  ├─ Publicar política de privacidad y términos en www.trazalog.com        (§2.1)
  ├─ Publicar el manual del conector como página de ayuda                   (§2.1)
  ├─ Definir mail de soporte                                                (§2.1)
  ├─ Crear organización Claude Team/Enterprise si no existe                 (§4.2)
  ├─ Iniciar verificación de identidad de negocio en OpenAI Platform        (§5.2)  ← puede tardar
  ├─ Preparar la empresa de prueba con datos realistas                      (§2.2)
  └─ Cambios de código #1, #3, #4 y #5                                      (§7)

CUTOVER A PRODUCCIÓN
  └─ Verificar que mcp.cloudtrazalog.com y Dnato respondan en <10 s        (§2.6)

DÍA 1 después del cutover
  ├─ MCP Registry oficial                                                   (§3)   ~1 hora
  └─ Envío a Anthropic                                                      (§4)   ~2 horas

DÍA 2
  └─ Envío a OpenAI                                                         (§5)   ~medio día

CUANDO HAYA UN CLIENTE CON GEMINI ENTERPRISE
  └─ Entregarle la guía de §6.3 con su client_id/secret                     (§6)
```

La verificación de identidad de OpenAI es el paso con más incertidumbre de plazo: **arrancarla
primero**, aunque el envío sea después.

---

### 9. Fuentes

Documentación oficial consultada el 2026-09-22. Revalidar antes de cada envío.

**Anthropic**
- [Submitting to the Connectors Directory](https://claude.com/docs/connectors/building/submission)
- [Pre-submission checklist](https://claude.com/docs/connectors/building/review-criteria)
- [Authentication for connectors](https://claude.com/docs/connectors/building/authentication)
- [Software Directory Terms](https://support.claude.com/en/articles/13145338-anthropic-software-directory-terms) · [Directory Policy](https://support.claude.com/en/articles/13145358-anthropic-software-directory-policy)

**OpenAI**
- [Submit plugins](https://developers.openai.com/plugins/deploy/submission)
- [App submission guidelines](https://developers.openai.com/apps-sdk/app-submission-guidelines)
- [Authentication – Plugins](https://developers.openai.com/plugins/build/auth)

**Google**
- [Set up your custom MCP server data store — Gemini Enterprise](https://docs.cloud.google.com/gemini/enterprise/docs/connectors/custom-mcp-server/set-up-custom-mcp-server)
- [How to get your MCP server into Google Gemini — Tallyfy](https://tallyfy.com/how-to-list-mcp-server-google-gemini/) (análisis independiente de las superficies)

**MCP Registry**
- [Quickstart](https://modelcontextprotocol.io/registry/quickstart) · [Remote servers](https://modelcontextprotocol.io/registry/remote-servers) · [Authentication](https://modelcontextprotocol.io/registry/authentication)

## De dónde salió este documento

Fusionado el 2026-11-26 (unificación de documentación, `DOC-UNIF-3`) a partir de:

- `doc/mcp/publicar-y-operar.md`
- `doc/mcp/publicar-y-operar.md`
- `doc/mcp/publicar-y-operar.md`
- `doc/mcp/publicar-y-operar.md`
- `doc/mcp/publicar-y-operar.md`

El texto se juntó sin reescribirlo; solo se bajaron niveles de título y se ajustaron enlaces. La historia de cada parte está en `git log --follow` de los archivos originales.
