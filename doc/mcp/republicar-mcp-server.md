# Agregar tools al MCP Server — procedimiento y trampas conocidas

## Objetivo

Cómo llevar a un ambiente **tools MCP nuevas** cuando el MCP Server ya existe y está en uso. Está
escrito para ejecutarse de punta a punta sin depender de otro documento: cada paso dice **dónde** se
ejecuta (SSH a la VM, navegador, terminal local).

**Cuándo leerlo:** cada vez que se agreguen o cambien operaciones en `toolsMCPAPI.xml` y en
`doc/api/trazalog-operaciones.yaml` y haya que publicarlas.

**Qué NO cubre:** la publicación inicial (crear la API y el MCP Server por primera vez) —
[`../v3/deployment-gcp.md`](../v3/deployment-gcp.md) §6.3 — ni la configuración de identidad/OAuth,
que es §6.0 y §7 del mismo documento.

| | |
|---|---|
| **Ambientes** | DEV y la VM de GCP (`mcp.cloudtrazalog.com`) — cambian los hosts, no los pasos |
| **Verificado** | 2026-08-20, agregando 8 tools a un MCP Server de 9 → **17/17 operativas** |
| **Duración** | ~40 min, la mayor parte esperando arranques y despliegues |

---

## 0. Lo único que hay que entender antes de empezar

**Agregarle recursos a una API que ya tiene un MCP Server generado NO funciona.** Ni re-importando la
OpenAPI, ni desplegando revisiones, ni recreando el MCP Server.

Las operaciones nuevas quedan en el MCP Server **sin `apiOperationMapping`**: visibles en
`tools/list`, pero fallando con `500` al invocarlas y rompiendo la pantalla `Tools` del Publisher.

**Hay que recrear la API.** Es el paso que parece desproporcionado y es el que resuelve.

```
   toolsMCPAPI.xml  ──►  .car  ──►  MI                     (paso A)

   trazalog-operaciones.yaml  ──►  RECREAR la API          (paso B)  ← el que importa
                                        │
                                        └──►  CREAR el MCP Server desde ella  (paso C)
```

Tres reglas que se derivan de esto:

| | |
|---|---|
| **`Publish` no es `Deploy`** | `Publish` la hace visible en el DevPortal; **`Deploy New Revision` es lo que la pone en el gateway**. Hacen falta las dos |
| **El MCP Server no hereda de la API** | el vínculo se arma **sólo al crearlo**, eligiendo operaciones. Después son artefactos independientes |
| **El Publisher muestra la working copy** | el gateway sirve la **revisión desplegada**. Pueden diferir, y ahí empieza el problema |

---

## 1. Antes de empezar

En tu máquina, en el repo:

```bash
# tools implementadas en el MI
grep -o 'uri-template="/mcp/[^"]*"' \
  _backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/apis/toolsMCPAPI.xml \
  | sed 's/uri-template="//;s/"//' | sort -u

# tools declaradas en la OpenAPI
grep -E '^\s+operationId:' doc/api/trazalog-operaciones.yaml | awk '{print $2}' | sort
```

Las dos listas tienen que tener la misma cantidad. **Si no coinciden, parar acá.**

| Qué cambió | Pasos |
|---|---|
| Sólo `toolsMCPAPI.xml` (mismo contrato) | A, D |
| Tools nuevas, o cambios de parámetros/descripciones | A, B, C, D |

---

## 2. Paso A — Actualizar el MI (el `.car`)

> **Primero el MI, siempre.** Si la tool se publica antes de que el MI tenga la ruta, falla aunque el
> Publisher esté perfecto.

### A.1 Revisar las IPs antes de buildear

SSH a la VM. El `.car` empaqueta la IP del ambiente, y buildear desde un checkout limpio deja el MI
apuntando a la base equivocada **sin fallar de forma visible** (responde `200` con datos de otro
ambiente). Detalle en `deployment-gcp.md` §6.1-bis:

| Archivo (bajo `src/main/wso2mi/`) | ¿Tocarlo? |
|---|---|
| `artifacts/data-sources/ToolsDataSource.xml` | **sí** — IP del ambiente |
| `artifacts/data-sources/AssetPlannerDataSource.xml` | **sí** — IP del ambiente |
| `resources/conf/tools/bpmconf.xml` → `bpm_url` | **sí** — IP de Bonita |
| `resources/conf/tools/apiconfig.xml` | **no** — es el MI llamándose a sí mismo, `localhost` es correcto |

> Editar siempre `resources/conf/tools/`. Existe una copia huérfana en `resources/registry/conf/` que
> **no se empaqueta** y tiene valores distintos.

### A.2 Buildear y desplegar

```bash
cd ~/traz-tools && git checkout develop-v3 && git pull origin develop-v3
cd _backend/api/ToolsAPIProject/ToolsAPIProject
mvn clean install          # ./mvnw no viaja en el clone

# verificar el CAR ANTES de copiarlo
mkdir -p /tmp/car && unzip -qo target/ToolsAPIProject_1.0.0.car -d /tmp/car
grep -rho 'uri-template="/mcp/[^"]*"' /tmp/car | sed 's/uri-template="//;s/"//' | sort -u
grep -rh "jdbc:" /tmp/car | sed 's/^[[:space:]]*//'
rm -rf /tmp/car

sudo systemctl stop wso2mi
sudo cp target/ToolsAPIProject_1.0.0.car $MI_HOME/repository/deployment/server/carbonapps/
sudo systemctl start wso2mi
```

### A.3 Esperar el arranque

El MI tarda **~40 s**. Antes de eso todo devuelve `101503`, que parece un error de configuración y no
lo es.

```bash
sudo tail -f $MI_HOME/repository/logs/wso2carbon.log | grep -m1 "started in"
```

### A.4 Probar el MI directo, salteando el APIM

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8290/tools/mcp/mcp/man/kpi/mttr
# 503 (identity_missing) = CORRECTO: la ruta existe y el MI está sano
# 404 = la ruta no está en el CAR desplegado -> volver a A.2
```

Repetir con cada ruta nueva. **Si el MI no responde, no tiene sentido seguir.**

---

## 3. Paso B — Recrear la API

Requiere `apictl` ([descarga](https://github.com/wso2/product-apim-tooling/releases), la versión que
corresponda al APIM):

```bash
apictl add env prod --apim https://localhost:9443
apictl login prod -u admin
```

### B.1 Actualizar la definición

Publisher → `APIs` → la API → **`API definition`** → subir `doc/api/trazalog-operaciones.yaml` →
`Save`. *(No hay botón `Edit`: se entra directo y se navega por el menú izquierdo.)*

### B.2 Recrear la API

SSH a la VM:

```bash
bash scripts/dev/recrear-api-y-mcp.sh            # muestra el plan
bash scripts/dev/recrear-api-y-mcp.sh --apply
```

Hace: backups de la API y de **todos** los MCP Servers → los borra → borra la API → la reimporta de
cero → despliega su revisión → verifica el conteo de operaciones.

> **Se borran todos los MCP Servers, no sólo el principal.** Cualquiera que referencie la API la
> bloquea: `409 Cannot remove the API as it is used by MCP server(s)`.
>
> El script **aborta** si un paso falla, en vez de dejar el estado a medias. Backups en
> `/root/mcp-backup-<fecha>`; se vuelve atrás con `apictl import api -f <zip> -e prod`.

Al terminar tiene que decir **17 operaciones** (o las que correspondan) y **revisión desplegada con
17 recursos**.

### B.3 Qué confirmar

- **`Enable Subscription Validation` desactivado.** Sin `azp` en el JWT de Dnato, con la validación
  activa el gateway responde `403` aunque la firma sea válida.
- **El selector de Key Managers no se toca.** Dnato **no está registrado como Key Manager** — APIM
  4.6.0 no tiene conector genérico para IdPs custom; la validación la resuelve `[[apim.jwt.issuer]]`
  del `deployment.toml`.

---

## 4. Paso C — Crear el MCP Server desde la API

Este paso es **manual a propósito**: es el único camino que genera los mappings. Reimportar un
proyecto de `apictl` no sirve — el import **descarta las tools sin mapping**.

1. `MCP Servers` → **`Create MCP Server`** → **`Start from Existing API`**
2. Elegir la API → `Next`
3. **Seleccionar las operaciones** → `Next`
   > **Contá cuántas te ofrece.** Ese número es el diagnóstico: si son menos de las que tiene la API,
   > la recreación no salió bien y hay que volver al paso B antes de seguir.
4. Name / Context / Version → `Create`
   > Repetir los valores anteriores mantiene la URL y **el conector de Claude sigue funcionando**. Si
   > cambian, hay que reconfigurar el conector y la system property `trazalog.mcp.resource.url`
   > (§6.2-bis), porque el PRM anuncia el `resource` y Claude valida que coincida.
5. **`Deploy`** → **`Deployments`** → `Deploy`
6. **`Publish`** → **`Lifecycle`** → `Publish`

### C.2 Suscribir la aplicación

**DevPortal** (`:9443/devportal`) — **otro portal, no el Publisher**:

`SUBSCRIBE TO AN APPLICATION` → elegir la Application que usa el conector → policy `Unlimited` →
`Subscribe`.

**Suscribir el MCP Server, no la API.** Son productos distintos del catálogo; el conector consume el
MCP Server. Sin esto, todas las tools dan `403` / `900908`.

> El **endpoint no hace falta** en MCP Servers de subtipo `EXISTING_API`: el ruteo sale del mapping.
> Un `endpointConfig` en `null` es normal ahí.

---

## 5. Paso D — Verificar

Terminal local, sin token ni VPN:

```bash
python3 scripts/dev/mcp-smoke-tools.py
python3 scripts/dev/mcp-smoke-tools.py --jwt "$JWT"    # además valida datos reales
```

| Respuesta | Significa |
|---|---|
| **`401`** | la tool está **bien mapeada** — el gateway llegó a pedir autenticación |
| `500` con `existingAPIOperationMapping is null` | la tool no tiene operación asociada → paso B/C |
| `404` en todas | no hay revisión desplegada |
| `403` (sólo visible con token) | falta la suscripción → C.2 |

Estado correcto: **todas en `401`, 0 rotas.**

Diagnóstico más profundo, por si algo no cierra:

```bash
bash scripts/dev/diag-mcp-mapping.sh     # mapping tool por tool, en la base
bash scripts/dev/diag-api-revisiones.sh  # working copy vs revisión desplegada
bash scripts/dev/diag-kpi-mttr.sh        # las 3 capas: DataService, MI, gateway
```

### D.2 Refrescar el conector en Claude

El cliente cachea la lista de tools. Conversación nueva; si la tool sigue sin aparecer, desconectar y
reconectar el conector.

---

## 6. Checklist

```
[ ] OpenAPI e implementación con la misma cantidad de tools (paso 1)
[ ] IPs del .car revisadas para el ambiente (A.1)
[ ] mvn clean install en verde y .car verificado por dentro (A.2)
[ ] MI arrancado ("started in NN seconds") (A.3)
[ ] curl directo al MI: 503 identity_missing en cada ruta nueva (A.4)
[ ] OpenAPI actualizada en API definition + Save (B.1)
[ ] API recreada; revision desplegada con TODOS los recursos (B.2)
[ ] Enable Subscription Validation sigue desactivado (B.3)
[ ] MCP Server creado desde la API, ofreciendo TODAS las operaciones (C)
[ ] Deploy + Publish del MCP Server (C.5, C.6)
[ ] Aplicacion suscripta al MCP Server en el DevPortal (C.2)
[ ] mcp-smoke-tools.py: todas en 401, 0 rotas (D)
[ ] Conector reconectado y las tools nuevas aparecen en Claude (D.2)
```

---

## 7. Las trampas, y cómo se ven

Todo esto se descubrió agregando 8 tools a un MCP Server de 9, entre el 18 y el 20 de agosto de 2026.
Se documenta con el síntoma primero, que es como aparece en la vida real.

### «El conector dice que el servidor no responde»

El gateway devuelve `500` con:

```
Cannot invoke "APIOperationMapping.getBackendOperation()" because "existingAPIOperationMapping" is null
```

La tool existe en el MCP Server pero no tiene operación de backend asociada. La misma inconsistencia
**rompe la pantalla `Tools` del Publisher** (`TypeError: Cannot read properties of undefined (reading
'toLowerCase')` en `ToolDetails.jsx`), así que no se puede ni ver ni editar desde la UI.

Es [wso2/api-manager#5106](https://github.com/wso2/api-manager/issues/5106), con fix en
[carbon-apimgt#13889](https://github.com/wso2/carbon-apimgt/pull/13889) — el fix **valida y rechaza
antes de persistir**, pero **no repara** lo ya guardado.

### «La API muestra todas las operaciones y aun así no funcionan»

El Publisher muestra la **working copy**. El gateway sirve la **revisión desplegada**. Importar la
OpenAPI y hacer `Publish` **no lleva ningún recurso al gateway**: eso lo hace `Deploy New Revision`.

Caso real: 17 recursos en el Publisher, 9 en el gateway, y las 9 tools que funcionaban eran
exactamente esas.

> *"To invoke an API, it needs to be published on the Developer Portal **as well as deployed on a
> Gateway environment**."* — [Deploy an
> API](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/api-design-manage/deploy-and-publish/deploy-on-gateway/deploy-api/deploy-an-api.md)

### Lo que NO arregla el mapping — probado, no supuesto

| Intento | Resultado |
|---|---|
| Desplegar revisión nueva de la API | necesario, pero **no alcanza** |
| `PUT` del mapping por el Publisher REST API | acepta con `200` y **guarda `null` igual** (2 veces) |
| Recrear el MCP Server desde la UI | mismas tools rotas |
| Recrearlo con **nombre y contexto nuevos** | mismas tools rotas → descarta que sea el artefacto |
| `apictl import --update` | `500` — `No backends found to update for API` |
| `apictl import` como nuevo, con los mappings en el YAML | importa, pero **descarta el mapping** |
| **Recrear la API** | **17/17 operativas** |

El `--update` roto es [wso2/api-manager#4997](https://github.com/wso2/api-manager/issues/4997) / fix
[carbon-apimgt#13822](https://github.com/wso2/carbon-apimgt/pull/13822): los MCP Server de subtipo
`EXISTING_API` no tienen backends por diseño, y el path de update los exigía igual.

### Por qué recrear la API es lo que funciona

Todo lo consultable por REST —`operations`, definición OpenAPI, revisión desplegada— mostraba los 17
recursos. Pero `findMatchingTemplate()` lee `AM_API_URL_MAPPING`, y ahí las filas de las operaciones
agregadas después nunca se insertaron. Recrear la API las inserta todas juntas.

**Consecuencia práctica: agregar operaciones a una API que ya tiene un MCP Server generado exige
recrear la API.** No es un paso opcional ni una precaución.

---

## 8. Fuentes

| Paso | De dónde sale |
|---|---|
| `API definition`, sin botón `Edit` | [Edit an API by modifying the API Definition](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/tutorials/edit-an-api-by-modifyng-the-api-definition.md) |
| `Deploy` → `Deployments` → `Deploy New Revision` | [deploy-revision](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/includes/design/deploy-revision.md) |
| Crear el MCP Server desde una API | [Create a MCP Server Using an Existing API](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/ai-gateway/mcp-gateway/create-from-api.md) |
| `Tools`, `Deploy`, `Publish`, `MCP Playground` | [Updating Tools and Deploying the MCP Server](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/ai-gateway/mcp-gateway/update-and-deploy-mcp-server.md) |
| `SUBSCRIBE TO AN APPLICATION` | [Subscribe to a MCP Server](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/ai-gateway/mcp-gateway/subscribe-to-a-mcp-server.md) |
| Comandos de `apictl` | [Managing MCP Servers](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/apiops/cli/managing-mcp-servers/managing-mcp-servers.md), [Migrating MCP Servers](https://github.com/wso2/docs-apim/blob/4.6.0/en/docs/apiops/cli/managing-mcp-servers/migrating-mcp-servers-to-different-environments.md) |
| Todo lo de la sección 7 | verificado contra la VM de GCP, 2026-08-18/20 |

> `apim.docs.wso2.com` responde `403` a descargas automatizadas. Las fuentes apuntan al repositorio
> del que se genera esa documentación, [`wso2/docs-apim`](https://github.com/wso2/docs-apim), rama
> **`4.6.0`**, que es la versión instalada.

### Pendientes que dejó este trabajo

- **`apictl` no está integrado al flujo.** Con `import mcp-server` sobre un proyecto versionado, el
  MCP Server sería reproducible desde el repo igual que el `.car`, y esto dejaría de ser un
  procedimiento de consola.
- **Los tres bugs tienen fix mergeado río arriba y ninguno aplicado acá.** Aplicarlos requiere
  suscripción WSO2. Mientras tanto, este procedimiento los esquiva.
- **Las credenciales de Bonita están en texto plano** en los dos `bpmconf.xml`.
