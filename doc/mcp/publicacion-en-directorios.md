# Publicar el MCP de Trazalog en los directorios de Anthropic, OpenAI y Google

## Objetivo

Guía paso a paso para que el MCP Server de Trazalog aparezca en los directorios de conectores de
**Claude (Anthropic)**, **ChatGPT (OpenAI)** y **Gemini (Google)**, en ese orden. Está escrita para
el PM, para ir preparando los trámites **antes** de que la versión de `develop` pase a producción,
así el día del cutover se envía y no se empieza. Cubre qué exige cada directorio, qué de eso
Trazalog ya cumple, qué falta, y los pasos exactos de cada envío. **No cubre** cómo publicar tools
nuevas en el APIM (eso está en [`republicar-mcp-server.md`](republicar-mcp-server.md)) ni el
despliegue a producción en sí.

| | |
|---|---|
| **Relevado el** | 2026-09-22, contra la documentación oficial de los tres proveedores (links al final) |
| **Versión que se publica** | la de `develop` — 20 tools, MCP Server en `https://mcp.cloudtrazalog.com/trazalog/mcp/1.0/mcp` |
| **Authorization Server** | Dnato — `https://<host-dnato>/traz-comp-dnato/oauth/` |
| **Vigencia** | los tres procesos cambiaron durante 2026; **revalidar los links oficiales antes de enviar** |

---

## 1. Lo primero que hay que entender: no son tres directorios

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

## 2. Lo que hay que tener ANTES de empezar cualquiera de los tres

Estos requisitos se repiten en los tres. Conviene resolverlos una sola vez, primero. La columna de
estado es lo verificado el 2026-09-22 contra `develop` y contra los sitios públicos.

### 2.1 Páginas públicas obligatorias

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

### 2.2 Cuenta de prueba para el revisor

Los tres piden credenciales de un usuario **con datos realistas cargados** (no una empresa vacía).
OpenAI además exige que funcione **sin MFA, sin confirmación por mail ni SMS, y sin VPN**.

Qué preparar: una empresa de demostración en producción con equipos, órdenes de trabajo, stock,
pedidos y movimientos suficientes para que cada tool devuelva algo, y **un usuario de esa empresa
que tenga exactamente una empresa asignada** (la versión de `develop` no tiene selector de empresa:
con más de una, el login OAuth rechaza el ingreso).

> ⚠️ El revisor va a **crear registros reales**: `man_create_ot` abre una OT en Bonita y
> `alm_crear_pedido_materiales` crea un pedido. La empresa de prueba tiene que ser descartable.

### 2.3 Logo e ícono

| | Anthropic | OpenAI |
|---|---|---|
| Ícono / logo | URL o SVG, más favicon | logo "production-ready" |

Usar el isologo (`public/img/logotzl.png` en dnato, 17 KB) o su versión SVG si existe.

### 2.4 Anotaciones de las tools

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

### 2.5 OAuth — lo que ya está y lo que falta

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

### 2.6 Red y latencia

- Anthropic sale a internet desde **`160.79.104.0/21`**. Ya funciona, así que el firewall de GCP lo
  permite; **no tocar esa regla** en el cutover.
- Anthropic espera **como máximo 10 segundos** en discovery, registro y token, y 30 en refresh. El
  Dnato de producción tiene que responder bien por debajo de eso. Si el `/token` tarda varios
  segundos (PHP 5.6 + consultas a Bonita), los usuarios van a ver fallos intermitentes de conexión.
- Google exige **certificado TLS de una CA pública** (Let's Encrypt sirve; autofirmado no) y
  **transporte Streamable HTTP** — SSE no está soportado. El MCP Server del APIM 4.6 ya es
  Streamable HTTP.

---

## 3. Paso 0 (recomendado): el MCP Registry oficial

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

## 4. Anthropic — Connectors Directory de Claude

### 4.1 Cómo funciona la revisión

Al enviar, el servidor se escanea automáticamente y **queda listado como *community connector***.
Anthropic puede escalarlo a **revisión *verified*** (humana, más lenta) si lo considera útil para
muchos usuarios; eso no se pide, lo deciden ellos. La etiqueta es una señal de calidad para el
usuario, no cambia cómo funciona el conector. Los criterios son los mismos en ambos casos.

### 4.2 Prerrequisitos administrativos

1. **Organización Claude Team o Enterprise.** El portal de envío vive en la configuración de la
   organización; los planes individuales no lo tienen. Si Trazalog no tiene una, hay que crearla.
2. **Rol con acceso al directorio.** Por defecto solo *Owner* y *Primary owner*. En Team no hay
   roles custom, así que lo envía un Owner.
3. Aceptar los [Anthropic Software Directory Terms](https://support.claude.com/en/articles/13145338-anthropic-software-directory-terms)
   y la [Directory Policy](https://support.claude.com/en/articles/13145358-anthropic-software-directory-policy).

### 4.3 Antes de enviar — lo que el revisor prueba

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

### 4.4 Los pasos del portal

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

### 4.5 Una recomendación de Anthropic que afecta a Dnato

> *"For servers expecting high traffic from the directory, prefer CIMD or `oauth_anthropic_creds`
> over DCR. DCR causes Claude to register a new client on every fresh connection."*

Con DCR, **cada conexión nueva crea un registro de cliente en Dnato**. Con decenas de usuarios no
importa; con cientos, la tabla de clientes OAuth crece sin límite. No es bloqueante para publicar,
pero hay que tenerlo en el radar: la alternativa más simple para Trazalog es `oauth_anthropic_creds`
(crear un `client_id`/`client_secret` fijo en Dnato y mandárselo a `mcp-review@anthropic.com`).

---

## 5. OpenAI — Plugins Directory de ChatGPT

### 5.1 Cómo funciona

Desde 2026 las apps de ChatGPT se envían como **plugins**. Un MCP remoto es un plugin "With MCP".
La revisión es **manual y sin plazos publicados**. Aprobado el plugin, **lo publicás vos** desde el
portal cuando quieras, y aparece en el directorio compartido por ChatGPT y Codex.

Después de publicado, OpenAI **relee las tools periódicamente**: las borradas desaparecen solas y
las nuevas o cambiadas entran después de un chequeo automático. Cambios en la ficha o los skills sí
requieren nueva versión y nueva revisión.

### 5.2 Prerrequisitos administrativos

1. 🌐 **Verificar la identidad de negocio** en OpenAI Platform: `https://platform.openai.com` →
   organización → configuración → verificación individual o de empresa. *"Reviewers may reject
   submissions that use an unverified or mismatched publisher identity."* La empresa verificada
   tiene que coincidir con el sitio web y las URLs legales que se declaran.
2. 🌐 **Rol con Apps Management = Write**:
   `https://platform.openai.com/settings/organization/people/roles` → rol del que envía →
   **Apps Management** → **Write** → asignar. Recargar `https://platform.openai.com/plugins`.

### 5.3 Prerrequisitos técnicos — lo que OpenAI exige de más

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

### 5.4 Políticas que hay que tener presentes

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

### 5.5 Los pasos del portal

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

### 5.6 Los ocho casos de prueba

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

## 6. Google — Gemini

### 6.1 Lo que existe y lo que no

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

### 6.2 Lo que Gemini Enterprise exige del lado de Trazalog

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

### 6.3 La guía para el administrador del cliente

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

## 7. Cambios de código que salen de todo esto

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

## 8. Orden sugerido

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

## 9. Fuentes

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
