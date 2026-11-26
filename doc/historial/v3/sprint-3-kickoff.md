# Trazalog v3 — Sprint 3 Kickoff

> **PLAN INICIAL INMUTABLE** (metodología v2, CICD §5-bis). El estado vivo se lleva en `doc/v3/STATE.md`, no acá. Este documento no se reescribe durante el sprint.

---

## 1. Objetivo del Sprint 3

> **Poner la plataforma en un servidor estable de Google Cloud y sumar las operaciones de almacenes (lectura + escritura), para activar al primer cliente early adopter minero sobre una base de producción real — no sobre ngrok.**

El sprint se enfoca en **dos frentes técnicos + la habilitación del cliente**. Mantenimiento no suma operaciones nuevas: las 5 tools actuales (equipos + OTs + create_ot) ya demuestran valor para la primera sesión. El diferencial de este sprint es infraestructura estable + almacenes (hoy en cero).

**Criterio de éxito:** el cliente minero hace su sesión guiada contra un servidor de Google Cloud (no ngrok), consultando y operando su inventario real (stock, movimientos) además de mantenimiento, con aislamiento multi-tenant garantizado criptográficamente también en almacenes.

---

## 2. Alcance — qué entra y qué NO

### Entra

| Frente | Qué | Por qué |
|---|---|---|
| Infra GCP | Despliegue del stack (WSO2 APIM + MI + Dnato + PostgreSQL) en una VM de Google Cloud, con URL estable | Prioridad #1. Sin server estable no hay demo; ngrok es efímero e impresentable ante un cliente |
| Almacenes | Tools MCP de lectura (stock, artículos, movimientos, depósitos) | Hoy hay 0 tools de almacenes; el cliente minero necesita consultar su inventario |
| Almacenes | Tools MCP de escritura (registrar movimientos, ajustes) — CON el fix de seguridad | El cliente necesita operar, no solo consultar |
| Seguridad | Envolver ALMDataService con el patrón EmprIdFromHeader (ADR-009) para que empr_id venga del JWT, no del caller | Bloqueante de almacenes. Sin esto, un agente podría leer/modificar stock de otra empresa |
| Negocio | Deck + acuerdo de early adopter | Prerequisito comercial |
| Negocio | Auditoría de datos del cliente (mantenimiento + almacenes) | Evita respuestas pobres por datos incompletos |
| Negocio | Conectar el cliente al server GCP + smoke test | El hito central |
| Negocio | Sesión guiada | El cierre del sprint |

### NO entra (backlog)

- Operaciones nuevas de mantenimiento (OTs programadas, preventivos, insumos AP, calendario) — diseño listo (survey Sprint 1) pero no necesario para el piloto. Sprint futuro.
- KPIs de mantenimiento — aunque "casi gratis", el PM decidió cero mantenimiento nuevo este sprint. Candidato #1 para el próximo.
- Trazabilidad sub->usrId en create_ot (deuda #1) — se difiere: no bloquea el piloto (contacto directo, pocas OTs).
- Dependabot, Secure Vault, RFC 8252, ADRs retroactivos, hardening firma X-JWT-Assertion — backlog.

---

## 3. Tareas del Sprint 3

> Clasificadas por riesgo (v2). Las de clase decisión requieren workshop CW+Rodolfo ANTES de que Claude Code implemente.

### Bloque A — Infraestructura GCP (prioridad #1)

| ID | Tarea | Clase | Notas |
|---|---|---|---|
| E7-INFRA-01 | Diseño de la topología de despliegue en GCP (qué VM, qué corre en ella, cómo se expone con dominio/TLS estable, dónde va PostgreSQL) | Decision | Workshop CW+Rodolfo. Define el ADR-011. Ver seccion 4 |
| E7-INFRA-02 | IaC del stack: docker-compose (APIM+MI+Dnato+PostgreSQL) siguiendo la decisión de stack ya documentada (Docker/Ansible) | Estandar | Depende de E7-INFRA-01. Migra de H2 embebida a PostgreSQL persistente |
| E7-INFRA-03 | Configurar WSO2 para TEST/PROD: PostgreSQL como BD (no H2), certificado real (no self-signed), URLs públicas estables | Estandar | Cierra el pendiente E0-INF-05 del Sprint 0 |
| E7-INFRA-04 | Desplegar en la VM de GCP + smoke test del flujo OAuth completo contra la URL estable (reemplaza ngrok) | Decision | Toca infra de cara al cliente. Rodolfo ejecuta el despliegue; verificación conjunta |

### Bloque B — Almacenes (lectura + escritura seguras)

| ID | Tarea | Clase | Notas |
|---|---|---|---|
| E9-SEC-01 | Definir cómo se inyecta empr_id desde el JWT en las operaciones de ALMDataService (patrón EmprIdFromHeader, igual que Mantenimiento) | Decision | Workshop CW+Rodolfo. Puede ser parte del ADR-011 o un ADR-012 propio. Ver seccion 4 |
| E1-ALM-01 | Crear toolsALMAPI (wrapper de orquestación sobre ALMDataService) con las operaciones de LECTURA, inyectando empr_id del JWT | Estandar | Sigue el patrón de toolsMANAPI. Requiere E9-SEC-01 resuelto |
| E1-ALM-02 | Agregar las operaciones de ESCRITURA (movimiento de stock, ajuste) a toolsALMAPI, con el mismo aislamiento | Decision | Escritura sobre datos reales — más sensible. Requiere E9-SEC-01. Alcance exacto a confirmar en planning de detalle |
| E1-ALM-03 | OpenAPI spec alm.yaml + Virtual MCP Server trazalog-almacenes | Estandar | Depende de E1-ALM-01/02 |

### Bloque C — Habilitación del cliente

| ID | Tarea | Clase | Notas |
|---|---|---|---|
| E6-EA-01 | Deck + acuerdo de early adopter | Rutina | CW+Rodolfo, no Claude Code |
| E6-EA-02 | Auditoría de datos del cliente (mantenimiento + almacenes) | Estandar | Cuando el cliente dé acceso |
| E6-EA-03 | Conectar el cliente al server GCP + smoke test con sus datos | Decision | Toca datos reales del cliente. Depende de todo el Bloque A + B |
| E6-EA-04 | Sesión guiada | Rutina | Cierre del sprint |

---

## 4. Workshops de arquitectura requeridos (clase decision, ANTES de implementar)

**Workshop 1 — Topología de despliegue GCP (ADR-011):**
- ¿Una sola VM con todo (APIM+MI+Dnato+PostgreSQL en containers) o separación? (costo $0 sugiere una sola VM)
- ¿Cómo se expone con URL estable y TLS? (dominio propio + Let's Encrypt, o el mecanismo que corresponda)
- ¿PostgreSQL en container o servicio gestionado de GCP? (costo $0 sugiere container)
- ¿Cómo se maneja el secreto de las credenciales de BD en la VM? (relacionado con la deuda de Secure Vault diferida)

**Workshop 2 — Aislamiento de almacenes (ADR-012 o parte del 011):**
- ¿El wrapper toolsALMAPI usa exactamente la misma sequence EmprIdFromHeader que toolsMANAPI, o hay diferencias por la estructura de ALMDataService?
- ¿Qué operaciones de escritura entran al piloto? (el relevamiento sugiere acotar a movimientoStock + crearAjuste en lugar de las 4 completas — decisión de alcance)
- ¿Hay lógica de negocio en el repo traz-comp-almacenes (no accesible hoy) que deba migrarse a WSO2 antes de exponer escritura, o el ALMDataService ya es autosuficiente?

---

## 5. Orden de ejecución y dependencias

```
FASE 1 (desbloqueo):
  - Workshop 1 (ADR-011 topología GCP) ---+
  - Workshop 2 (ADR-012 aislamiento ALM) -+ CW+Rodolfo, pueden ser la misma sesión
  - E6-EA-01 (deck) ----------------------+ en paralelo

FASE 2 (construcción, en paralelo):
  Infra: E7-INFRA-02 -> E7-INFRA-03
  Almacenes: E9-SEC-01 -> E1-ALM-01 -> E1-ALM-02 -> E1-ALM-03

FASE 3 (integración):
  E7-INFRA-04 (desplegar en GCP) — requiere Fase 2 infra + almacenes mergeados
  E6-EA-02 (auditoría datos cliente) — cuando el cliente dé acceso

FASE 4 (cliente):
  E6-EA-03 (conectar cliente al server GCP)
  E6-EA-04 (sesión guiada) — cierre
```

Máximo 3 tareas activas en paralelo (regla v2). El ritual semanal audita contra STATE.md.

---

## 6. Definition of Done del Sprint 3

- [ ] ADR-011 (topología GCP) y ADR-012 (aislamiento almacenes) redactados y aprobados; CONTEXT-PACK actualizado
- [ ] Stack desplegado en VM de GCP con URL estable y TLS — ngrok ya no se usa para el cliente
- [ ] PostgreSQL persistente (no H2); certificado real (no self-signed)
- [ ] Flujo OAuth completo verificado contra la URL estable de GCP
- [ ] Tools de almacenes LECTURA funcionando, con empr_id derivado del JWT (verificado: no se puede pasar empr_id de otra empresa)
- [ ] Tools de almacenes ESCRITURA funcionando, con el mismo aislamiento (verificado con 2 empresas: no se puede modificar stock ajeno)
- [ ] Virtual MCP Server trazalog-almacenes operativo
- [ ] Deck + acuerdo listos; datos del cliente auditados
- [ ] Cliente conectado al server GCP; aislamiento verificado con su empr_id
- [ ] Sesión guiada ejecutada; feedback registrado
- [ ] STATE.md refleja el cierre

---

## 7. Riesgos del sprint

- **El despliegue GCP es "desde cero en artefactos"** (relevamiento seccion 3): no hay docker-compose, ni playbooks Ansible, ni workflows CI. Es el frente de mayor incertidumbre de esfuerzo. Mitigación: la decisión de stack ya está tomada; el workshop 1 acota el diseño antes de construir.
- **La escritura de almacenes sobre datos reales** es lo más sensible del sprint. Mitigación: el fix de seguridad (E9-SEC-01) es bloqueante duro — ninguna tool de escritura se expone sin él, y se verifica con la prueba de 2 empresas antes de tocar datos del cliente.
- **Dependencia del cliente** (acceso a sus datos, disponibilidad para la sesión): si el cliente se demora, infra y almacenes igual avanzan; solo el Bloque C queda en espera.
