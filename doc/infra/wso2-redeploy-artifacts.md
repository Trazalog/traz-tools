# Cómo redesplegar artefactos WSO2 después de un cambio

## Objetivo

Este documento responde una sola pregunta: **cambié algo en una API, sequence o
DataService del MI, o en una spec OpenAPI publicada en el APIM — ¿cómo hago
para que ese cambio se vea reflejado en el servidor donde estoy probando?**

Está pensado para vos (Rodolfo) cuando volvés a este proyecto después de un
tiempo y no te acordás el paso exacto, y para Claude Code cuando necesita
verificar un cambio en el MI local antes de abrir un PR. No cubre cómo
instalar WSO2 desde cero (eso es `wso2-install.md`) ni cómo desplegar a la
VM de GCP (eso es `doc/v3/deployment-gcp.md`).

Hay **dos niveles** de artefactos, con mecanismos de redespliegue totalmente
distintos — la confusión más común es tratar de resolver uno con el
procedimiento del otro:

| Nivel | Ejemplos | Vive en | Redespliegue |
|---|---|---|---|
| **MI** (Micro Integrator) | APIs (`toolsMANAPI`, `toolsMCPAPI`, `toolsALMAPI`, `toolsBPMAPI`, `toolsCOREAPI`), sequences (`emprIdFromHeader`, `toolsFault`), DataServices (`ALMDataService`, `MANDataService`, etc.) | `_backend/api/ToolsAPIProject/` (Maven project, este repo) | Recompilar el `.car` y copiarlo al MI — **script**, ver §1 |
| **APIM** (API Manager / Publisher) | APIs publicadas (`Trazalog Operaciones`, `EquiposAPI-TrazalogMCP`), Virtual MCP Servers (`trazalog-operaciones`, `trazalog-equipos`) | Consola del Publisher (`:9443/publisher`) | Re-importar la spec OpenAPI — **manual, consola**, ver §2 |

---

## 1. Redesplegar artefactos del MI (APIs, sequences, DataServices)

**Cuándo:** cambiaste cualquier archivo bajo
`_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/` (por ejemplo,
agregaste una tool a `toolsMCPAPI.xml`, o una query a `ALMDataService.dbs`).

**Script (recomendado):**

```bash
./scripts/dev/rebuild-and-deploy-mi.sh
```

Hace las tres cosas en orden: compila (`./mvnw clean install`), copia el
`.car` resultante a `$MI_HOME/repository/deployment/server/carbonapps/`, y
reinicia el MI (para que tome el `.car` nuevo — copiarlo solo no alcanza si
el MI ya está corriendo).

Usar `--no-restart` si vas a copiar más de un cambio antes de reiniciar, o
si preferís reiniciar el MI vos mismo en otro momento.

**Manual, paso a paso** (si el script no te sirve por algún motivo, o para
entender qué hace):

```bash
cd _backend/api/ToolsAPIProject/ToolsAPIProject
./mvnw clean install
# el .car queda en target/ToolsAPIProject_1.0.0.car

MI_HOME=~/.wso2-mi/micro-integrator/wso2mi-4.5.0   # ajustar si es otro path
cp target/ToolsAPIProject_1.0.0.car "$MI_HOME/repository/deployment/server/carbonapps/"

# reiniciar (copiar el .car con el MI corriendo NO alcanza)
"$MI_HOME/bin/micro-integrator.sh" stop
"$MI_HOME/bin/micro-integrator.sh" start
```

**Cómo confirmar que el redespliegue funcionó:**

```bash
tail -f "$MI_HOME/repository/logs/wso2carbon.log"
```

Buscar `Successfully deployed the Carbon Application : ToolsAPIProject_1.0.0`.
Si en cambio aparece `Undeploying Carbon Application` con un error de
conexión a base de datos, es casi siempre que algún DataService (`.dbs`) no
pudo conectar a su BD al arrancar — el deploy del `.car` es **atómico**: una
sola DataService que falle tira abajo todo el paquete, incluidas las APIs
que no tienen nada que ver con esa BD. No es un bug del cambio que hiciste;
es una característica del CAR de WSO2 MI a tener presente.

**Nota sobre `scripts/dev/setup-mi-b4-car-deploy.sh`:** ese script es
anterior a este documento — quedó de una tarea puntual (ADR-008, bloqueante
B4) y **asume que el `.car` ya está compilado** (no corre Maven). Si lo usás
directamente, compilá primero a mano o usá `rebuild-and-deploy-mi.sh`, que
cubre el ciclo completo.

---

## 2. Redesplegar una API publicada en el APIM (Publisher)

**Cuándo:** cambiaste una spec OpenAPI ya publicada (por ejemplo, agregaste
una operación nueva a `doc/api/trazalog-operaciones.yaml`, o cambiaste una
descripción).

Esto **no tiene script** — es un procedimiento de consola, porque el
Publisher de WSO2 APIM no tiene una CLI/API pública simple para esto en este
entorno. Pasos (ya documentados en detalle en
[`openapi-publish-procedure.md`](../api/openapi-publish-procedure.md) §7,
resumidos acá):

1. `https://localhost:9443/publisher` (o el host del APIM correspondiente)
2. Abrir la API (ej. `Trazalog Operaciones`) → **`Edit`**
3. **`API Definition`** → **`Import`** → subir el archivo `.yaml` actualizado
4. **`Save`**
5. Si se agregaron o cambiaron `paths`/`operationId` (no solo texto de
   `description`): hace falta **`Publish`** de nuevo para que el gateway
   tome los cambios.
6. Si el cambio agregó una operación nueva y ya existe un Virtual MCP Server
   generado desde esta API: el MCP Server **no se actualiza solo** — hay que
   ir a **`MCP Servers`** → el server correspondiente → **`Tools`** → agregar
   la tool nueva a mano (o regenerarlo, según qué tan grande sea el cambio).
7. Confirmar que la API sigue asociada al Key Manager **Dnato** después de
   re-importar — re-importar no debería desasociarlo, pero conviene
   verificarlo.

**Cómo confirmar que el redespliegue funcionó:** `tools/list` contra el
Virtual MCP Server debe reflejar el cambio (nueva tool, descripción
actualizada, etc.) — ver el smoke test de
[`virtual-mcp-unificado.md`](../mcp/virtual-mcp-unificado.md) §4 como
plantilla de verificación.

---

## 3. Los dos niveles a la vez

Si el cambio toca ambos (ej: agregaste una tool nueva en `toolsMCPAPI.xml`
**y** la sumaste a `trazalog-operaciones.yaml`), hacer primero **§1** (MI) y
recién después **§2** (APIM) — el Publisher apunta al MI como backend, así
que si el MI todavía no tiene la ruta nueva, la operación nueva del APIM
va a devolver error aunque esté bien configurada del lado del Publisher.
