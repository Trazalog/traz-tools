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

**Conclusión:** correr APIM + MI + reverse proxy + SO en la misma VM necesita, como piso real, **RAM(APIM oficial) + RAM(MI liviano) + margen de SO/red** ≈ 4 GB + 1 GB + 1-2 GB ≈ **6-7 GB mínimo**, no los 4 GB que alcanzarían para el APIM solo.

### 1.2 Comparación de tiers E2 (specs verificadas contra `docs.cloud.google.com`)

| Tier | vCPU | RAM | Precio aprox.* (on-demand, us-central1) | ¿Aguanta el stack? |
|---|---|---|---|---|
| `e2-micro` | 2 vCPU compartidas (0.25 sustenido) | **1 GB** | Cubierto por Always Free (ver 1.3) | ❌ No. Por debajo del mínimo oficial del APIM solo (4 GB) |
| `e2-small` | 2 vCPU compartidas (0.5 sustenido) | **2 GB** | ≈ US$12-15/mes | ❌ No. La mitad del mínimo oficial del APIM solo |
| `e2-medium` | 2 vCPU compartidas (1.0 sustenido) | **4 GB** | ≈ US$24-25/mes | ⚠️ Al límite exacto del mínimo oficial del APIM **solo**, sin margen para el MI, el reverse proxy, sshd ni el SO. Riesgo real de OOM/lentitud — no recomendado para un despliegue de cara al cliente |
| **`e2-standard-2`** | **2 vCPU dedicadas** | **8 GB** | ≈ US$48-52/mes | ✅ Sí. Cubre el mínimo oficial del APIM con margen, el MI en su heap liviano, y deja ~3-4 GB para SO/reverse proxy/monitoreo |

\* Precios de referencia obtenidos de trackers de terceros (economize.cloud, cloudprice.net, vantage.sh) al momento de esta investigación (2026-07-21). **Cambian seguido y varían por región** — reconfirmar el número exacto en [cloud.google.com/products/calculator](https://cloud.google.com/products/calculator) antes de aprobar el gasto. No son los precios oficiales citados textualmente, son una referencia de orden de magnitud.

### 1.3 Free tier — verificado contra la doc oficial

Texto verbatim de la [documentación oficial Always Free](https://docs.cloud.google.com/free/docs/free-cloud-features) (consultada 2026-07-21):

> "1 non-preemptible `e2-micro` VM instance per month in one of the following US regions: Oregon: `us-west1`. Iowa: `us-central1`. South Carolina: `us-east1`." + "30 GB-months standard persistent disk" + "1 GB of outbound data transfer from North America... per month."

**El free tier solo cubre `e2-micro` (1 GB RAM)**, que según 1.1 es insuficiente incluso para el APIM solo (necesita 4 GB documentados por WSO2). `e2-small` y `e2-medium` **no están cubiertos** por Always Free bajo ninguna condición actual. No hay forma de correr este stack a costo $0 en Compute Engine nativo.

### 1.4 Decisión de sizing

**Tier elegido: `e2-standard-2` (2 vCPU, 8 GB RAM).**

Justificación: es el primer tier que supera el mínimo oficial documentado por WSO2 para el APIM (4 GB) dejando margen real para el MI, el reverse proxy (Caddy) y el sistema operativo — `e2-medium` empata justo con el piso del APIM solo, sin ningún margen, lo cual es un riesgo inaceptable para el primer despliegue de cara a un cliente. El tipo de máquina es cambiable sin reinstalar (ADR-011, riesgo aceptado "sizing ajustado" — primer movimiento ante problemas de memoria es subir de tier).

**⚠️ Punto que requiere confirmación explícita de Rodolfo antes de crear la VM:**
ADR-005 establece costo incremental **$0 hasta 2027**. El sizing mínimo viable real (`e2-standard-2`) **no es gratuito** — ronda los US$48-52/mes (a reconfirmar con el calculador oficial). El free tier de Compute Engine no alcanza para este stack bajo ninguna combinación verificada. Esto es una excepción parcial a ADR-005 que el sizing técnico no puede evitar — se documenta acá para que sea una decisión consciente y no un descubrimiento post-facto en la factura de GCP.

### 1.5 Reparto de heap propuesto (`e2-standard-2`, 8 GB total)

| Proceso | `-Xms` | `-Xmx` | Nota |
|---|---|---|---|
| APIM | 2g | 3g | Prioridad de RAM (ADR-011 #4). Deja margen sobre el mínimo oficial de 2 GB heap |
| MI | 256m | 768m | Cerca del default de fábrica (`256m`/`1024m`); se recorta el `-Xmx` levemente para dejarle más margen al APIM |
| SO + Caddy + sshd + monitoreo | — | — | Resto (~3-4 GB) sin asignar a heap, disponible como colchón |

Configurable en [`deploy/gcp/.env`](../../deploy/gcp/.env.example) (`APIM_XMS`/`APIM_XMX`/`MI_XMS`/`MI_XMX`) sin tener que reinstalar — volver a correr `install-apim.sh` / `install-mi.sh` reaplica la config sobre una instalación existente.

### 1.6 Disco

Ambos productos + logs necesitan holgadamente menos que los 10 GB mínimos que documenta WSO2 para el APIM solo. Se recomienda **30 GB pd-balanced** (o pd-standard si se prioriza costo sobre IOPS) — cubre APIM + MI + logs con margen para varios meses de crecimiento, a un costo marginal (unos pocos dólares/mes, verificar en el calculador).

---

## 2. Cómo conecta la VM a lo que ya existe

```
VM GCP nueva (e2-standard-2, solo WSO2 nativo)
  APIM 4.6.0 ──jdbc:postgresql──> PostgreSQL existente (registro/metadata interno: apim_db, shared_db)
  MI 4.x      ──(red interna del proyecto GCP, sin VPN/peering)──> Dnato existente
```

- **Red interna del proyecto GCP**: al estar la VM nueva, PostgreSQL y Dnato en el mismo proyecto, la conectividad es directa por IP interna — no requiere VPN ni peering (ADR-011 #6). Confirmar con Rodolfo el rango/subred donde viven Dnato y PostgreSQL hoy, para crear la VM nueva en la misma red (VPC) y, si aplica, la misma región (ver pregunta abierta en 4).
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

1. **Confirmar región/VPC** donde ya viven Dnato y PostgreSQL en el proyecto GCP actual, y crear la VM nueva en esa misma región/red (evita latencia y cargos de tráfico inter-región).
2. **Crear la VM**: tipo `e2-standard-2`, imagen Ubuntu 24.04 LTS (o la que ya se use para Dnato, por consistencia operativa), disco 30 GB pd-balanced.
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

- **Costo real vs. ADR-005**: ver 1.4 — el sizing mínimo viable no es gratis. Requiere aprobación explícita de Rodolfo del gasto mensual (~US$50-60/mes incluyendo disco, a reconfirmar con el calculador oficial al momento de crear la VM).
- **Región/VPC exacta** donde viven hoy Dnato y PostgreSQL — necesaria para decidir la región de la VM nueva (no investigable sin acceso a la consola de GCP de Rodolfo).
- **Versión exacta del MI**: se usa `4.5.0` por ser la validada junto al APIM 4.6.0 en DEV (ver `scripts/dev/setup-mi-b4-car-deploy.sh`). Si Rodolfo prefiere subir a una versión más nueva de MI, es una decisión aparte — no se investigó compatibilidad de versiones más nuevas contra el mecanismo de identidad de ADR-009.
- **Migración de DataServices a PostgreSQL**: en curso pero no cerrada (`doc/identity/dataservices-remediation-phase-a.md`). Se detectó además que las datasources actuales (`AssetPlannerDataSource.xml`, `ToolsDataSource.xml`) tienen credenciales en texto plano commiteadas en el repo — preexistente, no introducido por esta tarea, pero vale la pena que Rodolfo lo sepa antes del cutover a producción.
