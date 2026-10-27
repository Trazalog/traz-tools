# Prompt para Claude Code — Agente Minero v3.5 (versión inicial completa)

> Pegar en una sesión nueva de Claude Code sobre `traz-tools`. Antes de empezar, verificá que los documentos `AGENTE_MINERO_ARQUITECTURA_FUNCIONAL.md` y `AGENTE_MINERO_ARQUITECTURA_TECNICA.md` estén en `doc/v3/` (si no están, pedímelos). Metodología v2 vigente: **el repo es la única fuente de verdad**; registrá estado en `STATE.md` y derivaciones cross-front en su tabla.

---

## Contexto y objetivo

Vamos a construir la **versión inicial completa del Agente Minero**: un agente de IA experto en operación minera que (a) responde consultas combinando una base de conocimiento (RAG) con datos reales vía las tools MCP existentes, (b) ejecuta monitoreo proactivo programado, (c) captura conocimiento de expertos humanos mediante entrevistas asistidas, y (d) notifica usando el sistema de alertas de Asset Planner extendido a Tools.

**Enfoque acordado por el PM: agresivo.** Todo el alcance en esta versión, para tomar contacto con el cliente real y derivar mejoras. La arquitectura de referencia es `AGENTE_MINERO_ARQUITECTURA_TECNICA.md` — **leela completa antes de escribir código** y respetá sus ADRs (A1 a A6). Ante ambigüedad: consultame, no definas por tu cuenta.

## Reglas de trabajo

1. **Rama:** todo en una rama nueva `develop-v3.5` creada desde `develop-v3`. Ningún commit a otras ramas.
2. **Stack obligatorio:** WSO2 APIM 4.6 (gateway/MCP), WSO2 MI (mediación), PostgreSQL (+pgvector), Bonita (identidad/memberships vía Dnato como ya está), PHP/CodeIgniter para las vistas dentro de Trazalog Tools. El orquestador y pipelines en **Python 3.11+ con FastAPI** (es el caso aprobado de Python: lógica de IA — ADR de arquitectura MCP). LLM **solo vía OpenRouter** con API OpenAI-compatible (ADR-A1); el modelo debe ser configurable por variable de entorno, nunca hardcodeado.
3. **Aislamiento multi-tenant innegociable:** los datos del cliente se acceden SOLO vía MCP Gateway con JWT Dnato (`empr_id` en el token, ADR-A3). La memoria vectorial se particiona por `empr_id`. El conocimiento compartido es de solo lectura para el flujo de consulta; solo el circuito de curaduría escribe en él (ADR-A4). Escribí tests que verifiquen que un `empr_id` no puede leer memoria de otro.
4. **Base de datos:** todos los cambios como **scripts SQL versionados** en `db/agente/` (numerados, idempotentes, con script de rollback). Incluí: instalación de pgvector, esquema de conocimiento compartido (chunks + metadatos: tipo_equipo, situacion, fuente, confianza), memoria por cliente particionada por `empr_id`, cola de conocimiento candidato, tabla de feedback, tablas del entrevistador (agenda de temas, sesiones, hechos capturados y su estado de validación).
5. **Pruebas automáticas para todo:** unit tests (pytest) para el orquestador y pipelines; tests de integración Hurl para los endpoints; tests de aislamiento multi-tenant; tests del feedback; y los derivados de DocTest (punto c). Ningún componente se da por terminado sin sus tests en verde. Mockeá OpenRouter en unit tests (no gastes tokens); un smoke test opt-in real con variable de entorno.
6. **Documentación:** todo en markdown, indexado desde el `README.md` de la rama. Estructura mínima: `doc/agente/arquitectura.md` (cómo quedó implementado), `doc/agente/instalacion.md` (por ambiente), `doc/agente/operacion.md` (variables, jobs, troubleshooting), `doc/agente/feedback.md` (cómo funciona el ciclo de mejora). El README de la rama debe permitir a cualquier persona levantar y probar el agente sin conocimiento previo.
7. **Presupuesto y APIs pagas:** para desarrollo usá siempre OpenRouter con modelos baratos (DeepSeek) y mockea en tests. No configures servicios pagos nuevos sin consultarme.
8. **PRs:** máximo 2 abiertos a la vez (metodología vigente). Cada etapa (E0-E6) cierra con PR revisable por mí.

## Etapas de trabajo (en orden)

### E0 — Análisis del sistema de alertas de Asset Planner (SOLO análisis, sin código)
Estudiá en el repo de Asset Planner cómo funciona su sistema de alertas: disparadores, canales (mail/UI/otros), persistencia, configuración por usuario, y qué dependencias tiene con el resto de AssetPlanner. Entregable: `doc/agente/analisis-alertas-assetplanner.md` con (a) diagrama del mecanismo actual, (b) evaluación de qué se puede reutilizar tal cual en Tools y qué hay que adaptar, (c) propuesta de integración con el orquestador, (d) riesgos. **Detenete ahí y esperá mi validación antes de implementar el puente** (gate 1).

### E1 — Base de datos
Los scripts SQL del punto 4. PR con el esquema completo y sus tests de estructura.

### E2 — Orquestador + RAG + cliente MCP
Servicio FastAPI con: endpoint de consulta (recibe pregunta + JWT del usuario), loop del agente (decide RAG / MCP / ambos), integración OpenRouter configurable, queries a pgvector (conocimiento compartido + memoria del `empr_id` del token), cliente MCP que consume las tools existentes (equipos, OTs) usando el JWT del usuario tal cual llega (passthrough del Bearer — el APIM ya valida). System prompt del agente minero en archivo versionado y editable (`prompts/agente-minero.md`) — dejalo con estructura y placeholders claros; el contenido fino lo defino yo (gate 2). Incluí el pipeline de ingesta documental (PDF/MD → chunks + metadatos → embeddings → pgvector) como comando CLI.

### E3 — UI de chat en Trazalog Tools + feedback
Vista PHP/CodeIgniter dentro de Tools (mismo patrón de módulos existente): chat simple contra el orquestador, con sesión del usuario ya logueado (su JWT). En cada respuesta del agente: control de feedback (👍/👎 + comentario opcional) que persiste en la tabla de feedback con la consulta, la respuesta, los fragmentos RAG usados y las tools llamadas — ese registro es el insumo de la próxima iteración. Endpoint de administración simple para listar feedback negativo agrupado.

### E4 — Agente entrevistador + carga de conocimiento
UI web simple (puede ser vista en Tools, rol restringido) donde un experto conversa con el agente entrevistador. Implementá: agenda de temas priorizada (seed inicial: taxonomía básica de mantenimiento minero que propongas + prioridad por frecuencia de OTs consultada vía MCP), sesión de entrevista (pregunta amplia → repreguntas → estructuración en hechos → pantalla de validación del experto), y promoción de hechos validados a pgvector con metadatos. La validación cruzada entre expertos dejala modelada en BD pero con UI mínima (lista de hechos de otros para aprobar/comentar). Entrada por voz: NO en esta versión (dejalo anotado como mejora).

### E5 — Scheduler + puente de alertas
Jobs programados (cron + comandos Python): al menos 2 monitoreos reales — (a) equipos con MTBF en deterioro contra el período anterior, (b) OTs críticas atrasadas — consultando vía MCP con un token de servicio por cliente (consultame cómo emitirlo con Dnato antes de implementar). Los hallazgos se registran en memoria del cliente y disparan notificación por el puente de alertas según lo validado en E0.

### E6 — DocTest: pruebas + ayudas
Aplicá la metodología DocTest vigente: catálogo funcional YAML del agente (casos de uso: consultar buenas prácticas, consultar datos propios, recibir alerta, dar feedback, entrevista de experto, ingesta de documento), y derivá los tres artefactos: help HTML en español (tuteo argentino, estilo del help site), tests automatizados (Playwright para la UI de chat, Hurl para la API), y Gherkin. **Presentame el catálogo para aprobación antes de generar los artefactos derivados** (gate DocTest habitual).

## Ambientes y despliegue

- **Desarrollo:** todo corre en mi máquina (Ubuntu 24) contra la BD de desarrollo vía VPN; el orquestador local apunta al WSO2 local/dev. Proveé `docker-compose.dev.yml` o scripts equivalentes para levantar el orquestador + dependencias locales.
- **Pruebas (demo):** instructivo de despliegue en la VM de demo respetando la topología actual (documento de instalación por ambiente). Variables de entorno por ambiente en `.env.example` documentado.
- **Producción:** solo documentación de despliegue en esta versión; el pase real lo decido yo.

## Definition of Done global

- [ ] Rama `develop-v3.5` con las 7 etapas en PRs cerrados y revisados
- [ ] Todos los tests en verde (pytest + Hurl + Playwright de DocTest) con comando único documentado
- [ ] Scripts SQL idempotentes con rollback en `db/agente/`
- [ ] README.md de la rama indexando toda la documentación
- [ ] Probable end-to-end en desarrollo: consulta con RAG+MCP respondida, alerta proactiva generada, feedback registrado, entrevista de experto completada e ingestada
- [ ] Tests de aislamiento multi-tenant pasando
- [ ] `STATE.md` actualizado con el estado del frente y derivaciones pendientes
- [ ] Ninguna violación de ADRs A1-A6; ante conflicto, consultaste antes de decidir
