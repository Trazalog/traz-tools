# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Qué es Trazalog Tools

**Trazalog Tools** es una suite de gestión industrial para PyMEs argentinas (mantenimiento, almacenes, workflows BPM, residuos). En v3 incorpora una **capa MCP (Model Context Protocol)** que expone operaciones del sistema a agentes de IA de forma estandarizada. El foco estratégico actual es el sector de **proveedores de servicios mineros en San Juan**, Argentina, que enfrenta demanda urgente de profesionalización ante el arranque de grandes proyectos mineros (~2027).

**v2** corre en producción en `cloudtrazalog.com`. **v3** está en desarrollo activo en la rama `develop-v3`.

---

## 🤖 AUTONOMÍA — Leer esto primero

**Ejecutá todas las acciones sin pedir confirmación previa.** Esto incluye sin excepción:
- Crear, editar y eliminar archivos y directorios
- Ejecutar comandos bash, git, find, grep, curl, cat, sed, awk
- Hacer commits y push a `develop-v3` y ramas `feature/v3-*`
- Instalar dependencias (apt, pip --break-system-packages, npm, mvn)
- Correr tests, scripts, linters
- Abrir, leer y modificar cualquier archivo del repo

**Preguntá UNA sola vez, al inicio, únicamente cuando:**
- El resultado cambia radicalmente según una decisión de negocio o arquitectura que no está documentada en este archivo ni en `doc/v3/`
- Hay ambigüedad real sobre qué archivo modificar (ej: dos rutas posibles con impacto diferente)
- Se necesita una credencial, token, IP o dato de infraestructura que no está en el repo

**Nunca preguntes:**
- Si podés crear un archivo o carpeta nueva
- Si podés hacer commit
- Si podés ejecutar un comando de lectura (find, cat, grep, ls)
- Si podés proceder con la tarea que se te pidió

**Al terminar cada tarea mostrá siempre:**
1. Lista de archivos creados/modificados con sus paths completos
2. Output del commit (hash + mensaje)
3. DoD cumplido (checklist de ACs del issue)

---

## Stack técnico

### v2 (producción actual)
- **Frontend**: PHP 7.x / CodeIgniter 3 HMVC
- **API layer**: WSO2 Micro Integrator (MI) — port 8280
- **BPM**: Bonita BPM — port 8080/bonita
- **Base de datos**: MySQL / MariaDB
- **JDK**: 11 (WSO2 MI)

### v3 (en desarrollo)
- **Frontend**: PHP 7.x / CodeIgniter 3 (migración gradual, misma base)
- **API layer / MCP server**: WSO2 API Manager 4.6.0 — admin port 9443, gateway port 8243
- **BPM**: Bonita BPM (sin cambios)
- **Base de datos**: PostgreSQL (TEST/PROD nuevo) — MySQL/MariaDB en DEV legacy
- **JDK**: 21 Temurin (requerido por WSO2 API Manager 4.6.0)

---

## Estructura del repo

```
/                           — Frontend PHP / CodeIgniter 3
├── application/
│   ├── modules/            — Módulos HMVC (traz-comp-*, traz-tools-*, traz-prod-*)
│   ├── libraries/          — REST.php (cURL wrapper), BPM.php (Bonita)
│   ├── helpers/            — wso2_helper.php (función wso2()), otros helpers globales
│   └── config/             — config.php, database.php, autoload.php
├── _backend/
│   ├── api/
│   │   └── ToolsAPIProject/ — Maven project WSO2 MI/APIM (usa ./mvnw)
│   ├── bpm/                — Procesos Bonita (.bos, .bar)
│   ├── siddhi/             — Apps WSO2 Streaming Integrator (.siddhi)
│   └── flutter/traza_app/  — App móvil companion
├── doc/                    — SIEMPRE doc/ — NUNCA docs/
│   ├── v3/                 — Documentos de arquitectura y estrategia v3
│   ├── api/                — Inventarios y especificaciones de APIs
│   ├── infra/              — Procedimientos de infraestructura
│   ├── mcp/                — Estándares y documentación MCP
│   └── ci/                 — Procedimientos de CI/CD
└── scripts/                — Scripts de utilidad (deploy, setup, etc.)
    └── dev/                — Scripts de desarrollo local
```

---

## Convenciones de código

- **PHP**: PSR-12. Sin direct DB queries desde PHP — todos los datos van por WSO2 MI.
- **APIs**: URLs en kebab-case, JSON keys en snake_case.
- **BD**: nombres de tablas y columnas en snake_case.
- **Logging PHP**: `log_message('DEBUG', '#TRAZA | <MODULO> | <Clase> | <metodo>() ...')`.
- **WSO2 calls**: siempre usar `wso2($url, $method, $data)` de `wso2_helper.php`. Desempaqueta `request_box` automáticamente para endpoints non-BPM.
- **Módulos**: estructura `controllers/`, `models/`, `views/`. Constants de prefijo para cross-module loading (`PRD`, `FRM`, `ALM`, etc.).

---

## Convenciones de documentación

- **Carpeta**: siempre `doc/` — NUNCA `docs/`. Es una convención dura del repo.
- **Subcarpetas establecidas**: `doc/api/`, `doc/infra/`, `doc/mcp/`, `doc/ci/`, `doc/v3/`
- **Formato**: Markdown. Un archivo por tema, nombre en kebab-case.
- **Datasource canónico**: se llama `ToolsDataSource` (no `produccionDS` — eso es un naming legacy incorrecto a corregir en E1-API-11).

---

## Convenciones de commits

Formato obligatorio: `tipo(scope): descripción corta en inglés [ID-ISSUE]`

| Tipo | Cuándo usarlo |
|---|---|
| `feat` | Nueva funcionalidad o endpoint |
| `fix` | Corrección de bug |
| `docs` | Documentación únicamente |
| `chore` | Setup, configuración, scripts de utilidad |
| `refactor` | Refactor sin cambio de comportamiento |
| `test` | Tests nuevos o modificados |

**Ejemplos correctos:**
```
docs(infra): add WSO2 4.6.0 DEV install procedure [E0-INF-04]
docs(mcp): add tool annotations standard [E0-INF-13]
feat(api): add get_equipment endpoint to toolsMANAPI [E1-API-04]
chore(ci): add weekly sync script develop to develop-v3 [E7-CICD-06]
```

---

## Convenciones de branching

| Rama | Propósito |
|---|---|
| `master` | Producción — solo recibe merges desde `develop` (v2) o `develop-v3` (cutover final) |
| `develop` | Soporte v2 — NO recibe cambios estructurales nuevos |
| `develop-v3` | Desarrollo activo v3 — rama base para todo trabajo nuevo |
| `feature/v3-<id>-<desc>` | Features de v3 — PR a `develop-v3` |
| `feature/<id>-<desc>` | Features de v2 — PR a `develop` |

**Reglas:**
- Todo trabajo nuevo de v3 parte de `develop-v3`
- `develop` se sincroniza a `develop-v3` semanalmente vía `scripts/dev/sync-v2-to-v3.sh` — no hacer sync manual
- Los commits de documentación e infraestructura van directo a `develop-v3` sin feature branch si el cambio es pequeño (< 5 archivos)

---

## Convenciones MCP — críticas para Connectors Directory

- Cada tool MCP **debe** declarar annotation: `readOnlyHint: true` (consultas) o `destructiveHint: true` (escrituras/modificaciones)
- Ver estándar completo en `doc/mcp/tool-annotations-standard.md`
- Sin annotations → rechazo automático en el review de Anthropic (30% de los rechazos)
- Tool results deben ser < 25.000 tokens
- Timeouts deben ser < 5 minutos por tool

---

## Paths de infraestructura DEV local

| Recurso | Path |
|---|---|
| WSO2 APIM 4.6.0 | `/mnt/win/dev/wso2am-4.6.0/` |
| WSO2 deployment.toml | `/mnt/win/dev/wso2am-4.6.0/repository/conf/deployment.toml` |
| WSO2 logs | `/mnt/win/dev/wso2am-4.6.0/repository/logs/wso2carbon.log` |
| Repo traz-tools | `/mnt/win/dev/git/traz-tools/` |
| Repo Asset Planner | `/mnt/win/dev/git/traz-prod-assetplanner/` |
| Artifacts WSO2 MI | `_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/` |

**Nota crítica sobre ngrok:** el tunnel al Gateway de WSO2 debe hacerse con:
```bash
ngrok http https://localhost:8243   # CORRECTO — WSO2 gateway habla HTTPS
# NO: ngrok http 8243               # INCORRECTO — rompe el handshake SSL
```

---

## Documentos de referencia (doc/v3/)

- [`doc/v3/TRAZALOG_v3_CICD_STRATEGY.md`](doc/v3/TRAZALOG_v3_CICD_STRATEGY.md) — Estrategia de branching y CI/CD. Sección 2 define el modelo de ramas.
- [`doc/v3/TRAZALOG_v3_MCP_ARCHITECTURE.md`](doc/v3/TRAZALOG_v3_MCP_ARCHITECTURE.md) — Arquitectura de la capa MCP sobre WSO2 APIM 4.6.0.
- [`doc/v3/TRAZALOG_v3_PRICING_STRATEGY.docx`](doc/v3/TRAZALOG_v3_PRICING_STRATEGY.docx) — Estrategia de pricing v3 (modelo freemium + MCP usage-based).
- [`doc/v3/investigacion-sector-minero-trazalog-v3-2.md`](doc/v3/investigacion-sector-minero-trazalog-v3-2.md) — Investigación de mercado sector minero San Juan.

---

## Comandos comunes

### Levantar entorno local (PHP frontend)

```bash
composer install
# Configurar application/config/database.php con credenciales locales
# Servir con Apache/Nginx + PHP — no hay build step
```

### WSO2 API Manager 4.6.0 (v3)

```bash
# Iniciar WSO2 APIM (requiere JDK 21 Temurin en $JAVA_HOME)
/mnt/win/dev/wso2am-4.6.0/bin/api-manager.sh start

# Admin console:      https://localhost:9443/carbon
# API Publisher:      https://localhost:9443/publisher
# Developer Portal:   https://localhost:9443/devportal
# Gateway (APIs/MCP): https://localhost:8243/

# Validar que el gateway está up (browser no funciona por cert self-signed):
curl -k https://localhost:8243
# Respuesta esperada: <H1>Welcome to APIM</H1>

# Ver logs en tiempo real:
tail -f /mnt/win/dev/wso2am-4.6.0/repository/logs/wso2carbon.log
```

### Build del API project (Maven)

```bash
cd _backend/api/ToolsAPIProject/ToolsAPIProject
./mvnw clean install
# El archivo .car deployable queda en target/
# Deploy: copiar .car a $APIM_HOME/repository/deployment/server/carbonapps/
```

### Tunnel ngrok (testing MCP con Claude real)

```bash
# Con WSO2 corriendo:
ngrok http https://localhost:8243
# Copiar la URL https://<id>.ngrok-free.app y configurarla en Claude.ai → Settings → Connectors
# La URL cambia en cada reinicio (plan free) — actualizar el connector en Claude.ai cuando cambie
```

### Sync semanal develop → develop-v3

```bash
bash scripts/dev/sync-v2-to-v3.sh
```

### Tests

[TODO: completar con PM — suite de tests v3 en construcción. Por ahora testing manual con MCP Inspector y curl.]

### Deploy a staging-v3

[TODO: completar con PM — entorno staging-v3 no configurado aún. Ver E7-CICD-04.]

---

## Data flow

```
Browser → CodeIgniter (PHP) → wso2_helper → REST.php → WSO2 APIM 4.6.0 (port 8243)
                                                            ├── Data Services (.dbs) → PostgreSQL (v3) / MySQL (v2)
                                                            ├── MCP Server (Model Context Protocol) → AI Agents
                                                            ├── API sequences → Bonita BPM (port 8080)
                                                            └── Connectors (Tango, Bascula, Firebase, WhatsApp)
```
