# Ambientes de Trazalog v3 — DEV / TEST / PROD

## Objetivo

Este documento explica los ambientes donde corre el stack WSO2 (APIM + MI) de Trazalog v3, cómo levantar DEV en una máquina local (Rodolfo u otro developer), y cómo se usa TEST hoy (futuro PROD). Está escrito para cualquier developer que necesite decidir "¿dónde pruebo esto?" o "¿necesito ngrok para esto?".

**Qué NO cubre:** la instalación paso a paso de WSO2 (eso está en [`wso2-install.md`](wso2-install.md) para DEV y [`doc/v3/deployment-gcp.md`](../v3/deployment-gcp.md) para TEST/PROD), el flujo de testing de tools MCP en sí ([`testing-workflow.md`](testing-workflow.md)), ni la arquitectura de identidad/federación con Dnato ([`doc/identity/oauth-discovery-flow.md`](../identity/oauth-discovery-flow.md), ADR-008/ADR-009). Este doc es el mapa que conecta esos documentos, no un reemplazo.

---

## 1. Resumen de los 3 ambientes

| Ambiente | Dónde corre | Acceso público | Quién lo usa | Estado hoy (2026-08-08) |
|---|---|---|---|---|
| **DEV** | Máquina local de cada developer (WSO2 APIM+MI nativos) | Ninguno por defecto. Con ngrok, temporal y bajo demanda | Cada developer, individualmente | Activo — es el que se usa día a día |
| **TEST** | VM GCP `e2-medium`, Rocky Linux 9, `us-east1-b` (ADR-011) | `https://mcp.cloudtrazalog.com` (Caddy + TLS Let's Encrypt). Consolas admin NUNCA públicas | Equipo completo, early adopter piloto (sector minero San Juan) | VM instalada y funcionando end-to-end (E7-INFRA-01/02). Todavía sin los artefactos de la fachada MCP desplegados (Tarea 3.5, pendiente) |
| **PROD** | Futuro clon de TEST (misma receta, otra VM/dominio) | Igual esquema que TEST | Clientes reales | No existe todavía |

---

## 2. DEV — máquina local

### 2.1 Cuándo alcanza con `localhost` (sin ngrok)

Para el trabajo del día a día — escribir y probar Synapse APIs, DataServices, correr los tests Hurl, usar Publisher/DevPortal/Carbon — **nunca hace falta ngrok**. Se accede directo:

```
https://localhost:9443/publisher
https://localhost:9443/devportal
https://localhost:9443/carbon
```

Instalación completa en [`wso2-install.md`](wso2-install.md).

### 2.2 Cuándo hace falta ngrok

Solo cuando algo **externo a tu máquina** necesita alcanzar tu instancia local:

- **(a) Probar el conector MCP desde Claude.ai** — Claude.ai necesita una URL pública para invocar el servidor MCP. Ver [`ngrok-setup.md`](ngrok-setup.md) y [`testing-workflow.md`](testing-workflow.md) Etapa 2.
- **(b) Probar el flujo completo de federación de identidad con Dnato** (ADR-008/009) — cuando Dnato también necesita ser alcanzable públicamente para que el intercambio OAuth (authorization code, JWKS, PRM) funcione de punta a punta. `scripts/dev/setup-ngrok.sh` automatiza este caso: levanta 2 túneles (APIM gateway 8243 + Dnato 80), actualiza `deployment.toml`, reinicia APIM, y actualiza el issuer del Resident Key Manager.

### 2.3 Cómo levantar una sesión de DEV con ngrok

1. Instalar y autenticar ngrok (una sola vez) — [`ngrok-setup.md`](ngrok-setup.md) §1-2.
2. Levantar WSO2 APIM + MI local ([`wso2-install.md`](wso2-install.md)).
3. Levantar los 2 túneles ngrok (config file o 2 terminales — ver cabecera de `scripts/dev/setup-ngrok.sh` para el detalle exacto).
4. Correr:
   ```bash
   export APIM_HOME=/ruta/a/tu/wso2am-4.6.0
   bash scripts/dev/setup-ngrok.sh
   ```
   Esto detecta las URLs públicas de los túneles, actualiza `hostname`/`https_endpoint`/`issuer` en `deployment.toml` (con backup automático `.bak.<timestamp>`), reinicia APIM, actualiza el Resident Key Manager, e imprime la URL del conector MCP para Claude.ai y las variables de entorno para Dnato.
5. Trabajar / probar.
6. **Paso obligatorio al terminar la sesión:**
   ```bash
   bash scripts/dev/setup-ngrok.sh --reset
   ```
   Esto revierte `hostname`/`issuer`/`https_endpoint` a `localhost` y reinicia APIM.

> **Por qué este paso es obligatorio y no opcional:** si te salteás el `--reset`, la próxima vez que quieras entrar a Publisher/DevPortal sin ngrok corriendo, APIM va a intentar redirigirte al login vía la URL vieja de ngrok — que ya no existe — y vas a quedar sin poder loguearte, aunque tu instancia esté sana. Esto pasó en la práctica el 2026-08-08: `setup-ngrok.sh` se había corrido (al menos) dos veces desde el 2026-06-30 sin `--reset` después, dejando `hostname` pisado con un subdominio ngrok muerto durante más de un mes. Se corrigió corriendo `--reset` manualmente y reiniciando APIM — ver `doc/v3/STATE.md`.

### 2.4 La URL de ngrok cambia en cada sesión — ¿está considerado?

Sí, en dos frentes distintos:

- **Conector MCP en Claude.ai**: hay que reconfigurar manualmente (Settings → Connectors → editar URL) cada vez que ngrok se reinicia — el plan free no tiene dominios fijos. Documentado en [`ngrok-setup.md`](ngrok-setup.md) §4.
- **`deployment.toml`**: `setup-ngrok.sh` no asume una URL fija — en cada corrida vuelve a leer la URL activa desde la API local de ngrok (`http://localhost:4040/api/tunnels`). Lo único que **no** se resuelve solo es el `--reset` al final de la sesión (§2.3 paso 6) — depende de que el developer lo corra.

### 2.5 Multi-developer

Cada developer levanta su propia instancia local (APIM + MI + ngrok) de forma completamente independiente, siguiendo [`wso2-install.md`](wso2-install.md) desde cero en su máquina. No hay nada compartido entre developers en DEV — las URLs de ngrok de uno no interfieren con las de otro, cada uno usa su propia cuenta ngrok free.

---

## 3. TEST (hoy) / PROD (futuro) — VM GCP

### 3.1 Qué es TEST hoy

VM `e2-medium`, zona `us-east1-b`, Rocky Linux 9, con WSO2 APIM 4.6.0 + MI 4.5.0 instalados **nativamente** (sin contenedores, sin ngrok, sin túneles) — ADR-011, detalle completo en [`doc/v3/deployment-gcp.md`](../v3/deployment-gcp.md).

- Dominio público: `mcp.cloudtrazalog.com`, TLS automático vía Caddy (Let's Encrypt).
- Puerto 9443 (carbon/publisher/devportal) **nunca se expone públicamente** — solo alcanzable por túnel SSH o red interna del proyecto GCP (`deployment-gcp.md` §3 y §4 paso 9).

**Estado actual:** la VM está instalada y funcionando end-to-end (E7-INFRA-01/02, PR #403/#404), pero todavía no tiene desplegados los artefactos de la fachada MCP unificada (`toolsMCPAPI`, `toolsALMAPI`, etc.) — eso es la Tarea 3.5 (E7-INFRA-05), pendiente de confirmación de Rodolfo sobre si la verificación en DEV de E2-MCP-13 alcanza como prerequisito (ver `doc/v3/STATE.md`).

### 3.2 Cómo acceder a TEST

- **Gateway público** (invocación de APIs/MCP): `https://mcp.cloudtrazalog.com` — directo, sin VPN ni túnel.
- **Consolas admin** (carbon/publisher/devportal): solo vía túnel SSH:
  ```bash
  gcloud compute ssh NOMBRE_VM --zone=us-east1-b --tunnel-through-iap -- -L 9443:localhost:9443
  ```
  y después `https://localhost:9443/publisher` en tu navegador (certificado self-signed, la advertencia del navegador es esperada).

**No hace falta ngrok en TEST** — a diferencia de DEV, ya tiene un dominio público estable con TLS real vía Caddy.

### 3.3 Cómo desplegar cambios a TEST

No existe todavía un script equivalente a `scripts/dev/rebuild-and-deploy-mi.sh` (el de DEV) para TEST — hoy el despliegue a la VM GCP es manual, siguiendo `deployment-gcp.md` §4 pasos 6-8. No se armó un script dedicado porque la Tarea 3.5 (primer despliegue real de la fachada MCP a esta VM) todavía no se ejecutó. Si el despliegue a TEST se vuelve frecuente una vez arrancada esa tarea, vale la pena automatizarlo — queda marcado acá para cuando corresponda.

### 3.4 PROD (futuro)

Todavía no existe. El plan (parte de ADR-011, no ejecutado) es clonar la receta de TEST — misma VM (nueva instancia, sizing igual o ajustado según el uso real del piloto), mismo Caddy+TLS, pero con su propio dominio/IP. Antes de dar de alta al primer cliente real sobre esa VM, quedan dos pendientes que hoy están fuera de alcance de TEST:

- Config de identidad completa (ADR-008/ADR-009) contra el Dnato de ese ambiente.
- Migración de DataServices a PostgreSQL (hoy MySQL/PostgreSQL mezclados — ver `doc/identity/dataservices-remediation-phase-a.md`, en curso, no cerrada).

No hay fecha ni VM creada todavía — se define cuando el piloto con el early adopter minero valide el approach en TEST.

---

## 4. Resumen rápido — ¿qué uso cuándo?

| Necesito... | Uso |
|---|---|
| Desarrollar o debuggear una API/DataService | DEV local, sin ngrok |
| Probar una tool MCP con Claude.ai | DEV local + ngrok ([`testing-workflow.md`](testing-workflow.md) Etapa 2), o TEST directamente si ya está desplegado ahí |
| Probar el login/flujo completo con Dnato | DEV local + `setup-ngrok.sh` (2 túneles), o TEST (dominio real, sin ngrok) |
| Mostrarle algo a alguien fuera del equipo, o probar con el early adopter | TEST |
| Dar de alta un cliente real en producción | Todavía no existe — esperar a que TEST valide y clonar (§3.4) |
