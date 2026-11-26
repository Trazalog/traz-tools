# Plan — Unificar la documentación macro de Trazalog Tools

## Objetivo

Es el plan para ordenar los documentos **macro** de Tools: arquitectura, agentes, conector para asistentes de IA, identidad e infraestructura. La meta es que cada tema esté en un solo documento y que haya un índice. Lo leen el PM, que lo aprueba, y la sesión de Claude Code que lo ejecute, que tiene que poder seguirlo leyendo solo este archivo. Hay que leerlo antes de mover o fusionar cualquier documento. **No cubre** los documentos de módulos, que quedan para otro momento (sección 4.6), ni **nada de DocTest**, que no se toca.

- **Estado:** versión 2, con el alcance recortado por el PM. **Nada se movió todavía.**
- **Relevado sobre:** `origin/develop-v3.5` al 2026-11-25: 117 archivos `.md` en `doc/`, sin contar este. Comparado con `origin/develop-v3` y `origin/develop`.
- **Decisiones del PM:**
  - 2026-11-25: lo que cumplió su función va a `historial/`, no se borra. Las decisiones de arquitectura de los agentes (ADR-A1 a A13) siguen como tabla dentro del documento técnico de agentes.
  - 2026-11-26: **los módulos se dejan para otro momento**; ahora solo se ordenan los documentos macro. **No se toca nada de DocTest.**
- **Este archivo se borra** en el último cambio de la etapa 4, cuando el índice lo reemplaza.

---

## 1. Diagnóstico

| Qué pasa | Dato |
|---|---|
| Hay demasiados documentos | 117 en `doc/`, en 22 carpetas; 27 son solo de agentes |
| No hay índice | No existe `doc/README.md` ni nada que diga qué leer para qué |
| El mismo tema está contado varias veces | La arquitectura de agentes está en 3 documentos, la instalación y operación de agentes en 5, el diseño del conector de IA en 3 y la identidad en 6 |
| La infraestructura no conoce a los agentes | `doc/infra/ambientes.md` y `doc/v3/deployment-gcp.md` no mencionan el motor de agentes ni su base |
| Falta escribir una decisión | Que el motor de agentes es un servicio aparte de Tools y de WSO2 no está escrito en ningún documento |
| Lo viejo está mezclado con lo vigente | Unos 30 documentos macro ya cumplieron su función: análisis de impacto aprobados, arranques de sprint, relevamientos, prompts de sesiones |
| Las ramas tienen documentos distintos | `develop-v3` tiene 25 documentos que no están en `develop-v3.5`. Casi todos son de módulos, así que este recorte casi no choca con ellos (ver la sección 6) |

---

## 2. Criterios

1. **Un tema, un documento.** Si dos documentos explican lo mismo, se fusionan en uno y el otro desaparece.
2. **Se ordena por para qué se lee**, no por cuándo se escribió.
3. **Lo que ya cumplió su función va a `doc/historial/<área>/`.** No se borra: es el respaldo de lo que se aprobó. Queda fuera del índice.
4. **Las rutas del núcleo no cambian.** `CLAUDE.md` y todas las sesiones leen `doc/v3/CONTEXT-PACK.md`, `doc/v3/STATE.md`, `doc/v3/TRAZALOG_v3_MCP_ARCHITECTURE.md`, `doc/v3/TRAZALOG_v3_CICD_STRATEGY.md` y `doc/adr/`. Moverlos rompería el trabajo de las otras sesiones.
5. **Fusionar no es reescribir.** Se junta y se ordena texto. No se cambia ninguna decisión ni se "mejora" el contenido. Si al fusionar aparece una contradicción entre dos documentos, se deja anotada con `⚠️ Contradicción a resolver` y se avisa al PM.
6. **Lo que no se pudo verificar se marca.** Un documento viejo que quizás ya no describe lo que corre lleva `⚠️ Sin verificar desde <fecha>` debajo del Objetivo. No se corrige de memoria.
7. **Todo documento vivo abre con `## Objetivo`** (regla global del PM). Los de `historial/` no se tocan.
8. **No se toca DocTest.** Ni los 4 documentos de DocTest de `doc/v3/` (`TRAZALOG_v3_DOCTEST_01_REQUERIMIENTOS.md`, `_02_CICLO_VIDA_CICD.md`, `_03_ARQUITECTURA.md`, `PROMPT_CC_DOCTEST.md`) ni ningún archivo bajo `doctest/`. Si una ruta que se mueve está citada desde `doctest/`, se aplica la regla 7 de la sección 5.
9. **No se tocan los documentos de módulos.** Quedan donde están (lista en la sección 4.6).

---

## 3. Estructura final

```
doc/
├── README.md                    índice: "si querés saber X, leé Y" (incluye lo que no se tocó)
├── v3/                          NÚCLEO (rutas sin cambios)
│   ├── CONTEXT-PACK.md
│   ├── STATE.md
│   ├── TRAZALOG_v3_MCP_ARCHITECTURE.md      arquitectura del sistema (+ capítulo de agentes)
│   ├── TRAZALOG_v3_CICD_STRATEGY.md         (+ anexo de sincronización de ramas)
│   ├── deployment-gcp.md                    (+ sección del motor de agentes)
│   ├── AGENTES_TRAZALOG_ARQUITECTURA_FUNCIONAL.md
│   ├── AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md
│   ├── investigacion-sector-minero-trazalog-v3-2.md
│   └── (DocTest y módulos: sin cambios)
├── adr/                         una decisión por archivo (sin cambios)
├── agente/                      4 documentos (+ 2 avisos de mudanza, ver regla 7)
├── mcp/                         3 documentos
├── identidad/                   1 documento
├── infra/                       2 documentos (+ kpi-cron-refresh.md, sin cambios)
├── manuales/                    para usuarios finales (sin cambios)
├── hallazgos/REGISTRO.md
├── api/inventario-wso2.md
├── historial/                   lo macro que cumplió su función, por área
└── (carpetas de módulos: sin cambios por ahora)
```

**Cuentas:**

| | Documentos |
|---|---|
| Macro vivos al terminar (contando los 6 ADR y el índice) | 29 |
| Macro a historial | 29 |
| Macro absorbidos por fusión | 32 |
| Macro a verificar antes de decidir (`ngrok-setup.md`, `testing-workflow.md`) | 2 |
| Fuera de alcance, sin tocar (DocTest 4 + módulos 29) | 33 |

---

## 4. Qué pasa con cada documento

Leyenda: **queda** (misma ruta), **mover** (cambia de ruta, mismo contenido), **fusionar en** (su contenido pasa a otro y el archivo desaparece), **historial** (se mueve a `doc/historial/<área>/` sin tocarlo), **fuera de alcance** (no se toca en este trabajo).

### 4.1 Núcleo — `doc/v3/` (24)

| Documento | Qué se hace |
|---|---|
| `CONTEXT-PACK.md` | queda. Bump de versión: ADR-A14 y las rutas nuevas de los documentos |
| `STATE.md` | queda |
| `TRAZALOG_v3_MCP_ARCHITECTURE.md` | queda. Se agrega un capítulo corto «Agentes de IA»: diagrama, dónde encaja el motor, link al documento técnico |
| `TRAZALOG_v3_CICD_STRATEGY.md` | queda. Absorbe `doc/ci/sync-procedure.md` como anexo |
| `deployment-gcp.md` | queda. Se agrega la sección del motor de agentes como servicio, marcada «no probado» |
| `AGENTES_TRAZALOG_ARQUITECTURA_FUNCIONAL.md` | queda, actualizado a lo construido |
| `AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md` | queda. Absorbe 6 documentos de `doc/agente/` (4.2) y suma ADR-A14 |
| `investigacion-sector-minero-trazalog-v3-2.md` | queda |
| `desplegar-mcp.md` | fusionar en `doc/mcp/publicar-y-operar.md` |
| `PROMPT_CC_AGENTES_TRAZALOG.md` | historial |
| `sprint-3-kickoff.md`, `sprint-3-prompts.md`, `sprint-3-relevamiento-estado.md`, `trazalog-v3-sprint-2-kickoff.md` | historial |
| `relevamiento-unificacion-mcp.md`, `unificacion-develop-v3-analisis-impacto.md` | historial |
| `TRAZALOG_v3_DOCTEST_01_REQUERIMIENTOS.md`, `_02_CICLO_VIDA_CICD.md`, `_03_ARQUITECTURA.md`, `PROMPT_CC_DOCTEST.md` | **fuera de alcance (DocTest)** |
| `bandeja-paginado-real.md`, `bandeja-paginado-real-referencia.md`, `integracion-assetplanner-panol.md`, `traspaso-migracion-assetplanner.md` | **fuera de alcance (módulos)** |

### 4.2 Agentes — `doc/agente/` (27)

| Documento | Qué se hace |
|---|---|
| `arquitectura.md`, `entrevistador.md`, `mediciones.md`, `feedback.md`, `funciones-sin-usar.md`, `kuntur-entrevista-configuracion.md` | fusionar en `doc/v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md` |
| `instalacion.md`, `instalacion-token-y-metas.md`, `operacion.md`, `entorno-de-prueba.md` | fusionar en `doc/agente/instalar-y-operar.md`, ordenado por ambiente. **`operacion.md` y `entorno-de-prueba.md` están citados desde `doctest/`:** en su lugar queda un aviso de mudanza (regla 7 de la sección 5) |
| `decisiones-para-revisar.md`, `decisiones-2026-11-24.md` | fusionar en `doc/agente/decisiones.md`, conservando la numeración D-01… y 1…44 |
| `identidad.md` | queda |
| `revision-legal.md` | queda |
| `consulta-legal-abogado.md` | historial (ya se envió) |
| `taller-claude-web-personajes.md`, `gate2-textos-pm/` (5 archivos) | historial |
| `analisis-alertas-assetplanner.md` y los 5 `analisis-impacto-*.md` | historial (aprobados e implementados) |

Quedan 4 documentos en `doc/agente/` (`instalar-y-operar.md`, `decisiones.md`, `identidad.md`, `revision-legal.md`) y 2 en `doc/v3/`.

**Decisión nueva a escribir, ADR-A14 — el motor de agentes es un servicio aparte.** Va como fila en la tabla de ADR del documento técnico. Razones aprobadas por el PM el 2026-11-25:

- Las consultas duran de 5 a 60 segundos y ocuparían los procesos de PHP.
- Hay trabajos sin nadie conectado: monitoreo y mediciones.
- Las herramientas para modelos de lenguaje están en Python.
- WSO2 es mediación, no orquestación con estado.
- El motor entra a WSO2 con el permiso del usuario, así el aislamiento por empresa lo sigue aplicando WSO2 (ADR-A3).
- Si el motor se cae, Tools sigue funcionando.
- Sirve a más de un canal (ADR-A5).
- Costo asumido: una pieza y una base más para operar.

### 4.3 Conector de IA — `doc/mcp/` (11) y relacionados

| Documento | Qué se hace |
|---|---|
| `COMO-CLAUDE-LLAMA-UN-MCP.md`, `tool-annotations-standard.md`, `virtual-mcp-unificado.md` | fusionar en `doc/mcp/diseno.md` |
| `republicar-mcp-server.md`, `publicacion-en-directorios.md`, `doc/operaciones/herramientas-mcp.md`, `doc/v3/desplegar-mcp.md`, `doc/api/openapi-publish-procedure.md` | fusionar en `doc/mcp/publicar-y-operar.md` |
| `escenarios-de-uso-y-regresion.md`, `verificacion-queries-datos-reales.md`, `casos-de-uso-mineria-y-gaps.md` | fusionar en `doc/mcp/pruebas-y-casos.md` |
| `virtual-mcp-equipos.md`, `virtual-mcp-ots.md` | historial (los reemplazó el unificado, ADR-013) |
| `demo-smoke-test.md` | historial (Sprint 2) |
| `doc/api/openapi-publish-procedure.OBSOLETE.md` | historial |

### 4.4 Identidad y seguridad — `doc/identity/` (7), `doc/sprint2/` (2)

| Documento | Qué se hace |
|---|---|
| `apim-keymanager-dnato.md`, `dnato-jwt-prereqs.md`, `empr-id-injection.md`, `gateway-token-validation.md`, `jwt-keys-setup.md`, `oauth-discovery-flow.md` | fusionar en `doc/identidad/identidad-y-seguridad.md` |
| `dataservices-remediation-phase-a.md` | historial |
| `doc/sprint2/blockers-adr-008.md`, `doc/sprint2/E9-IDENT-05-revisada.md` | historial |

⚠️ Es el área más delicada: los documentos citan ADR-008 y ADR-009, y varios son de mayo a julio. La fusión marca «sin verificar» lo que no se pueda contrastar con el código.

### 4.5 Infraestructura — `doc/infra/` (6), `doc/ci/` (1)

| Documento | Qué se hace |
|---|---|
| `ambientes.md` | queda. Se agrega el motor de agentes y su base en cada ambiente, y el servidor compartido de DEV (EI 6.5) |
| `wso2-install.md`, `wso2-redeploy-artifacts.md` | fusionar en `doc/infra/wso2.md` |
| `ngrok-setup.md`, `testing-workflow.md` | fusionar en `ambientes.md` si siguen vigentes; si no, historial. **Verificar antes**: son de mayo |
| `kpi-cron-refresh.md` | **fuera de alcance** (es del tablero, se ve con los módulos) |
| `doc/ci/sync-procedure.md` | fusionar en `doc/v3/TRAZALOG_v3_CICD_STRATEGY.md` como anexo |

### 4.6 Módulos — diferido por el PM

**No se tocan en este trabajo.** El índice los lista tal como están, para que se encuentren. Son:

- `doc/alm/`, `doc/dnato/`, `doc/man/`, `doc/mantenimiento/`, `doc/migracion/`, `doc/specs/`, `doc/analisis/`, `doc/notificaciones/`, `doc/despliegue/`, `doc/novedades/`.
- Sueltos en la raíz de `doc/`: `traz-comp-codigos.md`, `traz-man-solicitud-servicio.md`, `api-ordenTransporte-desdeTemplate-flujo-y-error.md`.
- De `doc/v3/`: los 4 de bandeja, pañol y migración (4.1).
- `doc/infra/kpi-cron-refresh.md`.
- Los 25 documentos que hoy solo están en `develop-v3`.

Propuesta para cuando se retome, como referencia y no aprobada: un documento por módulo en `doc/modulos/` (`alm`, `dnato`, `man`, `man-migracion`, `tar`, `prd`, `codigos`, `tablero-kpi`, `avisos`, `bandeja`, `pan`), todos con las mismas secciones: qué hace, flujo de datos, especificación, despliegue y pendientes. Antes de hacerlo hay que traer a `develop-v3.5` los 25 documentos de `develop-v3` y coordinar con las sesiones de Tareas y Mantenimiento.

### 4.7 Resto macro

| Documento | Qué se hace |
|---|---|
| `doc/adr/` (6) | queda |
| `doc/hallazgos/REGISTRO.md` | queda (registro vivo) |
| `doc/manuales/conectar-claude-a-trazalog.md`, `doc/manuales/img/README.md` | queda |
| `doc/api/inventory-2026.md` | mover a `doc/api/inventario-wso2.md`, con «sin verificar desde 2026-05-30» |
| `doc/api/codeigniter-models-survey.md` | historial |
| `doc/vision-v3-context.md` | historial |
| Archivos que no son `.md` (`.docx`, `.pdf`, `.xlsx`, `.yaml`, imágenes) | quedan donde están |

### 4.8 Fuera de `doc/` (no se mueven; el índice los enlaza)

`README.md`, `CLAUDE.md`, `db/agente/README.md`, `deploy/gcp/README.md`, `tests/security/README.md`, `prompts/*.md` (son código: los leen los agentes). También `doctest/README.md`, `doctest/GUIA-PRUEBAS-Y-AYUDAS.md` y `doctest/feedback/PROCESO.md`: **solo se enlazan, no se tocan.**

⚠️ En la raíz hay `CONTRIBUTING.md` y `contributing.md`, con el mismo contenido. En un disco que no distingue mayúsculas, como el de Windows del PM, chocan. Se deja `CONTRIBUTING.md` y se borra el otro en la etapa 1.

---

## 5. Etapas

Una rama y un cambio (PR) por etapa, contra `develop-v3.5`, con merge commit. Cada etapa se puede unir sin las siguientes.

| Etapa | Qué | Riesgo de choque con otras sesiones |
|---|---|---|
| **1. Historial e índice** | Mover a `doc/historial/` todo lo marcado «historial» en 4.1 a 4.7 (solo `git mv`). Crear `doc/README.md` con el mapa completo, incluidos DocTest y módulos tal como están. Borrar `contributing.md` | Bajo: son documentos que nadie edita |
| **2. Agentes e infraestructura** | 4.2 y 4.5, el capítulo de agentes en la arquitectura del sistema, la sección del motor en `deployment-gcp.md`, el anexo de sincronización, ADR-A14 y el bump del CONTEXT-PACK | Bajo: es el frente de agentes |
| **3. Conector de IA e identidad** | 4.3, 4.4 y el movimiento de `inventory-2026.md` | Medio: `republicar-mcp-server.md` se editó 7 veces en el último mes. Antes de empezar, comparar `doc/mcp` y `doc/identity` entre `develop-v3` y `develop-v3.5` |
| **4. Cierre** | Pasada final de enlaces, índice con las rutas finales y la tabla «ruta vieja → ruta nueva», `CLAUDE.md` apuntando al índice, borrar este plan | Bajo |

### Reglas para quien ejecuta

1. **Mover siempre con `git mv`**, en un commit separado del que cambia contenido. Así se conserva el historial del archivo y la revisión es legible.
2. **Al fusionar:** crear el documento destino con `## Objetivo`, copiar las secciones de cada origen bajo un título propio, quitar lo repetido y borrar los orígenes en el mismo commit. Al final del destino va una sección «De dónde salió este documento» con la lista de archivos fusionados y la fecha.
3. **Después de cada etapa, arreglar los enlaces** en todo el repositorio, no solo en `doc/`: `CLAUDE.md`, `.claude/`, `db/`, `agente/`, `application/`, `scripts/`, `tests/` y los comentarios del código. **Excepción: `doctest/` no se edita** (regla 7).
4. **No tocar** los documentos del núcleo más allá de lo que dice la tabla 4.1.
5. **No corregir contenido.** Lo dudoso se marca (criterios 5 y 6) y se lista en la descripción del PR.
6. Formato de commit: `docs(<área>): <qué> [DOC-UNIF-<etapa>]`.
7. **Rutas citadas desde `doctest/`.** Antes de mover o fusionar un documento, buscar su ruta en `doctest/` con `grep -rn "<ruta>" doctest/`. Si aparece, en la ruta vieja queda un archivo corto que dice: título, `## Objetivo` de una línea («Este documento se mudó») y el link al destino. Hoy pasa con `doc/agente/operacion.md` y `doc/agente/entorno-de-prueba.md`.
8. **Antes de cada PR, revisar que no se haya tocado nada fuera de alcance.** Esta línea no tiene que mostrar nada:

```bash
git diff --name-only origin/develop-v3.5...HEAD \
  | grep -E '^doctest/|DOCTEST|^doc/(alm|dnato|man|mantenimiento|migracion|specs|analisis|notificaciones|despliegue|novedades)/|bandeja-paginado|integracion-assetplanner|traspaso-migracion|kpi-cron-refresh|traz-comp-codigos|traz-man-solicitud|api-ordenTransporte'
```

### Cómo se verifica cada etapa

**Dónde:** terminal local, en la raíz del repositorio.

- Ningún enlace roto. Esta línea lista los enlaces relativos a un `.md` que apuntan a un archivo que no existe:

```bash
grep -rnoE '\]\((\.\./|\./)?[A-Za-z0-9_./-]+\.md' doc CLAUDE.md README.md \
  | awk -F'[(]' '{print $1 "|" $2}' \
  | while IFS='|' read donde ruta; do \
      f="$(dirname "${donde%%:*}")/$ruta"; [ -e "$f" ] || echo "ROTO: $donde -> $ruta"; \
    done
```

- Ninguna mención a una ruta que ya no existe: buscar con `grep -rn` cada ruta vieja de la etapa en todo el repositorio. Resultado esperado: solo dentro de `doc/historial/`, de la sección «De dónde salió este documento» y de `doctest/`, donde la ruta sigue existiendo como aviso de mudanza.
- Todo documento vivo macro abre con `## Objetivo`. Esta línea lista los que no; los de módulos y DocTest pueden aparecer y se ignoran:

```bash
find doc -name '*.md' -not -path 'doc/historial/*' \
  -exec sh -c 'grep -q "^## Objetivo" "$1" || echo "SIN OBJETIVO: $1"' _ {} \;
```

- El chequeo de `CLAUDE.md`: el último ADR de `doc/adr/` coincide con el que declara el CONTEXT-PACK.
- La revisión de la regla 8 no muestra nada.
- Las pruebas del motor siguen pasando (`pytest tests/`): algunas leen rutas de `doc/` y de `prompts/`.

---

## 6. Riesgos

| Riesgo | Qué se hace |
|---|---|
| Las ramas tienen documentos distintos | Los 25 documentos que solo están en `develop-v3` son casi todos de módulos, que quedan fuera. Supuesto a confirmar en la etapa 3, comparando `doc/mcp` y `doc/identity` entre ramas |
| Otra sesión edita un documento mientras se fusiona | Una etapa por PR, corta. Se anota en `STATE.md` qué área está en reorganización |
| Una sesión futura busca un documento por su ruta vieja | El índice lleva al final una tabla «ruta vieja → ruta nueva». `CLAUDE.md` apunta al índice |
| DocTest deja de encontrar un documento que cita | Regla 7: aviso de mudanza en la ruta vieja |
| Se pierde información al fusionar | Regla 2: orígenes y destino en el mismo commit; el PR lista qué secciones se quitaron por repetidas |
| Se «arregla» contenido sin querer | Criterio 5 y regla 5 |

---

## 7. Lo que tiene que decidir el PM antes de arrancar

1. **¿Se aprueba el destino de cada documento macro de la sección 4?**
2. Rama: `develop-v3.5`, una etapa por PR (recomendado; ya no hace falta sincronizar antes porque los módulos quedan fuera).
