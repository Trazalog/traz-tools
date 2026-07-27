# Despliegue en GCP — VM nativa WSO2 (ADR-011)

> Implementa [ADR-011](../adr/ADR-011-gcp-deployment.md). Tarea: E7-INFRA-01/02.
> Este documento NO despliega nada — es sizing + checklist para que Rodolfo
> ejecute en su consola de GCP, más los scripts en [`deploy/gcp/`](../../deploy/gcp/).

---

## 1. Sizing de la VM

### 1.1 Requisitos oficiales del stack (verificados contra doc oficial WSO2)

| Componente | RAM mínima (oficial) | CPU mínima (oficial) | Fuente |
|---|---|---|---|
| WSO2 API Manager 4.6.0 (all-in-one) | **4 GB** (2 GB heap JVM + 2 GB SO) | 2 cores (3 GHz dual-core Xeon/Opteron o equiv.) | [Installation Prerequisites — APIM 4.6.0](https://apim.docs.wso2.com/en/4.6.0/install-and-setup/install/installation-prerequisites/) |
| WSO2 Micro Integrator 4.x | Liviano — heap por defecto de fábrica `-Xms256m -Xmx1024m` en `bin/micro-integrator.sh` (footprint total ≈1 GB, reducido respecto a las ~4 GB de la generación EI anterior) | 1-2 cores compartidos | Confirmado en el script de arranque distribuido por WSO2; ver también `scripts/dev/setup-mi-b4-car-deploy.sh` de este repo (DEV corre MI 4.5.0 así) |

**Estos son los mínimos "de catálogo" de WSO2**, pensados para un ambiente de producción genérico con carga concurrente real. No son el punto de partida correcto para dimensionar el piloto: Rodolfo ya corre APIM+MI en su máquina de desarrollo con heaps de fábrica (`MI: -Xms256m -Xmx1024m`, sin tocar nada) y le anda bien. El early adopter va a tener **1-2 usuarios**, no la carga concurrente que esos mínimos oficiales asumen. Se prioriza ese dato empírico + el volumen real esperado por sobre el catálogo oficial (ver decisión en 1.4).

**Sistema operativo: `Rocky Linux 9`** — ya decidido en la arquitectura canónica (`TRAZALOG_v3_MCP_ARCHITECTURE.md` §9-10, decisión **IDR-001**), no es una elección nueva de esta tarea. Ese documento estableció que WSO2 4.6.0 requiere JDK 21, y CentOS 7 (el SO histórico de Trazalog) quedó EOL en junio 2024 con una `glibc` (2.17) incompatible con los builds modernos de JDK 21 — por eso IDR-001 fija Rocky Linux 9 (drop-in replacement de CentOS/RHEL, soporte hasta 2032) como el SO de cualquier VM nueva de WSO2 en v3. Ubuntu fue evaluada en ese mismo documento y descartada salvo "razón estratégica" (cambio de paradigma apt↔dnf sin beneficio para este caso). La primera versión de este documento decía Ubuntu 24.04 LTS por error — se tomó como referencia el SO del workstation de DEV de Rodolfo (`doc/infra/wso2-install.md`) en vez de la decisión ya tomada en la arquitectura canónica. Corregido acá.

### 1.2 Comparación de tiers E2 (specs verificadas contra `docs.cloud.google.com`)

| Tier | vCPU | RAM | Precio aprox.* (on-demand, us-central1) | ¿Aguanta 1-2 usuarios piloto? |
|---|---|---|---|---|
| `e2-micro` | 2 vCPU compartidas (0.25 sustenido) | **1 GB** | Cubierto por Always Free (ver 1.3) | ❌ No. Ni siquiera un solo heap de MI (`Xmx1024m`) entra cómodo, sin contar el APIM ni el SO |
| **`e2-medium`** | **2 vCPU compartidas (1.0 sustenido)** | **4 GB** | ≈ US$24-25/mes | ✅ Sí, con heaps chicos (ver 1.5) y aceptando el riesgo ya previsto en ADR-011 ("sizing ajustado", escalable sin reinstalar) |
| `e2-standard-2` | 2 vCPU dedicadas | 8 GB | ≈ US$48-52/mes | Sobredimensionado para 1-2 usuarios — se descarta por costo (ver 1.4) |

\* Precios de referencia obtenidos de trackers de terceros (economize.cloud, cloudprice.net, vantage.sh) al momento de esta investigación (2026-07-21). **Cambian seguido y varían por región** — reconfirmar el número exacto en [cloud.google.com/products/calculator](https://cloud.google.com/products/calculator) antes de aprobar el gasto. No son los precios oficiales citados textualmente, son una referencia de orden de magnitud.

`e2-small` (2 GB) se descartó directamente: ni con heaps mínimos entran dos JVMs (APIM+MI) más SO más Caddy sin arriesgar swap constante.

### 1.3 Free tier — verificado contra la doc oficial

Texto verbatim de la [documentación oficial Always Free](https://docs.cloud.google.com/free/docs/free-cloud-features) (consultada 2026-07-21):

> "1 non-preemptible `e2-micro` VM instance per month in one of the following US regions: Oregon: `us-west1`. Iowa: `us-central1`. South Carolina: `us-east1`." + "30 GB-months standard persistent disk" + "1 GB of outbound data transfer from North America... per month."

**El free tier solo cubre `e2-micro` (1 GB RAM)**, que según 1.1 es insuficiente incluso para el APIM solo (necesita 4 GB documentados por WSO2). `e2-small` y `e2-medium` **no están cubiertos** por Always Free bajo ninguna condición actual. No hay forma de correr este stack a costo $0 en Compute Engine nativo.

### 1.4 Decisión de sizing

**Tier elegido: `e2-medium` (2 vCPU compartidas, 4 GB RAM). Decisión de Rodolfo, no la recomendación inicial de esta investigación.**

La primera versión de este documento recomendaba `e2-standard-2` (8 GB) siguiendo al pie de la letra el mínimo "de catálogo" que documenta WSO2 para producción genérica. Rodolfo corrigió el enfoque: el early adopter va a tener **1-2 usuarios**, no la carga concurrente que ese catálogo asume, y él mismo corre el stack en su máquina de desarrollo con heaps de fábrica sin problemas. Para ese volumen real, `e2-medium` alcanza — y cuesta la mitad (~US$24-25/mes vs. ~US$48-52/mes).

Esto es exactamente el riesgo que ADR-011 ya preveía y aceptó explícitamente ("sizing ajustado: si la VM elegida queda por debajo de lo que WSO2 recomienda, puede haber lentitud... mitigación: el tipo de máquina es escalable sin reinstalar"). Se arranca con lo mínimo indispensable; si el feedback de uso real del early adopter muestra que hace falta más, se sube de tier sin tener que reinstalar nada (cambio de tipo de máquina en la consola de GCP + reinicio).

**Costo vs. ADR-005**: `e2-medium` sigue sin ser gratis (~US$24-25/mes, el free tier de GCP solo cubre `e2-micro`), pero es una excepción mucho más chica a ADR-005 que la propuesta original, y Rodolfo ya la aceptó conscientemente en esta conversación.

### 1.5 Reparto de heap propuesto (`e2-medium`, 4 GB total)

| Proceso | `-Xms` | `-Xmx` | Nota |
|---|---|---|---|
| MI | 256m | 1024m | Igual al default de fábrica que Rodolfo ya usa en DEV y confirmó que anda bien |
| APIM | 512m | 1536m | Recibe algo más de RAM que el MI (ADR-011 #4 — sigue priorizando al APIM) pero muy por debajo del mínimo "de catálogo" de 2 GB heap, acorde al volumen de 1-2 usuarios |
| SO + Caddy + sshd | — | — | Resto (~1-1.5 GB una vez descontado el overhead de JVM de ambos procesos, no solo el heap declarado) — colchón más ajustado que en un dimensionamiento de catálogo, aceptado a propósito |

Configurable en [`deploy/gcp/.env`](../../deploy/gcp/.env.example) (`APIM_XMS`/`APIM_XMX`/`MI_XMS`/`MI_XMX`) sin tener que reinstalar — volver a correr `install-apim.sh` / `install-mi.sh` reaplica la config sobre una instalación existente. Si tras el feedback de uso hace falta más margen, el camino es subir estos valores y/o el tier de la VM, no rearmar nada desde cero.

### 1.6 Disco

Ambos productos + logs necesitan holgadamente menos que los 10 GB mínimos que documenta WSO2 para el APIM solo. Se recomienda **20 GB pd-standard** — cubre APIM + MI + logs con margen para varios meses, priorizando costo (consistente con el criterio de esta sección), a un costo marginal (un par de dólares/mes, verificar en el calculador).

### 1.7 Nota de contexto: la otra VM (WSO2 4.4, sin MCP)

Rodolfo ya tiene otra VM en el mismo proyecto GCP corriendo WSO2 **4.4** (sin servidor MCP). Una vez cerrado el trabajo con el early adopter, se evaluará migrar esa VM a 4.6.0 **si existe un path de migración** — no se investigó en esta tarea. La VM nueva de este documento es independiente de esa migración futura; no la reemplaza ni depende de ella.

---

## 2. Cómo conecta la VM a lo que ya existe

```
VM GCP nueva (e2-medium, solo WSO2 nativo)
  APIM 4.6.0 ──jdbc:postgresql──> PostgreSQL existente (registro/metadata interno: apim_db, shared_db)
  MI 4.x      ──(red interna del proyecto GCP, sin VPN/peering)──> Dnato existente
```

- **Red interna del proyecto GCP**: al estar la VM nueva, PostgreSQL y Dnato en el mismo proyecto, la conectividad es directa por IP interna — no requiere VPN ni peering (ADR-011 #6). **Zona confirmada por Rodolfo: `us-east1-b`** — la VM nueva se crea ahí, misma zona que el resto del stack existente (Dnato, PostgreSQL, y la VM legacy con WSO2 4.4).
- **Qué configuran los scripts**: `PG_HOST`/`PG_PORT`/credenciales en `deploy/gcp/.env` apuntan a la instancia PostgreSQL ya existente — `install-apim.sh` los usa para reescribir `[database.apim_db]` y `[database.shared_db]` en `deployment.toml` (registro/metadata **interno** del APIM, no las DataServices de negocio).
- **Qué NO configuran los scripts**: las DataServices de negocio del MI (`AssetPlannerDataSource`, `ToolsDataSource`) están embebidas en el `.car` de `ToolsAPIProject` con su propia definición de conexión — hoy mezclan MySQL legacy y PostgreSQL (ver `doc/identity/dataservices-remediation-phase-a.md`, migración ya en curso pero no cerrada). Migrar esas conexiones es un cambio al proyecto Maven, no a la VM, y queda fuera de esta tarea.
- **Identidad/JWT**: la config de `[apim.jwt]` + Key Manager federado de Dnato (ADR-008/ADR-009) tampoco la tocan estos scripts — es clase 🔴 (identidad/seguridad). Debe aplicarse como paso separado, replicando `doc/identity/apim-keymanager-dnato.md` contra el Dnato de este mismo proyecto GCP, antes de dar de alta al primer cliente.

---

## 3. Reverse proxy + TLS

**Elegido: Caddy** (nativo, sin contenedor) por sobre nginx — Let's Encrypt automático con configuración mínima (un solo `Caddyfile` de ~15 líneas, sin certbot ni renovación manual), consistente con la prioridad de "cero curva de aprendizaje nueva" de ADR-011 #3.

- Config: [`deploy/gcp/reverse-proxy/Caddyfile`](../../deploy/gcp/reverse-proxy/Caddyfile) — enruta `mcp.cloudtrazalog.com` (TLS Let's Encrypt) → `https://127.0.0.1:8243` (Gateway del APIM, certificado self-signed interno, válido porque el salto es loopback).
- Instalación: [`deploy/gcp/setup-reverse-proxy.sh`](../../deploy/gcp/setup-reverse-proxy.sh) — repo oficial de Caddy vía `dnf`/Copr, siguiendo al pie de la letra la sección "CentOS/RHEL" de [caddyserver.com/docs/install](https://caddyserver.com/docs/install) (`dnf-plugins-core` + `dnf copr enable @caddy/caddy`). Esa página no nombra Rocky Linux explícitamente (solo Fedora/RedHat/CentOS) — Rocky es rebuild 1:1 de RHEL así que debería resolver igual, pero no está confirmado 1:1 en la doc oficial de Caddy. Verificar `caddy version` después de correr el script como parte del smoke test (paso 8).
- **9443 (consola de administración) nunca se expone** — ni el Caddyfile ni las reglas de firewall de la sección 4 lo enrutan. Acceso a `/carbon`, `/publisher`, `/devportal` solo por túnel SSH o red interna (ADR-011 #9).

---

## 4. Checklist para Rodolfo (ejecución manual)

Pasos manuales — Claude Code no tiene acceso a la consola de GCP y no ejecuta nada de esto.

**Este checklist se ejecuta en 3 lugares distintos. Cada paso dice cuál con una etiqueta:**

| Etiqueta | Qué es | Cuándo se usa |
|---|---|---|
| 🖥️ **Consola web** | `console.cloud.google.com`, clicks con el mouse | Crear la VM, ver/reservar IP, ver reglas de firewall (opcional, alternativa a los comandos) |
| ⌨️ **Cloud Shell** | Terminal integrada en la consola web (botón `>_` arriba a la derecha). No requiere instalar nada — ya viene logueada y con `gcloud` listo | Todos los comandos `gcloud` de este checklist (pasos 3 y 5) |
| 💻 **SSH en la VM** | Terminal conectada DENTRO de la VM nueva ya creada | Instalar JDK y correr los scripts de `deploy/gcp/` (pasos 6 y 7) |

### 4.0 Antes de empezar: abrir Cloud Shell (una sola vez)

1. 🖥️ Ir a [console.cloud.google.com](https://console.cloud.google.com) y loguearse con la cuenta de Trazalog.
2. 🖥️ Arriba a la izquierda, click en el selector de proyecto → buscar **"Trazalog"** → seleccionarlo. Confirmar que la barra superior queda con ese proyecto activo.
3. 🖥️ Arriba a la derecha, click en el ícono de terminal (`>_`, tooltip "Activate Cloud Shell"). Se abre una terminal abajo de la pantalla — esperar a que inicialice.
4. ⌨️ Confirmar el proyecto activo: `gcloud config get-value project` → tiene que mostrar el ID del proyecto Trazalog.

Cloud Shell queda disponible para todo el resto del checklist — no hay que repetir esto en cada paso.

### 4.1 Pasos

1. ~~Confirmar región/VPC~~ ✅ **Confirmado: `us-east1-b`** (proyecto GCP "Trazalog") — misma zona donde ya viven Dnato, PostgreSQL y la VM legacy con WSO2 4.4. Crear la VM nueva ahí.

2. 🖥️ **Consola web — crear la VM**: `Compute Engine` → `VM instances` → `Create instance`.
   - Tipo de máquina: `e2-medium`
   - Zona: `us-east1-b`
   - Imagen del sistema operativo: **Rocky Linux 9** — decisión ya tomada en IDR-001 (ver §1.1), no Ubuntu ni CentOS 7.
     - ⚠️ En el selector puede aparecer también "Rocky Linux 10 optimized for GCP with GVNIC". **No elegir la 10** — la [matriz oficial de WSO2 4.6.0](https://apim.docs.wso2.com/en/4.6.0/install-and-setup/setup/reference/product-compatibility/) solo lista Rocky Linux `8.7`/`9.3` como testeados, la 10 no figura. GVNIC no aporta nada relevante para este tamaño de VM.
   - Disco: 20 GB, tipo `pd-standard`.

3. **Reservar IP pública estática** (para que `mcp.cloudtrazalog.com` no se rompa si la VM se reinicia).
   - ⌨️ **Cloud Shell**:
     ```bash
     # 1. ver la IP efímera que GCP le asignó a la VM en el paso 2
     gcloud compute instances describe NOMBRE_VM --zone=us-east1-b \
       --format="get(networkInterfaces[0].accessConfigs[0].natIP)"

     # 2. promoverla a estática (usar la IP que devolvió el comando anterior)
     gcloud compute addresses create mcp-cloudtrazalog-ip \
       --region=us-east1 \
       --addresses=LA_IP_DEL_COMANDO_ANTERIOR
     ```
   - Alternativa 🖥️ **consola web**: `VPC network` → `IP addresses` → la IP de la VM aparece como "In use"/"Ephemeral" → botón **"Reserve Static Address"** en esa fila.

4. **DNS**: apuntar `mcp.cloudtrazalog.com` (registro A) a la IP estática del paso 3.
   - 🌐 **Panel del proveedor de DNS de `cloudtrazalog.com`** (fuera de GCP — el mismo lugar donde está configurado hoy el DNS de v2):
     - Tipo: `A`
     - Nombre/Host: `mcp`
     - Valor: la IP estática del paso 3
     - TTL: default del proveedor
   - ⌨️ **Cloud Shell** (o cualquier terminal), para verificar que propagó (puede tardar de minutos a un par de horas):
     ```bash
     dig +short mcp.cloudtrazalog.com
     ```
     Tiene que devolver la IP estática reservada.

5. **Firewall del proyecto GCP** — todo en ⌨️ **Cloud Shell**:
   - **Etiquetar la VM y abrir 80/443 solo para ella** (no "todas las instancias" — el proyecto ya tiene otras VMs como Dnato y la VM legacy 4.4, y no queremos abrirles estos puertos también):
     ```bash
     gcloud compute instances add-tags NOMBRE_VM --zone=us-east1-b --tags=mcp-gateway

     gcloud compute firewall-rules create allow-mcp-http-https \
       --network=default \
       --direction=INGRESS \
       --action=ALLOW \
       --rules=tcp:80,tcp:443 \
       --source-ranges=0.0.0.0/0 \
       --target-tags=mcp-gateway
     ```
     (si la red del proyecto no se llama `default`, chequear con `gcloud compute networks list` y ajustar `--network`)
   - **NO crear ninguna regla que abra 9443 al público.** GCP deniega todo por defecto salvo regla `ALLOW` explícita — no crear ninguna alcanza. Confirmar que no exista ya una regla vieja demasiado abierta:
     ```bash
     gcloud compute firewall-rules list --format="table(name,sourceRanges.list(),allowed[].map().firewall_rule().list(),targetTags.list())"
     ```
     Si aparece algo con `0.0.0.0/0` y un rango de puertos amplio (`0-65535` o similar), avisar antes de tocar nada.
   - **Confirmar que la VM llega a PostgreSQL/Dnato por red interna** (PostgreSQL corre en su propia VM, `traz-db-prod`, no es Cloud SQL administrado — ver `TRAZALOG_v3_MCP_ARCHITECTURE.md` §10.5). Si todas están en la red `default`, ya existe la regla `default-allow-internal` que permite el tráfico interno entre VMs del proyecto — solo falta confirmar que quedaron en la misma red:
     ```bash
     gcloud compute instances describe NOMBRE_VM --zone=us-east1-b --format="get(networkInterfaces[0].network)"
     gcloud compute instances describe NOMBRE_VM_POSTGRES --zone=us-east1-b --format="get(networkInterfaces[0].network)"
     ```
     Mismo resultado en ambos → OK. Distinto → parar y avisar (haría falta peering o una regla nueva).

6. 💻 **SSH en la VM — instalar JDK 21 Temurin** (requisito de WSO2 4.6.0). Primero conectarse: 🖥️ `Compute Engine` → `VM instances` → botón **"SSH"** al lado de la VM nueva (abre una terminal en el navegador, sin configurar claves). Una vez adentro:
   ```bash
   sudo tee /etc/yum.repos.d/adoptium.repo <<'EOF'
   [Adoptium]
   name=Adoptium
   baseurl=https://packages.adoptium.net/artifactory/rpm/rhel/$releasever/$basearch
   enabled=1
   gpgcheck=1
   gpgkey=https://packages.adoptium.net/artifactory/api/gpg/key/public
   EOF
   sudo dnf install -y temurin-21-jdk
   java -version   # debe mostrar "21.x.x"
   ```
   Fuente: [adoptium.net/installation/linux](https://adoptium.net/installation/linux/), repo RPM oficial de Adoptium. **Usar `rhel` en el `baseurl`, no `rocky`** — el path `rpm/rocky/` de Adoptium solo tiene paquetes para Rocky Linux 8 (`rpm/rocky/8/`), no existe `rpm/rocky/9/` (probado en la práctica: da 404). `rpm/rhel/9/x86_64/` sí existe y aplica igual a Rocky 9 por ser compatible 1:1 con RHEL 9. `install-apim.sh`/`install-mi.sh` (paso 7) detectan `JAVA_HOME` solos a partir de este `java` instalado y lo escriben en el unit de systemd — a diferencia de DEV (`doc/infra/wso2-install.md`), acá no alcanza con `/etc/profile.d` porque systemd no lo lee.

7. 💻 **SSH en la VM (misma sesión que el paso 6) — instalar y arrancar WSO2**:
   ```bash
   git clone <este repo> && cd traz-tools/deploy/gcp
   cp .env.example .env   # completar con los valores reales
   # descargar manualmente wso2am-4.6.0.zip y wso2mi-4.5.0.zip desde wso2.com
   # (cuenta gratuita) y el driver JDBC de PostgreSQL desde jdbc.postgresql.org,
   # dejarlos en las rutas indicadas en .env
   sudo ./install-apim.sh
   sudo ./install-mi.sh
   sudo ./setup-reverse-proxy.sh
   sudo systemctl start wso2am
   sudo systemctl start wso2mi
   ```
   Nota sobre `setup-reverse-proxy.sh`: instala Caddy vía `dnf`/Copr siguiendo la sección "CentOS/RHEL" de [caddyserver.com/docs/install](https://caddyserver.com/docs/install) — esa página no nombra Rocky Linux explícitamente (Rocky es rebuild 1:1 de RHEL, debería resolver igual, pero no está confirmado 1:1). Verificar `caddy version` en el smoke test (paso 8).

   También en esta sesión SSH, chequear `firewalld` (no confirmado 1:1 para Rocky en la doc oficial de GCP — ver nota abajo):
   ```bash
   sudo firewall-cmd --state
   # si dice "running":
   sudo firewall-cmd --list-all
   # si 80/443 no aparecen:
   sudo firewall-cmd --add-port=80/tcp --add-port=443/tcp --permanent && sudo firewall-cmd --reload
   ```
   *(La [doc oficial de GCP](https://docs.cloud.google.com/compute/docs/images/os-details) confirma para AlmaLinux/CentOS que el firewall del guest permite todo por defecto porque las reglas de la VPC lo overridean — Rocky no está listada ahí explícitamente, pero es la misma familia de imagen. Por eso este chequeo, en vez de asumirlo.)*

8. ⌨️ **Cloud Shell (o cualquier terminal, incluso tu compu) — smoke test** (equivalente al de DEV en `doc/infra/wso2-install.md` §5):
   ```bash
   curl -I https://mcp.cloudtrazalog.com
   ```
   Tiene que responder con el certificado de Let's Encrypt (no self-signed) y proxyear al Gateway del APIM.

9. **Antes de dar de alta al primer cliente** (no es parte de esta tarea, queda pendiente aparte): aplicar la config de identidad (ADR-008/009) y cerrar la migración de DataServices a PostgreSQL.

---

## 5. Preguntas abiertas

- **Costo real vs. ADR-005**: ver 1.4 — `e2-medium` (~US$24-25/mes incluyendo disco, a reconfirmar con el calculador oficial) sigue sin ser $0, pero ya fue aceptado conscientemente por Rodolfo dado el volumen de 1-2 usuarios del piloto.
- ~~Región/VPC exacta~~ **Resuelto: `us-east1-b`** (ver §2 y §4 paso 1).
- **Versión exacta del MI**: se usa `4.5.0` por ser la validada junto al APIM 4.6.0 en DEV (ver `scripts/dev/setup-mi-b4-car-deploy.sh`). Si Rodolfo prefiere subir a una versión más nueva de MI, es una decisión aparte — no se investigó compatibilidad de versiones más nuevas contra el mecanismo de identidad de ADR-009.
- **Migración de DataServices a PostgreSQL**: en curso pero no cerrada (`doc/identity/dataservices-remediation-phase-a.md`). Se detectó además que las datasources actuales (`AssetPlannerDataSource.xml`, `ToolsDataSource.xml`) tienen credenciales en texto plano commiteadas en el repo — preexistente, no introducido por esta tarea, pero vale la pena que Rodolfo lo sepa antes del cutover a producción.
