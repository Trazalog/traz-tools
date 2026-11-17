# Prompt para Claude Code — Relevamiento de los formularios dinámicos (insumo para el ABM de DNATO v3)

> Pegar completo en una sesión de Claude Code abierta en la carpeta que contiene los repos hermanos `traz-comp-dnato` y `traz-tools` (y el submódulo `traz-comp-formularios` inicializado en los dos lugares donde aparece).
> Modo: **solo lectura** sobre el código. El único archivo que se escribe es el informe.

---

## Rol y regla de oro

Sos un analista funcional y arquitecto de software. Tu tarea es **relevar cómo funcionan hoy los formularios dinámicos** de la suite Trazalog, tal como están construidos, sin proponer nada todavía. El informe es el insumo para especificar un ABM de formularios dinámicos en DNATO v3 (Portal de la empresa + Consola del súper usuario). Hoy se customizan a mano en la base de datos y no hay pantalla.

Regla de oro: **todo lo que afirmes debe estar respaldado por un archivo y una línea** (`ruta:línea`). Si algo no lo encontrás, escribí "NO ENCONTRADO" y qué buscaste. Nunca reconstruyas de memoria ni completes con lo que "debería" existir. Si una duda bloquea el relevamiento, preguntame antes de seguir.

Contexto ya conocido del relevamiento anterior (`doc/v3/dnato/DNATO_v2_RELEVAMIENTO.md`), que debés verificar y ampliar, no repetir:
- El módulo vive en el submódulo git `traz-comp-formularios` (pin `d1cc7f9`, tag `v1.8.5.1`) y hay una copia vieja versionada en `traz-comp-dnato/application/modules/{controllers,models,helpers,views}`.
- Tablas vistas de pasada: `frm.formularios`, `frm.items`. Modelo `Forms` (`obtener`, `obtenerPlantilla`, `listado`, `guardar`, `actualizar`). Helper `form_helper.php` con funciones globales `form`, `input`, `select`, `check`, `radio`, `textarea`, `image`, `number`. Vista `scripts.php`.
- DNATO lo usa para el formulario de registro (`FORMULARIO_REGISTRO_ID = 72`, `Register::register_success`, `Main::guardarFormularioRegistro`). El trigger de alta de empresa (`traz-tools/_backend/database/scripts/versiones/v2.8.1.3/configuracion_inicial_empresa_trg_func.sql`) crea filas en `frm.*`.
- Los controllers `application/modules/controllers/Form.php` no son ruteables (no hay HMVC); el módulo se carga con `require_once` directo.

## Alcance del relevamiento

### 1. Modelo de datos completo del esquema `frm`
- Todas las tablas, vistas y funciones del esquema `frm` (y cualquier otra tabla que guarde definiciones o respuestas de formularios dinámicos, aunque esté en otro esquema). Fuente: dumps, scripts `*.sql`, `.dbs` de WSO2, models.
- Para cada tabla: columnas, claves, FK reales o por texto, y **para qué sirve**. En particular distinguí:
  - la **definición** del formulario (cabecera): nombre, código, empresa (`empr_id` nulo = global?), estado, versión, a qué entidad o pantalla se asocia;
  - los **ítems** (campos): tipo, etiqueta, orden, obligatorio, valores posibles (listas), validaciones, agrupación o secciones, condicionales (si existen);
  - las **respuestas / instancias** (lo que carga el usuario): dónde se guardan, cómo se vinculan con la entidad de negocio (equipo, OT, artículo, empresa, usuario…), si se versionan.
- Diagrama Mermaid `erDiagram` con lo encontrado.
- Confirmá o negá: ¿la visibilidad "global para todas las empresas" se modela con `empr_id` nulo en la cabecera? ¿Hay otro mecanismo (empresa 0, tabla puente, flag)?

### 2. Catálogo de tipos de ítem
- Lista exhaustiva de tipos de campo soportados por el código (`form_helper.php` y donde se rendericen), con: nombre interno, cómo se guarda su valor, qué opciones admite (lista de valores fija, lista desde tabla, multi-selección, imagen, archivo, fecha, número con unidad, texto largo, etc.), validaciones que aplica y cómo se dibuja (HTML generado).
- Qué pasa con un tipo desconocido.
- Si hay listas de valores: de dónde salen (`core.tablas`, tabla propia, valores inline en el ítem) y si pueden ser por empresa.

### 3. Quién usa formularios dinámicos y cómo se elige cuál
Este es el punto central. Recorré **toda la suite** (`traz-comp-dnato`, `traz-tools` y sus módulos `application/modules/*`) buscando usos del módulo (`Forms`, `getForm`, `obtenerPlantilla`, `FRM`, `frm.`, `formulario`, `form_id`, `info_id`, `require_once ... traz-comp-formularios`).
- Tabla: **pantalla o ABM → módulo/repo → cómo pide el formulario (por id fijo, por código, por entidad + empresa) → qué formulario recibe si la empresa tiene uno propio y si no → dónde guarda la respuesta**.
- Explicá con evidencia **la regla de resolución** "para esta pantalla y esta empresa, qué formulario se muestra": ¿busca primero el de la empresa y si no el global? ¿Está hardcodeado el id por pantalla (como `FORMULARIO_REGISTRO_ID = 72`)? ¿Hay una tabla que asocie pantalla/entidad ↔ formulario ↔ empresa?
- Diagrama Mermaid `sequenceDiagram` del flujo: pantalla → resolución → render → guardado.

### 4. Cómo se customizan hoy "a mano"
- Reconstruí, a partir de scripts SQL, docs, prompts o bitácoras del repo, el procedimiento que hoy se sigue para crear o modificar un formulario para una empresa: qué filas se insertan, en qué orden, qué ids se copian, qué se duplica (¿se clona el global y se edita la copia?).
- Scripts encontrados que lo hagan (`scripts/*.sql`, `development/*.sql`, `_backend/database/...`), con ruta.
- Qué hace el trigger de alta de empresa sobre `frm.*`: ¿copia formularios globales para la empresa nueva o solo referencia?

### 5. Ciclo de vida y riesgos
- ¿Se puede modificar un formulario que ya tiene respuestas cargadas? ¿Qué pasa con las respuestas viejas si se borra o renombra un ítem? ¿Hay versionado?
- Baja lógica o física; estados (borrador, activo, inactivo).
- Validaciones en servidor vs solo en el navegador.
- Multi-empresa: ¿todas las consultas de respuestas filtran por `empr_id`? Listá métodos del modelo `Forms` con ✓/✗ como en la auditoría de aislamiento del relevamiento anterior.
- Diferencias entre la copia vieja en `traz-comp-dnato/application/modules/*` y el submódulo (qué agrega la versión nueva).

### 6. UI actual
- Cómo se renderiza un formulario dinámico dentro de una pantalla (parcial, modal, página entera), con qué assets (`views/scripts.php`, `public/lib/props/forms.js` que no existe, etc.).
- Capturas textuales de dos usos distintos (por ejemplo, el registro y un ABM de negocio).

### 7. Lo que NO existe
Listá explícitamente, con qué buscaste: ABM de formularios por pantalla; clonar formulario global para una empresa; ordenar ítems arrastrando; vista previa; versionado; export/import; asociación pantalla↔formulario administrable; permisos sobre quién edita formularios.

## Entregable

Un único archivo: `doc/v3/dnato/FORMULARIOS_DINAMICOS_RELEVAMIENTO.md` en `traz-tools`, con:

1. Resumen ejecutivo (10 líneas): qué son los formularios dinámicos hoy, dónde se usan, cómo se resuelve cuál mostrar, los 5 hallazgos más importantes.
2. Secciones 1 a 7 en ese orden, con tablas y diagramas Mermaid.
3. "Lo que NO existe".
4. "Dudas para el PM" (numeradas): todo lo que no pudiste resolver leyendo el código. Incluí sí o sí estas, si el código no las responde:
   - ¿El formulario de una empresa **reemplaza** al global en esa pantalla o se **suma** a él?
   - ¿Una pantalla puede tener más de un formulario (por tipo de equipo, por etapa)?
   - ¿Las respuestas viven junto a la entidad de negocio o en una tabla genérica de respuestas?
   - ¿Qué formularios globales existen hoy en producción y cuáles tiene cada empresa? (dar la consulta SQL para obtenerlo, no ejecutarla).
5. Anexo: inventario de archivos recorridos.

No escribas nada más en el repo. No modifiques código. No hagas commit. Al terminar, pegá en el chat el resumen ejecutivo, la regla de resolución (sección 3) y las dudas.
