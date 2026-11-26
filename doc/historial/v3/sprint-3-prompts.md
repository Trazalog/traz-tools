# Sprint 3 — Prompts para Claude Code

> **Cómo se usa este archivo:**
> - Rodolfo le dice a Claude Code: *"Leé doc/v3/sprint-3-prompts.md y doc/v3/STATE.md. Ejecutá la próxima tarea pendiente (o el próximo bloque encadenable), respetando los bloqueos marcados."*
> - Claude Code ejecuta **en orden**, de arriba hacia abajo, **saltando lo marcado como 🔴 BLOQUEADO**.
> - Las tareas 🟢/🟡 marcadas **[ENCADENABLE]** pueden ir juntas en un solo PR. Las que dicen **[PR PROPIO]** van solas.
> - Al llegar a una 🔴 BLOQUEADA, Claude Code **PARA y avisa** — no la ejecuta. Esa tarea requiere un workshop CW+Rodolfo o una decisión del PM que todavía no se tomó.
>
> **Regla transversal para TODAS las tareas de este archivo:**
> Ante cualquier duda funcional, de negocio o de arquitectura — o si algo contradice el CONTEXT-PACK o un ADR — **PARÁ y consultá a Rodolfo. NO definas por tu cuenta.** Preferimos una pregunta de más que un desvío. (Regla de escalamiento, CLAUDE.md.)

---

## BLOQUE 0 — Relevamiento para unificación MCP (E2-MCP-10-RELEV) ✅ COMPLETADO

> **✅ Hecho.** Entregable: `doc/v3/relevamiento-unificacion-mcp.md`. Resultado: WSO2 4.6 no permite agrupar varias APIs en un MCP Server → la unificación se logra con una API fachada única. El workshop ADR-013 cerró con esa decisión. Ver Bloque 3 para la implementación.

---

## BLOQUE 1 — Cerrar trabajo ya hecho (2 PRs pendientes) [ENCADENABLE, pero cada PR es su propio PR]

Hay dos ramas con trabajo terminado que nunca se abrieron como PR. Abrirlos es lo primero, para no perder trazabilidad.

### Tarea 1.1 — Abrir PR de los fixes post-merge de infra [PR PROPIO]

```
╔════════════════════════════════════════════╗
║ REPO: traz-tools → /mnt/win/dev/git/traz-tools ║
╚════════════════════════════════════════════╝

Leé doc/v3/CONTEXT-PACK.md y doc/v3/STATE.md antes de empezar.

Tarea: Abrir el PR de la rama fix/e7-infra-01-02-post-merge-followups → develop-v3.
Clase: 🟡

Esta rama ya tiene los fixes encontrados durante la ejecución real de E7-INFRA-01/02
(SELinux restorecon, repo JDK rhel/9, nota H2 vs PostgreSQL en ADR-011). El trabajo
está hecho y commiteado; solo falta abrir el PR.

Acciones:
1. Verificá que la rama está pusheada y al día con develop-v3 (rebase si hace falta).
2. Verificá que no hay marcadores de conflicto ni secretos (.env real no trackeado).
3. Abrí el PR con el formato obligatorio (Qué cambia / Por qué / Cómo lo verifiqué / Closes si aplica).
4. NO mergees — dejalo para review de Rodolfo.

Reportá el número de PR.
```

### Tarea 1.2 — Abrir PR del relevamiento de estado [PR PROPIO]

```
╔════════════════════════════════════════════╗
║ REPO: traz-tools → /mnt/win/dev/git/traz-tools ║
╚════════════════════════════════════════════╝

Leé doc/v3/CONTEXT-PACK.md y doc/v3/STATE.md antes de empezar.

Tarea: Abrir el PR de la rama docs/e1-api-20-sprint3-relevamiento-estado → develop-v3.
Clase: 🟢 (solo un documento).

Esta rama tiene doc/v3/sprint-3-relevamiento-estado.md (el relevamiento de los 3 frentes).
El trabajo está hecho; falta abrir el PR.

Acciones:
1. Verificá que la rama está al día con develop-v3.
2. Abrí el PR con el formato obligatorio.
3. NO mergees — review de Rodolfo.

Reportá el número de PR.
```

> **Después del Bloque 1:** Rodolfo revisa y mergea ambos PRs. Recién con ellos mergeados, seguir al Bloque 2.

---

## BLOQUE 2 — Configuración de identidad en la VM nueva (E7-INFRA-03) [PR PROPIO]

```
╔════════════════════════════════════════════╗
║ REPO: traz-tools → /mnt/win/dev/git/traz-tools ║
╚════════════════════════════════════════════╝

Leé doc/v3/CONTEXT-PACK.md, doc/v3/STATE.md, doc/adr/ADR-008 y doc/adr/ADR-009
antes de empezar.

Tarea: E7-INFRA-03 — Configurar el mecanismo de identidad (ADR-008/009) en la VM
de GCP recién desplegada, para que el flujo OAuth funcione contra el Dnato real
(no el de DEV/ngrok).
Clase: 🟡

Contexto: La VM nueva (mcp.cloudtrazalog.com) ya corre APIM 4.6 + MI 4.5 con TLS
(E7-INFRA-01/02). Falta que el APIM valide los JWT de Dnato como Key Manager
federado (ADR-008) y que el MI derive empr_id del X-JWT-Assertion (ADR-009) —
igual que funciona en DEV, pero apuntando al Dnato de producción/test que ya
existe en el mismo proyecto GCP.

Acciones:
1. Revisá cómo quedó configurado esto en DEV (Key Manager federado en el APIM,
   apim.jwt.enable=true, header X-JWT-Assertion, sequence EmprIdFromHeader en el MI).
2. Producí la configuración/checklist para replicarlo en la VM nueva:
   - Registrar el Dnato existente como Key Manager en el APIM de la VM.
   - Configurar el discovery OAuth apuntando al Dnato real (URL de producción, no ngrok).
   - Verificar que apim.jwt.enable y el X-JWT-Assertion estén activos.
3. IMPORTANTE — parte de esto requiere acciones en la consola del APIM y datos que
   solo Rodolfo tiene (URL exacta del Dnato de producción, credenciales del Key
   Manager). Para todo lo que no puedas hacer vos: dejá un checklist claro en
   doc/v3/deployment-gcp.md (sección "Configuración de identidad") para que Rodolfo
   lo ejecute.
4. Si durante la tarea encontrás que falta una decisión (ej: qué URL de Dnato usar,
   si el Dnato de producción ya expone el discovery RFC 8414, o si hay que tocar
   algo en Dnato) → PARÁ y consultá a Rodolfo. NO asumas.

DoD:
- [ ] Documentado cómo se configura el Key Manager federado en la VM nueva
- [ ] Checklist para Rodolfo de lo que requiere consola/credenciales
- [ ] Preguntas abiertas listadas si las hay
- [ ] STATE.md actualizado
- [ ] PR con formato obligatorio, sin mergear

NO mergees. Review de Rodolfo.
```

---

## BLOQUE 3 — Unificación MCP + Almacenes (ADR-013) — la fachada toolsMCPAPI

> **Desbloqueado:** el workshop ADR-013 cerró. `doc/adr/ADR-013-unificacion-mcp.md` está en el repo. La decisión: una fachada MI DELGADA (`toolsMCPAPI`) que resuelve empr_id una vez y rutea a los DataServices existentes, expuesta como UN SOLO Virtual MCP Server con tools prefijadas por módulo (`man_`, `alm_`).
>
> **Orden estricto:** 3.1 → 3.2 → 3.3 → 3.4 → 3.5, en secuencia. Cada una es **[PR PROPIO]**.
> **Regla de tests (decisión del PM):** cada tarea que construya o modifique una tool deja sus tests automatizados como parte del DoD — NO hay tarea de smoke test aparte.

### Tarea 3.1 — Verificar ruteo múltiple + crear el esqueleto de toolsMCPAPI (E2-MCP-11) [PR PROPIO]

```
╔════════════════════════════════════════════╗
║ REPO: traz-tools → /mnt/win/dev/git/traz-tools ║
╚════════════════════════════════════════════╝

Leé doc/v3/CONTEXT-PACK.md, doc/v3/STATE.md, doc/adr/ADR-013-unificacion-mcp.md y
doc/v3/relevamiento-unificacion-mcp.md antes de empezar.

Tarea: E2-MCP-11 — Verificar el ruteo a múltiples DataServices y crear el esqueleto
de la fachada toolsMCPAPI.
Clase: 🔴 (toca la arquitectura MCP; primer paso de la unificación).

PASO 1 OBLIGATORIO — VERIFICACIÓN (parada obligatoria si falla):
El ADR-013 (decisión #6) asume que un artefacto MI puede rutear a varios DataServices
(MANDataService y ALMDataService) desde una sola API. Es lo normal en WSO2 MI, pero el
relevamiento no lo confirmó en vivo. ANTES de construir nada:
- Hacé una prueba mínima: un artefacto/recurso MI que llame a DOS DataServices distintos.
- Si funciona → seguí al paso 2.
- Si NO funciona o encontrás una limitación → PARÁ, documentá qué pasó, y consultá a
  Rodolfo. NO improvises un workaround.

PASO 2 — Esqueleto de toolsMCPAPI:
- Creá el artefacto MI toolsMCPAPI (nuevo, context propio, ej. /tools/mcp) como
  FACHADA DELGADA: NO reimplementa lógica, solo resolverá empr_id (sequence
  EmprIdFromHeader, ADR-009) y ruteará a los DataServices/lógica existentes.
- En esta tarea, implementá SOLO UNA tool de prueba de punta a punta (ej.
  man_get_equipos) para validar el patrón completo: EmprIdFromHeader → ruteo a
  MANDataService → respuesta. Con prefijo man_ en el nombre.
- Dejá el esqueleto preparado para sumar el resto de las tools en las tareas siguientes.

DoD:
- [ ] Verificación de ruteo múltiple documentada (funciona / no funciona)
- [ ] toolsMCPAPI creado con EmprIdFromHeader y una tool de prueba (man_get_equipos)
- [ ] empr_id derivado del JWT, nunca del caller
- [ ] Tests automatizados de la tool de prueba
- [ ] STATE.md actualizado
- [ ] PR con formato obligatorio, sin mergear

🔴 Parada obligatoria en el PASO 1 si el ruteo múltiple no funciona. Ante cualquier
otra duda, PARÁ y consultá a Rodolfo.
```

### Tarea 3.2 — Migrar las tools de mantenimiento a la fachada (E2-MCP-12) [PR PROPIO]

```
╔════════════════════════════════════════════╗
║ REPO: traz-tools → /mnt/win/dev/git/traz-tools ║
╚════════════════════════════════════════════╝

Leé CONTEXT-PACK, STATE y ADR-013. Requiere E2-MCP-11 mergeado.

Tarea: E2-MCP-12 — Migrar las 5 tools de mantenimiento a toolsMCPAPI con prefijo man_.
Clase: 🟡

Sumá a la fachada toolsMCPAPI el resto de las tools de mantenimiento, replicando el
patrón validado en 3.1:
- man_get_equipos (ya en 3.1), man_get_equipo, man_get_ots, man_get_ot, man_create_ot
- Rutas internas prefijadas: /mcp/man/...
- man_create_ot mantiene el patrón BPM + rollback ya probado en toolsMANAPI (NO
  reimplementar la lógica: la fachada rutea a lo existente).
- empr_id del JWT en todas.

IMPORTANTE: esto NO toca todavía los Virtual MCP Servers viejos (trazalog-equipos/ots)
— siguen activos. Solo se construye la fachada en paralelo. La migración del cliente
se hace en 3.4.

DoD:
- [ ] Las 5 tools de mantenimiento en toolsMCPAPI con prefijo man_
- [ ] man_create_ot con BPM+rollback funcionando (ruteo, no reimplementación)
- [ ] Tests automatizados de cada tool
- [ ] STATE.md actualizado
- [ ] PR con formato obligatorio, sin mergear

Ante cualquier duda, PARÁ y consultá a Rodolfo.
```

### Tarea 3.3 — Sumar almacenes a la fachada (E1-ALM-01/02 unificadas) [PR PROPIO]

```
╔════════════════════════════════════════════╗
║ REPO: traz-tools → /mnt/win/dev/git/traz-tools ║
╚════════════════════════════════════════════╝

Leé CONTEXT-PACK, STATE, ADR-012 y ADR-013. Requiere E2-MCP-12 mergeado.

Tarea: E1-ALM — Sumar las tools de almacenes a toolsMCPAPI con prefijo alm_.
Clase: 🔴 (incluye crear_pedido con escritura + BPM).

Según ADR-012 (alcance almacenes) + ADR-013 (fachada unificada), agregá a toolsMCPAPI:
- Lecturas (análogas a mantenimiento): alm_get_stock (o el nombre real de la query de
  stock/artículos/movimientos que releves del ALMDataService), alm_get_pedidos_materiales,
  alm_get_pedido_material. Rutas /mcp/alm/...
- Escritura: alm_crear_pedido_materiales — replica el patrón de man_create_ot (INSERT +
  BPM Bonita + rollback). NO toca stock (es una solicitud). Annotation de confirmación
  (openWorldHint).
- empr_id del JWT en todas (cierra el gap de seguridad del relevamiento: ALMDataService
  hoy recibe empr_id del caller; en la fachada NUNCA se acepta como parámetro).

PUNTOS DE PARADA OBLIGATORIA (🔴): si no conocés el proceso Bonita del pedido, el
payload real (campos del pedido), o si el ALMDataService no es análogo a MANDataService
→ PARÁ y consultá a Rodolfo.

DoD:
- [ ] 3 lecturas + alm_crear_pedido_materiales en toolsMCPAPI, prefijo alm_
- [ ] Aislamiento verificado: no se puede pasar empr_id de otra empresa
- [ ] crear_pedido con BPM+rollback + confirmación; verificado que el rollback dispara
- [ ] Tests automatizados de cada tool (incluida la prueba de aislamiento 2 empresas)
- [ ] STATE.md actualizado
- [ ] PR con formato obligatorio, sin mergear

🔴 Paradas obligatorias marcadas arriba. Ante cualquier duda, PARÁ y consultá a Rodolfo.
```

### Tarea 3.4 — Publicar la API + Virtual MCP Server único + migración coordinada (E2-MCP-13) [PR PROPIO]

```
╔════════════════════════════════════════════╗
║ REPO: traz-tools → /mnt/win/dev/git/traz-tools ║
╚════════════════════════════════════════════╝

Leé CONTEXT-PACK, STATE y ADR-013. Requiere E1-ALM (3.3) mergeado.

Tarea: E2-MCP-13 — OpenAPI unificada + Virtual MCP Server único + guía de migración.
Clase: 🟡 (el trabajo de consola lo hace Rodolfo; Code prepara los artefactos y la guía).

1. Creá la spec OpenAPI unificada doc/api/trazalog-operaciones.yaml con TODAS las tools
   (man_* + alm_*), descripciones semánticas, empr_id AUSENTE de los parámetros de
   request (el gateway lo extrae del JWT), y las annotations de confirmación en las
   tools de escritura (man_create_ot, alm_crear_pedido_materiales).
2. Creá doc/mcp/virtual-mcp-unificado.md con:
   - La tabla completa de tools del server unificado
   - Los pasos de consola WSO2 para Rodolfo: publicar la API fachada en el Publisher y
     generar UN Virtual MCP Server (ej. trazalog-operaciones) desde ella.
   - La GUÍA DE MIGRACIÓN COORDINADA (ADR-013 decisión #5): orden estricto →
     (a) crear y publicar el unificado, (b) smoke test de las 9 tools, (c) reconfigurar
     Claude.ai a la URL nueva, (d) RECIÉN ahí despublicar trazalog-equipos y trazalog-ots.
   - Advertencia explícita: NO despublicar los viejos antes de verificar el nuevo.

DoD:
- [ ] trazalog-operaciones.yaml con las 9 tools, empr_id ausente de request
- [ ] virtual-mcp-unificado.md con pasos de consola + guía de migración coordinada
- [ ] STATE.md actualizado
- [ ] PR con formato obligatorio, sin mergear

Ante cualquier duda, PARÁ y consultá a Rodolfo.
```

> **Después de 3.4:** Rodolfo ejecuta en la consola WSO2 (pasos manuales): publica la API fachada, genera el Virtual MCP Server unificado, hace el smoke test de las 9 tools con la prueba de aislamiento de 2 empresas, reconfigura Claude.ai, y recién despublica los viejos. Esta verificación manual es la que en Sprint 2 fue el smoke test — ahora los tests automatizados de cada tarea la respaldan.

### Tarea 3.5 — Desplegar la fachada al server GCP (E7-INFRA-05) [PR PROPIO]

```
╔════════════════════════════════════════════╗
║ REPO: traz-tools → /mnt/win/dev/git/traz-tools ║
╚════════════════════════════════════════════╝

Leé CONTEXT-PACK, STATE, ADR-011 y ADR-013. Requiere E2-MCP-13 mergeado y verificado
por Rodolfo en DEV.

Tarea: E7-INFRA-05 — Desplegar la fachada toolsMCPAPI + el Virtual MCP Server unificado
al server de GCP (mcp.cloudtrazalog.com).
Clase: 🟡

Contexto: toolsMCPAPI y el Virtual MCP Server unificado funcionan en el DEV de Rodolfo.
Falta llevarlos a la VM de GCP (la que E7-INFRA-01/02 dejó lista: APIM 4.6 + MI 4.5
nativo, Caddy con TLS en mcp.cloudtrazalog.com).

1. Preparar los artefactos desplegables (el CApp/CAR del MI con toolsMCPAPI, la config
   de la API para el APIM) y documentar el procedimiento de despliegue al server GCP.
2. Como el despliegue en sí requiere acceso a la VM (que solo tiene Rodolfo): dejá un
   checklist claro en doc/v3/deployment-gcp.md (sección "Despliegue de la fachada MCP")
   con los pasos que Rodolfo ejecuta en el server: desplegar el CAR al MI, publicar la
   API y el Virtual MCP Server en el APIM de la VM, verificar el flujo OAuth end-to-end
   contra mcp.cloudtrazalog.com.
3. Incluí en el checklist la verificación de que el aislamiento multi-tenant funciona
   también en el server GCP (prueba de 2 empresas contra la URL pública).

DoD:
- [ ] Artefactos desplegables preparados
- [ ] Checklist de despliegue al server GCP en deployment-gcp.md
- [ ] Verificación de aislamiento incluida en el checklist
- [ ] STATE.md actualizado
- [ ] PR con formato obligatorio, sin mergear

Ante cualquier duda (sobre todo si el despliegue difiere de lo que quedó documentado
en E7-INFRA), PARÁ y consultá a Rodolfo.
```

> **Después del Bloque 3:** el MCP unificado está corriendo en GCP, con las 9 tools (mantenimiento + almacenes), aislamiento verificado, listo para el early adopter. Queda el frente de negocio (deck, auditoría de datos del cliente, sesión guiada) del kickoff.


## Estado de este archivo

- **✅ Completado:** Bloque 0 (relevamiento) → ADR-013 cerrado y mergeado.
- **Desbloqueado y listo para ejecutar (en orden):**
  - Bloque 2 (identidad E7-INFRA-03) — independiente, se puede hacer cuando quieras
  - Bloque 3 completo, secuencial: 3.1 (fachada + verificación ruteo 🔴) → 3.2 (mantenimiento a la fachada) → 3.3 (almacenes 🔴) → 3.4 (publicar + Virtual MCP único + migración) → 3.5 (desplegar a GCP)
- **Bloque 1:** ya mergeado (#403/#404).
- **Paradas obligatorias 🔴:** Tarea 3.1 (verificación de ruteo múltiple) y 3.3 (proceso Bonita/payload de almacenes).
- **Tests:** cada tarea deja sus tests automatizados (decisión del PM, sin tarea de smoke test aparte).
- **Pendiente fuera de este archivo:** frente de negocio del kickoff (deck, auditoría de datos del cliente, sesión guiada) — no es trabajo de Claude Code.
- CW actualiza este archivo a medida que se destraban los bloques.
