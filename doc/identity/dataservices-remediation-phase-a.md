# DataServices Remediation — Fase A [E9-IDENT-06]

**Decisión base:** E9-IDENT-01 + Sección 6.8 MCP Architecture Doc (decisión P04)  
**Fecha:** 2026-05  
**Alcance:** Solo DataServices expuestos en el MVP del demo (Sprint 2)

---

## 1. Contexto

La investigación E9-IDENT-01 confirmó que múltiples DataServices no filtran por empresa.
En la arquitectura MCP, el gateway (E9-IDENT-05) inyecta `X-Empr-Id` como header, pero si
el DataService no usa ese valor en el WHERE, el aislamiento multi-empresa no se aplica.

La estrategia es dos fases:
- **Fase A (Sprint 2)**: solo los DataServices que se exponen en el demo MVP.
- **Fase B (Sprint 3+)**: el resto. Ver `doc/api/inventory-2026.md §7`.

---

## 2. Auditoría MANDataService (MySQL `assetv2`)

### 2.1 Tabla de queries auditadas

| Query ID | Tipo | ¿Usa empresa? | Estado pre-fix | Acción |
|---|---|---|---|---|
| `getKPIDisponibiidadPorFecha` | KPI | `id_empresa=:id_empresa` | ✓ OK | Sin cambio |
| `getKPIDisponibiidadPorFechaPorEquipo` | KPI | `id_empresa=:id_empresa` | ✓ OK | Sin cambio |
| `getKPIMttrporFecha` | KPI | `id_empresa=:id_empresa` | ✓ OK | Sin cambio |
| `getKPIMttrporFechaxEquipo` | KPI | `id_empresa=:id_empresa` | ✓ OK | Sin cambio |
| `getKPIMttfporFecha` | KPI | `id_empresa=:id_empresa` | ✓ OK | Sin cambio |
| `getKPIMttfporFechaporEquipo` | KPI | `id_empresa=:id_empresa` | ✓ OK | Sin cambio |
| `getTiempoTotal` | Utilidad fechas | N/A (no scoped por empresa) | ✓ OK | Sin cambio |
| `getTiempoTotalReparacion` | Tiempo reparación | `id_empresa=:id_empresa` | ✓ OK | Sin cambio |
| `getCantidadEquiposxEmpresa` | Conteo equipos | `id_empresa=:empr_id` | ✓ OK | Sin cambio |
| `getTiempoTotalReparacionxEquipo` | Tiempo por equipo | Solo `id_equipo` | ⚠️ Parcial | No es MCP MVP — Fase B |
| `getCantidadFallosxEquipo` | Conteo fallos | `id_empresa2=:id_empresa2` | ✓ OK | Sin cambio |
| `getCantidadFallos` | Conteo fallos | `id_empresa2=:id_empresa2` | ✓ OK | Sin cambio |
| `getEstadoEquipo` | Estado equipo | Solo `id_equipo` | ⚠️ Sin empresa | No es MCP MVP — Fase B |
| `getCantEquiposxEmpresaxSectorxGrupo` | Conteo | `id_empresa=:id_empresa` | ✓ OK | Sin cambio |
| `getFechaAltaEquipo` | Fecha alta | `id_empresa=:id_empresa` | ✓ OK | Sin cambio |
| `getSolicitudServicio` (getSolicitudServcio) | **OT — MCP** | `id_empresa=:id_empresa` | ✓ OK | Sin cambio |
| `getNotificaciones` | Notificaciones | `user_id=:user_id` | ✓ OK (scope usuario) | Sin cambio |
| `setsolicitudServicio` | **OT — MCP** | INSERT con `:id_empresa` | ✓ OK | Sin cambio |
| `getLastsolicitudServicio` | Helper OT | Solo `equi_id` | ⚠️ Helper interno | No expuesto MCP — Fase B |
| `putSolicitudServicioCase` | Update OT | Solo `id_solicitud` | ⚠️ Sin empresa | No expuesto MCP — Fase B |
| `deleteSolicitudServicio` | Delete OT | Solo `id_solicitud` | ⚠️ Sin empresa | No expuesto MCP — Fase B |
| `getEquipo` | **Equipos — MCP** | Solo `id_equipo` | ❌ **SIN EMPRESA** | **Fix Fase A** |
| `setAdjuntosSolReparacion` | Adjuntos | Solo `id_solicitud` | ⚠️ Sin empresa | No expuesto MCP — Fase B |
| `getAdjuntosSolReparacion` | Adjuntos | Solo `id_solicitud` | ⚠️ Sin empresa | No expuesto MCP — Fase B |

### 2.2 Fix aplicado

**Query:** `getEquipoIsolated` (nueva — preserva `getEquipo` original para v2)

```sql
-- Antes (getEquipo — sin empresa):
WHERE e.id_equipo = :equi_id

-- Después (getEquipoIsolated — con empresa, solo para MCP):
WHERE e.id_equipo = :equi_id
AND e.id_empresa = :id_empresa
```

**Recurso nuevo:** `GET /mcp/equipo/{id_empresa}/{equi_id}`  
**Recurso original conservado:** `GET /equipo/{equi_id}` (sin cambio — v2 safety)

**Rationale estrategia `_isolated`:** El recurso `/equipo/{equi_id}` no recibe `id_empresa`
en su path actual. La app web v2 llama este endpoint sin empresa. Modificar la query original
requeriría cambiar el path o la firma, rompiendo v2. Se eligió crear la variante `_isolated`
exclusiva para consumo MCP, dejando el original intacto.

### 2.3 Verificación de no-regresión v2

- La query `getEquipo` (sin empresa) no fue modificada. El recurso `/equipo/{equi_id}` es idéntico.
- El PHP de v2 no tiene callers directos de `/MANDataService/equipo/{id}` en el codebase
  (verificado con grep en `application/`). Los callers de `/equipo/` en PHP corresponden a
  PANDataService y semaresiduosDS (módulos diferentes).
- El MCP tool `get_equipo` debe usar `/mcp/equipo/{id_empresa}/{equi_id}`, NO el path legacy.

---

## 3. Auditoría ALMDataService (PostgreSQL `tools_prod_t`)

### 3.1 Queries con empr_id hardcodeado

| Query ID | SQL antes del fix | Problema |
|---|---|---|
| `getArticulos2` | `WHERE A.empr_id = 1` | Hardcoded a empresa 1 — cualquier otra empresa obtiene lista vacía |
| `getArticulo` | `WHERE A.empr_id = 1 AND A.arti_id = :arti_id` | Ídem — solo devuelve artículos de empresa 1 |

### 3.2 Fix aplicado

**getArticulos2:**
```sql
-- Antes:
WHERE A.empr_id = 1

-- Después:
WHERE A.empr_id = cast(:empr_id as integer)
```
Nuevo param: `<param name="empr_id" sqlType="STRING"/>`  
Resource actualizado: `GET /articulos/{empr_id}` (antes: `GET /articulos`)

**getArticulo:**
```sql
-- Antes:
WHERE A.empr_id = 1 AND A.arti_id = CAST(:arti_id as INTEGER)

-- Después:
WHERE A.empr_id = cast(:empr_id as integer) AND A.arti_id = CAST(:arti_id as INTEGER)
```
Nuevo param: `<param name="empr_id" sqlType="STRING"/>`  
Resource actualizado: `GET /articulos/obtener/{empr_id}/{arti_id}` (antes: `GET /articulos/obtener/{arti_id}`)

### 3.3 Impacto en v2 / riesgo de regresión

⚠️ **Los paths de resource cambiaron.** Si v2 llama a `/articulos` o `/articulos/obtener/{id}`,
esas rutas ya no existen. Caller discovery en `application/`:

```bash
grep -rn "ALMDataService\|REST_ALM\|/articulos" application/ | grep -v ".svn"
```

El MVP NO usa estas queries. Si se detecta un caller v2 afectado, migrar ese caller al nuevo
path pasando el empr_id del usuario. No revertir el fix — el hardcode a empr_id=1 es un bug.

---

## 4. Tests Hurl de aislamiento

Ver: `tests/security/dataservice-isolation.hurl`

| Caso | Query | Descripción | Resultado esperado |
|---|---|---|---|
| 1a | `getEquipoIsolated` | equipo 10, empresa 42 → datos de empresa 42 | `empr_id=42` en respuesta |
| 1b | `getEquipoIsolated` | equipo 10, empresa 99 → sin resultado | Respuesta vacía |
| 2 | `getSolicitudServcio` | OTs empresa 42 → no incluyen OTs de empresa 99 | `id_empresa` ≠ 99 en todos |
| 3a | `getArticulos2` | empresa 42 → devuelve artículos de 42 | colección no vacía |
| 3b | `getArticulos2` | empresa 2 → NO devuelve artículos de empresa 1 | `empr_id` ≠ 1 en todos |
| 3c | `getArticulos2` | empresa 9999 → lista vacía | colección vacía |
| 4a | `getArticulo` | artículo 5, empresa 42 → devuelve artículo | `arti_id=5` |
| 4b | `getArticulo` | artículo 5, empresa 99 → sin resultado | vacío |
| 4c | `getArticulo` | empresa 2 → NO devuelve datos de empresa 1 | `empr_id` ≠ 1 |

Los tests requieren WSO2 MI corriendo con datos de prueba sembrados.

---

## 5. Fase B — pendiente Sprint 3+

Los DataServices listados en `doc/api/inventory-2026.md §7` no se modifican en este sprint.
Antes de exponer cualquiera de ellos como MCP tool, se debe:

1. Auditar todas las queries (ídem proceso de esta sección)
2. Agregar filtro `empr_id` en toda query de tipo SELECT, UPDATE, DELETE
3. Para INSERTs: verificar que `empr_id` proviene del JWT (inyectado por `EmprIdInjector`),
   no de un parámetro que el caller pueda falsificar
4. Correr test set equivalente al de Fase A
5. Verificar no-regresión en v2 para cada DataService modificado

**Prioridad sugerida para Sprint 3+:** TARDataService (preventivos), LOGDataService
(logística), COREDataService (usuarios/roles).
