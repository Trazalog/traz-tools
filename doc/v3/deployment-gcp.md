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
- Instalación: [`deploy/gcp/setup-reverse-proxy.sh`](../../deploy/gcp/setup-reverse-proxy.sh) — repo oficial de Caddy (Cloudsmith), sin Docker.
- **9443 (consola de administración) nunca se expone** — ni el Caddyfile ni las reglas de firewall de la sección 4 lo enrutan. Acceso a `/carbon`, `/publisher`, `/devportal` solo por túnel SSH o red interna (ADR-011 #9).

---

## 4. Checklist para Rodolfo (consola de GCP)

Pasos manuales — Claude Code no tiene acceso a la consola de GCP y no ejecuta nada de esto.

1. ~~Confirmar región/VPC~~ **Confirmado: `us-east1-b`** (proyecto GCP "Trazalog") — misma zona donde ya viven Dnato, PostgreSQL y la VM legacy con WSO2 4.4. Crear la VM nueva ahí (evita latencia y cargos de tráfico inter-región/inter-zona).
2. **Crear la VM**: tipo `e2-medium`, zona `us-east1-b`, imagen Ubuntu 24.04 LTS (o la que ya se use para Dnato, por consistencia operativa), disco 20 GB pd-standard.
3. **Reservar IP pública estática** y asociarla a la VM.
4. **DNS**: apuntar `mcp.cloudtrazalog.com` (registro A) a la IP estática reservada en el paso 3.
5. **Firewall del proyecto GCP**:
   - Abrir **80/tcp** (requerido por el desafío HTTP-01 de Let's Encrypt) y **443/tcp** (tráfico público real), origen `0.0.0.0/0`.
   - **NO** abrir 9443 al público — solo alcanzable desde la red interna del proyecto o vía túnel SSH (`gcloud compute ssh --tunnel-through-iap` o similar).
   - Confirmar que el firewall interno permite que la VM llegue a PostgreSQL (5432) y a Dnato por su puerto correspondiente dentro de la misma VPC.
6. **Orden de ejecución en la VM** (una vez creada y con acceso SSH):
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
7. **Smoke test** (equivalente al de DEV en `doc/infra/wso2-install.md` §5): `curl -I https://mcp.cloudtrazalog.com` debe responder con el cert de Let's Encrypt (no self-signed), y proxyear al Gateway del APIM.
8. **Antes de dar de alta al primer cliente**: aplicar la config de identidad (ADR-008/009) y cerrar la migración de DataServices a PostgreSQL — ninguna de las dos está cubierta por esta tarea.

---

## 5. Preguntas abiertas

- **Costo real vs. ADR-005**: ver 1.4 — `e2-medium` (~US$24-25/mes incluyendo disco, a reconfirmar con el calculador oficial) sigue sin ser $0, pero ya fue aceptado conscientemente por Rodolfo dado el volumen de 1-2 usuarios del piloto.
- ~~Región/VPC exacta~~ **Resuelto: `us-east1-b`** (ver §2 y §4 paso 1).
- **Versión exacta del MI**: se usa `4.5.0` por ser la validada junto al APIM 4.6.0 en DEV (ver `scripts/dev/setup-mi-b4-car-deploy.sh`). Si Rodolfo prefiere subir a una versión más nueva de MI, es una decisión aparte — no se investigó compatibilidad de versiones más nuevas contra el mecanismo de identidad de ADR-009.
- **Migración de DataServices a PostgreSQL**: en curso pero no cerrada (`doc/identity/dataservices-remediation-phase-a.md`). Se detectó además que las datasources actuales (`AssetPlannerDataSource.xml`, `ToolsDataSource.xml`) tienen credenciales en texto plano commiteadas en el repo — preexistente, no introducido por esta tarea, pero vale la pena que Rodolfo lo sepa antes del cutover a producción.
