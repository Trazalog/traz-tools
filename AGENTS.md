# AGENTS.md — Historial de Conocimientos del Sistema

Este archivo consolida el historial de lo aprendido sobre **Trazalog Tools** en sesiones anteriores.
Sirve como memoria para tener en cuenta a la hora de programar. Los estándares detallados viven en
los skills de `.agents/skills/`; cargalos cuando la tarea corresponda.

---

## 1. Stack y Capas

1. **Frontend** — CodeIgniter 3 (PHP) HMVC, repositorio raíz. Sin build step.
2. **Integración/API** — WSO2 Micro Integrator, proyectos en `_backend/api/` (principal: `ToolsAPIProject`).
3. **BPM** — Bonita BPM, procesos en `_backend/bpm/` (`.bos`, `.bar`).

Soportes: Siddhi apps (`_backend/siddhi/`) para sincronización ERP (Tango) y app Flutter (`_backend/flutter/traza_app/`).

## 2. Arquitectura y Flujo de Datos

```
Browser → CodeIgniter (PHP) → wso2() → REST.php (cURL) → WSO2 MI (8280)
                                                                    ├── Data Services (.dbs) → DB
                                                                    ├── API sequences → Bonita BPM (8080)
                                                                    └── Connectors (Tango, Bascula, Firebase, WhatsApp)
```

- **Regla crítica:** toda la BD desde PHP pasa por WSO2 MI Data Services en `http://<host>:8280/services/`. **Nunca** hacer consultas SQL directas desde PHP para datos de negocio.
- Llamadas WSO2 siempre con el helper `wso2($url, $method, $data)`, que desenvuelve automáticamente el `request_box` (excepto endpoints BPM).
- Auto-cargados: `session`, `REST`, `BPM`, `database` + helpers `url`, `componente`, `fecha`, `timeline`, `info`, `develop`, `validacion`, `admin`, `menu`, `sesion`, `lenguaje`, `infoentidadesproceso`, `infoproceso`, `wso2`, `form`, `arbol`, `gitv`.
- Controlador por defecto: `Dash`.

## 3. Módulos y Convenciones

- Módulos en `application/modules/` con estructura `controllers/`, `models/`, `views/` (algunos con `libraries/`).
- Prefijos de nombres:
  - `traz-comp-*` — componentes compartidos (BPM, almacenes, calendar, codigos/QR, formularios, notificaciones, PAN, tareas-estandar)
  - `traz-tools-*` — herramientas funcionales (man=mantenimiento, resi=residuos)
  - `traz-prod-trazasoft`, `ddpe-tools-pro`, `sein-tools-almpantar`, `yudi-tools-almproc` — cliente específicos
- **Logging:** `log_message('DEBUG', '#TRAZA | <MODULO> | <Class> | <method>() ...')`.
- **Constantes:** prefijos de módulo (ej. `PRD`, `FRM`, `ALM`) como constantes de ruta al cargar modelos/helpers entre módulos: `$this->load->model(PRD.'Tablas')`.
- Estilos UI: AdminLTE / Bootstrap 3, botones `btn-flat`, color corporativo de encabezados `#dd4b39`.
- **Layout de pantallas con tabla (patrón consolidado):** un **único** `<div class="box box-primary">` por pantalla, con `box-header` + `box-title` (título a la izquierda, acciones a la derecha), y un solo `box-body` que apila: botones de acción → fila de filtros → `<hr>` → tabla. Ver §10.

## 4. Estándares Aprendidos (Resumen + Skills)

Cargá el skill correspondiente cuando la tarea lo requiera:

- **Archivos e imágenes Base64** → usar la herramienta `skill` con `base64-file-handling`
  - Archivos/BD: nombre original en `valor`, contenido base64 en `valor4_base64` (TEXT/BYTEA).
  - Al salir de BD puede venir como `resource` → siempre `stream_get_contents()` antes de concatenar.
  - Mapear extensión a prefijo Data URI con `obtenerExtension()` (ver `traz-comp-formularios/helpers/form_helper.php`).
  - Inputs con prefijo `-file-`; render `archivo()` / `image()`; preview con FileReader / Blob en el cliente.
  - Base64 pesa ~33% más que el binario → vigilar `upload_max_filesize`/`post_max_size`.

- **DataTables paginados server-side** → usar la herramienta `skill` con `datatable-server-side`
  - Botones Excel/PDF/Copiar/Imprimir con `dom: 'lBfrtip'` y DataTables Buttons.
  - Exportación completa en server-side: truco `dt.page.len(1000000)` + `dt.one('draw', ...)` + restaurar con `dt.page.len(oldLength).draw()`.
  - PDF con cabecera (título + logo) vía `customize`; imprimir limpiando links/scripts rotos que causan 404 `/index` en CodeIgniter.
  - Ajustar `exportOptions.columns` para excluir columnas de acciones.

## 5. Gotchas Clave

- PostgreSQL/PDO devuelven `resource` para campos `bytea`/text extensos → `stream_get_contents()`.
- En DataTables print, remover `link[href=""]` / `script[src=""]` y `tr[data-json]` para evitar 404.
- Siempre verificar los índices de columnas exportadas para no incluir botones/acciones.
- **Modales anidados (Bootstrap 3) → pantalla negra:** el segundo `.modal-backdrop` (z-index 2070 con el fix de `modal_checklist.php`) tapa todo modal hijo que quede en z-index 1050 por defecto. Todo modal que se abra sobre otro debe subir su z-index (`#mi-modal { z-index: 2080 !important; }`), ej. `modal_adjunto.php` y `#mdl-back`.
- **`bytea` en Postgres vía WSO2:** un valor como `data:image/png;base64,...` guardado en `bytea` puede volver en el JSON como base64 de ese texto (doble codificación) o como hex `\x...`, NO como `data:`. Nunca asumir el prefijo directo → usar decode defensivo (ver §6).
- **Handlers sobre tablas creadas por DataTable:** si el `<script>` está antes del HTML (vista standalone), `$('#tabla').on(...)` enlaza "nada" porque el elemento no existe aún → envolver en `$(function(){...})` o delegar en `document`.
- **`inner join` a tablas opcionales = movimientos que desaparecen:** un `INNER JOIN` a un.checklist/formulario anula la fila entera si el `info_id` es NULL. Para "traer el movimiento al menos", usar `LEFT JOIN` **o directamente sacar el join** si las columnas no se usan (ver §10).

## 6. Lecciones Recientes — Módulo `traz-comp-pan` / Herramientas

Sesión donde se trabajó la **vista QR pública de herramienta** (`Herramienta::vistaQrHerramienta()` → `views/herramienta/vista_qr_herramienta.php`) y el modal de edición/consulta (`modals/modal_editar.php`, tab "movimientos_herramientas" → trazabilidad / certificaciones / checklists).

### Vista QR standalone
- Es una página **autónoma** (su propio `<head>`, jQuery + Bootstrap + DataTables/Buttons). **NO carga** `alertify`, `swal`, `wo()/wc()` ni helpers de sesión → los handlers no pueden usarlos.
- `$data` embebidos como JS: `MOVIMIENTOS`, `CERTIFICACIONES`, `CHECKLISTS` + `CHECKLIST_DETALLES` (formularios armados server-side por `obtenerFormularioChecklist($info_id)` → evita AJAX/sesión/CSRF en la vista pública).
- No tiene `#mdl-back` (es del layout global) → si se replica algo del backend que lo use, hay que agregar un shell `<div class="modal modal-fade" id="mdl-back"></div>` en la página.

### Adjuntos de certificaciones (decode defensivo)
Patrón `parseAdjunto(adjunto, adjunto_nombre)` (duplicado en `vista_qr_herramienta.php` y `view_.php`), el adjunto puede llegar así:
1. Data URI directo `data:mime;base64,<b64>` → MIME del prefijo + base64 interno.
2. **base64 de un Data URI** (WSO2 devuelve el `bytea` codificado) → `atob()` una vez y reprocesar.
3. Hex de Postgres `\x....` → convertir bytes a texto y reprocesar.
4. base64 puro → fallback por extensión (y si `adjunto_nombre` es NULL, agregar `.png/.pdf` desde el MIME).

- **El MIME se saca del prefijo `data:`**, NUNCA de la extensión (`adjunto_nombre` es nullable y suele venir NULL).
- `mimeToIcon()` → ícono de la tabla según MIME real (imagen/PDF/video/audio), no un `fa-file-text-o` fijo.
- `base64ToBlob()` con chunking (512 bytes) para Chrome con archivos grandes; `URL.revokeObjectURL()` en `hidden.bs.modal`.

### Trazabilidad: impresión de vale
- La acción de la col. "Acciones" de trazabilidad es un **ícono print** (`fa-print`), SOLO cuando `tipo_movimiento` es ENTRADA/SALIDA y hay `nro_vale`; onclick `imprimirVale(nro_vale, tipo)`.
- `imprimirVale()` hace AJAX GET a `Vales/printVale/{id}/{tipo}` (controller `Vales.php`, vista `views/vales/vale.php` que es un fragmento `.modal-dialog`), inyecta en `#mdl-back` y `modal('show')`. Ojo: en vista standalone la función debe ser **global** (fuera de `$(function(){})`) porque el `onclick` la busca en `window`.
- `Vales::printVale` carga el modelo `Movimientosherramientas` (`obtenerSalidaSepaId`/`obtenerEntradaEnpaId`) + formulario dinámico por `info_id`.

### Lupa de checklists
- En el backend la lupa `.btnInfoDinamico` (col. info_id) abre `#modalchecklist` en modo lectura vía `verChecklist` (AJAX) y `llenarItemsChecklist` (agrupa CHECK por `name`). En la vista QR se hace server-side (modo solo lectura, modal `#modal-checklist-detalle`).

### Ruteo de interés
- Endpoints PAN vía WSO2 `PANDataService` (`REST_PAN = HOST.'/services/PANDataService'`, ver `application/config/constants.php`): `/certificaciones/herramienta`, `/herramientas/movimientos`, `/checklists/paginado`, `/certificacion` (POST), `/checklist` (POST).
- `traz-comp-pan` es un **submódulo git** (`.git` propio; `vista_*` puede estar untracked → el rename no afecta git).
- Lint PHP en Windows: `C:\xampp\php\php.exe -l <archivo>`.

## 7. WSO2 Data Services — dónde viven los `.dbs` (v2.5+)

### ⛔ Regla: preguntar antes de tocar un `.dbs`
- **Cada vez que vaya a modificar un dataservice (`.dbs`), SIEMPRE consultarle al developer** si lo modifico yo o si lo modifica él. No editarlo por iniciativa propia ni "de paso".
- Motivo: los `.dbs` se despliegan a mano con `scripts/dev/rebuild-and-deploy-mi.sh`, el SQL no se puede inventar desde el PHP (ver "Drift" más abajo) y el developer puede tener el SQL real en la consola de WSO2 o querer applyar cambios por su cuenta.
- Cuando el `.dbs` sea necesario para el cambio, dejarlo **documentado y explícito** en el plan (o en el doc de análisis) con el `<query>`/`<resource>` a agregar, para que él pueda aplicarlo.
- Los cambios de `.dbs` que el developer aplicó a mano (caso PAN, filtro por encargado de pañol) quedan como cambios locales en el working tree: `_backend/api/ToolsAPIProject/.../data-services/PANDataservice.dbs`. **No commitearlos sin que él lo pida.**

- **Ruta única y oficial:** `_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/data-services/*.dbs`.
- La carpeta vieja **`_backend/api/dataservice/` fue eliminada** en develop (commit `b35c0441`, "una sola copia de cada artefacto"). Hasta v2.4 los `.dbs` estaban **duplicados** ahí y en `ToolsAPIProject`, y las copias podían divergir.
- `scripts/deploy/deploytools.sh` es el que deploya: lee de `$ARTEFACTOS/data-services/` (`ARTEFACTOS=<producto>/_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts`). El script viejo leía de la carpeta eliminada y **el `cp` fallaba en silencio**, dejando el DEMO con dataservices viejos. Si agregás un `.dbs` nuevo, va en la ruta de arriba y nada más.
- Los `.dbs` de **submódulos** se buscan aparte, en `<submodulo>/api/dataservice/` (el producto puede no tener backend WSO2 propio).
- `toolsBPMAPI.xml` fue renombrado a `toolsbpmAPI.xml` (commit `edc1b9e3`): el archivo y el `name` had binding **must match** o WSO2 no lo despliega.

### Drift repo ↔ WSO2 desplegado (deuda conocida)
- El `.dbs` commiteado puede estar **muy por detrás** de lo que hay desplegado en el servidor. Hay operaciones que se crearon en la consola de WSO2 y nunca se commitearon.
- **Caso PAN:** el código llama 14 endpoints que **no existen** en `PANDataservice.dbs` commiteado → `/herramientas/paginado`, `/herramienta/{id}`, `/herramientas/tipos`, `/herramientas/tipos/eliminar`, `/inhabilitacion`, `/herramientas/movimientos`, `/certificacion`, `/certificaciones/herramienta`, `/checklist`, `/checklists/paginado`, `/herramientas/estado/{estado}`, `/movimientos/herramientas`, `/panol/salida/{id}`, `/panol/entrada/{id}`. Funcionan contra el WSO2 local pero el repo no los documenta.
- Para agregarlos hay que escribir el `<query>` + `<resource>` en `PANDataservice.dbs` (ruta nueva). **No se puede inventar el SQL** desde el PHP: hay que sacarlo del WSO2 o del modelo.
- Los endpoints `_*_batch_req` (`/_put_herramientas_estado_batch_req`, `/_post_panol_entrada_herramientas_detalle_batch_req`, …) son **auto-derivados** por `enableBatchRequests="true"` a partir de un `<resource>` que ya existe → no necesitan entrada propia.

### Estilo de `PANDataservice.dbs`: es REST por recursos, no por operaciones
- No busca `<operation name="...">`: son **30 `<query>` + 30 `<resource>`, cero `<operation>`**. El mapeo URL→SQL vive en `<resource method="GET" path="/ruta/{param}">`. Para saber si un endpoint existe hay que grepear `path=`, no `operation`.
- Además tiene recursos con `path` **sin** slash inicial (`path="equipos/{empr_id}"`), lo que hace que un grep por `/equipos` no matchee.

## 8. Git — subir una rama de trabajo a `develop` con submódulos

El repo tiene **14 submódulos** en `application/modules/`. El orden importa: **submódulos primero, superproyecto después.** Al revés, el puntero del submódulo queda viejo y hay que commitear dos veces.

### Antes de empezar
- Diagnosticar si hay algo que mergear. `git log --oneline origin/develop..HEAD` **vacío** = tu rama ya está mergeada y lo que falta es trabajo **sin commitear**, no merge. Mergear develop no te "pierde" nada.
- Comparar contenido real, no commits: `git diff --stat pmarrelli develop`. En los submódulos suele dar **vacío** aunque develop tenga commits "nuevos" (son merges de tu propia rama). Solo los merges contam.
- Chequear qué archivos del working treealso tocaron develop: `git diff --name-status origin/pmarrelli origin/develop -- <tus archivos>`. Es la lista real de conflictos, mucho más chica que "39 commits de diferencia".
- Lint PHP de todo lo que se va a commitear **antes** de commitear: `C:\xampp\php\php.exe -l <archivo>`. Con `git status --porcelain -uall` (el `-uall` es necesario: sin él los directorios sin trackear vienen colapsados y los archivos adentro se escapan del filtro).

### Secuencia (3 repos: codigos, pan, superproyecto)
```
git add -A && git commit -m "..."      # en el submódulo
git push origin pmarrelli
git checkout develop && git merge pmarrelli --no-edit && git push origin develop
git checkout pmarrelli && git merge --ff-only develop   # deja pmarrelli == develop
git push origin pmarrelli
```
El `merge --ff-only develop` al final alinea `pmarrelli` con el commit de merge, para que el superproyecto registre punteros de la rama de trabajo y no del develop viejo.

### En el superproyecto
- `git checkout develop && git pull` puede mover **muchos** archivos y dejar punteros de submódulos viejos en disco → `git status` los muestra como ` M` aunque no tengas nada sin commitear. **NO son cambios tuyos.** Se arreglan con `git submodule update <path>` (seguro si el submódulo tiene 0 archivos sin commitear: `git -C <path> status --porcelain`).
- `git checkout develop` **no toca** el working tree de los submódulos. `git submodule update` **sí**, y con cambios sin commitear puede fallar o pisar trabajo → no correrlo a mitad de un merge.

### Resolución de conflictos
- En un merge, **`--ours` = la rama en la que estás** (develop) y `--theirs` = la que mergeás. Para respetar develop: `git checkout --ours <archivo>`.
- Un archivo que develop y vos cambiaron en la **misma línea** (p.ej. un link en un layout) siempre conflicto, aunque los cambios sean conceptualmente distintos. En `.gitignore`, si ambos agregan al final del archivo, conflicto seguro aunque las reglas no se pisen: hay que unificar a mano conservando **los dos** bloques.
- `git diff --name-only --diff-filter=U` lista los paths sin resolver. `git commit` se niega hasta que los resuelvas con `git add`.

### `.gitignore` del proyecto
- `application/config/constants.php` está en `.gitignore` **pero sigue trackeado** (se commiteó antes de ignorarse). Ignorarlo no lo des-trackea: `git ls-files` lo sigue listando y sus cambios se commitean igual. Para dejar de trackearlo hace falta `git rm --cached`.
- El `.gitignore` de develop ignora `.claude/settings.local.json` y `.claude/worktrees/` (pero versiona `.claude/commands/`). `.agents/` y `AGENTS.md` también quedan ignorados localmente.
- `codigosQR/` genera PNGs al probar las vistas públicas de QR (665-901 bytes cada uno, en carpetas por módulo) → ignorado, no versionar.

### Ruido de line-endings
- `core.autcrlf=true` global y **no hay `.gitattributes`** → diff con ruido de CRLF. `git diff --ignore-cr-at-eol` separa el ruido del cambio real (en una sesión: 3.737 vs 3.625 líneas, ~110 de ruido). Git normaliza a LF al commitear, así que lo que sube está bien; el ruido solo afecta la lectura del diff.
- **No confundir esto con un cambio real:** si el `--ignore-cr-at-eol` también muestra diferencias, son contenido de verdad.

### Commits
- Estilo de `pmarrelli`: mensajes cortos en español, sin prefijo (`sincro`, `sincro almacenes`, `QR-residuos`). develop v2.5/v3 usa conventional commits en inglés (`fix(core): ...`). Merge: `Merge branch 'pmarrelli' into develop`.
- `git status` en PowerShell: el output de `git push` va a **stderr**, que PowerShell envuelve como `NativeCommandError` aunque el push haya funcionado. Filtrar con `| Select-String "->|rejected"` y **mirar el `->`**, no el error.

## 9. Verificación post-merge
- `git status -sb` limpio + `git rev-list --left-right --count develop...origin/develop` = `0 0`.
- `git submodule status` **sin prefijos** `+` (checkout adelantado) ni `-` (atrás) ni `U` (conflicto).
- `git log --oneline origin/develop..pmarrelli` vacío = nada quedó sin subir.
- Ojo con `contributing.md`: en el repo estaba el **stock de CodeIgniter** en inglés desde el commit inicial, mientras el disco tenía la versión custom de Trazalog Tools. Nunca se commiteó. Un `git add -A` a secas lo sube como borrado de 79 líneas.

## 10. Lección Reciente — Layout de pantallas con tabla + "inner join" que anula el movimiento

Sesión de refactor de UI y de un bug de datos en `traz-comp-pan`. Dos temas independientes que conviene no mezclar.

### (a) Layout: un solo box, tabla adentro del filtro

Patrón consolidado para pantallas AdminLTE de este proyecto (aplicado en `herramienta/view_.php` y `movimientosherramientas/view_.php`):

- **Un único `<div class="box box-primary animated fadeInLeft">`** por pantalla, NO un box por cada sección. Antes había 2-3 (header, filtros, tabla) y se veían como cajas flotando separadas.
- Estructura: `box-header` (título a la izquierda + botón de acción a la derecha) → `box-body` → botones de acción → fila de filtros → `<hr>` → tabla.
- El botón "Agregar" va en el `box-header` con `pull-right`, o arriba a la izquierda de los filtros según el diseño; **no** en su propio box.
- `.box-tools` de AdminLTE es `position:absolute; right:10px; top:5px` → para alinear un botón a la derecha del header usar **flexbox inline** (`display:flex; justify-content:space-between; align-items:center`) en vez de `pull-right`, que desalinea verticalmente.
- **`.box-body { padding: 10px }` y `.box { margin-bottom: 20px }`** (AdminLTE por defecto). Con varios boxes apilados, ese `margin-bottom` + los paddings anidados acumulan decenas de px de espacio gris entre secciones. Unificar en un box y bajar el `padding` a `5px` (o 0) cuando la tabla va a ras.
- El HTML de la tabla va en un archivo aparte que se inyecta por AJAX en un `<div id="cargar_tabla">` (`.load(...)`). Ese fragmento **solo debe contener la `<table>` + su `<script>`**, nunca un `<section class="content">` ni otro `.box` — si no, mete un box adentro de otro con todo el padding extra.
- Los selectores JS de los filtros (`#filtro_esta_id`, `#tipo_movimiento`, etc.) y el `#cargar_tabla` se acceden **por id**, nunca por posición ni por clase de contenedor → mover/mezclar el HTML entre boxes es seguro. Verificar igual que el `<script>` que llama al `.load()` quede **después** del div destino en el DOM.

### (b) "inner join" a tabla opcional = datos que desaparecen (vale de impresión)

Bug: al imprimir un vale sin formulario/checklist asociado (`info_id` NULL) salía "No se encontraron datos" en vez del vale.

- En `PANDataservice.dbs`, las queries `getSalidaxSapaId` / `getEntradaxEnpaId` tenían `inner join frm.instancias_formularios t on t.info_id = <mov>.info_id` solo para exponer `t.label, t.valor`. Como el `inner join` no matchea si `info_id` es NULL, **el movimiento entero desaparecía** (no solo las columnas del form).
- El `vale.php` nunca usa `label`/`valor` del endpoint PAN (las del form salen de `$cabecera`/`$form_dinamico`, poblados en otro lado), así que **el join era completamente innecesario**. Fix: quitar el `inner join` + las columnas `t.label, t.valor` del `select`. Alternativa would've sido `left join` si esas columnas fueran necesarias.
- Lección: antes de tocar SQL de un `.dbs`, verificar (a) si la columna del join se usa en el mapeo JSON `<result>` del `.dbs` (puede estar en el `select` pero no en el output) y (b) si el consumidor PHP realmente la lee. Ambos se chequean rápido con grep.
- Patrón de robustez en la vista de impresión: en vez de `if (count($data)>0) { ...todo... } else { "sin datos" }`, normalizar primero (`$filas = is_array($data) ? $data : []; $primera = $filas[0] ?? null;`) y renderizar siempre, dejando los campos de cabecera en blanco con `isset($x->campo) ? ... : ''` si faltan. El botón "Imprimir" también debe quedar siempre visible.

## 11. Lección Reciente — Recepción de herramientas: el destino NO es un filtro de la lista

Sesión en `traz-comp-pan`: se implementó el **filtro por encargado de pañol** (`pan.encargado_panol`) y se corrigió la recepción. Deploy y verificación funcional OK (probado por el developer).

### (a) El bug de negocio: receptionar en cualquier pañol
- Recepción (`Unload`) y entrega (`Order`) son **simétricas pero con reglas distintas**:
  - **Entrega**: depósito → pañol → herramientas **de ese pañol**. El pañol es parte del filtro. **No tocar.**
  - **Recepción**: listar **todas** las herramientas en `TRANSITO` de los pañoles del usuario desde que se abre el modal, y poder **ingresar a cualquier pañol** a cargo del usuario. El pañol es solo el **destino** del ingreso, no acota la lista.
- Antes el endpoint exigía `pano_id` y usaba `filtrarHerramientasPorPano()` → lista vacía sin destino, y la herramienta de otro pañol nunca aparecía. Por eso el `Swal` "fue Entregada en X, ¿la recepcionás en Y?" **existía pero era código muerto**; con el fix empezó a dispararse.
- Fix backend (`controllers/Unload.php::obtenerHerramientasPanol()`): filtro plural + guarda de autorización **condicional**:
  ```php
  if ( !empty($pano_id) && !usuarioManejaPano($pano_id) ) { echo json_encode(array()); return; }
  $resp = filtrarHerramientasPorPanosDelUsuario($this->Unloads->obtenerHerramientasPanol());
  ```
  El `pano_id` es **datos no confiables del POST**: si viene, se valida contra los pañoles del usuario (evita un POST directo pidiendo herramientas de un pañol ajeno); si no viene, se ignora. `usuarioManejaPano('')` devuelve `false` → por eso el `!empty()` es obligatorio, si no la carga al abrir el modal vuelve a salir vacía.
- El estado `TRANSITO` no se filtra en PHP: ya viene del modelo (`Unloads::obtenerHerramientasPanol()` → `/herramientas/estado/TRANSITO`).

### (b) Helper plural en `sesion_helper.php` (duplicado en core y módulo)
- `filtrarHerramientasPorPanosDelUsuario($herramientas)`: `normalizarLista()` → `array_map('strval', filtrarbyPano())` → si vacío **no restringe** (mismo criterio que el resto de filtros por usuario) → si no, `array_filter` comparando `strval(valorCampo($herr,'pano_id'))` con `in_array(..., true)`.
- **Comparar siempre con `strval()` en los dos lados:** la API puede devolver `"3"` y `filtrarbyPano()` devuelve `3`; el `===` estricto con tipos distintos filtraría todo en silencio.
- `sesion_helper.php` vive **duplicado** en `application/helpers/` y en `application/modules/traz-comp-pan/helpers/`. El autoload carga el de core, pero un módulo puede pedir el suyo → **los helpers de permisos se agregan/actualizan en las dos copias**.

### (c) select2: nunca armar options por string HTML, ni placeholder como nodo de texto
- `views/unloads/view_.php`: `cargarHerramientasEnTransito()` se llama **al abrir el modal** (al final del `<script>`), sin `pano_id`. Se removió el AJAX de herramientas del `$("#pano_id").change` (ese handler solo recarga encargados) y el de `$("#esta_id").change`.
- Agrupar por pañol de origen con `<optgroup label="…">` para que se vea de qué pañol viene cada herramienta; cada option conserva `data-pano_id` y `data-pan_descrip`.
- **Armar las options como nodos DOM** (`new Option(texto, id, false, false)` + `.append()` + `.trigger('change')`), no con `$('#tools').html('<option ...>')`: (a) es el patrón que ya usa `orders/view_.php`, (b) `new Option()` escapa el texto solo, (c) `.html()` no refresca bien en algunas versiones de select2. Así no hace falta ningún `escHtml()`.
- **Placeholder = `<option value="">`, nunca nodo de texto.** `$('#tools').append('Seleccione una herramienta')` no crea una option y `find(':selected').val()` devuelve `undefined`, así que el guard clásico `if (seleccionado == undefined) return;` funciona por casualidad y **deja agregar filas vacías** en cuanto existe una option real con value vacío. El guard correcto es `if (!seleccionado) return;` → cubre placeholder, "sin herramientas" y "error al cargar" con un solo caso.
- El mensaje de lista vacía también va como `option` (`- No hay herramientas en tránsito -`) para que el usuario no sospeche que el combo se rompió.

### (d) Otros gotchas de la sesión
- **`.data('pano_id')` funciona con `data-pano_id`:** jQuery convierte a camelCase solo las mayúsculas (`/[A-Z]/g`), así que el `_` se respeta y busca el atributo tal cual. No renombrar a `data-panoId` sin cambiar el JS.
- Agregar una función JS nueva en un `<script>` inline: **definirla antes de su llamada** (si es `function` declaration el hoisting la salva igual, pero no si es `function` expresión).
- **`edit` falla con "oldString not found" en archivos con acentos** si el string del `oldString` no es byte-idéntico al del archivo (encoding/CRLF). Para eliminar una línea problemática, borrar por número: `[System.IO.File]::ReadAllLines($f)` + `WriteAllLines` con índices, en vez de pelear con el matcher.
- PowerShell: `Get-Content` de archivos UTF-8 **mojibakea los acentos en la consola** (sale `paol`). No es que el archivo esté roto → no "corregir" acentos basándose en lo que muestra la consola.
- El botón "Agregar" de `herramienta/view_.php` quedó en **su propio box** con `btn btn-block btn-primary` (redondeado, sombra) — **excepción explícita al patrón de §10(a)**, pedido así por el developer. No volver a "unificar en un único box" ni a `btn-flat` ese botón.
- Análisis y plan de esta sesión en `doc/analisis/impacto-filtro-encargado-panol.md` (checklist con el estado de avance, incluidos los `.dbs` que aplica el developer a mano).