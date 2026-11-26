# Análisis de impacto — Token de máquina emitido por Dnato (DNATO-TOKEN)

## Objetivo

Qué es: el análisis de impacto **obligatorio** (CLAUDE.md, "Sistema PRODUCTIVO") antes de tocar la identidad de Dnato para que emita tokens de máquina por `client_credentials` (ADR-A10). Para quién: el PM, que lo aprueba o lo corrige; sin su aprobación no se escribe código. Cuándo leerlo: antes de implementar DNATO-TOKEN y antes de los avisos proactivos de Quirqui (AGENTE-AS-03) y las mediciones de Kuntur. Qué NO cubre: cómo los agentes usan el token una vez emitido (eso es AS-03), ni el resto de la arquitectura de identidad (ver [`doc/identity/`](../identity/)).

**Estado:** **aprobado por el PM el 2026-10-29**, con las recomendaciones de la sección 7, e **implementado** el mismo día (rama `feat/AGENTE-fase4-token-kpi` de `traz-tools` y PR #48 de `traz-comp-dnato`). Cómo se instala: [`instalacion-token-y-metas.md`](instalacion-token-y-metas.md).
**Comparado contra:** `traz-comp-dnato` `origin/master` (producción) y `traz-tools` `develop-v3.5`.

---

## 1. Por qué hace falta

Los agentes tienen que trabajar **sin nadie conectado**: los avisos proactivos de Quirqui (una orden por vencer a las 7 de la mañana) y las mediciones periódicas de Kuntur corren desde un job. Hoy el agente consulta el MCP con el JWT **del usuario** que está chateando; un job no tiene usuario. Sin un token propio, esos jobs no pueden leer datos de la empresa (ADR-A3: los datos del cliente solo por MCP).

El PM eligió la opción A: **Dnato emite un JWT de máquina por `client_credentials`, un cliente por empresa**.

## 2. Cómo está hoy en producción (`master`)

| Pieza | Cómo funciona | Dónde |
|---|---|---|
| Emisión | Solo `grant_type=authorization_code` con PKCE S256. Un único `client_id` fijo: `trazalog-mcp-connector` ("fase 1: cliente único fijo") | `traz-comp-dnato/application/controllers/Oauth.php` (`token()`, `ALLOWED_CLIENT_ID`) |
| Contenido del JWT | RS256 con `kid`; `iss`, `aud` (`trazalog-mcp`), `exp` (TTL de `jwt_ttl`), `sub` (usernick), `azp` (fijo, de config), `email`, `empr_id`, `empr_id_mysql`, `role`, `userIdBpm`, `groupBpm` | `application/libraries/JwtIssuer.php` |
| Validación en el gateway | El APIM valida firma (JWKS de Dnato) e `iss`, **y valida suscripción por el claim `azp`**: tiene que ser el `consumerKey` de una aplicación del DevPortal suscripta a la API | [`doc/identity/apim-keymanager-dnato.md`](../identity/apim-keymanager-dnato.md) §4.1 |
| Identidad en el MI | La sequence `EmprIdFromHeader` saca el `empr_id` del backend JWT (`X-JWT-Assertion`) que firma el APIM (ADR-009) | `_backend/api/ToolsAPIProject/.../sequences/EmprIdFromHeader.xml` |
| Escrituras del MCP | `man_create_ot` (y `alm_crear_pedido_materiales`) usan **solo el `empr_id`** del token: no leen `sub`, `role` ni `userIdBpm` | `toolsMCPAPI.xml`, recurso `POST /mcp/man/ot` |

**Por qué quedó así:** la fase 1 de la identidad MCP resolvió el caso de un usuario conectado desde Claude.ai, con un cliente único y sin secretos que administrar ([`doc/identity/oauth-discovery-flow.md`](../identity/oauth-discovery-flow.md) §6.3). No había ningún proceso sin usuario que necesitara datos.

## 3. Qué cambia (propuesta)

### 3.1 En Dnato (`traz-comp-dnato`, PHP 5.6 estricto)

1. **Tabla nueva `oauth_client`** (en la base de Dnato, junto a la de los codes): `client_id`, `secret_hash` (bcrypt, nunca el secreto en claro), `empr_id`, `nombre`, `activo`, `fec_alta`, `fec_ultimo_uso`. Una fila por empresa con el agente habilitado.
2. **`Oauth::token()` acepta un segundo `grant_type`: `client_credentials`.** Rama nueva y separada: si es `authorization_code` sigue **exactamente** igual que hoy. Si es `client_credentials`: busca el cliente activo, verifica el secreto (`password_verify`), y emite un JWT con:

   | Claim | Valor | Por qué |
   |---|---|---|
   | `sub` | `agente:<client_id>` | Identifica que no es una persona |
   | `empr_id`, `empr_id_mysql` | Los de la empresa del cliente, **sacados de la tabla, nunca del pedido** | Regla de oro: el `empr_id` no es un parámetro |
   | `azp` | El mismo de hoy | Así el APIM lo acepta **sin cambios** (misma aplicación, misma suscripción) |
   | `token_tipo` | `maquina` | Para que el MI pueda rechazar escrituras (ver 3.2) |
   | `role` | vacío | No es un usuario de ningún nivel |
   | `userIdBpm`, `groupBpm` | vacíos | No actúa en Bonita |
   | `exp` | **15 minutos** (configurable aparte del TTL de usuarios) | Un token robado sirve poco tiempo |

3. **Metadata** (`authorization_server_metadata`): `grant_types_supported` suma `client_credentials`. `register_client` no cambia: el registro dinámico sigue siendo solo para conectores con usuario.
4. **Alta de clientes**: un comando o pantalla de administración que genere el `client_id` y el secreto **una sola vez** (se muestra y no se guarda en claro). Lo opera Trazalog al habilitar el agente para una empresa.

### 3.2 En el MI de Tools (core: `toolsMCPAPI.xml` y `EmprIdFromHeader`)

**Hallazgo:** hoy las escrituras del MCP solo miran el `empr_id`. Con un token de máquina, **quien tenga el secreto de una empresa podría crear OTs y pedidos de esa empresa** llamando al gateway directo. La lista blanca del orquestador (ADR-A8) no protege ese camino, porque no pasa por el orquestador.

**Propuesta:** `EmprIdFromHeader` también extrae `token_tipo`, y los dos recursos de escritura (`POST /mcp/man/ot`, `POST /mcp/alm/pedido`) responden **403** si es `maquina`, antes de tocar nada. Es una condición de una línea en cada recurso, y no cambia nada para los tokens de usuario.

Alternativa evaluada: **scopes del APIM por recurso** (el token de máquina sin el scope de escritura). Es más estándar, pero requiere configurar scopes en la API y verificar que el APIM 4.6 los lea del JWT de un emisor federado. Queda como mejora; la condición en el MI cierra el riesgo ya.

### 3.3 En el orquestador de los agentes (`traz-tools`, no es core)

- **Credenciales por empresa** en la base del agente: tabla `agente.credencial_empresa` (`empr_id`, `client_id`, `secreto` **cifrado** con `pgcrypto` y una clave que vive en una variable de entorno del orquestador, no en la base). RLS por empresa.
- **Caché del token** en memoria hasta un minuto antes de que venza.
- Los jobs (AS-03, mediciones) piden el token de la empresa y lo usan como `Authorization: Bearer`, igual que el de un usuario. **La lista blanca y el guardián siguen aplicando**.

## 4. Qué lo consume (todos los caminos)

| Quién | Usa | Qué le pasa con el cambio |
|---|---|---|
| Claude.ai y conectores MCP | `authorization_code` + PKCE | **Nada.** La rama no se toca |
| Chat de los agentes en Tools (E3) | `authorization_code` + PKCE, desde el servidor | **Nada** |
| Login web de Dnato y Tools | Sesión, no OAuth | **Nada** |
| APIM | Valida firma, `iss` y suscripción por `azp` | **Nada**: el token de máquina lleva el mismo `azp` y la misma firma |
| MI — lecturas | `empr_id` del backend JWT | **Nada**: el token de máquina trae `empr_id` |
| MI — escrituras | `empr_id` del backend JWT | **Cambia**: rechazan `token_tipo = maquina` (3.2) |
| Jobs de los agentes | — (hoy no existen) | **Nuevo** consumidor |

## 5. Qué se rompe si se hace mal

| Riesgo | Cómo se previene |
|---|---|
| Romper el login OAuth de Claude.ai | Rama separada por `grant_type`; tests Hurl de `authorization_code` corriendo **antes y después** contra DEV |
| Un token de máquina con el `empr_id` equivocado = **fuga entre empresas** | El `empr_id` sale **solo** de la fila del cliente. Test: un cliente de la empresa A no puede obtener un token de B, ni mandando `empr_id` en el pedido |
| Secreto filtrado = lectura completa de esa empresa | TTL de 15 min; `activo = false` revoca en el acto; secretos solo hasheados en Dnato y cifrados en el agente; `fec_ultimo_uso` para detectar uso raro |
| Secreto filtrado = **escritura** en esa empresa | La condición de 3.2 en el MI |
| El APIM rechaza el token (403 900908) | Mismo `azp` que los tokens de usuario; verificar en DEV antes de nada |

## 6. Cómo se prueba (antes de desplegar, en DEV con VPN)

1. Hurl del flujo actual (`tests/agente/oauth-dnato.hurl`) en verde **antes** de cambiar nada.
2. Tests nuevos: `client_credentials` con secreto correcto → JWT con `token_tipo=maquina`, `empr_id` de la tabla y `exp` de 15 min; secreto incorrecto, cliente inactivo o `empr_id` en el pedido → rechazo.
3. Con ese token: una lectura MCP (`man_get_equipos`) **pasa**; `man_create_ot` y `alm_crear_pedido_materiales` → **403**.
4. Hurl del flujo actual otra vez en verde.
5. Recién ahí, un solo despliegue.

## 7. Lo que necesito que decidas

1. **¿Aprobás el diseño?** (sección 3).
2. **¿La condición de las escrituras en el MI (3.2) va en el mismo cambio?** Recomiendo que sí: sin ella, el token de máquina abre la escritura a quien tenga el secreto.
3. **TTL de los tokens de máquina:** propongo 15 minutos.
4. **Quién da de alta los clientes y cómo** (comando de consola o pantalla de administración en Dnato). Recomiendo el comando: lo opera Trazalog y no suma pantallas a Dnato.
