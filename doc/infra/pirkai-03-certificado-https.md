# Pirkai · Guía 03 — Certificado https y sitio seguro (puerto 443)

## Objetivo

Emitir un certificado gratuito de Let's Encrypt para `demo.pirkai.net` (o `app.pirkai.net`), dejarlo con
renovación automática y crear el sitio seguro en Apache. Para quien opere el servidor. Se hace **antes
de desplegar**, después de la [guía 02](pirkai-02-apache-sitio-http.md). Al terminar, el subdominio abre
el sistema con candado **todavía con marca Trazalog** (la marca aparece al desplegar el código). **No**
toca el certificado de Trazalog, que es otro y sigue igual.

| Ítem | Valor |
|---|---|
| Herramienta | `acme.sh` (no depende de paquetes de CentOS 7, que ya no tiene soporte) |
| Autoridad | Let's Encrypt, validez 90 días, renovación automática a los 60 |
| Validación | Por la carpeta web `/.well-known/acme-challenge/` (puerto 80, preparado en la guía 02) |
| Archivos | `/etc/pki/tls/certs/<dominio>.crt`, `/etc/pki/tls/certs/<dominio>.ca.crt`, `/etc/pki/tls/private/<dominio>.key` |

---

## Pasos

Todos en una **sesión SSH al servidor** (guía 00, paso 1). El ejemplo usa DEMO; para producción,
reemplazar `demo.pirkai.net` por `app.pirkai.net` en **todos** los comandos y en el archivo.

### 1. Pasar a usuario administrador

```bash
sudo -i
```

Los pasos 2 a 5 se ejecutan como `root` (el indicador de la terminal termina en `#`).

### 2. Instalar `acme.sh` (una sola vez por servidor)

Si ya está instalado (`ls /root/.acme.sh/acme.sh` lo muestra), saltá al paso 3.

```bash
cd /root
curl -fsSL -o acme-instalar.sh https://get.acme.sh
less acme-instalar.sh
```

Revisá que sea el instalador de acme.sh (salí de `less` con `q`) y ejecutalo con un correo de contacto
para avisos de vencimiento (reemplazá `CORREO`):

```bash
sh acme-instalar.sh email=CORREO
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
crontab -l | grep acme
```

La última línea tiene que mostrar la tarea programada de renovación que agrega el instalador.

Si `curl` falla con un error de certificado, el almacén de autoridades de CentOS 7 está viejo:
`yum update -y ca-certificates` y repetir.

### 3. Emitir el certificado

```bash
/root/.acme.sh/acme.sh --issue -d demo.pirkai.net -w /var/www/html
```

Si termina con `Cert success`, seguir. Si falla:

- `Invalid response from http://demo.pirkai.net/.well-known/...`: repetir la prueba del paso 5 de la
  guía 02.
- `Timeout` o `Connection refused`: el puerto 80 no está abierto desde internet (planilla, R8). Hay que
  abrirlo (consultar con quien administre GCP) o usar validación por registro del dominio:
  `--dns --yes-I-know-dns-manual-mode-enough-go-ahead-please`, que pide cargar un registro TXT en el panel
  del dominio y **no se renueva solo** (habría que repetirlo cada 60 días).

### 4. Copiar el certificado a su lugar y programar la recarga de Apache

```bash
/root/.acme.sh/acme.sh --install-cert -d demo.pirkai.net \
  --cert-file /etc/pki/tls/certs/demo.pirkai.net.crt \
  --ca-file /etc/pki/tls/certs/demo.pirkai.net.ca.crt \
  --key-file /etc/pki/tls/private/demo.pirkai.net.key \
  --reloadcmd "systemctl reload httpd"
chmod 600 /etc/pki/tls/private/demo.pirkai.net.key
```

Con esto, cada renovación copia los archivos nuevos y recarga Apache sola.

### 5. Agregar el sitio seguro

Abrí `/etc/httpd/conf.d/zz-pirkai.conf` (creado en la guía 02) y agregá **al final**:

```apache
# Marca Pirkai (REQ-019) — sitio seguro. Misma carpeta que el sitio de Trazalog:
# el código decide la marca por el dominio (application/config/marcas.php).
<VirtualHost *:443>
    ServerName demo.pirkai.net
    DocumentRoot /var/www/html

    SSLEngine on
    SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
    SSLCertificateFile      /etc/pki/tls/certs/demo.pirkai.net.crt
    SSLCertificateKeyFile   /etc/pki/tls/private/demo.pirkai.net.key
    SSLCertificateChainFile /etc/pki/tls/certs/demo.pirkai.net.ca.crt

    # La raíz del dominio lleva directo al sistema.
    RedirectMatch 302 "^/$" "/traz-tools/"

    ErrorLog  logs/pirkai_ssl_error_log
    CustomLog logs/pirkai_ssl_access_log combined
</VirtualHost>
```

Si el bloque de Trazalog en el puerto 443 (planilla, R4) tiene otras directivas además de las de
certificado (por ejemplo `<Directory>` con `AllowOverride`, cabeceras o alias), copialas también acá:
el sistema tiene que comportarse igual en los dos dominios.

### 6. Validar y recargar sin corte

```bash
apachectl configtest && systemctl reload httpd
httpd -S | grep -i pirkai
exit
```

`configtest` tiene que decir `Syntax OK`; si no, no recargues y corregí. La salida de `httpd -S` debe
mostrar `demo.pirkai.net` en los puertos 80 y 443.

### 7. Probar

**Dónde:** terminal de tu computadora.

```bash
curl -sI https://demo.pirkai.net/ | grep -i -E "^HTTP|location"
curl -sI https://demo.cloudtrazalog.com/ | head -1
echo | openssl s_client -connect demo.pirkai.net:443 -servername demo.pirkai.net 2>/dev/null \
  | openssl x509 -noout -subject -issuer -enddate
```

- El primero: respuesta `302` hacia `/traz-tools/`.
- El segundo: el sitio de Trazalog responde igual que antes.
- El tercero: `subject` con `demo.pirkai.net`, emisor Let's Encrypt y la fecha de vencimiento.

**Dónde:** navegador. Abrí `https://demo.pirkai.net/`: tiene que aparecer el ingreso **con candado**.
Todavía con marca Trazalog y, al ingresar, puede llevarte al dominio de Trazalog: es lo esperado hasta
desplegar el código y hacer la guía 04.

## Vuelta atrás

**Dónde:** sesión SSH, como `root`.

```bash
/root/.acme.sh/acme.sh --remove -d demo.pirkai.net
rm /etc/httpd/conf.d/zz-pirkai.conf
apachectl configtest && systemctl reload httpd
```

(Borrar el archivo saca los dos sitios, el del puerto 80 y el seguro. Los archivos de certificado en
`/etc/pki/tls/` se pueden dejar o borrar; Apache ya no los usa.)
