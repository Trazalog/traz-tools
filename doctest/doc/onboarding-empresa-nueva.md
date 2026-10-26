# Onboarding de una empresa nueva en AssetPlanner (full seed)

## Objetivo

Guía **autocontenida** para dejar operativa una empresa **recién registrada** en AssetPlanner:
qué datos maestros cargar, **en qué orden** (hay dependencias), en qué pantalla y con qué campos,
hasta poder recorrer el ciclo de una Orden de Trabajo con herramientas y pañol (maqueta F3-F6).
Está escrita para que **una persona o un agente de IA** acompañe a un cliente nuevo en su primer
arranque, cuando la empresa está **vacía** (sin equipos, herramientas, artículos ni OTs).

Cada paso dice **dónde** se ejecuta (menú y URL dentro de AssetPlanner) y qué campos pide. No cubre
el alta de la empresa en sí (eso es la registración de Trazalog, previa a esta guía) ni la
administración avanzada. El circuito automatizado equivalente vive en
`doctest/tests/e2e/flows/` (spec `CICLO-UC-001`), que ejecuta y captura este mismo recorrido.

> **Dónde se opera todo:** AssetPlanner — `https://<host>/tools/traz-prod-assetplanner` —
> con el usuario **administrador** de la empresa (el correo con que se registró). Verificado en DEMO:
> ese admin entra a AssetPlanner y tiene en el menú Mantenimiento, Pañol y Almacenes.

---

## Orden de carga (por dependencias)

```
Maestros base (Equipo los exige, y están vacíos al empezar):
  área · proceso · criticidad · etapa · grupo · marca
        └── Equipo  (Mantenimiento → Equipos)
Pañol:
  marca · depósito ── Herramienta (Pañol → Herramientas)
                        └── Salida de Herramientas (Pañol → Salida Herramientas)  → asocia la OT (F6)
Almacén:
  unidad de medida ── Artículo (Almacenes → Artículos)
                        └── Stock (Almacenes → Stock) → Entrega (F4)
Ciclo:
  Equipo ── Solicitud de Servicio (Mantenimiento → Solicitud de Servicio)
              └── Orden de Trabajo → Informe de Servicio (F3 texto libre, F4 entregas, F5 herramientas usadas)
```

---

## Pasos

<!-- Se completa a medida que se releva/automatiza cada flujo. -->

### 1. Maestros base para el Equipo

**Dónde:** AssetPlanner → menú **Mantenimiento → Equipos** (`/Equipo`) → botón **Agregar**
(abre el formulario de alta de equipo).

Al abrir el alta, los combos **Área, Proceso, Criticidad, Etapa, Grupo, Marca** están **vacíos**
(empresa nueva). Cada uno tiene al lado un botón **Agregar** que abre un modal chico para crearlo
sin salir de la pantalla:

| Combo | Botón | Qué se escribe | Queda en |
|---|---|---|---|
| Área | Agregar (área) | Nombre o descripción (ej. *Área Minería*) | tabla `area` |
| Proceso | Agregar (proceso) | Nombre o descripción (ej. *Molienda*) | tabla `proceso` |
| Criticidad | Agregar (criticidad) | Descripción (ej. *Alta*) | — |
| Etapa | Agregar (etapa) | Descripción (ej. *Operación*) | — |
| Grupo | Agregar (grupo) | Descripción (ej. *Bombas*) | — |
| Marca | Agregar (marca) | Descripción de la marca (ej. *ACME*) | tabla `marcasequipos` |
| **Unidad industrial** | Agregar (unidad) | Nombre (ej. *Planta Principal*) | tabla `unidad_industrial` |
| **Cliente** | Agregar (cliente) | Razón social (ej. *Cliente Interno*) | tabla `admcustomers` |

> ⚠️ **CRÍTICO — sin Unidad Industrial y Cliente el equipo NO aparece en el listado.** El listado
> de equipos (`Equipos->equiposPaginados`) hace `INNER JOIN` con `unidad_industrial` y con
> `admcustomers` (cliente), además de sector/criticidad/área/proceso. Una empresa recién registrada
> **no tiene ninguna unidad ni cliente** (verificado en DEMO: `getunidad` → "nada"), así que un equipo
> cargado sin ellos **se guarda pero queda invisible** — y la **Solicitud de Servicio no lo encuentra**.
> Por eso hay que crear **al menos una unidad industrial y un cliente** antes del primer equipo.
> _(Es, muy probablemente, una falta de la registración: debería dejar una unidad/establecimiento por defecto. Anotar como hallazgo.)_

Al guardar cada modal, el valor queda **seleccionado** en su combo. Hacé esto una vez; después
quedan disponibles para todos los equipos. **Marca es opcional** para dar de alta el equipo.

### 2. Equipo

**Dónde:** el mismo formulario de **Mantenimiento → Equipos → Agregar**, una vez creados los maestros.

Campos a completar:

| Campo | Ejemplo | Obligatorio |
|---|---|---|
| Código | `EQ-001` | sí (identifica el equipo) |
| Descripción | Bomba centrífuga 100HP | sí |
| Número de serie | `SN-0001` | — |
| Ubicación | Planta 1 | — |
| Fecha de ingreso / garantía | 2026-01-10 / 2027-01-10 | — |
| Área / Proceso / Criticidad / Etapa / Grupo | los creados en el paso 1 | sí |
| Marca | la creada en el paso 1 | opcional |

**Guardar.** El sistema confirma *"Guardado exitoso de nuevo equipo"*. Con un equipo ya se puede
pedir un servicio (paso 6).

> Automatización: `flows/seed-asset.ts → seedEquipo()` crea los maestros y el equipo por los mismos
> endpoints que usa la UI (`Equipo/agregar_*` y `Equipo/guardar_equipo`).

### 3. Herramienta (Pañol)

**Dónde:** AssetPlanner → **Pañol → Herramientas** (`/Herramienta`) → botón **Agregar**.

Campos: **Código** (ej. `HRR-001`), **Descripción** (ej. Taladro percutor), **Modelo** (ej. TP-500),
**Marca** (combo — usa las mismas marcas que el equipo, `marcasequipos`; si está vacío, cargá una) y
**Depósito** (combo). **Guardar**.

> Notas verificadas en DEMO (2026-10-26) — anotar como hallazgos:
> - Una empresa recién registrada **no trae ningún depósito/pañol** (`getdeposito` → "nada"). La
>   herramienta se puede crear igual (depósito opcional), pero para la **salida de herramientas**
>   (vale, paso 4) conviene tener un depósito. _(Falta relevar dónde se crea el depósito.)_
> - El **código de equipo** se valida único **global** (no por empresa): usar códigos irrepetibles.
>
> Automatización: `flows/seed-asset.ts → seedHerramienta()` (endpoint `Herramienta/agregar_herramienta`).

### 4. Salida de Herramienta / vale (Pañol) — asocia la OT (F6)
_(pendiente)_

### 5. Artículo y Stock (Almacenes)
_(pendiente)_

### 6. Solicitud de Servicio → Orden de Trabajo

**Dónde:** AssetPlanner → **Mantenimiento → Solicitud de Servicio** (`/Sservicio`) → **Nueva solicitud**.

Se elige el **equipo** que falla (tiene que estar listado — ver paso 1-2) y se describe la **falla**.
Al confirmar, el sistema **inserta la solicitud y lanza el proceso de mantenimiento en Bonita**
(`Sservicio/lanzarProcesoBPM`). Verificado en DEMO: responde `{"status":true,"msj":"OK"}`.

> La **OT no se genera sola**: la solicitud entra al proceso y lo primero es el **análisis del
> Supervisor** (Planificar Solicitud → Asignar Recursos y Tareas). Recién ahí se genera la Orden de
> Trabajo. En la empresa nueva, el usuario que haga de supervisor avanza esos pasos desde su bandeja
> de tareas. _(La orquestación por código está en el controller `Calendario`.)_

> Automatización: `flows/seed-asset.ts → crearSolicitudServicio()`. El avance del proceso hasta la
> OT se automatiza en la fase siguiente del spec `CICLO-UC-001`.

### 6-bis. Generar la Orden de Trabajo (avanzar el proceso) — MAPA para continuar

La OT se genera cuando el **supervisor planifica** la solicitud. En la UI: **Mantenimiento → Plan de
Mantenimiento** (`/calendario/indexot`), se toma la solicitud de la bandeja y se la planifica
(tarea + fecha/hora/recursos). Eso postea a **`Calendario/guardar_agregar`**, que crea la OT y
cierra las tareas Bonita ("Planificar Solicitud").

**Payload de `guardar_agregar` (correctivo), del código:** `event_tipo=1`, `id_sol=<id solicitud>`,
`id_tarea=<tarea>`, `ide=<id equipo>`, `tipo=2`, `fecha_progr=dd-mm-yyyy`, `hora_progr=HH:MM`,
`descripcion`. Internamente: `getInfoTareaporIdSolicitud(id_sol,'correctivo')` → `{taskId,caseId}` →
`cerrarTarea` → genera la OT.

**Estado verificado en DEMO (oct 2026):**
- La **solicitud se crea bien** mandando `equipo=<ID del equipo>` (NO el código: `setservicios` lee
  `post('equipo')` primero como id_equipo; si va el código, la solicitud queda ligada a un id_equipo
  inválido y no lista por el INNER JOIN a equipos/sector). Su id se obtiene de `Sservicio/paginado`
  (la fila trae `id_solicitud`, `estado`, `case_id`, e `id_orden` cuando ya hay OT).
- `id_tarea` **no es obligatorio** para el correctivo básico (confirmado por el PM).
- **El paso de ANÁLISIS del supervisor** (compuerta *¿Es Urgente?* del BPM) se cierra con
  **`Tarea/decidirUrgencia`** (`idTarBonita` + `opcion` → contrato Bonita `esUrgente`). Según la
  opción, el proceso va a **urgente** (lo planifica el Supervisor) o a **backlog** (lo planifica el
  Planificador). Luego **`Calendario/guardar_agregar`** crea la OT (**tipo 2** correctivo/urgente,
  **tipo 4** backlog; MAN-UC-009).

**Mapa de los 3 caminos (BPM "Proceso de Mantenimiento AssetPlanner"), para los 3 doctests de regresión:**
1. **SS Urgente**: `lanzarProcesoBPM` → `decidirUrgencia`(urgente) → `guardar_agregar`(tipo 2) →
   asignar responsable (`Tarea/...`) → `Tarea/ejecutarOT`.
2. **SS Backlog**: `lanzarProcesoBPM` → `decidirUrgencia`(no urgente) → editar backlog →
   `guardar_agregar`(tipo 4) → asignar → ejecutar.
3. **OT por planificación** (no es SS): planificación directa del supervisor → `guardar_agregar`.

> ⛔ **Blocker verificado en DEMO (necesita dev/pruebas):** la tarea Bonita *"Análisis de Solicitud de
> Servicio"* **no aparece en la bandeja** del admin (`Tarea/paginado` → 0), así que no se obtiene el
> `idTarBonita` para cerrarla. Es un tema de **ruteo/asignación de tareas de Bonita** (qué actor/usuario
> Bonita recibe la tarea en una empresa nueva, y si hay que reclamarla primero). `getInfoTareaporIdSolicitud`
> la resuelve internamente (`ObtenerActividades` sobre el caseId) pero no la expone por endpoint. **Este es
> el único punto que el código solo no alcanza a destrabar** — requiere ver el entorno de desarrollo:
> por qué la tarea no cae en la bandeja / qué usuario Bonita la toma. Resuelto eso, los 3 doctests se
> arman con la secuencia de arriba.

### 7. Informe de Servicio: F3 (texto libre), F4 (entregas), F5 (herramientas usadas)
_(pendiente — una vez generada la OT: `Ordenservicio/cargarOrden/<ot>/0/0/0` para F3/F5 y
`Calendario/verEjecutarOT/<ot>` para F4; selectores en el spec de la maqueta
`tests/e2e/07-ciclo-ot-herramientas-entregas.spec.js` de asset)_

---

## Hallazgos para `doc/hallazgos/REGISTRO.md`
1. **La registración no deja una `unidad_industrial` ni un cliente por defecto** → los equipos no
   listan (INNER JOIN del paginado) y no se puede pedir un servicio. (§1)
2. **El código de equipo se valida único GLOBAL**, no por empresa. (§2)
3. **La solicitud liga mal el equipo si se manda el código en `equipo`**: `setservicios` toma
   `post('equipo')` como id_equipo, así que hay que mandar el **id**. (§6-bis)
4. El comentario de `LoginManPage.ts` sobre #489 está **desactualizado**: el admin de una empresa
   registrada SÍ entra a AssetPlanner.
