# WSO2 API Manager 4.6.0 — Instalación en DEV

Procedimiento real ejecutado en la workstation del PM (Ubuntu 24).
Referencia para reproducir en entornos TEST y PROD (ver notas al final).

---

## Entorno

| Item | Valor |
|---|---|
| OS | Ubuntu 24 |
| Path de instalación | `/mnt/win/dev/wso2am-4.6.0/` |
| Java | Temurin OpenJDK 21 |
| JAVA_HOME | configurado en `/etc/profile.d/jdk21.sh` |
| Modo | All-in-one (single node, sin profileSetup) |
| Base de datos | H2 embebida (solo DEV — ver sección de notas) |

> **Por qué no `/opt/`**: espacio en disco insuficiente en la partición del sistema.
> La partición montada en `/mnt/win/dev/` tiene el espacio disponible.

---

## 1. Prerequisito: Java 21 Temurin

WSO2 APIM 4.6.0 requiere JDK 21. Verificar antes de continuar:

```bash
java -version
# openjdk version "21.x.x" ...

echo $JAVA_HOME
# /usr/lib/jvm/temurin-21-amd64  (o equivalente)
```

Si `JAVA_HOME` no está seteado, crearlo en `/etc/profile.d/jdk21.sh`:

```bash
export JAVA_HOME=/usr/lib/jvm/temurin-21-amd64
export PATH=$JAVA_HOME/bin:$PATH
```

Luego `source /etc/profile.d/jdk21.sh` o reiniciar la sesión.

---

## 2. Descarga e instalación

```bash
# Descargar el zip oficial desde wso2.com/api-platform/api-manager/
# (requiere cuenta gratuita en wso2.com)

# Descomprimir en el path de destino
cd /mnt/win/dev/
unzip wso2am-4.6.0.zip

# El directorio resultante es /mnt/win/dev/wso2am-4.6.0/

# Dar permisos de ejecución al script principal
chmod +x /mnt/win/dev/wso2am-4.6.0/bin/api-manager.sh
```

---

## 3. Configuración (deployment.toml)

Path: `/mnt/win/dev/wso2am-4.6.0/repository/conf/deployment.toml`

Cambios aplicados sobre el archivo default. Solo se listan las secciones modificadas;
el resto queda con los valores default de WSO2:

```toml
[server]
hostname = "localhost"
mode = "single"

[super_admin]
username = "admin"
password = "admin"
create_admin_account = true

[user_store]
type = "database_unique_id"

[database.apim_db]
type = "h2"

[database.shared_db]
type = "h2"

[[apim.gateway.environment]]
name = "Default"
# todos los endpoints apuntan a localhost (valores default de la instalación)

[apim.analytics]
enable = false
```

> La configuración completa está en el kickoff doc del proyecto.
> H2 es la base embebida de WSO2 — válida solo en DEV, sin datos persistentes entre
> reinstalaciones. Para TEST y PROD usar PostgreSQL (ver E0-INF-05).

---

## 4. Arranque

```bash
cd /mnt/win/dev/wso2am-4.6.0
./bin/api-manager.sh start
```

Seguir los logs durante el primer arranque (~3-4 minutos):

```bash
tail -f repository/logs/wso2carbon.log
```

El servidor está listo cuando aparece en el log:

```
[INFO] WSO2 API Manager started in X seconds
```

Otros comandos útiles:

```bash
./bin/api-manager.sh stop
./bin/api-manager.sh restart
./bin/api-manager.sh status
```

---

## 5. Smoke test ejecutado y validado

### Consolas web

| Endpoint | URL | Estado |
|---|---|---|
| Publisher | https://localhost:9443/publisher | OK |
| Developer Portal | https://localhost:9443/devportal | OK |
| Admin Console | https://localhost:9443/carbon | OK |

Credenciales: `admin` / `admin`

El browser muestra advertencia de certificado self-signed — aceptar la excepción
para continuar (solo en DEV).

### Gateway (puerto 8243)

El Gateway usa HTTPS con certificado self-signed. Validar con curl, no con el browser:

```bash
curl -k https://localhost:8243
# Respuesta: "Welcome to WSO2 API Manager" (o similar)
```

### API HelloWorld

Se creó una API de prueba desde el Publisher, se publicó y se consumió exitosamente
desde el Developer Portal — flujo completo validado.

### Tunnel ngrok

```bash
ngrok http https://localhost:8243
```

URL pública generada y accesible desde internet — smoke test completo del flujo
MCP end-to-end confirmado.

---

## 6. Notas para reproducir en TEST / PROD

**Puerto 8243 es HTTPS — ngrok requiere esquema explícito:**

```bash
# CORRECTO
ngrok http https://localhost:8243

# INCORRECTO — rompe el handshake SSL
ngrok http 8243
```

**Certificado self-signed en localhost:8243:**
El browser bloquea la conexión directa al Gateway. Usar siempre `curl -k` para
validar el Gateway en DEV. En TEST/PROD configurar un certificado válido.

**Base de datos:**
H2 es solo para DEV. Para TEST y PROD reemplazar las secciones `[database.*]` en
`deployment.toml` con la configuración PostgreSQL correspondiente (ver E0-INF-05).

**Permisos en filesystem NTFS (Windows/WSL):**
Si los scripts `.sh` pierden el bit de ejecución después de descomprimir en una
partición NTFS montada desde Windows:

```bash
find /mnt/win/dev/wso2am-4.6.0/bin -name "*.sh" -exec chmod +x {} \;
```
