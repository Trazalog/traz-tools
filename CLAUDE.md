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

## 🔒 Metodología de Git — OBLIGATORIA

### Nunca commitear directo a ramas de integración
PROHIBIDO hacer commit o push directo a: develop-v3, develop, master, main.
Estas ramas están protegidas y todo cambio DEBE entrar por Pull Request.

### Flujo obligatorio para cualquier cambio
1. Sincronizar: `git checkout develop-v3 && git pull origin develop-v3`
2. Crear rama de trabajo con nombre descriptivo:
   `git checkout -b <tipo>/<issue-id>-<desc-corta>`
   (tipos: feat, fix, docs, chore, refactor)
   ejemplo: feature/E9-IDENT-12-refresh-tokens
3. Hacer TODOS los commits en esa rama (nunca en la de integración)
4. Formato de commit: `tipo(scope): descripción [ID-ISSUE]`
5. Push de la rama de trabajo: `git push origin <nombre-rama>`
6. Abrir PR: `gh pr create --base develop-v3 --head <nombre-rama>`
7. NO mergear el PR sin confirmación explícita del PM
8. NUNCA `git push` directo a develop-v3, develop, master ni main

### Antes de crear un PR
- Verificar que el build pasa (si aplica: `./mvnw clean install`)
- Verificar que no quedan marcadores de conflicto:
  `grep -rn "^<<<<<<<\|^=======\|^>>>>>>>" .`
- Verificar que no se commitean secretos (claves privadas, tokens, .env)

### Si un push a rama de integración es rechazado (protected branch)
NO intentar forzar ni desactivar la protección. Es el comportamiento correcto.
Mover los commits a una rama feature y abrir PR.

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

---

## 🧭 Metodología v2 — Contexto y estado antes de cualquier tarea

> Ver detalle completo en `TRAZALOG_v3_CICD_STRATEGY.md` sección 5-bis. Este bloque resume las obligaciones operativas para vos (Claude Code) en este repo.

### Antes de empezar CUALQUIER tarea

1. Leé `doc/v3/CONTEXT-PACK.md` completo.
2. Leé `doc/v3/STATE.md` para saber en qué sprint/estado está el proyecto.
3. **Chequeo de staleness obligatorio:** corré `ls doc/adr/` y comparalo contra el "último ADR" declarado en el encabezado del CONTEXT-PACK. Si hay un ADR más nuevo que el que el CONTEXT-PACK dice conocer, PARÁ y reportá la desincronización antes de continuar — no asumas que el resumen está actualizado.

### Jerarquía de fuentes — el CONTEXT-PACK es un resumen, no la verdad

El CONTEXT-PACK.md es un resumen operativo. La fuente canónica de arquitectura es `doc/v3/TRAZALOG_v3_MCP_ARCHITECTURE.md` + los ADR individuales en `doc/adr/`. Ante cualquier ambigüedad, contradicción, o tema que el CONTEXT-PACK no cubra:

1. Primero, leé la sección correspondiente del documento canónico.
2. Si el documento canónico tampoco lo cubre, **PARÁ**. No improvises ni tomes la decisión de arquitectura solo. Reportalo como "requiere decisión de arquitectura" (ver reglas de escalamiento abajo).

**Vos NO tomás decisiones de arquitectura.** Las toman Rodolfo y Claude Web en un workshop previo (clase 🔴 de tarea). Tu trabajo es implementar decisiones ya tomadas, y detectar cuándo una tarea te está pidiendo algo que ninguna decisión previa cubre.

### Al terminar CUALQUIER tarea (parte del Definition of Done)

1. Actualizá `doc/v3/STATE.md`: mové la tarea de "activa" a su estado final, actualizá "próxima acción", agregá la decisión relevante si hubo alguna.
2. **Si tu tarea creó o modificó un ADR:** actualizá `doc/v3/CONTEXT-PACK.md` en el MISMO PR — agregá la línea del ADR a la tabla de decisiones vigentes y hacé bump de versión en el encabezado del CONTEXT-PACK. No lo dejes para un PR aparte.
3. Abrí el PR con este formato obligatorio de descripción:

```markdown
## Qué cambia
[1-2 líneas, en términos funcionales]

## Por qué
[referencia a la tarea/issue/decisión que lo origina]

## Cómo lo verifiqué
[build / tests / curls ejecutados, con resultado]

Closes #NNN
```

### Reglas de escalamiento — cuándo parar y preguntar

| Tipo de duda | Qué hacés |
|---|---|
| Técnica menor (dos formas válidas de implementar lo mismo) | Decidís vos, documentás la elección en la descripción del PR |
| Funcional o de negocio (variantes con impacto distinto para el usuario o el modelo comercial — ej. algo que afecte tiers, límites, pricing) | PARÁS y preguntás a Rodolfo con las opciones + tu recomendación. No avanzás sin respuesta |
| Arquitectura (contradice o no está cubierto por el CONTEXT-PACK ni por el documento canónico) | PARÁS, marcás la tarea como "requiere decisión de arquitectura" en tu reporte |

**Regla de oro: ante la duda de si algo es menor o funcional, preguntá.** Preferimos una pregunta de más que un desvío de arquitectura — un desvío mal encaminado cuesta semanas de retrabajo, una pregunta cuesta un minuto.

### Clasificación de riesgo de tu tarea

Si la tarea que te llega no indica su clase, asumí por default:
- Si toca solo docs/scripts/tests/configs sin efecto en runtime ni datos → 🟢, podés ejecutar sin más validación que tu propio criterio técnico.
- Si toca código de producción (endpoints, DataServices, sequences, tools MCP) → 🟡, seguí el ciclo estándar de 4 pasos.
- Si toca identidad, seguridad, migraciones de BD, o algo que huela a cambio de arquitectura o de modelo de negocio → 🔴, no implementes nada — reportá que necesita workshop previo con Rodolfo.
