# Pasaje a Producción — tools v2.4.15→develop · dnato v1.2.17.1→develop

## Objetivo

Qué es: el detalle de **qué agregar en `constants.php`** y **qué scripts de base de datos correr**
para llevar producción desde los tags actuales (tools `v2.4.15`, dnato `v1.2.17.1`) al estado de
`develop`. Para quién: quien haga el pasaje (PM). Cuándo leerlo: antes del pasaje, y para prepararlo.
Qué NO cubre: el deploy del código en sí (git/`deploytools.sh`), el `.car` de WSO2 (DataServices/APIs),
los procesos de Bonita, ni la infra. Esos van por su carril; acá está lo de **constants + BD**.

## ⚠️ Advertencia de alcance — leer primero

Es un salto grande (muchas versiones). Puntos delicados detectados:
- Varias constantes son **por-ambiente** (IDs de procesos Bonita, token de Bonita, `form_id` del
  formulario de registro, URLs). **NO se copian los valores de dev**: hay que poner los de PROD.
- Algunos scripts de BD son **iterativos** (se fueron corrigiendo en dev) o **seeds de datos de dev**
  que **NO** deben correr en prod. Están marcados abajo.
- No puedo ver el estado actual de la BD de prod. **Recomendación fuerte: probar todo esto primero en
  una copia de la base de prod**, y recién con eso OK, aplicarlo en prod.

---

## 1. Constants.php — el delta

> El deploy **preserva** `constants.php` de cada ambiente, así que estas constantes nuevas se agregan
> **A MANO** en el `constants.php` de prod. No reiniciar nada (es PHP).
> **Excluidas a pedido del PM:** todo lo de **sicpoa** (`SICP`, `REST_SICP`, `API_SICP`), lo de
> **Bonita** (`BPM_*` — ya están en prod y no cambian) y la **báscula** (`API_BASCULA`).
> `⚠` marca las que tienen valor **por-ambiente**: no copiar el de dev, poner el de PROD.

### 1.1 tools — agregar en `application/config/constants.php`
```php
define('URL_AYUDA', 'ayuda/');                     // ruta de la ayuda (relativa; o URL absoluta a un sitio externo)
define('PLANIF_AVANZA_TAREA', true);               // planificador de tareas: si la tarea avanza automáticamente
define('NOTI', 'traz-comp-notificaciones/');       // prefijo del módulo Notificaciones
define('MAN', 'traz-tools-man/');                  // prefijo del módulo Mantenimiento
define('PRO_STD', 'PROCESO-STANDAR');              // nombre del proceso "pedido de trabajo" estándar
define('DT_SIZE_ROWS', false);                     // filas por página de los datatables (false = default del sistema)
define('dias_vencimiento', 30);                    // Pañol: días de aviso previo al vencimiento de certificados
define('REST_KPI', HOST.'/services/ToolsKPIDataService');  // DataService de KPIs del Tablero del Administrador
define('EMPRESAS_FORM', 1);                        // ⚠ empr_id(s) que ven los formularios de mantenimiento autónomo — usar el/los de PROD

// --- Módulo Residuos (agregar SOLO si este ambiente usa Residuos) ---
define('RESI', 'traz-tools-resi/');                // prefijo del módulo Residuos
define('REST_RESI', HOST.'/services/semaresiduosDS');          // DataService de Residuos
define('REST_RESI2', HOST.'/services/semaresiduosDS2');        // DataService de Residuos (2)
define('REST_PRD_RESI', HOST.'/services/sema/PRDDataService'); // DataService de producción de Residuos
define('EMPRESAS_RESI_ADMIN', json_encode([1]));   // ⚠ empr_id(s) autorizadas al ABM de transportistas — usar el/los de PROD
define('TIPOS_VEHICULOS_TOLVA', 999);              // id de tabla para camiones con tolva/contenedor
```

### 1.2 dnato — agregar en `application/config/constants.php`
```php
define('FRM', 'traz-comp-formularios/');           // prefijo del módulo Formularios (usado por el registro)
define('API_URL', HOST . '/tools/log');            // endpoint de logging
define('COREDataService_URL', $wso2_base . '/services/COREDataService');  // COREDataService (usa la var $wso2_base ya definida; si no existe, usar HOST)
define('REST_CORE_PAISES', REST_CORE . '/tablas/paises_registracion');    // países habilitados en el combo de la registración
define('LOGIN_MOSTRAR_REGISTRO', FALSE);           // banner/links de "Crear cuenta gratis" en el login: FALSE = ocultos (registración pública off), TRUE = visibles. Si NO se define, asume TRUE. Para prod sin registración: FALSE.

// --- Registración: imágenes (los archivos deben existir en public/img/ de prod) ---
define('REGISTER_IMG_LOGO', 'public/img/toolsgrey.png');            // logo en el header del registro
define('REGISTER_IMG_BACKGROUND', 'public/img/toolsregister.jpg');  // imagen del panel derecho (registro)
define('REGISTER_IMG_COMPLETE_PASSWORD', 'public/img/toolschangepass.jpg'); // pantalla de crear contraseña
define('REGISTER_IMG_FORMULARIO', 'public/img/toolsform.jpg');      // pantalla del formulario de registro
define('REGISTER_IMG_CREAR_EMPRESA', 'public/img/toolscreaempr.jpg'); // pantalla de alta de empresa
define('REGISTER_IMG_BIENVENIDA', 'public/img/toolsbienvenida.jpg'); // pantalla de bienvenida
define('REGISTER_IMG_EMAIL_LOGO', 'public/img/logotzl.png');        // logo en los mails de registro
define('LOGIN_IMG_LOGO', 'public/img/logotzl.png');                 // logo del login/recuperar/reset
define('LOGIN_IMG_BACKGROUND', 'public/img/toolslogin.jpg');        // imagen del panel derecho (login)

// --- Registración: valores por defecto del alta de empresa ---
define('REGISTRACION_ESTABLECIMIENTO_DEFAULT_NOMBRE', 'Establecimiento Principal'); // establecimiento que se crea en el alta
define('REGISTRACION_DEPOSITO_DEFAULT_NOMBRE', 'Deposito 1');        // depósito por defecto (nombre)
define('REGISTRACION_DEPOSITO_DEFAULT_DESCRIPCION', 'Depósito 1');   // depósito por defecto (descripción)
define('REGISTRACION_DEPOSITO_DEFAULT_ENCARGADO_ALIAS', 'almacen');  // alias del usuario encargado del depósito

// --- Registración: validación de email corporativo vs webmail ---
define('WEBMAIL_DOMAINS_CSV', 'gmail.com,googlemail.com,...');  // CSV de dominios de webmail (copiar el CSV COMPLETO de develop)

// --- Carga masiva (bulk load) ---
define('BULKLOAD_STAGING_DIR', FCPATH . 'bulkload_stage_files');    // carpeta temporal de archivos de carga masiva
define('BULKLOAD_MAX_FILE_SIZE', 10 * 1024 * 1024);                 // tamaño máx. del archivo (10 MB)
define('BULKLOAD_ALLOWED_EXTENSIONS', 'xlsx,xls');                  // extensiones permitidas
define('BULKLOAD_TIMEOUT', 60);                                     // timeout de procesamiento (segundos)

// --- OAuth (opcional) ---
define('DNATO_OAUTH_ISSUER', '');                  // '' = OAuth desactivado (ver §2.3, tabla seg.oauth_codes)
```
**Bloques multilínea (copiar el bloque COMPLETO desde `develop`, con su comentario):**
- `WEBMAIL_DOMAINS` (array) — misma lista de webmail en formato array.
- `CAMPOS_USUARIO_ADICIONALES` (array) — campos extra del formulario de usuario.
- `ALTA_EMPRESA_ROLES_EXTRA` (array) — roles extra a crear además de los 12 base, en el alta de empresa.
- `ALTA_EMPRESA_ACTORES_EXTRA` (array) — actores/membership extra a crear en el alta de empresa.
- `REGISTRACION_USUARIOS_DEFAULT_JSON` (JSON) — usuarios iniciales que se crean con la empresa.

**⚠️ Por-ambiente (revisar/ajustar para PROD, NO copiar el de dev):**
```php
define('DNATO', 'http://localhost/traz-comp-dnato/main/users');  // ⚠ URL base de dnato — verificar host de prod
define('FORMULARIO_REGISTRO_ID', 72);              // ⚠ form_id REAL del formulario de registro en prod (ver §2.3; probablemente NO sea 72)
define('REGISTER_TEMP_EMPR_ID', '9000');           // empresa plantilla temporal del alta; confirmar que exista en prod
define('REGISTRACION_PASSWORD_DEFAULT', '12345');  // ⚠ clave inicial de los usuarios creados en el alta; confirmar política
```

> **Módulo Residuos en dnato:** si el ambiente usa Residuos, agregar también
> `define('REST_RESI', HOST . '/services/semaresiduosDS');` en dnato. Si no, omitir.

---

## 2. Base de datos

> **Dos motores:** PostgreSQL **core** (compartido por tools y dnato, vía WSO2) y **MariaDB de
> AssetPlanner**. Los scripts dicen contra cuál corren. Correr **conectado a la base del ambiente de
> prod** (por SSH al server + `psql`/`mysql`, o por DBeaver). Todos, primero en una **copia de prod**.

### 2.1 tools — PostgreSQL core  *(en orden)*
| Script (en el repo traz-tools) | Qué hace | Notas |
|---|---|---|
| `_backend/database/scripts/versiones/v2.8.1.3/configuracion_inicial_empresa_trg_func.sql` | Actualiza el SP de alta de empresa: clona el formulario "Entrega Materiales" de la empresa 9000. | `CREATE OR REPLACE`. Requiere que exista la 9000 con ese formulario. |
| `_backend/database/scripts/versiones/v2.8.1.4/kpi_cache_engine.sql` | Motor de caché de KPIs (schema `kpi.*` + funciones). | Idempotente. |
| `_backend/database/scripts/versiones/v2.8.1.4/kpi_definiciones.sql` | Registra los 3 KPIs de ALM/HER. | Idempotente (ON CONFLICT). |
| `_backend/database/scripts/geo-paises-hispanohablantes.sql` | **Opcional.** Normaliza países/divisiones/localidades (27k filas). | Idempotente y no destructivo. Correr solo si se quiere el geo completo. |

Después: `select kpi.correr();` (primera carga) y programar el **cron** (ver §3).

### 2.2 tools — AssetPlanner (MariaDB)
| Script | Qué hace | Notas |
|---|---|---|
| `_backend/database/scripts/assetplanner/kpi-disponibilidad.sql` | Registra el KPI `getDisponibilidad` en `kpi_queries_a_cachear` + asegura el event `kpi_correr_cache`. | Requiere que ya exista el mecanismo kpi (procedure) en la Asset de prod (existe en prod). `event_scheduler=ON`. |
| `_backend/database/scripts/asset-sisusers-hashear-passwords.sql` | **One-off correctivo:** hashea contraseñas que quedaron en texto plano en `sisusers` (issue #489). | Correr **solo si** hay usuarios afectados en prod (revisar antes). |

Después: `CALL kpi_calcular_queries_cacheados();` (primera carga de la caché de MAN).

### 2.3 dnato — PostgreSQL core
| Script (repo traz-comp-dnato) | Qué hace | Notas |
|---|---|---|
| `scripts/modificar_tabla_usuarios.sql` | `ALTER TABLE seg.users ADD COLUMN reg_info_id`. | Necesario. Verificar que la columna no exista ya. |
| `development/sp_insert_usuario_con_hash_con_imagen.sql` | SP `seg.insert_usuario_con_hash` (PBKDF2-SHA256, compatible con `Password.php`). | Requiere `CREATE EXTENSION IF NOT EXISTS pgcrypto;`. `CREATE OR REPLACE`. |
| `doc/identity/migrations/001_create_seg_oauth_codes.sql` | Crea `seg.oauth_codes` (codes de un solo uso, OAuth 2.1 + PKCE, E9-IDENT-03). | **Solo si se usa OAuth.** Con `DNATO_OAUTH_ISSUER=''` (off) es opcional. |
| **Formulario de registro** (`scripts/crear_formulario_registro.sql`, `formulario_registro_usuario.sql`, `corregir_formulario_registro.sql`, `corregir_valo_id.sql`) | Crean el formulario de registro (4 preguntas) + sus items/valores. | **⚠️ NO correr en cadena tal cual:** son iterativos y **hardcodean `form_id=1` y `72`**. En prod el `form_id` lo asigna el serial → hay que **crear el form, ver qué `form_id` quedó, y setear `FORMULARIO_REGISTRO_ID` a ese número** (ver §1.2). Recomiendo **consolidarlos en un script limpio** (te lo armo, ver §5). |

### 2.4 dnato — AssetPlanner (MariaDB)
| Script | Qué hace | Notas |
|---|---|---|
| `development/sql/asset-empresa-trigger.sql` | Trigger de alta de empresa en Asset (crea grupos/acciones). | Correr si la Asset de prod aún no lo tiene (verificar). |
| `development/sql/asset-createEmpresaGroupsAndActions.sql` | **⚠️ NO CORRER EN PROD.** Tiene INSERTs con **empresas concretas de DEV** (id 17 "Tierras_de_Capayan_Lama", etc.). Es seed de dev, no migración. | Omitir. |
| `development/verificar_md5_assetplanner.sql` | Solo verificación (SELECT). | Opcional, para chequear. |

### 2.5 Carga Masiva (bulkload) multi-motor — ⚠️ feature grande, review dedicada
Las constantes `BULKLOAD_*` (§1.2) pertenecen a este feature, que trae **su propio set de scripts** (no
estaba en versiones anteriores de este doc). **Solo aplica si el ambiente va a usar Carga Masiva.** Tiene
dependencias cruzadas (dnato + tools) y lado MariaDB; conviene revisarlo aparte antes de prod.
| Script | Motor / repo | Qué hace |
|---|---|---|
| `scripts/sql/despliegue/2026-09-carga-masiva-multimotor.sql` | PostgreSQL · dnato | **Script consolidado de despliegue** (el que se corre en DEMO/PROD): deja `core`+`sta` listos para despachar entidades a PostgreSQL o MariaDB. |
| `scripts/sql/sta/2026-08-agregar-motor-bd.sql` | PostgreSQL · dnato | **Prerequisito** del consolidado (agrega la columna `motor_bd`). |
| `scripts/sql/2026-08-core-empresas-empr-id-mysql.sql` | PostgreSQL · **tools** | Agrega `core.empresas.empr_id_mysql` (lo usa carga masiva contra MariaDB **y** el KPI de MAN del tablero). Verificar si prod ya lo tiene. |
| `scripts/menu/insert_bulkload_menu.sql` | PostgreSQL · dnato | Inserta la opción de menú "Carga Masiva" (`seg.menues`). |
| `scripts/sql/mariadb/fase0-verificar-entorno.sql` + `scripts/sql/sta/*` | **MariaDB** · dnato | Objetos del esquema `sta` en la MariaDB del ambiente (lado que el consolidado NO cubre — ver sección "QUÉ FALTA DESPUÉS DE ESTO" dentro del propio script consolidado). |

> Recomendación: tratar Carga Masiva como un **sub-pasaje propio**. Si querés, armo una guía dedicada
> siguiendo el orden que indica el encabezado del script consolidado (§"QUÉ FALTA DESPUÉS DE ESTO").

---

## 3. Post-scripts (no son SQL de esquema pero completan la BD)
- **Cron KPI (Postgres, server de prod):** `*/5 * * * *` corriendo `select kpi.correr();` (como el
  usuario `postgres` por socket, o `kpi_cron` — ver `doc/despliegue/dashboard-administrador-despliegue.md`).
- **Event AssetPlanner:** dejar `kpi_correr_cache` **ENABLED** (en prod ya suele estarlo).
- **DataServices / APIs (WSO2):** el `.car` (rebuild `./mvnw clean install` + deploy) trae
  `ToolsKPIDataService` (nuevo) y `COREDataService` (query `getEsAdminXEmailEmpresa` nueva). Sin eso,
  el tablero no trae KPIs ni detecta admin. Va por el deploy, no es un script de BD.

---

## 3-bis. ⚠️ Artefactos Synapse duplicados (el deploy NO borra lo viejo)
El `deploytools.sh` **copia pero no borra**. Si un artefacto se **renombró** en el repo (p.ej.
`toolsFault.xml` → `toolsFaultSequence.xml`, ambos con `name="toolsFault"`), el archivo viejo queda en
el server y choca con el nuevo → **"Duplicate resource definition"** → se faultea el synapse-config y se
caen servicios (en demo se cayó `COREDataService`: desapareció el logo y el menú).

**Prevención — correr SIEMPRE después del deploy de WSO2 y ANTES de reiniciar** (en el server):
```
sh traz-tools/scripts/deploy/verificar-artefactos-duplicados.sh \
   /usr/lib64/wso2/wso2ei/6.5.0 \
   traz-tools/_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts
```
Lista los `name` declarados por más de un archivo en `sequences/` y `api/`, y marca cuál **NO está en el
repo** (ese es el leftover a borrar). Devuelve código 1 si hay duplicados (sirve para cortar un deploy
automatizado). Borrar el viejo y recién ahí reiniciar WSO2.

**Leftover conocido para ESTE pasaje:** borrar en prod
`…/synapse-configs/default/sequences/toolsFault.xml` (queda `toolsFaultSequence.xml`, mismo `name`).

## 4. Orden sugerido del pasaje
1. **Copia de prod** (BD Postgres + Asset) y probar TODO esto ahí primero.
2. Código: deploy de tools y dnato (rama/tag a prod).
3. `constants.php` de prod: agregar §1.1 (tools) y §1.2 (dnato), con los valores por-ambiente de prod.
4. BD Postgres core: §2.1 + §2.3.
5. BD AssetPlanner: §2.2 + §2.4.
6. `.car` WSO2 (DataServices/APIs) + cron KPI + event Asset (§3).
7. **Verificar artefactos duplicados (§3-bis)** y borrar leftovers, ANTES de reiniciar WSO2.
8. Reiniciar WSO2 (si hace falta) y verificar el log sin "Duplicate resource definition".
9. Verificar: login/registración, alta de empresa, y el tablero del Admin (4 KPIs).

## 5. Pendiente de confirmar / que te puedo armar
Para dejar esto 100% cerrado necesito un par de datos del estado de prod (o de una copia):
- ¿Prod ya tiene el **formulario de registro** creado? ¿Con qué `form_id`? → para consolidar los 4
  scripts del form en **uno limpio e idempotente** y fijar `FORMULARIO_REGISTRO_ID`.
- ¿La **Asset de prod** ya tiene el trigger de alta de empresa y el mecanismo `kpi_*`? (para saber si
  §2.4 trigger y §2.2 aplican o ya están).
- Los **IDs de procesos de Bonita** de prod (para `BPM_PROCESS_ID_*`) y el **token de Bonita** de prod
  (`BPM_SESSION_FALLBACK`).
Con esos datos te dejo los scripts finales consolidados y los valores exactos de las constantes
por-ambiente. Decime y lo cierro.
