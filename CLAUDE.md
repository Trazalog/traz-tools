# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**traz-tools** is Trazalog Tools — an industrial asset/process management platform. It serves sectors such as industrial maintenance, agro-industry, and oil & gas.

The system is composed of three main layers:
1. **Frontend** — CodeIgniter 3 (PHP) HMVC web application (repo root)
2. **Integration/API layer** — WSO2 Micro Integrator (WSO2 MI) projects under `_backend/api/`
3. **BPM** — Bonita BPM engine process definitions under `_backend/bpm/`

Supporting components:
- **Siddhi apps** (`_backend/siddhi/`) — WSO2 Streaming Integrator event processing apps for data synchronization (e.g., Tango ERP sync)
- **Flutter mobile app** (`_backend/flutter/traza_app/`) — companion mobile app

---

## Architecture

### Data Flow

```
Browser → CodeIgniter (PHP) → wso2_helper → REST.php library → WSO2 MI (port 8280)
                                                                    ├── Data Services (.dbs) → DB
                                                                    ├── API sequences → Bonita BPM (port 8080)
                                                                    └── Connectors (Tango, Bascula, Firebase, WhatsApp)
```

All database access from the PHP frontend goes through WSO2 MI Data Services at `http://<host>:8280/services/`. Direct DB queries from PHP do **not** occur for business data.

### Frontend (CodeIgniter HMVC)

- Modules in `application/modules/` using a custom HMVC loader (`MY_Loader.php`, `MY_Router.php`)
- Module naming conventions:
  - `traz-comp-*` — shared components (BPM, almacenes/warehouses, calendar, codigos/QR, formularios/forms, notificaciones, PAN, tareas-estandar)
  - `traz-tools-*` — functional tools (man=maintenance, resi=residuos/waste)
  - `traz-prod-trazasoft` — Trazasoft product module
  - `ddpe-tools-pro`, `sein-tools-almpantar`, `yudi-tools-almproc` — client-specific modules
- Auto-loaded libraries: `session`, `REST`, `BPM`, `database`
- Auto-loaded helpers: `url`, `componente`, `fecha`, `timeline`, `info`, `develop`, `validacion`, `admin`, `menu`, `sesion`, `lenguaje`, `infoentidadesproceso`, `infoproceso`, `wso2`, `form`, `arbol`, `gitv`
- Default controller: `Dash` (main dashboard after login)
- `application/libraries/REST.php` — cURL wrapper for all HTTP calls
- `application/libraries/BPM.php` — Bonita BPM integration
- `application/helpers/wso2_helper.php` — `wso2($url, $method, $data)` function; main abstraction for all WSO2 MI calls. Automatically unwraps `request_box` responses for non-BPM calls.

### WSO2 Micro Integrator (API Layer)

- Primary project: `_backend/api/ToolsAPIProject/ToolsAPIProject/` — Maven-based WSO2 MI project (use `./mvnw` or `mvn`)
- APIs defined in `src/main/wso2mi/artifacts/apis/`:
  - `toolsCOREAPI.xml` — core user/session/config operations
  - `toolsBPMAPI.xml` — BPM process integration
  - `toolsLogAPI.xml` — logging
  - `toolsMANAPI.xml` — maintenance module
- Data Services (`.dbs`) in `src/main/wso2mi/artifacts/data-services/` — each module has its own: `COREDataService`, `ALMDataService`, `MANDataService`, `FRMDataService`, `LOGDataService`, etc.
- Connectors in `_backend/api/`: `BasculaConnector`, `TangoConnectorAPI`, `FirebaseConnectorAPI`, `gestionadoresResiduosAPI`
- `_backend/api/apiconfig.xml` — defines `api_url` and `dataservices_url` endpoints
- `_backend/api/bpmconf.xml` — defines Bonita BPM URL and credentials

### BPM (Bonita)

- Process definitions (`.bos`) and deployable archives (`.bar`) in `_backend/bpm/`
- Bonita runs at `http://localhost:8080/bonita`
- Process instances are created from PHP via `BPM.php` library and the `toolsBPMAPI.xml` in WSO2 MI

---

## Development Setup

### PHP Frontend

The app runs as a standard Apache/Nginx + PHP site. No build step required.

```bash
# Install PHP dependencies (CodeIgniter is vendored, but check composer.json)
composer install

# Configure base URL and DB connection
# application/config/config.php  — base_url is auto-detected from HTTP_HOST
# application/config/database.php — set DB credentials
```

Configure WSO2 endpoint in `_backend/api/apiconfig.xml` and update `application/libraries/REST.php` or the module that reads the config if the WSO2 host changes.

### WSO2 Micro Integrator

The `ToolsAPIProject` is a Maven project. Use **WSO2 Integration Studio** (Eclipse-based) or **VS Code with WSO2 MI extension** to develop.

```bash
# Build the CAR (Composite Application Archive) for deployment
cd _backend/api/ToolsAPIProject/ToolsAPIProject
./mvnw clean install

# The deployable .car file is output to target/
```

Deploy the generated `.car` file to a running WSO2 MI instance by placing it in `<MI_HOME>/repository/deployment/server/carbonapps/`.

### Siddhi Apps

Siddhi apps (`_backend/siddhi/*.siddhi`) are deployed to WSO2 Streaming Integrator. Copy the `.siddhi` file to `<SI_HOME>/deployment/siddhi-files/`.

### Bonita BPM

Import `.bos` files into Bonita Studio. Deploy `.bar` files to a running Bonita server.

---

## Key Conventions

- **Logging**: Use `log_message('DEBUG', '#TRAZA | <MODULE> | <Class> | <method>() ...')` pattern throughout PHP code for consistent traceability.
- **WSO2 calls from PHP**: Always use the `wso2($url, $method, $data)` helper. Response data is automatically unwrapped from `request_box` for non-BPM endpoints.
- **Module structure**: Each module follows `controllers/`, `models/`, `views/` layout. Some modules include a `libraries/` directory for module-specific third-party libs (e.g., KoolReport for PDF reports).
- **Constants**: Module prefixes (like `PRD`, `FRM`, `ALM`) are used as path constants when loading models/helpers across modules (e.g., `$this->load->model(PRD.'Tablas')`).
