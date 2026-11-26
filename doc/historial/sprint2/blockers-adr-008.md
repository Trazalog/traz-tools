# Blockers ADR-008 — Sprint 2

**Contexto:** El PM aceptó correr la fecha de la demo para implementar ADR-008 correctamente
(Key Manager federado Dnato) en lugar del passthrough. Los artefactos de código están listos;
quedan tareas procedimentales que requieren acceso al entorno y confirmación antes de ejecutar.

---

## Estado de blockers

| # | Blocker | Tipo | Estado | Responsable |
|---|---|---|---|---|
| B1 | Verificar accesibilidad del JWKS de Dnato desde el host del APIM | Operativo | **PENDIENTE** | PM + Ops |
| B2 | Registrar Key Manager Dnato en la consola Admin del APIM | Config | **PENDIENTE** | PM + Ops |
| B3 | Subir in-sequence EmprIdInjectorPolicy a las APIs Equipos y OTs | Config | **PENDIENTE** | PM |
| B4 | Deploy del CAR actualizado al MI (incluye EmprIdFromHeader.xml) | Deploy | **PENDIENTE** | PM + Ops |
| B5 | Actualizar tests Hurl para apuntar al APIM (:8243) en vez del MI (:8280) | Código | **DONE** | Sprint 2 |

---

## Detalle por blocker

### B1 — JWKS accesible desde el APIM

**Qué verificar:** desde el host del APIM, ejecutar:
```bash
curl -s https://<dnato-host>/oauth/.well-known/jwks.json | python3 -m json.tool
```
Debe devolver 200 con `keys[]` no vacío.

**Si falla:** ver `doc/identity/apim-keymanager-dnato.md §2` para opciones de TLS (importar cert
al truststore del APIM o usar HTTP en red privada para DEV).

**Impacto si no se resuelve:** el APIM no puede validar ningún JWT de Dnato. Todo el tráfico MCP
devuelve 401.

---

### B2 — Key Manager Dnato en consola Admin

**Qué ejecutar:** seguir `doc/identity/apim-keymanager-dnato.md §3` en la consola Admin del APIM.
**Requiere confirmación del PM** antes de tocar la consola Admin de cualquier entorno compartido.

**Nota:** el APIM de DEV tiene `:9443` escuchando localmente. La config del KM no afecta a las
APIs legacy porque el KM se asocia por API (no globalmente).

---

### B3 — In-sequence EmprIdInjectorPolicy en Publisher

**Artefacto:** `doc/identity/apim-empr-id-injector-policy.xml`
**Dónde:** Publisher → API Equipos / API OTs → Message Mediation → In Flow → Upload
**Requiere confirmación del PM** antes de modificar APIs publicadas.

---

### B4 — Deploy del CAR al MI

El CAR incluye los siguientes artefactos nuevos/modificados (incluye los 3 fixes de hardening):

| Artefacto | Cambio |
|---|---|
| `EmprIdFromHeader.xml` | **Nuevo** — reemplaza jwtValidator+emprIdInjector |
| `toolsMANAPI.xml` | Modificado — 5 resources usan emprIdFromHeader |
| `JwtValidator.xml` | Modificado — comentario ADR-008 (no se invoca en MCP) |

> **Fix 3 incluido:** `EmprIdFromHeader.xml` responde 503 + log WARN si falta `X-Empr-Id`.
> Antes del deploy del CAR, ejecutar `tests/security/mi-fallback.hurl` contra el MI con el
> CAR actual para confirmar la línea base (actualmente devuelve 400; post-deploy devuelve 503).

```bash
cd _backend/api/ToolsAPIProject/ToolsAPIProject
./mvnw clean install
# Verificar que el build pasa sin errores (incluye los fixes de Sprint 2)
# Luego: con confirmación del PM:
cp target/ToolsAPIProject_1.0.0.car $WSO2MI_HOME/repository/deployment/server/carbonapps/
```

**Impacto:** hasta que se deploy el CAR nuevo, el MI sigue teniendo `jwtValidator` en el flujo.
Si el APIM ya está configurado con el KM Dnato pero el MI no tiene `EmprIdFromHeader.xml`, las
APIs MCP van a fallar (el MI llama a `emprIdFromHeader` que no existe). Sincronizar B4 y B3.

---

### B5 — Tests Hurl ✅ DONE (Sprint 2)

`tests/security/jwt-validation.hurl` actualizado: apunta a `{{APIM_HOST}}` (`:8243`), casos
a-h. Caso h verifica anti-spoofing (Fix 1). `tests/security/mi-fallback.hurl` (nuevo): verifica
Fix 3 llamando al MI directo (`:8280`) sin `X-Empr-Id` → 503. Los tests de aislamiento del
DataService (`dataservice-isolation.hurl`) no cambian.

---

## Secuencia de ejecución recomendada

Para evitar estado inconsistente durante el despliegue:

```
1. B1: verificar JWKS accesible (prerequisito para B2)
2. B2: registrar KM Dnato en Admin (prerequisito para B3)
3. B4: build + deploy del CAR al MI
4. B3: asociar in-sequence y KM Dnato en Publisher + re-publicar APIs
5. B5: ejecutar tests Hurl actualizados para verificar el flujo end-to-end
```

**Ventana de inconsistencia (entre B4 y B3):** el MI tiene `emprIdFromHeader` pero el APIM
todavía no valida ni inyecta. Los requests llegarán al MI sin `X-Empr-Id` y responderán 400.
Planificar B4 y B3 en la misma ventana de mantenimiento para minimizar esta ventana.
