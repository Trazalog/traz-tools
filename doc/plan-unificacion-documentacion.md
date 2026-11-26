# Plan — Unificar la documentación de Trazalog Tools

## Objetivo

Es la propuesta para pasar de 117 documentos sueltos en `doc/` a unos 40 documentos vivos, con un índice y una carpeta de historial. Está escrito para el PM, que lo aprueba, y para la sesión de Claude Code que lo ejecute, que tiene que poder seguirlo leyendo solo este archivo. Hay que leerlo antes de mover o fusionar cualquier documento. No cubre el contenido técnico de cada documento: dice dónde va cada uno, no qué tiene que decir.

- **Estado:** propuesta, pendiente de aprobación del PM. **Nada se movió todavía.**
- **Relevado sobre:** `origin/develop-v3.5` al 2026-11-25 (117 archivos `.md` en `doc/`), comparado con `origin/develop-v3` y `origin/develop`.
- **Decisiones ya tomadas por el PM (2026-11-25):** lo que cumplió su función va a `historial/`, no se borra; el alcance es todo Tools; las decisiones de arquitectura de los agentes (ADR-A1 a A13) siguen como tabla dentro del documento técnico de agentes.
- **Este archivo se borra** en el último PR de la etapa 5, cuando el índice lo reemplaza.

---

## 1. Diagnóstico

| Qué pasa | Dato |
|---|---|
| Hay demasiados documentos | 117 en `doc/`, en 22 carpetas; 26 son solo de agentes |
| No hay índice | No existe `doc/README.md` ni nada que diga qué leer para qué |
| El mismo tema está contado varias veces | La arquitectura de agentes, en 3 documentos; la instalación y operación de agentes, en 5; el MCP virtual, en 3; DocTest, en 3 |
| La infraestructura no conoce a los agentes | `doc/infra/ambientes.md` y `doc/v3/deployment-gcp.md` no mencionan el motor de agentes ni su base |
| Falta escribir una decisión | Que el motor de agentes es un servicio aparte de Tools y de WSO2 no está en ningún documento |
| Lo viejo está mezclado con lo vigente | Unos 45 documentos ya cumplieron su función: análisis de impacto aprobados, arranques de sprint, relevamientos, prompts de sesiones |
| Las carpetas no siguen un criterio | Por módulo (`alm`, `man`), por tema (`identity`, `mcp`), por tipo (`analisis`, `specs`), por momento (`sprint2`) y por versión (`v3`), todo a la vez |
| **Las ramas tienen documentos distintos** | `develop-v3` tiene 25 documentos que no están en `develop-v3.5`, y `develop-v3.5` tiene 35 que no están en `develop-v3` |

La última fila es el riesgo principal. Ver la sección 6.

---

## 2. Criterios

1. **Un tema, un documento.** Si dos documentos explican lo mismo, se fusionan en uno y el otro desaparece.
2. **Se ordena por para qué se lee**, no por cuándo se escribió: núcleo, arquitectura por tema, infraestructura, módulos, manuales.
3. **Lo que ya cumplió su función va a `doc/historial/`.** No se borra: es el respaldo de lo que se aprobó. Queda fuera del índice.
4. **Las rutas del núcleo no cambian.** `CLAUDE.md` y todas las sesiones leen `doc/v3/CONTEXT-PACK.md`, `doc/v3/STATE.md`, `doc/v3/TRAZALOG_v3_MCP_ARCHITECTURE.md`, `doc/v3/TRAZALOG_v3_CICD_STRATEGY.md` y `doc/adr/`. Moverlos rompe el trabajo de las otras sesiones.
5. **Fusionar no es reescribir.** Se junta y se ordena texto. No se cambia ninguna decisión ni se "mejora" el contenido. Si al fusionar aparece una contradicción entre dos documentos, se deja anotada con `⚠️ Contradicción a resolver` y se avisa al PM.
6. **Lo que no se pudo verificar se marca.** Un documento viejo que quizás ya no describe lo que corre lleva `⚠️ Sin verificar desde <fecha>` debajo del Objetivo. No se corrige de memoria.
7. **Todo documento vivo abre con `## Objetivo`** (regla global del PM). Los de `historial/` no se tocan.

---

## 3. Estructura final

```
doc/
├── README.md                    índice: "si querés saber X, leé Y"
├── v3/                          NÚCLEO (rutas sin cambios)
│   ├── CONTEXT-PACK.md
│   ├── STATE.md
│   ├── TRAZALOG_v3_MCP_ARCHITECTURE.md      arquitectura del sistema (+ capítulo de agentes)
│   ├── TRAZALOG_v3_CICD_STRATEGY.md
│   ├── deployment-gcp.md                    (+ sección del motor de agentes)
│   ├── AGENTES_TRAZALOG_ARQUITECTURA_FUNCIONAL.md
│   ├── AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md
│   ├── TRAZALOG_v3_DOCTEST.md               (3 en 1)
│   └── investigacion-sector-minero-trazalog-v3-2.md
├── adr/                         una decisión por archivo (sin cambios)
├── agente/                      4 documentos
├── mcp/                         3 documentos
├── identidad/                   1 documento
├── infra/                       2 documentos
├── modulos/                     1 documento por módulo (11)
├── manuales/                    para usuarios finales (2)
├── hallazgos/REGISTRO.md
├── api/inventario-wso2.md
└── historial/                   lo que cumplió su función, por área
```

**Documentos vivos:** 42 (contando los 6 ADR y el índice). **A historial:** unos 45. **Absorbidos por fusión:** unos 30.

---

## 4. Qué pasa con cada documento

Leyenda: **queda** (misma ruta), **mover** (cambia de ruta, mismo contenido), **fusionar en** (su contenido pasa a otro y el archivo desaparece), **historial** (se mueve a `doc/historial/<área>/` sin tocarlo).

### 4.1 Núcleo — `doc/v3/` (24)

| Documento | Qué se hace |
|---|---|
| `CONTEXT-PACK.md` | queda. Bump de versión: ADR-A14 y los nombres nuevos de los documentos |
| `STATE.md` | queda |
| `TRAZALOG_v3_MCP_ARCHITECTURE.md` | queda. Se agrega un capítulo corto «Agentes de IA»: diagrama, dónde encaja el motor, link al técnico |
| `TRAZALOG_v3_CICD_STRATEGY.md` | queda |
| `deployment-gcp.md` | queda. Se agrega la sección del motor de agentes como servicio (marcada «no probado») |
| `AGENTES_TRAZALOG_ARQUITECTURA_FUNCIONAL.md` | queda, actualizado a lo construido |
| `AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md` | queda. Absorbe 6 documentos de `doc/agente/` (4.2) y suma ADR-A14 |
| `TRAZALOG_v3_DOCTEST_01_REQUERIMIENTOS.md`, `_02_CICLO_VIDA_CICD.md`, `_03_ARQUITECTURA.md` | fusionar en `TRAZALOG_v3_DOCTEST.md` (tres capítulos) |
| `investigacion-sector-minero-trazalog-v3-2.md` | queda |
| `desplegar-mcp.md` | fusionar en `doc/mcp/publicar-y-operar.md` |
| `bandeja-paginado-real.md`, `bandeja-paginado-real-referencia.md` | fusionar en `doc/modulos/bandeja.md` |
| `integracion-assetplanner-panol.md` | fusionar en `doc/modulos/pan.md` |
| `traspaso-migracion-assetplanner.md` | fusionar en `doc/modulos/man-migracion.md` |
| `PROMPT_CC_AGENTES_TRAZALOG.md`, `PROMPT_CC_DOCTEST.md` | historial |
| `sprint-3-kickoff.md`, `sprint-3-prompts.md`, `sprint-3-relevamiento-estado.md`, `trazalog-v3-sprint-2-kickoff.md` | historial |
| `relevamiento-unificacion-mcp.md`, `unificacion-develop-v3-analisis-impacto.md` | historial |

### 4.2 Agentes — `doc/agente/` (26)

| Documento | Qué se hace |
|---|---|
| `arquitectura.md`, `entrevistador.md`, `mediciones.md`, `feedback.md`, `funciones-sin-usar.md`, `kuntur-entrevista-configuracion.md` | fusionar en `doc/v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md` |
| `instalacion.md`, `instalacion-token-y-metas.md`, `operacion.md`, `entorno-de-prueba.md` | fusionar en `doc/agente/instalar-y-operar.md`, ordenado por ambiente |
| `decisiones-para-revisar.md`, `decisiones-2026-11-24.md` | fusionar en `doc/agente/decisiones.md` (se conserva la numeración D-01… y 1…44) |
| `identidad.md` | queda |
| `revision-legal.md` | queda |
| `consulta-legal-abogado.md` | historial (ya se envió) |
| `taller-claude-web-personajes.md`, `gate2-textos-pm/` (5 archivos) | historial |
| `analisis-alertas-assetplanner.md` y los 5 `analisis-impacto-*.md` | historial (aprobados e implementados) |

Quedan 4 en `doc/agente/` y 2 en `doc/v3/`.

**Decisión nueva a escribir, ADR-A14 — el motor de agentes es un servicio aparte.** Va como fila en la tabla de ADR del documento técnico. Razones aprobadas por el PM el 2026-11-25: las consultas duran de 5 a 60 segundos y ocuparían los procesos de PHP; hay trabajos sin nadie conectado (monitoreo, mediciones); las herramientas para modelos de lenguaje están en Python; WSO2 es mediación y no orquestación con estado; el motor entra a WSO2 con el permiso del usuario, así el aislamiento por empresa lo sigue aplicando WSO2 (ADR-A3); si el motor se cae, Tools sigue funcionando; sirve a más de un canal (ADR-A5). Costo asumido: una pieza y una base más para operar.

### 4.3 MCP — `doc/mcp/` (11) y relacionados

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

⚠️ Este es el área más delicada: los documentos citan ADR-008 y ADR-009, y varios son de mayo a julio. La fusión marca «sin verificar» lo que no se pueda contrastar con el código.

### 4.5 Infraestructura — `doc/infra/` (6), `doc/despliegue/`, `doc/ci/`

| Documento | Qué se hace |
|---|---|
| `ambientes.md` | queda. Se agrega el motor de agentes y su base en cada ambiente, y el servidor compartido de DEV (EI 6.5) |
| `wso2-install.md`, `wso2-redeploy-artifacts.md` | fusionar en `doc/infra/wso2.md` |
| `ngrok-setup.md`, `testing-workflow.md` | fusionar en `ambientes.md` si siguen vigentes; si no, historial. **Verificar antes** (son de mayo) |
| `kpi-cron-refresh.md`, `doc/despliegue/dashboard-administrador-despliegue.md` | fusionar en `doc/modulos/tablero-kpi.md` |
| `doc/ci/sync-procedure.md` | fusionar en `doc/v3/TRAZALOG_v3_CICD_STRATEGY.md` como anexo |

### 4.6 Módulos — nueva carpeta `doc/modulos/`

Un documento por módulo, con las mismas secciones: qué hace, flujo de datos, especificación, despliegue propio si lo tiene, pendientes.

| Documento nuevo | Se arma con |
|---|---|
| `alm.md` | `doc/alm/flujo-de-datos.md` |
| `dnato.md` | `doc/dnato/flujo-de-datos.md` |
| `man.md` | `doc/man/flujo-de-datos.md`, `doc/man/proceso-mantenimiento.md`, `doc/mantenimiento/kpis-consultas-a-ingenieria.md`, `doc/traz-man-solicitud-servicio.md` |
| `man-migracion.md` | `doc/migracion/assetplanner-a-traz-tools-man.md`, `doc/v3/traspaso-migracion-assetplanner.md` |
| `tar.md` | `doc/specs/TAR-spec-modulo-tareas.md`, `doc/specs/TAR-metas-pedido-hito.md`, `doc/specs/TAR-bugs-detectados.md` (los bugs abiertos como sección «Pendientes») |
| `prd.md` | `doc/specs/PRD-modulo-produccion.md` |
| `codigos.md` | `doc/traz-comp-codigos.md` |
| `tablero-kpi.md` | `doc/analisis/dashboard-administrador-landing.md`, `doc/despliegue/dashboard-administrador-despliegue.md`, `doc/infra/kpi-cron-refresh.md` |
| `avisos.md` | `doc/notificaciones/diseno-avisos-tools.md`, `instalacion-avisos.md`, `firebase-prueba.md`. Lleva arriba el cartel «push al celular pospuesto por el PM (2026-11-25)» |
| `bandeja.md` | `doc/v3/bandeja-paginado-real.md`, `bandeja-paginado-real-referencia.md` |
| `pan.md` | `doc/v3/integracion-assetplanner-panol.md` |

### 4.7 Resto

| Documento | Qué se hace |
|---|---|
| `doc/adr/` (6) | queda |
| `doc/hallazgos/REGISTRO.md` | queda (registro vivo) |
| `doc/manuales/conectar-claude-a-trazalog.md`, `doc/manuales/img/README.md` | queda |
| `doc/novedades/Trazalog-Tools-Novedades-v2.4-v2.5.md` | mover a `doc/manuales/novedades-v2.4-v2.5.md` |
| `doc/api/inventory-2026.md` | mover a `doc/api/inventario-wso2.md`, con «sin verificar desde 2026-05-30» |
| `doc/api/codeigniter-models-survey.md` | historial |
| `doc/analisis/impacto-*.md` (5) | historial |
| `doc/specs/TAR-analisis-impacto-correcciones.md` | historial |
| `doc/api-ordenTransporte-desdeTemplate-flujo-y-error.md`, `doc/vision-v3-context.md` | historial |
| Archivos que no son `.md` (`.docx`, `.pdf`, `.xlsx`, imágenes) | quedan donde están |

### 4.8 Documentos que hoy solo están en `develop-v3` (25)

No se tocan en este trabajo. Cuando lleguen a `develop-v3.5` por la sincronización, se ubican así:

| Documento | Destino |
|---|---|
| `doc/adr/ADR-014-man-acceso-datos-dataservices.md` | queda en `doc/adr/` |
| `doc/v3/dnato/` (9: especificación, modelo, casos, relevamientos, prompts) | especificación, modelo y casos: fusionar en `doc/modulos/dnato.md`; relevamientos y prompts: historial |
| `doc/migracion/` (9) | lo vigente en `doc/modulos/man-migracion.md`; análisis, errores y propuestas cerradas: historial |
| `doc/v3/administracion/ANALISIS_INICIAL.md` | `doc/modulos/adm.md` |
| `doc/v3/bandeja-tareas-funcionamiento-actual.md` | fusionar en `doc/modulos/bandeja.md` |
| `doc/infra/man-lanzamiento-cron.md` | fusionar en `doc/modulos/man.md` |
| `doc/metodologia/GUIA_REQUERIMIENTOS_CLAUDE_DEEPSEEK.md`, `REGLAS-PARA-AGENTES.md` | quedan (son de proceso); se suman al índice |
| `doc/analisis/impacto-alta-usuario-consulta-con-cuerpo.md` | historial |

### 4.9 Fuera de `doc/` (no se mueven; el índice los enlaza)

`README.md`, `CLAUDE.md`, `doctest/README.md`, `doctest/GUIA-PRUEBAS-Y-AYUDAS.md`, `doctest/feedback/PROCESO.md`, `db/agente/README.md`, `deploy/gcp/README.md`, `tests/security/README.md`, `prompts/*.md` (son código: los leen los agentes).

⚠️ En la raíz hay `CONTRIBUTING.md` y `contributing.md`, con el mismo contenido. En un disco que no distingue mayúsculas (el de Windows del PM) chocan. Se deja `CONTRIBUTING.md` y se borra el otro en la etapa 1.

---

## 5. Etapas

Una rama y un PR por etapa, contra `develop-v3.5`. Cada etapa se puede unir sin las siguientes.

| Etapa | Qué | Riesgo de choque con otras sesiones |
|---|---|---|
| **1. Historial e índice** | Mover a `doc/historial/` todo lo marcado «historial» (solo `git mv`). Crear `doc/README.md` con el mapa completo, aunque apunte a rutas todavía viejas | Bajo: son documentos que nadie edita |
| **2. Agentes e infraestructura** | 4.2, 4.5, el capítulo de agentes en la arquitectura del sistema, ADR-A14, bump del CONTEXT-PACK | Bajo: es el frente de esta sesión |
| **3. MCP e identidad** | 4.3 y 4.4 | Medio: `republicar-mcp-server.md` se editó 7 veces en el último mes |
| **4. Módulos** | 4.6 | Alto: TAR y MAN tienen sesiones activas. Coordinar antes |
| **5. Cierre** | Fusión de DocTest, pasada final de enlaces, actualizar el índice a las rutas finales, borrar este plan | Bajo |

### Reglas para quien ejecuta

1. **Mover siempre con `git mv`**, en un commit separado del que cambia contenido. Así el historial del archivo se conserva y la revisión es legible.
2. **Al fusionar:** crear el documento destino con `## Objetivo`, copiar las secciones de cada origen bajo un título propio, quitar lo repetido y borrar los orígenes en el mismo commit. Al final del destino, una sección «De dónde salió este documento» con la lista de archivos fusionados y la fecha.
3. **Después de cada etapa, arreglar los enlaces.** Buscar cada ruta vieja en todo el repositorio (no solo en `doc/`): `CLAUDE.md`, `.claude/`, `doctest/`, `db/`, `agente/`, `application/`, `scripts/`, `tests/`, y los comentarios del código.
4. **No tocar** los documentos del núcleo más allá de lo que dice la tabla 4.1.
5. **No corregir contenido.** Lo dudoso se marca (criterios 5 y 6) y se lista en la descripción del PR.
6. Formato de commit: `docs(<área>): <qué> [DOC-UNIF-<etapa>]`.

### Cómo se verifica cada etapa

**Dónde:** terminal local, en la raíz del repositorio.

- Ningún enlace roto. Para cada enlace relativo a un `.md` dentro de `doc/`, el archivo existe. Esta línea lista los que no:

```bash
grep -rnoE '\]\((\.\./|\./)?[A-Za-z0-9_./-]+\.md' doc CLAUDE.md README.md \
  | awk -F'[(]' '{print $1 "|" $2}' \
  | while IFS='|' read donde ruta; do \
      f="$(dirname "${donde%%:*}")/$ruta"; [ -e "$f" ] || echo "ROTO: $donde -> $ruta"; \
    done
```

- Ninguna mención a una ruta que ya no existe: buscar con `grep -rn` cada ruta vieja de la etapa en todo el repositorio. Resultado esperado: solo dentro de `doc/historial/` y de la sección «De dónde salió este documento».
- Todo documento vivo abre con `## Objetivo`:

```bash
find doc -name '*.md' -not -path 'doc/historial/*' \
  -exec sh -c 'grep -q "^## Objetivo" "$1" || echo "SIN OBJETIVO: $1"' _ {} \;
```

- El chequeo de `CLAUDE.md`: el último ADR de `doc/adr/` coincide con el que declara el CONTEXT-PACK.
- Las pruebas del motor siguen pasando (`pytest tests/`): algunas leen rutas de `doc/` y de `prompts/`.

---

## 6. Riesgos

| Riesgo | Qué se hace |
|---|---|
| **Las tres ramas tienen documentos distintos.** Reordenar en `develop-v3.5` y que después llegue una sincronización con archivos en las rutas viejas genera conflictos de renombrado | Las etapas 1 y 2 tocan casi solo documentos que existen únicamente en `develop-v3.5`. Para las etapas 3 y 4, sincronizar primero (lo decide el PM, ver sección 7) |
| Otra sesión edita un documento mientras se fusiona | Una etapa por PR, corta. Avisar en `STATE.md` qué área está en reorganización. La etapa 4 se coordina con las sesiones de TAR y MAN |
| Una sesión futura busca un documento por su ruta vieja | El índice lleva al final una tabla «ruta vieja → ruta nueva». `CLAUDE.md` apunta al índice |
| Se pierde información al fusionar | Regla 2: orígenes y destino en el mismo commit; el PR lista qué secciones se quitaron por repetidas |
| Se «arregla» contenido sin querer | Criterio 5 y regla 5 |

---

## 7. Lo que tiene que decidir el PM antes de arrancar

1. **¿Se aprueba la estructura de la sección 3 y el destino de cada documento de la sección 4?**
2. **¿En qué rama se hace?** Recomendado: `develop-v3.5`, etapas 1 y 2 ya. Las etapas 3 y 4 después de traer a `develop-v3.5` los 25 documentos que hoy solo están en `develop-v3`.
3. **¿Quién avisa a las sesiones de TAR y MAN** antes de la etapa 4?
