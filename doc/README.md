# Documentación de Trazalog Tools — índice

## Objetivo

Qué es: el mapa de la documentación de Tools: para cada pregunta, qué documento leer. Para quién: el PM, el equipo y cualquier sesión de Claude Code. Cuándo leerlo: cuando no sabés dónde está algo, o cuando una ruta vieja ya no existe (tabla del final). Qué NO cubre: el contenido de cada tema; para empezar una tarea, primero [`v3/CONTEXT-PACK.md`](v3/CONTEXT-PACK.md) y [`v3/STATE.md`](v3/STATE.md).

> Ordenado el 2026-11-26 (unificación de documentación). Los documentos **de módulos** y los **de DocTest** quedaron como estaban, a pedido del PM: figuran abajo con su ruta de siempre.

---

## Si querés saber…, leé…

| Si querés saber… | Leé |
|---|---|
| Por dónde empezar cualquier tarea | [`v3/CONTEXT-PACK.md`](v3/CONTEXT-PACK.md) y [`v3/STATE.md`](v3/STATE.md) |
| En qué estado está cada tarea y qué decidió el PM | [`v3/STATE.md`](v3/STATE.md) |
| Cómo está armado Trazalog v3 (MCP, WSO2, identidad, infraestructura) | [`v3/TRAZALOG_v3_MCP_ARCHITECTURE.md`](v3/TRAZALOG_v3_MCP_ARCHITECTURE.md) |
| Ramas, PRs, pruebas, migraciones y cómo trabajamos con Claude Code | [`v3/TRAZALOG_v3_CICD_STRATEGY.md`](v3/TRAZALOG_v3_CICD_STRATEGY.md) |
| Una decisión de arquitectura y por qué se tomó | [`adr/`](adr/) (una por archivo) y, para los agentes, la tabla ADR-A1 a A14 de [`v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md`](v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md) |
| Para qué sirven los agentes (Kuntur, Quirqui, Faustino) y para quién | [`v3/AGENTES_TRAZALOG_ARQUITECTURA_FUNCIONAL.md`](v3/AGENTES_TRAZALOG_ARQUITECTURA_FUNCIONAL.md) |
| Cómo están construidos los agentes | [`v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md`](v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md) |
| Cómo se instalan, prueban y operan los agentes | [`agente/instalar-y-operar.md`](agente/instalar-y-operar.md) |
| Qué decidió Claude Code solo y falta revisar | [`agente/decisiones.md`](agente/decisiones.md) |
| Cómo son los personajes y sus imágenes | [`agente/identidad.md`](agente/identidad.md) |
| Qué falta revisar en lo legal | [`agente/revision-legal.md`](agente/revision-legal.md) |
| Cómo se diseña una tool del conector MCP | [`mcp/diseno.md`](mcp/diseno.md) |
| Cómo se despliega y publica el conector, y cómo se diagnostica | [`mcp/publicar-y-operar.md`](mcp/publicar-y-operar.md) |
| Cómo se prueba el conector y qué casos de uso cubre | [`mcp/pruebas-y-casos.md`](mcp/pruebas-y-casos.md) |
| Login, permisos (JWT), Dnato y aislamiento por empresa | [`identidad/identidad-y-seguridad.md`](identidad/identidad-y-seguridad.md) |
| Qué ambiente usar, el servidor compartido de DEV y dónde corre el motor de agentes | [`infra/ambientes.md`](infra/ambientes.md) |
| Instalar WSO2 en una máquina o redesplegar un artefacto | [`infra/wso2.md`](infra/wso2.md) |
| Instalar en Google Cloud (TEST y PROD) | [`v3/deployment-gcp.md`](v3/deployment-gcp.md) |
| Qué artefactos de WSO2 hay | [`api/inventario-wso2.md`](api/inventario-wso2.md) (⚠️ sin verificar desde mayo) y las specs en [`api/`](api/) |
| Errores y hallazgos encontrados | [`hallazgos/REGISTRO.md`](hallazgos/REGISTRO.md) |
| Cómo conectar Claude a Trazalog (para usuarios) | [`manuales/conectar-claude-a-trazalog.md`](manuales/conectar-claude-a-trazalog.md) |
| El mercado minero de San Juan | [`v3/investigacion-sector-minero-trazalog-v3-2.md`](v3/investigacion-sector-minero-trazalog-v3-2.md) |

---

## Módulos (sin ordenar todavía)

Quedan para otro momento, por decisión del PM (2026-11-26).

| Módulo o tema | Documentos |
|---|---|
| Almacenes | [`alm/flujo-de-datos.md`](alm/flujo-de-datos.md) |
| Dnato | [`dnato/flujo-de-datos.md`](dnato/flujo-de-datos.md) |
| Mantenimiento | [`man/flujo-de-datos.md`](man/flujo-de-datos.md), [`man/proceso-mantenimiento.md`](man/proceso-mantenimiento.md), [`mantenimiento/kpis-consultas-a-ingenieria.md`](mantenimiento/kpis-consultas-a-ingenieria.md), [`traz-man-solicitud-servicio.md`](traz-man-solicitud-servicio.md) |
| Migración de AssetPlanner a Mantenimiento | [`migracion/assetplanner-a-traz-tools-man.md`](migracion/assetplanner-a-traz-tools-man.md), [`v3/traspaso-migracion-assetplanner.md`](v3/traspaso-migracion-assetplanner.md) |
| Tareas | [`specs/TAR-spec-modulo-tareas.md`](specs/TAR-spec-modulo-tareas.md), [`specs/TAR-metas-pedido-hito.md`](specs/TAR-metas-pedido-hito.md), [`specs/TAR-bugs-detectados.md`](specs/TAR-bugs-detectados.md), [`specs/TAR-analisis-impacto-correcciones.md`](specs/TAR-analisis-impacto-correcciones.md) |
| Producción | [`specs/PRD-modulo-produccion.md`](specs/PRD-modulo-produccion.md) |
| Códigos | [`traz-comp-codigos.md`](traz-comp-codigos.md) |
| Tablero del administrador y KPI | [`analisis/dashboard-administrador-landing.md`](analisis/dashboard-administrador-landing.md), [`despliegue/dashboard-administrador-despliegue.md`](despliegue/dashboard-administrador-despliegue.md), [`infra/kpi-cron-refresh.md`](infra/kpi-cron-refresh.md) |
| Avisos (campanita) | [`notificaciones/diseno-avisos-tools.md`](notificaciones/diseno-avisos-tools.md), [`notificaciones/instalacion-avisos.md`](notificaciones/instalacion-avisos.md) |
| Bandeja de tareas | [`v3/bandeja-paginado-real.md`](v3/bandeja-paginado-real.md), [`v3/bandeja-paginado-real-referencia.md`](v3/bandeja-paginado-real-referencia.md) |
| Pañol | [`v3/integracion-assetplanner-panol.md`](v3/integracion-assetplanner-panol.md) |
| Orden de transporte | [`api-ordenTransporte-desdeTemplate-flujo-y-error.md`](api-ordenTransporte-desdeTemplate-flujo-y-error.md) |
| Análisis de impacto de módulos | [`analisis/`](analisis/) |
| Novedades para usuarios | [`novedades/Trazalog-Tools-Novedades-v2.4-v2.5.md`](novedades/Trazalog-Tools-Novedades-v2.4-v2.5.md) |

## DocTest (sin cambios)

[`v3/TRAZALOG_v3_DOCTEST_01_REQUERIMIENTOS.md`](v3/TRAZALOG_v3_DOCTEST_01_REQUERIMIENTOS.md), [`v3/TRAZALOG_v3_DOCTEST_02_CICLO_VIDA_CICD.md`](v3/TRAZALOG_v3_DOCTEST_02_CICLO_VIDA_CICD.md), [`v3/TRAZALOG_v3_DOCTEST_03_ARQUITECTURA.md`](v3/TRAZALOG_v3_DOCTEST_03_ARQUITECTURA.md), [`v3/PROMPT_CC_DOCTEST.md`](v3/PROMPT_CC_DOCTEST.md) y la carpeta [`doctest/`](../doctest/) ([`README.md`](../doctest/README.md), [`GUIA-PRUEBAS-Y-AYUDAS.md`](../doctest/GUIA-PRUEBAS-Y-AYUDAS.md), [`feedback/PROCESO.md`](../doctest/feedback/PROCESO.md)).

## Fuera de `doc/`

| Qué | Dónde |
|---|---|
| Reglas para Claude Code en este repositorio | [`CLAUDE.md`](../CLAUDE.md) |
| Cómo contribuir | [`CONTRIBUTING.md`](../CONTRIBUTING.md) |
| Esquema de la base de los agentes | [`db/agente/README.md`](../db/agente/README.md) |
| Scripts de instalación en Google Cloud | [`deploy/gcp/README.md`](../deploy/gcp/README.md) |
| Pruebas de seguridad | [`tests/security/README.md`](../tests/security/README.md) |
| Textos de los agentes (son código: los leen los agentes) | [`prompts/`](../prompts/) |

## Historial

[`historial/`](historial/) guarda lo que ya cumplió su función: análisis de impacto aprobados, arranques de sprint, relevamientos, prompts de sesiones viejas. **No se lee para decidir**: puede describir cosas que ya cambiaron. Sus enlaces internos pueden estar rotos, porque se movió sin tocarlo.

---

## Rutas viejas → rutas nuevas

Para encontrar un documento citado con su ruta anterior al 2026-11-26. Las rutas de `doc/agente/operacion.md`, `entorno-de-prueba.md`, `arquitectura.md`, `decisiones-para-revisar.md` y `analisis-impacto-kpi-objetivos.md` siguen existiendo como avisos de mudanza, porque las citan DocTest o documentos de módulos.

| Ruta vieja | Ruta nueva |
|---|---|
| `contributing.md` | `CONTRIBUTING.md (eran idénticos)` |
| `doc/agente/analisis-alertas-assetplanner.md` | [`doc/historial/agente/analisis-alertas-assetplanner.md`](historial/agente/analisis-alertas-assetplanner.md) |
| `doc/agente/analisis-impacto-kpi-objetivos.md` | [`doc/historial/agente/analisis-impacto-kpi-objetivos.md`](historial/agente/analisis-impacto-kpi-objetivos.md) |
| `doc/agente/analisis-impacto-kuntur-configuracion.md` | [`doc/historial/agente/analisis-impacto-kuntur-configuracion.md`](historial/agente/analisis-impacto-kuntur-configuracion.md) |
| `doc/agente/analisis-impacto-plan-accion-kuntur.md` | [`doc/historial/agente/analisis-impacto-plan-accion-kuntur.md`](historial/agente/analisis-impacto-plan-accion-kuntur.md) |
| `doc/agente/analisis-impacto-tar-lectura.md` | [`doc/historial/agente/analisis-impacto-tar-lectura.md`](historial/agente/analisis-impacto-tar-lectura.md) |
| `doc/agente/analisis-impacto-token-maquina.md` | [`doc/historial/agente/analisis-impacto-token-maquina.md`](historial/agente/analisis-impacto-token-maquina.md) |
| `doc/agente/arquitectura.md` | [`doc/v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md`](v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md) |
| `doc/agente/consulta-legal-abogado.md` | [`doc/historial/agente/consulta-legal-abogado.md`](historial/agente/consulta-legal-abogado.md) |
| `doc/agente/decisiones-2026-11-24.md` | [`doc/agente/decisiones.md`](agente/decisiones.md) |
| `doc/agente/decisiones-para-revisar.md` | [`doc/agente/decisiones.md`](agente/decisiones.md) |
| `doc/agente/entorno-de-prueba.md` | [`doc/agente/instalar-y-operar.md`](agente/instalar-y-operar.md) |
| `doc/agente/entrevistador.md` | [`doc/v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md`](v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md) |
| `doc/agente/feedback.md` | [`doc/v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md`](v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md) |
| `doc/agente/funciones-sin-usar.md` | [`doc/v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md`](v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md) |
| `doc/agente/gate2-textos-pm` | [`doc/historial/agente/gate2-textos-pm`](historial/agente/gate2-textos-pm) |
| `doc/agente/instalacion-token-y-metas.md` | [`doc/agente/instalar-y-operar.md`](agente/instalar-y-operar.md) |
| `doc/agente/instalacion.md` | [`doc/agente/instalar-y-operar.md`](agente/instalar-y-operar.md) |
| `doc/agente/kuntur-entrevista-configuracion.md` | [`doc/v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md`](v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md) |
| `doc/agente/mediciones.md` | [`doc/v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md`](v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md) |
| `doc/agente/operacion.md` | [`doc/agente/instalar-y-operar.md`](agente/instalar-y-operar.md) |
| `doc/agente/taller-claude-web-personajes.md` | [`doc/historial/agente/taller-claude-web-personajes.md`](historial/agente/taller-claude-web-personajes.md) |
| `doc/api/codeigniter-models-survey.md` | [`doc/historial/api/codeigniter-models-survey.md`](historial/api/codeigniter-models-survey.md) |
| `doc/api/inventory-2026.md` | [`doc/api/inventario-wso2.md`](api/inventario-wso2.md) |
| `doc/api/openapi-publish-procedure.OBSOLETE.md` | [`doc/historial/api/openapi-publish-procedure.OBSOLETE.md`](historial/api/openapi-publish-procedure.OBSOLETE.md) |
| `doc/api/openapi-publish-procedure.md` | [`doc/mcp/publicar-y-operar.md`](mcp/publicar-y-operar.md) |
| `doc/ci/sync-procedure.md` | [`doc/v3/TRAZALOG_v3_CICD_STRATEGY.md`](v3/TRAZALOG_v3_CICD_STRATEGY.md) |
| `doc/identity/apim-keymanager-dnato.md` | [`doc/identidad/identidad-y-seguridad.md`](identidad/identidad-y-seguridad.md) |
| `doc/identity/dataservices-remediation-phase-a.md` | [`doc/historial/identidad/dataservices-remediation-phase-a.md`](historial/identidad/dataservices-remediation-phase-a.md) |
| `doc/identity/dnato-jwt-prereqs.md` | [`doc/identidad/identidad-y-seguridad.md`](identidad/identidad-y-seguridad.md) |
| `doc/identity/empr-id-injection.md` | [`doc/identidad/identidad-y-seguridad.md`](identidad/identidad-y-seguridad.md) |
| `doc/identity/gateway-token-validation.md` | [`doc/identidad/identidad-y-seguridad.md`](identidad/identidad-y-seguridad.md) |
| `doc/identity/jwt-keys-setup.md` | [`doc/identidad/identidad-y-seguridad.md`](identidad/identidad-y-seguridad.md) |
| `doc/identity/oauth-discovery-flow.md` | [`doc/identidad/identidad-y-seguridad.md`](identidad/identidad-y-seguridad.md) |
| `doc/infra/ngrok-setup.md` | [`doc/infra/ambientes.md`](infra/ambientes.md) |
| `doc/infra/testing-workflow.md` | [`doc/infra/ambientes.md`](infra/ambientes.md) |
| `doc/infra/wso2-install.md` | [`doc/infra/wso2.md`](infra/wso2.md) |
| `doc/infra/wso2-redeploy-artifacts.md` | [`doc/infra/wso2.md`](infra/wso2.md) |
| `doc/mcp/COMO-CLAUDE-LLAMA-UN-MCP.md` | [`doc/mcp/diseno.md`](mcp/diseno.md) |
| `doc/mcp/casos-de-uso-mineria-y-gaps.md` | [`doc/mcp/pruebas-y-casos.md`](mcp/pruebas-y-casos.md) |
| `doc/mcp/demo-smoke-test.md` | [`doc/historial/mcp/demo-smoke-test.md`](historial/mcp/demo-smoke-test.md) |
| `doc/mcp/escenarios-de-uso-y-regresion.md` | [`doc/mcp/pruebas-y-casos.md`](mcp/pruebas-y-casos.md) |
| `doc/mcp/publicacion-en-directorios.md` | [`doc/mcp/publicar-y-operar.md`](mcp/publicar-y-operar.md) |
| `doc/mcp/republicar-mcp-server.md` | [`doc/mcp/publicar-y-operar.md`](mcp/publicar-y-operar.md) |
| `doc/mcp/tool-annotations-standard.md` | [`doc/mcp/diseno.md`](mcp/diseno.md) |
| `doc/mcp/verificacion-queries-datos-reales.md` | [`doc/mcp/pruebas-y-casos.md`](mcp/pruebas-y-casos.md) |
| `doc/mcp/virtual-mcp-equipos.md` | [`doc/historial/mcp/virtual-mcp-equipos.md`](historial/mcp/virtual-mcp-equipos.md) |
| `doc/mcp/virtual-mcp-ots.md` | [`doc/historial/mcp/virtual-mcp-ots.md`](historial/mcp/virtual-mcp-ots.md) |
| `doc/mcp/virtual-mcp-unificado.md` | [`doc/mcp/diseno.md`](mcp/diseno.md) |
| `doc/operaciones/herramientas-mcp.md` | [`doc/mcp/publicar-y-operar.md`](mcp/publicar-y-operar.md) |
| `doc/sprint2/E9-IDENT-05-revisada.md` | [`doc/historial/sprint2/E9-IDENT-05-revisada.md`](historial/sprint2/E9-IDENT-05-revisada.md) |
| `doc/sprint2/blockers-adr-008.md` | [`doc/historial/sprint2/blockers-adr-008.md`](historial/sprint2/blockers-adr-008.md) |
| `doc/v3/PROMPT_CC_AGENTES_TRAZALOG.md` | [`doc/historial/v3/PROMPT_CC_AGENTES_TRAZALOG.md`](historial/v3/PROMPT_CC_AGENTES_TRAZALOG.md) |
| `doc/v3/desplegar-mcp.md` | [`doc/mcp/publicar-y-operar.md`](mcp/publicar-y-operar.md) |
| `doc/v3/relevamiento-unificacion-mcp.md` | [`doc/historial/v3/relevamiento-unificacion-mcp.md`](historial/v3/relevamiento-unificacion-mcp.md) |
| `doc/v3/sprint-3-kickoff.md` | [`doc/historial/v3/sprint-3-kickoff.md`](historial/v3/sprint-3-kickoff.md) |
| `doc/v3/sprint-3-prompts.md` | [`doc/historial/v3/sprint-3-prompts.md`](historial/v3/sprint-3-prompts.md) |
| `doc/v3/sprint-3-relevamiento-estado.md` | [`doc/historial/v3/sprint-3-relevamiento-estado.md`](historial/v3/sprint-3-relevamiento-estado.md) |
| `doc/v3/trazalog-v3-sprint-2-kickoff.md` | [`doc/historial/v3/trazalog-v3-sprint-2-kickoff.md`](historial/v3/trazalog-v3-sprint-2-kickoff.md) |
| `doc/v3/unificacion-develop-v3-analisis-impacto.md` | [`doc/historial/v3/unificacion-develop-v3-analisis-impacto.md`](historial/v3/unificacion-develop-v3-analisis-impacto.md) |
| `doc/vision-v3-context.md` | [`doc/historial/raiz/vision-v3-context.md`](historial/raiz/vision-v3-context.md) |
