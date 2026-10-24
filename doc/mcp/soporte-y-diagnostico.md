# Soporte y diagnóstico del MCP

## Objetivo

Dónde mirar cuando el MCP no responde o una tool falla: qué log tiene cada tramo del camino, qué
script valida qué, y qué significa cada síntoma. Está escrito para consultarlo en caliente, por
síntoma, no para leerlo de corrido.

**Cuándo leerlo:** cuando algo falla, o cuando hay que verificar un despliegue más allá del
"terminó OK".

**Qué NO cubre:** instalar un ambiente ([`instalar-ambiente-nuevo.md`](instalar-ambiente-nuevo.md)) ni
desplegar una versión ([`desplegar-version.md`](desplegar-version.md)).

---

## El camino de una llamada

Una tool atraviesa **cinco tramos en tres máquinas**. Saber en cuál murió es la mitad del
diagnóstico, y cada uno tiene su propio log.

```
  Claude ──► Caddy :443 ──► APIM :8243 ──► MI :8290 ──► base / Bonita
             (1)            (2)            (3)          (4)
                   ▲
                   └── el login va aparte, a Dnato  (5)
```

| | Tramo | Log | Máquina |
|---|---|---|---|
| **1** | Caddy | `/var/log/caddy/mcp-access.log` | VM del MCP |
| **2** | APIM (gateway) | `journalctl -u wso2am` + `api.log` | VM del MCP |
| **3** | MI | `journalctl -u wso2mi` + `wso2carbon.log` | VM del MCP |
| **4** | bases / Bonita | errores de datasource en el log del MI | VM del MCP |
| **5** | Dnato (login) | `application/logs/log-<fecha>.php` + `ssl_access_log` | servidor de Dnato |

> 🔴 **El `api.log` del APIM miente sobre el status.** Informa `RESPONSE_OUT statusCode:200` mientras
> el cliente recibe `202`. **La única fuente confiable de lo que recibe el cliente es el log de
> Caddy.** Eso costó días de diagnóstico una vez; no vuelvas a confiar en el `api.log` para eso.

---

## Los logs, uno por uno

### 1. Caddy — lo que realmente recibió el cliente

💻 En la VM del MCP. Es **JSON por línea**, así que `python3 -m json.tool` no sirve:

```bash
sudo tail -20 /var/log/caddy/mcp-access.log | python3 -c "
import sys, json
for l in sys.stdin:
    try: d = json.loads(l)
    except: continue
    print(d.get('status'), d.get('request', {}).get('uri'))
"
```

Hay un atajo: `bash scripts/dev/ver-access-log.sh`.

### 2. APIM

```bash
sudo journalctl -u wso2am --since "-20 min" | grep -iE "ERROR|Exception" | tail -40
```

```bash
sudo tail -200 /opt/wso2/wso2am-4.6.0/repository/logs/wso2carbon.log | grep -iE "error|exception"
```

Los fallos de autorización no siempre son `ERROR`. Si buscás uno puntual:

```bash
sudo journalctl -u wso2am --since "-30 min" | grep -iE "900901|900906|900908|subscription|azp|issuer" | tail -30
```

### 3. MI

```bash
sudo journalctl -u wso2mi --since "-20 min" | grep -iE "ERROR|Exception" | tail -40
```

> Los `WARN ... Unable to determine batch query support for query '...'` del arranque son
> **inofensivos**: el MI no puede preguntarle al driver si soporta batch y avisa. Aparecen decenas
> cada vez que arranca. Mirá la fecha antes de perseguirlos.

### 4. Dnato — todo lo del login

💻 En el servidor de **Dnato**, no en el del MCP. Es el log más útil y el peor de leer: con
`log_threshold = 4` guarda el body completo de cada llamada REST, así que `tail` te trae medio
megabyte de JSON. **Siempre con `grep`:**

```bash
grep -a "ERROR" /var/www/html/traz-comp-dnato/application/logs/log-$(date +%Y-%m-%d).php | tail -10
```

Y el acceso — en CentOS con `mod_ssl` el tráfico **HTTPS va a `ssl_access_log`**, no a `access_log`,
que es un error fácil de cometer y hace parecer que Claude nunca llegó:

```bash
sudo tail -f /var/log/httpd/ssl_access_log | grep -E "oauth/(authorize|login|token|register)"
```

### 5. API Logs del APIM — el más potente y el más sensible

Logging por API, en caliente, con headers y payload de los cuatro flujos:

```bash
curl -k -u admin:admin -X PUT \
  "https://localhost:9443/api/am/devops/v0/tenant-logs/carbon.super/apis/<ID>" \
  -H "Content-Type: application/json" -d '{"logLevel":"FULL"}'
```

> ⚠️ **En `FULL` escribe los `Authorization` y los `Internal-Key` completos en texto plano.**
> Apagalo (`{"logLevel":"OFF"}`) apenas termines. El `<ID>` sale de `diag-mcp-mapping.sh`, y conviene
> habilitarlo en el MCP Server **y** en la API fuente, para ver los dos saltos.

---

## Qué mirar primero, según el síntoma

### El conector no conecta

| Síntoma | Causa | Dónde se arregla |
|---|---|---|
| "No se pudo conectar" después del callback | el conector tiene cacheado un registro viejo | **borrar y recrear** el conector, no reconectarlo |
| Claude marca `Detectado: Sin inicio de sesión` | `initialize` y `tools/list` pasan sin token y Claude sondea con esos | ignorarlo, elegir `Iniciar sesión ahora` a mano |
| Se abre `https://mcp.<dominio>/authorize` y da `404` | Claude no encontró el PRM y cayó al fallback host-based | el CAR de discovery y las system properties |
| «No se pudo registrar con el servicio de inicio de sesión» | el DCR apuntó a algo que no es Dnato | ídem, y que la AS metadata traiga `registration_endpoint` |
| Nunca aparece el login de Dnato | puede ser normal: si ya hay sesión en ese navegador, `authorize` no vuelve a pedir credenciales | **no es evidencia de nada** — verificar en `ssl_access_log` |

**El chequeo que parte el problema en dos**, ⌨️ desde cualquier lado:

```bash
curl -s https://mcp.<dominio>/.well-known/oauth-protected-resource | python3 -m json.tool
```

`authorization_servers` es, literalmente, a dónde manda Claude a loguearse. Si apunta al Dnato de
otro ambiente, ahí está el problema entero. Y con el `ssl_access_log` de Dnato corriendo: si no
aparece ninguna línea, Claude ni llega; si aparecen, el discovery anda y el problema es de identidad.

### El login falla

| Síntoma | Causa |
|---|---|
| `500` en `/oauth/.well-known/oauth-authorization-server` | falta `vendor/`, o `composer_autoload` sin setear, o las claves RS256 |
| "Error interno al generar el código de autorización" | la tabla `seg.oauth_codes` no existe o le falta una columna |
| Al superusuario le aparecen menos empresas de las que tiene | **no es un bug**: la lista es la intersección con las membresías de **Bonita**, que es quien autoriza. Si las dos fuentes discrepan, manda Bonita |

El log de Dnato (§4) te da el error exacto en una línea.

### Las tools fallan

| Síntoma | Causa | Qué hacer |
|---|---|---|
| `500` `existingAPIOperationMapping is null`, y la pantalla `Tools` del Publisher no abre | la tool no tiene operación de backend asociada | recrear la API y el MCP Server |
| La API muestra todas las operaciones y aun así no funcionan | el Publisher muestra la **working copy**; el gateway sirve la **revisión desplegada** | `Deploy New Revision` |
| **Todas** dan `403` / `900908` | falta la suscripción | DevPortal → suscribir **el MCP Server** |
| `403` con la firma del JWT válida | `Enable Subscription Validation` activo, o el `azp` del token no corresponde a ninguna Application | desactivar la validación, o corregir `JWT_AZP` en el `.htaccess` de Dnato |
| `404` en `tools/call` con el conector ya autenticado | el `endpointConfig` del MCP Server quedó en `null` | configurar el endpoint en **los dos** artefactos y desplegar revisión |
| `101503 Error connecting to the back end` | **casi siempre el MI reiniciando** (tarda ~40 s) | esperar el arranque; si persiste, es el endpoint |
| La tool falla en el cliente pero **el dato se creó igual** | el MI responde `202` y en MCP eso significa "sin cuerpo" | el `Caddyfile` lo cubre; ver el apéndice |
| Una tool devuelve datos y otra viene vacía | los dos ids de empresa no son intercambiables | ver abajo |
| `404` sueltos que no son de ninguna tool | el cliente abre sesión con `server/discover` | benigno, el `Caddyfile` contesta el `-32601` |

> **Los dos identificadores de empresa.** Las tools `man_*` filtran por `empr_id_mysql` (assetv2) y
> las `alm_*` por `empr_id` (PostgreSQL). Los dos viajan en el mismo JWT. Si un grupo devuelve datos
> y el otro viene vacío, es el id — o el datasource del `.car` apuntando a otro ambiente.

### Todo responde, pero con datos raros

🔴 **El peor de todos, porque no falla.** El MCP apuntando a las bases de un ambiente y al Dnato de
otro responde `200`, con estructura correcta, y datos de la empresa equivocada.

```bash
curl -s https://mcp.<dominio>/.well-known/oauth-protected-resource | python3 -m json.tool
```

El `authorization_servers` de ahí y las tres líneas que imprime `deploymcp.sh` antes de desplegar
tienen que ser **del mismo ambiente**. Siempre.

---

## Los scripts

Todos en `scripts/dev/`. De más a menos usado:

| Script | Qué valida | Necesita token |
|---|---|---|
| **`mcp-smoke-tools.py`** | el mapeo de cada tool: distingue `401` (bien mapeada) de `500` (mapping roto) | no |
| **`validar-tools-e2e.py`** | **el camino real y completo**, con los headers `Mcp-*` del cliente | sí (`--jwt` o `--desde-log`) |
| `smoke-tools-mi.py` | los datos contra el MI, salteando gateway y Caddy | no |
| `capturar-fallo-tool.sh` | el error real de una tool puntual | sí |
| `ver-access-log.sh` | URL y status reales, del log de Caddy | no |
| `diag-mcp-mapping.sh` | el estado de las tools en la base del APIM, tool por tool | no |
| `diag-api-revisiones.sh` | working copy vs revisión desplegada | no |
| `recrear-api-y-mcp.sh` | **modifica**: recrea la API | no |

**`validar-tools-e2e.py` es el único que recorre el camino completo** y el único que mira el status
en el cable. Cualquier script que valide tools tiene que mandar los headers `Mcp-*` como el cliente
real, o el rewrite de Caddy no matchea y el test da un falso negativo.

> 🔴 **Nunca `--escrituras` contra producción.** `alm_crear_pedido_materiales` y `man_create_ot` crean
> registros reales e instancian procesos en Bonita.

---

## Apéndice — lo que ya se probó

No hace falta para operar. Está acá para no volver a probar lo que ya se probó.

### Recrear la API es lo único que inserta los mappings

Todo lo consultable por REST —`operations`, la definición OpenAPI, la revisión desplegada— mostraba
los 17 recursos. Pero `findMatchingTemplate()` lee `AM_API_URL_MAPPING`, y ahí las filas de las
operaciones agregadas **después** de generar el MCP Server nunca se insertaron.

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

Los tres tienen fix mergeado río arriba y ninguno aplicado acá: requieren suscripción WSO2.

### El `202` de las tools de escritura

El síntoma más caro de diagnosticar: el cliente mostraba `Error occurred during tool execution`, sin
código ni detalle, y el pedido estaba creado con su `case_id` de Bonita. Cada reintento creaba otro —
**14 pedidos y 13 casos por un pedido real**. Sólo pasa en las tools de escritura: son las únicas
donde el MI responde `202`, y en MCP sobre HTTP el `202` significa "notificación aceptada, sin
cuerpo", así que el cliente descarta una respuesta que venía completa y con `isError: false`.

Lo cubre `deploy/gcp/reverse-proxy/Caddyfile`, reescribiendo `202 → 200` sólo para `tools/call`, por
el header `Mcp-Method`. Es un parche de borde: el arreglo de fondo es que el MI devuelva `200` — la
mediación `HTTP_SC` ya está en `toolsMCPAPI.xml` pero **no toma efecto en runtime**.

### El `server/discover`

El cliente MCP (protocolo `2026-07-28`) abre sesión con `server/discover`, que no está en el
`ALLOWED_METHODS` de APIM 4.6.0: responde `404` con un cuerpo de Synapse que no es JSON-RPC, cuando
correspondería `-32601`. El cliente hace fallback a `2025-06-18` y sigue, así que es benigno, pero es
un gap real de compatibilidad. El `Caddyfile` contesta el `-32601` correcto.

### El `Caddyfile` no es un passthrough

Esos dos parches viven ahí. Para validarlo hay que cargar el entorno primero, porque usa variables
que provee systemd — sin eso `caddy validate` falla en la línea del `email` con `wrong argument
count`, que despista:

```bash
sudo bash -c 'set -a; source /etc/caddy/gcp.env; caddy validate --config /etc/caddy/Caddyfile'
```

### Pendientes conocidos

- **`apictl` no está integrado al flujo.** Con `import mcp-server` sobre un proyecto versionado, el
  MCP Server sería reproducible desde el repo igual que el `.car`.
- **El `202` de fondo**: que el MI devuelva `200` y el `Caddyfile` deje de parchearlo.
- **Las credenciales de Bonita están en texto plano** en los dos `bpmconf.xml`, y
  `bpmAPICallTemplate.xml` **loguea la password** en un `<log level="custom">`.
- **El log de Dnato en `log_threshold = 4`** guarda nombres y emails de todos los usuarios de todas
  las empresas, en un archivo legible por cualquier usuario del server.
