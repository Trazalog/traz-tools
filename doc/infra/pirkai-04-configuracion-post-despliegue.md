# Pirkai · Guía 04 — Despliegue y ajustes de configuración en el servidor

## Objetivo

Desplegar la versión que trae la marca por dominio ([REQ-019](../../requerimientos/REQ-019-marca-por-dominio.md))
y hacer los ajustes a mano que el despliegue **no puede** hacer, porque `deploytools.sh` restaura la
configuración propia de cada servidor (`config.php`, `constants.php`). Para quien despliegue en DEMO o
producción. Se hace **después** de las guías [00](pirkai-00-relevamiento-servidor.md) a
[03](pirkai-03-certificado-https.md), y se sigue con la [guía 05](pirkai-05-verificacion.md). **No** cubre
el despliegue de WSO2 (este cambio no toca APIs ni DataServices).

| Archivo del servidor | Ajuste | ¿Siempre? |
|---|---|---|
| `traz-tools/application/config/constants.php` | Envolver `DNATO` con `marca_url_host()` | Sí |
| `traz-comp-dnato/application/config/constants.php` | Fijar `DNATO_OAUTH_ISSUER` | Solo si no hay `DNATO_ISSUER` en el entorno (planilla, R12) |
| `traz-tools/application/config/config.php` | Detectar `https` en `base_url` | Solo si la línea `$base` dice `"http://"` fijo (planilla, R9) |

Orden obligatorio: **primero desplegar, después editar**. Si se edita `constants.php` antes, el servidor
llama a una función que todavía no existe y Tools deja de abrir.

---

## Pasos

Todos en una **sesión SSH al servidor** (guía 00, paso 1).

### 1. Desplegar el código

La versión a desplegar es la etiqueta (o la rama) que incluye REQ-019 en **los dos** repositorios.
Reemplazá `VERSION` (por ejemplo `v3.0.0.5`, o `origin/develop` en DEMO).

```bash
cd /var/www/html
sh traz-tools/scripts/deploy/deploytools.sh VERSION traz-tools
sh traz-tools/scripts/deploy/deploytools.sh VERSION traz-comp-dnato
```

Cada uno termina informando el log. Comprobá que llegaron los archivos nuevos:

```bash
ls traz-tools/application/helpers/marca_helper.php \
  traz-tools/application/config/marcas.php \
  traz-tools/lib/marcas/pirkai/marca.css \
  traz-comp-dnato/application/helpers/marca_helper.php \
  traz-comp-dnato/public/marcas/pirkai/marca.css
```

Si falta alguno, **no sigas**: el despliegue no trajo la versión correcta.

Con esto, el dominio de Trazalog sigue exactamente igual. Pirkai ya muestra su marca en Tools, pero el
ingreso todavía lo lleva al dominio de Trazalog: lo resuelve el paso 3.

### 2. Respaldo de los archivos que se van a editar

```bash
cd /var/www/html
mkdir -p bk/pirkai-$(date +%Y%m%d)
cp traz-tools/application/config/constants.php bk/pirkai-$(date +%Y%m%d)/tools-constants.php
cp traz-tools/application/config/config.php bk/pirkai-$(date +%Y%m%d)/tools-config.php
cp traz-comp-dnato/application/config/constants.php bk/pirkai-$(date +%Y%m%d)/dnato-constants.php
```

### 3. Tools: el ingreso por el mismo dominio

Archivo: `/var/www/html/traz-tools/application/config/constants.php`. Buscá la línea:

```bash
grep -n "define('DNATO'" traz-tools/application/config/constants.php
```

Abrila con el editor (`vi` o `nano`) en esa línea. Hoy es algo así (el valor es el de la planilla, R10):

```php
define('DNATO', 'https://demo.cloudtrazalog.com/traz-comp-dnato/');
```

Reemplazala por estas **dos** líneas, dejando **el mismo valor** entre comillas:

```php
require_once APPPATH . 'helpers/marca_helper.php';
define('DNATO', marca_url_host('https://demo.cloudtrazalog.com/traz-comp-dnato/'));
```

Con el dominio de Trazalog la dirección queda igual; con el de Pirkai pasa a ser
`https://demo.pirkai.net/traz-comp-dnato/`.

### 4. DNATO: el emisor de los tokens del agente no puede cambiar

Si la planilla (R12) muestra que `DNATO_ISSUER` está definida en el entorno de Apache, **saltá este
paso**: esa variable manda y no depende del dominio.

Si no está, averiguá el emisor que usa hoy. **Dónde:** navegador o terminal de tu computadora, por el
dominio de **Trazalog**:

```bash
curl -s https://demo.cloudtrazalog.com/traz-comp-dnato/oauth/.well-known/oauth-authorization-server
```

Copiá el valor de `"issuer"` (por ejemplo `https://demo.cloudtrazalog.com/traz-comp-dnato/oauth`).

**Dónde:** sesión SSH. Archivo `/var/www/html/traz-comp-dnato/application/config/constants.php`:

```bash
grep -n "DNATO_OAUTH_ISSUER" traz-comp-dnato/application/config/constants.php
```

- Si la línea existe (`define('DNATO_OAUTH_ISSUER', '');`), poné entre las comillas el valor copiado.
- Si no existe, agregala al final del archivo:
  `define('DNATO_OAUTH_ISSUER', 'https://demo.cloudtrazalog.com/traz-comp-dnato/oauth');`

El valor tiene que ser **idéntico, carácter por carácter**, al que ya usaba: el APIM compara contra él.

### 5. Tools: `https` en la dirección base (solo si hace falta)

Mirá la planilla (R9). Si la línea `$base = ...` de `traz-tools/application/config/config.php` ya dice
`"https://"` o ya detecta el esquema, **saltá este paso**.

Si dice `$base = "http://" . $_SERVER['HTTP_HOST'];`, reemplazá **esa sola línea** por el bloque de
detección que está en el repositorio, en el mismo archivo `application/config/config.php`, desde el
comentario `/* REQ-019: el esquema (http/https) se detecta del pedido` hasta la línea
`$base = $_esquema . "://" . $_SERVER['HTTP_HOST'];` inclusive. Las dos líneas que siguen
(`$base .= ...` y `$config['base_url'] = $base;`) quedan como están.

Sin este ajuste, entrando por `https://demo.pirkai.net` el navegador bloquea hojas de estilo y scripts
pedidos por `http`, y la pantalla se ve rota.

### 6. Validar la sintaxis de lo editado

```bash
php -l traz-tools/application/config/constants.php
php -l traz-tools/application/config/config.php
php -l traz-comp-dnato/application/config/constants.php
```

Los tres tienen que decir `No syntax errors detected`. Si alguno no, restaurá ese archivo desde el
respaldo (vuelta atrás) y revisá la edición.

No hace falta reiniciar Apache: PHP lee los archivos en cada pedido.

### 7. Prueba rápida

**Dónde:** terminal de tu computadora.

```bash
curl -sI https://demo.pirkai.net/traz-tools/ | grep -i location
curl -sI https://demo.cloudtrazalog.com/traz-tools/ | grep -i location
```

Sin sesión, el primero tiene que llevar a `https://demo.pirkai.net/traz-comp-dnato/main/login` y el
segundo al ingreso del dominio de Trazalog, como siempre. La prueba completa es la guía 05.

## Vuelta atrás

**Dónde:** sesión SSH. Restaurar los tres archivos (reemplazá `FECHA` por la carpeta del paso 2):

```bash
cd /var/www/html
cp bk/pirkai-FECHA/tools-constants.php traz-tools/application/config/constants.php
cp bk/pirkai-FECHA/tools-config.php traz-tools/application/config/config.php
cp bk/pirkai-FECHA/dnato-constants.php traz-comp-dnato/application/config/constants.php
```

Para volver también el código, desplegar la versión anterior con `deploytools.sh`. Restaurá los archivos
**antes**: la versión anterior no tiene `marca_url_host()`.
