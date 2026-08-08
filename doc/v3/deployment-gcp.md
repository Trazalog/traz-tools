# Despliegue en GCP — VM nativa WSO2 (ADR-011)

> Implementa [ADR-011](../adr/ADR-011-gcp-deployment.md). Tarea: E7-INFRA-01/02.
> Este documento NO despliega nada — es sizing + checklist para que Rodolfo
> ejecute en su consola de GCP, más los scripts en [`deploy/gcp/`](../../deploy/gcp/).
>
> **Actualizado 2026-08-08 (E7-INFRA-05, Tarea 3.5):** §6 agrega el checklist para
> desplegar la fachada MCP (`toolsMCPAPI`/`toolsALMAPI` + el Virtual MCP Server
> unificado) a esta misma VM, una vez que ya está instalada (§1-4). Ese checklist
> incorpora todo lo aprendido en el smoke test real hecho en DEV el mismo día
> (`doc/mcp/virtual-mcp-unificado.md` §2.3/§2.8-bis/§4) para no repetir los mismos
> errores de configuración acá.

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
  APIM 4.6.0 ──registro/metadata interno en H2 embebida (local, sin red)
  MI 4.x      ──(red interna del proyecto GCP, sin VPN/peering)──> Dnato existente
```

- **Registro interno del APIM (`apim_db`/`shared_db`): H2 embebida, no PostgreSQL.** Decisión explícita de Rodolfo (2026-07-28) — ver nota de implementación en [ADR-011](../adr/ADR-011-gcp-deployment.md) punto 6. Para un piloto de 1-2 usuarios no se justificaba la complejidad de crear bases + cargar esquemas de PostgreSQL para el registro interno del propio APIM; se deja el H2 de fábrica, igual que en DEV. `install-apim.sh` **no toca** `[database.*]` en `deployment.toml`. Riesgo aceptado: si esto escala a producción real, migrar H2 → PostgreSQL más adelante es trabajo aparte, no trivial.
- **Red interna del proyecto GCP**: al estar la VM nueva y Dnato en el mismo proyecto, la conectividad es directa por IP interna — no requiere VPN ni peering (ADR-011 #6, ahora acotado a Dnato). **Zona confirmada por Rodolfo: `us-east1-b`** — la VM nueva se crea ahí, misma zona que el resto del stack existente (Dnato, PostgreSQL, y la VM legacy con WSO2 4.4).
- **Dónde sigue entrando PostgreSQL:** el PostgreSQL existente no se usa en este despliegue en absoluto por ahora — queda reservado para la futura migración de las DataServices de negocio del MI (`AssetPlannerDataSource`, `ToolsDataSource`, hoy mezclan MySQL legacy y PostgreSQL — ver `doc/identity/dataservices-remediation-phase-a.md`, migración ya en curso pero no cerrada, es un cambio al proyecto Maven, no a esta VM, y queda fuera de esta tarea).
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
| 💻 **SSH en la VM** | Terminal conectada DENTRO de la VM nueva ya creada | Instalar JDK, subir los archivos de WSO2 y correr los scripts de `deploy/gcp/` (pasos 6 a 8) |

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
   - **Confirmar que la VM llega a Dnato por red interna** (el APIM ya no usa PostgreSQL en este despliegue — ver §2 — así que no hace falta verificar conectividad contra esa VM para esta tarea). Si todas están en la red `default`, ya existe la regla `default-allow-internal` que permite el tráfico interno entre VMs del proyecto — solo falta confirmar que quedaron en la misma red:
     ```bash
     gcloud compute instances describe NOMBRE_VM --zone=us-east1-b --format="get(networkInterfaces[0].network)"
     gcloud compute instances describe NOMBRE_VM_DNATO --zone=us-east1-b --format="get(networkInterfaces[0].network)"
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
   Fuente: [adoptium.net/installation/linux](https://adoptium.net/installation/linux/), repo RPM oficial de Adoptium. **Usar `rhel` en el `baseurl`, no `rocky`** — el path `rpm/rocky/` de Adoptium solo tiene paquetes para Rocky Linux 8 (`rpm/rocky/8/`), no existe `rpm/rocky/9/` (probado en la práctica: da 404). `rpm/rhel/9/x86_64/` sí existe y aplica igual a Rocky 9 por ser compatible 1:1 con RHEL 9. `install-apim.sh`/`install-mi.sh` (paso 8) detectan `JAVA_HOME` solos a partir de este `java` instalado y lo escriben en el unit de systemd — a diferencia de DEV (`doc/infra/wso2-install.md`), acá no alcanza con `/etc/profile.d` porque systemd no lo lee.

7. **Conseguir los 2 archivos que necesitan los scripts** (WSO2 no deja descargarlos directo con `wget` desde la VM — hay que bajarlos con el navegador y después subirlos). *(Antes había un tercer archivo, el driver JDBC de PostgreSQL — ya no hace falta: el registro interno del APIM usa H2 embebida, ver §2.)*

   - 🌐 **En tu computadora** (navegador normal, no en la VM):
     - API Manager: [wso2.com/products/downloads](https://wso2.com/products/downloads/) → buscar "API Manager" → **"Previous Releases"** → versión **4.6.0** → completar el formulario (email + aceptar la licencia — no hace falta contraseña ni instalar nada) → descarga `wso2am-4.6.0.zip`.
     - Micro Integrator: misma página → "WSO2 Integrator: MI" → **"Previous Releases"** → versión **4.5.0** → mismo formulario → descarga `wso2mi-4.5.0.zip`.
     - Los 2 quedan en la carpeta de Descargas de tu computadora.
   - 💻 **En la ventana de SSH de la VM** (la misma del paso 6): arriba a la derecha de esa ventana hay un ícono de **engranaje ⚙️** → **"Upload file"** → elegir cada uno de los 2 archivos desde tu carpeta de Descargas, uno por vez. Quedan guardados en tu home dentro de la VM (`~`).
   - 💻 **Seguir en la misma sesión SSH** — mover los archivos a las rutas que usa `.env` y confirmar que llegaron:
     ```bash
     sudo mkdir -p /opt/wso2/dist
     sudo mv ~/wso2am-4.6.0.zip /opt/wso2/dist/
     sudo mv ~/wso2mi-4.5.0.zip /opt/wso2/dist/
     ls /opt/wso2/dist/
     ```

8. 💻 **SSH en la VM (misma sesión) — instalar y arrancar WSO2**:
   ```bash
   git clone <este repo> && cd traz-tools/deploy/gcp
   cp .env.example .env   # completar con los valores reales (incluidas las rutas del paso 7)
   sudo ./install-apim.sh
   sudo ./install-mi.sh
   sudo ./setup-reverse-proxy.sh
   sudo systemctl start wso2am
   sudo systemctl start wso2mi
   ```
   Nota sobre `setup-reverse-proxy.sh`: instala Caddy vía `dnf`/Copr siguiendo la sección "CentOS/RHEL" de [caddyserver.com/docs/install](https://caddyserver.com/docs/install) — esa página no nombra Rocky Linux explícitamente (Rocky es rebuild 1:1 de RHEL, debería resolver igual, pero no está confirmado 1:1). Verificar `caddy version` en el smoke test (paso 9).

   También en esta sesión SSH, chequear `firewalld` (no confirmado 1:1 para Rocky en la doc oficial de GCP — ver nota abajo):
   ```bash
   sudo firewall-cmd --state
   # si dice "running":
   sudo firewall-cmd --list-all
   # si 80/443 no aparecen:
   sudo firewall-cmd --add-port=80/tcp --add-port=443/tcp --permanent && sudo firewall-cmd --reload
   ```
   *(La [doc oficial de GCP](https://docs.cloud.google.com/compute/docs/images/os-details) confirma para AlmaLinux/CentOS que el firewall del guest permite todo por defecto porque las reglas de la VPC lo overridean — Rocky no está listada ahí explícitamente, pero es la misma familia de imagen. Por eso este chequeo, en vez de asumirlo.)*

   **Si `systemctl start wso2am`/`wso2mi` falla con `Failed to locate executable ... Permission denied`** (confirmado en la práctica): es **SELinux** (viene `Enforcing` por defecto en las imágenes Rocky de GCP). `install-apim.sh`/`install-mi.sh` descomprimen el `.zip` en un directorio temporal y lo mueven (`mv`) a `/opt/wso2/...` — el `mv` no actualiza el contexto de SELinux, así que los binarios quedan con la etiqueta del temporal (`tmp_t`, no ejecutable), aunque el `chmod +x` esté bien aplicado. Los scripts ya corren `restorecon -R` después del `chown` para evitar esto — si de todos modos aparece, confirmar y arreglar a mano:
   ```bash
   getenforce
   sudo ausearch -m avc -ts recent -i 2>/dev/null | tail -20   # buscar "denied"
   sudo restorecon -Rv /opt/wso2/wso2am-4.6.0
   sudo restorecon -Rv /opt/wso2/wso2mi-4.5.0
   sudo systemctl start wso2am
   sudo systemctl start wso2mi
   ```

9. ⌨️ **Cloud Shell (o cualquier terminal, incluso tu compu) — smoke test** (equivalente al de DEV en `doc/infra/wso2-install.md` §5):
   ```bash
   curl -I https://mcp.cloudtrazalog.com
   ```
   Tiene que responder con el certificado de Let's Encrypt (no self-signed) y proxyear al Gateway del APIM.

   **Verificar que ambos servicios y sus puertos quedaron arriba** — 💻 en la sesión SSH de la VM:
   ```bash
   sudo systemctl status wso2am wso2mi --no-pager
   sudo ss -tlnp | grep -E ':(9443|8280|8243|8290|8253|9164)\b'
   ```
   Deberían aparecer los 6 puertos escuchando (3 del APIM, 3 del MI — no colisionan entre sí, el MI ya viene con sus propios puertos de fábrica corridos, distintos de los del APIM, precisamente para poder convivir en la misma máquina sin configurar nada).

   **Consolas del APIM** (mismo patrón que DEV, `doc/infra/wso2-install.md` §5 — solo alcanzables desde dentro de la VM o por túnel SSH, **nunca públicamente**, ADR-011 #9):
   ```bash
   curl -k https://localhost:9443/carbon      # Admin Console
   curl -k https://localhost:9443/publisher   # Publisher
   curl -k https://localhost:9443/devportal   # Developer Portal
   curl -k https://localhost:8243             # Gateway (lo mismo que expone Caddy en :443 públicamente)
   ```
   Para verlas en el navegador de tu computadora (no solo con `curl`), hace falta un túnel SSH, por ejemplo:
   ```bash
   gcloud compute ssh NOMBRE_VM --zone=us-east1-b --tunnel-through-iap -- -L 9443:localhost:9443
   ```
   y después abrir `https://localhost:9443/carbon` en tu propio navegador (certificado self-signed — el navegador va a advertir, es esperado).

   **El MI no tiene una consola web como el APIM** (no es Carbon con UI, es un runtime liviano). Se verifica que está arriba con el `systemctl status`/`ss` de arriba, los logs (`tail -f /opt/wso2/wso2mi-4.5.0/repository/logs/wso2carbon.log`), o pegándole directo a un endpoint desplegado (ej. `curl http://localhost:8290/<contexto-del-API>`, igual que en DEV — ver `scripts/dev/setup-mi-b4-car-deploy.sh`). El puerto 9164 es su Management API (REST, para tooling — no para navegar).

10. **Antes de dar de alta al primer cliente** (no es parte de esta tarea, queda pendiente aparte): aplicar la config de identidad (ADR-008/009) y cerrar la migración de DataServices a PostgreSQL.

---

## 5. Preguntas abiertas

- **Costo real vs. ADR-005**: ver 1.4 — `e2-medium` (~US$24-25/mes incluyendo disco, a reconfirmar con el calculador oficial) sigue sin ser $0, pero ya fue aceptado conscientemente por Rodolfo dado el volumen de 1-2 usuarios del piloto.
- ~~Región/VPC exacta~~ **Resuelto: `us-east1-b`** (ver §2 y §4 paso 1).
- **Versión exacta del MI**: se usa `4.5.0` por ser la validada junto al APIM 4.6.0 en DEV (ver `scripts/dev/setup-mi-b4-car-deploy.sh`). Si Rodolfo prefiere subir a una versión más nueva de MI, es una decisión aparte — no se investigó compatibilidad de versiones más nuevas contra el mecanismo de identidad de ADR-009.
- **Migración de DataServices a PostgreSQL**: en curso pero no cerrada (`doc/identity/dataservices-remediation-phase-a.md`). Se detectó además que las datasources actuales (`AssetPlannerDataSource.xml`, `ToolsDataSource.xml`) tienen credenciales en texto plano commiteadas en el repo — preexistente, no introducido por esta tarea, pero vale la pena que Rodolfo lo sepa antes del cutover a producción.

---

## 6. Despliegue de la fachada MCP a esta VM (E7-INFRA-05, Tarea 3.5)

Prerequisito de esta sección: la VM ya está instalada y funcionando (§1-4 de este documento, E7-INFRA-01/02, ya cerrado). Acá se agrega **lo nuevo**: llevar `toolsMCPAPI`/`toolsALMAPI` (Bloque 3, ya mergeados en `develop-v3`) y el Virtual MCP Server unificado a esta misma VM.

### 6.0 Prerequisito de identidad — leer antes de empezar

**El paso de verificación de aislamiento (§6.5) NO va a funcionar hasta que E7-INFRA-03 (Bloque 2 — config de identidad ADR-008/009 contra el Dnato de este mismo proyecto GCP) esté aplicado.** A la fecha de este documento, E7-INFRA-03 todavía no se ejecutó (ver `doc/v3/STATE.md` → Bloqueos). Los pasos §6.1-6.4 (desplegar el CAR, publicar la API, generar el MCP Server) se pueden hacer igual sin ese prerequisito — solo la verificación real con JWT de Dnato (§6.5-6.6) lo necesita. Si llegás a §6.5 y da 401/403 con un JWT que debería ser válido, lo primero a chequear es si `[[apim.jwt.issuer]]` para `trazalog-dnato` está configurado en el `deployment.toml` de **esta** VM (no asumir que se copió solo desde DEV).

**El checklist concreto de E7-INFRA-03 está en §7 de este mismo documento.** Punto importante que no estaba claro hasta ahora: esa configuración **no viaja con el código**. `deployment.toml` no está versionado en git (cambia por ambiente — DEV, esta VM, y a futuro PROD tienen cada uno el suyo, con su propia URL de JWKS). Desplegar `develop-v3` a ningún servidor — ni al de Dnato ni a esta VM — aplica esos cambios solo: son ediciones manuales de un archivo de config local, siempre. Ver §7.0 para el detalle completo.

### 6.1 Artefacto desplegable — el `.car`

Se genera igual que en DEV, no hay nada nuevo que preparar aparte del código ya mergeado:

```bash
cd _backend/api/ToolsAPIProject/ToolsAPIProject
./mvnw clean install
# target/ToolsAPIProject_1.0.0.car
```

Verificado en esta tarea (2026-08-08): el build corre limpio contra el estado actual de `develop-v3` (`BUILD SUCCESS`). El CAR incluye `toolsMCPAPI`, `toolsALMAPI`, `toolsMANAPI`, `toolsBPMAPI`, `toolsCOREAPI` y todos los DataServices — incluida la corrección de `case_id` en `MANDataService.dbs` (PR #416, ya mergeada). No hay un artefacto separado para la API/MCP Server del lado del APIM — esos se publican interactivamente en el Publisher (§6.3), igual que en DEV.

### 6.2 Desplegar el CAR en el MI de la VM

💻 SSH a la VM (mismo acceso que §4 paso 6):

```bash
cd ~/traz-tools   # el clone que ya existe en la VM desde el setup inicial (§4 paso 8)
git checkout develop-v3 && git pull origin develop-v3
cd _backend/api/ToolsAPIProject/ToolsAPIProject
./mvnw clean install

cp target/ToolsAPIProject_1.0.0.car /opt/wso2/wso2mi-4.5.0/repository/deployment/server/carbonapps/
sudo systemctl restart wso2mi
sudo journalctl -u wso2mi -f   # confirmar "Successfully Deployed Carbon Application" antes de seguir
```

Confirmar que el recurso existe localmente en la VM antes de tocar el APIM (un `503 identity_missing` acá es la respuesta ESPERADA — confirma que `toolsMCPAPI` está desplegado y corriendo, solo falta el JWT del gateway):

```bash
curl http://localhost:8290/tools/mcp/mcp/man/equipos
```

### 6.3 Publicar la API + generar el MCP Server en el Publisher de esta VM

Seguir `doc/mcp/virtual-mcp-unificado.md` §2 completo — ya corregido con todo lo que falló la primera vez en DEV (2026-08-08). Puntos que cambian respecto a DEV:

- **Acceso al Publisher:** el puerto 9443 nunca se expone públicamente (ADR-011 #9). Entrar por túnel SSH:
  ```bash
  gcloud compute ssh NOMBRE_VM --zone=us-east1-b --tunnel-through-iap -- -L 9443:localhost:9443
  ```
  y ahí sí `https://localhost:9443/publisher` desde tu propio navegador.
- **Endpoint (§2.3 de `virtual-mcp-unificado.md`):** Production/Sandbox URL = `http://localhost:8290/tools/mcp` — APIM y MI conviven en la misma VM (igual que en DEV), **no** usar ninguna IP interna de otra VM del proyecto. Configurar en los DOS artefactos (la API y el MCP Server generado) — son artefactos separados, generar el MCP Server desde la API no copia el endpoint (encontrado en DEV el mismo día, ver la nota en §2.3 de ese documento).
- **Seguridad (§2.4):** no tocar el selector de Key Managers (Dnato no se registra ahí — es `[[apim.jwt.issuer]]` en `deployment.toml`, ver §6.0). Desactivar `Enable Subscription Validation`.
- **Suscripción (§2.8-bis):** crear o reusar una aplicación equivalente a `TrazalogDnatoMCP` en el DevPortal de esta VM y suscribirla al MCP Server nuevo. Sin este paso, las 9 tools dan `900908` aunque todo el resto esté bien — fue el primer bloqueo real que apareció en DEV.
- **Nombre/contexto:** a elección de Rodolfo — no hay obligación de repetir `Trazalog MCP Server`/`/trazalog/mcp` (lo que terminó usándose en DEV), pero mantener el mismo nombre entre ambientes evita confusión al comparar configuraciones.

### 6.4 Verificar el flujo OAuth end-to-end contra `mcp.cloudtrazalog.com`

Requiere §6.0 resuelto (identidad de esta VM aplicada) y un JWT real emitido por el Dnato de este mismo proyecto GCP — no sirve el JWKS local de DEV (`scripts/dev/dnato-jwks-server.py`, ese es solo para el JWKS falso de DEV).

```bash
HOST="mcp.cloudtrazalog.com"
CONTEXTO="<el que se haya elegido en §6.3>"   # ej. trazalog/mcp
JWT="<JWT real de Dnato, este proyecto GCP>"

curl -X POST "https://$HOST/$CONTEXTO/1.0/mcp" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"gcp-smoke-test","version":"1.0"}},"id":1}'

curl -X POST "https://$HOST/$CONTEXTO/1.0/mcp" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $JWT" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"man_get_equipos","arguments":{}},"id":2}'
```

### 6.5 Verificación de aislamiento multi-tenant (2 empresas)

Mismo patrón que el smoke test que se hizo en DEV el 2026-08-08 (`virtual-mcp-unificado.md` §4): un JWT de empresa A y uno de empresa B, misma tool de lectura (ej. `man_get_equipos`), confirmar que cada uno ve solo los datos de su propia empresa y ninguno ve datos del otro.

### DoD de esta tarea (E7-INFRA-05)

- [ ] CAR reconstruido y desplegado en el MI de la VM (§6.2)
- [ ] API + MCP Server publicados en el APIM de la VM (§6.3)
- [ ] Suscripción de la aplicación al MCP Server confirmada
- [ ] `initialize`/`tools/list` responden vía `https://mcp.cloudtrazalog.com`
- [ ] Al menos una tool de cada módulo (`man_*`, `alm_*`) probada con `tools/call` real
- [ ] Aislamiento de 2 empresas confirmado contra la URL pública
- [ ] Esta sección actualizada marcando el despliegue como hecho, con fecha real
---

## 7. Configuración de identidad en esta VM (E7-INFRA-03, Bloque 2)

### 7.0 Por qué esto es un paso aparte — no viaja con el código

**`deployment.toml` (donde vive toda la config de identidad — `[apim.jwt]`, `[[apim.jwt.issuer]]`) nunca está versionado en git.** Es un archivo de configuración local de cada instancia de APIM, y cambia por ambiente: el `deployment.toml` de DEV apunta al JWKS local de DEV (`http://localhost:8090/...`, servido por `scripts/dev/dnato-jwks-server.py`, un shim que solo existe para pruebas), el de esta VM tiene que apuntar al JWKS del Dnato real de este mismo proyecto GCP, y el de una futura VM de PROD tendría el suyo propio.

**Por eso desplegar el contenido de `develop-v3` — a esta VM, o a cualquier servidor, incluido el de Dnato — no aplica ninguno de los cambios de `doc/identity/apim-keymanager-dnato.md`.** Ese documento describe ediciones manuales de `deployment.toml`, hechas y verificadas en DEV; acá se replican esas mismas ediciones, a mano, contra el `deployment.toml` de esta VM. No hay ningún artefacto en el repo que las traiga automáticamente.

> **Corrección 2026-08-08:** la primera versión de esta sección decía "tampoco hace falta desplegar nada en el servidor de Dnato". **Eso estaba mal** — ver §7.0-bis. `dnato-jwt-prereqs.md` confirmó que Dnato **no necesita código nuevo** para esta federación porque ese código **ya se escribió**, en `traz-comp-dnato` rama `develop-v3` (E9-IDENT-03/04) — no porque no hiciera falta ningún despliegue. Si el servidor de Dnato de este proyecto GCP corre `develop` o `master` (no `develop-v3`), ese código simplemente no está ahí todavía.

### 7.0-bis Prerequisito real: `traz-comp-dnato` rama `develop-v3` en el servidor de Dnato

**Sí hace falta desplegar algo en el servidor de Dnato — y no es este repo, es `traz-comp-dnato`.** Confirmado revisando ese repo directamente: los commits que implementan la emisión de JWT, el login OAuth 2.1 PKCE, y el endpoint JWKS están **solo en `develop-v3`**, no en `develop` (soporte v2) ni en `master` (producción v2):

```bash
# Verificado en traz-comp-dnato:
git log --all --oneline --grep="jwt\|jwks\|oauth" -i
# 999d9a6 feat(identity): empr_id en JWT + login OAuth Dnato [E9-IDENT-03 / ADR-008]
# 9516d30 feat(identity): add RFC 8414 AS metadata endpoint + configurable issuer for MCP discovery
# 3da3f77 feat(identity): add OAuth 2.1 PKCE login screen in Dnato [E9-IDENT-04]
# 5b5d1d6 feat(identity): add OAuth JWT issuance in Dnato with empr_id claim [E9-IDENT-03]
# (todos solo en develop-v3, confirmado con git merge-base --is-ancestor)
```

Si el servidor de Dnato en este proyecto GCP (el que está "en la misma red donde está la VM de MCP", en otro server) corre `develop` o `master` de `traz-comp-dnato`, **hace falta desplegar `develop-v3` ahí** — el checkout de código en sí (`git checkout develop-v3 && git pull`, reemplazando el vhost/deploy que corresponda para ese ambiente) es responsabilidad de `traz-comp-dnato` y sus propias convenciones de deploy, no de este repo.

**Con el código desplegado, todavía faltan pasos manuales — mismo patrón que `deployment.toml` (§7.0): nada de esto viaja con el `git checkout` solo.** Comandos concretos, tomados de `traz-comp-dnato/doc/identity/jwt-keys-setup.md` y verificados contra el código real de `develop-v3` (2026-08-08):

```bash
# 0. En el checkout de traz-comp-dnato en el servidor de Dnato
cd /ruta/real/a/traz-comp-dnato

# 1. Dependencias PHP (firebase/php-jwt, agregado en develop-v3)
composer install --no-dev --optimize-autoloader

# 2. Par de claves RS256 — generar EN ESTE SERVIDOR, no copiar el de DEV
mkdir -p application/config/keys
openssl genrsa -out application/config/keys/jwt_private.pem 2048
openssl rsa -in application/config/keys/jwt_private.pem -pubout -out application/config/keys/jwt_public.pem
openssl rsa -in application/config/keys/jwt_private.pem -check
chmod 600 application/config/keys/jwt_private.pem
chmod 644 application/config/keys/jwt_public.pem
chown <usuario-de-apache>:<grupo-de-apache> application/config/keys/*.pem   # confirmar cuál aplica en ese server

# 3. Variables de entorno vía .htaccess (Apache SetEnv — mismo mecanismo que DEV/ngrok)
cp .htaccess.example .htaccess
# editar .htaccess a mano con los valores reales (ver bloque de abajo)

# 4. Migración — PostgreSQL (TEST/PROD usan Postgres, no MySQL)
psql -h <host-postgres> -U <usuario> -d <basededatos> \
  -c "CREATE SCHEMA IF NOT EXISTS seg;" \
  -f doc/identity/migrations/001_create_seg_oauth_codes.sql

# 5. Reiniciar Apache
sudo systemctl restart httpd      # Rocky/RHEL
# sudo systemctl restart apache2  # si ese server es Debian/Ubuntu

# 6. Verificar
curl -s https://<host-real-de-dnato>/oauth/.well-known/jwks.json | python3 -m json.tool
php index.php cli issue_test_token admin@empresa.com 1
```

Contenido real del `.htaccess` (paso 3 — reemplazar los placeholders con datos reales del server, no quedan resueltos solos):

```apache
SetEnv DNATO_PUBLIC_URL "https://<host-real-de-dnato>/traz-comp-dnato"
SetEnv DNATO_ISSUER "https://<host-real-de-dnato>/traz-comp-dnato/oauth"
SetEnv JWT_PRIVATE_KEY_PATH "/ruta/real/a/traz-comp-dnato/application/config/keys/jwt_private.pem"
SetEnv JWT_PUBLIC_KEY_PATH "/ruta/real/a/traz-comp-dnato/application/config/keys/jwt_public.pem"
SetEnv JWT_AZP "<Consumer Key generado en §7.4 — no existe todavía en este paso>"
```

> **Corrección 2026-08-08 sobre `JWT_AZP`:** una versión anterior de este checklist decía "confirmar que `oauth_clients.php` tiene registrada la aplicación... equivalente al `azp`/`consumerKey`". Es impreciso — leyendo `application/config/jwt.php` directamente: `oauth_clients.php` es un archivo distinto (registra a Claude.ai como cliente OAuth válido con su `redirect_uri` fijo, **no cambia por ambiente, no hace falta tocarlo**). El valor `azp` que de verdad importa se setea vía la variable de entorno `JWT_AZP` de arriba, y tiene que ser el **Consumer Key real de la Application del APIM de esta VM** — **§7.4 abajo tiene los clicks exactos de dónde sale ese valor** (no existe todavía, se genera al crear la app).

**No hace falta tocar `oauth_clients.php`** — ya tiene registrado a Claude.ai (`trazalog-mcp-connector`, redirect fijo `https://claude.ai/api/mcp/auth_callback`), y ese valor es el mismo en cualquier ambiente.

> Esto es trabajo de `traz-comp-dnato`, no de `traz-tools` — la CLAUDE.md de este repo lo marca explícitamente ("Login, tokens, JWT, OAuth → traz-comp-dnato"). Esta sección solo señala que existe y qué falta, para que no se pierda como dependencia; los detalles completos viven en los docs de ese otro repo (`doc/identity/jwt-keys-setup.md`, `doc/identity/oauth-login-flow.md`, `doc/identity/token-issuance.md`, todos en `develop-v3`).

### 7.1 Qué hay que replicar — mismo mecanismo que DEV, otro `deployment.toml`

Adaptado de `doc/identity/apim-keymanager-dnato.md` §3, aplicado al `deployment.toml` de **esta VM** (no el de DEV):

```toml
[apim.jwt]
enable = true
header = "X-JWT-Assertion"
convert_dialect = false

[[apim.jwt.issuer]]
name = "<el mismo valor exacto que DNATO_ISSUER en el .htaccess de Dnato, §7.0-bis — ej. https://host-de-dnato/traz-comp-dnato/oauth>"
consumer_key_claim = "azp"
scopes_claim = "scope"
jwks.url = "<URL real del JWKS de Dnato en este proyecto GCP — ver 7.2>"

[[apim.jwt.issuer.claim_mapping]]
remote_claim = "empr_id"
local_claim = "empr_id"
[[apim.jwt.issuer.claim_mapping]]
remote_claim = "empr_id_mysql"
local_claim = "empr_id_mysql"
```

> **Corrección 2026-08-08:** `name` NO es el string fijo `"trazalog-dnato"` — ese valor es el que usa el shim de pruebas de DEV (`scripts/dev/dnato-jwks-server.py` + `mint-dnato-jwt.py`), no el Dnato real. `jwt.php` (en `traz-comp-dnato`) arma el claim `iss` del JWT real a partir de la variable de entorno `DNATO_ISSUER` (default `http://localhost/oauth` si no se setea) — `name` acá tiene que coincidir EXACTAMENTE con ese valor, o el gateway va a rechazar los tokens reales de Dnato con "issuer mismatch" aunque todo el resto esté bien configurado.

Reiniciar APIM después de editar: `sudo systemctl restart wso2am`.

### 7.2 Antes de aplicar esto — confirmar, no asumir

- [ ] **`traz-comp-dnato` `develop-v3` desplegado en el servidor de Dnato de este proyecto** (§7.0-bis) — sin esto, no hay JWKS real que apuntar, ni login OAuth que emita los JWT.
- [ ] Claves RS256 generadas en ESE servidor, migración corrida, `.htaccess` con `JWT_AZP` seteado al consumer key real (checklist de §7.0-bis).
- [ ] **URL real del JWKS** (`https://<host-de-dnato>/oauth/.well-known/jwks.json`, confirmado el endpoint en §7.0-bis — reemplaza el placeholder de §7.1).
- [ ] Confirmar que ese endpoint es alcanzable desde esta VM — por HTTPS con cadena válida, o por HTTP si están en la misma red interna/VPC del proyecto (`apim-keymanager-dnato.md` §2, Opción B — nunca exponer el JWKS por HTTP públicamente).
- [ ] Confirmar el `kid` de la clave activa que quedó en `application/config/jwt.php` de ese despliegue — no necesariamente el mismo `dnato-rs256-v1` que usa el shim de DEV (cada par de claves generado en §7.0-bis puede tener su propio `kid`).
- [ ] **Si alguno de los puntos anteriores no se puede confirmar sin acceso al servidor/config de Dnato de este proyecto: PARAR y consultar antes de aplicar §7.1.** No asumir que ya está desplegado o configurado solo porque el mecanismo ya funciona en DEV — son servidores y despliegues distintos.

### 7.3 Verificar accesibilidad del JWKS desde la VM

Igual que `apim-keymanager-dnato.md` §2 — ejecutado **desde dentro de la VM** (no desde tu compu):

```bash
curl -s <URL del JWKS de 7.2> | python3 -m json.tool
```

### 7.4 Aplicación + suscripción en el DevPortal de esta VM

Mismo patrón que el que se usó para destrabar el smoke test de DEV (`virtual-mcp-unificado.md` §2.8-bis), acá con los clicks concretos porque en DEV la app ya existía de Sprint 2 y nunca hizo falta documentar cómo se crea:

1. `https://localhost:9443/devportal` (mismo túnel SSH de §6.3).
2. Menú lateral → **Applications** → **+ Add New Application** (o **Create Application**).
3. Nombre (ej. `TrazalogDnatoMCP-GCP`), Per Token Quota: `Unlimited` → **Save**.
4. Dentro de la app → pestaña **Production Keys** (o **Credentials**) → **Generate Keys**.
5. Copiar el **Consumer Key** que aparece — **ese es el valor que va en `JWT_AZP`** (§7.0-bis, `.htaccess` de Dnato).
6. Misma app → pestaña **Subscriptions** → elegir la API/MCP Server desplegado en §6 (ej. `Trazalog MCP Server`) → suscribir con policy `Unlimited`.

Sin el paso 6, las tools dan `900908` aunque el resto de la identidad esté bien configurado — fue el primer bloqueo real que apareció en DEV el mismo día. Sin el paso 5 (o con el `JWT_AZP` desactualizado), los JWT que emite Dnato no van a tener el `azp` que esta app espera, y la subscription validation los va a rechazar igual.

### 7.5 Verificar que funciona

Repetir §6.4 (verificación OAuth) y §6.5 (aislamiento) de este mismo documento — con la identidad ya configurada, ahora sí deberían pasar en verde.

### DoD de esta sección (E7-INFRA-03)

- [ ] `deployment.toml` de esta VM actualizado con `[[apim.jwt.issuer]]` para `trazalog-dnato`, apuntando al JWKS real de este proyecto GCP
- [ ] JWKS verificado accesible desde la VM
- [ ] Aplicación + suscripción al MCP Server creadas en el DevPortal de esta VM
- [ ] §6.4/§6.5 confirmados en verde con identidad real (no la de DEV)
- [ ] Esta sección actualizada con el resultado real, fecha, y la URL de JWKS usada
