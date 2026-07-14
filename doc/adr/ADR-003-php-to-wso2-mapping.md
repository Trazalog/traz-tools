# ADR-003 — Estrategia de mapeo PHP/CodeIgniter a WSO2 para operaciones MCP

**Estado:** Aceptado  
**Fecha:** 2026-05  
**Contexto:** E1-API-03 — MCP MVP Sprint 2  
**Decisores:** PM (Rodolfo Ruiz)  
**Prerequisitos:** E1-API-02 (relevamiento CI3), E1-API-11 (datasource normalizado), E9-IDENT-01 (investigación aislamiento), E9-IDENT-06 (remediación DataServices Fase A)

---

## Contexto

El MCP MVP de Sprint 2 expone dos Virtual MCP Servers:

- **Equipos** — `get_equipo`: devuelve el detalle técnico de un equipo dado su `id`.
- **OTs (Órdenes de Trabajo)** — `create_ot`: crea una solicitud de servicio correctiva e instancia el proceso en Bonita BPM.

Cada operación que se expone como MCP tool necesita una decisión explícita sobre la estrategia de implementación en WSO2:

| Estrategia | Cuándo aplicar |
|---|---|
| **DataService SQL puro** | SELECT o INSERT/UPDATE/DELETE simples sin lógica de orquestación. El DataService expone el endpoint directamente. |
| **Sequence de mediación** | Operaciones multi-paso: llamadas a múltiples DataServices, interacción con Bonita BPM, transformaciones de payload, o ensamble de respuesta. |
| **Python Phase 2** | Únicamente para lógica AI/ML/RAG: modelos predictivos, análisis de series de tiempo, RAG sobre documentos, procesamiento de lenguaje natural. |

**Criterio principal (ADR-003):** maximizar WSO2. Python Phase 2 se aplica solo cuando la lógica es inherentemente AI/ML o requiere iteración sobre grandes volúmenes de datos que SQL no puede resolver eficientemente.

---

## Flujo de autenticación y propagación de empr_id

> **ADR-008 (Mayo 2026):** el flujo de validación fue actualizado. El APIM Gateway valida el JWT
> y extrae el `empr_id` (no el MI). Ver [empr-id-injection.md](../identity/empr-id-injection.md).

El flujo actual (post ADR-008):

```
Agente MCP
  │  Authorization: Bearer <JWT Dnato>
  ▼
APIM Gateway (:8243)
  ├── Key Manager Dnato: valida firma RS256, exp, iss, aud
  ├── EmprIdInjectorPolicy (in-sequence): extrae empr_id, inyecta X-Empr-Id
  ▼
WSO2 MI (:8280)
  ├── emprIdFromHeader: lee X-Empr-Id, setea jwt_empr_id en contexto
  └── API Sequence (toolsMANAPI.xml)
         │  Usa jwt_empr_id para construir URL del DataService
         ▼
      DataService
         │  WHERE id_empresa = :id_empresa  (o id_empresa = :empr_id)
         ▼
      MySQL assetv2
```

**Consecuencia para las Sequences:** cada sequence MCP que llame a un DataService debe extraer `X-Empr-Id` del header de transporte y pasarlo explícitamente como parámetro al DataService. El caller MCP no puede inyectar `empr_id` directamente — el gateway lo sobreescribe con el valor del JWT.

---

## Tabla de decisiones — Sprint 2

> Nomenclatura MAN: la columna `filtra por empr_id` usa el nombre de campo de la tabla MySQL (`id_empresa`), que en AssetPlanner es históricamente `id_empresa`, no `empr_id` como en PostgreSQL.

### Virtual MCP Server 1: Equipos — `get_equipo`

| Operación MCP | Entidad | DataService / Artefacto | Estrategia | Filtra por empr_id | Justificación |
|---|---|---|---|---|---|
| `get_equipo` | Equipos | `MANDataService.getEquipoIsolated` | **DataService SQL puro** | ✅ `AND e.id_empresa = :id_empresa` | SELECT simple con JOIN a catálogos. Ya existe la query `getEquipoIsolated` agregada en E9-IDENT-06. Sin lógica de orquestación. |

**Resource en WSO2:**
```
GET /services/MANDataService/mcp/equipo/{id_empresa}/{equi_id}
```

**Wiring en toolsMANAPI:**
```
GET /tools/man/mcp/equipo/{equi_id}
→ extraer X-Empr-Id del header
→ llamar MANDataService /mcp/equipo/{empr_id}/{equi_id}
```

**Por qué no Sequence:** la operación es un único SELECT. La única "lógica" es pasar el `empr_id` como parámetro — eso lo hace la API resource directamente sin necesitar una sequence separada.

**Por qué no Python:** es una consulta SQL sobre datos relacionales. No hay ML, ni análisis estadístico, ni RAG.

---

### Virtual MCP Server 2: OTs — `create_ot`

| Operación MCP | Entidad | DataService / Artefacto | Estrategia | Filtra por empr_id | Justificación |
|---|---|---|---|---|---|
| `create_ot` | OTs | `MANDataService.setsolicitudServicio` + `bpmAPICallTemplate` + `MANDataService.putSolicitudServicioCase` | **Sequence de mediación** | ✅ INSERT con `:id_empresa` en el payload | Operación multi-paso obligatoria: INSERT solicitud → instanciar proceso Bonita → UPDATE case_id. Sin la vinculación BPM, la OT queda en estado inconsistente. |

**Secuencia de pasos en `createOTCorrectivaSequence`:**

```
1. Extraer X-Empr-Id del header de transporte → id_empresa
2. POST /services/MANDataService/solicitudServicio
   - payload incluye id_empresa (del header), id_equipo, causa, solicitante, etc.
3. GET /services/MANDataService/solicitudServicio/ultima/{equi_id}
   - recupera el sose_id recién creado
4. POST /tools/bpm/proceso/instancia (vía bpmAPICallTemplate)
   - proceso: "Proceso de Mantenimiento AssetPlanner SIM"
5. PUT /services/MANDataService/solicitudServicio/caseid
   - vincula el case_id de Bonita al sose_id
6. Respuesta: { sose_id, case_id, estado }
```

**Por qué no DataService:** los pasos 3, 4 y 5 son dependientes del resultado del paso 2. Un DataService no puede orquestar llamadas secuenciales. Reemplazar la secuencia con un stored procedure en MySQL implicaría lógica de negocio en la BD — contra las convenciones del proyecto.

**Por qué no Python:** la orquestación es secuencial y determinista. No hay ML. WSO2 Sequences son exactamente el mecanismo de mediación del stack.

**Reutilización:** `toolsMANAPI.xml` ya tiene un endpoint POST `/tools/man/solicitudServicio` que hace este mismo flujo para v2. La `createOTCorrectivaSequence` reutiliza y extiende ese patrón para contexto MCP (extrayendo `empr_id` del header en lugar de recibirlo como query param).

---

## Tabla ampliada — operaciones de soporte del sprint

Las siguientes operaciones no son los Virtual MCP Servers principales, pero son necesarias para que el agente pueda invocar `get_equipo` y `create_ot` con datos válidos (lookups, listados).

| Operación | Entidad | Estrategia | Filtra por empr_id | Nota |
|---|---|---|---|---|
| `get_equipos` (lista paginada) | Equipos | DataService SQL puro | ✅ `WHERE id_empresa = :empr_id` | Query nueva `getEquipos` en `MANEquiposDataService` (nuevo DBS). Necesaria para que el agente encuentre el `equi_id` a consultar. |
| `get_ots` (lista solicitudes) | OTs | DataService SQL puro | ✅ ya filtra por `id_empresa` | `getSolicitudServcio` en MANDataService. Ya existe. |
| `get_sectores` (lookup) | Catálogo | DataService SQL puro | No aplica (catálogo global) | Lookup sin scope de empresa — los sectores son del cliente. |
| `get_criticidades` (lookup) | Catálogo | DataService SQL puro | No aplica | Ídem |
| `get_grupos` (lookup) | Catálogo | DataService SQL puro | No aplica | Ídem |

---

## Operaciones diferidas a Python Phase 2 (fuera de Sprint 2)

| Funcionalidad | Modelo PHP origen | Razón para diferir |
|---|---|---|
| `check_pm_hours` — PMs disparados por horas de uso | `Preventivos::revisaEstadoPreventivosPorHoras` | Requiere evaluar umbrales dinámicos sobre historial de lecturas con estado. Lógica con bucle sobre múltiples equipos — candidata a agente Python con acceso a `historial_lecturas`. |
| `analyze_condition` — Análisis predictivo | `Predictivos.php` | Requiere modelos ML sobre series de tiempo de lecturas. |
| `alert_threshold` — Alertas por parámetros | `Lecturas::setupparam` | Comparación dinámica de lectura actual vs umbral configurado — puede incluir histéresis y lógica temporal. |

**Aclaración importante:** los KPIs (Disponibilidad, MTTR, MTTF, conteo de fallas) **no son Python Phase 2**. Ya están implementados como DataService SQL puro en `MANDataService.dbs` usando `historial_lecturas_mem` (tabla cache MySQL). El relevamiento E1-API-02 confirmó que `Kpis.php` era un wrapper REST sobre esos endpoints — la migración a WSO2 ya estaba hecha.

---

## Decisiones excluidas del scope de este ADR

Las siguientes operaciones se posponen a sprints posteriores y NO tienen decisión en este ADR:

- `create_preventivo` — Sequence (INSERT preventivo + recursos + opcionalmente BPM)
- `get_kpis` — DataService SQL puro (ya existe en MANDataService)
- `get_stock_ap` — DataService SQL puro (ALMDataService)
- Ciclo de vida de OTs (estados, RRHH, Ordenservicios) — Sequences

---

## Consecuencias

**Positivas:**
- Maximiza WSO2: el 100% de las operaciones de Sprint 2 son implementables en WSO2 sin Python.
- Reutiliza artefactos existentes: `MANDataService.dbs`, `toolsMANAPI.xml`, `bpmAPICallTemplate`.
- El aislamiento multi-empresa está garantizado en la capa SQL (`getEquipoIsolated`, `setsolicitudServicio`), no solo en el gateway.

**Riesgos a monitorear:**
- La `createOTCorrectivaSequence` tiene 5 pasos secuenciales — si Bonita (paso 4) falla, la solicitud quedó insertada en MySQL sin `case_id`. El rollback manual (DELETE solicitud) debe incluirse en el error handler de la sequence.
- `MANDataService` tiene 6 slots disponibles antes del límite de 30 ops. Las operaciones de soporte (`get_equipos`, etc.) deben ir en `MANEquiposDataService` (nuevo), no en el DataService existente.

---

## Referencias

- `doc/api/codeigniter-models-survey.md` — relevamiento CI3, tabla de categorización por entidad
- `doc/api/inventory-2026.md` §5 — gap analysis vs MCP MVP, §7 — lista negra de DataServices
- `doc/identity/dataservices-remediation-phase-a.md` — auditoría empr_id en MANDataService y ALMDataService
- `doc/identity/gateway-token-validation.md` — flujo de validación JWT y propagación de empr_id
- `_backend/api/ToolsAPIProject/.../sequences/JwtValidator.xml` — validación JWT en gateway
- `_backend/api/ToolsAPIProject/.../sequences/EmprIdInjector.xml` — inyección X-Empr-Id
- `_backend/api/ToolsAPIProject/.../data-services/MANDataService.dbs` — queries existentes y getEquipoIsolated
