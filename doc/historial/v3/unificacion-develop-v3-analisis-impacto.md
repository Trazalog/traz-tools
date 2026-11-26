# Unificar `develop-v3` con `develop` — análisis de impacto

## Objetivo

Medir qué pasa si se mergea `develop-v3` en `develop`, en **traz-tools** y en **traz-comp-dnato**,
antes de hacerlo. Está escrito para decidir si se avanza y con qué recaudos, y para ejecutar el
merge cuando se decida. **No cubre** el paso siguiente (`develop` → `master`), que es el cutover a
producción y necesita su propia validación.

| | |
|---|---|
| **Fecha del análisis** | 2026-08-25 |
| **Ramas comparadas** | `origin/develop` vs `origin/develop-v3`, ambas recién fetcheadas |
| **Método** | `git merge-tree` — simulación real del merge, sin tocar ningún working tree |
| **Veredicto** | Bajo riesgo textual. El riesgo real es de **despliegue**, no de código |

---

## 1. Resumen

La hipótesis de partida —"v3 solo agregó cosas, no tocó lo existente"— **se confirma en el código**,
con una salvedad importante: `develop` no se quedó quieto. Siguió recibiendo trabajo de v2 en
paralelo (27 commits en traz-tools, 7 en dnato desde el 29-abr), y ahí es donde puede haber roce.

| | traz-tools | traz-comp-dnato |
|---|---|---|
| Commits solo en `develop` (v2) | 27 | 7 |
| Commits solo en `develop-v3` | 61 | 12 |
| Archivos tocados por v2 | 12 | 10 |
| Archivos tocados por v3 | 311 | 46 |
| **Archivos tocados por AMBOS** | **3** | **0** |
| **Conflictos reales al mergear** | **1** | **ninguno** |

**dnato mergea limpio.** En **traz-tools** hay **un solo conflicto**, y es benigno.

Del lado del código de aplicación, el impacto es mínimo: de los 311 archivos que v3 aporta en
traz-tools, **uno solo es código PHP existente** (`BPM.php`, un límite de 10 a 100). Cero cambios en
`application/config/`. Cero cambios en dependencias. El resto es documentación (68), tests de
doctest (143), scripts de desarrollo (49), infraestructura nueva (8) y artefactos WSO2 (24).

Lo que sí hay que mirar son **cuatro cambios de infraestructura** que no se ven en el diff como
riesgo pero que rompen al desplegar. Están en la sección 3.

---

## 2. El único conflicto: `_backend/api/dataservice/ALMDataService.dbs`

Es el DataService del EI (el de v2). Ambas ramas le agregaron queries **en el mismo punto del
archivo**, sin tocar lo del otro:

| | Queries que agrega |
|---|---|
| **v2** (`develop`) | `getStockPaginado`, `totalPaginadoStock`, `getHistoricoMovimientosPaginado`, `getEntregaxBatch`, `getMovimientosInternosPaginado`, `getAjustePaginado` |
| **v3** (`develop-v3`) | `getPedidosMaterialesEmpresa`, `setCaseIdPedido`, `deletePedido`, `getDepositosMcp`, `getPedidoPorOrden`, `setPedidoOrden`, `setEstadoPedido` |

**Ningún nombre se pisa** (verificado). La resolución es **conservar los dos bloques**, uno detrás
del otro. No hay que elegir.

> Nota al margen: el archivo ya tiene `extraerCantidadLote` definido **dos veces**, en las dos ramas
> por igual. Es un duplicado preexistente, no lo introduce el merge — pero conviene limpiarlo
> aparte.

Los otros dos archivos compartidos **git los fusiona solo, y bien**:

- `application/libraries/BPM.php` — v3 sube un límite de paginación (`c=10` → `c=100`) y v2 agrega
  un método nuevo (`getTodoListPaginado`). Independientes.
- `.../ToolsAPIProject/.../ALMDataService.dbs` — v2 agrega `getHistoricoMovimientosPaginado`, v3
  agrega las queries MCP. Independientes.

---

## 3. Los riesgos reales — todos de despliegue, ninguno de código

Estos cambios mergean sin conflicto, pero cambian **cómo se conecta o arranca el sistema**. Son los
que hay que verificar antes de desplegar lo mergeado.

### 3.1 🔴 traz-tools — cambia el driver JDBC de MySQL

`_backend/api/ToolsAPIProject/.../data-sources/AssetPlannerDataSource.xml`:

```diff
- <driverClassName>com.mysql.jdbc.Driver</driverClassName>
+ <driverClassName>com.mysql.cj.jdbc.Driver</driverClassName>
- <url>jdbc:mysql://10.142.0.13:3306/assetv2</url>
+ <url>jdbc:mysql://10.142.0.13:3306/assetv2?useSSL=false&allowPublicKeyRetrieval=true&useUnicode=true&characterEncoding=UTF-8</url>
```

`com.mysql.cj.jdbc.Driver` es Connector/J **8.x**. El driver viejo es 5.x. **Si el WSO2 donde se
despliegue tiene solo el 5.x, el datasource no levanta** y todo lo que dependa de `assetv2` deja de
responder.

**Verificar antes de desplegar** — por SSH al server WSO2 de v2:

```bash
ls -la $WSO2_HOME/repository/components/lib/ | grep -i mysql
```

Si aparece `mysql-connector-java-5.*`, hay que sumar el 8.x antes de aplicar el merge en ese server.

> Aparte: ese archivo tiene la IP `10.142.0.13` (base de **desarrollo**) hardcodeada, en las dos
> ramas por igual. No lo empeora el merge, pero significa que el `.xml` versionado no sirve tal cual
> para otro ambiente.

### 3.2 🟡 traz-tools — renombre de datasource en tres DataServices

`ProduccionDataService.dbs`, `TARDataService.dbs` y `TareasSTD.dbs` cambian todas sus referencias
de `produccionDS` a `ToolsDataSource` (33, 42 y 31 referencias respectivamente).

**Está bien**: `ToolsDataSource.xml` existe en el mismo proyecto, así que el renombre es
autoconsistente. El riesgo es solo si el server de destino tiene un datasource `produccionDS`
declarado a mano por fuera del proyecto y algo más lo usa.

**Verificar**: que en el server no quede nada apuntando a `produccionDS` después del merge.

### 3.3 🟡 traz-tools — fix de motor JS específico de MI v3

`toolsBPMAPI.xml` reemplaza `mc.setPayloadJSON(...)` por un `payloadFactory`, con este motivo
declarado en el propio archivo:

> *el motor JS del MI v3 es GraalVM, donde `mc.setPayloadJSON(JSON.stringify(obj))` envuelve el JSON
> como string-literal → "Error creating JSON Payload"*

El fix es correcto para MI 4.5 (GraalVM). **Si el WSO2 de v2 usa un motor JS distinto** (Rhino /
Nashorn en EI), hay que confirmar que el `payloadFactory` se comporte igual ahí. No es que rompa
seguro: es que el fix se escribió para otro runtime.

**Verificar**: probar el flujo de BPM que pasa por `toolsBPMAPI` en el ambiente de v2.

### 3.4 🔴 dnato — se borra el `.htaccess`

El commit de OAuth (`999d9a6`) **elimina el `.htaccess`**, que contenía las rewrite rules estándar
de CodeIgniter:

```apache
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^(.+)$ index.php/$1 [L]
```

**Si el Apache que sirve dnato no tiene esas reglas en el vhost, al mergear se rompen todas las URLs
limpias** — todo pasaría a necesitar `index.php/` adelante. Es el riesgo más concreto de este merge.

**Verificar antes** — por SSH al server de dnato:

```bash
grep -rn "RewriteRule" /etc/apache2/sites-enabled/ /etc/httpd/conf.d/ 2>/dev/null
```

Si no aparecen las reglas ahí, **restaurar el `.htaccess`** en el merge en vez de aceptar el borrado.

### 3.5 🟡 dnato — `composer_autoload` pasa a exigir `vendor/`

`application/config/config.php`:

```diff
- $config['composer_autoload'] = FALSE;
+ $config['composer_autoload'] = FCPATH . 'vendor/autoload.php';
```

`vendor/` **no está versionado**, y `composer.json` requiere `firebase/php-jwt ^5.5`.

CodeIgniter 3 no muere si el archivo no existe (loguea el error y sigue), así que dnato **arranca
igual**. Lo que falla es todo lo que use JWT, o sea las pantallas OAuth nuevas. Para el resto de
dnato es inocuo.

**Acción**: correr `composer install` en el server de dnato como parte del despliegue.

### 3.6 🟢 dnato — el resto de los cambios es aditivo

- `routes.php`: **solo agrega** las rutas `oauth/*`. No modifica ninguna existente.
- `User_model.php` y `Empresas.php`: **solo agregan métodos** (`getEmprIdByGroup`,
  `getEmpresaById`). No tocan los existentes.
- `config.php`, `base_url`: el bloque nuevo solo actúa si existe la variable de entorno
  `DNATO_PUBLIC_URL`; sin ella, el comportamiento es **idéntico al actual**.
- `permitted_uri_chars`: agrega `@` a los caracteres permitidos. Aditivo.
- Se borran 15 `.car` de backup de `development/`. Limpieza, sin efecto en runtime.

Esta sección es la que confirma tu lectura: en dnato, el código existente prácticamente no se toca.

---

## 4. Un tema estructural que el merge deja sin resolver

traz-tools mantiene **los mismos artefactos WSO2 en dos lugares**:

- `_backend/api/dataservice/*.dbs` y `_backend/api/tools*.xml` — la estructura del EI (v2)
- `_backend/api/ToolsAPIProject/...` — el proyecto Maven del MI (v3)

Y **las dos ramas tocan las dos copias**: v2 modificó `ALMDataService.dbs` en ambas. Después del
merge esa duplicación sigue, con las copias ya divergentes entre sí.

No es un bloqueante del merge, pero es deuda que conviene resolver antes del cutover a producción:
decidir cuál es la fuente de verdad, o el próximo cambio vuelve a tener que aplicarse dos veces.

---

## 5. Plan de merge propuesto

Ejecutar **en la terminal local**, un repo por vez. Nada de esto toca los servers.

### 5.1 dnato — el fácil

```bash
cd /mnt/win/dev/git/traz-comp-dnato && \
git fetch origin && \
git checkout -b merge/unificar-develop-v3 origin/develop && \
git merge origin/develop-v3
```

Mergea limpio. **Antes de pushear**, decidir el punto 3.4: si el vhost de Apache no tiene las
rewrite rules, restaurar el `.htaccess`:

```bash
git checkout origin/develop -- .htaccess && git commit -m "chore: conservar .htaccess (las rewrite rules no estan en el vhost)"
```

### 5.2 traz-tools — resolver el conflicto conocido

```bash
cd /mnt/win/dev/git/traz-tools && \
git fetch origin && \
git checkout -b merge/unificar-develop-v3 origin/develop && \
git merge origin/develop-v3
```

Va a marcar conflicto en `_backend/api/dataservice/ALMDataService.dbs`. Abrir el archivo, buscar el
bloque `<<<<<<<` (queda alrededor de la línea 553) y **borrar solo las tres líneas marcadoras**
(`<<<<<<<`, `=======`, `>>>>>>>`), conservando los dos bloques de queries. Después:

```bash
python3 -c "import re;s=open('_backend/api/dataservice/ALMDataService.dbs',encoding='utf-8',errors='replace').read();ids=re.findall(r'<query id=\"([^\"]+)\"',s);from collections import Counter;print({k:v for k,v in Counter(ids).items() if v>1})"
```

Tiene que imprimir `{'extraerCantidadLote': 2}` — ese es el duplicado preexistente. **Si aparece
cualquier otro, la resolución quedó mal.** Luego:

```bash
git add _backend/api/dataservice/ALMDataService.dbs && git commit
```

### 5.3 Validar antes de abrir el PR

```bash
cd /mnt/win/dev/git/traz-tools/_backend/api/ToolsAPIProject/ToolsAPIProject && mvn clean install
```

Y con el MI local levantado y la base de desarrollo accesible (VPN):

```bash
cd /mnt/win/dev/git/traz-tools && python3 scripts/dev/mcp_escenarios.py
```

Tienen que dar 14/14. Después, PR a `develop` con este documento enlazado.

---

## 6. Cómo reproducir el análisis

Todo lo de arriba sale de estos comandos, que **no modifican nada**:

```bash
cd <repo> && git fetch origin
git rev-list --left-right --count origin/develop...origin/develop-v3
B=$(git merge-base origin/develop origin/develop-v3)
comm -12 <(git diff --name-only $B origin/develop | sort) \
         <(git diff --name-only $B origin/develop-v3 | sort)
git merge-tree --write-tree --name-only origin/develop origin/develop-v3
```

El último es el que simula el merge de verdad: si sale con código 0, no hay conflictos.
