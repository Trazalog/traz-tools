# ADR-011 — Topología de despliegue en Google Cloud (early adopter)

- **Estado:** Aceptado
- **Fecha:** 2026-07-16
- **Contexto de decisión:** Workshop CW + Rodolfo (Sprint 3)
- **Relacionado:** ADR-005 (costo $0 hasta 2027), ADR-009 (mecanismo de identidad vigente)

---

## Contexto

El Sprint 2 dejó la plataforma MCP funcionando end-to-end, pero corriendo en el entorno de desarrollo y expuesta mediante **ngrok** (túnel efímero: la URL cambia en cada reinicio, el servicio se cae, no es presentable ante un cliente). Para activar al primer cliente early adopter minero se necesita un **servidor estable, con URL fija y TLS válido**.

Restricción rectora: **costo incremental $0 hasta 2027** (ADR-005). El despliegue debe apoyarse en infraestructura ya disponible y minimizar recursos pagos.

Datos del entorno actual que condicionan la decisión:
- Dnato (PHP, Authorization Server OAuth) y PostgreSQL **ya existen y corren en Google Cloud, en el mismo proyecto** donde irá la VM nueva.
- El stack MCP probado en DEV usa **WSO2 APIM 4.6.0 + WSO2 MI 4.x**. Producción v2 usa WSO2 EI 6.x (Carbon-based, generación anterior), que NO es donde se construyó ni probó el mundo v3.
- Rodolfo opera WSO2 hoy **sin Docker** (instalación nativa).

---

## Decisión

Se despliega una **VM nueva en Google Cloud (mismo proyecto) que corre ÚNICAMENTE WSO2 (APIM 4.6.0 + MI 4.x), con instalación nativa (sin contenedores)**, detrás de un reverse proxy con TLS para el dominio `mcp.cloudtrazalog.com`. La VM se conecta por la red interna del proyecto a la PostgreSQL y al Dnato existentes.

### Decisiones puntuales

| # | Decisión | Justificación |
|---|---|---|
| 1 | **Solo WSO2 en la VM nueva** (APIM + MI). Dnato y PostgreSQL se reutilizan (ya existen) | Menos recursos, menos superficie a desplegar, reutiliza lo que ya funciona |
| 2 | **APIM 4.6 + MI 4.x** (replica DEV), NO EI 6 | Todo el mecanismo ADR-009 (X-JWT-Assertion, EmprIdFromHeader, DataServices, sequences) está probado sobre MI. Desplegar sobre EI 6 obligaría a re-verificar compatibilidad en una generación distinta de WSO2 — riesgo innecesario antes de un cliente |
| 3 | **Instalación NATIVA, sin Docker** | (a) Menos consumo de RAM: sin overhead del daemon Docker, crítico en una VM chica donde cada MB va al APIM. (b) Es como Rodolfo opera hoy: cero curva de aprendizaje nueva antes del cliente. (c) WSO2 se instala descomprimiendo un .zip + servicio systemd, sin dependencias complejas. Docker/K8s tendrá sentido al escalar a varios clientes — se revisará con un ADR nuevo entonces |
| 4 | **MI con memoria mínima; el grueso de RAM al APIM** | El MI es un runtime liviano pensado para contenedores, arranca con footprint bajo. El APIM sí consume (2GB JVM + 2GB SO según doc oficial WSO2). El reparto prioriza al APIM |
| 5 | **VM más barata/gratis de GCP que aguante el stack** | Costo $0 (ADR-005). El sizing exacto lo investiga Claude Code contra doc oficial de GCP (E7-INFRA-01). Escalable después cambiando el tipo de máquina sin reinstalar |
| 6 | **PostgreSQL existente, red interna del proyecto GCP** | Ya existe, mismo proyecto → conectividad interna simple, sin VPN ni peering |

> **Nota de implementación (2026-07-28, E7-INFRA-01/02):** el punto 6 se acotó durante la ejecución. PostgreSQL existente sigue siendo el destino de la futura migración de las DataServices de negocio del MI (ver `doc/identity/dataservices-remediation-phase-a.md`) y de la conectividad de red asumida en esta topología. Pero **el registro interno del propio APIM (`apim_db`/`shared_db`) se deja en su H2 embebida por defecto, no en PostgreSQL** — decisión explícita de Rodolfo: para un piloto de 1-2 usuarios, mantener esquemas de PostgreSQL para el registro interno del APIM no se justificaba frente a la simplicidad de H2 (mismo comportamiento que su DEV). Riesgo aceptado: si el piloto escala a producción real, migrar de H2 a PostgreSQL para `apim_db`/`shared_db` es trabajo aparte, no trivial. Detalle en `doc/v3/deployment-gcp.md` §2.
| 7 | **`mcp.cloudtrazalog.com` + Let's Encrypt** vía reverse proxy (nginx o caddy nativo) | Dominio propio ya disponible. Let's Encrypt = TLS válido gratis. Reemplaza ngrok |
| 8 | **Secretos por archivo `.env` gitignored** (o equivalente nativo en el systemd/config) | Mínimo viable honesto para el piloto. NO es la solución final (Secure Vault sigue siendo deuda de GA), pero evita credenciales hardcodeadas en el repo |
| 9 | **No exponer la consola 9443 públicamente** — solo el gateway 8243 tras el reverse proxy TLS | Reduce superficie de ataque. La consola de administración se accede por túnel/red interna |

---

## Topología resultante

```
Claude.ai (cliente) ──HTTPS+OAuth──> mcp.cloudtrazalog.com (TLS Let's Encrypt)
                                          │ reverse proxy (nginx/caddy nativo)
                                          ▼
                                     VM GCP nueva (solo WSO2, nativo)
                                       APIM 4.6.0 (RAM prioritaria)
                                       MI 4.x (RAM mínima)
                                          │ red interna del proyecto GCP
                                          ▼
                                     PostgreSQL existente
Claude.ai (login) ──OAuth──> Dnato existente (mismo proyecto GCP)
```

---

## Consecuencias

### Positivas
- URL estable y TLS válido: presentable ante el cliente, reemplaza ngrok.
- Recursos mínimos: reutiliza BD y Dnato existentes; la VM solo carga WSO2.
- Sin curva de aprendizaje nueva (nativo, como opera Rodolfo hoy).
- Coherente con costo $0 (ADR-005).

### Negativas / riesgos aceptados
- **Punto único de falla** (una sola VM). Aceptable para un early adopter; se revisa al escalar.
- **Sizing ajustado**: si la VM elegida queda por debajo de lo que WSO2 recomienda para el APIM, puede haber lentitud o fallos de arranque por memoria. Mitigación: el tipo de máquina es escalable sin reinstalar; primer movimiento ante problemas = subir RAM.
- **Secretos por `.env`**: solución de piloto, no de GA. La deuda de Secure Vault sigue registrada.
- **Sin Docker hoy**: cuando se escale a varios clientes / Kubernetes, habrá que containerizar — trabajo futuro, ADR nuevo.

---

## Preguntas abiertas (a resolver en la implementación)

- Sizing exacto de la VM y reparto de memoria APIM/MI → E7-INFRA-01 (Claude Code investiga contra doc oficial GCP).
- Elección de reverse proxy (nginx vs caddy) → Claude Code recomienda; caddy hace TLS automático con Let's Encrypt con config mínima.
- Pasos manuales en la consola de GCP (crear VM, DNS de mcp.cloudtrazalog.com → IP, reglas de firewall) → checklist para Rodolfo en `doc/v3/deployment-gcp.md`.

---

## Alternativas descartadas

- **Docker / docker-compose:** descartado para el early adopter. No cambia el costo en GCP (se cobra la VM, no lo que corre adentro), pero suma overhead de RAM y una capa operativa nueva justo antes del cliente, sin beneficio hasta que se escale a K8s.
- **WSO2 EI 6 (el de producción v2):** descartado. El mundo v3 se construyó y probó sobre MI; usar EI 6 obligaría a re-verificar todo el mecanismo de identidad en otra generación de WSO2.
- **PostgreSQL gestionado (Cloud SQL):** descartado por costo. La instancia existente ya cubre la necesidad.
- **VM separada para BD:** innecesario para un piloto de un cliente; sobredimensionado.
