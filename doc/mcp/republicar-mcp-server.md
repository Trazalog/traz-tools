# Publicar tools nuevas en el MCP Server

## Objetivo

Los 8 pasos para que una tool MCP nueva quede funcionando en un ambiente donde el MCP Server **ya
existe y está en uso**. Está escrito para ejecutarlo de corrido: cada paso dice dónde se corre, qué
comando o clic va, y qué tiene que dar para pasar al siguiente.

**Cuándo leerlo:** cada vez que cambien las operaciones de `toolsMCPAPI.xml` y de
`doc/api/trazalog-operaciones.yaml` y haya que publicarlas.

**Qué NO cubre:** el despliegue del MI en sí —[`../v3/desplegar-mcp.md`](../v3/desplegar-mcp.md)—, la
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

## Las tres reglas

Saltearse una deja la tool visible en `tools/list` y fallando al invocarla, **sin que nada dé un
error claro**. Son la razón de que el procedimiento sea tan largo para algo que parece un deploy.

1. **Hay que recrear la API** (paso 4). Agregarle operaciones a una API que ya tiene un MCP Server
   generado no funciona por ningún camino: quedan sin `apiOperationMapping`.
2. **El MCP Server no hereda de la API.** El vínculo se arma **sólo al crearlo**, eligiendo
   operaciones (paso 5). Después son dos artefactos independientes.
3. **`Publish` no es `Deploy`.** `Publish` lo muestra en el DevPortal, `Deploy` lo pone en el
   gateway. Hacen falta las dos, en la API y en el MCP Server.

---

## Paso 0 — Chequeo previo

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

## Paso 1 — Desplegar el MI

💻 **SSH a la VM del MCP.**

> **Primero el MI, siempre.** Si la tool se publica antes de que el MI tenga la ruta, falla aunque el
> Publisher esté impecable.

```bash
sh ~/git/traz-tools/scripts/deploy/deploymcp.sh <rama-o-tag>
```

Tiene que cerrar en **`DESPLIEGUE OK`**. El `.env`, el rollback y el detalle están en
[`../v3/desplegar-mcp.md`](../v3/desplegar-mcp.md) — no se edita ningún archivo del repo. Lo que el
script **no** hace es probar las rutas nuevas una por una: curlea una sola, para saber si el MI
levantó. Eso es el paso 2.

---

## Paso 2 — Probar cada ruta nueva contra el MI

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

## Paso 3 — Subir la OpenAPI

🌐 **Publisher** (`https://<host>:9443/publisher`).

`APIs` → la API → **`API definition`** → subir `doc/api/trazalog-operaciones.yaml` → **`Save`**.

*(No hay botón `Edit`: se entra directo y se navega por el menú izquierdo.)*

> **Va antes del paso 4, sin excepción.** El script del paso 4 reimporta la definición **tal como
> está en el APIM**: si no la actualizaste acá, recrea la API con las operaciones viejas.

---

## Paso 4 — Recrear la API

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

## Paso 5 — Crear el MCP Server desde la API

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

## Paso 6 — Suscribir la aplicación

🌐 **DevPortal** (`https://<host>:9443/devportal`) — **otro portal, no el Publisher.**

`SUBSCRIBE TO AN APPLICATION` → la Application que usa el conector → policy `Unlimited` →
`Subscribe`.

> **Suscribí el MCP Server, no la API.** Son productos distintos del catálogo y el conector consume
> el MCP Server. Sin esto, **todas** las tools dan `403` / `900908`.
>
> El endpoint no hace falta: en MCP Servers de subtipo `EXISTING_API` el ruteo sale del mapping, y un
> `endpointConfig` en `null` es normal ahí.

---

## Paso 7 — Verificar

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
[`../operaciones/herramientas-mcp.md`](../operaciones/herramientas-mcp.md).

---

## Paso 8 — Refrescar el conector

🌐 **En Claude.** El cliente cachea la lista de tools: abrir una **conversación nueva**. Si la tool
sigue sin aparecer, desconectar y reconectar el conector.

---

## Checklist

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

## Si algo falla

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

## Apéndice — por qué el procedimiento es así

No hace falta para ejecutarlo. Está acá para no volver a probar lo que ya se probó: todo esto sale de
llevar un MCP Server de 9 tools a 17, entre el 18 y el 20 de agosto de 2026, contra la VM de GCP.

### Recrear la API es lo único que inserta los mappings

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

### Los tres bugs de WSO2 que esto esquiva

| | |
|---|---|
| Mapping en `null` persistido | [api-manager#5106](https://github.com/wso2/api-manager/issues/5106), fix en [carbon-apimgt#13889](https://github.com/wso2/carbon-apimgt/pull/13889) — **valida y rechaza antes de persistir, pero no repara lo ya guardado** |
| `apictl import --update` | [api-manager#4997](https://github.com/wso2/api-manager/issues/4997), fix en [carbon-apimgt#13822](https://github.com/wso2/carbon-apimgt/pull/13822) — los MCP Server `EXISTING_API` no tienen backends por diseño y el path de update los exigía igual |
| El alta desde la UI | **no está reportado** |

Los tres tienen fix mergeado río arriba y ninguno aplicado acá: aplicarlos requiere suscripción WSO2.

### El `202` de las tools de escritura

El síntoma más caro de toda la etapa: el cliente mostraba `Error occurred during tool execution`, sin
código ni detalle, y el pedido estaba creado con su `case_id` de Bonita. Cada reintento creaba otro —
**14 pedidos y 13 casos por un pedido real**. Sólo pasa en las tools de escritura: son las únicas
donde el MI responde `202`.

Lo cubre `deploy/gcp/reverse-proxy/Caddyfile`, reescribiendo `202 → 200` sólo para `tools/call`, por
el header `Mcp-Method`. Es un parche de borde: el arreglo de fondo es que el MI devuelva `200` — la
mediación `HTTP_SC` ya está en `toolsMCPAPI.xml` pero **no toma efecto en runtime**.

### El `server/discover` del cliente

El cliente MCP (protocolo `2026-07-28`) abre sesión con `server/discover`, que no está en el
`ALLOWED_METHODS` de APIM 4.6.0 (`APIConstants.java`): responde `404` con un cuerpo de Synapse que no
es JSON-RPC, cuando correspondería `-32601`. El cliente hace fallback a `2025-06-18` y sigue, así que
es benigno, pero es un gap real de compatibilidad.

### Fuentes

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

### Pendientes

- **`apictl` no está integrado al flujo.** Con `import mcp-server` sobre un proyecto versionado, el
  MCP Server sería reproducible desde el repo igual que el `.car`, y los pasos 3 a 6 dejarían de ser
  un procedimiento de consola y navegador.
- **El `202` de fondo**, arriba: que el MI devuelva `200` y el `Caddyfile` deje de parchearlo.
- **Las credenciales de Bonita están en texto plano** en los dos `bpmconf.xml`.
