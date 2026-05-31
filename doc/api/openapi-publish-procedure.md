# Procedimiento de publicación de OpenAPI specs en WSO2 API Manager 4.6.0

**Tarea:** E1-API-10  
**Aplica a:** `equipos.yaml`, `ot.yaml`  
**Prerequisito:** WSO2 APIM 4.6.0 instalado y corriendo (`https://localhost:9443`)

---

## 1. Visión general

```
doc/api/equipos.yaml          doc/api/ot.yaml
        │                             │
        ▼                             ▼
  API Publisher              API Publisher
  (9443/publisher)           (9443/publisher)
        │                             │
        ▼                             ▼
  API Gateway                API Gateway
  (8243/equipos/1.0)         (8243/ordenes-trabajo/1.0)
        │                             │
        ▼                             ▼
  toolsMANAPI (MI 8280)      toolsMANAPI (MI 8280)
  /tools/man/mcp/equipo*     /tools/man/mcp/ot*
```

Cada spec OpenAPI se importa en el Publisher como una API independiente.
El gateway APIM recibe los requests de los agentes MCP y los proxea al
Micro Integrator (WSO2 MI) donde están los artefactos de mediación.

---

## 2. Publicar `equipos.yaml` — API de Equipos

### 2.1 Importar la spec

1. Ir a: `https://localhost:9443/publisher`
2. Iniciar sesión con credenciales de administrador
3. Click en **`+ Create API`** → **`Import OpenAPI`**
4. Seleccionar `doc/api/equipos.yaml` desde el filesystem
5. Verificar los campos pre-completados:
   - **Name:** `Equipos`
   - **Version:** `1.0`
   - **Context:** `/equipos`
6. Click **`Create`**

### 2.2 Configurar el backend (Endpoint)

En la sección **`Endpoints`** de la API creada:

| Campo | Valor |
|---|---|
| Endpoint type | HTTP/REST Endpoint |
| Production URL | `http://10.142.0.13:8280/tools/man` |
| Sandbox URL | `http://10.142.0.13:8280/tools/man` |

> El APIM proxea al MI (port 8280). El contexto `/tools/man` ya está configurado en `toolsMANAPI.xml`.

### 2.3 Configurar seguridad (OAuth2 → JWT passthrough)

En **`Runtime`** → **`Application Level Security`**:

- Desmarcar **`OAuth2`** (el APIM no valida el JWT propio — lo valida el MI via `jwtValidator`)
- Marcar **`None`** o configurar como "passthrough"

> **Importante:** la validación del JWT Dnato ocurre en el MI (sequence `jwtValidator`).
> El APIM solo rutea el request sin validar el token. El header `Authorization: Bearer <JWT>`
> se pasa tal cual al MI.

Alternativa si el APIM requiere OAuth2 propio:
- Configurar el MI para aceptar tanto el JWT Dnato (header) como ignorar el token APIM
- Documentar como mejora Sprint 3+

### 2.4 Publicar

1. Click **`Publish`** (esquina superior derecha)
2. Estado debe cambiar a `Published`
3. URL del gateway: `https://localhost:8243/equipos/1.0/mcp/equipos`

### 2.5 Verificar

```bash
# Obtener un JWT de prueba (ver tests/security/generate-test-jwts.sh)
source tests/security/test-env.vars

# Lista de equipos via APIM gateway
curl -k -H "Authorization: Bearer $VALID_JWT" \
     https://localhost:8243/equipos/1.0/mcp/equipos

# Detalle de equipo via APIM gateway
curl -k -H "Authorization: Bearer $VALID_JWT" \
     https://localhost:8243/equipos/1.0/mcp/equipo/10
```

---

## 3. Publicar `ot.yaml` — API de Órdenes de Trabajo

### 3.1 Importar la spec

1. **`+ Create API`** → **`Import OpenAPI`**
2. Seleccionar `doc/api/ot.yaml`
3. Verificar:
   - **Name:** `Ordenes de Trabajo`
   - **Version:** `1.0`
   - **Context:** `/ordenes-trabajo`
4. Click **`Create`**

### 3.2 Configurar el backend

| Campo | Valor |
|---|---|
| Endpoint type | HTTP/REST Endpoint |
| Production URL | `http://10.142.0.13:8280/tools/man` |
| Sandbox URL | `http://10.142.0.13:8280/tools/man` |

### 3.3 Seguridad

Misma configuración que Equipos: JWT passthrough al MI.

### 3.4 Publicar y verificar

```bash
source tests/security/test-env.vars

# Listar OTs via APIM
curl -k -H "Authorization: Bearer $VALID_JWT" \
     https://localhost:8243/ordenes-trabajo/1.0/mcp/ot

# Detalle de OT
curl -k -H "Authorization: Bearer $VALID_JWT" \
     https://localhost:8243/ordenes-trabajo/1.0/mcp/ot/1842

# Crear OT (create_ot demo tool)
curl -k -X POST \
     -H "Authorization: Bearer $VALID_JWT" \
     -H "Content-Type: application/json" \
     -d '{"equipo_id":"10","descripcion":"Test OT desde APIM gateway"}' \
     https://localhost:8243/ordenes-trabajo/1.0/mcp/ot
```

---

## 4. Asociar las specs al MCP Gateway (Virtual MCP Server)

Una vez publicadas las APIs en APIM, asociarlas al Virtual MCP Server:

1. Ir al **`MCP Gateway`** de APIM 4.6.0
   (si no está visible, habilitar el plugin MCP en `deployment.toml`)
2. Crear un nuevo **`Virtual MCP Server`** para cada API:

| MCP Server | API | Tools generadas |
|---|---|---|
| `trazalog-equipos` | Equipos 1.0 | `get_equipos`, `get_equipo` |
| `trazalog-ots` | Ordenes de Trabajo 1.0 | `get_ots`, `get_ot`, `create_ot` |

3. El APIM deriva automáticamente las MCP tools desde los `operationId`
   de la spec y las `description` de cada operación — esas son las que
   Claude usa para decidir cuándo invocar cada tool.

---

## 5. Re-publicar tras cambios en la spec

Si se modifica `equipos.yaml` o `ot.yaml`:

1. En el Publisher → seleccionar la API → **`Edit`**
2. **`API Definition`** → **`Import`** → subir el archivo actualizado
3. Hacer click en **`Save`**
4. Si los paths/methods cambiaron: volver a publicar (**`Publish`**)
5. Los Virtual MCP Servers se actualizan automáticamente en el siguiente
   ciclo de sincronización del MCP Gateway (o reiniciar el gateway)

---

## 6. Checklist de publicación

```
[ ] equipos.yaml válido (validar con: npx swagger-cli validate doc/api/equipos.yaml)
[ ] ot.yaml válido
[ ] Backend URL apuntando a MI (no a APIM mismo)
[ ] JWT passthrough configurado (no OAuth2 nativo de APIM)
[ ] Ambas APIs en estado Published
[ ] curl de verificación exitoso contra gateway :8243
[ ] Virtual MCP Servers creados en el MCP Gateway
[ ] Tests Hurl pasan contra la URL del gateway (actualizar MI_HOST en test-env.vars)
```

---

## 7. Validar las specs localmente antes de publicar

```bash
# Instalar swagger-cli si no está disponible
npm install -g @apidevtools/swagger-cli

# Validar equipos.yaml
npx swagger-cli validate doc/api/equipos.yaml

# Validar ot.yaml
npx swagger-cli validate doc/api/ot.yaml
```

Ambos deben devolver `doc/api/equipos.yaml is valid` sin errores.
