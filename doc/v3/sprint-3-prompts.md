# Sprint 3 — Prompts para Claude Code (frente INFRA)

> **Cómo se usa este archivo:**
> - Rodolfo le dice a Claude Code: *"Leé doc/v3/sprint-3-prompts.md y doc/v3/STATE.md. Ejecutá la próxima tarea pendiente (o el próximo bloque encadenable), respetando los bloqueos marcados."*
> - Claude Code ejecuta **en orden**, de arriba hacia abajo, **saltando lo marcado como 🔴 BLOQUEADO**.
> - Las tareas 🟢/🟡 marcadas **[ENCADENABLE]** pueden ir juntas en un solo PR. Las que dicen **[PR PROPIO]** van solas.
> - Al llegar a una 🔴 BLOQUEADA, Claude Code **PARA y avisa** — no la ejecuta. Esa tarea requiere un workshop CW+Rodolfo o una decisión del PM que todavía no se tomó.
>
> **Regla transversal para TODAS las tareas de este archivo:**
> Ante cualquier duda funcional, de negocio o de arquitectura — o si algo contradice el CONTEXT-PACK o un ADR — **PARÁ y consultá a Rodolfo. NO definas por tu cuenta.** Preferimos una pregunta de más que un desvío. (Regla de escalamiento, CLAUDE.md.)

---

## BLOQUE 0 — Relevamiento para unificación MCP (E2-MCP-10-RELEV) [PR PROPIO] ⭐ PRÓXIMA TAREA

> **Contexto:** Rodolfo quiere unificar los Virtual MCP Servers separados (equipos, ots, y el futuro almacenes) en UN SOLO MCP Server con todas las tools, URLs prefijadas por módulo (ej. `/man/...`, `/alm/...`). Esto es un cambio de arquitectura (ADR-013, pendiente) que toca lo que YA funciona en producción-demo. Antes de decidir el ADR, hace falta relevar terreno real: ni CW ni Rodolfo tienen certeza de dos cosas técnicas.
>
> **Esta tarea va PRIMERO en el frente de unificación. Bloquea el ADR-013 y, por lo tanto, la construcción final de almacenes** (porque se decidió que almacenes nazca dentro del MCP unificado).

```
╔════════════════════════════════════════════╗
║ REPO: traz-tools → /mnt/win/dev/git/traz-tools ║
╚════════════════════════════════════════════╝

Leé doc/v3/CONTEXT-PACK.md, doc/v3/STATE.md y doc/v3/TRAZALOG_v3_MCP_ARCHITECTURE.md
(sección de Virtual MCP Servers) antes de empezar.

Tarea: E2-MCP-10-RELEV — Relevamiento para la unificación de los Virtual MCP Servers.
Clase: 🟢 (relevamiento + documento, no modifica nada de la config actual).

OBJETIVO: responder con datos reales dos preguntas que hoy no tienen certeza, para
que el PM+CW decidan el ADR-013 (unificación MCP) sin adivinar. NO implementar la
unificación — solo relevar y reportar.

CONTEXTO ARQUITECTÓNICO (confirmado): el flujo real de Trazalog es
DataServices (MI) → APIs WSO2 (con recursos /mcp/... que derivan empr_id del
X-JWT-Assertion, nunca del caller) → Virtual MCP Server (APIM 4.6). En el Sprint 2
se crearon Virtual MCP Servers SEPARADOS (uno para equipos, uno para OTs).

PREGUNTA 1 — ¿Se puede agrupar varias APIs en un solo Virtual MCP Server?
- Investigá, en la consola WSO2 APIM 4.6 real de este entorno Y en la documentación
  oficial de la versión 4.6, si un Virtual MCP Server puede componerse tomando
  operaciones/tools de VARIAS APIs WSO2 distintas (ej: toolsMANAPI + toolsALMAPI en
  un mismo MCP Server), o si cada Virtual MCP Server se ata a UNA sola API/OpenAPI.
- Si se puede agrupar: documentá el mecanismo exacto (cómo se seleccionan las tools
  de cada API, cómo se manejan las URLs/prefijos, si permite prefijo por módulo tipo
  /man/ y /alm/).
- Si NO se puede agrupar varias APIs: documentá la alternativa real (ej: una sola API
  WSO2 grande con todas las operaciones prefijadas → un MCP Server; o cualquier otro
  patrón que el producto soporte). NO inventes: si la doc/consola no lo aclara,
  decilo explícitamente.

PREGUNTA 2 — ¿Cómo están estructuradas HOY las APIs con recursos MCP de mantenimiento?
- Relevá en el repo (artefactos WSO2 en _backend/) y/o en la consola: los recursos
  MCP de mantenimiento (/mcp/equipo, /mcp/ot, etc.), ¿viven en una API DEDICADA a MCP
  (creada nueva para esto), o en una API WSO2 PREEXISTENTE (de v2) a la que se le
  agregaron los recursos /mcp/... junto a otros recursos no-MCP?
- Documentá: nombre real de la(s) API(s), qué recursos tiene cada una (cuáles son
  /mcp/ y cuáles no), y si equipos y OTs comparten una API o están en APIs separadas.

ENTREGABLE: doc/v3/relevamiento-unificacion-mcp.md con:
- Respuesta a Pregunta 1 (con cita a la doc oficial 4.6 o a lo visto en consola)
- Respuesta a Pregunta 2 (estructura real de las APIs de mantenimiento)
- Una sección "Opciones de unificación" que, según lo relevado, liste los caminos
  viables reales para lograr UN solo MCP Server con tools de man+alm prefijadas por
  módulo, con pros/contras de cada uno y una recomendación técnica.
- Una sección "Impacto sobre lo que ya funciona": qué habría que tocar de los Virtual
  MCP Servers actuales (equipos, ots) y qué riesgo tiene para la demo que ya anda.

REGLAS:
- Solo relevamiento. NO modifiques la configuración de los MCP Servers actuales ni
  las APIs.
- Verificá contra la doc OFICIAL de WSO2 4.6 y contra el entorno real — no asumas
  del comportamiento genérico del producto.
- Si algo no se puede determinar sin romper lo que anda, decilo como pregunta abierta.
- Actualizá STATE.md al terminar.
- PR con formato obligatorio, sin mergear.
```

> **Después del Bloque 0:** CW + Rodolfo leen el relevamiento y cierran el **ADR-013 (unificación MCP)** en un workshop corto. Recién ahí se define si los prompts de almacenes (Bloque 3) se ejecutan como están (server propio) o se reescriben para nacer dentro del MCP unificado.

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

## BLOQUE 3 — Almacenes (ADR-012 aprobado) — tools MCP ⚠️ ESPERA ADR-013

> **⚠️ NO ejecutar todavía.** El ADR-012 (aislamiento y alcance de almacenes) está aprobado, pero Rodolfo decidió que **almacenes nazca dentro del MCP unificado**. Por lo tanto, estos prompts dependen del ADR-013 (unificación MCP), que se decide después del Bloque 0 (relevamiento).
>
> **Qué puede cambiar según el ADR-013:** hoy la tarea 3.3 asume un Virtual MCP Server propio (`trazalog-almacenes`). Si la unificación define un MCP Server único, la 3.3 se reescribe para que almacenes se sume al server unificado en vez de crear uno separado. Las tareas 3.1 (lecturas) y 3.2 (crear_pedido) probablemente NO cambian — construyen la API WSO2 `toolsALMAPI`, que es independiente de cómo se agrupe el MCP Server. CW confirmará esto al cerrar el ADR-013.
>
> **Orden real:** Bloque 0 (relevamiento) → workshop ADR-013 → CW ajusta este bloque si hace falta → recién ahí se ejecuta.

### Tarea 3.1 — toolsALMAPI: las 3 operaciones de LECTURA (E1-ALM-01) [PR PROPIO]

```
╔════════════════════════════════════════════╗
║ REPO: traz-tools → /mnt/win/dev/git/traz-tools ║
╚════════════════════════════════════════════╝

Leé doc/v3/CONTEXT-PACK.md, doc/v3/STATE.md y doc/adr/ADR-012-almacenes-aislamiento.md
antes de empezar.

Tarea: E1-ALM-01 — Crear el wrapper toolsALMAPI con las operaciones de LECTURA de
almacenes, inyectando empr_id desde el JWT (patrón ADR-009).
Clase: 🟡

Contexto: Las tools de almacenes reusan EXACTAMENTE el patrón de Mantenimiento
(toolsMANAPI). El ALMDataService ya existe y hace lectura/escritura contra la BD,
igual que MANDataService. El gap a cerrar: hoy ALMDataService recibe empr_id como
parámetro del caller — en el wrapper NUNCA debe aceptarse empr_id como parámetro;
se deriva del X-JWT-Assertion vía la sequence EmprIdFromHeader (idéntico a Mantenimiento).

Alcance de lectura (según ADR-012):
- Consultar stock / artículos / movimientos (nombre exacto de la query: relevalo del
  ALMDataService existente)
- get_pedidos_materiales (lista de pedidos de la empresa) — análoga a get_ots
- get_pedido_material (detalle de un pedido; vacío si es de otra empresa) — análoga a get_ot

Acciones:
1. Estudiá cómo está resuelto toolsMANAPI (endpoints /mcp/... , uso de emprIdFromHeader,
   estructura de las sequences de lectura) — es el molde a replicar.
2. Relevá en ALMDataService las queries de lectura disponibles (stock/artículos/
   movimientos, pedidos, detalle de pedido) y sus parámetros reales.
3. Creá toolsALMAPI con las 3 operaciones de lectura, cada una:
   - Derivando empr_id del header validado (EmprIdFromHeader), NUNCA del caller.
   - Con el filtrado por empresa a nivel SQL.
4. Si al relevar el ALMDataService encontrás que la estructura NO es análoga a
   MANDataService (ej: nombres de columnas de empresa distintos, o falta el filtro
   empr_id en alguna query) → PARÁ y consultá a Rodolfo. NO improvises el aislamiento.

DoD:
- [ ] toolsALMAPI con las 3 operaciones de lectura, empr_id del JWT (no del caller)
- [ ] Verificado: no se puede pasar empr_id de otra empresa (aislamiento a nivel gateway)
- [ ] STATE.md actualizado
- [ ] PR con formato obligatorio, sin mergear

Ante cualquier duda funcional o de arquitectura: PARÁ y consultá a Rodolfo.
```

### Tarea 3.2 — crear_pedido_materiales con BPM+rollback (E1-ALM-02) [PR PROPIO]

```
╔════════════════════════════════════════════╗
║ REPO: traz-tools → /mnt/win/dev/git/traz-tools ║
╚════════════════════════════════════════════╝

Leé doc/v3/CONTEXT-PACK.md, doc/v3/STATE.md y doc/adr/ADR-012-almacenes-aislamiento.md
antes de empezar. Requiere E1-ALM-01 ya mergeado.

Tarea: E1-ALM-02 — Agregar la operación de ESCRITURA crear_pedido_materiales a
toolsALMAPI, con el mismo patrón de create_ot (BPM Bonita + rollback).
Clase: 🔴 (escritura que dispara proceso externo sobre datos reales)

Contexto (ADR-012): crear_pedido_materiales es análoga a create_ot. Dispara un
proceso Bonita igual que create_ot, con el MISMO patrón de sequence de mediación:
INSERT del pedido → instancia el proceso BPM → si Bonita falla, rollback (DELETE
del pedido). NO toca stock (un pedido es una solicitud, no un movimiento de inventario).

Acciones:
1. Estudiá cómo está implementado create_ot en toolsMANAPI: la sequence de mediación,
   el INSERT, la llamada a Bonita, y el rollback (DELETE si Bonita falla). Es el molde EXACTO.
2. Identificá en ALMDataService la query de creación de pedido de materiales y el
   proceso Bonita correspondiente (nombre del proceso, parámetros que espera).
3. Implementá crear_pedido_materiales replicando el patrón de create_ot:
   - empr_id del JWT (EmprIdFromHeader), nunca del caller.
   - INSERT del pedido → instancia BPM → rollback en caso de fallo.
   - La tool debe pedir confirmación explícita del usuario (annotation tipo
     openWorldHint, igual que create_ot).
4. PUNTOS DE PARADA OBLIGATORIA (consultá a Rodolfo, NO decidas):
   - Si el proceso Bonita del pedido de materiales tiene un nombre/estructura que NO
     conocés o no encontrás.
   - Si el payload del pedido requiere campos cuyo significado no está claro
     (ej: tipo de material, depósito destino, prioridad).
   - Si el patrón de rollback de create_ot no aplica limpiamente por alguna diferencia.

DoD:
- [ ] crear_pedido_materiales funcionando con INSERT + BPM + rollback
- [ ] empr_id del JWT; annotation de confirmación (openWorldHint)
- [ ] Verificado que el rollback dispara si Bonita falla (no quedan pedidos huérfanos)
- [ ] STATE.md actualizado
- [ ] PR con formato obligatorio, sin mergear

Esta es clase 🔴: ante CUALQUIER duda sobre el proceso BPM, el payload, o el rollback,
PARÁ y consultá a Rodolfo antes de implementar.
```

### Tarea 3.3 — OpenAPI spec + Virtual MCP Server almacenes (E1-ALM-03) [PR PROPIO]

```
╔════════════════════════════════════════════╗
║ REPO: traz-tools → /mnt/win/dev/git/traz-tools ║
╚════════════════════════════════════════════╝

Leé doc/v3/CONTEXT-PACK.md, doc/v3/STATE.md y doc/adr/ADR-012-almacenes-aislamiento.md
antes de empezar. Requiere E1-ALM-01 y E1-ALM-02 ya mergeados.

Tarea: E1-ALM-03 — OpenAPI spec alm.yaml + Virtual MCP Server trazalog-almacenes.
Clase: 🟡

Contexto: Con las 4 operaciones de almacenes ya implementadas (3 lecturas + crear_pedido),
falta la spec OpenAPI con descripciones semánticas (para que Claude sepa cuándo usar
cada tool) y la configuración del Virtual MCP Server, siguiendo el patrón de equipos.yaml
y ot.yaml + sus Virtual MCP Servers.

Acciones:
1. Estudiá doc/api/equipos.yaml y doc/api/ot.yaml como molde (descripciones semánticas,
   ejemplos de request/response, empr_id AUSENTE de los parámetros de request — solo
   aparece en response como dato informativo).
2. Creá doc/api/alm.yaml con las 4 tools:
   - Las 3 de lectura + crear_pedido_materiales
   - Descripciones orientadas a que Claude sepa cuándo usarlas
   - empr_id NUNCA como parámetro de request (securitySchemes explica que el gateway
     lo extrae del JWT)
   - crear_pedido_materiales marcada con la annotation de confirmación
3. Creá doc/mcp/virtual-mcp-almacenes.md con la tabla de tools + pasos de consola WSO2
   para crear el Virtual MCP Server trazalog-almacenes (patrón de URL:
   /trazalog-almacenes/1.0/mcp — usa el NOMBRE del server, no el de la API).
4. Actualizá el CONTEXT-PACK si corresponde (nueva entrada en la tabla "si tu tarea
   toca X → leé Y" para almacenes).

DoD:
- [ ] doc/api/alm.yaml con las 4 tools, empr_id ausente de request
- [ ] doc/mcp/virtual-mcp-almacenes.md con tabla + pasos de consola
- [ ] STATE.md actualizado
- [ ] PR con formato obligatorio, sin mergear

Ante cualquier duda: PARÁ y consultá a Rodolfo.
```

> **Después del Bloque 3:** Rodolfo publica la API en el Publisher y configura el Virtual MCP Server en la consola WSO2 (pasos manuales, como en Sprint 2), y hace el smoke test de las 4 tools de almacenes con la prueba de aislamiento de 2 empresas.

---

## Estado de este archivo

- **⭐ Próxima tarea:** Bloque 0 (relevamiento de unificación MCP) — desbloquea el ADR-013.
- **Desbloqueado y listo:** Bloque 0 → Bloque 1 (2 PRs, ya mergeados #403/#404) → Bloque 2 (identidad E7-INFRA-03).
- **Espera decisión de arquitectura (ADR-013):** Bloque 3 (almacenes) — porque almacenes nace dentro del MCP unificado.
- **Nota:** E1-ALM-02 (crear_pedido_materiales) es clase 🔴 con puntos de parada obligatoria.
- CW actualiza este archivo a medida que se destraban los bloques (próximo ajuste: tras el ADR-013).
