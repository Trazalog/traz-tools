# Trazalog v3 — Arquitectura MCP

## Documento de Arquitectura Técnica
**Versión:** 1.3  
**Fecha:** Marzo 2026 (v1.0) — Mayo 2026 (v1.3 — ADR-008 sobre validación JWT en APIM)  
**Autor:** Rodolfo (Co-founder & Lead Developer) + Claude (AI Architecture Advisor)  
**Estado:** En definición — decisiones consolidadas de sesiones de diseño

**Changelog:**
- **v1.3 (Mayo 2026):** Se incorpora ADR-008 — APIM valida JWT de Dnato como Key Manager federado. Reemplaza el patrón "JWT passthrough al MI" propuesto en `openapi-publish-procedure.md`. Justificación principal: viabilidad de APIM único compartido entre APIs MCP y legacy sin flags globales que rompan unas u otras.

---

## 1. Contexto Estratégico

### 1.1 Qué es Trazalog Tools

Trazalog Tools es una plataforma de gestión industrial para PyMEs, con base en San Juan, Argentina, orientada a la región de Cuyo. La plataforma actualmente opera con los siguientes módulos:

- **Asset Planner (AP):** Gestión de mantenimiento de equipos. Implementa MTBF, MTTR, MTTF, Confiabilidad, ciclo de vida de OTs, consumo de materiales por orden de trabajo.
- **Almacenes (ALM):** Gestión de depósitos (componente `traz-comp-almacenes`).
- **Procesos (PRO):** Workflows BPM vía Bonita.
- **Producción (PRD):** Módulo productivo (`traz-prod-trazasoft`).
- **Residuos (RES):** Gestión de residuos industriales.

Los clientes actuales van desde equipos pequeños (~5 usuarios) hasta despliegues grandes (100+ usuarios), incluyendo clientes municipales/gubernamentales.

### 1.2 Pivote Estratégico

El pivote estratégico apunta al **sector de servicios mineros** en San Juan, donde proyectos mineros internacionales entrarán en fase de construcción alrededor de 2027. Esto genera demanda urgente de proveedores PyME locales para profesionalizarse. Un proveedor de servicios de mantenimiento minero está próximo a cerrar como primer cliente del vertical.

### 1.3 Por Qué MCP

La capa MCP transforma Trazalog de una plataforma de gestión tradicional a una **plataforma AI-ready**, permitiendo que agentes de IA (Claude, ChatGPT, Copilot, Gemini, o agentes custom de clientes) interactúen con los datos y operaciones de Trazalog de forma estandarizada, segura y monetizable.

Esto habilita:
- Un canal de discovery para nuevos clientes (modelo freemium + MCP).
- Diferenciación competitiva frente a ERPs tradicionales.
- Monetización basada en uso de herramientas de IA, no solo licencias por usuario.
- Co-discovery de features específicas de minería con clientes tempranos.

---

## 2. MCP como Estándar de Industria

### 2.1 Estado de Adopción (Marzo 2026)

MCP (Model Context Protocol) fue creado por Anthropic en noviembre 2024 y en poco más de un año se convirtió en el estándar de facto para conectar sistemas de IA con herramientas y datos externos.

**Adopción por plataformas de IA:**

| Plataforma | Soporte MCP | Desde |
|---|---|---|
| Claude (Anthropic) | ✅ Nativo, creador del protocolo | Nov 2024 |
| ChatGPT (OpenAI) | ✅ Desktop, Agents SDK, Responses API | Mar 2025 |
| Gemini (Google DeepMind) | ✅ Adoptado | Abr 2025 |
| Microsoft Copilot | ✅ Integrado con Semantic Kernel | 2025 |
| Visual Studio Code | ✅ Soporte nativo | 2025 |
| Cursor | ✅ Soporte nativo | 2025 |
| DeepSeek, Qwen, Kimi (China) | ⚠️ Sin adopción formal, soportan function calling compatible | — |

**Gobernanza:** En diciembre 2025, Anthropic donó MCP a la **Agentic AI Foundation (AAIF)**, un fondo dirigido bajo la **Linux Foundation**, cofundado por Anthropic, Block y OpenAI, con soporte de AWS, Google, Microsoft, Cloudflare y Bloomberg.

**Ecosistema:** 97 millones de descargas mensuales del SDK, más de 10.000 servers activos, más de 6.400 servers en el registro oficial.

### 2.2 MCP vs REST API: Diferencias Clave

MCP **no reemplaza** REST APIs. Es una capa superior diseñada para que agentes de IA consuman servicios. Los MCP servers típicamente envuelven APIs REST existentes.

| Aspecto | REST API + API Gateway | MCP |
|---|---|---|
| **Diseñado para** | Desarrolladores humanos que escriben código | Agentes de IA (LLMs) que razonan y deciden |
| **Descubrimiento** | Estático (documentación OpenAPI) | Dinámico (`tools/list` en runtime) |
| **Estado de sesión** | Stateless (cada call es independiente) | Stateful (contexto persiste entre tool calls) |
| **Granularidad** | Endpoints técnicos (CRUD) | Herramientas semánticas (tareas completas) |
| **Protocolo** | HTTP con variaciones infinitas | JSON-RPC 2.0 sobre Streamable HTTP (uniforme) |
| **Seguridad** | OAuth 2.0 + policies por endpoint | OAuth 2.1 + policies por herramienta individual |
| **Contexto** | Manual (el developer pasa estado entre calls) | Automático (el agente mantiene historial de acciones) |
| **Nuevas capacidades** | Requiere actualizar integración del cliente | El agente descubre automáticamente nuevas tools |

**Regla práctica:** Si el cliente es un programa escrito por un humano → REST. Si el cliente es un modelo de IA → MCP (que envuelve REST).

---

## 3. Arquitectura de Referencia

### 3.1 Diagrama General

```
┌─────────────────────────────────────────────────────────────┐
│                      MCP CLIENTS                            │
│   Claude · ChatGPT · Copilot · Gemini · Cursor              │
│   Agentes custom de clientes · Apps de partners              │
└──────────────────────────┬──────────────────────────────────┘
                           │ Streamable HTTP / JSON-RPC 2.0
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              WSO2 MCP GATEWAY / AI GATEWAY                  │
│                                                             │
│  ┌──────────────┐ ┌───────────────┐ ┌────────────────────┐ │
│  │  OAuth 2.1   │ │  Rate Limit   │ │   Monetización     │ │
│  │  + Scopes    │ │  por Tool     │ │   (Moesif/Stripe)  │ │
│  │  + PKCE      │ │  por Cliente  │ │                    │ │
│  └──────────────┘ └───────────────┘ └────────────────────┘ │
│  ┌──────────────┐ ┌───────────────┐ ┌────────────────────┐ │
│  │   MCP Hub    │ │  Analytics &  │ │   Guardrails &     │ │
│  │  (Catálogo)  │ │  Observability│ │   RBAC / OPA       │ │
│  └──────────────┘ └───────────────┘ └────────────────────┘ │
│                                                             │
│  Modos de creación de MCP Servers:                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 1. Virtual MCP Server (auto-generado desde OpenAPI) │   │
│  │ 2. Proxy a MCP Server externo (ej: Python)          │   │
│  │ 3. Importar definición OpenAPI                       │   │
│  └─────────────────────────────────────────────────────┘   │
└────────┬────────────────────────────┬───────────────────────┘
         │                            │
         │ (Modo 1: directo)          │ (Modo 2: proxy)
         │                            │
         │                            ▼
         │                 ┌─────────────────────────┐
         │                 │  Python MCP Server(s)   │
         │                 │  (FastMCP)              │
         │                 │                         │
         │                 │  SOLO para:             │
         │                 │  • IA/ML (predicción,   │
         │                 │    anomalías, NLP)      │
         │                 │  • Procesamiento de     │
         │                 │    datos no-estructurados│
         │                 │    (PDFs, Excel, imgs)  │
         │                 │  • RAG / prompt assembly│
         │                 │                         │
         │                 │  ⚠️ NO en MVP (Fase 2+) │
         │                 └────────────┬────────────┘
         │                              │
         ▼                              ▼
┌─────────────────────────────────────────────────────────────┐
│              WSO2 API MANAGER / ESB                         │
│          (Capa de APIs REST de Trazalog)                     │
│                                                             │
│  ┌────────────┐ ┌────────────┐ ┌──────────────────────────┐│
│  │ APIs REST  │ │DataServices│ │  APIs nuevas             ││
│  │ existentes │ │   (DSS)    │ │  (orquestaciones migradas││
│  │            │ │            │ │   desde PHP controllers) ││
│  └─────┬──────┘ └─────┬──────┘ └───────────┬──────────────┘│
└────────┼──────────────┼────────────────────┼────────────────┘
         │              │                    │
         ▼              ▼                    ▼
┌─────────────────────────────────────────────────────────────┐
│                  TRAZALOG BACKEND                            │
│                                                             │
│  ┌────────────────┐  ┌───────────────┐  ┌────────────────┐ │
│  │  CodeIgniter   │  │    Bonita     │  │  Base de Datos │ │
│  │  (Asset Planner│  │    (BPM /     │  │  Oracle /      │ │
│  │   legacy)      │  │    Procesos)  │  │  PostgreSQL    │ │
│  └────────────────┘  └───────────────┘  └────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Decisión Arquitectónica: Maximizar WSO2, Minimizar Python

**Decisión:** El 80-90% de las herramientas MCP se implementan como **Virtual MCP Servers** generados automáticamente por WSO2 desde las APIs REST existentes (o nuevas). Python MCP Servers se reservan exclusivamente para capacidades que WSO2 no puede replicar.

**Fundamento:**

1. **WSO2 ya es parte del stack.** El equipo tiene expertise, infraestructura desplegada, y operaciones probadas. Agregar Python al runtime implica un segundo stack de deployment, debugging y mantenimiento.

2. **Migración del PHP.** Las orquestaciones que hoy viven en controllers PHP deben migrar a APIs WSO2 (REST APIs o secuencias de mediación). Esto mata dos pájaros: expone la lógica como MCP tools vía el gateway Y avanza el desacople del monolito PHP. Hacerlo en Python no ayuda con la migración.

3. **Conversión automática OpenAPI → MCP es casi gratuita.** Si la lógica ya está en una API WSO2, el MCP Gateway la expone como tool sin código adicional.

4. **Equipo chico.** Cada tecnología adicional tiene un costo de mantenimiento que no escala linealmente con el tamaño del equipo.

**Regla de decisión para cada operación:**

| Si la operación... | Entonces... |
|---|---|
| Es un mapeo 1:1 con un endpoint REST existente | Virtual MCP Server (zero code) |
| Necesita orquestación de múltiples APIs | Crear API de orquestación en WSO2, luego virtualizar |
| Hoy vive en un controller PHP | Migrar a API WSO2, luego virtualizar |
| No tiene API expuesta (solo SQL/CodeIgniter) | Crear DataService o API en WSO2, luego virtualizar |
| Requiere IA/ML, procesamiento de PDFs/Excel, o RAG | Python MCP Server (Fase 2+) |

### 3.3 Criterios Exclusivos para Python MCP Server

Python se justifica **únicamente** cuando la operación requiere capacidades que WSO2 mediations no pueden replicar:

1. **Procesamiento de IA/ML embebido en la tool call.** Ejemplo: un tool que recibe "¿qué repuestos debería pedir para el próximo mes?" y ejecuta un modelo predictivo sobre el historial de consumo.

2. **Transformación de datos no-estructurados.** Parsear PDFs de remitos, extraer tablas de planillas Excel, procesar imágenes de partes de trabajo. Python con pandas, pdfplumber, openpyxl.

3. **Lógica de prompt engineering o context assembly compleja (RAG).** Ensamblar contexto de múltiples fuentes para que un LLM lo procese, implementar retrieval augmented generation.

**Tecnología elegida:** FastMCP (framework estándar, 70% del ecosistema MCP, incorporado al SDK oficial de Python para MCP).

**Transporte recomendado para producción:** Streamable HTTP con `stateless_http=True` y `json_response=True`.

---

## 4. WSO2 MCP Gateway — Capacidades Detalladas

### 4.1 Funcionalidades del Gateway

El WSO2 MCP Gateway (disponible desde API Manager 4.6.0, noviembre 2025) ofrece:

**Virtualización de APIs existentes:**
- Convierte cualquier REST API en un Virtual MCP Server derivando tool definitions automáticamente desde especificaciones OpenAPI.
- No requiere código nuevo — configuración desde la consola.

**Proxy de MCP Servers externos:**
- Envuelve MCP servers externos (ej: Python/FastMCP) bajo la misma gobernanza.
- Aplica las mismas políticas de seguridad, rate limiting y monetización.

**Seguridad OAuth 2.1 completa:**
- OAuth2 scopes granulares por tool.
- Resource indicators (RFC 8707).
- Validación de tokens con audience binding y PKCE.
- Soporte para delegated identity (el agente actúa "en nombre de" un usuario verificado).

**Rate limiting por herramienta:**
- Límites de ejecución y cuotas de uso por tool call individual.
- Previene loops infinitos de agentes autónomos.
- Protege backends de invocaciones de alta frecuencia.

**Control de acceso avanzado:**
- IP filtering, RBAC, integración con OPA (Open Policy Agent).
- Restricción por hora del día, origen geográfico, o "persona del agente".

### 4.2 MCP Hub (Catálogo)

El MCP Hub es un portal dedicado donde desarrolladores de agentes IA descubren, exploran y consumen las herramientas MCP publicadas:

- Catálogo searchable por tool, capacidad, dominio o server.
- Documentación estandarizada con schemas de input/output.
- Configuraciones copy-ready para VS Code Copilot, Claude Desktop, etc.
- Gestión del ciclo de vida completo: creación → testing (MCP Playground) → publicación → versionado.

### 4.3 Observabilidad

- Analytics de uso nativas de WSO2 API Manager (por tool, por agente, por cliente).
- Tracking de patrones de tráfico MCP desde el gateway.
- Logs y métricas vía OpenTelemetry (gratuito, estándar abierto).
- Dashboards custom construidos sobre la base de datos de analytics de WSO2.

**Nota:** WSO2 API Manager incluye analytics integradas sin requerir componentes externos pagos.

---

## 5. Monetización de MCP — Estrategia Costo $0

### 5.1 Restricción Estratégica

**Premisa:** Costo $0 en licencias y servicios externos hasta 2027, cuando la facturación real comience con la masa crítica de proveedores mineros. Toda la infraestructura de monetización debe construirse con herramientas gratuitas o ya disponibles en el stack.

### 5.2 Mecanismos de Cobro Disponibles sin Costo

**WSO2 API Manager (open source) ya incluye:**
- **Rate limiting y cuotas:** Tiers de suscripción con cuotas de requests por período (Bronze, Silver, Gold). Se configuran desde la consola, sin código.
- **Analytics nativas:** Conteo de API calls por suscriptor, por API, por período. Los datos se almacenan en la base de datos interna de WSO2.
- **Developer Portal:** Portal de autoservicio donde el suscriptor ve su aplicación, se suscribe a APIs, ve su tier activo y puede obtener tokens OAuth.
- **Suscripciones:** Mecanismo nativo para que un consumidor se suscriba a una API con un tier específico. El sistema controla automáticamente que no exceda la cuota.

**Lo que NO incluye gratis:**
- ❌ Billing automatizado (generar factura y cobrar)
- ❌ Dashboards de consumo embebibles en portal de cliente
- ❌ Integración directa con procesadores de pago

### 5.3 Arquitectura de Monetización Costo $0

**Fase 1 (2026-2027) — Cobro manual asistido por datos:**

```
MCP Client → WSO2 MCP Gateway → Analytics nativas WSO2
                                        │
                                        ▼
                                 BD de analytics
                                 (PostgreSQL/Oracle)
                                        │
                                        ▼
                              Script/cron de reporte
                              (genera resumen mensual
                               de consumo por cliente)
                                        │
                                        ▼
                              Facturación manual o
                              semi-automática
                              (MercadoPago / transferencia)
```

Cómo funciona:
1. WSO2 registra cada tool call con metadatos: cliente, herramienta, timestamp, status.
2. Un script (Python o SQL) consulta la BD de analytics de WSO2 y genera un reporte mensual por cliente: calls totales, desglose por herramienta, tier contratado, excedentes.
3. El socio comercial usa ese reporte para facturar manualmente (factura electrónica AFIP + cobro por MercadoPago o transferencia bancaria).
4. El cliente puede ver su consumo en una sección del portal de Trazalog (dashboard simple que lee la misma BD).

**Fase 2 (2027+) — Billing semi-automatizado:**

Cuando el volumen de clientes MCP justifique automatizar:
- Evaluar Moesif (plan pago) para billing automatizado, O
- Desarrollar integración custom WSO2 → Stripe/MercadoPago para facturación automática.
- La interfaz extensible de monetización de WSO2 permite implementar cualquier billing engine custom.

### 5.4 Portal de Cliente para Visibilidad de Costos

**Con costo $0, usando lo que ya existe:**

1. **WSO2 Developer Portal** como portal de suscripción: el cliente se registra, se suscribe a las APIs/MCP tools, y ve su tier y tokens activos. Esto es out-of-the-box.

2. **Dashboard de consumo en Trazalog:** Una página en el portal web de Trazalog (PHP/CodeIgniter) que consulta la BD de analytics de WSO2 y muestra al cliente:
   - Calls consumidas en el período
   - Cuota restante según su tier
   - Desglose por tipo de operación
   - Proyección de consumo al ritmo actual
   
   Esto es desarrollo propio (esfuerzo bajo — es un query a la BD + una página con gráficos).

3. **Reportes descargables:** El mismo script que genera reportes para facturación puede generar un PDF/CSV para que el cliente descargue su historial de consumo.

### 5.5 Modelo de Tiers Propuesto

| Tier | Precio | Incluye | Rate Limit | Cómo se implementa |
|---|---|---|---|---|
| **Free / Discovery** | $0 | Tools de solo lectura | 100 calls/día | Tier de suscripción en WSO2 (built-in) |
| **Professional** | $/mes por empresa | Lectura + escritura | 5.000 calls/día | Tier de suscripción en WSO2 + factura manual |
| **Enterprise** | Custom | Todos los tools + SLA | Ilimitado | Tier de suscripción en WSO2 + factura manual |
| **API/Partner** | Pay-as-you-go | Acceso programático | Por call | Tier de suscripción en WSO2 + factura por consumo |

### 5.6 Procesador de Pagos

**Para el mercado argentino (MVP):**
- **MercadoPago:** Opera nativamente en Argentina, sin necesidad de entidad legal en otro país. Comisiones ~4-5% + IVA. Cobro mediante link de pago o integración API.
- **Transferencia bancaria / CBU/CVU:** Para clientes que prefieran pagar por transferencia (común en B2B argentino).
- **Factura electrónica AFIP:** Obligatoria, se emite con el sistema habitual.

**Para clientes internacionales (futuro):**
- Stripe (requiere entidad en país soportado) o dLocal (opera desde LATAM).
- Se evalúa cuando haya demanda real de clientes fuera de Argentina.

### 5.7 Decisiones de Monetización Registradas

**MDR-001: No se contratan servicios pagos de billing hasta 2027**
- **Decisión:** La monetización se implementa con WSO2 analytics nativas + facturación manual/semi-automática.
- **Razón:** Costo $0 es premisa estratégica. El volumen de clientes MCP en 2026 no justifica automatización completa.
- **Consecuencia:** Mayor trabajo manual del socio comercial para facturar, pero cero costo de licencias.

**MDR-002: MercadoPago como procesador primario**
- **Decisión:** Se usa MercadoPago para cobros en Argentina. Stripe se difiere hasta que haya clientes internacionales.
- **Razón:** Opera nativamente en Argentina, sin necesidad de entidad en USA.
- **Consecuencia:** Links de pago o integración API de MercadoPago con el portal de cliente.

---

## 6. Modelo de Identidad y Aislamiento Multi-Tenant

### 6.1 El Problema

Trazalog es una plataforma SaaS multi-tenant. Todos los datos de negocio (provistos por DataServices y queries) requieren que se especifique el identificador de empresa: `empr_id` en el módulo Tools, `id_empresa` en Asset Planner. Este identificador es el mecanismo que garantiza la confidencialidad y privacidad de los datos de cada cliente — sin él, un cliente podría ver datos de otro.

**Cómo funciona hoy (flujo web tradicional):**

```
1. Usuario ingresa user + password en la pantalla de login de Trazalog
2. El sistema autentica las credenciales
3. El sistema consulta los Memberships de Bonita del usuario
   (rol + group; Trazalog usa "group" para representar una empresa)
4. Se resuelve el empr_id correspondiente
5. El empr_id se guarda en la sesión PHP
6. Durante toda la sesión, las queries filtran por ese empr_id
```

**Por qué este modelo no se traslada directo a MCP:**

En una interacción MCP no existe pantalla de login ni pantalla de selección de empresa. El usuario conversa con un agente de IA (Claude u otro), y el agente invoca herramientas. No hay un "momento de login" dentro de la conversación, ni una sesión PHP donde persistir el `empr_id`.

Además, la especificación de seguridad de MCP es explícita en un punto crítico: el identificador de sesión del protocolo (`Mcp-Session-Id`) debe tratarse como entrada no confiable, y **la autorización nunca debe atarse a él**. Esto significa que el patrón actual de Trazalog —"guardar el empr_id en la sesión"— no es válido en el mundo MCP. La identidad y el tenant deben resolverse de forma verificable en *cada* request.

### 6.2 Cómo MCP Resuelve la Identidad

MCP no maneja credenciales propias. Sigue las convenciones de **OAuth 2.1**. Esto implica dos hechos fundamentales para el diseño de Trazalog:

**Hecho 1 — El usuario nunca entrega su contraseña al agente de IA.** Cuando el usuario agrega el connector de Trazalog en Claude, se dispara un flujo OAuth: Claude redirige el navegador del usuario a la pantalla de login de Trazalog (una pantalla propia de Trazalog, no de Claude), el usuario se autentica ahí, y Trazalog devuelve un token de acceso. Claude almacena ese token y lo envía en el header `Authorization: Bearer` de cada tool call.

**Hecho 2 — El tenant viaja en el token, no en una sesión.** El `empr_id` se resuelve una sola vez, durante el flujo OAuth de alta del connector, y se "hornea" dentro del token de acceso como un claim del JWT (por ejemplo, `"empr_id": "1234"`). Cada tool call transporta ese token; el gateway lo valida criptográficamente y extrae el `empr_id` del claim. No hay estado de sesión que mantener: el token es autocontenido.

### 6.3 Flujo de Identidad Diseñado para Trazalog v3 (MVP)

```
┌─────────────────────────────────────────────────────────────────┐
│  FASE 1 — ALTA DEL CONNECTOR (una sola vez por usuario)          │
└─────────────────────────────────────────────────────────────────┘

   Usuario en Claude
        │  "Agregar connector Trazalog"
        ▼
   Claude redirige el navegador → Pantalla de login de Trazalog
        │
        ▼
   Usuario ingresa user + password EN TRAZALOG
   (nunca en Claude — Claude no ve las credenciales)
        │
        ▼
   Trazalog autentica + consulta Memberships de Bonita
        │
        ▼
   Se resuelve el empr_id
   (MVP: se asume UNA empresa por usuario — ver 6.4)
        │
        ▼
   Se emite un token OAuth que CONTIENE el empr_id como claim
        │
        ▼
   Claude almacena el token asociado al connector

┌─────────────────────────────────────────────────────────────────┐
│  FASE 2 — USO (en cada tool call)                                │
└─────────────────────────────────────────────────────────────────┘

   Usuario → "Mostrame las órdenes de trabajo atrasadas"
        │
        ▼
   Claude invoca la tool → envía el token en Authorization: Bearer
        │
        ▼
   WSO2 MCP Gateway valida el token y extrae el claim empr_id
        │
        ▼
   WSO2 inyecta el empr_id en la llamada al DataService / API
        │
        ▼
   El DataService filtra por empr_id → devuelve SOLO datos
   de la empresa correspondiente
```

El principio rector: **el `empr_id` se resuelve una vez (en el login OAuth) y queda dentro del token. Cada request lo transporta de forma verificable. El backend no cambia — sigue recibiendo el `empr_id` como siempre; solo cambia su origen: antes la sesión PHP, ahora el claim del token validado por WSO2.**

### 6.4 Decisiones Arquitectónicas Tomadas

**TAD-IDENT-01: El `empr_id` viaja como claim del token OAuth, nunca como estado de sesión ni como parámetro de tool**

- **Decisión:** El identificador de empresa se incluye como claim dentro del token de acceso OAuth. Se resuelve durante el flujo de autorización y se valida en cada request. No se mantiene en sesión, y nunca se expone como parámetro que el agente de IA pueda completar.
- **Justificación:** (a) La spec de seguridad de MCP prohíbe atar autorización al identificador de sesión. (b) Si el `empr_id` fuera un parámetro de tool, el LLM podría pasar un valor incorrecto —por error o por prompt injection— y acceder a datos de otra empresa. El tenant jamás debe ser decidido por el modelo. (c) Un token firmado criptográficamente es inviolable: el usuario no puede alterar su propio `empr_id`.
- **Consecuencia:** El backend (DataServices, queries) no cambia. El trabajo se concentra en la capa de emisión y validación de tokens.

**TAD-IDENT-02: MVP asume una sola empresa por usuario, pero el diseño no impide el caso multi-empresa**

- **Decisión:** Para el MVP se asume que cada usuario pertenece a una única empresa. No se construye la pantalla de selección de empresa. Sin embargo, el `empr_id` se modela como un claim explícito del token (no como un valor hardcodeado ni implícito).
- **Justificación:** Hasta la fecha no ha habido clientes con usuarios multi-empresa, por lo que construir la selección de empresa sería sobre-ingeniería para el MVP. Modelar el `empr_id` como claim explícito mantiene la puerta abierta: el día que aparezca un cliente multi-empresa, solo se agrega la pantalla de selección en el flujo OAuth, sin rediseñar el modelo de tokens ni el backend.
- **Consecuencia:** Si durante el flujo OAuth se detecta que un usuario tiene más de un Membership de empresa en Bonita, el comportamiento para el MVP debe definirse explícitamente (ver decisión pendiente TAD-IDENT-P02).

**TAD-IDENT-03: El aislamiento multi-tenant se enforza en el WSO2 MCP Gateway**

- **Decisión:** La validación del token y la extracción/inyección del `empr_id` ocurren en el WSO2 MCP Gateway, antes de que el request llegue al backend.
- **Justificación:** Centralizar el enforcement de seguridad en el gateway evita que cada DataService o API reimplemente la lógica de aislamiento. Es coherente con el rol del gateway definido en la Sección 4 y con la decisión ADR-001 (gateway como único punto de entrada MCP). Reduce la superficie de error: un solo lugar que validar y auditar.
- **Consecuencia:** El gateway debe ser capaz de leer el claim `empr_id` del JWT e inyectarlo como header o parámetro en la llamada downstream. Esta es una capacidad estándar de mediación de WSO2.

**TAD-IDENT-04: El usuario se autentica contra Trazalog, no contra Claude ni contra WSO2 directamente**

- **Decisión:** La autenticación de credenciales (user + password) se realiza siempre contra el sistema de Trazalog, mediante una pantalla de login propia de Trazalog dentro del flujo OAuth.
- **Justificación:** (a) Preserva la fuente de verdad de identidad existente. (b) El agente de IA nunca ve ni almacena credenciales — solo recibe un token. (c) Permite reutilizar el mecanismo de login actual en lugar de migrar la base de usuarios a otro sistema.
- **Consecuencia:** Trazalog debe exponer una pantalla de login compatible con el flujo OAuth (authorization code + PKCE). El grado de reutilización del login actual depende de la investigación de código pendiente (ver TAD-IDENT-P01).

### 6.5 Decisiones Arquitectónicas Pendientes

Las siguientes decisiones requieren información que solo puede obtenerse investigando el código actual del sistema. Quedan explícitamente abiertas y deben resolverse durante el Sprint 2, antes de implementar la capa de identidad.

**TAD-IDENT-P01: ¿Quién actúa como Authorization Server — WSO2 o el sistema Trazalog actual?**

- **La cuestión:** Hay dos roles a ubicar. Rol A: autenticar al usuario y resolver el `empr_id` consultando Bonita. Rol B: emitir y validar los tokens OAuth. Hoy todo lo hace el stack PHP/Bonita. Hay dos caminos:
  - **Opción 3.1 — WSO2 como Authorization Server completo:** WSO2 maneja login, emisión y validación de tokens, usando su Key Manager nativo, conectado a la base de usuarios de Trazalog y a Bonita.
  - **Opción 3.2 — Trazalog mantiene el login, WSO2 valida:** Se reutiliza la pantalla de login actual de Trazalog. El PHP autentica y resuelve el `empr_id` desde Bonita; el token se emite con el `empr_id` ya resuelto; WSO2 solo valida el token en el gateway.
- **Recomendación preliminar del arquitecto:** La Opción 3.2 es probablemente la más sensata para un MVP de bajo costo y bajo riesgo, porque reutiliza un login que ya funciona y ya está integrado con Bonita, en vez de reescribirlo dentro de WSO2. Sin embargo, esta recomendación NO está confirmada.
- **Qué falta para decidir:** Investigación del código actual del login. Específicamente: cómo está implementado el login, qué tan acoplado está a Bonita, y si el stack PHP puede participar de un flujo OAuth 2.1 (authorization code + PKCE) sin una reescritura mayor. Si el login actual es muy difícil de adaptar a OAuth, la balanza podría inclinarse hacia 3.1.
- **Cómo resolverlo:** Mediante la investigación de código descrita en 6.6. La decisión debe cerrarse al inicio del Sprint 2.

**TAD-IDENT-P02: Comportamiento ante un usuario con múltiples empresas en el MVP**

- **La cuestión:** El MVP asume una empresa por usuario (TAD-IDENT-02), pero el sistema podría encontrarse con un usuario que tenga más de un Membership de empresa en Bonita. ¿Qué hace el flujo OAuth en ese caso?
- **Opciones:** (a) Rechazar el login con un mensaje claro. (b) Tomar la primera empresa por algún criterio determinístico documentado. (c) Adelantar la pantalla de selección de empresa.
- **Qué falta para decidir:** Confirmar, mediante la investigación de código y/o datos, si existen hoy usuarios con múltiples Memberships de empresa. Si no existen, la opción (a) —rechazar con mensaje— es la más segura y barata para el MVP. Si existen, hay que evaluar (c).
- **Cómo resolverlo:** Parte de la investigación de código (punto 2 de 6.6) y consulta a datos de producción.

**TAD-IDENT-P03: Mecanismo de consulta de Memberships de Bonita durante la emisión del token**

- **La cuestión:** En el momento del login OAuth, el Authorization Server (sea WSO2 o Trazalog) necesita resolver el `empr_id` consultando los Memberships de Bonita del usuario. ¿Existe ya una API que exponga esto?
- **Qué falta para decidir:** Confirmar si existe una API/función que, dado un usuario, devuelva sus Memberships de Bonita (empresas/groups y roles). Según el conocimiento actual del equipo, esta capacidad ya existiría, pero debe verificarse su contrato exacto (endpoint, input, output) y su forma de comunicación con Bonita (REST API de Bonita, librería, o BD).
- **Impacto:** Si la API existe y es adecuada, el esfuerzo es bajo. Si no existe o es inadecuada, hay que crearla, lo que agranda el alcance del Sprint 2.
- **Cómo resolverlo:** Parte de la investigación de código (punto 2 de 6.6).

**TAD-IDENT-P04: Auditoría de consistencia del filtrado por `empr_id` en los DataServices**

- **La cuestión:** El modelo de aislamiento asume que todos los DataServices y queries filtran correctamente por `empr_id` / `id_empresa`. Si existiera algún DataService que no filtra, o que lo hace de forma inconsistente, sería una vía de fuga de datos entre empresas al exponerlo como tool MCP.
- **Qué falta para decidir:** Auditar una muestra representativa de DataServices y queries para confirmar que el filtrado por empresa es consistente. Identificar excepciones.
- **Impacto:** Cualquier DataService que se exponga como tool MCP y no filtre por empresa es un riesgo de seguridad crítico. Esto puede requerir historias correctivas en el Sprint 2 o posteriores.
- **Cómo resolverlo:** Parte de la investigación de código (punto 3 de 6.6).

### 6.6 Investigación de Código Requerida (Insumo para Sprint 2)

Para cerrar las decisiones pendientes, se requiere una investigación del código actual del sistema. El alcance de esa investigación es:

1. **Flujo de login y resolución de empresa:** Identificar los controllers de login, cómo se autentican las credenciales, cómo se resuelve el `empr_id` / `id_empresa` tras el login, dónde se consultan los Memberships de Bonita, y en qué variable de sesión se persiste el `empr_id`.

2. **Integración con Bonita:** Determinar si existe una API/función que devuelva los Memberships de Bonita de un usuario (con su contrato exacto: endpoint, input, output), cómo se comunica el sistema con Bonita (REST API de Bonita, librería, o BD directa), y si la consulta pega a Bonita en vivo o a una tabla local sincronizada.

3. **Uso del `empr_id` en el acceso a datos:** Revisar una muestra de 3-5 DataServices o queries representativos para confirmar cómo reciben el `empr_id`, si el filtrado por empresa es consistente en todos, y si Asset Planner maneja `id_empresa` igual que Tools maneja `empr_id`.

4. **OAuth / tokens actuales:** Determinar si el sistema ya emite algún tipo de token (JWT, API key, OAuth), si WSO2 ya valida tokens para alguna API existente, y si hay algún Key Manager de WSO2 ya configurado.

El entregable esperado de esa investigación es un documento en la carpeta `doc/` del repositorio con: (a) el diagrama del flujo de login actual, (b) la respuesta sobre la existencia y el contrato de la API de Memberships, (c) la conclusión sobre la viabilidad de reutilizar el login actual en un flujo OAuth, y (d) la lista de riesgos o inconsistencias detectadas (especialmente DataServices que no filtren por empresa).

### 6.7 Implicaciones para el Sprint 2

Esta sección debe traducirse en historias del Sprint 2. El trabajo se descompone naturalmente en:

- **Investigación previa (bloqueante):** La investigación de código de 6.6 debe ejecutarse primero, ya que TAD-IDENT-P01, P02, P03 y P04 dependen de sus resultados.
- **Capa de emisión de token:** Implementar el flujo OAuth que autentica al usuario, resuelve el `empr_id` desde Bonita, y emite un token con el `empr_id` como claim. La forma exacta depende de la resolución de TAD-IDENT-P01.
- **Capa de validación e inyección en el gateway:** Configurar el WSO2 MCP Gateway para validar el token y extraer/inyectar el `empr_id` en las llamadas downstream.
- **Historias correctivas (condicional):** Si la auditoría de TAD-IDENT-P04 detecta DataServices que no filtran por empresa, se requieren historias para corregirlos antes de exponerlos como tools MCP.

Las decisiones tomadas (6.4) son firmes y deben respetarse en la planificación. Las decisiones pendientes (6.5) deben cerrarse al inicio del Sprint 2, con la investigación de código como insumo, y NO deben asumirse resueltas en una dirección particular antes de esa investigación.

---

## 7. Gestión de APIs: Estado Actual y Brechas

### 7.1 Estado Actual de APIs Expuestas

| Componente | APIs WSO2 Existentes | Orquestación en PHP | Solo CodeIgniter/SQL |
|---|---|---|---|
| Asset Planner | Parcial | Sí (controllers) | Sí (modelos CI) |
| Almacenes | Parcial | Sí | Sí |
| Procesos (BPM) | Vía Bonita | — | — |
| Producción | Por definir | Por definir | Por definir |
| Residuos | Por definir | Por definir | Por definir |
| Cross-componente (ej: crear usuario) | ✅ (orquestada en WSO2) | — | — |

### 7.2 Trabajo Necesario para Habilitar MCP

**Paso 1: Inventariar APIs existentes en WSO2**
- Listar todas las APIs REST y DataServices actualmente expuestas.
- Verificar que tengan especificaciones OpenAPI actualizadas.
- Resultado: catálogo de tools que se pueden virtualizar "as-is".

**Paso 2: Identificar operaciones en controllers PHP que deben migrar**
- Mapear las orquestaciones de controllers PHP.
- Crear APIs de orquestación equivalentes en WSO2 (secuencias de mediación).
- Beneficio dual: habilita MCP + desacopla monolito PHP.

**Paso 3: Exponer lógica de CodeIgniter como APIs**
- Identificar operaciones en modelos CodeIgniter que no tienen API.
- Crear DataServices o REST APIs en WSO2 para exponerlas.
- Priorizar por demanda de las herramientas MCP planificadas.

**Paso 4: Virtualizar en MCP Gateway**
- Tomar las APIs resultantes y generar Virtual MCP Servers desde OpenAPI specs.
- Enriquecer con descripciones semánticas para que los LLMs las usen correctamente.
- Publicar en MCP Hub.

---

## 8. Plan de Evolución por Fases

### Fase 1 — MVP MCP (Prioridad actual)

**Objetivo:** Exponer capacidades existentes de Trazalog como MCP tools, sin Python, sin nueva tecnología.

- Virtualizar APIs REST existentes como MCP Servers vía WSO2 MCP Gateway.
- Crear APIs nuevas en WSO2 para operaciones que hoy están en PHP o no expuestas.
- Configurar seguridad OAuth 2.1, rate limiting básico.
- Publicar en MCP Hub con documentación.
- Habilitar tier Free/Discovery para validación con primer cliente minero.

**Resultado:** Trazalog consumible desde Claude, ChatGPT, Copilot, etc. Zero Python.

### Fase 2 — IA y Monetización

**Objetivo:** Agregar inteligencia y comenzar a cobrar.

- Implementar UN Python MCP Server (FastMCP) para tools de inteligencia:
  - Predicción de consumo de repuestos.
  - Detección de anomalías en indicadores de mantenimiento.
  - Procesamiento de documentos (remitos, partes de trabajo).
- Proxear Python server detrás del WSO2 MCP Gateway (misma gobernanza).
- Activar monetización con Moesif + Stripe.
- Implementar tiers Professional y Enterprise.

### Fase 3 — Escala y Ecosistema

**Objetivo:** Expandir capacidades y abrir a partners.

- Separar Python servers por dominio si el volumen lo justifica.
- Habilitar tier API/Partner para integradores.
- Explorar A2A (Agent-to-Agent protocol) cuando WSO2 lo soporte.
- Unificación de arquitectura dual de almacenes (Asset Planner ALM vs traz-comp-almacenes).
- Evolución de modelo de pricing.

---

## 9. Costos e Infraestructura — Estrategia Costo $0

### 9.1 Premisa

La estrategia de negocio establece que no se deben incurrir costos de licencias ni servicios pagos nuevos hasta 2027, cuando la facturación real comience con la masa crítica de proveedores mineros. Toda la arquitectura MCP debe funcionar con software open source instalado en la infraestructura existente de Google Cloud.

### 9.2 Análisis por Componente

| Componente | Licencia | Versión | Costo | Dónde corre | Nota |
|---|---|---|---|---|---|
| **WSO2 API Manager 4.6.0** | Apache 2.0 (open source) | Self-hosted desde GitHub | **$0** | VM existente o nueva en GCP | Incluye MCP Gateway, MCP Hub, Developer Portal, rate limiting, analytics nativas. WSO2 confirma: "no separate premium version, all features available in open source" |
| **Python + FastMCP** | MIT (open source) | PyPI | **$0** | VM existente | Solo en Fase 2+. Liviano, puede correr en cualquier VM con Python 3.10+ |
| **WSO2 API Manager (ya existente)** | Ya desplegado | Ya en stack | **$0** | VMs actuales | APIs REST, DataServices, orquestación ya operativas |
| **Bonita BPM** | Community (open source) | Ya en stack | **$0** | VMs actuales | Ya operativo para módulo Procesos/PRO |
| **CodeIgniter** | MIT (open source) | Ya en stack | **$0** | VMs actuales | Backend Asset Planner |
| **PostgreSQL / Oracle** | OSS / ya licenciado | Ya en stack | **$0** | VMs actuales | Persistencia |
| **OpenTelemetry** | Apache 2.0 (open source) | Collector gratuito | **$0** | VM existente | Observabilidad y tracing distribuido |
| **MercadoPago** | — | API / links de pago | **Solo comisión por transacción (~4-5%)** | SaaS | Solo cuando se empiece a cobrar. Sin costo fijo |
| **Moesif** | — | — | **NO SE CONTRATA (Fase 1)** | — | Se evalúa en Fase 2+ si los ingresos lo justifican |
| **Stripe** | — | — | **NO SE CONTRATA (Fase 1)** | — | Requiere entidad en país soportado. Se difiere |

### 9.3 Infraestructura en Google Cloud

**Estado actual:** Toda la plataforma funciona sobre Google Cloud en VMs con CentOS 7.

**Para el MCP Gateway (WSO2 4.6.0):**
- **Opción A — Cohabitar en VM existente:** Si la VM actual de WSO2 API Manager tiene recursos disponibles, WSO2 4.6.0 puede instalarse como upgrade del API Manager existente. El MCP Gateway es parte del mismo producto. **Costo: $0 adicional.**
- **Opción B — VM nueva mínima:** Si se necesita aislar, una e2-small (2 vCPU, 2 GB RAM) en GCP cuesta ~$15/mes. WSO2 recomienda 2-4 GB RAM mínimo.

**⚠️ CentOS 7 — Riesgo crítico para WSO2 4.6.0:** CentOS 7 llegó a End of Life en junio 2024 y no soporta JDK 21 (requerido por WSO2 4.6.0) debido a incompatibilidades de glibc. Esto convierte la migración de OS en un **prerequisito ineludible** para v3, no solo en una recomendación. El plan de migración detallado está en la **Sección 10 — Arquitectura de Infraestructura**.

### 9.4 Resumen de Inversión

| Concepto | Costo Fase 1 (2026-2027) | Costo Fase 2 (2027+) |
|---|---|---|
| Licencias de software | $0 | $0 (todo open source) |
| Servicios SaaS (Moesif, Stripe) | $0 (no se contratan) | Se evalúa según ingresos |
| Infraestructura incremental | $0-15/mes (si se necesita VM nueva) | ~$10-15/mes adicional para Python server |
| Procesador de pagos | $0 (no hay cobros aún) | Solo comisión por transacción (MercadoPago) |
| **TOTAL** | **$0-15/mes** | **Variable según ingresos** |

### 9.5 Camino de Evolución de Costos

```
2026 (MVP)                    2027 (Validación)              2027+ (Escala)
─────────────                 ─────────────                  ─────────────
Costo: $0                     Costo: ~$15/mes                Costo: variable
                              (VM para Python MCP)

• WSO2 open source            • Primeros cobros              • Evaluar Moesif
• MCP Gateway incluido          con MercadoPago              • Evaluar Stripe
• Analytics nativas           • Facturación manual           • Automatizar billing
• Sin billing externo         • Dashboard de consumo         • Escalar infra
• Validar con 1er cliente       en portal Trazalog           • Separar Python
  minero (gratis/piloto)      • Script de reportes             servers por dominio
```

---

## 10. Arquitectura de Infraestructura

### 10.1 Estado Actual del Entorno

**Ambiente de Desarrollo (DEV):**
- **Workstation del developer:** Ubuntu 24.04.1 LTS (estación local de Rodolfo).
- **Base de datos de desarrollo:** VM accesible vía OpenVPN de Trazalog.
- **Conectividad:** OpenVPN para acceso seguro desde la workstation a las bases de datos.

**Ambiente de Test (TEST):**
- **OS:** CentOS Linux 7 (Core) — `VERSION_ID="7"`
- **Estado:** End of Life desde junio 2024. Sin parches de seguridad oficiales.

**Ambiente de Producción (PROD):**
- **OS:** CentOS Linux 7 (Core) — mismo que TEST
- **Estado:** End of Life. Riesgo de seguridad creciente.

**VM de WSO2 (compartida o dedicada — actualmente `vm-pruebas-wso2`):**
- Path base: `/trazaSystems/`
- Componentes instalados:
  - `wso2am-4.1.0` — API Manager (versión actual, lanzada en abril 2022)
  - `wso2mi-4.1.0` — Micro Integrator
  - `wso2mi-dashboard-4.1.0` — Dashboard del MI
  - `wso2si-4.1.0` — Streaming Integrator
- Path de configuración SSL, scripts y medios

**VM de Backend Aplicativo:**
- **PostgreSQL 11** — Base de datos principal
- **PHP 5.6 + CodeIgniter** — Backend legacy de Asset Planner
- **Bonita BPM 7** — Motor de workflows del módulo Procesos

### 10.2 Diagnóstico de Compatibilidad

Esta es la decisión más importante de toda la sección de infraestructura, y conviene encararla con datos crudos.

**WSO2 4.6.0 — Requerimientos:**
- **JDK obligatorio:** Java 21 (Temurin OpenJDK 11, 17, y 21 también soportados)
- **Sistemas operativos testeados:** Ubuntu 18.04/20.04/22.04, CentOS 7.4/7.5, RHEL 7.0/8.x/9.x, Rocky Linux 8.7/9.3
- **RAM mínima:** 4 GB (2 GB para JVM + 2 GB para OS)
- **CPU:** 2 cores mínimo, 4 cores recomendado para alta concurrencia
- **Disco:** 10 GB libre

**El problema con CentOS 7:**

CentOS 7 viene con `glibc 2.17`. Las builds modernas de OpenJDK tienen requerimientos de glibc más nuevos:

| Build de OpenJDK | glibc requerido | Funciona en CentOS 7 (glibc 2.17)? |
|---|---|---|
| Temurin OpenJDK 21 | glibc 2.14+ pero binarios linkean contra glibc 2.27+ | ❌ NO |
| Red Hat OpenJDK 11 portable | glibc 2.27 | ❌ NO |
| Red Hat OpenJDK 21 (RPM oficial) | Solo RHEL 8/9 | ❌ NO |
| Oracle/Zulu/Amazon Corretto JDK 21 | Variable por vendor — algunas funcionan | ⚠️ Con esfuerzo |

Aunque la documentación oficial de WSO2 lista CentOS 7.4/7.5 como "tested", esto se refiere a versiones anteriores de WSO2 (que usaban JDK 8/11 con builds compatibles). Para WSO2 4.6.0 con su requisito de JDK 21, **CentOS 7 no es viable en la práctica** para una instalación productiva.

**Conclusión:** La migración del SO de TEST y PROD es prerequisito ineludible para v3.

### 10.3 Estrategia de Migración del Sistema Operativo

**Decisión:** Migrar TEST y PROD desde CentOS 7 a una distribución soportada antes del despliegue de v3.

**Opciones evaluadas (todas open source y gratuitas):**

| Distribución | Argumento a favor | Argumento en contra | Recomendación |
|---|---|---|---|
| **Rocky Linux 9** | Drop-in replacement de RHEL/CentOS. Mismo ecosistema yum/dnf. Curva de aprendizaje cero. | Comunidad más nueva que CentOS Stream. | ✅ **Recomendada** |
| **AlmaLinux 9** | Drop-in replacement de RHEL/CentOS. Backed por CloudLinux. Buena comunidad. | Equivalente a Rocky Linux. | ✅ Alternativa válida |
| **Ubuntu 22.04 LTS** | Soporte hasta 2027. Documentación abundante. Match con DEV (Ubuntu). | Cambio de paradigma (apt vs yum). Procedimientos operativos a reescribir. | ⚠️ Solo si hay razón estratégica |
| **CentOS Stream 9** | Misma familia, gratis. | Modelo de "rolling release pre-RHEL", menos predecible para producción. | ❌ No recomendada para PROD |

**Decisión:** Se recomienda **Rocky Linux 9** porque:
1. Es drop-in replacement de CentOS 7 — los scripts y procedimientos actuales funcionan con cambios mínimos.
2. Soporta JDK 21 nativo (paquete `java-21-openjdk` en repos oficiales).
3. Soporte activo hasta 2032.
4. Compatible 1:1 con RHEL 9, una distribución comercial probada.
5. Costo: **$0** (open source, Apache 2.0).

### 10.4 Plan de Migración Recomendado

```
Etapa 1 — Preparación (1-2 semanas)
─────────────────────────────────
□ Provisión VM nueva con Rocky Linux 9 en Google Cloud (TEST)
□ Instalar dependencias: JDK 21, PHP 8.2+, PostgreSQL 11+ client
□ Backup completo de configuraciones actuales
□ Documentar puntos de integración (puertos, conexiones, firewalls)

Etapa 2 — Migración TEST (2-3 semanas)
─────────────────────────────────────
□ Instalar WSO2 API Manager 4.6.0 en VM Rocky Linux 9
□ Migrar configuraciones desde wso2am-4.1.0 → wso2am-4.6.0
□ Importar APIs existentes (export/import nativo de WSO2)
□ Probar conectividad VPN, bases de datos, servicios backend
□ Validación funcional con los tests actuales del equipo

Etapa 3 — Validación (1 semana)
──────────────────────────────
□ Ejecutar suite de tests de regresión sobre TEST
□ Validar que las APIs existentes responden idénticamente
□ Verificar tiempos de respuesta y consumo de recursos
□ Si OK → proceder a PROD. Si falla → ajustar y revalidar

Etapa 4 — Migración PROD (Ventana de mantenimiento)
─────────────────────────────────────────────────
□ Provisión VM nueva con Rocky Linux 9 (PROD)
□ Instalar WSO2 4.6.0 con configuración de producción
□ Migración de datos (BD interna de WSO2, certificados, secretos)
□ DNS cutover / load balancer redirect
□ Monitoreo intensivo primeras 48hs
□ Plan de rollback: VM CentOS 7 queda apagada pero disponible 30 días
```

### 10.5 Topología de Infraestructura Propuesta

```
┌──────────────────────────────────────────────────────────────────┐
│                      GOOGLE CLOUD PLATFORM                       │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              AMBIENTE DE PRODUCCIÓN (PROD)                │   │
│  │                                                            │   │
│  │  ┌─────────────────────┐    ┌────────────────────────┐   │   │
│  │  │   VM: traz-wso2-    │    │   VM: traz-app-prod    │   │   │
│  │  │       prod          │    │   (sin cambios v3)     │   │   │
│  │  │   🆕 Rocky Linux 9  │    │   CentOS 7 (legacy)    │   │   │
│  │  │                     │    │                        │   │   │
│  │  │  • WSO2 APIM 4.6    │    │  • PHP 5.6/CodeIgniter │   │   │
│  │  │    (incluye MCP GW) │◄───┤  • Bonita BPM 7        │   │   │
│  │  │  • JDK 21           │    │  • Apache              │   │   │
│  │  │  • 8 GB RAM         │    │  • Solo accesible      │   │   │
│  │  │  • Expuesto         │    │    desde red interna   │   │   │
│  │  │    públicamente     │    │  • Migración a v4      │   │   │
│  │  └─────────────────────┘    └───────────┬────────────┘   │   │
│  │                                          │                │   │
│  │                          ┌───────────────▼────────────┐  │   │
│  │                          │   VM: traz-db-prod         │  │   │
│  │                          │   (sin cambios v3)         │  │   │
│  │                          │   • PostgreSQL 11          │  │   │
│  │                          │   • Backups automatizados  │  │   │
│  │                          └────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              AMBIENTE DE TEST (TEST)                      │   │
│  │                                                            │   │
│  │  ┌─────────────────────┐    ┌────────────────────────┐   │   │
│  │  │   VM: traz-wso2-    │    │   VM: traz-app-test    │   │   │
│  │  │       test          │    │   CentOS 7 (sin v3)    │   │   │
│  │  │   🆕 Rocky Linux 9  │    │   (mismo stack PHP)    │   │   │
│  │  │   WSO2 APIM 4.6     │    │   con datos de prueba  │   │   │
│  │  └─────────────────────┘    └────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              AMBIENTE DE DESARROLLO (DEV)                 │   │
│  │                                                            │   │
│  │  ┌────────────────────────┐                               │   │
│  │  │   VM: traz-db-dev      │                               │   │
│  │  │   • PostgreSQL          │                               │   │
│  │  │   • Acceso vía OpenVPN  │                               │   │
│  │  └─────────┬──────────────┘                               │   │
│  └────────────┼──────────────────────────────────────────────┘   │
└───────────────┼──────────────────────────────────────────────────┘
                │ OpenVPN (túnel cifrado)
                │
       ┌────────▼──────────┐
       │ Workstation DEV   │
       │ Ubuntu 24.04 LTS  │
       │                   │
       │ • WSO2 APIM 4.6   │ (instalación local para dev)
       │   (Docker/native) │
       │ • Cursor + Claude │
       │   Code            │
       │ • Git, Postman    │
       │ • Python+FastMCP  │ (para tests locales de MCP — Fase 2+)
       └───────────────────┘
```

**Nota sobre la topología:** Solo la VM de WSO2 cambia de OS en v3. La VM de aplicación (PHP + Bonita) y la VM de base de datos se mantienen en CentOS 7 con el stack actual. Esto reduce el alcance de la migración y aísla el riesgo a un único componente.

### 10.6 Sizing Recomendado por Ambiente

**En el scope de v3, solo cambia la VM de WSO2.** Las VMs de aplicación y base de datos mantienen su sizing actual.

| Ambiente | Componente | vCPU | RAM | Disco | Tipo GCP | Cambio en v3? |
|---|---|---|---|---|---|---|
| **PROD** | 🆕 WSO2 APIM 4.6 | 4 | 8 GB | 50 GB SSD | e2-standard-2 o n2-standard-2 | ✅ Nueva VM Rocky Linux 9 |
| **PROD** | App (PHP+Bonita) | (actual) | (actual) | (actual) | (actual) | ❌ Sin cambios |
| **PROD** | PostgreSQL | (actual) | (actual) | (actual) | (actual) | ❌ Sin cambios |
| **TEST** | 🆕 WSO2 APIM 4.6 | 2 | 4 GB | 30 GB | e2-medium | ✅ Nueva VM Rocky Linux 9 |
| **TEST** | App + BD | (actual) | (actual) | (actual) | (actual) | ❌ Sin cambios |
| **DEV** | BD remota | (actual) | (actual) | (actual) | (actual) | ❌ Sin cambios |

**Costo incremental aproximado mensual en Google Cloud (USD):**

| Concepto | Costo |
|---|---|
| 🆕 VM nueva WSO2 PROD (e2-standard-2) | ~USD 50/mes |
| 🆕 VM nueva WSO2 TEST (e2-medium) | ~USD 25/mes |
| VMs existentes (App, BD, DEV) | Sin cambio |
| **Costo incremental v3** | **~USD 75/mes** |

**Importante:** Durante la transición, la VM actual de WSO2 4.1.0 puede coexistir con la nueva VM de WSO2 4.6.0 hasta validar el cutover. Esto puede agregar temporalmente otros ~USD 75/mes durante 1-2 meses, después de los cuales la VM antigua se apaga. Esta inversión temporal funciona como seguro de rollback.

### 10.7 Estrategia de Conectividad y Seguridad

**OpenVPN se mantiene** como mecanismo de acceso a recursos privados (BD de DEV, consolas de administración). No hay razón para cambiarlo.

**Para acceso público a APIs/MCP del MCP Gateway:**
- Cloud Load Balancer con IP pública
- Certificado SSL (Let's Encrypt — gratuito) o Google Managed Certificate
- Firewall rules de GCP restringiendo puertos
- Solo se exponen los puertos del WSO2 Gateway (8243 HTTPS) y MCP endpoint
- Las consolas administrativas de WSO2 (9443) NO se exponen públicamente — solo accesibles vía VPN

**Backups:**
- Snapshots automáticos diarios de discos persistentes (incluido en GCP, $0 adicional)
- Retención: 7 días de snapshots, 4 semanas, 12 meses (rotación)
- Backups lógicos de PostgreSQL: dump diario al storage bucket

### 10.8 Cuándo Actualizar Cada Componente

```
┌─────────────────────────────────────────────────────────────┐
│            CRONOGRAMA DE ACTUALIZACIONES — v3                │
└─────────────────────────────────────────────────────────────┘

Q2 2026 (Abril-Junio) — PREPARACIÓN
├── Provisión Rocky Linux 9 en GCP (VM WSO2 TEST)
├── Instalación WSO2 APIM 4.6.0 en TEST
├── Migración de APIs vía apictl
└── Validación funcional contra App PHP existente

Q3 2026 (Julio-Septiembre) — MCP MVP
├── Cutover de WSO2 TEST a 4.6.0
├── PoC de MCP Gateway con APIs existentes
├── Definición de tools MCP para minería
└── Onboarding de primer cliente minero (validación gratuita)

Q4 2026 (Octubre-Diciembre) — PROD MIGRATION
├── Provisión nueva VM Rocky Linux 9 para WSO2 PROD
├── Migración de PROD a WSO2 4.6.0
├── Activación gradual del MCP Gateway en producción
├── VM antigua queda apagada como rollback (30 días)
└── Tier Free disponible para validación con clientes

Q1 2027 (Enero-Marzo) — MONETIZACIÓN
├── Activación de tiers pagos
├── Facturación con MercadoPago
└── Eventual evaluación de Python MCP Server (Fase 2)

POSTERGADO A v4 (2027+)
├── Migración PHP 5.6 → 8.2 LTS
├── Migración PostgreSQL 11 → 15
├── Migración de OS de VM de aplicación
└── Contenedorización con Docker/Kubernetes
```

### 10.9 Migraciones de Software Necesarias

Más allá del sistema operativo, hay otras migraciones técnicas a considerar:

**WSO2 API Manager: 4.1.0 → 4.6.0**
- Migración de APIs: usar herramienta `apictl` para export/import
- Migración de BD interna: ejecutar scripts SQL de upgrade provistos por WSO2
- Migración de configuración: `deployment.toml` cambia de formato entre versiones — migración manual asistida
- **Esfuerzo estimado:** 2-3 semanas
- **Riesgo:** Bajo si se valida bien en TEST primero

**PHP: 5.6 (diferido a v4)**
- PHP 5.6 está EOL desde 2019. Es un riesgo de seguridad conocido.
- **Decisión:** No se migra en v3. La VM de aplicación con PHP+CodeIgniter está aislada del MCP Gateway (que es lo único que se expone públicamente como nueva superficie). El stack de v3 que se actualiza es WSO2 (que sí necesita JDK 21 y por lo tanto Rocky Linux 9).
- **Razón:** Migrar PHP a la par que el OS y WSO2 introduce demasiados cambios simultáneos y riesgo innecesario. Se posterga a v4.
- **Mitigación temporal:** El acceso a la VM de aplicación queda restringido a la red interna y conexiones desde el WSO2 Gateway. No hay exposición pública directa.
- **Esfuerzo cuando se haga (v4):** 4-8 semanas, CodeIgniter 3 ajustado para PHP 8.2.

**PostgreSQL: 11 (diferido a v4)**
- PostgreSQL 11 tuvo EOL en noviembre 2023.
- **Decisión:** No se migra en v3. PostgreSQL 11 vive en una VM accedida solo desde la red interna y desde el WSO2 Gateway. La migración se planifica junto con la migración de PHP en v4.
- **Razón:** Reducir alcance de v3. PostgreSQL 11 sigue funcional aunque sin parches oficiales — el riesgo es manejable mientras la BD no esté expuesta públicamente.
- **Esfuerzo cuando se haga (v4):** 1 semana con `pg_upgrade`.

**Bonita BPM 7:**
- Bonita 7.x sigue siendo soportado. La versión actual 2024.x es compatible.
- Evaluar si conviene actualizar a la última 7.x menor disponible.
- **Esfuerzo estimado:** 2 semanas (si se decide actualizar).
- **Riesgo:** Bajo a medio según versión específica.

### 10.10 Decisiones de Infraestructura Registradas

**IDR-001: Migrar OS de TEST y PROD a Rocky Linux 9**
- **Decisión:** Reemplazar CentOS 7 con Rocky Linux 9 antes de desplegar WSO2 4.6.0.
- **Razón:** CentOS 7 está EOL y no soporta JDK 21 (requerido por WSO2 4.6.0).
- **Consecuencia:** Plan de migración de OS necesario. Costo: $0 en licencias, esfuerzo de provisión + cutover.

**IDR-002: Mantener arquitectura multi-VM (no contenedorizar aún)**
- **Decisión:** Continuar con VMs separadas para WSO2, App+Bonita, y PostgreSQL.
- **Razón:** El equipo no tiene operación productiva con Docker/Kubernetes. Cambiar OS y stack a la vez aumenta el riesgo. La contenedorización se evalúa para v4.
- **Consecuencia:** Más simple operacionalmente en 2026. Migración a contenedores diferida.

**IDR-003: WSO2 4.6.0 cohabita con APIs existentes en la misma VM**
- **Decisión:** Una VM única para WSO2 APIM 4.6.0 reemplaza la VM actual con WSO2 4.1.0.
- **Razón:** Sizing de 8 GB RAM permite correr WSO2 con holgura. No se justifica el costo de una VM separada.
- **Consecuencia:** El MCP Gateway corre junto con el API Manager existente, simplificando operación.

**IDR-004: PHP 5.6 se mantiene en v3, se difiere a v4**
- **Decisión:** No se migra PHP en el scope de v3. La VM de aplicación con PHP 5.6 + CodeIgniter mantiene su stack actual.
- **Razón:** La VM de aplicación está aislada de la nueva superficie pública (el MCP Gateway). Migrar PHP a la par que el OS y WSO2 introduce cambios simultáneos que aumentan el riesgo del proyecto sin beneficio directo para v3. Se reduce el alcance para asegurar el éxito del MCP.
- **Consecuencia:** El backend PHP queda accesible solo desde la red interna y desde el WSO2 Gateway. La migración a PHP 8.2 LTS se planifica para v4.

**IDR-005: La VM de aplicación (PHP + Bonita) puede mantenerse en CentOS 7 si el riesgo es manejable**
- **Decisión:** La migración de OS es obligatoria solo para la VM de WSO2 (que requiere JDK 21). La VM de aplicación puede evaluarse caso por caso.
- **Razón:** PHP 5.6 no corre en versiones modernas de glibc sin ajustes. Si se migra el OS de la VM de aplicación, hay que migrar PHP también — y eso queda fuera del scope. Mantener CentOS 7 + PHP 5.6 en una VM aislada de internet es un riesgo controlado.
- **Consecuencia:** Solo la VM de WSO2 va a Rocky Linux 9 en v3. La VM de aplicación se migra cuando se haga la migración de PHP en v4.

---

## 11. Testing, Distribución y Publicación

### 11.1 Las Tres Etapas del Ciclo de Vida del MCP Server

El proceso de llevar un MCP server desde código hasta usuarios finales tiene tres etapas claramente diferenciadas, cada una con herramientas específicas:

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  ETAPA 1: TESTING TÉCNICO          ETAPA 2: TESTING CON IA       │
│  ─────────────────────────         ──────────────────────        │
│   (sin Claude, sin internet)        (con Claude, vía tunnel)     │
│                                                                  │
│   Workstation Ubuntu 24                Workstation Ubuntu 24     │
│        │                                      │                  │
│        ▼                                      ▼                  │
│   WSO2 MCP local                       WSO2 MCP local            │
│   o Python FastMCP                     o Python FastMCP          │
│        │                                      │                  │
│        ▼                                      ▼                  │
│   ┌────────────────┐                   ┌────────────┐            │
│   │ MCP Inspector  │                   │   ngrok    │            │
│   │ (localhost     │                   │   tunnel   │            │
│   │  :6274)        │                   │            │            │
│   └────────────────┘                   └─────┬──────┘            │
│        │                                     │                   │
│        ▼                                     ▼                   │
│   Tests JSON-RPC                       URL HTTPS pública         │
│   crudos, validación                   temporal                  │
│   de schemas                                 │                   │
│                                              ▼                   │
│                                        ┌──────────────┐          │
│                                        │  Claude.ai   │          │
│                                        │  (custom     │          │
│                                        │  connector)  │          │
│                                        └──────────────┘          │
│                                                                  │
│  ETAPA 3: PRODUCCIÓN Y DISCOVERY                                 │
│  ───────────────────────────────                                 │
│                                                                  │
│   VM PROD Rocky Linux 9                                          │
│        │                                                         │
│        ▼                                                         │
│   WSO2 4.6 + MCP Gateway                                         │
│        │                                                         │
│        ▼                                                         │
│   ┌──────────────────────┐    ┌─────────────────────┐            │
│   │  HTTPS público       │ ──►│ Claude Connectors   │ ──► 🌍     │
│   │  mcp.trazalog.com    │    │ Directory (catálogo)│   Usuarios │
│   └──────────────────────┘    └─────────────────────┘   Claude   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 11.2 Etapa 1: Testing Técnico Local (MCP Inspector)

**Herramienta principal:** MCP Inspector — el debugger oficial del protocolo, mantenido por la comunidad MCP. Es el equivalente a "Postman para MCP".

**Cuándo se usa:**
- Mientras Claude Code escribe el código del MCP server en la workstation Ubuntu de Rodolfo.
- Para validar que cada tool nueva expone el schema correcto, recibe los inputs esperados, y devuelve outputs válidos.
- Para probar el contrato JSON-RPC sin necesidad de un cliente IA real.
- En CI/CD como parte del pipeline (modo CLI).

**Cómo se lanza:** No requiere instalación permanente. Se ejecuta directamente con `npx`:

```bash
# Para inspeccionar un servidor local construido en build/index.js (Node)
npx @modelcontextprotocol/inspector node build/index.js

# Para un servidor Python con FastMCP
npx @modelcontextprotocol/inspector uvx mcp-server-name --args

# Para conectar a un MCP server remoto (HTTP)
# Lanzar inspector y configurar URL en el navegador
npx @modelcontextprotocol/inspector
# Luego abrir http://localhost:6274 y configurar:
#   Transport: Streamable HTTP
#   URL: http://localhost:8243/mcp  (puerto del WSO2 Gateway)
```

**Qué provee:**
- UI web en `localhost:6274` para listar tools, ejecutarlas con parámetros, ver responses crudos.
- Modo CLI para automatización en CI/CD.
- Soporte para los tres transports: STDIO, SSE, Streamable HTTP.
- Validación de schemas, OAuth flows, y manejo de errores.

**Alternativa más completa: MCPJam Inspector**

Para validaciones más sofisticadas, especialmente del flujo OAuth 2.1 que va a usar Trazalog:

- App de escritorio para macOS/Windows o web app hosted.
- OAuth conformance checks con explicaciones paso a paso.
- Multi-server chat para probar contra modelos frontier sin API key personal.
- Soporte para Dynamic Client Registration (DCR), requerido por el directory de Claude.

### 11.3 Etapa 2: Testing con Claude Real (Vía Tunnel)

Cuando el MCP server pasó las validaciones técnicas con Inspector, el siguiente paso es probarlo con un cliente IA real (Claude) para verificar que las descripciones semánticas de las tools sean comprendidas correctamente y que el comportamiento end-to-end sea el esperado.

**Problema:** El MCP server vive en localhost de la workstation Ubuntu, pero Claude se conecta desde la nube de Anthropic. Necesita una URL HTTPS pública.

**Solución estándar: ngrok**

ngrok crea un tunnel HTTPS público temporal hacia un puerto local. Es la solución más usada por la comunidad MCP para desarrollo.

**Plan free de ngrok — suficiente para Trazalog en desarrollo:**
- URL HTTPS pública dinámica (cambia en cada reinicio).
- Suficientes requests para iteración de desarrollo.
- Costo: $0.

```bash
# Lanzar tunnel hacia el puerto local del WSO2 Gateway
ngrok http 8243

# Output:
# Forwarding  https://abc123.ngrok-free.app -> http://localhost:8243
```

**Cómo conectar a Claude.ai:**

1. Ir a Claude.ai → Settings → Connectors → Add custom connector.
2. Pegar la URL pública de ngrok con el path MCP: `https://abc123.ngrok-free.app/mcp`.
3. Claude se conecta, descubre las tools automáticamente vía `tools/list`, y queda disponible para usar en conversaciones.

**Restricción importante:** Solo planes **Pro, Max, Team y Enterprise** pueden agregar custom connectors. El plan Free NO permite esto. Rodolfo necesita al menos Claude Pro durante la fase de desarrollo de Trazalog v3.

**Alternativa para testing local sin tunnel: Claude Desktop**

Si la workstation y el MCP server son la misma máquina, Claude Desktop puede conectarse directamente al MCP local sin necesidad de tunnel:
- Editando `~/.config/Claude/claude_desktop_config.json` (Linux) con la configuración del server.
- Soporta transport STDIO (proceso hijo) o HTTP a localhost.
- No requiere internet ni cuenta paga (es una instalación local).

Esta opción es útil para iteraciones rápidas, pero el flujo con ngrok + Claude.ai es el más cercano al comportamiento de producción.

### 11.4 Etapa 3: Distribución y Publicación

Una vez que el MCP server está corriendo en producción (VM Rocky Linux 9 con HTTPS público), hay tres caminos para que los usuarios lo consuman:

**Camino A: Custom Connector Privado (recomendado para arrancar)**

El cliente recibe la URL HTTPS del MCP de Trazalog (ej: `https://mcp.trazalog.com/mcp`) y la agrega manualmente como custom connector en su Claude.ai.

- ✅ Inmediato — no requiere review de Anthropic.
- ✅ Control total — Trazalog decide quién accede.
- ✅ Ideal para clientes contractuales (el primer cliente minero, por ejemplo).
- ❌ Requiere que el usuario tenga plan pago (Pro/Max/Team/Enterprise).
- ❌ Sin discovery público — solo lo encuentra quien recibe la URL.

**Camino B: Claude Connectors Directory (discovery público)**

Submission al directorio público de Claude, donde aparecen >200 connectors curados (Google Drive, Slack, Figma, Adobe, Canva, etc.). Es el equivalente a una "tienda de apps" para MCP.

- ✅ Discovery automático — cualquier usuario de Claude (incluso plan Free) puede instalar el connector con un click.
- ✅ Validación de seguridad por Anthropic — genera confianza.
- ✅ Canal de marketing pasivo — los clientes potenciales pueden encontrar Trazalog buscando soluciones de gestión industrial.
- ❌ Review manual de Anthropic (~2 semanas).
- ❌ Requisitos técnicos estrictos (ver 10.5).
- ❌ El connector aún requiere que el usuario tenga cuenta de Trazalog (no es self-serve).

**Camino C: Otras Plataformas IA**

El mismo MCP server funciona automáticamente en otras plataformas que adoptaron MCP (ChatGPT, Cursor, VS Code Copilot, Gemini). Cada una tiene su propio mecanismo de submission o configuración manual.

### 11.5 Requisitos para el Connectors Directory de Claude

Estos son los requisitos no negociables que Anthropic verifica en el review. La mayoría ya están cubiertos por la arquitectura WSO2 MCP Gateway propuesta:

| Requisito | Estado en arquitectura propuesta |
|---|---|
| Transport: **Streamable HTTP** | ✅ Default del WSO2 MCP Gateway |
| **HTTPS público** internet-accessible | ✅ Cloud Load Balancer + Let's Encrypt |
| **OAuth 2.1** con user consent flow | ✅ WSO2 lo provee nativamente |
| Dynamic Client Registration (DCR) | ✅ Soportado por WSO2 |
| Tool **annotations**: `readOnlyHint` o `destructiveHint` por cada tool | ⚠️ Hay que agregarlo al definir cada tool |
| Tool result < **25.000 tokens** | ⚠️ Diseñar tools para no exceder |
| Timeout < **5 minutos** por tool | ✅ Más que suficiente |
| **Privacy policy** pública | ⚠️ Producir antes de submit |
| **Documentación pública** con 3+ ejemplos de uso | ⚠️ Producir antes de submit |
| **Test account** con datos de muestra para los reviewers | ⚠️ Preparar antes de submit |
| **Logo y branding** (favicon, screenshots si es MCP App) | ⚠️ Producir antes de submit |

**Causa #1 de rechazos en el directory:** la falta de annotations en las tools. Aproximadamente el 30% de los rechazos se deben a esto. Cada tool MCP de Trazalog debe declarar si es de solo lectura o destructiva.

**Ejemplo de annotations correctas:**

```python
# Tool de solo lectura (búsqueda, consulta, listado)
@mcp.tool(annotations={"readOnlyHint": True})
def buscar_ordenes_trabajo(equipo_id: str) -> list:
    """Busca órdenes de trabajo asociadas a un equipo."""
    # ...

# Tool destructiva (creación, modificación, envío)
@mcp.tool(annotations={"destructiveHint": True})
def crear_orden_trabajo(equipo_id: str, descripcion: str) -> dict:
    """Crea una nueva orden de trabajo."""
    # ...
```

### 11.6 Implicaciones para la Infraestructura

Para que el MCP de Trazalog se publique en el directory, el server **debe ser alcanzable desde la internet pública** desde los rangos de IP de Anthropic. Esto refuerza varias decisiones de la sección 10 de Arquitectura de Infraestructura:

- ✅ **HTTPS público obligatorio** — ya contemplado con Cloud Load Balancer + Let's Encrypt.
- ✅ **No detrás de VPN ni firewall corporativo** — el MCP Gateway es público; solo las consolas administrativas (puerto 9443 de WSO2) van por VPN.
- ✅ **Streamable HTTP transport** — default del WSO2 MCP Gateway 4.6.0.
- ⚠️ **Dominio público propio** — recomendable registrar `mcp.trazalog.com` o similar para profesionalismo, en vez de usar IP directa.

### 11.7 Plan de Adopción por Fases

```
Q3 2026 — Etapa de Desarrollo
─────────────────────────────
• MCP Inspector en workstation Ubuntu para todo el dev
• ngrok + Claude.ai Pro para validación con cliente real
• Sin discovery público aún

Q4 2026 — Cliente Piloto Minero (Custom Connector Privado)
──────────────────────────────────────────────────────────
• MCP en PROD con HTTPS público
• Cliente minero accede como custom connector
• Sin submit al directory todavía
• Validación de tools, tiempos, calidad de descripciones

Q1 2027 — Preparación para Directory
────────────────────────────────────
• Producir privacy policy
• Documentación pública con casos de uso
• Test account con datos de muestra
• Verificar annotations en todas las tools
• Logo y branding profesional

Q2 2027 — Submit al Connectors Directory
────────────────────────────────────────
• Enviar formulario de submission
• Review manual de Anthropic (~2 semanas)
• Si aprobado: discovery público activado
• Marketing y casos de uso públicos
```

### 11.8 Diferencias Clave con un App Store Tradicional

| Aspecto | Google Play / App Store | Claude Connectors Directory |
|---|---|---|
| **Distribución del software** | Binario descargable al dispositivo | URL HTTPS — el server lo hostea el desarrollador |
| **Hosting** | Plataforma hostea el binario | Desarrollador hostea su MCP server |
| **Costo de submit** | Pagas anuales (Apple) o únicas (Google) | Gratuito |
| **Comisiones por venta** | 15-30% del revenue | 0% — el desarrollador maneja sus propios cobros |
| **Review** | Automatizado + manual, días-semanas | Manual, ~2 semanas |
| **Updates** | El usuario actualiza el binario | El developer despliega cambios — usuarios reciben automáticamente |
| **Funcionalidad offline** | Posible | No — siempre requiere el server activo |

Esto es relevante porque significa que **Trazalog mantiene control total sobre su infraestructura, monetización y experiencia de cliente**, sin pagar comisiones a Anthropic. El directory es discovery, no intermediario comercial.

### 11.9 Decisiones de Distribución Registradas

**DDR-001: MCP Inspector como herramienta estándar de testing técnico**
- **Decisión:** Todo desarrollo de tools MCP se valida con MCP Inspector antes de integrar con Claude.
- **Razón:** Loop de feedback más rápido, debugging más claro, no requiere cuenta paga.
- **Consecuencia:** Workflow estándar documentado para el equipo dev.

**DDR-002: Plan Pro de Claude.ai como herramienta de desarrollo**
- **Decisión:** Rodolfo debe tener al menos Claude Pro durante el desarrollo de v3 para usar custom connectors.
- **Razón:** El plan Free no permite custom connectors. Es la única forma de validar end-to-end antes del submit al directory.
- **Consecuencia:** Costo asumido como herramienta de desarrollo.

**DDR-003: Custom connector privado primero, directory después**
- **Decisión:** El primer cliente minero accede vía custom connector privado (URL compartida directamente). El submit al directory se difiere a Q2 2027.
- **Razón:** Permite iterar sin presión de review de Anthropic. Validar tools y descripciones con uso real antes de exponer públicamente.
- **Consecuencia:** Discovery público diferido, pero menor riesgo de submission rechazada.

**DDR-004: Tool annotations son requisito de definición**
- **Decisión:** Cada MCP tool debe declarar `readOnlyHint` o `destructiveHint` desde el momento de su creación.
- **Razón:** Es requisito del directory y del 30% de los rechazos. Hacerlo desde el día 1 evita refactor masivo antes del submit.
- **Consecuencia:** Template/checklist de creación de tools incluye annotations como obligatorias.

---

## 12. Riesgos y Mitigaciones

| Riesgo | Impacto | Probabilidad | Mitigación |
|---|---|---|---|
| **Latencia del doble salto** (MCP GW → Python → WSO2 API → Backend) | Medio | Alta (en Fase 2) | Tools simples van directo (virtual MCP server); Python solo para tools que agregan valor |
| **Complejidad operacional** (3 capas tecnológicas) | Alto | Media | Regla clara de qué va en cada capa; runbooks; solo Python cuando se justifica |
| **Lock-in con WSO2** | Medio | Baja | MCP es estándar abierto; Python servers son portables; protocolo permite migrar gateway |
| **Debugging cross-stack** | Medio | Alta | OpenTelemetry end-to-end; FastMCP 3.0 lo soporta nativamente; correlación de logs |
| **APIs de CodeIgniter no expuestas** | Alto | Alta | Plan sistemático de exposición vía DataServices/APIs WSO2 |
| **Calidad de tool descriptions** | Alto | Media | Descripciones semánticas ricas; testing en MCP Playground antes de publicar |
| **Evolución rápida del protocolo MCP** | Bajo | Media | Bajo Linux Foundation, evolución será conservadora; WSO2 trackea activamente |
| **Migración de OS de WSO2 (CentOS 7 → Rocky Linux 9) interrumpe operación** | Alto | Media | Migrar TEST primero, validar exhaustivamente, ventana de mantenimiento planificada para PROD con plan de rollback. La VM antigua queda apagada como rollback durante 30 días |
| **Backend PHP 5.6 sigue activo con vulnerabilidades conocidas** | Medio | Alta | Mitigación: VM de aplicación sin exposición pública, accesible solo desde red interna y desde el WSO2 Gateway. Migración planificada en v4 |
| **Fuga de datos entre empresas (cross-tenant leak)** | Crítico | Media | El `empr_id` viaja en token firmado, nunca como sesión ni parámetro de tool (TAD-IDENT-01); enforcement en el gateway (TAD-IDENT-03); auditoría obligatoria del filtrado por empresa en DataServices antes de exponerlos como tools (TAD-IDENT-P04) |
| **DataService sin filtro por `empr_id` expuesto como tool MCP** | Crítico | Media | Auditoría de consistencia previa a la exposición (TAD-IDENT-P04); ningún DataService se virtualiza como tool sin verificar su filtrado |
| **Costos de GCP suben con la nueva VM de WSO2** | Bajo | Baja | Incremento estimado ~USD 75/mes; revisar consumo real a 30 días y ajustar |
| **Configuración de Dnato como Key Manager federado del APIM toma más tiempo del esperado** | Medio | Media | Acordado correr fecha de demo Sprint 2 antes que tomar atajos (passthrough). Dnato debe exponer JWKS endpoint + firmar con RS256 antes de avanzar con E9-IDENT-05. Ver ADR-008 |

---

## 13. Stack Tecnológico Consolidado (Costo $0)

| Capa | Tecnología | Costo | Rol |
|---|---|---|---|
| MCP Gateway | WSO2 API Manager 4.6.0+ (open source, self-hosted) | $0 | Seguridad, rate limiting, MCP Hub, virtualización |
| MCP Server (IA) | Python + FastMCP (Fase 2+, open source) | $0 | Tools con IA/ML, procesamiento no-estructurado |
| API Management | WSO2 API Manager (open source, ya en uso) | $0 | APIs REST, DataServices, orquestación, mediaciones |
| BPM | Bonita (open source, ya en uso) | $0 | Workflows del módulo Procesos/PRO, HSE |
| Backend Legacy | CodeIgniter (PHP, ya en uso) | $0 | Lógica de Asset Planner (en migración progresiva) |
| Base de Datos | Oracle / PostgreSQL (ya en uso) | $0 | Persistencia |
| Analytics MCP | WSO2 Analytics nativas + script custom | $0 | Conteo de calls, reportes de consumo por cliente |
| Billing | Manual (MercadoPago / transferencia) | Solo comisión por txn | Cobro a clientes (Fase 1: manual, Fase 2: semi-auto) |
| Observabilidad | OpenTelemetry + logs WSO2 | $0 | Tracing distribuido, debugging cross-stack |
| IDE/Dev | Cursor + Claude Code | Ya contratado | Desarrollo |
| Infra | Google Cloud VMs (ya existentes) | Ya contratado | Hosting de todo el stack |

**Costo incremental total de la arquitectura MCP: $0/mes**
(Asumiendo que WSO2 4.6.0 corre en las VMs existentes o en una redistribución de recursos actual)

---

## 14. Decisiones Arquitectónicas Registradas (ADRs)

### ADR-001: WSO2 MCP Gateway como único punto de entrada MCP
- **Decisión:** Todo tráfico MCP pasa por WSO2 MCP Gateway.
- **Razón:** Centraliza seguridad, monetización y observabilidad.
- **Consecuencia:** Dependencia de WSO2 para features MCP.

### ADR-002: Maximizar Virtual MCP Servers, minimizar Python
- **Decisión:** 80-90% de tools se implementan como virtual servers generados desde OpenAPI. Python solo para IA/ML y procesamiento no-estructurado.
- **Razón:** Reutiliza stack existente, avanza migración de PHP, reduce complejidad operacional.
- **Consecuencia:** Python no entra en Fase 1 (MVP).

### ADR-003: Orquestaciones de PHP migran a WSO2, no a Python
- **Decisión:** La lógica de orquestación que hoy vive en controllers PHP se recrea como APIs/mediaciones WSO2.
- **Razón:** Mata dos pájaros: habilita MCP + desacopla monolito PHP. Python agregaría una tercera tecnología de orquestación.
- **Consecuencia:** Esfuerzo de desarrollo en WSO2 antes de exponer como MCP.

### ADR-004: Arquitectura dual de almacenes se mantiene para MVP
- **Decisión:** Asset Planner legacy ALM y traz-comp-almacenes se mantienen como fuentes separadas.
- **Razón:** Unificación es compleja y no bloquea el MVP de MCP.
- **Consecuencia:** Tools MCP de almacén deben especificar claramente qué fuente consultan.

### ADR-005: Monetización sin costos de licencia hasta 2027
- **Decisión:** Se usa WSO2 analytics nativas para metering, facturación manual con MercadoPago/transferencia para billing. No se contratan Moesif, Stripe ni otros servicios pagos.
- **Razón:** Premisa estratégica de costo $0 hasta que la masa crítica de clientes mineros (2027) genere ingresos que justifiquen automatización.
- **Consecuencia:** Mayor esfuerzo manual en facturación. Se evalúa automatización en Fase 2 cuando los ingresos lo justifiquen.

### ADR-006: Modelo de identidad y aislamiento multi-tenant
- **Nota:** Las decisiones arquitectónicas de identidad están detalladas en extenso en la **Sección 6 — Modelo de Identidad y Aislamiento Multi-Tenant**, dividida en decisiones tomadas (TAD-IDENT-01 a 04, firmes) y decisiones pendientes (TAD-IDENT-P01 a P04, a cerrar en Sprint 2 con investigación de código).
- **Resumen de decisiones tomadas:** El `empr_id` viaja como claim del token OAuth, nunca como sesión ni parámetro de tool; el MVP asume una empresa por usuario sin cerrar la puerta al caso multi-empresa; el aislamiento se enforza en el WSO2 MCP Gateway; el usuario se autentica contra Trazalog, no contra Claude ni WSO2 directamente.
- **Decisiones pendientes:** Quién actúa como Authorization Server; comportamiento ante usuario multi-empresa; mecanismo de consulta de Memberships de Bonita; auditoría de filtrado por `empr_id` en DataServices.

### ADR-008: APIM valida JWT de Dnato como Key Manager federado — NO passthrough al MI

> **Estado:** Aprobada (Sprint 2, sesión de arquitectura).  
> **Reemplaza/Anula:** Cualquier procedimiento anterior que propusiera "JWT passthrough" donde el APIM proxea sin validar y el MI valida vía `JwtValidator.xml`.

**Contexto:** Durante el Sprint 2, al configurar las primeras APIs (`equipos.yaml`, `ot.yaml`) en WSO2 API Manager 4.6.0, se propuso inicialmente un patrón de "JWT passthrough": el APIM deshabilitaba la seguridad a nivel de Resource, el header `Authorization: Bearer` se proxeaba al MI sin validar, y el MI ejecutaba `JwtValidator.xml` para validar el JWT emitido por Dnato. Este patrón requería el flag global `enable_outbound_auth_header = true` en `deployment.toml`.

**Decisión:** El **APIM valida directamente los JWT emitidos por Dnato**, configurando Dnato como **Key Manager federado** del APIM. El MI NO valida JWTs; solo recibe el `empr_id` ya inyectado por el APIM (en el header `X-Empr-Id` o equivalente) y lo usa para filtrar datos en los DataServices. La sequence `JwtValidator.xml` se descarta del flujo MCP (puede mantenerse en repo para referencia o reutilizarse en otros contextos, pero no se ejecuta para tráfico MCP).

**Justificación:**

1. **Compatibilidad con APIM único compartido (restricción de costos de hardware).** El MVP requiere un APIM compartido entre las APIs MCP nuevas y las APIs legacy que ya usan OAuth2 nativo. El patrón passthrough requiere el flag global `enable_outbound_auth_header = true`, que afecta a **todas** las APIs del APIM y podría romper las APIs legacy. Con APIM como Key Manager federado, cada API decide independientemente si valida vía OAuth2 nativo o vía Dnato federado, sin flags globales que rompan otras APIs.

2. **El APIM cumple su rol clásico de centralizador de seguridad.** Es el patrón documentado por WSO2 y por la industria para gateways de API. Tener el APIM "desnudo" en seguridad mientras el MI valida es un anti-patrón que confunde a quien revise la arquitectura y genera deuda técnica permanente.

3. **Habilita el MCP Gateway 4.6.0 sin reanalizar la seguridad.** Cuando se active el Virtual MCP Server sobre las APIs ya publicadas, el gateway aprovecha automáticamente la validación que el APIM ya hace. Si la seguridad estuviera en el MI, habría que rediseñar el flujo cuando se sume la capa MCP.

4. **Consistencia con TAD-IDENT-03.** La decisión arquitectónica TAD-IDENT-03 establece que "el aislamiento multi-tenant se enforza en el WSO2 MCP Gateway". En la arquitectura WSO2 4.6.0, el componente que cumple este rol es el APIM (que ahora incluye el MCP Gateway nativo). El MI es un broker de mediación, no un gateway de seguridad.

5. **Simplifica el flujo end-to-end.** Una sola validación, en un solo punto, con un solo mecanismo. Reduce la superficie de error y los puntos a auditar.

**Mecanismo técnico (alto nivel):**

```
┌─────────────────────────────────────────────────────────────────┐
│ FLUJO ARQUITECTÓNICAMENTE CORRECTO (ADR-008)                     │
└─────────────────────────────────────────────────────────────────┘

   Agente MCP (Claude, etc.)
        │  Authorization: Bearer <JWT Dnato>
        ▼
   APIM Gateway (:8243)
        │  ┌──────────────────────────────────────┐
        │  │ 1. Valida firma JWT vs JWKS de Dnato │
        │  │ 2. Valida exp, iss, aud              │
        │  │ 3. Extrae claim empr_id              │
        │  │ 4. Inyecta X-Empr-Id como header     │
        │  └──────────────────────────────────────┘
        ▼
   MI (:8280) — recibe X-Empr-Id ya validado
        │  (NO ejecuta JwtValidator.xml para tráfico MCP)
        ▼
   DataServices — filtran por X-Empr-Id
```

Para que esto funcione, **Dnato debe**:
- Exponer un endpoint **JWKS** (`/.well-known/jwks.json` o equivalente) con la clave pública para que el APIM valide la firma.
- Firmar los JWT con un algoritmo asimétrico (recomendado: **RS256**, NO HS256 — HS256 requeriría compartir secreto entre Dnato y APIM, no es escalable).
- Incluir los claims estándar: `iss` (issuer = URL de Dnato), `aud` (audience = identificador del APIM), `exp`, `iat`, además del claim custom `empr_id`.

Para que esto funcione, **el APIM debe**:
- Configurar Dnato como Key Manager externo (módulo "Key Managers" en `/admin`).
- Activar la validación JWT con el JWKS endpoint de Dnato.
- Definir una mediación (in-sequence) que extraiga el claim `empr_id` y lo inyecte como header downstream.
- Mantener OAuth2 nativo del APIM activo para las APIs legacy — ambos coexisten gracias a la federación de Key Managers.

**Consecuencias:**

- ✅ APIM único viable para todas las APIs (MCP + legacy).
- ✅ Flujo arquitectónicamente limpio, alineado con TAD-IDENT-03.
- ✅ Habilita Virtual MCP Server sin retrabajo.
- ❌ Se corre la fecha de la demo del Sprint 2 (originalmente 1 de junio). La configuración de Key Manager federado y los ajustes necesarios en Dnato requieren más tiempo que el passthrough. **Decisión del PM: priorizar correctitud arquitectónica sobre fecha.**
- ❌ Dnato debe exponer JWKS endpoint si todavía no lo hace.
- ❌ Si Dnato firma con HS256, debe migrar a RS256 (clave asimétrica).

**Trabajo derivado (impacta al backlog):**

1. **Dnato debe exponer JWKS y firmar con RS256.** Validar el estado actual y, si es necesario, agregar como tarea bloqueante del Sprint 2 antes de E9-IDENT-05.
2. **El procedimiento `openapi-publish-procedure.md` debe rehacerse.** El procedimiento actual de configuración de las APIs en el APIM (deshabilitar seguridad a nivel de Resource, flag global) se anula. Hay que escribir el nuevo procedimiento basado en Key Manager federado.
3. **La sequence `JwtValidator.xml` del MI sale del flujo MCP.** Se mantiene en repo pero no se invoca desde las APIs MCP. Documentar explícitamente en el código o como ADR derivado.
4. **El flag `enable_outbound_auth_header = true` NO se aplica** al `deployment.toml`. Las APIs legacy y MCP coexisten sin tocar config global.
5. **La inyección del `empr_id` ahora ocurre en una mediación del APIM**, no en el MI. La historia E9-IDENT-05 se reorienta.

**Referencias para la implementación:**
- WSO2 docs: "Configuring Key Managers" — https://apim.docs.wso2.com/en/latest/administer/key-managers/configure-keymanager/
- WSO2 docs: "External JWT Key Manager" — https://apim.docs.wso2.com/en/latest/design/api-security/oauth2/key-managers/configure-external-idp/
- JWKS spec: RFC 7517

---

## 15. Próximos Pasos

**Prerequisitos de Sprint 2 — Modelo de Identidad (bloqueante):**
- **Investigación de código** del modelo de autenticación y multi-tenancy actual (alcance detallado en Sección 6.6). Es bloqueante: las decisiones TAD-IDENT-P01 a P04 dependen de sus resultados.
- **Cierre de decisiones pendientes** TAD-IDENT-P01 a P04 al inicio del Sprint 2, con la investigación como insumo.
- **Implementación de la capa de identidad:** emisión de token con claim `empr_id` + validación e inyección en el WSO2 MCP Gateway (ver Sección 6.7).

**Prerequisitos de Infraestructura (Q2 2026):**
0. **Provisión de VM nueva con Rocky Linux 9** en GCP para TEST. Instalación de JDK 21 y validación de compatibilidad básica. Esta es la única migración de OS dentro del scope de v3.

**Trabajo de Arquitectura MCP:**
1. **Inventario de APIs:** Listar todas las APIs REST y DataServices actualmente expuestas en WSO2 4.1.0 con sus OpenAPI specs.
2. **Mapeo de operaciones PHP:** Identificar orquestaciones en controllers PHP candidatas a migrar a WSO2 (la migración es de la lógica a APIs WSO2, no del PHP en sí).
3. **Definición de Tool Catalog:** Para cada operación, definir el MCP tool con nombre, descripción semántica, input schema, output schema, y annotations (`readOnlyHint` o `destructiveHint`).
4. **Priorización:** Ordenar tools por valor para el primer cliente minero.
5. **PoC con WSO2 MCP Gateway:** Una vez instalado WSO2 4.6.0 en TEST, virtualizar 3-5 APIs existentes y probar desde Claude Desktop / VS Code Copilot.

**Setup de Testing y Desarrollo:**
6. **Workstation Ubuntu lista:** Instalar Node.js 22+, MCP Inspector vía npx, ngrok con cuenta free, Claude Pro para custom connectors.
7. **Workflow de testing:** Definir checklist de validación con MCP Inspector antes de integrar a Claude.
8. **Activar Claude Pro:** Para uso de custom connectors durante desarrollo.

**Plan de Migración de Software (Q2-Q4 2026):**
9. **Upgrade WSO2:** 4.1.0 → 4.6.0 (export/import de APIs vía apictl).

**Preparación para Connectors Directory (Q1-Q2 2027):**
10. **Privacy policy:** Redactar y publicar política de privacidad de Trazalog MCP.
11. **Documentación pública:** Producir docs con al menos 3 ejemplos de uso por tool.
12. **Test account:** Preparar cuenta con datos de muestra para reviewers de Anthropic.
13. **Branding:** Logo, favicon, screenshots si aplica.
14. **Submit al directory** una vez cubiertos los requisitos.

**Diferido a v4:**
- Migración de PHP 5.6 → 8.2 LTS
- Migración de PostgreSQL 11 → 15
- Migración de OS de la VM de aplicación
- Eventual contenedorización con Docker/Kubernetes

---

## Apéndice A: Glosario

| Término | Definición |
|---|---|
| **MCP** | Model Context Protocol — protocolo abierto para conectar agentes de IA con herramientas y datos externos |
| **MCP Server** | Servicio que expone tools, resources y prompts a agentes de IA vía JSON-RPC 2.0 |
| **MCP Client** | Componente del agente que se conecta a MCP servers (ej: Claude, ChatGPT) |
| **MCP Gateway** | Capa de mediación entre MCP clients y servers que aplica seguridad, rate limiting, monetización |
| **MCP Hub** | Catálogo searchable de MCP servers publicados |
| **Virtual MCP Server** | MCP server generado automáticamente por WSO2 a partir de una API REST existente (via OpenAPI spec) |
| **FastMCP** | Framework Python de alto nivel para construir MCP servers (estándar de facto, 70% del ecosistema) |
| **Tool** | Función callable que un agente de IA puede invocar (equivalente a un endpoint, pero semántico) |
| **Resource** | Dato que puede ser consultado por un agente (equivalente a un GET, pero con metadata semántica) |
| **Prompt** | Template reutilizable que estandariza comportamiento del agente |
| **Streamable HTTP** | Transporte recomendado para MCP en producción (reemplaza SSE dual-endpoint) |
| **AAIF** | Agentic AI Foundation — organización bajo Linux Foundation que gobierna MCP |
| **Moesif** | Plataforma de analytics y monetización de APIs, adquirida por WSO2 |
| **MCP Inspector** | Herramienta oficial de testing y debugging de MCP servers. Web UI accesible en localhost:6274. Equivalente a "Postman para MCP" |
| **MCPJam** | Alternativa a MCP Inspector con features adicionales como OAuth conformance checks y multi-server playground |
| **ngrok** | Servicio de tunneling que expone servidores localhost a internet vía URL HTTPS pública. Plan free suficiente para desarrollo |
| **Custom Connector** | MCP server agregado manualmente a Claude.ai mediante una URL HTTPS. Requiere plan Pro o superior |
| **Connectors Directory** | Catálogo público de Claude con MCP servers curados, similar a una app store. Submission gratuita pero con review manual de Anthropic |
| **Tool Annotations** | Metadata en cada tool MCP que declara si es de solo lectura (`readOnlyHint`) o destructiva (`destructiveHint`). Requisito del directory |
| **Streamable HTTP** | Transport recomendado para MCP en producción. Reemplazó al transport SSE que fue deprecado en marzo 2025 |
| **MCPB** | Formato de empaquetado de MCP servers desktop (.mcpb), instalables como extensiones de Claude Desktop |
| **Multi-tenant** | Arquitectura donde una sola instancia de software sirve a múltiples clientes (tenants), manteniendo sus datos aislados |
| **empr_id / id_empresa** | Identificador de empresa en Trazalog. `empr_id` en el módulo Tools, `id_empresa` en Asset Planner. Mecanismo de aislamiento de datos entre clientes |
| **Claim** | Dato incluido dentro de un token JWT (ej: identidad del usuario, `empr_id`). Firmado criptográficamente, no manipulable por el usuario |
| **Authorization Server** | Componente OAuth que autentica usuarios y emite tokens de acceso |
| **Membership (Bonita)** | Asociación de un usuario con un rol y un group en Bonita. Trazalog usa el "group" para representar una empresa |
| **PKCE** | Proof Key for Code Exchange — extensión de OAuth que asegura que el cliente que inició el flujo es el mismo que lo completa |
| **Key Manager (WSO2)** | Componente del APIM responsable de validar tokens OAuth y autorizar accesos. Soporta múltiples Key Managers federados, permitiendo que APIs distintas usen distintos emisores de tokens (ej: Dnato para MCP, OAuth2 nativo para APIs legacy) |
| **JWKS** | JSON Web Key Set — endpoint público (RFC 7517) que expone las claves públicas usadas para verificar la firma de JWTs. Estándar para validación de tokens emitidos por un IdP externo |
| **RS256** | Algoritmo de firma de JWT basado en RSA + SHA-256 (clave asimétrica: clave privada para firmar, clave pública para validar). Es la opción correcta para federación entre componentes (vs HS256 que requiere secreto compartido) |

## Apéndice B: Referencias

- Especificación MCP: https://modelcontextprotocol.io
- WSO2 MCP Gateway docs: https://apim.docs.wso2.com/en/latest/mcp-gateway/overview/
- WSO2 AI Gateway: https://wso2.com/api-platform/ai-gateway/
- FastMCP (Python): https://github.com/jlowin/fastmcp
- MCP Python SDK oficial: https://github.com/modelcontextprotocol/python-sdk
- Agentic AI Foundation: https://www.anthropic.com/news/donating-the-model-context-protocol-and-establishing-of-the-agentic-ai-foundation
- WSO2 API Monetization: https://apim.docs.wso2.com/en/4.3.0/design/api-monetization/monetizing-an-api/
- MCP Inspector (oficial): https://github.com/modelcontextprotocol/inspector
- MCP Inspector docs: https://modelcontextprotocol.io/docs/tools/inspector
- MCPJam Inspector: https://github.com/MCPJam/inspector
- Claude Connectors Directory submission: https://claude.com/docs/connectors/building/submission
- Claude Custom Connectors guide: https://support.claude.com/en/articles/11175166-get-started-with-custom-connectors-using-remote-mcp
- Claude Desktop local MCP servers: https://modelcontextprotocol.io/docs/develop/connect-local-servers
- ngrok MCP gateway docs: https://ngrok.com/docs/using-ngrok-with/using-mcp
- WSO2 API Manager 4.6.0 release: https://github.com/wso2/product-apim/releases
