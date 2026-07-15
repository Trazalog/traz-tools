# Procedimiento de publicación de OpenAPI specs en WSO2 API Manager 4.6.0

**Tarea:** E1-API-10 (rehecha por ADR-008)
**Aplica a:** `equipos.yaml`, `ot.yaml`
**Decisión base:** [ADR-008](../v3/TRAZALOG_v3_MCP_ARCHITECTURE.md) — el APIM valida el JWT de
Dnato como **Key Manager federado**. El MI **no** valida JWT para tráfico MCP.
**Prerequisito:** WSO2 APIM 4.6.0 corriendo (`https://localhost:9443`) **y** Dnato configurado
como Key Manager federado (ver [apim-keymanager-dnato.md](../identity/apim-keymanager-dnato.md)).

> Reemplaza a [`openapi-publish-procedure.OBSOLETE.md`](openapi-publish-procedure.OBSOLETE.md),
> que usaba el patrón "JWT passthrough" descartado.

---

## 1. Visión general (flujo ADR-008)

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

## 2. Prerequisito: Key Manager "Dnato" configurado

Antes de publicar las APIs, el APIM debe tener registrado el Key Manager federado de Dnato.
Ver el procedimiento completo en
**[apim-keymanager-dnato.md](../identity/apim-keymanager-dnato.md)**. En resumen, debe existir
en `https://localhost:9443/admin` → **Key Managers** una entrada **`Dnato`** de tipo externo,
apuntando al JWKS de Dnato (`/oauth/.well-known/jwks.json`), con issuer `trazalog-dnato` y
audience `trazalog-mcp`, y **validación de suscripción desactivada** (MVP).

---

## 3. Publicar `equipos.yaml` — API de Equipos

### 3.1 Importar la spec

1. Ir a: `https://localhost:9443/publisher`
2. Iniciar sesión con credenciales de administrador
3. **`+ Create API`** → **`Import OpenAPI`**
4. Seleccionar `doc/api/equipos.yaml` desde el filesystem
5. Verificar los campos pre-completados:
   - **Name:** `Equipos`
   - **Version:** `1.0`
   - **Context:** `/equipos`
6. **`Create`**

### 3.2 Configurar el backend (Endpoint)

En **`Develop`** → **`API Configurations`** → **`Endpoints`**:

| Campo | Valor |
|---|---|
| Endpoint type | HTTP/REST Endpoint |
| Production URL | `http://10.142.0.13:8280/tools/man` |
| Sandbox URL | `http://10.142.0.13:8280/tools/man` |

> El APIM proxea al MI (port 8280). El contexto `/tools/man` ya está en `toolsMANAPI.xml`.

### 3.3 Configurar seguridad — OAuth2 con Key Manager Dnato

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

### 3.4 Asociar la mediación de inyección de `empr_id`

Aplicar a esta API la policy/mediación que extrae `empr_id` del JWT y lo inyecta como header
`X-Empr-Id` hacia el MI. Ver **[empr-id-injection.md](../identity/empr-id-injection.md)** para
el artefacto y los pasos de asociación (policy reutilizable, no copy-paste por API).

### 3.5 Publicar

1. **`Publish`** (esquina superior derecha)
2. Estado → `Published`
3. URL del gateway: `https://localhost:8243/equipos/1.0/mcp/equipos`

### 3.6 Verificar — con JWT REAL de Dnato

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

## 4. Publicar `ot.yaml` — API de Órdenes de Trabajo

### 4.1 Importar la spec

1. **`+ Create API`** → **`Import OpenAPI`**
2. Seleccionar `doc/api/ot.yaml`
3. Verificar:
   - **Name:** `Ordenes de Trabajo`
   - **Version:** `1.0`
   - **Context:** `/ordenes-trabajo`
4. **`Create`**

### 4.2 Configurar el backend

| Campo | Valor |
|---|---|
| Endpoint type | HTTP/REST Endpoint |
| Production URL | `http://10.142.0.13:8280/tools/man` |
| Sandbox URL | `http://10.142.0.13:8280/tools/man` |

### 4.3 Seguridad y mediación

Idéntico a Equipos (ver §3.3 y §3.4): OAuth2 + Key Manager **Dnato** (no Resident KM) +
mediación de inyección de `X-Empr-Id`. El Key Manager y la policy de mediación son compartidos
— no se vuelven a crear, solo se asocian a esta API.

### 4.4 Publicar y verificar

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

## 5. Asociar las specs al MCP Gateway (Virtual MCP Server)

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

## 6. Cómo el APIM inyecta `empr_id` downstream al MI

Resumen (detalle completo en [empr-id-injection.md](../identity/empr-id-injection.md)):

1. El APIM valida el JWT de Dnato (firma vs JWKS, `exp`, `iss`, `aud`).
2. Una mediación in-flow extrae el claim `empr_id` del JWT validado.
3. La mediación setea el header **`X-Empr-Id: <empr_id>`** en el request hacia el MI.
4. El MI **no valida JWT**; lee `X-Empr-Id` (sequence `emprIdFromHeader`) y lo usa para
   construir las URLs de los DataServices, que filtran por `empr_id`.

El cliente no puede falsificar `X-Empr-Id`: el APIM lo sobreescribe en cada request a partir del
claim del token ya validado, ignorando cualquier `X-Empr-Id` entrante.

---

## 7. Re-publicar tras cambios en la spec

1. Publisher → seleccionar la API → **`Edit`**
2. **`API Definition`** → **`Import`** → subir el archivo actualizado
3. **`Save`**
4. Si los paths/methods cambiaron: volver a publicar (**`Publish`**)
5. Verificar que la API sigue asociada al Key Manager **Dnato** y a la mediación de `empr_id`
   (re-importar la definición no debe desasociarlas, pero conviene confirmar).

---

## 8. Checklist de publicación

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

## 9. Validar las specs localmente antes de publicar

```bash
npm install -g @apidevtools/swagger-cli
npx swagger-cli validate doc/api/equipos.yaml
npx swagger-cli validate doc/api/ot.yaml
```

Ambos deben devolver `... is valid` sin errores.
