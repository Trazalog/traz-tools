# Historia E9-IDENT-05 — Revisada (ADR-008, Mayo 2026)

**Historia original:** "Validación JWT en WSO2 MI — JwtValidator.xml"
**Razón de la revisión:** ADR-008 descartó el patrón "JWT passthrough al MI". La validación
y la inyección del `empr_id` ocurren ahora en el APIM, no en el MI.

---

## Alcance revisado

### Qué se hizo en esta revisión (Sprint 2, junio 2026)

**APIM — nuevo:**
- Configurar Dnato como Key Manager federado en la consola Admin del APIM (RS256 + JWKS).
  Procedimiento: [`apim-keymanager-dnato.md`](../identity/apim-keymanager-dnato.md).
- Crear la in-sequence `EmprIdInjectorPolicy` (XML en `doc/identity/apim-empr-id-injector-policy.xml`)
  que extrae `empr_id` del JWT validado y lo inyecta como header `X-Empr-Id`.
- Asociar la policy y el Key Manager Dnato a las APIs Equipos y Ordenes de Trabajo en el Publisher.
  Procedimiento: [`openapi-publish-procedure.md`](../api/openapi-publish-procedure.md).

**MI — modificado:**
- Crear sequence `EmprIdFromHeader.xml` que lee `X-Empr-Id` del header y setea `jwt_empr_id`
  en el contexto (reemplaza la combinación `jwtValidator + emprIdInjector`).
- Actualizar los 5 resources MCP en `toolsMANAPI.xml` para invocar `emprIdFromHeader`
  en lugar de `jwtValidator + emprIdInjector`.
- Anotar `JwtValidator.xml` como out-of-flow para MCP (se mantiene en repo para referencia).

**Documentación:**
- [`dnato-jwt-prereqs.md`](../identity/dnato-jwt-prereqs.md) — confirma que Dnato cumple.
- [`empr-id-injection.md`](../identity/empr-id-injection.md) — diseño del flujo nuevo.
- [`gateway-token-validation.md`](../identity/gateway-token-validation.md) — marcado como
  reemplazado.

### Qué NO cambia

- La lógica downstream del MI: sigue usando `get-property('jwt_empr_id')` para construir URLs.
- Los DataServices: no se tocan; filtran por `empr_id` exactamente igual que antes.
- Dnato: no requiere cambios de código para el MVP. RS256 + JWKS ya están.

---

## Criterios de aceptación (vigentes)

- [ ] JWT válido de Dnato → 200 desde el APIM gateway (`:8243`)
- [ ] JWT inválido / expirado / sin firma → 401 del APIM; el MI no registra el request
- [ ] JWT de empresa A no devuelve datos de empresa B (aislamiento end-to-end)
- [ ] APIs legacy (con Resident KM) no se ven afectadas (siguen respondiendo 200 con su token)
- [ ] `enable_outbound_auth_header` NO está en ningún `deployment.toml`
- [ ] `JwtValidator.xml` tiene el comentario ADR-008 y no se invoca en el flujo MCP

---

## Tareas pendientes de ejecución (configuración en APIM, no código)

Estas tareas son procedimentales — requieren acceso a la consola Admin del APIM y
confirmación del PM antes de ejecutar en cualquier entorno:

1. **[BLOQUEANTE para demo]** Verificar accesibilidad del JWKS de Dnato desde el host del APIM.
   Procedimiento: `apim-keymanager-dnato.md §2`.
2. **[BLOQUEANTE para demo]** Registrar el Key Manager Dnato en la consola Admin.
   Procedimiento: `apim-keymanager-dnato.md §3`.
3. **[BLOQUEANTE para demo]** Subir la in-sequence `apim-empr-id-injector-policy.xml` a las APIs
   Equipos y OTs en el Publisher. Procedimiento: `openapi-publish-procedure.md §3.4`.
4. Deploy del CAR actualizado al MI (incluye `EmprIdFromHeader.xml`).
   Ver checklist de blockers: [`blockers-adr-008.md`](blockers-adr-008.md).

---

## Referencia

- [ADR-008 en TRAZALOG_v3_MCP_ARCHITECTURE.md §14](../v3/TRAZALOG_v3_MCP_ARCHITECTURE.md)
- Historia original: `doc/identity/gateway-token-validation.md` (referencia histórica)
