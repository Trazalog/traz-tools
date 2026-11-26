# Pirkai · Guía 02 — Sitio de Apache para el subdominio (puerto 80)

## Objetivo

Crear en Apache un sitio nuevo para `demo.pirkai.net` (o `app.pirkai.net`) en el puerto 80, apuntando a
la **misma carpeta** que el sitio de Trazalog. Hace falta para emitir el certificado (guía 03) y para
redirigir `http` a `https`. Para quien opere el servidor. Se hace **antes de desplegar**, después de la
[guía 01](pirkai-01-dominio-dns.md). **No** toca el sitio de Trazalog ni crea todavía el sitio seguro
(eso es la [guía 03](pirkai-03-certificado-https.md)).

| Ítem | Valor |
|---|---|
| Archivo nuevo | `/etc/httpd/conf.d/zz-pirkai.conf` |
| Por qué ese nombre | Apache lee `conf.d/` en orden alfabético; con `zz-` queda último y el sitio de Trazalog sigue siendo el primero (el que responde a dominios desconocidos) |
| Carpeta raíz | La misma que el sitio de Trazalog (planilla, R5; se espera `/var/www/html`) |

---

## Pasos

Todos los pasos son en una **sesión SSH al servidor** (cómo entrar: guía 00, paso 1). El ejemplo usa
DEMO; para producción, reemplazar `demo.pirkai.net` por `app.pirkai.net`.

### 1. Respaldo de la configuración de Apache

```bash
sudo tar czf /root/httpd-conf-antes-pirkai-$(date +%Y%m%d%H%M).tgz \
  /etc/httpd/conf /etc/httpd/conf.d
```

### 2. Crear la carpeta para la validación del certificado

```bash
sudo mkdir -p /var/www/html/.well-known/acme-challenge
```

(Si la carpeta raíz no es `/var/www/html`, usar la de R5 en este paso y en el siguiente.)

### 3. Crear el archivo del sitio

Abrí el editor (`sudo vi /etc/httpd/conf.d/zz-pirkai.conf` o `sudo nano ...`) y pegá **exactamente**
esto, cambiando el dominio si es producción:

```apache
# Marca Pirkai (REQ-019) — sitio en el puerto 80.
# Solo atiende la validación del certificado; todo lo demás se redirige a https.
<VirtualHost *:80>
    ServerName demo.pirkai.net
    DocumentRoot /var/www/html

    # Validación de Let's Encrypt (guía 03): se sirve tal cual, sin redirigir.
    <Directory "/var/www/html/.well-known/acme-challenge">
        Options None
        AllowOverride None
        Require all granted
    </Directory>

    # El resto, a https. Mientras no exista el certificado, la redirección
    # lleva a una página con error de seguridad: es esperado hasta la guía 03.
    RedirectMatch 301 "^/(?!\.well-known/acme-challenge/)(.*)$" "https://demo.pirkai.net/$1"

    ErrorLog  logs/pirkai_error_log
    CustomLog logs/pirkai_access_log combined
</VirtualHost>
```

### 4. Validar y recargar sin corte

```bash
sudo apachectl configtest
```

Tiene que decir `Syntax OK`. **Si dice otra cosa, no sigas**: corregí el archivo o borralo (vuelta atrás).

```bash
sudo systemctl reload httpd
sudo httpd -S | grep -i pirkai
```

`reload` no corta las conexiones abiertas. La última línea debe mostrar `demo.pirkai.net` en el puerto 80.

### 5. Probar

**Dónde:** sesión SSH.

```bash
echo ok-pirkai | sudo tee /var/www/html/.well-known/acme-challenge/prueba >/dev/null
```

**Dónde:** terminal de tu computadora.

```bash
curl -s http://demo.pirkai.net/.well-known/acme-challenge/prueba ; echo
curl -sI http://demo.pirkai.net/traz-tools/ | grep -i location
```

La primera tiene que mostrar `ok-pirkai`; la segunda, `Location: https://demo.pirkai.net/traz-tools/`.

**Dónde:** sesión SSH, para limpiar.

```bash
sudo rm /var/www/html/.well-known/acme-challenge/prueba
```

## Vuelta atrás

**Dónde:** sesión SSH.

```bash
sudo rm /etc/httpd/conf.d/zz-pirkai.conf
sudo apachectl configtest && sudo systemctl reload httpd
```
