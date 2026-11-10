# REQ-017 · Módulo Administración — Formularios globales en Tools

## Objetivo

Decimoséptimo trabajo de Pablo para el módulo **Administración** (`traz-comp-adm`), aunque casi todo pasa
**fuera** del módulo, en el núcleo de Tools: que los combos de formularios de tareas estándar, subtareas y
etapas muestren también los **formularios globales**, que el **alta de empresa** deje de clonar desde la
empresa plantilla 9000 y apunte a los globales, y el pase **mínimo** de los formularios de la 9000 que usa
ese alta. Lo leen Pablo para planificar y Rodolfo para aprobar el análisis de impacto. **No** toca cómo se
muestran, se dibujan o se completan los formularios en Tools (prohibido en este plan) ni hace la migración
completa de formularios; las pantallas del ABM están en [REQ-015](REQ-015-administracion-formularios.md).
Lista completa en [`README.md`](README.md).

| Campo | Valor |
|---|---|
| Estado | **Borrador**: Rodolfo tiene que contestar las dudas de los casos, correr (o hacer correr) la verificación §8.5 en producción y aprobar el análisis de impacto. Nace el 2026-11-10 con lo que salió de REQ-015 por decisión de Rodolfo |
| Se apoya en | [REQ-015](REQ-015-administracion-formularios.md) (columna `estado` de `frm.formularios`, tabla `seg.formularios_puntos_uso` con su "Global al alta", estructura de `frm.*` versionada), [REQ-002](REQ-002-administracion-esqueleto.md); relevamiento [`doc/v3/dnato/FORMULARIOS_DINAMICOS_RELEVAMIENTO.md`](../doc/v3/dnato/FORMULARIOS_DINAMICOS_RELEVAMIENTO.md) (§4.2, §8 y decisiones D1 a D3); análisis previo del clonado [`doc/analisis/impacto-config-formulario-entrega-alta.md`](../doc/analisis/impacto-config-formulario-entrega-alta.md) |
| Entrega de la especificación | Parte de **E11b** de `doc/v3/dnato/PROMPT_CLI_DNATO_V3_BUILD.md`: configuración al alta (RF-127, reemplaza el clonado del disparador), punto T-8 de `02_MODELO_Y_REGLAS.md` (combos), y de M-7b / RF-131 **solo** el pase de los formularios de la 9000 que usa el disparador. CP-127, la parte de combos de CP-130 y la parte mínima de CP-132 |
| Casos de uso | `ADM-UC-290` a `ADM-UC-292` en `doctest/catalogo/adm/` (rango reservado 290 a 309) |
| Repos que se tocan | `traz-tools`: `FRMDataService.dbs` (consulta existente `getFormularios`), una versión nueva de la función del disparador `core.configuracion_inicial_empresa_trg` y un script de datos. **No** se toca `traz-comp-formularios`, ni las pantallas de tareas estándar, subtareas ni etapas, ni `traz-comp-adm` |
| Riesgo | 🔴 **Núcleo de Tools, las tres cosas**: (1) se **modifica un DataService existente** (`FRMDataService.getFormularios`), que llenan los combos de tres pantallas de producción; (2) se **modifica un disparador existente** del schema `core` (`configuracion_inicial_empresa_trg`), que corre en **toda** alta de empresa, por cualquier canal; (3) la migración **cambia filas existentes** (`frm.formularios.empr_id` de la 9000 pasa a vacío). → **Rodolfo aprueba el análisis de impacto (sección "Análisis de impacto en Tools") y el script antes de construir.** Lo que es aditivo (la fila de "Global al alta" en `seg.formularios_puntos_uso`, tabla nueva de REQ-015; las filas **nuevas** de configuración en `core.tablas` para cada empresa nueva) lo decide el equipo (reglas de Rodolfo del 2026-11-10) |

---

## Para qué sirve

- Hoy un formulario global (sin empresa, decisión D1) **no se puede elegir** en los combos de tareas
  estándar, subtareas y etapas: la consulta filtra solo `empr_id = :empr_id` (`FRMDataService.dbs:6`). Lo
  que se arma como global en la Consola (REQ-015) no sirve para esas pantallas.
- Hoy el alta de empresa **copia** "Entrega Materiales" de la empresa plantilla 9000 a cada empresa nueva
  (disparador v2.8.1.3, relevamiento §4.2). Cada empresa nueva suma un formulario más que nadie mantiene,
  y la marca "Global al alta" que guarda REQ-015 no la usa nadie.
- Para que el alta apunte a un global, ese global tiene que existir: hoy el formulario que se copia es de
  la 9000, no global.

## Quién lo usa

- **Planificador** (o quien arme tareas estándar y etapas): ve los globales en los combos.
- **Superusuario**: da de alta empresas en la Consola (REQ-008) o en DNATO; elige el "Global al alta" de
  cada punto de uso (REQ-015).
- **Visitante**: se autorregistra y su empresa nueva pasa por el mismo disparador.
- **Administrador** de una empresa existente: no tiene que notar ningún cambio en sus pantallas de
  almacén y pañol.

## Qué tiene que hacer

0. **Primera tarea de Pablo, de solo lectura, antes de escribir nada:** sacar de la base de DEMO la
   definición **actual** de la función del disparador (`select pg_get_functiondef('core.configuracion_inicial_empresa_trg'::regproc)`)
   y compararla con `_backend/database/scripts/versiones/v2.8.1.3/configuracion_inicial_empresa_trg_func.sql`.
   Si difieren, **para y avisa a Rodolfo** (regla del núcleo productivo: lo desplegado manda). Rodolfo hace
   lo mismo en producción. Sin caso propio: se revisa en "Cómo se revisa".
1. Que los combos de formularios de **tareas estándar, subtareas y etapas** muestren primero los
   formularios **publicados** de la empresa y después los globales **publicados**, con "(global)" al
   lado del nombre (decisiones D2 y D3, punto T-8) → **ADM-UC-290**.
2. Que el **alta de empresa** deje de clonar desde la 9000 y escriba la configuración de la empresa nueva
   apuntando, por referencia, al "Global al alta" de cada punto de uso (RF-127) → **ADM-UC-291**.
3. Pasar a globales **solo** los formularios de la 9000 que usa el disparador ("Entrega Materiales") y
   marcarlo como "Global al alta" de `formulario_entrega_materiales` → **ADM-UC-292**.

## Qué NO hace

- **No toca cómo se muestran, se dibujan o se completan los formularios en Tools** (prohibición del plan,
  decisión de Rodolfo del 2026-11-10): nada dentro de `traz-comp-formularios`. En particular, **F-1 no se
  hace**: si la empresa nueva no tiene su lista de opciones, los campos de lista del global se ven vacíos,
  **igual que hoy** con el clon (el disparador nunca copió las listas, relevamiento §4.2).
- **No cambia las pantallas** de tareas estándar, subtareas ni etapas: solo cambia lo que devuelve la
  consulta que llena sus combos (mismo contrato: `form_id`, `nombre`, `descripcion`).
- **No hace la migración completa M-7b / RF-131** (decisión de Rodolfo del 2026-11-10): no pasa a
  globales las listas de opciones de la 9000, no asigna a su cliente los formularios sin empresa, no pasa
  los demás formularios de la 9000 (el del registro, entre otros), no completa los puntos de uso de las
  empresas existentes ni arma el informe de pañol.
- **No toca las empresas existentes**: conservan su clon y su configuración (ver el análisis de impacto).
- **No toca el formulario del autorregistro** ni `REGISTER_TEMP_EMPR_ID='9000'` de DNATO.
- **No cambia la parte del disparador que no es de formularios** (menús, superadministrador, listas de
  valores por defecto): se copia tal cual.

---

## Cómo se arma

### (vi) Consulta `getFormularios` — `FRMDataService.dbs`

Archivo: `_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/data-services/FRMDataService.dbs`,
consulta `getFormularios`, recurso `GET /formularios/{empr_id}` (líneas 5-9 y 31-35 en `develop`).
Verificado: en `develop`, `develop-v3` y `master` es la misma consulta vieja
`select * from frm.formularios where empr_id = cast(:empr_id as integer) and eliminado != 1`.

Consulta nueva (forma, Pablo la ajusta):

- trae los de la empresa **o** sin empresa: `(f.empr_id = cast(:empr_id as integer) or f.empr_id is null)`;
- `f.eliminado != 1`, como hoy;
- **estado** (T-8, columna de REQ-015): `coalesce(f.estado, 'publicado') = 'publicado'`, así un formulario
  en borrador o inactivo no se ofrece;
- nombre: `case when f.empr_id is null then f.nombre || ' (global)' else f.nombre end`;
- orden: primero los de la empresa, después los globales, y por nombre dentro de cada grupo.

El resultado sigue con las mismas tres claves (`form_id`, `nombre`, `descripcion`), así que ningún llamador
cambia. **Antecedente:** en el repositorio local de Rodolfo hay una rama `feat/frm-formularios-globales-en-combos`
(commit `e9663b73`, sin subir y sin pull request) con esta misma consulta **sin** el filtro de estado;
Pablo puede partir de ahí y sumarle el estado.

Hay una copia vieja del mismo DataService en `esb/dataservices/FRMDataService.xml` con la consulta vieja;
**no** se toca (duda de ADM-UC-290).

### (vii) Disparador de alta — `core.configuracion_inicial_empresa_trg`

Hoy (v2.8.1.3, `…/v2.8.1.3/configuracion_inicial_empresa_trg_func.sql:94-129`), en un bloque propio:

1. busca en la 9000 el formulario "Entrega Materiales" no eliminado más nuevo (`:98-105`);
2. si existe, copia la cabecera con el `empr_id` nuevo (`:109-113`) y sus ítems no eliminados (`:116-120`);
3. escribe `core.tablas ('configuraciones', 'formulario_entrega_materiales', <form_id del clon>, empr_id)` (`:123-124`);
4. si algo falla, solo `raise warning` y el alta sigue (`:126-128`).

Versión nueva (carpeta de versión nueva en `_backend/database/scripts/versiones/`, número **[SUPUESTO]**:
la siguiente a `v2.8.1.4`), `CREATE OR REPLACE` de la **misma** función, idéntica salvo ese bloque, que pasa
a hacer:

1. por cada fila de `seg.formularios_puntos_uso` con `form_id_alta` cargado, si ese formulario existe, es
   global (`empr_id` vacío), no está eliminado y está `publicado`:
   `insert into core.tablas (tabla, valor, descripcion, empr_id) values ('configuraciones', <clave>, <form_id_alta>::text, new.empr_id)`;
2. **no** crea ningún formulario ni ítem;
3. si algo falla, `raise warning` con el mismo prefijo `CONFINICEMP:` y el alta sigue, como hoy.

Así cubre también los puntos de pañol que hoy nadie siembra, en cuanto el superusuario les elija un
"Global al alta" en la Consola (REQ-015). Las filas que escribe son **nuevas** (la empresa recién nace).

### (viii) Pase mínimo de la 9000 a globales

Script de datos, en **la misma transacción** que el cambio del disparador (para que nunca haya un alta con
el disparador viejo y el formulario ya global, o al revés):

1. identifica el formulario con **la misma consulta** que usa hoy el disparador (`empr_id = 9000`,
   `nombre = 'Entrega Materiales'`, no eliminado, el `form_id` más alto) y **guarda su `form_id`** en el
   registro del script (para la vuelta atrás);
2. `update frm.formularios set empr_id = null where form_id = <ese>` (cambia **una** fila existente);
3. lo deja `publicado` (la columna `estado` de REQ-015 ya trae ese valor por defecto);
4. carga ese `form_id` como `form_id_alta` de `formulario_entrega_materiales` en `seg.formularios_puntos_uso`
   (tabla nueva de REQ-015: lo decide el equipo);
5. es repetible: si ya corrió, no hace nada.

No toca sus ítems, ni sus listas de opciones en `core.tablas`, ni las respuestas, ni ningún otro formulario
de la 9000.

### Orden de despliegue

1. Script de base de REQ-015 (columna `estado`, tabla `seg.formularios_puntos_uso`): sin eso, la consulta
   nueva y el disparador nuevo fallan.
2. (vii) + (viii) juntos, en una transacción.
3. (vi), **después** de que Rodolfo revise el resultado de la verificación §8.5 en producción.

(vi) y (vii)+(viii) se pueden desplegar por separado; las dos dependen de REQ-015.

---

## De dónde sale cada dato

| Dato | De dónde | Cómo |
|---|---|---|
| Formularios para los combos | `FRMDataService GET /formularios/{empr_id}` | **Existente, se modifica** la consulta `getFormularios` (núcleo) |
| Puntos de uso con su "Global al alta" | `seg.formularios_puntos_uso` | Tabla nueva de REQ-015, leída por el disparador |
| Configuración de la empresa nueva | `core.tablas` (`configuraciones` / `formulario_<punto>`) | Filas nuevas escritas por el disparador (como hoy, pero apuntando al global) |
| Estado del formulario | `frm.formularios.estado` | Columna nueva de REQ-015 |

No hay recursos nuevos en `ADMDataService` ni pantallas nuevas del módulo.

---

## Pantallas

No hay pantallas nuevas. Cambia solo lo que muestran tres combos existentes de Tools (sin tocar su
código, por eso no llevan `data-testid` del módulo):

| Pantalla de Tools | Dónde está el combo | Qué cambia |
|---|---|---|
| Tareas estándar → alta / edición de tarea | `traz-comp-tareasestandar/views/tareas/form.php:25` (`selectFromFont` sobre `REST_FRM.'/formularios/'.empresa()`) | Aparecen los globales publicados después de los propios, como "<nombre> (global)"; los borradores e inactivos ya no aparecen |
| Tareas estándar → subtareas | `traz-comp-tareasestandar/views/tareas/subtareas.php:37` (mismo helper) | Ídem |
| Producción → ABM de etapas | `traz-prod-trazasoft/controllers/general/Etapa.php:746` → `Forms::listarFormularios()` (`traz-comp-formularios/models/Forms.php:541-548`, en el commit de `develop`) → `views/etapa/abm_etapa/view_.php:97-98` (alta) y `:214-215` (edición) | Ídem |

Texto que agrega la consulta: " (global)" después del nombre (D3).

## Reglas

1. Los combos muestran los propios **publicados** de la empresa y después los globales **publicados**; nunca
   los de otra empresa (RF-130).
2. Un formulario en borrador o inactivo no se ofrece en los combos (T-8).
3. El alta de empresa **no crea** formularios: apunta la configuración de cada punto de uso a su "Global al
   alta", si existe, es global y está publicado (RF-127).
4. Si un punto no tiene "Global al alta", o el global no está publicado, la empresa nueva queda sin fila
   para ese punto ("No se especificó un formulario", como hoy cuando no hay).
5. Una falla en ese bloque no frena el alta de empresa (como hoy).
6. Las empresas existentes no cambian.
7. Del pase a globales, solo el formulario que usa el disparador; ningún otro.

## Registro en el log

No hay código PHP nuevo. El disparador deja `raise warning 'CONFINICEMP: …'` como hoy si falla el bloque de
formularios; el script de (viii) informa el `form_id` que pasó a global.

---

## Datos

| Tabla | Cambio | Quién decide |
|---|---|---|
| `frm.formularios` | `empr_id` de **una** fila existente ("Entrega Materiales" de la 9000) pasa a vacío | **Rodolfo** (cambia una fila existente) |
| `seg.formularios_puntos_uso` (nueva, REQ-015) | `form_id_alta` de `formulario_entrega_materiales` = ese formulario | El equipo (tabla nueva) |
| `core.tablas` | Filas **nuevas** `configuraciones/formulario_<punto>` de cada empresa **nueva** (las escribe el disparador) | El equipo (filas nuevas, regla de Rodolfo del 2026-11-10) |
| `core.configuracion_inicial_empresa_trg()` | Versión nueva de la función existente | **Rodolfo** (objeto existente del núcleo) |
| `FRMDataService.getFormularios` | Consulta modificada | **Rodolfo** (DataService existente) |

---

## Análisis de impacto en Tools — lo aprueba Rodolfo antes de construir

Verificado contra `origin/develop` (y, para el DataService y el disparador, también contra `master`, que es
igual) y contra los submódulos en el commit al que apunta `develop`.

### Qué pantallas usan esos combos

| Pantalla | Llamador | Qué hace con lo que recibe |
|---|---|---|
| Tareas estándar (alta y edición) | `traz-comp-tareasestandar/views/tareas/form.php:25` → `selectFromFont` (`traz-prod-trazasoft/helpers/componente_helper.php:81-89`) | Arma un `<option>` por formulario con `form_id` y `nombre`. Al guardar usa solo `form_id`; al instanciar, `models/Tareas.php:215-217` crea la respuesta con `Forms->guardar(form_id)`, que no mira la empresa |
| Subtareas | `traz-comp-tareasestandar/views/tareas/subtareas.php:37` → mismo helper | Ídem |
| Etapas productivas | `traz-prod-trazasoft/controllers/general/Etapa.php:746` → `traz-comp-formularios/models/Forms.php:541-548` (`listarFormularios`, llama a `/formularios/`.empresa()) → `views/etapa/abm_etapa/view_.php:97-98, 214-215` | Ídem; al guardar, si no viene `form_id` lo pone en nulo (`Etapa.php:764-765`) |

No se encontraron otros llamadores del recurso (buscado `/formularios/` y `listarFormularios` en los
submódulos de Tools, `_backend`, `esb` y en AssetPlanner). El contrato no cambia (mismas claves), así que
ninguno se rompe por la forma. Lo que sí cambia, a propósito:

- **Aparecen los formularios sin empresa** en los combos de **todas** las empresas. Hoy no aparecía ninguno.
  Riesgo: si en producción hay formularios sin empresa que son de un cliente (relevamiento §8.5, consulta
  **no corrida**), se verían en todas las empresas → la verificación §8.5 en producción es **condición**
  para desplegar (vi) (duda de ADM-UC-290).
- Después de (viii), "Entrega Materiales (global)" aparece en esos combos de todas las empresas; las que ya
  tienen su clon ven además "Entrega Materiales" (el suyo).
- **Editar una tarea o etapa cuyo formulario quedó inactivo:** como la consulta ya no lo trae, el combo de
  edición no lo tiene y, en etapas, guardar lo deja en nulo (`Etapa.php:764-765`). Hoy no pasa porque todos
  los formularios nacen `publicado` (valor por defecto de REQ-015); solo puede pasar cuando alguien inactive
  uno en el ABM (duda de ADM-UC-290).

### Qué hace hoy el disparador y quién depende de lo que clona

- El disparador `configuracion_inicial_empresa_ai` (`AFTER INSERT ON core.empresas`,
  `…/v2.8.1.2/configuracion_inicial_empresa_trg.sql`) corre en **toda** alta de empresa: autorregistro de
  DNATO, alta del superusuario en DNATO, la registración copiada del módulo (REQ-003) y el alta de la
  Consola (REQ-008, vía `API_CORE/empresa`). Por eso el cambio vale igual para todos los canales.
- Lo que clona lo usan: la **entrega de materiales** de almacenes (`Entrega_Material.php:50` lee
  `configuraciones/formulario_entrega_materiales` y dibuja por número; la vista lee `comprobante`,
  `solicitante` y `dni` del formulario, relevamiento §5.1). Dibujar por número **no mira la empresa del
  formulario** (relevamiento §8.2), así que apuntar al global funciona igual que apuntar al clon.
- Las listas de opciones: el clon nunca las copió (§4.2), y se buscan con la empresa de quien mira
  (`Forms.php:228-231`). Con el global pasa **exactamente lo mismo**. No hay diferencia para el usuario.
- La única diferencia visible: la empresa nueva ya no tiene un formulario **propio** "Entrega Materiales"
  en su ABM (REQ-015); si quiere cambiarlo, usa "⧉ Usar como base" del global.

### Qué pasa con las empresas existentes

- **Conservan sus copias y su configuración**: ni el disparador nuevo ni el script tocan sus formularios,
  ítems, respuestas ni filas de `core.tablas`. Las que apuntan al 26 u otro número siguen igual
  (`doc/analisis/impacto-config-formulario-entrega-alta.md`, "Compatibilidad").
- La 9000: su formulario pasa a global; las respuestas que tenga se siguen viendo (se dibujan desde su
  propia copia, relevamiento §5.1) y si la 9000 tiene una fila de configuración apuntando a ese número, sigue
  funcionando (por número). El registro de DNATO no usa ese formulario (usa el suyo, con número fijo).

### Cómo se vuelve atrás

| Pieza | Vuelta atrás |
|---|---|
| (vi) DataService | Volver a desplegar la versión anterior de `FRMDataService.dbs` (revertir el commit). Mismo contrato: no hay datos que arreglar |
| (vii) + (viii), juntos | En una transacción: reaplicar `v2.8.1.3/configuracion_inicial_empresa_trg_func.sql` (`CREATE OR REPLACE`) **y** devolver el formulario a la 9000 (`update frm.formularios set empr_id = 9000 where form_id = <el guardado por el script>`), y vaciar su `form_id_alta`. Hay que hacer las dos: el disparador viejo busca en la 9000 |
| Empresas creadas mientras estuvo el cambio | Quedan apuntando a ese `form_id`; siguen funcionando (por número). No hace falta arreglarlas |

### Qué pruebas DocTest hay que correr o actualizar

- **Correr sin cambios (regresión):** ALM-UC-010 (entregar contra pedido) y ALM-UC-011 (entrega directa),
  que usan el formulario de entrega en una empresa **existente**; ALM y PAN de `regresion` en verde.
- **Correr y ampliar:** `doctest/tests/e2e/specs/dnato/DNATO-UC-002-005.alta-de-empresa.spec.ts`
  (DNATO-UC-004, alta con configuración inicial) y DNATO-UC-023 (alta desde la administración): hoy no
  revisan formularios; con este cambio hay que comprobar que la empresa nueva apunta al global y que no se
  creó ningún formulario suyo (ADM-UC-291).
- **No hay casos DocTest de tareas estándar, subtareas ni etapas**: los cubre ADM-UC-290 (nuevo).
- Las cargas de datos de DocTest que crean una empresa nueva van a quedar con el global en vez del clon:
  ALM-UC-011 sobre una empresa nueva tiene que seguir en verde **[SUPUESTO]**.

---

## Decisiones tomadas

- **Combos, disparador y pase mínimo salen de REQ-015 a este requerimiento** (decisión de Rodolfo del
  2026-11-10): cada uno toca el núcleo y lleva su propio análisis de impacto.
- **Se modifica la consulta existente**, no se crea una nueva (decisión D2 del relevamiento), y el
  "(global)" lo pone la consulta (D3).
- **Solo publicados en los combos** (T-8): un borrador o un inactivo no debería poder elegirse para una
  tarea nueva.
- **Migración mínima**: solo el formulario que usa el disparador (decisión de Rodolfo del 2026-11-10); la
  completa (M-7b / RF-131) no se hace.
- **Disparador y migración en la misma transacción**: el disparador viejo depende de que el formulario sea
  de la 9000, y el nuevo de que sea global.
- **El disparador lee la marca "Global al alta"** de REQ-015 por número, no por nombre: si el superusuario
  renombra el global en la Consola, el alta sigue funcionando.

## Cómo se revisa (además de DocTest)

- Tarea 0 hecha: la función desplegada en DEMO (y en producción, por Rodolfo) es igual a la de v2.8.1.3, o
  la diferencia está reportada y resuelta antes de seguir.
- Verificación §8.5 corrida en producción por Rodolfo y revisada **antes** de desplegar (vi).
- En una copia de DEMO: alta de una empresa de prueba → tiene la fila `configuraciones/formulario_entrega_materiales`
  apuntando al global y **ningún** formulario con su `empr_id`; la entrega directa dibuja el global.
- Una empresa existente: su configuración y su clon, iguales antes y después (comparar las filas).
- La vuelta atrás probada en la copia de DEMO: después de revertir, un alta nueva vuelve a clonar.
- `git diff` sin cambios en `application/modules/` (ni `traz-comp-formularios` ni las pantallas de tareas
  y etapas) ni en `esb/`.
- `./mvnw clean install` del proyecto de APIs.
- **Aviso para el despliegue:** el script de despliegue sube los DataServices (entra el cambio de
  `FRMDataService.dbs`); este requerimiento no cambia APIs. El cambio del disparador y el script de datos se
  corren aparte, en la base, con el OK de Rodolfo.

## Dudas abiertas

Están en los casos de uso (campo `dudas`), para contestarlas en un solo lugar.

---

## Casos de prueba de la especificación que cubre

| CP | Qué prueba | Lo cubre |
|---|---|---|
| CP-127 | El alta escribe la configuración apuntando a los globales "al alta", sin copiar | ADM-UC-291. "G-2 en salida de pañol" se cumple cuando el superusuario le marque un global al alta a ese punto (REQ-015) |
| CP-130 | (parte de combos) El combo de tareas estándar muestra sus propios y después los globales con "(global)" | ADM-UC-290. El resto de CP-130 está en REQ-015 (ADM-UC-250) |
| CP-132 | Migración de la 9000 a globales | **Parcial**, ADM-UC-292: solo "Entrega Materiales" de la 9000 queda global publicado y cada empresa existente conserva su clon y su configuración. **No se hace** (decisión de Rodolfo): su lista como global, los sin empresa asignados a su cliente y el informe de pañol |
