# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Qué es Trazalog Tools

**Trazalog Tools** es una suite de gestión industrial para PyMEs argentinas (mantenimiento, almacenes, workflows BPM, residuos). En v3 incorpora una **capa MCP (Model Context Protocol)** que expone operaciones del sistema a agentes de IA de forma estandarizada. El foco estratégico actual es el sector de **proveedores de servicios mineros en San Juan**, Argentina, que enfrenta demanda urgente de profesionalización ante el arranque de grandes proyectos mineros (~2027).

**v2** corre en producción en `cloudtrazalog.com`. **v3** está en desarrollo activo en la rama `develop-v3`.

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
├── doc/
│   └── v3/                 — Documentos de arquitectura y estrategia v3
└── scripts/                — Scripts de utilidad (deploy, setup, etc.)
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

## Convenciones de branching

| Rama | Propósito |
|---|---|
| `master` | Producción — solo recibe merges desde `develop` (v2) o `develop-v3` (cutover final) |
| `develop` | Soporte v2 — no recibe cambios estructurales nuevos |
| `develop-v3` | Desarrollo activo v3 — rama base para todo trabajo nuevo |
| `feature/<id>` | Features individuales — PR a `develop-v3` (v3) o `develop` (v2) |

**Regla clave**: `develop` se sincroniza a `develop-v3` semanalmente (E7-CICD-06). No hacer esa sync manualmente.

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

[TODO: completar con PM — detallar stack docker/local, vars de entorno, archivo .env si aplica]

### WSO2 API Manager 4.6.0 (v3)

```bash
# Admin console: https://localhost:9443/carbon
# API Publisher: https://localhost:9443/publisher
# Developer Portal: https://localhost:9443/devportal
# Gateway (invocación APIs): https://localhost:8243/

# Iniciar WSO2 APIM
$APIM_HOME/bin/api-manager.sh start   # Linux/Mac
# Requiere JDK 21 Temurin en $JAVA_HOME
```

[TODO: completar con PM — proceso de deploy del CAR en APIM 4.6.0, pasos de configuración de MCP server]

### Build del API project (Maven)

```bash
cd _backend/api/ToolsAPIProject/ToolsAPIProject
./mvnw clean install
# El archivo .car deployable queda en target/
# Deploy: copiar .car a $APIM_HOME/repository/deployment/server/carbonapps/
```

### Tests

[TODO: completar con PM — suite de tests v3 en construcción. Por ahora testing manual.]

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
