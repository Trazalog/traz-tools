# Permiso propio de los agentes y metas de indicadores — cómo se instala y se verifica

## Objetivo

Procedimiento para poner en marcha, en un ambiente, las dos piezas que Kuntur necesita antes de existir: el **token de máquina** de los agentes (Dnato emite un permiso por empresa para correr sin un usuario conectado, ADR-A10) y la **historia, metas y desvíos de los KPIs** (ADR-A9). Está escrito para el PM o quien despliegue y se sigue leyendo solo este archivo, en orden. No explica por qué se diseñó así: eso está en [`analisis-impacto-token-maquina.md`](analisis-impacto-token-maquina.md) y [`analisis-impacto-kpi-objetivos.md`](analisis-impacto-kpi-objetivos.md). Los avisos (campanita y push) tienen su propio procedimiento: [`../notificaciones/instalacion-avisos.md`](../notificaciones/instalacion-avisos.md).

- **Probado:** todo en la máquina de desarrollo, el 2026-10-29: PostgreSQL 11 (12 pruebas del motor), un MI 4.5.0 aparte apuntando solo a bases locales (recursos del DataService y de `toolsMCPAPI`), Tools en PHP 7.3 contra ese MI (pantalla de metas, 12 controles en navegador) y `JwtIssuer` en PHP 5.6 (10 controles).
- **No probado:** contra DEV ni el APIM (el pedido real a Dnato, la publicación de las tools nuevas).

---

## 0. Antes de empezar

| Qué | Dónde se consigue |
|---|---|
| Acceso `psql` a la base de Tools con el usuario dueño de los esquemas `kpi` y `seg` | El servidor de base del ambiente |
| El código de Dnato con el PR `traz-comp-dnato#48` y el de Tools con la rama `feat/AGENTE-fase4-token-kpi` | GitHub, después del merge |
| El CAR de `ToolsAPIProject` compilado con esa rama | Terminal local de la máquina de build (`mvn clean install`) |
| Acceso al Publisher del APIM | `https://<apim>:9443/publisher` |
| Acceso a la base de los agentes y al entorno del orquestador | El servidor del orquestador |

**Orden:** base de Tools → Dnato → MI → APIM → agentes → Tools (PHP) → Kuntur. Cada paso se puede verificar antes de seguir.

---

## 1. Base de Tools

**Dónde:** terminal con `psql` conectada a la base de Tools del ambiente, parado en la raíz del repo `traz-tools`.

```bash
psql -h <host-base> -U <usuario-dueño> -d <base-tools> -v ON_ERROR_STOP=1 \
  -f _backend/database/scripts/versiones/v2.8.1.6/kpi_objetivos.sql
```

Crea `kpi.historico` y `kpi.objetivos`, las funciones `kpi.objetivos_de`, `kpi.desvios`, `kpi.objetivo_guardar` y `kpi.objetivo_cancelar`, y **reemplaza `kpi.publicar()`** por una que además guarda la historia del día. Lo que lee el Tablero (`kpi.cache`) no cambia.

Verificar que la próxima corrida del cron (cada 5 minutos) llena la historia:

```bash
psql -h <host-base> -U <usuario-dueño> -d <base-tools> \
  -c "select nombre, count(*), max(fecha) from kpi.historico group by nombre"
```

Si no aparece nada después de 5 minutos, mirar el log del motor:

```bash
psql -h <host-base> -U <usuario-dueño> -d <base-tools> \
  -c "select * from kpi.event_log where nombre = 'kpi.historico' order by id desc limit 5"
```

**Vuelta atrás:** `_backend/database/scripts/versiones/v2.8.1.6/kpi_objetivos.rollback.sql` (devuelve `kpi.publicar()` a la versión anterior; **la historia y las metas cargadas se pierden**).

---

## 2. Dnato: clientes de máquina

### 2.1 La tabla

**Dónde:** terminal con `psql` a la base de Dnato (la del esquema `seg`), parado en la raíz del repo `traz-comp-dnato`.

```bash
psql -h <host-base> -U <usuario-dueño> -d <base-dnato> -v ON_ERROR_STOP=1 \
  -f doc/identity/migrations/002_create_seg_oauth_clients.sql
```

### 2.2 El código

**Dónde:** el despliegue habitual de Dnato. Va con el código del PR #48: `application/controllers/Oauth.php`, `Cli.php`, `application/models/OauthClient_model.php`, `application/libraries/JwtIssuer.php` y `application/config/jwt.php`.

Verificar en el navegador o con `curl`, desde cualquier terminal:

```bash
curl -s https://<dnato>/oauth/.well-known/oauth-authorization-server
```

Tiene que decir `"grant_types_supported":["authorization_code","client_credentials"]`.

**Antes y después de este paso**, el login de Claude.ai y el chat de los agentes tienen que seguir andando (es la rama que no se tocó). Con un usuario cualquiera, conectarse a Trazalog desde Claude.ai.

### 2.3 Dar de alta el cliente de una empresa

**Dónde:** terminal en el servidor de Dnato, parado en la carpeta de Dnato.

```bash
php index.php cli oauth_cliente_alta <empr_id> "Agentes de <nombre de la empresa>"
```

Imprime el `client_id` y el **secreto, una sola vez**. Copiarlos en ese momento para el paso 5. Para revocar: `php index.php cli oauth_cliente_baja <client_id>`. Para ver los que hay: `php index.php cli oauth_cliente_lista`.

### 2.4 Verificar el token

**Dónde:** cualquier terminal.

```bash
curl -s -X POST https://<dnato>/oauth/token \
  -d grant_type=client_credentials \
  -d client_id=<client_id> \
  -d client_secret=<secreto>
```

Tiene que devolver `access_token` y `"expires_in":900`. Con un secreto inventado tiene que devolver `invalid_client` (401). Agregando `-d empr_id=1` tiene que devolver `invalid_request` (400): la empresa no se pide, sale del cliente.

---

## 3. Micro Integrator

**Dónde:** el servidor del MI del ambiente, carpeta `carbonapps`.

Desplegar el CAR nuevo. Trae:

- `ToolsKPIDataService` con cinco recursos más (`/historico/…`, `/objetivos/…`, `/desvios/…`, `POST /objetivo`, `PUT /objetivo/cancelar`). Los tres de antes (`/kpi/…`, `/kpis/…`, `/man/…`) no cambian.
- `toolsMCPAPI` con `GET /mcp/kpi/valor`, `/mcp/kpi/historico`, `/mcp/kpi/objetivos` y `/mcp/kpi/desvios`.
- La secuencia `rechazarTokenMaquina`: `POST /mcp/man/ot` y `POST /mcp/alm/pedido` responden **403** con un token de máquina.

**Ojo:** si alguna fuente de datos del CAR no conecta, el MI revierte el CAR completo. Verificar las conexiones del ambiente antes.

Verificar, en una terminal con acceso al MI:

```bash
curl -s -H 'Accept: application/json' \
  http://<mi>:8290/services/ToolsKPIDataService/objetivos/emprid/<empr_id>
```

Tiene que devolver `{"objetivos":{}}` (o la lista, si ya hay metas).

---

## 4. API Manager

**Dónde:** Publisher del APIM.

En la API unificada de operaciones (la que genera el servidor MCP), sumar las cuatro operaciones `GET /mcp/kpi/valor`, `/mcp/kpi/historico`, `/mcp/kpi/objetivos` y `/mcp/kpi/desvios`, tal como están en `doc/api/trazalog-operaciones.yaml` (etiqueta "Indicadores"). Republicar y regenerar el servidor MCP para que aparezcan como tools.

Verificar que el token de máquina del paso 2.4 pasa por el gateway: una lectura (`man_get_equipos`) tiene que andar y `man_create_ot` tiene que dar 403.

---

## 5. Agentes

**Dónde:** terminal en el servidor del orquestador, parado en la raíz del repo `traz-tools`.

1. Catalogar las tools nuevas en la base de los agentes:

```bash
psql -h <host-agente> -U <usuario-dueño> -d <base-agente> -v ON_ERROR_STOP=1 \
  -f db/agente/022-tools-kpi.sql
```

2. En el entorno del orquestador, `AGENTE_DNATO_TOKEN_URL` = `https://<dnato>/oauth/token` y `AGENTE_CLAVE_CREDENCIALES` = una clave larga al azar (ver `doc/agente/operacion.md`).
3. Cargar la credencial de cada empresa (pide el secreto del paso 2.3 por teclado):

```bash
python -m agente.credenciales alta --empresa <empr_id> --client-id <client_id>
```

---

## 6. Tools (PHP)

**Dónde:** el despliegue habitual de Tools.

Va con el código: `application/controllers/Objetivos.php`, `application/models/Objetivos_model.php`, `application/views/dashboard/objetivos.php`, `application/views/dashboard/admin_dashboard.php` y `lib/props/objetivos.js`.

Verificar con un **administrador** de la empresa: en el Tablero, debajo de los indicadores, aparece la tarjeta **Metas**. Cargar una meta, ver que aparece con el valor de hoy y si se cumple, y cancelarla. Con un usuario que **no** es administrador, la tarjeta dice "Solo el administrador de la empresa ve las metas".

---

## 7. Kuntur: charla de metas y avisos

Requiere los pasos 1 a 6. Lo que se activa acá está explicado para el usuario en [`operacion.md`](operacion.md), sección "Kuntur: metas y avisos al administrador".

### 7.1 Activar a Kuntur

**Dónde:** terminal en el servidor del orquestador, parado en la raíz del repo `traz-tools`.

```bash
psql -h <host-agente> -U <usuario-dueño> -d <base-agente> -v ON_ERROR_STOP=1 \
  -f db/agente/023-kuntur-metas.sql
```

Reiniciar el orquestador para que tome el código nuevo (`agente/metas.py`, `agente/coach.py` y los cambios de `agente/orquestador.py` y `agente/api.py`), y desplegar en Tools el panel nuevo: `application/modules/traz-comp-agente/views/panel.php`, `controllers/Agente.php` y `models/Agentes.php`.

Verificar con un **administrador**: en el panel del agente aparecen las pestañas **Quirqui** y **Kuntur**. Pedirle a Kuntur "quiero bajar los artículos bajo punto de pedido": tiene que mirar el valor de hoy y, cuando acuerden, mostrar una tarjeta "Meta propuesta" con el botón **Cargar meta**. Al tocarlo, la meta aparece en la tarjeta Metas del Tablero con la etiqueta "Kuntur". Con un usuario que **no** es administrador, el panel no muestra pestañas.

**Vuelta atrás:** `db/agente/023-kuntur-metas.rollback.sql` (Kuntur queda inactivo; las metas ya cargadas siguen).

### 7.2 Programar el seguimiento de metas

**Dónde:** crontab del usuario del orquestador, en el servidor del orquestador.

```
0 8 * * * cd /ruta/a/traz-tools && .venv-agente/bin/python -m agente.coach >> /var/log/agente-coach.log 2>&1
```

Verificar a mano, en la terminal del servidor del orquestador parado en el repo, con una meta que hoy no se cumpla:

```bash
.venv-agente/bin/python -m agente.coach --empresa <empr_id>
```

Tiene que imprimir una línea con `"desvios": 1` y `"avisos": 1`, y a quien cargó la meta le tiene que llegar a la campanita "No se cumple la meta: …", firmado por Kuntur. Corrido otra vez la misma semana, no se repite.
