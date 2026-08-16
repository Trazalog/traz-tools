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

| Archivo (bajo `src/main/wso2mi/`) | Qué define |
|---|---|
| `artifacts/data-sources/ToolsDataSource.xml` | PostgreSQL de tools |
| `artifacts/data-sources/AssetPlannerDataSource.xml` | MySQL `assetv2` |
| `resources/registry/conf/apiconfig.xml` | `api_url` y `dataservices_url` internas |
| `resources/conf/tools/bpmconf.xml` | `bpm_url` de Bonita |

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

🌐 **Navegador.** Si el Publisher no está expuesto, abrir primero un túnel SSH desde tu máquina:

```bash
ssh -L 9443:localhost:9443 <usuario>@<vm>
# y después entrar a https://localhost:9443/publisher
```

1. **`APIs`** → abrir la API (ej. `Trazalog MCP`) → **`Edit`**
2. **`API Definition`** → **`Import`** → subir `doc/api/trazalog-operaciones.yaml` actualizado
3. **`Save`**
4. Confirmar que sigue **asociada al Key Manager Dnato** y que `Enable Subscription Validation`
   sigue como estaba — re-importar no debería tocarlo, pero conviene mirarlo
5. Si cambiaron paths o methods: **`Publish`** de nuevo

> Re-importar **reemplaza** la definición. Cualquier ajuste hecho a mano en el Publisher sobre
> operaciones (descripciones editadas ahí, no en el YAML) se pierde. La fuente de verdad es el YAML
> del repo.

---

## 4. Paso C — Agregar las tools nuevas al MCP Server

**Este es el paso que se olvida.** El MCP Server es un artefacto distinto y no hereda las
operaciones nuevas de la API.

🌐 **Navegador**, mismo Publisher:

1. **`MCP Servers`** → abrir el server (ej. `Trazalog MCP Server`)
2. **`Tools`** → agregar cada tool nueva, apuntándola a la operación correspondiente de la API
3. Verificar que el nombre de la tool coincida **exactamente** con el `operationId` del YAML — es
   el nombre con el que el agente la invoca

**Alternativa: regenerarlo desde la API.** Más rápido si hay varias tools nuevas, pero **borra la
configuración propia del server**. Si se regenera, hay que rehacer sí o sí:

- el **`endpointConfig`** (queda en `null` → todas las tools dan `404`)
- la **suscripción** de la aplicación en el DevPortal (→ todas dan `403` / `900908`)

Ambos valores y el detalle de cómo reponerlos están en `deployment-gcp.md` §6.3-bis.

---

## 5. Paso D — Desplegar una revisión de cada artefacto

**Guardar no publica.** El gateway sirve la última revisión desplegada.

🌐 **Navegador**, para **la API** y **el MCP Server** por separado:

1. **`Deployments`** → **`Deploy New Revision`**
2. Elegir el gateway environment (en la VM de GCP: `Default`, vhost `mcp.cloudtrazalog.com`)
3. Confirmar

> APIM guarda un número limitado de revisiones. Si el botón aparece deshabilitado, hay que borrar
> una revisión vieja primero.

Si el `endpointConfig` del MCP Server no se deja editar desde la UI —pasa en 4.6.0— hay que hacerlo
por el Publisher REST API: procedimiento completo y verificado en `deployment-gcp.md` §6.3-ter.

---

## 6. Paso E — Verificar

💻 **Terminal local.** Hace falta un JWT real emitido por el Dnato **de ese mismo ambiente**.

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
[ ] OpenAPI re-importada en la API + Save (+ Publish si cambiaron paths) (B)
[ ] Key Manager Dnato sigue asociado (B.4)
[ ] Tools nuevas agregadas al MCP Server (C)
[ ] Revisión nueva desplegada en la API (D)
[ ] Revisión nueva desplegada en el MCP Server (D)
[ ] tools/list muestra la tool nueva (E.1)
[ ] tools/call devuelve datos reales (E.2)
[ ] Aislamiento verificado con dos empresas (E.3)
[ ] Conector reconectado y la tool aparece en Claude (F)
```

---

## 9. Estado de verificación de este procedimiento

**Verificado en la práctica:** los pasos A (build, deploy, arranque, curl directo) y las tres
condiciones de error de E.2 — los tres se encontraron realmente durante el despliegue a GCP del
2026-08-11 y están documentados con su log en `deployment-gcp.md` §6.3-bis.

**No verificado end-to-end todavía:** la secuencia completa de republicación con tools nuevas
(pasos C, D y F) — este documento se escribió *antes* de la primera republicación, consolidando lo
que estaba disperso en `openapi-publish-procedure.md` §7 (cinco líneas, sin el paso de revisión),
`wso2-redeploy-artifacts.md` §2 y `deployment-gcp.md` §6.3. **Al ejecutarlo la primera vez conviene
corregir acá lo que no coincida con la UI real**, sobre todo el paso C (nombres exactos de las
pantallas de `Tools` en el MCP Server de APIM 4.6.0) y el F (si alcanza con conversación nueva o
hace falta reconectar).
