# Pirkai · Guía 06 — Operación continua del dominio

## Objetivo

Qué hay que revisar o hacer **después** de habilitar el dominio Pirkai: renovación del certificado, qué
mirar en cada despliegue futuro, cómo cambiar logo o colores, cómo sumar otro dominio o marca y cómo dar
de baja el dominio. Para quien opere los servidores. Se lee cuando aparece alguna de esas situaciones.
**No** repite la puesta en marcha (guías [00](pirkai-00-relevamiento-servidor.md) a
[05](pirkai-05-verificacion.md)).

| Situación | Sección |
|---|---|
| Un despliegue nuevo de Tools o DNATO | 1 |
| Vence o falla el certificado | 2 |
| Llegó el logo o la paleta definitiva | 3 |
| Sumar un dominio o una marca | 4 |
| Dar de baja el dominio | 5 |
| Subir el tiempo de vida de los registros | 6 |

---

## 1. En cada despliegue futuro

`deploytools.sh` respalda y restaura `config.php` y `constants.php` del servidor, así que los ajustes de
la guía 04 **se conservan**. Igual conviene comprobarlo después de cada despliegue.

**Dónde:** sesión SSH al servidor.

```bash
cd /var/www/html
grep -n "marca_url_host" traz-tools/application/config/constants.php
grep -n "DNATO_OAUTH_ISSUER" traz-comp-dnato/application/config/constants.php
```

El primero tiene que mostrar la línea de `DNATO`. Si no aparece (por ejemplo, alguien reemplazó el
archivo), el dominio Pirkai sigue funcionando pero el ingreso se ve con Trazalog: repetir la guía 04,
paso 3.

**Cuidado al volver a una versión anterior a REQ-019**: primero restaurar `constants.php` sin
`marca_url_host()` (guía 04, vuelta atrás) y después desplegar; si no, Tools no abre.

## 2. Certificado

`acme.sh` lo renueva solo cada 60 días (vence a los 90) y recarga Apache.

**Dónde:** sesión SSH, como `root` (`sudo -i`).

```bash
/root/.acme.sh/acme.sh --list
crontab -l | grep acme
```

`--list` muestra la próxima renovación. Para probar la renovación sin esperar:

```bash
/root/.acme.sh/acme.sh --renew -d demo.pirkai.net --force
```

Si la renovación falla, lo más común es que el puerto 80 se haya cerrado o que alguien haya cambiado
`/etc/httpd/conf.d/zz-pirkai.conf`: repetir la prueba de la guía 02, paso 5. Let's Encrypt avisa por
correo (el de la guía 03, paso 2) unos 20 días antes de vencer si no se renovó.

## 3. Cambiar el logo o los colores

No hace falta tocar código PHP. **Dónde:** repositorios, en una rama nueva y con pedido de cambio:

| Qué | Archivos (mantener los nombres) |
|---|---|
| Logo de la barra superior (fondo oscuro) | `traz-tools/lib/marcas/pirkai/logo.svg`, `traz-comp-dnato/public/marcas/pirkai/logo.svg` |
| Logo para fondo blanco (impresiones, ingreso) | `traz-tools/lib/marcas/pirkai/logo-impresos.svg`, `traz-comp-dnato/public/marcas/pirkai/logo-impresos.svg` |
| Ícono de la pestaña | `traz-tools/lib/marcas/pirkai/favicon.svg`, `traz-comp-dnato/public/marcas/pirkai/favicon.svg` |
| Colores | Variables al principio de `traz-tools/lib/marcas/pirkai/marca.css` y `traz-comp-dnato/public/marcas/pirkai/marca.css` (los mismos valores en los dos) |

Si el logo definitivo viene en PNG, cambiar también la extensión en los dos `application/config/marcas.php`.
Después, desplegar normalmente (no hace falta repetir la guía 04).

## 4. Sumar un dominio o una marca

- **Otro dominio para Pirkai** (por ejemplo `pirkai.com.ar`): agregarlo a `'hosts'` de la marca `pirkai` en
  **los dos** `application/config/marcas.php`, desplegar y repetir las guías 01, 02, 03 y 05 para ese
  dominio. La guía 04 no hace falta (ya está hecha en el servidor).
- **Una marca nueva**: copiar el bloque `'pirkai'` en los dos `marcas.php` con otro nombre, crear sus
  carpetas `lib/marcas/<nombre>/` y `public/marcas/<nombre>/` con los mismos archivos, y seguir las
  guías 01 a 05 para su dominio.

## 5. Dar de baja el dominio

En este orden:

1. **Dónde:** panel del dominio. Borrar los registros A (guía 01, vuelta atrás).
2. **Dónde:** sesión SSH. Quitar el sitio y el certificado (guía 03, vuelta atrás).
3. Opcional, en los repositorios: sacar los dominios de `'hosts'`. Si se dejan, no tienen efecto: sin
   registro del dominio, nadie llega con ese nombre.

Los ajustes de la guía 04 pueden quedar: con el dominio de Trazalog no cambian nada.

## 6. Tiempo de vida de los registros

Cuando el dominio lleve una semana sin cambios, **dónde:** panel del dominio, subir el tiempo de vida
(TTL) de `demo` y `app` de 300 a 3600 segundos.
