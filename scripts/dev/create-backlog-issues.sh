#!/bin/bash
# Script para crear todos los issues del backlog v3 en GitHub Projects
# Uso: chmod +x create-backlog-issues.sh && ./create-backlog-issues.sh
# Requisito: gh CLI autenticado (gh auth login)

set -euo pipefail

REPO="Trazalog/traz-tools"

echo "Creando issues del backlog v3 en $REPO..."
echo ""

# E0-INF-01
gh issue create --repo "$REPO" \
  --title '[E0-INF-01] Preparar entorno DEV local en máquina del PM (Ubuntu 24)' \
  --body $'Como PM técnico, necesito mi máquina local con Ubuntu 24 configurada como entorno DEV de v3, para construir el MCP Gateway, las APIs nuevas y los Virtual MCP Servers desde mi equipo personal sin necesidad de provisionar una VM dedicada en GCP.\nEl acceso a las bases de datos productivas/staging se hace vía VPN (OpenVPN) a la red de Trazalog. Este entorno DEV es exclusivo para desarrollo y experimentación local — TEST sigue siendo VM en GCP (E0-INF-02) y PROD migra in-place en cutover (E0-INF-07).\n\nCRITERIOS DE ACEPTACIÓN:\n1. Máquina local con Ubuntu 24 actualizada (apt update/upgrade ejecutados)\n2. OpenVPN cliente instalado y configurado para conectar a la red de Trazalog\n3. Conexión validada: ping a la BD de staging-v2 y a las VMs corporativas\n4. Cliente DBeaver (u otro) instalado y conectado a la BD vía VPN para inspección de schema\n5. Git, Cursor y Claude Code configurados con credenciales del repo Trazalog\n6. Acceso SSH a las VMs DEV/TEST/PROD configurado con keys\n7. Carpetas de trabajo definidas: ~/trazalog/v3/ con subcarpetas por componente (mcp, apis, regression)\n\nDEFINICIÓN DE LISTO:\n- [ ] VPN se conecta y desconecta sin errores\n- [ ] Cursor abre el repo y puede commitear\n- [ ] Conexión a BD via DBeaver funcionando\n- [ ] Reviewed por PM' \
  --label "e0,must-have,type:técnica"

sleep 0.3  # rate limit

# E0-INF-02
gh issue create --repo "$REPO" \
  --title '[E0-INF-02] Provisionar VM nueva TEST con OS soportado' \
  --body $'Como PM técnico, necesito una VM nueva con el mismo OS y configuración que DEV para usarla como ambiente TEST/staging-v3, separada del staging-v2 actual.\nEsta VM también es instalación limpia. Va a ser la que ejecute la suite de regresión Pareto contra v3 antes del cutover.\n\nCRITERIOS DE ACEPTACIÓN:\n1. VM provisionada en GCP con el mismo OS elegido en E0-INF-01\n2. Specs equivalentes a DEV (4 vCPU, 4GB RAM, 20GB)\n3. Acceso SSH y OpenVPN configurados\n4. DNS/URL distinta de staging-v2 (ej: staging-v3.cloudtrazalog.com)\n\nDEFINICIÓN DE LISTO:\n- [ ] VM accesible y validada con un ping desde la VM DEV\n- [ ] Reviewed por PM' \
  --label "e0,must-have,type:técnica"

sleep 0.3  # rate limit

# E0-INF-03
gh issue create --repo "$REPO" \
  --title '[E0-INF-03] Instalar JDK 21 (Temurin) en DEV y TEST' \
  --body $'Como PM técnico, necesito JDK 21 (Temurin OpenJDK) instalado en las VMs DEV y TEST de v3, porque WSO2 API Manager 4.6.0 requiere Java 21 según la documentación oficial.\nSin esto el upgrade de WSO2 está bloqueado.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Temurin OpenJDK 21 instalado en DEV y TEST\n2. Variable JAVA_HOME configurada y persistente entre sesiones\n3. java -version devuelve openjdk version 21\n4. Validación con un proceso Java básico que arranca sin errores de glibc\n\nDEFINICIÓN DE LISTO:\n- [ ] Validado por SSH en ambas VMs\n- [ ] Reviewed por PM' \
  --label "e0,must-have,type:técnica"

sleep 0.3  # rate limit

# E0-INF-04
gh issue create --repo "$REPO" \
  --title '[E0-INF-04] Instalar WSO2 API Manager 4.6.0 en DEV' \
  --body $'Como PM técnico, necesito WSO2 API Manager 4.6.0 (open source, Apache 2.0) instalado en la VM DEV con configuración base, porque es el componente central que provee el MCP Gateway, MCP Hub, Developer Portal, OAuth 2.1 y rate limiting.\nEsta versión incluye todo lo necesario para virtualizar APIs como MCP Servers sin código, y es 100% gratuita.\n\nCRITERIOS DE ACEPTACIÓN:\n1. WSO2 4.6.0 corriendo en DEV con consola accesible en https://<dev-vm>:9443/carbon\n2. Developer Portal accesible en https://<dev-vm>:9443/devportal\n3. Publisher accesible en https://<dev-vm>:9443/publisher\n4. Certificado SSL configurado (puede ser self-signed para DEV)\n5. Base de datos H2 inicial OK (PostgreSQL queda para TEST/PROD)\n6. MCP Gateway listado como capability disponible\n\nDEFINICIÓN DE LISTO:\n- [ ] Smoke test: crear API hello-world en publisher y consumir desde devportal\n- [ ] Documentado el procedimiento de instalación en docs/infra/wso2-install.md\n- [ ] Reviewed por PM' \
  --label "e0,must-have,type:técnica"

sleep 0.3  # rate limit

# E0-INF-05
gh issue create --repo "$REPO" \
  --title '[E0-INF-05] Instalar WSO2 4.6.0 en TEST + PostgreSQL' \
  --body $'Como PM técnico, necesito WSO2 4.6.0 instalado en la VM TEST con base de datos PostgreSQL (no H2), porque TEST simula el comportamiento de PROD y PostgreSQL es el motor que va a usar producción.\nTEST también es donde se ejecuta la suite de regresión Pareto contra v3.\n\nCRITERIOS DE ACEPTACIÓN:\n1. WSO2 4.6.0 corriendo en TEST con consolas accesibles vía URL pública (HTTPS)\n2. PostgreSQL configurado como user store y registry\n3. Backup automático diario de la BD configurado\n4. Métricas básicas de WSO2 visibles desde la consola\n\nDEFINICIÓN DE LISTO:\n- [ ] Smoke test end-to-end OK desde un cliente externo\n- [ ] PostgreSQL backup verificado restaurando en una BD temporal\n- [ ] Reviewed por PM' \
  --label "e0,must-have,type:técnica"

sleep 0.3  # rate limit

# E0-INF-06
gh issue create --repo "$REPO" \
  --title '[E0-INF-06] Migrar APIs y configuración de WSO2 4.1.0 a 4.6.0' \
  --body $'Como PM técnico, necesito exportar las APIs y configuraciones del WSO2 4.1.0 actual e importarlas a la nueva instancia 4.6.0, para no perder lo que ya está construido y operativo en v2.\nSe usa la herramienta apictl que es la oficial de WSO2 para CI/CD de APIs entre instancias.\n\nCRITERIOS DE ACEPTACIÓN:\n1. apictl instalado y configurado con perfiles para 4.1.0 y 4.6.0\n2. Inventario completo de APIs migradas vs APIs descartadas (con justificación)\n3. Todas las APIs marcadas como '\''a migrar'\'' funcionan en 4.6.0\n4. Si hay incompatibilidades documentadas en docs/infra/wso2-migration-issues.md\n5. WSO2 4.1.0 sigue corriendo en paralelo durante M1-M3 hasta validar 4.6.0\n\nDEFINICIÓN DE LISTO:\n- [ ] Smoke test de las 3 APIs más críticas en 4.6.0\n- [ ] Documento de migración revisado por socio técnico\n- [ ] Reviewed por PM' \
  --label "e0,must-have,type:técnica"

sleep 0.3  # rate limit

# E0-INF-07
gh issue create --repo "$REPO" \
  --title '[E0-INF-07] Migración in-place de OS en PROD (cutover)' \
  --body $'Como PM técnico, necesito un plan de migración in-place del OS de la VM de PROD desde CentOS 7 al OS elegido (Rocky 9 o Ubuntu 22.04), ejecutado durante la ventana de cutover de v2 a v3.\nEsto es distinto de DEV/TEST (donde se hizo instalación limpia). En PROD hay datos y servicios en operación, así que se ejecuta como parte del cutover único orquestado.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Plan de migración documentado paso a paso con tiempos estimados y rollback\n2. Backup completo de la VM de PROD antes de iniciar (snapshot GCP + dump BD)\n3. Procedimiento validado contra TEST en al menos 2 ensayos previos\n4. Ventana de mantenimiento coordinada con clientes (notificación con 7 días)\n5. Post-migración: smoke test completo + suite de regresión contra PROD\n6. Plan de rollback ejecutable en menos de 30 minutos\n\nDEFINICIÓN DE LISTO:\n- [ ] Migración ejecutada en PROD sin pérdida de datos\n- [ ] Suite de regresión pasa contra PROD post-migración\n- [ ] Documento de incidentes y lecciones aprendidas creado\n- [ ] Reviewed por PM y socio comercial (informado)' \
  --label "e0,must-have,type:técnica"

sleep 0.3  # rate limit

# E0-INF-08
gh issue create --repo "$REPO" \
  --title '[E0-INF-08] Configurar OpenTelemetry Collector para observabilidad' \
  --body $'Como PM técnico, necesito un collector de OpenTelemetry (open source, Apache 2.0) para captura de logs y métricas distribuidas de WSO2 y de los servicios PHP, porque la observabilidad nativa es un requisito para diagnosticar problemas durante MVP y cuando se sumen clientes.\nCosto: $0. Se instala en TEST primero, después en PROD.\n\nCRITERIOS DE ACEPTACIÓN:\n1. OTel Collector instalado en TEST\n2. Exporters configurados para WSO2 (logs + métricas)\n3. Backend de visualización elegido (puede ser Grafana + Prometheus, o Jaeger para tracing)\n4. Tracing distribuido funcional entre WSO2 y un endpoint PHP de prueba\n\nDEFINICIÓN DE LISTO:\n- [ ] Trace de prueba visible en el backend\n- [ ] Documentado en docs/infra/observability.md\n- [ ] Reviewed por PM' \
  --label "e0,should-have,type:técnica"

sleep 0.3  # rate limit

# E1-API-01
gh issue create --repo "$REPO" \
  --title '[E1-API-01] Inventario completo de APIs y DataServices ya expuestos' \
  --body $'Como PM técnico, necesito un inventario completo de todas las APIs REST y DataServices que ya están expuestas en WSO2 (post upgrade a 4.6.0), para identificar cuáles puedo virtualizar como MCP Servers directamente y cuáles tengo que crear desde cero.\nEsta es la base del trabajo de E1 y de E2 — sin saber qué hay, no podemos planificar qué falta.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Documento con tabla de todas las APIs en WSO2: nombre, URL, método HTTP, parámetros, qué módulo expone\n2. Para cada API: si tiene OpenAPI spec actualizada (sí/no/desactualizada)\n3. Categorización por módulo: Asset Planner, Almacenes, Procesos, Residuos, Producción, otros\n4. Gap analysis: qué APIs faltan para cubrir los Virtual MCP Servers planeados (Equipos, OTs, Preventivos, KPIs, Stock)\n\nDEFINICIÓN DE LISTO:\n- [ ] Documento en docs/api/inventory-2026.md\n- [ ] Revisado y aprobado por PM' \
  --label "e1,must-have,type:investigación"

sleep 0.3  # rate limit

# E1-API-02
gh issue create --repo "$REPO" \
  --title '[E1-API-02] Relevamiento de models CodeIgniter de Asset Planner' \
  --body $'Como PM técnico, necesito relevar los models de CodeIgniter de Asset Planner para identificar todos los queries y lógica de orquestación que tendré que exponer como APIs WSO2.\nAsset Planner tiene 59 models y 61 controladores. La mayoría de la lógica de cálculo (KPIs, OTs, preventivos) vive ahí en PHP — hay que migrar parte de eso a WSO2 (ADR-003) y otra parte exponerla con DataServices SQL directos.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Documento por cada entidad clave: Equipos, OTs, Preventivos, Predictivos, Lecturas, Historial, Consumo de materiales, KPIs\n2. Para cada model: nombre, métodos relevantes, queries SQL principales, tablas involucradas, lógica de cálculo no trivial\n3. Identificación de orquestaciones que cruzan varios models (típicamente en controllers) — candidatas a sequence WSO2\n4. Marcado explícito de qué se puede convertir en DataService SQL puro y qué requiere lógica de mediación\n\nDEFINICIÓN DE LISTO:\n- [ ] Documento en docs/api/codeigniter-models-survey.md\n- [ ] Revisado por PM' \
  --label "e1,must-have,type:investigación"

sleep 0.3  # rate limit

# E1-API-03
gh issue create --repo "$REPO" \
  --title '[E1-API-03] ADR — Mapeo de orquestaciones PHP a estrategia WSO2' \
  --body $'Como PM técnico, necesito un ADR formal que decida, para cada orquestación identificada en E1-API-02, si se resuelve con: (a) DataService SQL en WSO2, (b) sequence de mediación WSO2, o (c) excepción que requiere Python en Phase 2.\nEl criterio del ADR-003 es: maximizar WSO2, reservar Python solo para AI/ML/RAG. Toda lógica determinista de datos debe migrar a WSO2.\n\nCRITERIOS DE ACEPTACIÓN:\n1. ADR creado en docs/adr/ADR-003-php-to-wso2-mapping.md\n2. Tabla de decisión por orquestación: estrategia elegida + justificación\n3. Listado priorizado para los 5 Virtual MCP Servers del MVP (Equipos, OTs, Preventivos, KPIs, Stock)\n4. Excepciones marcadas explícitamente (lo que sí va a Python en Phase 2)\n\nDEFINICIÓN DE LISTO:\n- [ ] ADR aprobado por PM\n- [ ] Linkeado desde MCP_ARCHITECTURE.md sección 3.2' \
  --label "e1,must-have,type:investigación"

sleep 0.3  # rate limit

# E1-API-04
gh issue create --repo "$REPO" \
  --title '[E1-API-04] Generar APIs WSO2 — Equipos / Activos' \
  --body $'Como agente IA del cliente minero, necesito poder consultar el catálogo de equipos del proveedor con filtros relevantes, para responder preguntas como '\''¿qué equipos críticos hay en el sector molienda?'\''.\nEsta API alimenta el Virtual MCP Server de Equipos (E2-MCP-02). La fuente es Asset Planner.\n\nCRITERIOS DE ACEPTACIÓN:\n1. API REST GET /api/equipos con filtros opcionales: estado, criticidad, area, sector, cliente_id\n2. API REST GET /api/equipos/{id} devuelve detalle completo con jerarquía sistema/componente\n3. API REST GET /api/equipos/{id}/disponibilidad devuelve disponibilidad actual y de últimos 12 meses\n4. API REST GET /api/equipos/qr/{codigo_qr} devuelve equipo por código QR\n5. OpenAPI 3.0 spec actualizada y publicada en WSO2\n6. Respeta multi-empresa via header X-Company-Id o claim OAuth\n7. Tiempo de respuesta < 800ms para hasta 500 equipos\n\nDEFINICIÓN DE LISTO:\n- [ ] Tests con Hurl que cubren los 4 endpoints\n- [ ] OpenAPI spec en docs/api/equipos.yaml\n- [ ] Reviewed por PM' \
  --label "e1,must-have,type:técnica"

sleep 0.3  # rate limit

# E1-API-05
gh issue create --repo "$REPO" \
  --title '[E1-API-05] Generar APIs WSO2 — Órdenes de Trabajo (read-only)' \
  --body $'Como agente IA del cliente, necesito consultar OTs filtradas por equipo, técnico, estado, tipo y fecha, para responder preguntas como '\''¿qué OTs vencidas tiene asignadas el técnico Pérez esta semana?'\''.\nMVP es read-only (writes en Phase 2 / E9). Cubre OTs correctivas, preventivas y predictivas.\n\nCRITERIOS DE ACEPTACIÓN:\n1. API REST GET /api/ot con filtros: equipo_id, tecnico_id, estado, tipo, fecha_desde, fecha_hasta\n2. API REST GET /api/ot/{id} devuelve detalle completo con timestamps (solicitud, asignación, inicio, fin), materiales consumidos, observaciones\n3. API REST GET /api/ot/vencidas devuelve OTs con preventivo vencido y/o sin cerrar más allá del SLA\n4. OpenAPI 3.0 spec actualizada\n5. Respeta multi-empresa\n6. Paginación implementada (max 100 por request)\n\nDEFINICIÓN DE LISTO:\n- [ ] Tests con Hurl que cubren listado, detalle y vencidas\n- [ ] OpenAPI spec en docs/api/ot.yaml\n- [ ] Reviewed por PM' \
  --label "e1,must-have,type:técnica"

sleep 0.3  # rate limit

# E1-API-06
gh issue create --repo "$REPO" \
  --title '[E1-API-06] Generar APIs WSO2 — Preventivos y plan de mantenimiento' \
  --body $'Como agente IA del cliente, necesito consultar el plan de mantenimiento preventivo y los preventivos vencidos por período, para soportar la consulta '\''¿qué preventivos vencen este mes y cuáles están atrasados?'\''.\nReusa el dato de Asset Planner. El PM Compliance se calcula sobre estos datos.\n\nCRITERIOS DE ACEPTACIÓN:\n1. API REST GET /api/preventivos con filtros: equipo_id, sector, fecha_desde, fecha_hasta, estado_cumplimiento\n2. API REST GET /api/preventivos/vencidos devuelve los pendientes pasados de su fecha programada\n3. API REST GET /api/preventivos/proximos devuelve los que vencen en los próximos N días (parámetro)\n4. API REST GET /api/preventivos/{equipo_id}/historial devuelve cumplimiento histórico del equipo\n5. OpenAPI 3.0 spec\n6. Multi-empresa respetado\n\nDEFINICIÓN DE LISTO:\n- [ ] Tests Hurl OK\n- [ ] OpenAPI spec en docs/api/preventivos.yaml\n- [ ] Reviewed por PM' \
  --label "e1,must-have,type:técnica"

sleep 0.3  # rate limit

# E1-API-07
gh issue create --repo "$REPO" \
  --title '[E1-API-07] Generar APIs WSO2 — KPIs de mantenimiento' \
  --body $'Como agente IA del cliente, necesito obtener los KPIs ya calculados por Asset Planner (Disponibilidad, MTBF, MTTR, MTTF, Confiabilidad, ratio Preventivo/Correctivo/Backlog, Equipos Operativos), para responder preguntas tipo '\''¿cómo viene la disponibilidad de la flota este mes?'\''.\nSe replica la lógica del dashboard PHP existente. Decisión técnica del ADR-003: si la lógica es compleja, exponer como sequence WSO2; si es agregación SQL pura, como DataService.\n\nCRITERIOS DE ACEPTACIÓN:\n1. API REST GET /api/kpi/disponibilidad con filtros: grupo_id, sector_id, equipo_id, periodo (YYYY-MM o rango)\n2. API REST GET /api/kpi/mtbf, /api/kpi/mttr, /api/kpi/mttf con mismos filtros\n3. API REST GET /api/kpi/confiabilidad con mismos filtros\n4. API REST GET /api/kpi/ratio-mantenimiento devuelve % preventivo, correctivo, backlog\n5. API REST GET /api/kpi/equipos-operativos devuelve % activos vs en reparación\n6. OpenAPI 3.0 spec\n7. Resultados consistentes con el dashboard PHP actual (validar con 3 escenarios)\n\nDEFINICIÓN DE LISTO:\n- [ ] Tests Hurl que comparan resultados con dashboard PHP\n- [ ] OpenAPI spec en docs/api/kpi.yaml\n- [ ] Reviewed por PM' \
  --label "e1,must-have,type:técnica"

sleep 0.3  # rate limit

# E1-API-08
gh issue create --repo "$REPO" \
  --title '[E1-API-08] Generar APIs WSO2 — Stock almacén legacy de Asset Planner' \
  --body $'Como agente IA del cliente minero, necesito consultar el stock de repuestos del cliente, sabiendo que el early adopter ya tiene los datos cargados en el almacén legacy de Asset Planner (no en traz-comp-almacenes).\nEsta API expone el almacén legacy de Asset Planner. Para clientes nuevos que se onboardeen directo en traz-comp-almacenes se usa otro Virtual MCP Server (E1-API-09). Esta API también sirve como insumo para la migración futura del almacén legacy a traz-comp-almacenes (E9-FUT-01).\n\nCRITERIOS DE ACEPTACIÓN:\n1. API REST GET /api/stock-legacy/articulos lista artículos del almacén legacy\n2. API REST GET /api/stock-legacy/{articulo_id} devuelve stock actual\n3. API REST GET /api/stock-legacy/{articulo_id}/consumo devuelve consumo histórico (parámetro: período)\n4. API REST GET /api/stock-legacy/punto-pedido devuelve artículos bajo punto de pedido\n5. API REST GET /api/stock-legacy/movimientos devuelve movimientos históricos\n6. OpenAPI 3.0 spec con descripción explícita: '\''Fuente: Asset Planner ALM legacy. Para clientes nuevos usar /api/stock'\''\n7. Multi-empresa respetado\n\nDEFINICIÓN DE LISTO:\n- [ ] Tests Hurl OK\n- [ ] OpenAPI spec en docs/api/stock-legacy.yaml\n- [ ] Reviewed por PM' \
  --label "e1,must-have,type:técnica"

sleep 0.3  # rate limit

# E1-API-09
gh issue create --repo "$REPO" \
  --title '[E1-API-09] Completar APIs de traz-comp-almacenes' \
  --body $'Como PM técnico, necesito identificar y completar las APIs faltantes de traz-comp-almacenes (módulo nuevo, multi-depot), para que clientes nuevos que se onboardeen directamente puedan usar el Virtual MCP Server de stock sin pasar por el almacén legacy.\nEl módulo es más maduro que el legacy y probablemente tiene mejor cobertura de APIs, pero conviene auditar.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Inventario de APIs actuales de traz-comp-almacenes\n2. Gap analysis vs lo que necesita el Virtual MCP Server de Stock para clientes nuevos\n3. APIs faltantes generadas (mismo patrón que E1-API-08 pero contra traz-comp-almacenes)\n4. OpenAPI 3.0 spec\n\nDEFINICIÓN DE LISTO:\n- [ ] Tests Hurl OK\n- [ ] OpenAPI spec en docs/api/stock.yaml\n- [ ] Reviewed por PM' \
  --label "e1,should-have,type:técnica"

sleep 0.3  # rate limit

# E1-API-10
gh issue create --repo "$REPO" \
  --title '[E1-API-10] Documentación OpenAPI consolidada en WSO2 Publisher' \
  --body $'Como PM técnico, necesito que todas las APIs nuevas tengan su OpenAPI 3.0 spec actualizada y publicada en el WSO2 API Publisher, para que el MCP Gateway pueda virtualizarlas automáticamente como Virtual MCP Servers (cero código).\nEsto es prerequisito para toda la épica E2.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Las 6 APIs (Equipos, OTs, Preventivos, KPIs, Stock-legacy, Stock-tools) tienen spec publicada en Publisher\n2. Cada spec tiene descripción semántica clara para cada operación (la descripción se vuelve la descripción del MCP tool)\n3. Cada operación tiene ejemplo de request y response\n4. Naming consistente entre las 6 APIs (snake_case, prefijos claros)\n\nDEFINICIÓN DE LISTO:\n- [ ] Las 6 APIs visibles en el WSO2 Developer Portal\n- [ ] Reviewed por PM' \
  --label "e1,must-have,type:documentación"

sleep 0.3  # rate limit

# E2-MCP-01
gh issue create --repo "$REPO" \
  --title '[E2-MCP-01] Configurar OAuth 2.1 + DCR en WSO2 MCP Gateway' \
  --body $'Como PM técnico, necesito OAuth 2.1 completo configurado en el WSO2 MCP Gateway con Dynamic Client Registration (DCR), porque DCR es requisito para que Trazalog sea listable en el directorio MCP de Anthropic.\nOAuth 2.1 incluye PKCE obligatorio, scopes granulares por tool, resource indicators (RFC 8707) y audience binding.\n\nCRITERIOS DE ACEPTACIÓN:\n1. OAuth 2.1 funcionando con PKCE obligatorio (no se puede saltear)\n2. Scopes granulares definidos por tool (ej: tool:equipos:read, tool:ot:read, tool:kpi:read)\n3. Resource indicators (RFC 8707) implementados — cada token tiene audience específica\n4. Dynamic Client Registration (DCR) endpoint accesible y funcional\n5. Test: registrar un cliente nuevo vía DCR sin intervención manual\n6. Test: token con scope incorrecto no puede invocar tool fuera de su scope\n\nDEFINICIÓN DE LISTO:\n- [ ] Suite de tests OAuth/DCR con Hurl\n- [ ] Documentado en docs/security/oauth-mcp.md\n- [ ] Reviewed por PM' \
  --label "e2,must-have,type:técnica"

sleep 0.3  # rate limit

# E2-MCP-02
gh issue create --repo "$REPO" \
  --title '[E2-MCP-02] Crear Virtual MCP Server: Equipos / Activos' \
  --body $'Como agente IA del cliente minero, necesito un MCP Server que exponga consultas sobre el catálogo de equipos del proveedor, para responder preguntas tipo '\''¿qué excavadoras críticas tenemos disponibles hoy?'\''.\nSe configura virtualizando la API E1-API-04 desde la consola de WSO2 sin escribir código.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Virtual MCP Server '\''trazalog-equipos'\'' creado en WSO2 MCP Hub\n2. Tools generadas: list_equipos, get_equipo_details, get_disponibilidad, get_equipo_by_qr\n3. Cada tool tiene descripción semántica clara (la usa el LLM para decidir cuándo invocarla)\n4. Tool descriptions incluyen ejemplos de uso típicos en lenguaje natural\n5. MCP Server accesible vía Streamable HTTP en https://<wso2>/mcp/equipos\n6. Validado con MCP Inspector y Claude Desktop\n\nDEFINICIÓN DE LISTO:\n- [ ] PoC documentado: 3 prompts reales que usan el server\n- [ ] Reviewed por PM' \
  --label "e2,must-have,type:técnica"

sleep 0.3  # rate limit

# E2-MCP-03
gh issue create --repo "$REPO" \
  --title '[E2-MCP-03] Crear Virtual MCP Server: Órdenes de Trabajo (read-only)' \
  --body $'Como agente IA del cliente minero, necesito un MCP Server que exponga consultas sobre OTs, para soportar consultas tipo '\''mostrame las OTs vencidas del técnico Pérez'\'' o '\''qué OTs cerramos esta semana en el equipo crítico A-104'\''.\nSolo lectura en MVP. Writes (crear, modificar) van en Phase 2 / E9.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Virtual MCP Server '\''trazalog-ot'\'' creado en WSO2\n2. Tools: list_ot, get_ot_details, list_ot_vencidas, list_ot_by_equipo, list_ot_by_tecnico\n3. Descripciones semánticas claras\n4. Streamable HTTP en https://<wso2>/mcp/ot\n5. Validado con MCP Inspector\n\nDEFINICIÓN DE LISTO:\n- [ ] PoC con 3 prompts reales\n- [ ] Reviewed por PM' \
  --label "e2,must-have,type:técnica"

sleep 0.3  # rate limit

# E2-MCP-04
gh issue create --repo "$REPO" \
  --title '[E2-MCP-04] Crear Virtual MCP Server: Preventivos' \
  --body $'Como agente IA del cliente, necesito un MCP Server que exponga el plan de preventivos y los vencidos, para responder consultas tipo '\''¿qué preventivos vencen esta semana?'\'' o '\''cuál es el cumplimiento histórico del equipo A-104'\''.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Virtual MCP Server '\''trazalog-preventivos'\'' creado en WSO2\n2. Tools: get_preventive_plan, list_due_preventives, list_upcoming_preventives, get_compliance_history\n3. Descripciones semánticas claras\n4. Streamable HTTP en https://<wso2>/mcp/preventivos\n5. Validado con MCP Inspector\n\nDEFINICIÓN DE LISTO:\n- [ ] PoC con 2 prompts reales\n- [ ] Reviewed por PM' \
  --label "e2,must-have,type:técnica"

sleep 0.3  # rate limit

# E2-MCP-05
gh issue create --repo "$REPO" \
  --title '[E2-MCP-05] Crear Virtual MCP Server: KPIs de mantenimiento' \
  --body $'Como agente IA del cliente minero, necesito un MCP Server que devuelva KPIs (Disponibilidad, MTBF, MTTR, MTTF, Confiabilidad, ratio prev/correc, equipos operativos), para responder consultas estratégicas tipo '\''resumime los KPIs del último trimestre'\'' o '\''¿cómo viene la disponibilidad por sector?'\''.\nEstos KPIs son los que las mineras exigen a sus contratistas.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Virtual MCP Server '\''trazalog-kpi'\'' creado en WSO2\n2. Tools: get_disponibilidad, get_mtbf, get_mttr, get_mttf, get_confiabilidad, get_ratio_mantenimiento, get_equipos_operativos\n3. Cada tool acepta parámetros: período (YYYY-MM o rango), filtros (grupo, sector, equipo)\n4. Descripciones semánticas que indican benchmarks típicos del sector minero (ej: disponibilidad >92% es world-class)\n5. Streamable HTTP en https://<wso2>/mcp/kpi\n6. Validado con MCP Inspector\n\nDEFINICIÓN DE LISTO:\n- [ ] PoC con 3 prompts reales (resumen mensual, análisis por sector, comparación con benchmarks)\n- [ ] Reviewed por PM' \
  --label "e2,must-have,type:técnica"

sleep 0.3  # rate limit

# E2-MCP-06
gh issue create --repo "$REPO" \
  --title '[E2-MCP-06] Crear Virtual MCP Server: Stock legacy AP (ADR-004)' \
  --body $'Como agente IA del cliente minero (early adopter), necesito un MCP Server que exponga el stock del almacén legacy de Asset Planner, sabiendo que el cliente tiene los repuestos cargados ahí y no en traz-comp-almacenes.\nLas descripciones de los tools deben aclarar EXPLÍCITAMENTE que la fuente es Asset Planner ALM legacy. Esta decisión está formalizada en ADR-004.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Virtual MCP Server '\''trazalog-stock-legacy'\'' creado en WSO2\n2. Tools: list_articulos_legacy, get_stock_legacy, get_consumo_historico_legacy, list_punto_pedido_legacy, list_movimientos_legacy\n3. Cada descripción de tool inicia con: '\''FUENTE: Asset Planner ALM (almacén legacy). Para clientes nuevos en traz-comp-almacenes usar tools del MCP Server trazalog-stock'\''\n4. Streamable HTTP en https://<wso2>/mcp/stock-legacy\n5. Validado con MCP Inspector\n\nDEFINICIÓN DE LISTO:\n- [ ] PoC con 2 prompts reales\n- [ ] ADR-004 actualizado con referencia a este server\n- [ ] Reviewed por PM' \
  --label "e2,must-have,type:técnica"

sleep 0.3  # rate limit

# E2-MCP-07
gh issue create --repo "$REPO" \
  --title '[E2-MCP-07] Configurar rate limiting por tier en WSO2' \
  --body $'Como Trazalog, necesito que WSO2 aplique cuotas distintas por tier de suscripción del cliente, para implementar el modelo de pricing capacity-based del PRICING_STRATEGY.\nMVP solo activa Free y Starter (Professional y Enterprise van en Phase 2).\n\nCRITERIOS DE ACEPTACIÓN:\n1. Tier Free configurado: 100 calls MCP / día, máximo 5 usuarios en plataforma\n2. Tier Starter configurado: 1.000 calls MCP / mes, hasta 15 usuarios, USD 199/mes\n3. Tiers Professional (4.000 calls, USD 449) y Enterprise (15.000+, USD 899) configurados como '\''inactive'\'' en MVP\n4. Rate limiting probado: cliente Free que excede 100 calls/día recibe 429 Too Many Requests\n5. Rate limiting probado: cliente Starter que excede 1000 calls/mes recibe 429\n6. Mensajes de error de WSO2 son claros (incluyen tier actual y cuota)\n\nDEFINICIÓN DE LISTO:\n- [ ] Tests con Hurl que validan los 4 tiers\n- [ ] Documentado en docs/pricing/wso2-tiers.md\n- [ ] Reviewed por PM' \
  --label "e2,must-have,type:técnica"

sleep 0.3  # rate limit

# E2-MCP-08
gh issue create --repo "$REPO" \
  --title '[E2-MCP-08] Publicar tools en MCP Hub con documentación copy-ready' \
  --body $'Como cliente minero (admin de cuenta), necesito instrucciones copy-paste para conectar mi instancia de Trazalog a Claude Desktop o VS Code Copilot, para que sea autoservicio.\nEl MCP Hub de WSO2 expone esto automáticamente, pero hay que llenarlo con descripciones claras.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Cada Virtual MCP Server tiene su página en el MCP Hub con: descripción del propósito, tools disponibles, ejemplos de prompts, configuración JSON para Claude Desktop, configuración para VS Code Copilot\n2. Tier Free habilitado para autoservicio (cualquiera puede registrarse y probar)\n3. Páginas accesibles desde URL pública (https://hub.cloudtrazalog.com)\n4. Búsqueda funcional sobre el catálogo\n\nDEFINICIÓN DE LISTO:\n- [ ] Cliente externo prueba conexión sin asistencia y reporta éxito\n- [ ] Reviewed por PM' \
  --label "e2,must-have,type:documentación"

sleep 0.3  # rate limit

# E2-MCP-09
gh issue create --repo "$REPO" \
  --title '[E2-MCP-09] PoC con MCP Inspector y Claude Desktop (validación end-to-end)' \
  --body $'Como PM técnico, necesito validar que la cadena completa funciona end-to-end (LLM → Claude Desktop → MCP Server → WSO2 → API → BD), antes de mostrarlo al primer cliente minero.\nProbamos con datos reales del cliente piloto (post auditoría de datos E6-EA-02).\n\nCRITERIOS DE ACEPTACIÓN:\n1. MCP Inspector valida los 5 servers (Equipos, OTs, Preventivos, KPIs, Stock legacy)\n2. Claude Desktop conectado a los 5 servers usando OAuth DCR\n3. Validados al menos 5 prompts reales con datos del cliente: equipos críticos disponibles, OTs vencidas, KPIs del último mes, preventivos próximos, stock bajo\n4. Tiempo de respuesta < 3s end-to-end por prompt\n5. Logs de WSO2 confirman que cada tool call invocó correctamente la API correspondiente\n\nDEFINICIÓN DE LISTO:\n- [ ] Documento de validación con screenshots y resultados en docs/validation/mcp-poc.md\n- [ ] Reviewed por PM' \
  --label "e2,must-have,type:funcional"

sleep 0.3  # rate limit

# E2-MCP-10
gh issue create --repo "$REPO" \
  --title '[E2-MCP-10] Submission al directorio MCP de Anthropic' \
  --body $'Como Trazalog, necesito estar listado en el directorio público de connectors MCP de Anthropic, para ganar credibilidad y visibilidad en el ecosistema MCP.\nRequisito: Remote MCP server con Streamable HTTP + OAuth 2.1 + DCR (cubierto por E2-MCP-01). El directorio es canal de credibilidad, no de adquisición masiva.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Submission completado en claude.com/connectors siguiendo el procedimiento oficial\n2. Repositorio público con configuración de conexión (URL, OAuth setup)\n3. Documento de cumplimiento confirmando: Streamable HTTP, OAuth 2.1, DCR, scopes granulares\n4. Página de aterrizaje en sitio Trazalog que linkea al directorio\n\nDEFINICIÓN DE LISTO:\n- [ ] Listing aprobado por Anthropic\n- [ ] Reviewed por PM y socio comercial' \
  --label "e2,should-have,type:funcional"

sleep 0.3  # rate limit

# E3-EXP-01
gh issue create --repo "$REPO" \
  --title '[E3-EXP-01] Biblioteca de prompts para mantenimiento minero' \
  --body $'Como jefe de mantenimiento de un proveedor minero, necesito una biblioteca de prompts probados que resuelvan mis consultas más frecuentes, para no tener que aprender a escribir prompts efectivos desde cero.\nLos prompts deben ser resolubles 100% con los Virtual MCP Servers del MVP (read-only, sin Python). Son la primera experiencia que tiene el cliente con Trazalog + IA.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Al menos 10 prompts documentados con: prompt completo, explicación del valor, ejemplo de respuesta esperada, tools del MCP que invoca\n2. Cubre los 4 casos de impacto ALTO de la investigación minera: preventivos vencidos, plan mensual, recomendación de compra, KPIs ejecutivos\n3. Cubre 3 casos de impacto MEDIO: top equipos problemáticos, ratio prev/correc, historial por equipo\n4. Cada prompt validado contra datos reales del cliente piloto\n5. Material entregable: PDF descargable + página en docs.trazalog.com\n\nDEFINICIÓN DE LISTO:\n- [ ] Material disponible en docs/playbook/prompts-mineros.md\n- [ ] Validado con cliente piloto (al menos 5 prompts probados)\n- [ ] Reviewed por PM' \
  --label "e3,must-have,type:funcional"

sleep 0.3  # rate limit

# E3-EXP-02
gh issue create --repo "$REPO" \
  --title '[E3-EXP-02] Prompt para informe semanal/mensual a la minera' \
  --body $'Como gerente de proveedor minero, necesito poder pedirle a la IA '\''armame el informe para Barrick'\'' y obtener en segundos un borrador profesional con OTs completadas, KPIs de disponibilidad, horas-hombre, materiales consumidos, y cumplimiento de plan preventivo.\nHoy esto se arma a mano en Word/Excel y toma 2-3 horas. Es probablemente el feature con mayor wow-factor del MVP. Sin Python — la composición la hace el LLM con los tools disponibles.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Prompt template documentado que cruza datos de Equipos, OTs, KPIs y Stock legacy\n2. Output formato markdown estructurado: encabezado, resumen ejecutivo, tabla de OTs completadas, KPIs (disponibilidad, MTBF, MTTR), horas-hombre por equipo, materiales consumidos con costos, cumplimiento de plan preventivo, alertas\n3. Output exportable a PDF y Word desde Claude Desktop\n4. Validado contra el formato de informe que el cliente piloto envía actualmente a su minera\n5. Tiempo de generación end-to-end < 30s\n\nDEFINICIÓN DE LISTO:\n- [ ] Validación con cliente piloto (compara informe IA vs informe actual)\n- [ ] Documentado en docs/playbook/informe-minera.md\n- [ ] Reviewed por PM' \
  --label "e3,must-have,type:funcional"

sleep 0.3  # rate limit

# E3-EXP-03
gh issue create --repo "$REPO" \
  --title '[E3-EXP-03] Prompt para plan de mantenimiento asistido por IA' \
  --body $'Como jefe de mantenimiento, necesito que la IA me sugiera el plan de mantenimiento del próximo mes cruzando preventivos por vencer + historial de fallas + criticidad, para no tener que armarlo a mano.\nSin lógica predictiva ML (eso es Phase 2 con Python). El LLM hace la composición con los datos que devuelven los Virtual MCP Servers. Output es sugerencia — la creación de OTs queda manual en MVP (writes son Phase 2).\n\nCRITERIOS DE ACEPTACIÓN:\n1. Prompt template que cruza tools: list_upcoming_preventives, list_ot_by_equipo (historial), get_disponibilidad, list_equipos (criticidad)\n2. Output: lista priorizada de OTs sugeridas con: equipo, tipo (preventivo/correctivo derivado), prioridad (basada en criticidad y atraso), recursos sugeridos\n3. Output validado: '\''esto es sugerencia de la IA, no creó OTs en el sistema; creación manual desde Asset Planner'\''\n4. Validado con cliente piloto\n\nDEFINICIÓN DE LISTO:\n- [ ] Documentado en docs/playbook/plan-mantenimiento.md\n- [ ] Validado con cliente piloto\n- [ ] Reviewed por PM' \
  --label "e3,must-have,type:funcional"

sleep 0.3  # rate limit

# E3-EXP-04
gh issue create --repo "$REPO" \
  --title '[E3-EXP-04] Prompt para análisis de puntos de pedido (recomendación)' \
  --body $'Como encargado de compras del proveedor minero, necesito que la IA detecte qué puntos de pedido están desajustados respecto al consumo real de los últimos 90 días, para no quedarme sin stock crítico ni acumular capital innecesario.\nRecomendación, no auto-ajuste. La aplicación del cambio queda manual (writes son Phase 2).\n\nCRITERIOS DE ACEPTACIÓN:\n1. Prompt template que invoca tools: list_punto_pedido_legacy, get_consumo_historico_legacy\n2. Output identifica 2 categorías: artículos con punto bajo (riesgo de stockout) y con punto alto (capital inmovilizado)\n3. Por cada artículo: punto de pedido actual, consumo promedio últimos 90 días, recomendación numérica, justificación\n4. Validado con cliente piloto\n\nDEFINICIÓN DE LISTO:\n- [ ] Documentado en docs/playbook/puntos-pedido.md\n- [ ] Validado con cliente piloto\n- [ ] Reviewed por PM' \
  --label "e3,must-have,type:funcional"

sleep 0.3  # rate limit

# E3-EXP-05
gh issue create --repo "$REPO" \
  --title '[E3-EXP-05] Documentación de uso del MCP para el cliente' \
  --body $'Como admin de cuenta de un proveedor minero, necesito un manual paso a paso para conectar mi instancia de Trazalog a Claude Desktop o VS Code Copilot, para hacerlo sin asistencia técnica de Trazalog.\nSin esto, la barrera de adopción es muy alta y el MCP queda subutilizado.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Manual con: cómo obtener API key desde portal Trazalog, cómo configurar Claude Desktop (claude_desktop_config.json), cómo configurar VS Code Copilot, ejemplos de los 10 prompts más útiles\n2. Screenshots reales (no mockups)\n3. Versión PDF descargable\n4. Versión web en docs.trazalog.com\n5. Sección de troubleshooting con los 5 errores más comunes\n\nDEFINICIÓN DE LISTO:\n- [ ] Cliente piloto se conecta sin asistencia siguiendo el manual\n- [ ] Reviewed por PM' \
  --label "e3,must-have,type:documentación"

sleep 0.3  # rate limit

# E4-DSC-01
gh issue create --repo "$REPO" \
  --title '[E4-DSC-01] Habilitar analytics nativas de WSO2 para todos los MCP Servers' \
  --body $'Como PM, necesito que cada llamada a un Virtual MCP Server quede registrada con metadatos completos (cliente, tool, parámetros, status, duración), para alimentar facturación, descubrimiento de patrones y diagnóstico.\nLas analytics nativas de WSO2 4.6.0 son built-in y gratuitas. Reemplazan a Moesif (descartado por costo, ver MDR-001).\n\nCRITERIOS DE ACEPTACIÓN:\n1. Analytics WSO2 habilitadas para los 5 Virtual MCP Servers\n2. Cada call registra: empr_id, user_id, tool_name, parámetros (sanitizados), timestamp, duración, status code, tier consumido\n3. Retención mínima: 6 meses\n4. Datos consultables vía SQL desde la BD de analytics\n5. Validado: tras 50 calls de prueba, todas figuran en la BD\n\nDEFINICIÓN DE LISTO:\n- [ ] Query SQL de muestra documentada en docs/analytics/wso2-queries.md\n- [ ] Reviewed por PM' \
  --label "e4,must-have,type:técnica"

sleep 0.3  # rate limit

# E4-DSC-02
gh issue create --repo "$REPO" \
  --title '[E4-DSC-02] Script de reporte de consumo mensual por cliente' \
  --body $'Como Trazalog (operación), necesito un script que genere mensualmente un reporte de consumo por cliente con: calls totales, desglose por tool, tier contratado, excedentes para cobro, para soportar facturación manual con AFIP + MercadoPago (MDR-002).\nSin Stripe — este script reemplaza la lógica de facturación automática.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Script en bash o Python (sin Python complejo, solo SQL + formato) que consulta BD analytics WSO2\n2. Output: CSV o JSON por cliente con calls, costos calculados según tier, excedentes\n3. Ejecutable manualmente o vía cron mensual\n4. Por cada cliente: información lista para que el socio comercial genere factura AFIP\n5. Validado contra al menos 1 cliente real (empr_id) con calls reales del mes\n\nDEFINICIÓN DE LISTO:\n- [ ] Script en repo en scripts/billing/monthly-report.sh (o .py)\n- [ ] Documentado el procedimiento operativo\n- [ ] Reviewed por PM' \
  --label "e4,must-have,type:técnica"

sleep 0.3  # rate limit

# E4-DSC-03
gh issue create --repo "$REPO" \
  --title '[E4-DSC-03] Dashboard interno de patrones de uso MCP' \
  --body $'Como PM, necesito un dashboard interno (solo Trazalog, no expuesto a clientes) que muestre patrones de uso del MCP, para detectar features de mayor valor y consultas que fallan.\nImplementación simple: notebook Jupyter o página PHP con queries a la BD de analytics WSO2.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Dashboard accesible internamente en https://admin.cloudtrazalog.com/mcp-analytics\n2. Métricas mostradas: top 10 tools más invocadas, top 10 tools con error, evolución semanal, hora pico de uso, clientes más activos, % de tools que devuelven vacío\n3. Filtros: por cliente, por período, por server\n4. Actualización automática diaria (no requiere intervención manual)\n\nDEFINICIÓN DE LISTO:\n- [ ] Dashboard en uso por PM al menos una vez por semana\n- [ ] Reviewed por PM' \
  --label "e4,should-have,type:funcional"

sleep 0.3  # rate limit

# E4-DSC-04
gh issue create --repo "$REPO" \
  --title '[E4-DSC-04] Detección de tool calls no soportadas (gaps de producto)' \
  --body $'Como PM, necesito detectar cuando un cliente intenta invocar una tool que no existe o que falla por capacidad faltante, para alimentar el backlog de v3.1+ con features que el mercado pide.\nCategorización quincenal manual: el log no se interpreta solo, es input para sesiones de PM.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Query SQL en el dashboard que muestra tool calls con error_no_match o respuestas vacías sospechosas\n2. Sesión quincenal documentada de revisión por parte de PM\n3. Categorización: '\''gap real'\'' / '\''consulta mal formulada'\'' / '\''datos faltantes en el cliente'\''\n4. Cada gap real se convierte en historia candidata al backlog v3.1\n\nDEFINICIÓN DE LISTO:\n- [ ] Plantilla de sesión quincenal en docs/discovery/template.md\n- [ ] Primera sesión ejecutada antes de fin M3\n- [ ] Reviewed por PM' \
  --label "e4,should-have,type:investigación"

sleep 0.3  # rate limit

# E5-PRC-01
gh issue create --repo "$REPO" \
  --title '[E5-PRC-01] Configurar tier Free en WSO2 (PDR-001)' \
  --body $'Como Trazalog, necesito el tier Free configurado como tier de suscripción nativo en WSO2, para que cualquier prospecto pueda registrarse y probar el sistema sin barrera de entrada.\nPDR-001: hasta 5 usuarios en plataforma, 0 calls MCP (solo demo del catálogo).\n\nCRITERIOS DE ACEPTACIÓN:\n1. Tier '\''free'\'' creado en WSO2 con throttling configurado\n2. Throttling: máximo 5 usuarios activos por empresa, 0 calls MCP cuota mensual\n3. Cliente Free que intenta invocar tools MCP recibe 403 con mensaje claro\n4. Cliente Free que intenta crear el 6° usuario recibe error con CTA a upgrade\n5. Validación con flujo end-to-end de un cliente nuevo en tier Free\n\nDEFINICIÓN DE LISTO:\n- [ ] Tests de throttling con Hurl\n- [ ] Documentado en docs/pricing/tier-free.md\n- [ ] Reviewed por PM' \
  --label "e5,must-have,type:técnica"

sleep 0.3  # rate limit

# E5-PRC-02
gh issue create --repo "$REPO" \
  --title '[E5-PRC-02] Configurar tier Starter en WSO2 (PDR-002, PDR-003)' \
  --body $'Como Trazalog, necesito el tier Starter configurado en WSO2 con su cuota de calls MCP y precio de overage, para validar el modelo capacity-based con el primer cliente minero.\nPDR-002: USD 199/mes, 15 usuarios, 1.000 calls MCP/mes (read-only). PDR-003: USD 0,06 por call de overage.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Tier '\''starter'\'' creado en WSO2\n2. Throttling: 15 usuarios activos por empresa, 1.000 calls MCP/mes\n3. Cliente que excede 1.000 calls/mes sigue funcionando (NO se bloquea — el overage se cobra)\n4. Logs registran calls de overage para que E4-DSC-02 los facture\n5. Validación con cliente sintético de 1.100 calls/mes\n\nDEFINICIÓN DE LISTO:\n- [ ] Tests de throttling y overage\n- [ ] Documentado en docs/pricing/tier-starter.md\n- [ ] Reviewed por PM' \
  --label "e5,must-have,type:técnica"

sleep 0.3  # rate limit

# E5-PRC-03
gh issue create --repo "$REPO" \
  --title '[E5-PRC-03] Dashboard simple de consumo en portal del cliente' \
  --body $'Como admin de cuenta de un proveedor minero, necesito ver mi consumo MCP del mes en el portal de Trazalog, para saber cuánto llevo consumido y cuánto me queda del tier.\nVersión MÍNIMA del dashboard de control. La versión completa (con simulador, alertas, spending caps, breakdown por agente) es Phase 2 (E9-FUT-04).\n\nCRITERIOS DE ACEPTACIÓN:\n1. Página PHP nueva en portal admin: /admin/mcp-consumo\n2. Muestra: calls del mes actual, % del tier consumido, cuota restante, fecha estimada de agotamiento al ritmo actual\n3. Tabla de tools más usadas en el mes\n4. Datos vienen de query a BD analytics WSO2\n5. Carga < 2s para hasta 5.000 calls/mes\n6. Si cliente está en Free: muestra CTA con beneficios de Starter\n\nDEFINICIÓN DE LISTO:\n- [ ] Vista funcional en staging-v3\n- [ ] Tests unitarios del controller\n- [ ] Documentado en docs/pricing/consumo-dashboard.md\n- [ ] Reviewed por PM' \
  --label "e5,must-have,type:funcional"

sleep 0.3  # rate limit

# E5-PRC-04
gh issue create --repo "$REPO" \
  --title '[E5-PRC-04] Procedimiento manual de facturación AFIP + MercadoPago' \
  --body $'Como socio comercial de Trazalog, necesito un procedimiento operativo claro para facturar mensualmente a clientes en tier Starter, para cobrar sin sistema de facturación automatizado.\nMDR-002: cero costo fijo de plataforma de pagos. Solo comisión MercadoPago por transacción.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Documento de procedimiento paso a paso: ejecutar script de reporte (E4-DSC-02) → revisar excedentes → emitir factura electrónica AFIP → enviar link de pago MercadoPago → registrar pago\n2. Plantillas de email para envío de factura\n3. Plantilla de factura AFIP cargada en el sistema de AFIP\n4. Link de pago MercadoPago configurado por cliente o link genérico\n5. Procedimiento ejecutado al menos 1 vez con cliente sintético\n\nDEFINICIÓN DE LISTO:\n- [ ] Documento en docs/operations/billing-procedure.md\n- [ ] Validado con socio comercial\n- [ ] Reviewed por PM' \
  --label "e5,must-have,type:documentación"

sleep 0.3  # rate limit

# E5-PRC-05
gh issue create --repo "$REPO" \
  --title '[E5-PRC-05] Validar tiers con primer cliente minero' \
  --body $'Como socio comercial, necesito validar con el primer cliente minero (early adopter) que el tier Professional (USD 449) sea aceptable como punto de migración futura desde su licencia actual de USD 563/mes.\nAcción comercial pura — no produce código. Output: confirmación o ajuste de pricing.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Reunión comercial ejecutada con el cliente\n2. Pricing presentado: Free (3 meses early adopter), Starter (USD 199), Professional (USD 449 desde mes 4)\n3. Feedback del cliente registrado\n4. Si requiere ajuste: PDR de revisión creado\n\nDEFINICIÓN DE LISTO:\n- [ ] Notas de la reunión en docs/clients/early-adopter-pricing.md\n- [ ] Reviewed por PM y socio' \
  --label "e5,must-have,type:funcional"

sleep 0.3  # rate limit

# E6-EA-01
gh issue create --repo "$REPO" \
  --title '[E6-EA-01] Preparar deck y acuerdo de early adopter' \
  --body $'Como socio comercial, necesito un deck de presentación y un acuerdo formal de early adopter, para activar el programa con el cliente minero candidato.\nAcuerdo: 3 meses sin costo de capa MCP a cambio de feedback estructurado.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Deck (PDF o Google Slides) con: visión MCP, qué va a poder hacer el cliente, qué se espera del cliente, hoja de ruta de 12 semanas\n2. Acuerdo de early adopter firmable: 3 meses sin costo, compromiso de 1 sesión guiada inicial + 4 reuniones quincenales de seguimiento, derecho de uso de logo del cliente como caso de éxito (con su permiso)\n3. Contacto clave del cliente identificado (idealmente jefe de mantenimiento)\n\nDEFINICIÓN DE LISTO:\n- [ ] Materiales en docs/clients/early-adopter-package/\n- [ ] Acuerdo aprobado por PM y socio\n- [ ] Reviewed por PM' \
  --label "e6,must-have,type:documentación"

sleep 0.3  # rate limit

# E6-EA-02
gh issue create --repo "$REPO" \
  --title '[E6-EA-02] Auditoría de datos del cliente antes de conectar MCP' \
  --body $'Como PM, necesito verificar que los datos del cliente en Asset Planner están en condiciones para alimentar el MCP, para evitar que el cliente reciba respuestas pobres por datos incompletos.\nSi falta algo, ayudar a completarlo durante semana 2-3 del programa.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Checklist de calidad ejecutado: equipos con criticidad, OTs con timestamps completos, preventivos programados, lecturas predictivas, repuestos con punto de pedido\n2. Reporte de gaps: qué falta y cuánto esfuerzo es completarlo\n3. Plan de remediación acordado con el cliente\n4. Datos completados antes de conexión MCP\n\nDEFINICIÓN DE LISTO:\n- [ ] Reporte en docs/clients/<cliente>/data-audit.md\n- [ ] Cliente confirma calidad de datos\n- [ ] Reviewed por PM' \
  --label "e6,must-have,type:investigación"

sleep 0.3  # rate limit

# E6-EA-03
gh issue create --repo "$REPO" \
  --title '[E6-EA-03] Conectar MCP a instancia productiva del cliente' \
  --body $'Como PM técnico, necesito configurar la suscripción MCP del cliente en WSO2 con su API key y validar que los Virtual MCP Servers devuelven datos correctos y segregados, para tener todo listo antes de la sesión guiada.\nEste es el momento de la verdad técnica del MVP.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Suscripción del cliente creada en WSO2 con tier '\''early-adopter'\'' (cuota equivalente a Starter durante 3 meses)\n2. API key entregada al cliente con instrucciones\n3. Probadas 5 consultas reales con datos del cliente desde Claude Desktop\n4. Confirmado: el cliente NO ve datos de otras empresas (multi-empresa funciona)\n5. Tiempo de respuesta < 3s en las 5 consultas\n\nDEFINICIÓN DE LISTO:\n- [ ] Reporte de validación en docs/clients/<cliente>/mcp-connection.md\n- [ ] Cliente recibe instrucciones de conexión\n- [ ] Reviewed por PM' \
  --label "e6,must-have,type:técnica"

sleep 0.3  # rate limit

# E6-EA-04
gh issue create --repo "$REPO" \
  --title '[E6-EA-04] Sesión guiada inicial con contacto clave' \
  --body $'Como PM y socio comercial, necesitamos ejecutar la sesión guiada inicial de ~2hs con el contacto clave del cliente, para hacer las primeras consultas usando los prompt templates y registrar lo que el cliente pregunta espontáneamente.\nEsta sesión define el modo de uso posterior (Claude Desktop directo, intermediario por WhatsApp, o esperar a UI propia post-MVP).\n\nCRITERIOS DE ACEPTACIÓN:\n1. Reunión ejecutada (presencial o virtual de 2hs)\n2. Cliente probó los 10 prompts del playbook\n3. Registro de: qué consultó espontáneamente, qué le sorprendió, qué esperaba y no encontró\n4. Decisión documentada de modo de uso posterior\n5. Frecuencia de seguimiento confirmada (quincenal)\n\nDEFINICIÓN DE LISTO:\n- [ ] Notas en docs/clients/<cliente>/sesion-inicial.md\n- [ ] Reviewed por PM y socio' \
  --label "e6,must-have,type:funcional"

sleep 0.3  # rate limit

# E6-EA-05
gh issue create --repo "$REPO" \
  --title '[E6-EA-05] Seguimiento quincenal (semanas 5-12)' \
  --body $'Como PM, necesito reuniones quincenales de 15 minutos con el cliente entre las semanas 5 y 12, para revisar el uso real del MCP, capturar feedback fresco y alimentar el motor de descubrimiento.\nCuatro reuniones en total. Cada una se nutre del dashboard de uso (E4-DSC-03) + feedback verbal del cliente.\n\nCRITERIOS DE ACEPTACIÓN:\n1. 4 reuniones quincenales ejecutadas (semanas 5, 7, 9, 11)\n2. Por cada reunión: dashboard de uso compartido con el cliente, feedback registrado, decisiones tomadas\n3. Patrones detectados que alimentan E4-DSC-04\n4. Si surge un gap crítico: historia agregada al backlog v3.1+\n\nDEFINICIÓN DE LISTO:\n- [ ] Notas de las 4 reuniones en docs/clients/<cliente>/seguimiento/\n- [ ] Lista de patrones detectados consolidada al final del programa\n- [ ] Reviewed por PM' \
  --label "e6,must-have,type:funcional"

sleep 0.3  # rate limit

# E6-EA-06
gh issue create --repo "$REPO" \
  --title '[E6-EA-06] Evaluación final y propuesta de pricing (semana 12)' \
  --body $'Como socio comercial, necesito ejecutar la reunión de cierre con el cliente al final de los 3 meses, para presentar métricas de uso, valor entregado, propuesta de pricing y evaluar NPS.\nSi el cliente acepta migrar a Starter o Professional, se documenta como caso de éxito.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Reunión de cierre ejecutada\n2. Métricas presentadas: total de calls del trimestre, top tools usadas, tiempo ahorrado estimado en reportes (input del cliente)\n3. Propuesta de migración: Starter (USD 199) o Professional (USD 449) con comparación de valor vs licencia actual\n4. NPS del cliente capturado (escala 0-10 + comentario)\n5. Si NPS >= 8: caso de éxito autorizado y documentado\n\nDEFINICIÓN DE LISTO:\n- [ ] Acta de reunión en docs/clients/<cliente>/cierre.md\n- [ ] Caso de éxito (si aplica) en docs/cases/<cliente>.md\n- [ ] Reviewed por PM y socio' \
  --label "e6,must-have,type:funcional"

sleep 0.3  # rate limit

# E7-CICD-01
gh issue create --repo "$REPO" \
  --title '[E7-CICD-01] Crear rama develop-v3 con protected branch' \
  --body $'Como PM técnico, necesito la rama develop-v3 creada y protegida en GitHub, para separar el flujo de features de v3 del flujo de soporte de v2 (que sigue en develop).\nDecisión documentada en CICD_STRATEGY: develop sigue siendo línea de soporte v2 sin cambios; develop-v3 es donde se construye v3.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Rama develop-v3 creada a partir de develop actual\n2. Branch protection configurada: requiere PR, requiere CI verde, no permite force push\n3. Documento de regla en CONTRIBUTING.md: features de v3 → develop-v3, fixes de v2 → develop\n4. PR template configurado con checklist mínimo\n\nDEFINICIÓN DE LISTO:\n- [ ] Rama visible y protegida en GitHub\n- [ ] Documento aprobado por PM' \
  --label "e7,must-have,type:técnica"

sleep 0.3  # rate limit

# E7-CICD-02
gh issue create --repo "$REPO" \
  --title '[E7-CICD-02] Workflow v2-ci.yml — pipeline suave para v2' \
  --body $'Como equipo de soporte v2, necesito un pipeline de CI no invasivo en develop y master, para tener checks básicos sin afectar el flujo actual de soporte (que usa deploytools.sh, GitKraken, DBeaver).\nLint en modo warning (no bloquea), tests si existen, smoke check de schema.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Archivo .github/workflows/v2-ci.yml creado\n2. Trigger: PR a develop y a master\n3. Steps: lint PHP en warning (no bloquea), ejecutar tests existentes si hay, validar schema BD coherente con el repo\n4. Pipeline no rompe builds existentes (validado con 3 PRs reales)\n\nDEFINICIÓN DE LISTO:\n- [ ] Pipeline corriendo en GitHub Actions\n- [ ] Equipo soporte confirma que no afecta su flujo\n- [ ] Reviewed por PM' \
  --label "e7,must-have,type:técnica"

sleep 0.3  # rate limit

# E7-CICD-03
gh issue create --repo "$REPO" \
  --title '[E7-CICD-03] Workflow v3-ci.yml — pipeline estricto para v3' \
  --body $'Como PM técnico de v3, necesito un pipeline de CI estricto en develop-v3, para asegurar calidad en cada PR antes de mergear.\nLint estricto bloquea, tests PHPUnit obligatorios, tests de API con Hurl, validación con MCP Inspector para tools nuevos.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Archivo .github/workflows/v3-ci.yml creado\n2. Trigger: PR a develop-v3\n3. Steps obligatorios: lint estricto (bloquea si falla), PHPUnit (bloquea si falla), tests Hurl de APIs nuevas, MCP Inspector contra tools afectados\n4. Definition of Done de cada PR: todos los steps verdes\n5. Pipeline corre en < 5 minutos para PRs típicos\n\nDEFINICIÓN DE LISTO:\n- [ ] Pipeline corriendo en GitHub Actions\n- [ ] Documentado en docs/ci/v3-pipeline.md\n- [ ] Reviewed por PM' \
  --label "e7,must-have,type:técnica"

sleep 0.3  # rate limit

# E7-CICD-04
gh issue create --repo "$REPO" \
  --title '[E7-CICD-04] Workflow security.yml — escaneo de seguridad compartido' \
  --body $'Como PM, necesito un pipeline de seguridad que ejecute escaneos diariamente y en cada PR, para detectar vulnerabilidades, secretos y problemas de código sin esperar a que ocurra un incidente.\nAplica a v2 y v3.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Archivo .github/workflows/security.yml creado\n2. Steps: Trivy (vulnerabilidades en deps + contenedores), Semgrep (análisis estático), gitleaks (detección de secretos)\n3. Cron diario a las 03:00 UTC + trigger en cada PR\n4. Notificación a Slack/email si severidad alta o crítica\n\nDEFINICIÓN DE LISTO:\n- [ ] Pipeline corriendo\n- [ ] Primer escaneo limpio (todos los hallazgos justificados o resueltos)\n- [ ] Reviewed por PM' \
  --label "e7,must-have,type:técnica"

sleep 0.3  # rate limit

# E7-CICD-05
gh issue create --repo "$REPO" \
  --title '[E7-CICD-05] Setup de staging-v3 environment' \
  --body $'Como PM técnico, necesito un ambiente staging-v3 separado del staging-v2 actual, para probar v3 sin afectar v2.\nDeploy automático desde develop-v3.\n\nCRITERIOS DE ACEPTACIÓN:\n1. VM TEST (E0-INF-02) configurada como staging-v3\n2. URL distinta del staging-v2 (ej: staging-v3.cloudtrazalog.com)\n3. Base de datos PostgreSQL separada con dump anonimizado de datos productivos\n4. Deploy automático en cada merge a develop-v3 (workflow GitHub Actions)\n5. Smoke test post-deploy automático\n\nDEFINICIÓN DE LISTO:\n- [ ] Staging-v3 accesible y operativo\n- [ ] Documentado en docs/ci/staging-v3.md\n- [ ] Reviewed por PM' \
  --label "e7,must-have,type:técnica"

sleep 0.3  # rate limit

# E7-CICD-06
gh issue create --repo "$REPO" \
  --title '[E7-CICD-06] Sincronización semanal develop → develop-v3' \
  --body $'Como PM técnico, necesito un proceso documentado y automatizable de sincronización semanal de develop hacia develop-v3, para mantener los fixes de soporte v2 incorporados en v3 y evitar que las ramas se separen demasiado.\nSi pasamos 4 meses sin sincronizar, el merge final del cutover es muy doloroso.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Script bash que ejecuta el merge: git checkout develop-v3 && git merge origin/develop --no-ff -m '\''chore: sync v2 fixes from develop'\''\n2. Reminder semanal (calendar event) para PM\n3. Documento que explica qué hacer si hay conflictos\n4. Primera sincronización ejecutada con éxito\n\nDEFINICIÓN DE LISTO:\n- [ ] Script en scripts/dev/sync-v2-to-v3.sh\n- [ ] Reminder configurado\n- [ ] Documentado en docs/ci/sync-procedure.md\n- [ ] Reviewed por PM' \
  --label "e7,should-have,type:técnica"

sleep 0.3  # rate limit

# E8-REG-01
gh issue create --repo "$REPO" \
  --title '[E8-REG-01] Setup de Playwright + config dual (staging-v2 y staging-v3)' \
  --body $'Como PM técnico, necesito Playwright configurado en el repo con dos projects (staging-v2 y staging-v3), para correr la misma suite contra ambos ambientes y detectar regresiones de v3 vs el comportamiento conocido de v2.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Estructura tests/regression/ creada\n2. playwright.config.ts con dos projects: staging-v2 (URL prod-v2) y staging-v3 (URL TEST-v3)\n3. Setup de fixtures, helpers, data-setup\n4. Smoke test de ejemplo corriendo OK contra ambos ambientes\n\nDEFINICIÓN DE LISTO:\n- [ ] Suite arrancando localmente y en CI\n- [ ] Documentado en docs/qa/playwright-setup.md\n- [ ] Reviewed por PM' \
  --label "e8,must-have,type:técnica"

sleep 0.3  # rate limit

# E8-REG-02
gh issue create --repo "$REPO" \
  --title '[E8-REG-02] Identificar y priorizar los 15 flujos críticos (Pareto)' \
  --body $'Como PM y QC, necesitamos identificar los 10-15 flujos más críticos que existen en v2 y deben seguir funcionando en v3, para decidir qué automatizar primero con Playwright.\nPareto: el 20% de flujos cubre el 80% del riesgo de regresión.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Sesión con QC ejecutada (~2hs)\n2. Lista priorizada de 10-15 flujos: login, OTs correctivas, OTs preventivas, asignar/cerrar OT, consumo material en OT, dashboard KPIs, KoolReport semanal, movimiento de stock, QR de artículo, workflow Bonita, formulario dinámico con adjunto, registro de residuo, registro de producción, permisos de usuario, contexto multi-empresa\n3. Cada flujo con: nombre, descripción, criticidad, frecuencia de uso real\n4. Documento en docs/qa/critical-flows.md\n\nDEFINICIÓN DE LISTO:\n- [ ] Lista aprobada por PM, QC y socio\n- [ ] Reviewed por PM' \
  --label "e8,must-have,type:investigación"

sleep 0.3  # rate limit

# E8-REG-03
gh issue create --repo "$REPO" \
  --title '[E8-REG-03] Capturar 15 flujos en Gherkin + implementar en Playwright' \
  --body $'Como QC + PM + Claude Code, necesitamos capturar cada uno de los 15 flujos críticos en formato Gherkin (sesiones de captura con QC) y luego implementarlos como tests Playwright (Claude Code).\nEs la story más grande del backlog. Se ejecuta de forma incremental: 1 flujo por sprint en M2-M3.\n\nCRITERIOS DE ACEPTACIÓN:\n1. 15 archivos .spec.ts en tests/regression/flows/, uno por flujo\n2. 15 archivos .feature en formato Gherkin como documentación viva\n3. Cada test pasa contra staging-v2 (verde antes de ejecutar contra v3)\n4. Tests son idempotentes (no requieren reset manual de datos)\n5. Cada test tarda < 2 minutos individualmente\n\nDEFINICIÓN DE LISTO:\n- [ ] 15 specs en repo\n- [ ] Suite completa < 30 min en CI\n- [ ] Reviewed por PM y QC' \
  --label "e8,must-have,type:técnica"

sleep 0.3  # rate limit

# E8-REG-04
gh issue create --repo "$REPO" \
  --title '[E8-REG-04] Workflow regression.yml — ejecución contra staging-v2 y staging-v3' \
  --body $'Como PM, necesito un workflow que ejecute la suite Playwright contra los dos ambientes en cadencias distintas, para detectar regresiones cuando aparezcan.\nStaging-v2: cron semanal (baseline). Staging-v3: diario + en cada release.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Archivo .github/workflows/regression.yml creado\n2. Trigger 1: cron semanal (lunes 06:00 UTC) contra staging-v2\n3. Trigger 2: cron diario (06:00 UTC) contra staging-v3\n4. Trigger 3: manual (workflow_dispatch) para ambos\n5. Trigger 4: en release tag de develop-v3\n6. Notificación Slack/email si falla algún flujo crítico\n7. Reportes Playwright HTML almacenados como artifacts\n\nDEFINICIÓN DE LISTO:\n- [ ] Pipeline corriendo en GitHub Actions\n- [ ] Documentado en docs/ci/regression.md\n- [ ] Reviewed por PM' \
  --label "e8,must-have,type:técnica"

sleep 0.3  # rate limit

# E8-REG-05
gh issue create --repo "$REPO" \
  --title '[E8-REG-05] Validar baseline contra v2 (7 días verde) y staging-v3 (3 días verde)' \
  --body $'Como PM, necesito que la suite pase 7 días consecutivos contra staging-v2 (baseline confirmado) y 3 días consecutivos contra staging-v3, para autorizar el cutover.\nEsto es la condición Definition of Done del cutover según CICD_STRATEGY.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Suite verde 7 días seguidos contra staging-v2 (si falla, ajustar test para reflejar comportamiento real de v2)\n2. Suite verde 3 días seguidos contra staging-v3\n3. Documentado en docs/qa/cutover-readiness.md\n4. Si algún flujo falla en v3 pero pasa en v2: bug bloqueante de cutover\n\nDEFINICIÓN DE LISTO:\n- [ ] Reporte de baseline aprobado por PM y QC\n- [ ] Reviewed por PM' \
  --label "e8,must-have,type:funcional"

sleep 0.3  # rate limit

# E8-REG-06
gh issue create --repo "$REPO" \
  --title '[E8-REG-06] Runbook de cutover v2 → v3' \
  --body $'Como PM, necesito un runbook detallado del cutover único de v2 a v3, para que la operación salga sin sorpresas.\nEl cutover incluye: merge develop-v3 → develop, suite completa, promoción a master, deploy en producción, migración de OS de PROD (E0-INF-07), verificación post-deploy.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Runbook paso a paso en docs/ops/cutover-runbook.md\n2. Plan de rollback (revertir merge, restaurar snapshot OS, restaurar BD)\n3. Checklist de verificación post-deploy con 20+ items\n4. Tiempos estimados por paso\n5. Roles asignados (RACI): PM, socio comercial, soporte v2\n6. Comunicación con clientes pre-cutover (template)\n7. Ensayo del cutover ejecutado contra TEST\n\nDEFINICIÓN DE LISTO:\n- [ ] Runbook revisado por PM y socio\n- [ ] Ensayo en TEST exitoso\n- [ ] Aprobado por PM' \
  --label "e8,must-have,type:documentación"

sleep 0.3  # rate limit

# E9-FUT-01
gh issue create --repo "$REPO" \
  --title '[E9-FUT-01] Unificación de almacenes: Asset Planner ALM → traz-comp-almacenes' \
  --body $'Como PM, necesito migrar los datos del almacén legacy de Asset Planner a traz-comp-almacenes, para deprecar el módulo legacy y permitir cruces nativos repuesto↔OT en el MCP.\nEsto desbloquea EXP-03 y EXP-04 nativos para clientes existentes (hoy funcionan separados por ADR-004).\n\nCRITERIOS DE ACEPTACIÓN:\n1. Plan de migración de datos del almacén legacy AP a traz-comp-almacenes\n2. Modificación de Asset Planner para que consume stock vía APIs de traz-comp-almacenes\n3. Migración ejecutada para Tierra Capayán (cliente existente con datos en almacén legacy)\n4. MCP-06 reapuntado a traz-comp-almacenes\n5. Almacén legacy de Asset Planner deprecado\n\nDEFINICIÓN DE LISTO:\n- [ ] Migración ejecutada sin pérdida de datos\n- [ ] Tests nativos repuesto↔OT verdes\n- [ ] Reviewed por PM' \
  --label "e9,should-have,type:técnica,db-migration"

sleep 0.3  # rate limit

# E9-FUT-02
gh issue create --repo "$REPO" \
  --title '[E9-FUT-02] MCP Server Python (FastMCP) para AI/ML/RAG (Phase 2)' \
  --body $'Como Trazalog, necesito un MCP Server adicional en Python (FastMCP) para casos que WSO2 no puede resolver: inferencia ML, RAG sobre documentos, lógica de IA compleja.\nSolo para los ~10-20% de casos que justifican Python según ADR-002.\n\nCRITERIOS DE ACEPTACIÓN:\n1. FastMCP server desplegado en infraestructura propia\n2. Conectado al WSO2 Gateway como upstream para que el cliente vea un solo punto de entrada\n3. Caso de uso piloto: predicción de fallas con ML simple\n4. Documentado en MCP_ARCHITECTURE.md sección Phase 2\n\nDEFINICIÓN DE LISTO:\n- [ ] Server operativo en TEST\n- [ ] Reviewed por PM' \
  --label "e9,could-have,type:técnica"

sleep 0.3  # rate limit

# E9-FUT-03
gh issue create --repo "$REPO" \
  --title '[E9-FUT-03] MCP Writes — tools de escritura (crear OT, registrar intervención)' \
  --body $'Como agente IA del cliente, necesito poder crear OTs, registrar intervenciones y actualizar estado de equipos desde la conversación, para que el sistema sea proactivo y no solo de consulta.\nPhase 2 según ADR-002. Tier Professional (USD 449).\n\nCRITERIOS DE ACEPTACIÓN:\n1. Tool MCP create_work_order con validaciones\n2. Tool MCP register_intervention\n3. Tool MCP update_equipment_status\n4. Confirmaciones por LLM antes de ejecutar acción\n5. Tier Professional activado en WSO2\n\nDEFINICIÓN DE LISTO:\n- [ ] Validado con cliente piloto\n- [ ] Reviewed por PM' \
  --label "e9,should-have,type:funcional"

sleep 0.3  # rate limit

# E9-FUT-04
gh issue create --repo "$REPO" \
  --title '[E9-FUT-04] Dashboard completo de control de consumo (PDR-004 completo)' \
  --body $'Como admin de cuenta del cliente, necesito un dashboard completo de control con: simulador de consumo, alertas, spending caps, breakdown por agente, historial descargable, además del consumo básico (E5-PRC-03).\nPDR-004 completo. Phase 2.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Simulador: '\''si invoco esta tool N veces, cuesto X'\''\n2. Alertas configurables al 50%, 80%, 100% del tier\n3. Spending caps duros (cliente decide limitar consumo)\n4. Breakdown por agente IA (cuál agente consumió cuánto)\n5. Historial descargable en CSV\n\nDEFINICIÓN DE LISTO:\n- [ ] Las 6 features de control listadas en PRICING_STRATEGY operativas\n- [ ] Reviewed por PM' \
  --label "e9,should-have,type:funcional"

sleep 0.3  # rate limit

# E9-FUT-05
gh issue create --repo "$REPO" \
  --title '[E9-FUT-05] Templates de procesos BPM HSE para minería' \
  --body $'Como Trazalog, necesito templates de procesos BPM pre-diseñados para flujos HSE (incidentes, near-miss, EPP, habilitaciones), para acelerar el onboarding de proveedores mineros que necesiten certificar ISO 45001.\nDiseño usando módulo de Procesos existente (BPM Bonita), no construir nuevo módulo.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Template: reporte de incidentes → investigación → acción correctiva → seguimiento (ISO 45001)\n2. Template: checklist de inspección pre-turno\n3. Template: registro de entrega de EPP con firma\n4. Template: control de habilitaciones del personal con alertas de vencimiento\n5. Templates importables a una instancia nueva en < 1h\n\nDEFINICIÓN DE LISTO:\n- [ ] Templates en docs/bpm/templates-hse/\n- [ ] Reviewed por PM' \
  --label "e9,should-have,type:funcional"

sleep 0.3  # rate limit

# E9-FUT-06
gh issue create --repo "$REPO" \
  --title '[E9-FUT-06] Kit de certificación ISO empaquetado' \
  --body $'Como Trazalog (comercial), necesito un kit de certificación ISO empaquetado como producto, para venderlo a proveedores mineros que necesiten certificar ISO 9001 / 14001 / 45001.\nMaterial comercial: '\''con Trazalog tenés el 70% de lo que necesitás para certificar'\''.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Mapeo ISO 9001/14001/45001 ↔ funcionalidades de Trazalog\n2. Templates de procesos BPM para los flujos ISO más comunes\n3. Checklist de cumplimiento por norma\n4. Material comercial (one-pager, deck)\n\nDEFINICIÓN DE LISTO:\n- [ ] Validado con auditor ISO externo (al menos 1)\n- [ ] Reviewed por PM y socio' \
  --label "e9,could-have,type:documentación"

sleep 0.3  # rate limit

# E9-FUT-07
gh issue create --repo "$REPO" \
  --title '[E9-FUT-07] Interfaz de chat embebida en Trazalog (Opción B)' \
  --body $'Como cliente sin Claude Pro, necesito un chat embebido dentro del portal Trazalog que use la API de Claude por detrás + MCP Server, para no depender de tener cuenta de Claude.\nDecisión post early adopter — solo se construye si el volumen de uso lo justifica.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Frontend de chat embebido en portal admin\n2. Backend que orquesta Claude API + MCP Servers\n3. Branding Trazalog (no Claude)\n4. Cobro: incluido en tier Starter / Professional\n\nDEFINICIÓN DE LISTO:\n- [ ] Validado con cliente piloto post-early adopter\n- [ ] Reviewed por PM' \
  --label "e9,could-have,type:funcional"

sleep 0.3  # rate limit

# E9-FUT-08
gh issue create --repo "$REPO" \
  --title '[E9-FUT-08] Agentes proactivos (alertas automáticas vía WhatsApp)' \
  --body $'Como gerente de proveedor minero, necesito recibir alertas proactivas por WhatsApp cuando hay preventivos por vencer, stock bajo con riesgo de stockout, o KPIs degradándose, para no tener que consultar el sistema.\nTrigger: cuando el log de descubrimiento (E4-DSC-04) revele consultas repetitivas que justifiquen automatizarlas.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Agentes programados (cron) que detectan situaciones\n2. Integración con conector WhatsApp existente\n3. Configuración de qué alertas recibir por usuario\n4. Frecuencia configurable (diaria, semanal)\n\nDEFINICIÓN DE LISTO:\n- [ ] Validado con cliente piloto\n- [ ] Reviewed por PM' \
  --label "e9,could-have,type:funcional"

sleep 0.3  # rate limit

# E9-FUT-09
gh issue create --repo "$REPO" \
  --title '[E9-FUT-09] Modernización UX del frontend' \
  --body $'Como Trazalog, necesito un reskin del frontend (theme moderno, responsive, dashboard landing) sin tocar la lógica de negocio, para no perder oportunidades por percepción de UX legacy.\nActivar solo si el feedback de clientes mineros indica que la UX es barrera de adopción.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Theme nuevo aplicado a las pantallas más visitadas\n2. Responsive mejorado en mobile\n3. Dashboard landing renovado\n4. Sin cambios en la lógica PHP\n\nDEFINICIÓN DE LISTO:\n- [ ] Aprobación visual de PM y socio\n- [ ] Reviewed por PM' \
  --label "e9,could-have,type:funcional"

sleep 0.3  # rate limit

# E9-FUT-10
gh issue create --repo "$REPO" \
  --title '[E9-FUT-10] Migración completa de Asset Planner a Tools (v4)' \
  --body $'Como Trazalog, necesito migrar todas las entidades de Asset Planner a la estructura traz-tools, para unificar la base de código, deprecar el proyecto separado y simplificar mantenimiento.\nEs el objetivo de v4. Prerequisito: E9-FUT-01 completado.\n\nCRITERIOS DE ACEPTACIÓN:\n1. Mapeo completo de entidades de Asset Planner a traz-tools\n2. Migración de código y datos\n3. Reapuntar referencias (OTs, preventivos, backlog)\n4. Deprecar proyecto traz-prod-assetplanner\n\nDEFINICIÓN DE LISTO:\n- [ ] Validado con todos los clientes existentes\n- [ ] Reviewed por PM' \
  --label "e9,wont-have,type:técnica,db-migration"

sleep 0.3  # rate limit


echo ""
echo "✓ 70 issues creados en $REPO"
echo ""
echo "PRÓXIMOS PASOS:"
echo "1. Ir a GitHub Project: https://github.com/Trazalog/traz-tools/projects/3"
echo "2. Asignar Story Points, Sprint, Mes, etc a cada issue"
echo "3. Mover los 8 issues del Sprint 1 a la columna 'Sprint Ready'"
echo ""
echo "Issues del Sprint 1:"
echo "  - E0-INF-01"
echo "  - E7-CICD-01"
echo "  - E7-CICD-06"
echo "  - E1-API-01"
echo "  - E1-API-02"
echo "  - E0-INF-02"
echo "  - E0-INF-03"
echo "  - E0-INF-04"
