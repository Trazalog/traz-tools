# Pirkai · Guía 00 — Relevamiento del servidor (solo lectura)

## Objetivo

Primera guía del dominio Pirkai ([REQ-019](../../requerimientos/REQ-019-marca-por-dominio.md)): junta los
datos del servidor que hoy **no están documentados** y que las guías 01 a 04 necesitan (dirección IP
pública, cómo está armado Apache, quién emite el certificado, qué valores tiene la configuración). Para
quien vaya a habilitar `demo.pirkai.net` o `app.pirkai.net`. Se hace **antes de todo**, una vez por
servidor. **No modifica nada**. No cubre el diseño del cambio ([ADR-015](../adr/ADR-015-marca-por-dominio.md)).

| Ítem | DEMO | Producción |
|---|---|---|
| Servidor | `vm-demo-trazalog`, IP interna 10.142.0.11, CentOS 7.9 | `vm-production-assetplanner-inst1`, IP interna 10.142.0.2, CentOS 7.9 |
| Proyecto GCP | `trazasuite-cloud` | `trazasuite-cloud` |
| Dominio de Trazalog hoy | `demo.cloudtrazalog.com` | `www.cloudtrazalog.com` |
| Dominio Pirkai (propuesto) | `demo.pirkai.net` | `app.pirkai.net` |

## Orden de todas las guías

| # | Guía | Momento |
|---|---|---|
| **00** | **Relevamiento (esta)** | Antes de desplegar |
| 01 | [Registros del dominio](pirkai-01-dominio-dns.md) | Antes de desplegar |
| 02 | [Sitio en Apache, puerto 80](pirkai-02-apache-sitio-http.md) | Antes de desplegar |
| 03 | [Certificado y sitio seguro](pirkai-03-certificado-https.md) | Antes de desplegar |
| — | Despliegue del código (`deploytools.sh`) | — |
| 04 | [Ajustes de configuración](pirkai-04-configuracion-post-despliegue.md) | Después de desplegar |
| 05 | [Verificación](pirkai-05-verificacion.md) | Después de desplegar |
| 06 | [Operación continua](pirkai-06-operacion.md) | Siempre |

---

## Planilla de resultados

Copiá esta tabla en el pedido de cambio o en un comentario del issue y completala. Las guías siguientes
la nombran como "la planilla".

| # | Dato | DEMO | Producción |
|---|---|---|---|
| R1 | IP pública del servidor | | |
| R2 | Versión de Apache | | |
| R3 | Versión de PHP | | |
| R4 | Archivo y bloque `VirtualHost` del dominio de Trazalog en el puerto 443 | | |
| R5 | Carpeta raíz (`DocumentRoot`) de ese bloque | | |
| R6 | Archivos de certificado que usa (`SSLCertificateFile`, `KeyFile`, `ChainFile`) | | |
| R7 | ¿Existe bloque en el puerto 80? ¿Redirige a https? | | |
| R8 | ¿Está abierto el puerto 80 desde internet? | | |
| R9 | Línea `$base = ...` de `traz-tools/application/config/config.php` | | |
| R10 | Línea `define('DNATO', ...)` de `traz-tools/application/config/constants.php` | | |
| R11 | Líneas `DE`, `DS`, `DNATO` y `DNATO_OAUTH_ISSUER` de `traz-comp-dnato/application/config/constants.php` | | |
| R12 | Variables `DNATO_ISSUER` y `DNATO_PUBLIC_URL` en el entorno de Apache | | |
| R13 | Espacio libre en disco | | |

## Pasos

### 1. Entrar al servidor

**Dónde:** terminal de tu computadora (con `gcloud` instalado y sesión iniciada) o el botón "SSH" de la
consola web de GCP (Compute Engine → Instancias de VM).

```bash
gcloud compute ssh vm-demo-trazalog \
  --project=trazasuite-cloud \
  --zone=us-east1-b
```

Para producción, reemplazar `vm-demo-trazalog` por `vm-production-assetplanner-inst1`. Si la zona no es
`us-east1-b`, la consola web la muestra en la lista de instancias.

Todos los pasos siguientes son **en esa sesión SSH**. Algunos necesitan `sudo`.

### 2. IP pública (R1)

**Dónde:** sesión SSH.

```bash
curl -s https://ifconfig.me ; echo
```

Comparala con la columna "IP externa" de la consola web de GCP. Si la IP es **efímera** (la consola lo
dice al lado), conviene reservarla como estática antes de apuntar un dominio: si no, cambia al reiniciar.
Eso se hace en la consola web: Red de VPC → Direcciones IP → la IP del servidor → "Reservar". Es un
cambio sin corte, pero consultalo antes con quien administre GCP.

### 3. Versiones (R2, R3) y espacio (R13)

**Dónde:** sesión SSH.

```bash
httpd -v ; php -v | head -1 ; df -h /var/www /etc
```

### 4. Cómo está armado Apache (R4 a R7)

**Dónde:** sesión SSH.

```bash
sudo httpd -S
```

Buscá en la salida la línea del dominio de Trazalog (`demo.cloudtrazalog.com` o `www.cloudtrazalog.com`)
en el puerto 443: dice el archivo y la línea del bloque. Anotalo en R4. Después mirá ese bloque:

```bash
sudo grep -n -E "ServerName|ServerAlias|DocumentRoot|SSLCertificate|Redirect|Rewrite" \
  /etc/httpd/conf.d/*.conf /etc/httpd/conf/httpd.conf
```

Anotá `DocumentRoot` (R5, se espera `/var/www/html`), los tres archivos `SSLCertificate*` (R6) y si hay un
bloque en el puerto 80 con `Redirect` o `Rewrite` hacia https (R7).

Para saber quién emitió el certificado actual y cuándo vence (no se usa para Pirkai, pero conviene
tenerlo anotado):

```bash
sudo openssl x509 -noout -issuer -enddate -in RUTA_DE_SSLCertificateFile
```

### 5. ¿Está abierto el puerto 80? (R8)

**Dónde:** consola web de GCP → Red de VPC → Firewall. Buscá reglas que permitan `tcp:80` desde
`0.0.0.0/0` y que apliquen a las etiquetas de red del servidor (en DEMO, `vm-demo`). Si no hay, la guía
03 usa el método por registro del dominio en vez del puerto 80.

Prueba rápida desde **tu computadora** (no el servidor):

```bash
curl -sI http://demo.cloudtrazalog.com/ | head -3
```

Si responde (aunque sea con una redirección), el puerto 80 está abierto.

### 6. Configuración de las aplicaciones (R9 a R12)

**Dónde:** sesión SSH. Se asume que las aplicaciones están en `/var/www/html/traz-tools` y
`/var/www/html/traz-comp-dnato`; si R5 dio otra carpeta, usá esa.

```bash
cd /var/www/html
grep -n '\$base' traz-tools/application/config/config.php
grep -n "define('DNATO'" traz-tools/application/config/constants.php
grep -n -E "define\('(DE|DS|DNATO|DNATO_OAUTH_ISSUER)'" \
  traz-comp-dnato/application/config/constants.php
sudo grep -rn -E "DNATO_ISSUER|DNATO_PUBLIC_URL" \
  /etc/httpd/ /etc/sysconfig/httpd 2>/dev/null
```

Qué mirar:

- **R9**: si dice `"http://"` fijo y el sitio de Trazalog funciona con https, igual anotalo; la guía 04
  decide si hace falta cambiarlo.
- **R12**: si `DNATO_PUBLIC_URL` está definida, la marca **no** va a funcionar en el ingreso (fija la
  dirección de DNATO). Avisá antes de seguir.

## Resultado

La planilla completa. Con eso se siguen la guía 01 (necesita R1) y las guías 02 a 04.
