# Bonita 7 (toolsbpmAPI) - Documentación de operaciones

Este documento describe las operaciones expuestas por el API wrapper configurado en `src/main/wso2mi/artifacts/apis/toolsBPMAPI.xml` (contexto `"/tools/bpm"`). El wrapper delega llamadas a la REST API de Bonita 7.x usando el contrato descrito en `doc/bonita/bonita-openapi-0.0.1.yaml` y utiliza la colección de Postman `doc/bonita/bonita-postman-collection-0.0.1.json` como referencia de payloads/ejemplos.

## Contexto y base de Bonita

- Contexto del wrapper: `"/tools/bpm"`
- Base URL de Bonita (desde `bpmconf.xml`): `bpm_url` (configurable; ver `src/main/wso2mi/resources/conf/tools/bpmconf.xml`).

## Autenticación y manejo de sesión (wrapper)

La REST API de Bonita requiere:

- Cookie `JSESSIONID`
- Header `X-Bonita-API-Token`

Esto corresponde a los `securitySchemes` del OpenAPI: `bonita_auth` (cookie `JSESSIONID`) y `bonita_token` (header `X-Bonita-API-Token`).

### ¿Qué debe enviar el cliente al wrapper?

El wrapper espera un campo `session` (en path o en body, según el endpoint) que contiene información de sesión en forma de string/cadena de cookie con al menos:

- `JSESSIONID=...`
- `X-Bonita-API-Token=...`
- `bonita.tenant=...`

Internamente, `templates/bpmAPICallTemplate.xml` elimina headers/cookies previos y llama a `conf/tools/armarSession.js` para reconstruir:

- Header `X-Bonita-API-Token` a partir de la cookie `X-Bonita-API-Token`
- Cookie `Cookie` reenviando los valores de `JSESSIONID` y `bonita.tenant`

### ¿Qué pasa si la sesión expira?

Si la respuesta Bonita retorna `401`, el wrapper:

1. Llama a `GET` sobre `/loginservice` usando el usuario/password configurados en `bpmconf.xml` (sin revelar credenciales en este documento).
2. Reconstruye la sesión con `armarSession.js`
3. Reintenta la llamada al recurso original.

## Formato de respuestas del wrapper

Para llamadas delegadas con `bpmAPICallTemplate`, el wrapper envuelve respuestas exitosas con este formato:

- Éxito con payload:
  - `{ "session": "<cookie reconstruida>", "payload": <respuesta Bonita> }`
- Éxito sin payload:
  - `{ "session": "<cookie reconstruida>" }`

Para errores, usa `sequences/toolsFaultSequence.xml`, devolviendo una respuesta con estructura:

- `{ "respuesta": { "codigo": "1000", "error": "...", "detalle": "...", "payload": ...? } }`

## Operaciones (13 endpoints del wrapper)

### 1) `POST /tools/bpm/proceso/instancia`

Objetivo: Instanciar un proceso en Bonita y, en caso de fallo al crear el “case empresa” en `COREDataService`, hacer rollback del case en Bonita.

Parámetros (body JSON):

- `nombre_proceso` (string)
- `payload` (object; normalmente contiene las variables/contrato del proceso e incluye `caseId` para registrar el case empresa)
- `session` (string con cookies de Bonita)
- `emprId` (string/number; id de empresa para COREDataService)

Uso (flujo interno):

- Buscar el proceso por nombre:
  - Bonita OpenAPI: `GET /API/bpm/process` (`operationId: searchProcesses`)
  - Wrapper usa (según `toolsBPMAPI.xml`): `p=0&c=10&s=<nombre_proceso>&f%3DactivationStateactivationState%253D=ENABLED`
- Instanciar el proceso:
  - Bonita OpenAPI: `POST /API/bpm/process/{id}/instantiation` (`operationId: instanciateProcess`)
  - Parámetros: `{id} = bpmProcessId` (tomado del resultado de búsqueda)
  - Body: `payload` (JSON que debe cumplir el contrato del proceso)
- Crear el “case empresa”:
  - `POST <dataservices_url>/COREDataService/empresa/proceso`
  - Body transformado desde wrapper:
    - `{"_post_empresa_proceso":{"case_id":"<payload.caseId>","empr_id":"<emprId>"}}`
- Rollback si COREDataService falla:
  - Bonita: `DELETE /API/bpm/case/{id}` (wrapper usa `caseId` del input)
  - OpenAPI: `'/API/bpm/case/{id}' delete` (operationId: `deleteProcessInstanceById`)

Ejemplo (request):

```json
{
  "nombre_proceso": "NombreProceso",
  "payload": {
    "caseId": "123",
    "contract_var_1": "valor"
  },
  "session": "JSESSIONID=...;X-Bonita-API-Token=...;bonita.tenant=...",
  "emprId": "999"
}
```

### 2) `DELETE /tools/bpm/proceso/instancia`

Objetivo: Eliminar (rollback/cleanup) un `case` (ProcessInstance) en Bonita por `caseid`.

Parámetros (body JSON):

- `caseid` (string)
- `session` (string con cookies de Bonita)

Llamada interna:

- Bonita OpenAPI: `DELETE /API/bpm/case/{id}` (`operationId: deleteProcessInstanceById`)

Ejemplo (request):

```json
{ "caseid": "123", "session": "JSESSIONID=...;X-Bonita-API-Token=...;bonita.tenant=..." }
```

### 3) `GET /tools/bpm/roles/{session}`

Objetivo: Listar roles en Bonita (ordenados por `displayName ASC`).

Parámetros:

- `session` (path; string con cookies de Bonita)

Llamada interna:

- Bonita OpenAPI: `GET /API/identity/role` (`operationId: searchRoles`)
  - Postman item: “Finds Roles”
  - Wrapper usa: `p=0&c=1000&o=displayName%20ASC`

Respuesta: envuelta por `bpmAPICallTemplate` como `{ "session": "...", "payload": [...] }`.

### 4) `GET /tools/bpm/groups/{session}`

Objetivo: Listar grupos y desplegar `parent_group_id`.

Parámetros:

- `session` (path; string con cookies de Bonita)

Llamada interna:

- Bonita OpenAPI: `GET /API/identity/group` (`operationId: searchGroups`)
  - Wrapper usa: `p=0&c=1000&d=parent_group_id&o=displayName%20ASC`

Respuesta: envuelta por `bpmAPICallTemplate`.

### 5) `POST /tools/bpm/memberships`

Objetivo: Crear una Membership (asociación user-role-group) en Bonita.

Parámetros (body JSON):

- `session` (string con cookies de Bonita)
- `payload` (object; se reenvía como body a Bonita)

Llamada interna:

- Bonita OpenAPI: `POST /API/identity/membership` (`operationId: createMembership`)
  - Postman item: “Create the Membership”
  - Esquema OpenAPI (MembershipCreateRequest): requiere `role_id`, `group_id`, `user_id`

Ejemplo (request):

```json
{
  "session": "JSESSIONID=...;X-Bonita-API-Token=...;bonita.tenant=...",
  "payload": { "role_id": "1", "group_id": "5", "user_id": "101" }
}
```

### 6) `POST /tools/bpm/users`

Objetivo: Crear un usuario en Bonita y luego forzarlo a “enabled=true”.

Parámetros (body JSON):

- `session` (string con cookies de Bonita)
- `payload` (object; se reenvía al `POST /API/identity/user`, y además el wrapper usa `payload.id` para el `PUT`)

Llamadas internas:

- Bonita OpenAPI: `POST /API/identity/user` (`operationId: createUser`)
  - Postman item: “Create the User”
  - Esquema OpenAPI (UserCreateRequest): requiere `userName`, `password`, `password_confirm`, `firstname`, `lastname`, `enabled`
- Bonita OpenAPI: `PUT /API/identity/user/{id}` (`operationId: updateUserById`)
  - El wrapper construye el body como `{"enabled":"true"}` (string), y usa `{id} = payload.id`.

Nota importante (posible inconsistencia):

- El wrapper determina `userid` desde `$.payload.id` (request) y no desde la respuesta del `POST /API/identity/user`. Si el cliente no conoce el `id` final del usuario creado, el `PUT` podría fallar.

### 7) `GET /tools/bpm/users/{usr}/session/{session}`

Objetivo: Buscar usuarios por nombre (filtro por `userName`) y devolver el resultado.

Parámetros:

- `usr` (path; string; valor usado en el filtro)
- `session` (path; string con cookies de Bonita)

Llamada interna:

- Bonita OpenAPI: `GET /API/identity/user` (`operationId: searchUsers`)
  - Wrapper usa: `f=userName%3d<usr>`

Respuesta: envuelta por `bpmAPICallTemplate`.

### 8) `GET /tools/bpm/memberships/xUserid/{usrid}/session/{session}`

Objetivo: Buscar memberships filtrando por `user_id` e incluyendo `role_id` y `group_id`.

Parámetros:

- `usrid` (path; string)
- `session` (path; string con cookies de Bonita)

Llamada interna:

- Bonita OpenAPI: `GET /API/identity/membership` (`operationId: searchMemberships`)
  - Esquema/nota OpenAPI: el filtro `user_id` es obligatorio
  - Wrapper usa: `f=user_id%3d<usrid>&d=role_id&d=group_id&o=GROUP_NAME_ASC`

Respuesta: envuelta por `bpmAPICallTemplate`.

### 9) `DELETE /tools/bpm/membership`

Objetivo: Borrar una Membership por identificadores compuestos.

Parámetros (body JSON):

- `user_id` (string)
- `group_id` (string)
- `role_id` (string)
- `session` (string con cookies de Bonita)

Llamada interna:

- Bonita OpenAPI: `DELETE /API/identity/membership/{userId}/{groupId}/{roleId}`
  - operationId: `deleteMembershipById`

Ejemplo (request):

```json
{
  "user_id": "101",
  "group_id": "5",
  "role_id": "1",
  "session": "JSESSIONID=...;X-Bonita-API-Token=...;bonita.tenant=..."
}
```

### 10) `POST /tools/bpm/group`

Objetivo: Crear un Group en Bonita.

Parámetros (body JSON):

- `session` (string con cookies de Bonita)
- `payload` (object; body parcial para `GroupCreateRequest`)

Llamada interna:

- Bonita OpenAPI: `POST /API/identity/group` (`operationId: createGroup`)
  - Postman item: “Create the Group”
  - Esquema OpenAPI (GroupCreateRequest): requiere `name`

### 11) `POST /tools/bpm/profileMember`

Objetivo: Crear un ProfileMember en Bonita (mapping entre perfil y miembro: user/role/group).

Parámetros (body JSON):

- `session` (string con cookies de Bonita)
- `payload` (object; body parcial para `ProfileMemberCreateRequest`)

Llamada interna:

- Bonita OpenAPI: `POST /API/portal/profileMember` (`operationId: createProfileMember`)
  - Postman item: “Create the ProfileMember”
  - Esquema OpenAPI (ProfileMemberCreateRequest): campos típicos `profile_id`, `member_type`, y uno de `user_id`/`role_id`/`group_id` según `member_type`

### 12) `POST /tools/bpm/role`

Objetivo: Crear un Role en Bonita.

Parámetros (body JSON):

- `session` (string con cookies de Bonita)
- `payload` (object; body parcial para `RoleCreateRequest`)

Llamada interna:

- Bonita OpenAPI: `POST /API/identity/role` (`operationId: createRole`)
  - Postman item: “Create the Role”
  - Esquema OpenAPI (RoleCreateRequest): requiere `name`

### 13) `POST /tools/bpm/actor/rol`

Objetivo: Asociar un `rol` a un `actor` dentro del contexto de un proceso Bonita.

Parámetros (body JSON):

- `nombre_proceso` (string)
- `nombre_actor` (string; se busca por `actors[i].name`)
- `nombre_rol` (string; se busca por `roles[i].name`)
- `session` (string con cookies de Bonita)

Llamadas internas (flujo):

1. Buscar proceso por nombre y estado:
   - Bonita OpenAPI: `GET /API/bpm/process` (`operationId: searchProcesses`)
   - Wrapper usa: `p=0&c=10&s=<nombre_proceso>&f=activationState%3DENABLED`
2. Obtener actores del proceso:
   - Bonita OpenAPI: `GET /API/bpm/actor` (`operationId: searchActors`)
   - Wrapper usa: `p=0&c=100&f=process_id=<bpmProcessId>`
3. Obtener rol por nombre:
   - Bonita OpenAPI: `GET /API/identity/role` (`operationId: searchRoles`)
   - Wrapper usa: `p=0&c=1000&s=<nombre_rol>` (busca por `s`)
4. Crear el vínculo actor-rol:
   - Wrapper llama: `POST /API/bpm/actorMember` con:
     - `actor_id` (actorId encontrado)
     - `role_id` (roleId encontrado)
     - `group_id = "-1"`, `user_id = "-1"`

Nota de compatibilidad con el OpenAPI:

- En `bonita-openapi-0.0.1.yaml` el OpenAPI documenta búsquedas en `GET /API/bpm/actorMemberEntry` y operaciones por ID, pero no aparece explícitamente el `POST /API/bpm/actorMember`. El wrapper usa `POST /API/bpm/actorMember`; validar en el entorno si ese endpoint existe o si debería mapearse a la ruta “Entry” según la versión/caso de uso.

## Resumen rápido (qué endpoints cubre el wrapper)

- Procesos/instanciación/case: `POST /proceso/instancia`, `DELETE /proceso/instancia`
- Identidad (roles, grupos, users, memberships): `roles`, `groups`, `memberships`, `users`, `membership`
- Portal (profileMember): `profileMember`
- BPM (actor-rol): `actor/rol`

Si necesitas, puedo generar también un “contrato de request/response” (JSON Schema) específico para estos 13 endpoints del wrapper, basado tanto en el XML como en los `*CreateRequest` del OpenAPI.

