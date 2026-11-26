# Ambientes de Trazalog v3 — DEV / TEST / PROD

## Objetivo

Este documento explica los ambientes donde corre el stack WSO2 (APIM + MI) de Trazalog v3, cómo levantar DEV en una máquina local (Rodolfo u otro developer), y cómo se usa TEST hoy (futuro PROD), dónde corre el motor de los agentes de IA en cada uno y cómo es el servidor compartido de DEV. Está escrito para cualquier developer que necesite decidir "¿dónde pruebo esto?" o "¿necesito ngrok para esto?".

**Qué NO cubre:** la instalación paso a paso de WSO2 (eso está en [`wso2-install.md`](wso2.md) para DEV y [`doc/v3/deployment-gcp.md`](../v3/deployment-gcp.md) para TEST/PROD), el flujo de testing de tools MCP en sí ([`testing-workflow.md`](ambientes.md)), ni la arquitectura de identidad/federación con Dnato ([`doc/identity/oauth-discovery-flow.md`](../identity/oauth-discovery-flow.md), ADR-008/ADR-009). Este doc es el mapa que conecta esos documentos, no un reemplazo.

---

## 1. Resumen de los 3 ambientes

| Ambiente | Dónde corre | Acceso público | Quién lo usa | Estado hoy (2026-08-08) |
|---|---|---|---|---|
| **DEV** | Máquina local de cada developer (WSO2 APIM+MI nativos) | Ninguno por defecto. Con ngrok, temporal y bajo demanda | Cada developer, individualmente | Activo — es el que se usa día a día |
| **TEST** | VM GCP `e2-medium`, Rocky Linux 9, `us-east1-b` (ADR-011) | `https://mcp.cloudtrazalog.com` (Caddy + TLS Let's Encrypt). Consolas admin NUNCA públicas | Equipo completo, early adopter piloto (sector minero San Juan) | VM instalada y funcionando end-to-end (E7-INFRA-01/02). Todavía sin los artefactos de la fachada MCP desplegados (Tarea 3.5, pendiente) |
| **PROD** | Futuro clon de TEST (misma receta, otra VM/dominio) | Igual esquema que TEST | Clientes reales | No existe todavía |

---

## 2. DEV — máquina local

### 2.1 Cuándo alcanza con `localhost` (sin ngrok)

Para el trabajo del día a día — escribir y probar Synapse APIs, DataServices, correr los tests Hurl, usar Publisher/DevPortal/Carbon — **nunca hace falta ngrok**. Se accede directo:

```
https://localhost:9443/publisher
https://localhost:9443/devportal
https://localhost:9443/carbon
```

Instalación completa en [`wso2-install.md`](wso2.md).

### 2.2 Cuándo hace falta ngrok

Solo cuando algo **externo a tu máquina** necesita alcanzar tu instancia local:

- **(a) Probar el conector MCP desde Claude.ai** — Claude.ai necesita una URL pública para invocar el servidor MCP. Ver [`ngrok-setup.md`](ambientes.md) y [`testing-workflow.md`](ambientes.md) Etapa 2.
- **(b) Probar el flujo completo de federación de identidad con Dnato** (ADR-008/009) — cuando Dnato también necesita ser alcanzable públicamente para que el intercambio OAuth (authorization code, JWKS, PRM) funcione de punta a punta. `scripts/dev/setup-ngrok.sh` automatiza este caso: levanta 2 túneles (APIM gateway 8243 + Dnato 80), actualiza `deployment.toml`, reinicia APIM, y actualiza el issuer del Resident Key Manager.

### 2.3 Cómo levantar una sesión de DEV con ngrok

1. Instalar y autenticar ngrok (una sola vez) — [`ngrok-setup.md`](ambientes.md) §1-2.
2. Levantar WSO2 APIM + MI local ([`wso2-install.md`](wso2.md)).
3. Levantar los 2 túneles ngrok (config file o 2 terminales — ver cabecera de `scripts/dev/setup-ngrok.sh` para el detalle exacto).
4. Correr:
   ```bash
   export APIM_HOME=/ruta/a/tu/wso2am-4.6.0
   bash scripts/dev/setup-ngrok.sh
   ```
   Esto detecta las URLs públicas de los túneles, actualiza `hostname`/`https_endpoint`/`issuer` en `deployment.toml` (con backup automático `.bak.<timestamp>`), reinicia APIM, actualiza el Resident Key Manager, e imprime la URL del conector MCP para Claude.ai y las variables de entorno para Dnato.
5. Trabajar / probar.
6. **Paso obligatorio al terminar la sesión:**
   ```bash
   bash scripts/dev/setup-ngrok.sh --reset
   ```
   Esto revierte `hostname`/`issuer`/`https_endpoint` a `localhost` y reinicia APIM.

> **Por qué este paso es obligatorio y no opcional:** si te salteás el `--reset`, la próxima vez que quieras entrar a Publisher/DevPortal sin ngrok corriendo, APIM va a intentar redirigirte al login vía la URL vieja de ngrok — que ya no existe — y vas a quedar sin poder loguearte, aunque tu instancia esté sana. Esto pasó en la práctica el 2026-08-08: `setup-ngrok.sh` se había corrido (al menos) dos veces desde el 2026-06-30 sin `--reset` después, dejando `hostname` pisado con un subdominio ngrok muerto durante más de un mes. Se corrigió corriendo `--reset` manualmente y reiniciando APIM — ver `doc/v3/STATE.md`.

### 2.4 La URL de ngrok cambia en cada sesión — ¿está considerado?

Sí, en dos frentes distintos:

- **Conector MCP en Claude.ai**: hay que reconfigurar manualmente (Settings → Connectors → editar URL) cada vez que ngrok se reinicia — el plan free no tiene dominios fijos. Documentado en [`ngrok-setup.md`](ambientes.md) §4.
- **`deployment.toml`**: `setup-ngrok.sh` no asume una URL fija — en cada corrida vuelve a leer la URL activa desde la API local de ngrok (`http://localhost:4040/api/tunnels`). Lo único que **no** se resuelve solo es el `--reset` al final de la sesión (§2.3 paso 6) — depende de que el developer lo corra.

### 2.5 Multi-developer

Cada developer levanta su propia instancia local (APIM + MI + ngrok) de forma completamente independiente, siguiendo [`wso2-install.md`](wso2.md) desde cero en su máquina. No hay nada compartido entre developers en DEV — las URLs de ngrok de uno no interfieren con las de otro, cada uno usa su propia cuenta ngrok free.

---

## 3. TEST (hoy) / PROD (futuro) — VM GCP

### 3.1 Qué es TEST hoy

VM `e2-medium`, zona `us-east1-b`, Rocky Linux 9, con WSO2 APIM 4.6.0 + MI 4.5.0 instalados **nativamente** (sin contenedores, sin ngrok, sin túneles) — ADR-011, detalle completo en [`doc/v3/deployment-gcp.md`](../v3/deployment-gcp.md).

- Dominio público: `mcp.cloudtrazalog.com`, TLS automático vía Caddy (Let's Encrypt).
- Puerto 9443 (carbon/publisher/devportal) **nunca se expone públicamente** — solo alcanzable por túnel SSH o red interna del proyecto GCP (`deployment-gcp.md` §3 y §4 paso 9).

**Estado actual:** la VM está instalada y funcionando end-to-end (E7-INFRA-01/02, PR #403/#404), pero todavía no tiene desplegados los artefactos de la fachada MCP unificada (`toolsMCPAPI`, `toolsALMAPI`, etc.) — eso es la Tarea 3.5 (E7-INFRA-05), pendiente de confirmación de Rodolfo sobre si la verificación en DEV de E2-MCP-13 alcanza como prerequisito (ver `doc/v3/STATE.md`).

### 3.2 Cómo acceder a TEST

- **Gateway público** (invocación de APIs/MCP): `https://mcp.cloudtrazalog.com` — directo, sin VPN ni túnel.
- **Consolas admin** (carbon/publisher/devportal): solo vía túnel SSH:
  ```bash
  gcloud compute ssh NOMBRE_VM --zone=us-east1-b --tunnel-through-iap -- -L 9443:localhost:9443
  ```
  y después `https://localhost:9443/publisher` en tu navegador (certificado self-signed, la advertencia del navegador es esperada).

**No hace falta ngrok en TEST** — a diferencia de DEV, ya tiene un dominio público estable con TLS real vía Caddy.

### 3.3 Cómo desplegar cambios a TEST

No existe todavía un script equivalente a `scripts/dev/rebuild-and-deploy-mi.sh` (el de DEV) para TEST — hoy el despliegue a la VM GCP es manual, siguiendo `deployment-gcp.md` §4 pasos 6-8. No se armó un script dedicado porque la Tarea 3.5 (primer despliegue real de la fachada MCP a esta VM) todavía no se ejecutó. Si el despliegue a TEST se vuelve frecuente una vez arrancada esa tarea, vale la pena automatizarlo — queda marcado acá para cuando corresponda.

### 3.4 PROD (futuro)

Todavía no existe. El plan (parte de ADR-011, no ejecutado) es clonar la receta de TEST — misma VM (nueva instancia, sizing igual o ajustado según el uso real del piloto), mismo Caddy+TLS, pero con su propio dominio/IP. Antes de dar de alta al primer cliente real sobre esa VM, quedan dos pendientes que hoy están fuera de alcance de TEST:

- Config de identidad completa (ADR-008/ADR-009) contra el Dnato de ese ambiente.
- Migración de DataServices a PostgreSQL (hoy MySQL/PostgreSQL mezclados — ver `doc/historial/identidad/dataservices-remediation-phase-a.md`, en curso, no cerrada).

No hay fecha ni VM creada todavía — se define cuando el piloto con el early adopter minero valide el approach en TEST.

---

## 4. Resumen rápido — ¿qué uso cuándo?

| Necesito... | Uso |
|---|---|
| Desarrollar o debuggear una API/DataService | DEV local, sin ngrok |
| Probar una tool MCP con Claude.ai | DEV local + ngrok ([`testing-workflow.md`](ambientes.md) Etapa 2), o TEST directamente si ya está desplegado ahí |
| Probar el login/flujo completo con Dnato | DEV local + `setup-ngrok.sh` (2 túneles), o TEST (dominio real, sin ngrok) |
| Mostrarle algo a alguien fuera del equipo, o probar con el early adopter | TEST |
| Dar de alta un cliente real en producción | Todavía no existe — esperar a que TEST valide y clonar (§3.4) |

---

## 5. El motor de los agentes de IA en cada ambiente

El motor es un servicio aparte de Tools y de WSO2, con su propia base (ADR-A14, en [`AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md`](../v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md)). Cómo se instala y se opera: [`doc/agente/instalar-y-operar.md`](../agente/instalar-y-operar.md).

| Ambiente | Motor | Base del motor | Con qué WSO2 habla | Estado (2026-11-26) |
|---|---|---|---|---|
| **DEV local** | `./agente/dev.sh`, en `127.0.0.1:8099` | PostgreSQL local con pgvector, base `agente_minero` (credenciales en `~/.agente-minero.env`, fuera del repositorio). Las pruebas automáticas usan un contenedor descartable aparte | Con el MI local o con el servidor compartido de DEV, en modo `AGENTE_MCP_MODO=mi` (el permiso del usuario va directo como `X-JWT-Assertion`); con el APIM, en modo `apim` | Funciona |
| **Servidor compartido de DEV** | No corre ahí: se usa desde la máquina local apuntando a ese servidor | — | EI 6.5 del servidor (sección 6) | Probado el 2026-11-25 con la empresa de prueba 191 |
| **TEST / PROD** | No instalado | Sin definir dónde vive | APIM, modo `apim` | ⚠️ Falta la unidad de servicio para producción y decidir dónde vive la base. Ver [`deployment-gcp.md`](../v3/deployment-gcp.md), sección del motor de agentes |

---

## 6. El servidor compartido de DEV

Es un servidor del equipo, distinto de la máquina local de cada developer. Se entra por la red privada de la empresa (VPN) con `ssh <usuario>@10.142.0.13` y se usa `sudo` para todo lo de abajo.

| Pieza | Dónde |
|---|---|
| WSO2 Enterprise Integrator **6.5.0** (no MI 4.5) | `/usr/lib64/wso2/wso2ei/6.5.0`, HTTP en el puerto 8280. Los servicios de datos se llaman en `http://10.142.0.13:8280/services` |
| Base de Tools | PostgreSQL 11 en el puerto 5432, base `tools_prod_t`. Consola: `sudo -u postgres psql -p 5432 -d tools_prod_t`, ejecutado desde `/tmp` |
| Lo que **no** tiene | Streaming Integrator, conector Firebase ni el PHP de Tools (Apache solo sirve otros sistemas). El motor de agentes tampoco corre ahí |

**Desplegar un artefacto sin reiniciar.** **Dónde:** SSH al servidor compartido. El EI toma en caliente los archivos que se copian a su carpeta de despliegue:

```bash
sudo install -o wso2 -g wso2 -m 644 <archivo> \
  /usr/lib64/wso2/wso2ei/6.5.0/repository/deployment/server/<carpeta>/
```

`<carpeta>` es `dataservices` para un `.dbs`, `synapse-configs/default/api` para una API y `synapse-configs/default/sequences` para una secuencia.

**Diferencias del EI 6.5 que ya hicieron fallar artefactos que andaban en el MI 4.5** (motor de scripts Rhino):

- Comparar con `===` un texto de Java contra uno de JavaScript da falso: convertir antes con `"" + x`.
- Un texto que devuelve `Packages.java...` no acepta `.replace` con expresión regular de JavaScript: convertir antes con `("" + x)`.
- Un servicio de datos con el mismo parámetro con nombre repetido falla.

Para ejecutar SQL en el servidor conviene copiar un archivo con `scp` y correrlo con `psql -f`: las comillas por SSH se rompen.

---

## Anexos

### Anexo A — ngrok: instalación y túnel para probar el MCP con Claude

> ⚠️ Sin verificar desde 2026-05-16: se juntó tal cual estaba; puede no describir lo que corre hoy.

Procedimiento para exponer el WSO2 API Gateway local a internet usando ngrok,
permitiendo que Claude.ai invoque el servidor MCP de Trazalog en desarrollo.

---

#### 1. Instalación (Ubuntu 24)

Se usa el repositorio oficial de ngrok vía apt:

```bash
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
  | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null

echo "deb https://ngrok-agent.s3.amazonaws.com buster main" \
  | sudo tee /etc/apt/sources.list.d/ngrok.list

sudo apt update && sudo apt install ngrok
```

Versión instalada: **3.39.1**

---

#### 2. Autenticación

Registrarse en [ngrok.com](https://ngrok.com) y obtener el authtoken desde el dashboard.
Configurarlo una sola vez:

```bash
ngrok config add-authtoken <TOKEN>
```

El token queda guardado en `~/.config/ngrok/ngrok.yml`.

---

#### 3. Lanzar el tunnel al WSO2 Gateway (puerto 8243)

Con WSO2 API Manager corriendo localmente:

```bash
ngrok http 8243
```

Salida esperada (ejemplo del smoke test ejecutado 2026-05-16):

```
Session Status    online
Region            South America (sa)
Web Interface     http://127.0.0.1:4040
Forwarding        https://129e-200-114-96-54.ngrok-free.app -> https://localhost:8243
```

La URL pública (`https://<id>.ngrok-free.app`) es la que se usa como base para el
conector MCP en Claude.ai.

La región South America (sa) se elige automáticamente por geolocalización — no
requiere configuración adicional.

---

#### 4. Limitaciones del plan free

| Limitación | Detalle |
|---|---|
| URL efímera | La URL pública cambia cada vez que se reinicia ngrok |
| Sin dominios fijos | El plan pago permite dominios estáticos |
| Conexiones simultáneas | 1 tunnel activo por cuenta en el plan free |

**Workaround para la URL cambiante**: cada vez que se reinicie ngrok, copiar la nueva
URL y actualizar el custom connector en Claude.ai:

> Settings → Connectors → (seleccionar el conector existente) → editar URL

El **dashboard local** en `http://127.0.0.1:4040` muestra todos los requests que
pasan por el tunnel en tiempo real — indispensable para debug de llamadas MCP.

---

#### 5. Agregar el custom connector en Claude.ai (E0-INF-12)

Una vez que ngrok está activo y WSO2 está corriendo:

1. Copiar la URL del tunnel desde la salida de ngrok (ej: `https://129e-200-114-96-54.ngrok-free.app`)
2. Abrir Claude.ai → **Settings** → **Connectors** → **Add custom connector**
3. Completar la URL del endpoint MCP:
   ```
   https://<url-ngrok>/mcp
   ```
4. Guardar y verificar que Claude detecta las herramientas expuestas por el servidor MCP

> **Nota**: el path `/mcp` corresponde al endpoint configurado en WSO2 APIM para el
> servidor MCP de Trazalog. Verificar en el API Publisher que el contexto de la API
> coincide antes de registrar el conector.

### Anexo B — Cómo se prueban las tools MCP (MCP Inspector y Claude.ai)

> ⚠️ Sin verificar desde 2026-05-16: se juntó tal cual estaba; puede no describir lo que corre hoy.

Flujo de testing en dos etapas para tools MCP expuestas via WSO2 APIM 4.6.0.

---

#### Las dos etapas

##### Etapa 1 — MCP Inspector (testing técnico local)

**Cuándo usarlo:** validar schemas JSON-RPC, contratos de tools y respuestas del servidor
*antes* de involucrar a Claude. No requiere internet ni cuenta Claude Pro.

```bash
npx @modelcontextprotocol/inspector
```

UI disponible en: http://localhost:6274

**Qué valida:**
- Estructura de `tools/list`
- Parámetros y tipos de datos
- Error handling

**Cuándo está completo:** todas las tools responden con schema correcto en Inspector.

---

##### Etapa 2 — Claude.ai con ngrok (testing semántico end-to-end)

**Cuándo usarlo:** después de pasar Etapa 1. Valida que Claude entiende las descripciones
de las tools y las invoca correctamente en contexto real.

**Requisitos:** Claude Pro activo + ngrok corriendo + WSO2 APIM levantado.

**Tunnel ngrok (crítico — WSO2 usa HTTPS en puerto 8243):**

```bash
# CORRECTO
ngrok http https://localhost:8243

# INCORRECTO — rompe el handshake SSL
ngrok http 8243
```

**Configurar connector en Claude.ai:**
Settings → Connectors → Add custom connector → URL: `https://<id>.ngrok-free.app`

> **Plan free:** la URL ngrok cambia en cada reinicio. Actualizar el connector en Claude.ai
> cada vez que se reinicie ngrok.

**Qué valida:**
- Semántica de las tool descriptions
- Comportamiento de Claude al invocar tools
- Respuestas en lenguaje natural

---

#### Cuándo usar cada etapa

| Situación | Etapa |
|---|---|
| Crear una tool nueva | Etapa 1 primero, luego Etapa 2 |
| Cambiar parámetros de una tool existente | Etapa 1 |
| Cambiar la descripción semántica de una tool | Etapa 2 |
| Debugging de error JSON-RPC | Etapa 1 |
| Validar que Claude invoca la tool correcta ante una pregunta | Etapa 2 |
| Antes de hacer PR de una tool nueva | Ambas etapas |

---

#### Checklist antes de cerrar un issue de tool MCP

- [ ] Tool pasa Etapa 1: MCP Inspector devuelve schema correcto
- [ ] Tool tiene annotation correcta (`readOnlyHint` o `destructiveHint`) — ver [`doc/mcp/tool-annotations-standard.md`](../mcp/tool-annotations-standard.md)
- [ ] Tool pasa Etapa 2: Claude la invoca correctamente con una pregunta en lenguaje natural
- [ ] Tool result < 25.000 tokens
- [ ] Timeout < 5 minutos

## De dónde salió este documento

Fusionado el 2026-11-26 (unificación de documentación, `DOC-UNIF-2`) a partir de:

- `doc/infra/ambientes.md (versión anterior)`
- `doc/infra/ambientes.md`
- `doc/infra/ambientes.md`

El texto se juntó sin reescribirlo; solo se bajaron niveles de título y se ajustaron enlaces. La historia de cada parte está en `git log --follow` de los archivos originales.
