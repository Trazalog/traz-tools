# ADR-009 — Inyección de `empr_id` vía backend JWT (X-JWT-Assertion) en lugar de EmprIdInjectorPolicy

**Estado:** Aceptado
**Fecha:** 2026-07
**Contexto:** ADR-008 (multi-tenancy MCP) — implementación end-to-end Sprint 2
**Decisores:** PM (Rodolfo Ruiz)
**Prerequisitos:** ADR-003 (mapeo PHP→WSO2), ADR-008 (aislamiento por `empr_id` del JWT), E9-IDENT-01 (investigación aislamiento)

---

## Contexto

ADR-008 estableció que el aislamiento multi-tenant de las operaciones MCP se apoya en el
claim `empr_id` del JWT emitido por Dnato: cada DataService filtra por la empresa del token,
de modo que el agente MCP no puede elegir la empresa desde el prompt.

Para propagar ese `empr_id` desde el gateway hasta el DataService, ADR-008 especificó una
**`EmprIdInjectorPolicy`** — una *operation policy* del gateway de APIM que extraería el
`empr_id` del JWT ya validado y lo inyectaría como header de transporte (`X-Empr-Id`) hacia
el backend. El artefacto conceptualmente equivalente en el plano MI es la sequence
`emprIdInjector` (`EmprIdInjector.xml`), que hace:

```xml
<header name="X-Empr-Id" scope="transport"
        expression="get-property('jwt_empr_id')"/>
```

Esta sequence **depende de que exista una propiedad de contexto `jwt_empr_id`**, es decir,
de que un paso previo haya tenido acceso al JWT para extraer el claim. Ese es exactamente el
supuesto que se rompió en la implementación.

---

## Problema descubierto

Al implementar la policy en el gateway de APIM 4.6.0 se comprobó que **la operation policy
no tiene acceso al JWT**:

- APIM valida el `Authorization: Bearer <JWT>` en su handler de seguridad y, **una vez
  validado, descarta el header `Authorization`** antes de ejecutar las operation policies y
  antes de enrutar al backend. Es un comportamiento deliberado de APIM (no reenviar la
  credencial del cliente aguas abajo por defecto).
- En consecuencia, cuando la `EmprIdInjectorPolicy` se ejecuta, **el JWT ya no está
  disponible**: no puede leer el claim `empr_id` porque no tiene de dónde extraerlo. La
  propiedad `jwt_empr_id` de la que depende `emprIdInjector` nunca se puebla por esta vía.

Es decir, el diseño original de ADR-008 era irrealizable tal cual: presuponía que la policy
podía inspeccionar el JWT, cosa que el modelo de seguridad de APIM no permite en ese punto
del pipeline.

Existía la opción de forzar el reenvío del token con `enable_outbound_auth_header=true`
(que reenvía el `Authorization` original al backend), pero eso viola las restricciones de
ADR-008 (ver §4) y se descartó.

---

## Decisión

Usar el mecanismo **nativo de "backend JWT" de WSO2 API Manager** (`X-JWT-Assertion`):

1. Habilitar en `deployment.toml`:

   ```toml
   [apim.jwt]
   enable = true
   header = "X-JWT-Assertion"
   convert_dialect = false
   ```

2. Registrar a Dnato como issuer y mapear los claims necesarios sin renombrarlos:

   ```toml
   [[apim.jwt.issuer]]
   name = "trazalog-dnato"
   ...
   [[apim.jwt.issuer.claim_mapping]]
   remote_claim = "empr_id"
   local_claim  = "empr_id"
   [[apim.jwt.issuer.claim_mapping]]
   remote_claim = "empr_id_mysql"
   local_claim  = "empr_id_mysql"
   ```

   `convert_dialect = false` mantiene los claims con su nombre original (`empr_id`,
   `empr_id_mysql`) en vez de namespacearlos.

3. Con esto, **tras validar el JWT de Dnato, APIM genera un JWT propio** (firmado por la
   clave del gateway) que incluye los claims mapeados y lo adjunta en el header
   `X-JWT-Assertion` hacia el backend.

4. En el MI, la sequence **`EmprIdFromHeader.xml`** reemplaza a `emprIdInjector`: decodifica
   el payload de `X-JWT-Assertion` y deriva `empr_id` (y `empr_id_mysql`) de esa assertion
   firmada por APIM, para pasarlo como parámetro al DataService.

```
Claude → Bearer <JWT Dnato> → APIM (valida RS256/iss vía JWKS Dnato; descarta Authorization)
        → re-emite backend JWT en X-JWT-Assertion (empr_id, empr_id_mysql)
        → MI EmprIdFromHeader (deriva empr_id del X-JWT-Assertion) → DataService → BD
```

---

## Por qué NO viola las restricciones de ADR-008

ADR-008 prohíbe que el backend confíe en un `empr_id` provisto/forjable por el cliente y que
la credencial del cliente se reenvíe sin control aguas abajo. El mecanismo elegido lo
respeta:

- **No se usó `enable_outbound_auth_header`.** Esa opción reenviaría el `Authorization`
  original (el Bearer del cliente) al backend. No se activó. Importa porque:
  - Reenviar el token del cliente expondría la credencial completa a los servicios internos
    (amplía la superficie y el blast radius si un backend se ve comprometido).
  - El backend tendría que re-validar el token del cliente por su cuenta, duplicando la
    lógica de confianza.
- **`X-JWT-Assertion` no es la credencial del cliente:** es un JWT **nuevo, firmado por el
  gateway de APIM**. El cliente no puede fabricarlo ni alterarlo (no tiene la clave de firma
  del gateway). El `empr_id` que llega al DataService proviene, por lo tanto, de una
  assertion emitida por un componente de confianza tras validar el token original —
  **exactamente la garantía que ADR-008 exige** (el `empr_id` no es elegible por el agente).
- El `Authorization` original **sigue siendo descartado** en el borde; el backend nunca ve
  el Bearer del cliente.

En síntesis: cambia el *transporte* del `empr_id` (de un header `X-Empr-Id` puesto por una
policy, a un claim dentro de un JWT firmado por el gateway), pero **la propiedad de seguridad
—`empr_id` no falsificable por el cliente— se mantiene idéntica**.

---

## Impacto: EmprIdInjectorPolicy / `emprIdInjector` deprecados

- La `EmprIdInjectorPolicy` (operation policy) **no se despliega**: era irrealizable (§2).
- La sequence MI `EmprIdInjector.xml` (`emprIdInjector`) queda **deprecada**. Se decide:
  - **Retenerla en el repo como referencia**, marcada como deprecada en su encabezado, y
    **desconectada de la cadena de llamadas** — el MAN API pasa a invocar la lógica de
    `EmprIdFromHeader.xml` en su lugar.
  - **No borrarla todavía:** la rewiring del MAN API a `X-JWT-Assertion` vive en la rama
    `feature/e2-mcp-equipos-ots` y aún no está mergeada a `develop-v3` (donde `toolsMANAPI`
    todavía referencia `emprIdInjector`/`X-Empr-Id`). El borrado definitivo de
    `EmprIdInjector.xml` se difiere a una tarea de limpieza **post-merge**, una vez validado
    en `develop-v3`.
- Nota de estado: al momento de este ADR, el mecanismo nuevo está implementado y verificado
  en `feature/e2-mcp-equipos-ots`; `develop-v3` conserva el mecanismo viejo hasta el merge.

---

## Verificación

El nivel de aislamiento se mantiene con el mecanismo nuevo, evidenciado por:

- **Sesión ADR-008 — tokens `empr_id=8` vs `empr_id=9` (anti-spoofing):** dos JWT de empresas
  distintas devuelven datasets disjuntos; un intento de forzar el `empr_id` desde el cliente
  (spoofing del header `X-Empr-Id`) es **ignorado**, porque el `empr_id` efectivo proviene
  del `X-JWT-Assertion` firmado por APIM, no de headers del cliente.
- **E2-MCP-09b — Empresa_Test vs MinTest_SJ** (ver
  [`doc/mcp/demo-smoke-test.md`](../mcp/demo-smoke-test.md)):
  - `admin@gmail.com` (Empresa_Test, `empr_id=1`) → **4 equipos** (BOMB-001, COMP-001,
    GEN-001, GHOR-001).
  - `admin@mintest-sj.local` (MinTest_SJ, `empr_id=187`) → **3 equipos** (BOMB-SJ-001,
    COMP-SJ-001, MOTO-SJ-001).
  - Sin cruce de datos entre sesiones — el filtrado ocurre server-side a partir del claim del
    `X-JWT-Assertion`.

Ambos conjuntos de pruebas confirman que sustituir `EmprIdInjectorPolicy`/`X-Empr-Id` por
`X-JWT-Assertion` **no degrada** el aislamiento multi-tenant.

---

## Deuda técnica relacionada (Sprint 3)

- **Hardening de la validación de firma del `X-JWT-Assertion` en PROD.** En DEV la
  verificación de la firma del backend JWT y del JWKS de Dnato está relajada (JWKS local,
  hostname verification off). En PROD hay que: validar estrictamente la firma del
  `X-JWT-Assertion` en el MI (clave pública del gateway), JWKS de Dnato por HTTPS con cadena
  válida, rotación de `kid`, y validación de `aud`/`iss`. Ya listado en
  [`doc/mcp/demo-smoke-test.md`](../mcp/demo-smoke-test.md) §5.

---

## Referencias

- ADR-003 — Estrategia de mapeo PHP/CodeIgniter a WSO2 (documenta el flujo `emprIdInjector`
  / `X-Empr-Id` que este ADR supersede en ese punto).
- ADR-008 — Aislamiento multi-tenant por `empr_id` del JWT (decisión trazada vía commits
  `[ADR-008]` y backlog; sin archivo ADR standalone).
- [`doc/mcp/demo-smoke-test.md`](../mcp/demo-smoke-test.md) — Evidencia E2-MCP-09 / E2-MCP-09b.
- `deployment.toml` — bloque `[apim.jwt]` y `[[apim.jwt.issuer.claim_mapping]]`.
- Artefactos MI: `EmprIdFromHeader.xml` (nuevo), `EmprIdInjector.xml` (deprecado).
