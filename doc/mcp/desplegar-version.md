# Desplegar una versión del MCP

## Objetivo

Subir una versión nueva del MCP a un ambiente **que ya funciona**. Es el procedimiento de todos los
días, el mismo en demo y en producción. Está escrito para ejecutarlo de corrido; cada paso dice dónde
se corre y qué tiene que dar.

**Cuándo leerlo:** cada vez que haya que llevar cambios al MCP — tools nuevas, queries, dataservices o
sequences.

**Qué NO cubre:** poner en pie un ambiente desde cero ([`instalar-ambiente-nuevo.md`](instalar-ambiente-nuevo.md))
ni diagnosticar algo que dejó de andar ([`soporte-y-diagnostico.md`](soporte-y-diagnostico.md)).

---

## Las dos mitades

Un despliegue del MCP toca **dos productos distintos**, y casi siempre alcanza con el primero:

| | Qué | Cuándo |
|---|---|---|
| **1. El MI** | el `.car`: la lógica, las queries, los dataservices | **siempre** |
| **2. El APIM** | la OpenAPI, la API y el MCP Server | **sólo si cambió el número de operaciones** |

El script del paso 1 compara el `.car` viejo con el nuevo y **te avisa** cuándo hace falta la segunda
mitad. Si no aparece ese aviso, terminaste en el paso 1.

> La parte 2 **deja el MCP caído un rato** y hay que rehacer la suscripción. No es un paso que
> convenga hacer de más.

---

# Parte 1 — El MI

## El comando

💻 **SSH a la VM del MCP**, desde cualquier directorio:

```bash
sh ~/git/traz-tools/scripts/deploy/deploymcp.sh origin/master
```

El único argumento es la **rama o el tag**: `origin/master`, `v2.5.1.17`, `origin/develop`… Sin
argumento usa `origin/master`.

**Es el mismo comando en todos los ambientes, sin variantes.** No hay parámetro de ambiente porque no
hace falta: lo que diferencia un ambiente de otro —las bases, el Bonita— ya está en
`deploy/gcp/.env.car` de **ese** servidor. El servidor es el ambiente.

**No hay que editar ningún archivo del repo.** Las IPs y las credenciales salen del `.env` y el script
las aplica sobre una **copia**: el checkout queda limpio y las credenciales nunca entran a git.

Antes de hacer nada te muestra a dónde va a quedar apuntando el MCP y pide confirmación:

```
  Este despliegue va a dejar el MCP leyendo:
    PostgreSQL  10.142.0.2:5434/trazalog_tools  (usuario postgres)
    MariaDB     10.142.0.2:3306/asp2tecn  (usuario root)
    Bonita      http://10.142.0.2:8080/bonita  (usuario admin)

  ¿Es correcto? [s/N]
```

🔴 **Leé esas tres líneas.** Es el único dato que, equivocado, **no falla**: las tools responden `200`,
con estructura correcta, y datos del ambiente de al lado.

## Qué hace

Siete pasos; en pantalla sólo el avance, el detalle va al log.

| | |
|---|---|
| 1 | Verifica el entorno: el repo, el `.env` (permisos `600` y sus variables completas), el MI y las herramientas |
| 2 | `git fetch` + `git reset --hard` a la rama o tag |
| 3 | **Respalda el `.car` que está andando** en `~/ToolsAPIProject_1.0.0.car.antes-de-<fecha>` |
| 4 | Copia el proyecto a `~/.cache/traz-mcp-build/<fecha>`, le aplica el `.env` y buildea |
| 5 | **Verifica el `.car` antes de desplegarlo**: las URLs del `.env`, que el MI siga apuntándose a sí mismo en `localhost:8290`, y que no haya quedado ninguna IP de otro ambiente |
| 6 | Copia el `.car` a `carbonapps/`, reinicia el MI y espera a que responda |
| 7 | Verifica el `.car` ya instalado y que no haya errores de datasource en el log |

Si algo falla antes del paso 6, **no se desplegó nada**. Cierra así:

```
----------------------------------------------------
  DESPLIEGUE OK
  revision               : a1b2c3d (origin/master)
  .env                   : /home/<user>/git/traz-tools/deploy/gcp/.env.car
  operaciones MCP        : 25
  respaldo del anterior  : /home/<user>/ToolsAPIProject_1.0.0.car.antes-de-20261020-143000
  log completo           : /home/<user>/deploymcp-20261020-143000.log
----------------------------------------------------
```

Para armar el `.car` y verificarlo **sin** tocar el MI:

```bash
SOLO_BUILD=1 sh ~/git/traz-tools/scripts/deploy/deploymcp.sh origin/master
```

## Probar cada ruta nueva

💻 En la VM, una vez por ruta nueva, salteando el APIM. El `context` de la API repite el `/mcp`:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8290/tools/mcp/mcp/core/empresa
```

### ✅ Tiene que dar `503`

**No es un error.** Le estás pegando al MI sin token, y el `503` lo escribe el propio MI:
`sequences/EmprIdFromHeader.xml` no resuelve el `empr_id` del header `X-JWT-Assertion` y contesta
`{"error":"identity_missing"}`. Que llegue esa respuesta prueba las dos cosas que este paso quiere
probar: **la ruta existe en el `.car` desplegado y la sequence de identidad está enganchada.**

| Cualquier otra respuesta | Significa |
|---|---|
| `404` | la ruta no está en el `.car` → revisar el log del despliegue |
| `200` con datos | no está pasando por `EmprIdFromHeader` → **parar**, está sirviendo sin autenticar |
| nada / timeout | el MI no levantó → `sudo journalctl -u wso2mi -n 80` |

## Si hay que volver atrás

El `.car` es el único artefacto que cambia, así que el rollback no toca el APIM ni el DNS. Si hubo
errores, el script te imprime el comando exacto. Si no:

```bash
sudo cp ~/ToolsAPIProject_1.0.0.car.antes-de-<fecha> \
  /opt/wso2/wso2mi-4.5.0/repository/deployment/server/carbonapps/ToolsAPIProject_1.0.0.car && \
sudo systemctl restart wso2mi
```

## La primera vez en una VM

El script **vive en el repo**, en el checkout de la propia VM: no se descarga ni se instala. 💻 Confirmá
dónde está el clone — no es la misma ruta en todos los servidores:

```bash
ls -d /trazasystems/traz-tools ~/git/traz-tools ~/traz-tools 2>/dev/null
```

Si no aparece ninguna, la VM no tiene checkout (el repo es privado, el clone pide credenciales):

```bash
mkdir -p ~/git && cd ~/git && \
git clone --recurse-submodules https://github.com/Trazalog/traz-tools.git
```

Y una sola vez a mano, para que el archivo exista:

```bash
cd <ruta-del-clone> && git fetch --all --prune && git reset --hard <el-tag-a-desplegar>
```

Eso no se repite: el paso 2 de cada despliegue es exactamente ese `reset`. `mvn` tiene que estar
instalado en la VM — el wrapper `./mvnw` está gitignoreado y no viaja con el clone.

El `.env` también es de una sola vez por servidor:

```bash
cd <ruta-del-clone> && \
cp deploy/gcp/.env.car.example deploy/gcp/.env.car && \
chmod 600 deploy/gcp/.env.car
```

---

# Parte 2 — El APIM

**Sólo si el script avisó que cambió el número de operaciones:**

```
  !! CAMBIO EL NUMERO DE OPERACIONES MCP: 24 -> 25
     Falta el paso del APIM, que no se puede automatizar.
```

## Las tres reglas

Saltearse una deja la tool visible en `tools/list` y fallando al invocarla, **sin que nada dé un error
claro**. Son la razón de que esta parte sea tan larga para algo que parece un deploy.

1. **Hay que recrear la API** (paso 5). Agregarle operaciones a una API que ya tiene un MCP Server
   generado no funciona por ningún camino: quedan sin `apiOperationMapping`.
2. **El MCP Server no hereda de la API.** El vínculo se arma **sólo al crearlo**, eligiendo
   operaciones (paso 6). Después son dos artefactos independientes.
3. **`Publish` no es `Deploy`.** `Publish` lo muestra en el DevPortal, `Deploy` lo pone en el gateway.
   Hacen falta las dos, en la API y en el MCP Server.

El porqué, con la evidencia de las seis alternativas que se probaron y fallaron, está en
[`soporte-y-diagnostico.md`](soporte-y-diagnostico.md).

## Paso 3 — Chequeo previo

⌨️ **En tu máquina**, en el repo. Los dos números tienen que ser **iguales**:

```bash
echo "MI:      $(grep -oE '<resource methods="[^"]*" uri-template="/mcp/' \
  _backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/apis/toolsMCPAPI.xml | wc -l)" && \
echo "OpenAPI: $(grep -cE '^[[:space:]]+operationId:' doc/api/trazalog-operaciones.yaml)"
```

**Si no coinciden, parar acá.**

> Se cuentan **operaciones**, no rutas: `/mcp/man/ot` tiene `GET` (`man_get_ots`) y `POST`
> (`man_create_ot`), así que hoy son 24 rutas y **25 operaciones**.

## Paso 4 — Subir la OpenAPI

🌐 **Publisher** (`https://<host>:9443/publisher`, por túnel SSH).

`APIs` → la API → **`API definition`** → subir `doc/api/trazalog-operaciones.yaml` → **`Save`**.

*(No hay botón `Edit`: se entra directo y se navega por el menú izquierdo.)*

> **Va antes del paso 5, sin excepción.** El script del paso 5 reimporta la definición **tal como está
> en el APIM**: sin esto, recrea la API con las operaciones viejas.

## Paso 5 — Desuscribir la aplicación

🌐 **DevPortal** → `Applications` → la app del conector → **`Subscriptions`** → **`Unsubscribe`** la
del MCP Server.

> Sin esto el paso siguiente no puede empezar: el MCP Server no se borra mientras tenga suscripciones
> activas, y la API no se borra mientras un MCP Server la referencie.
>
> ```
> 409 Cannot remove the MCP server: <id> as active subscriptions exist
> ```

🔴 **Acá arranca la ventana de indisponibilidad.** Hasta el paso 8, **las tools no responden para
ningún cliente**. Elegí el momento.

Si el borrado igual falla con `409`, lo otro que lo bloquea es el estado: 🌐 Publisher → el MCP Server
→ `Lifecycle` → **`Demote to Created`**.

## Paso 6 — Recrear la API

💻 **En la VM.** La primera vez en ese servidor, registrar el ambiente en `apictl`:

```bash
apictl add env prod --apim https://localhost:9443 && apictl login prod -u admin
```

```bash
apictl get apis -e prod --limit 1
```

Tiene que listar. `apictl` tiene **su propio login**, independiente del que usa el script por REST.

Después, siempre dos corridas — la primera sólo muestra el plan:

```bash
bash scripts/dev/recrear-api-y-mcp.sh
```

```bash
bash scripts/dev/recrear-api-y-mcp.sh --apply
```

Hace: backup de la API y de **todos** los MCP Servers → los borra → borra la API → la reimporta de
cero → despliega la revisión → verifica el conteo.

> ⚠️ Se borran **todos** los MCP Servers que referencien la API, no sólo el principal: cualquiera la
> bloquea. Si hay más de uno, el paso 5 hay que hacerlo para todos.
>
> El script aborta en cuanto un paso falla, en vez de dejar el estado a medias. Los backups quedan en
> `~/mcp-backup-<fecha>` y se vuelve atrás con `apictl import api -f <zip> -e prod`.

Al terminar, **los dos conteos tienen que coincidir** con el número que el script imprime al arrancar:

```
  operaciones: 25  (deberian ser 25)
  revision desplegada con 25 recursos
```

Si la revisión quedó con menos, **no sigas**: es mapping incompleto y crear el MCP Server encima sólo
lo esconde.

## Paso 7 — Crear el MCP Server

🌐 **Publisher.** Es manual a propósito: es el único camino que genera los mappings. Reimportar un
proyecto de `apictl` **descarta las tools sin mapping**.

1. `MCP Servers` → **`Create MCP Server`** → **`Start from Existing API`**
2. Elegir la API → `Next`
3. **Seleccionar las operaciones** → `Next`
4. Name / Context / Version → `Create`
5. **`Deploy`** → `Deployments` → `Deploy`
6. **`Publish`** → `Lifecycle` → `Publish`

> **En el punto 3, contá cuántas operaciones te ofrece.** Si son menos que las de la API, la
> recreación no salió bien → volver al paso 6.
>
> **En el punto 4, repetí el mismo Name / Context / Version que tenía** — el script te los lista al
> arrancar, en "estado actual". Si cambian, cambia la URL y hay que reconfigurar el conector de
> **todos** los clientes, más la system property `trazalog.mcp.resource.url`.

Y dos cosas que **no** se tocan: `Enable Subscription Validation` queda **desactivado**, y el selector
de **Key Managers** no se toca.

## Paso 8 — Volver a suscribir

🌐 **DevPortal** — otro portal, no el Publisher.

`SUBSCRIBE TO AN APPLICATION` → la misma Application del paso 5 → policy `Unlimited` → `Subscribe`.

**Acá se cierra la ventana de indisponibilidad.**

> **Suscribí el MCP Server, no la API**: son productos distintos del catálogo y el conector consume el
> MCP Server. Sin esto, **todas** las tools dan `403` / `900908`.

## Paso 9 — Verificar

⌨️ **En tu máquina**, sin token ni VPN:

```bash
python3 scripts/dev/mcp-smoke-tools.py
```

**Estado correcto: todas en `401`, 0 rotas.**

| Respuesta | Significa |
|---|---|
| **`401`** | ✅ bien mapeada — el gateway llegó a pedir autenticación |
| `500` `existingAPIOperationMapping is null` | sin operación asociada → pasos 6 y 7 |
| `404` en todas | no hay revisión desplegada → el `Deploy` del paso 7 |
| `403` (sólo con token) | falta la suscripción → paso 8 |

Con un token real, además valida los datos:

```bash
python3 scripts/dev/validar-tools-e2e.py --desde-log
```

> 🔴 **Nunca `--escrituras` contra producción**: `alm_crear_pedido_materiales` y `man_create_ot` crean
> pedidos reales e instancian procesos en Bonita.

## Paso 10 — Refrescar el conector

🌐 **En Claude.** El cliente cachea la lista de tools: abrir una **conversación nueva**. Si la tool
sigue sin aparecer, **borrar y recrear** el conector — reconectarlo no alcanza cuando se recreó el MCP
Server.

---

## Checklist

```
    PARTE 1 — el MI (siempre)
[ ] 1  deploymcp.sh cerro en DESPLIEGUE OK
[ ] 2  Las tres lineas de bases confirmadas, del ambiente correcto
[ ] 3  curl directo al MI: 503 en cada ruta nueva

    PARTE 2 — el APIM (solo si cambio el numero de operaciones)
[ ] 4  MI y OpenAPI con la misma cantidad de operaciones
[ ] 5  OpenAPI subida en API definition + Save
--- de aca al 8 el MCP esta caido -------------------------------------------
[ ] 6  Application DESUSCRIPTA del MCP Server
[ ] 7  API recreada; conteo de la revision desplegada = conteo de la OpenAPI
[ ] 8  MCP Server creado desde la API, con TODAS las operaciones
[ ] 8  mismo Name / Context / Version que antes
[ ] 8  Deploy + Publish del MCP Server
[ ] 8  Enable Subscription Validation sigue desactivado
[ ] 9  Application suscripta de nuevo AL MCP SERVER
-----------------------------------------------------------------------------
[ ] 10 mcp-smoke-tools.py: todas en 401, 0 rotas
[ ] 10 validar-tools-e2e.py con token real: 0 FAIL, ninguna en 202
[ ] 11 Conector refrescado y las tools nuevas aparecen en Claude
```
