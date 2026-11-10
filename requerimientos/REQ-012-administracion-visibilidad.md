# REQ-012 · Módulo Administración — Funcionalidades de otro plan: vista de presentación y "Me interesa"

## Objetivo

Duodécimo trabajo de Pablo para el módulo **Administración** (`traz-comp-adm`): la **vista de
presentación** que se abre al tocar en el menú de Tools una opción sombreada (de otro plan, o con el
plan vencido), el botón **"Me interesa"** que avisa al administrador, y el **contador** de "Me interesa"
del catálogo con datos reales. Lo leen Pablo para planificar y Rodolfo para aprobar
el cambio chico en el menú de Tools. **No** cubre el dibujo del menú sombreado (ya lo hace
[REQ-009](REQ-009-administracion-menus.md)), el pedido de cambio de plan (REQ-010) ni el rechazo de pantallas no visibles en
Tools (T-5, deuda H-091). Lista completa en [`README.md`](README.md).

| Campo | Valor |
|---|---|
| Estado | **Borrador**: Rodolfo tiene que contestar las dudas de los casos y aprobar el análisis de impacto en Tools |
| Se apoya en | [REQ-002](REQ-002-administracion-esqueleto.md) (controlador base), [REQ-004](REQ-004-administracion-base-y-atributos.md) (`seg.intereses`, `seg.menues.texto_presentacion`, auditoría), [REQ-005](REQ-005-administracion-catalogo-y-planes.md) (catálogo con su contador, plan de menor orden), [REQ-006](REQ-006-administracion-funcionalidades.md) (R1, R2, `otro_plan`, servicio "Funcionalidad visible"), [REQ-009](REQ-009-administracion-menus.md) (menú resuelto con `url_presentacion` y menú lateral de Tools) y [REQ-010](REQ-010-administracion-plan-y-pedidos.md) (Plan) |
| Entrega de la especificación | **E9** de `doc/v3/dnato/PROMPT_CLI_DNATO_V3_BUILD.md`: vista de presentación, "Me interesa", contador en el catálogo. CU-50; CP-90, CP-93, CP-42. Más el punto **T-6** de `02_MODELO_Y_REGLAS.md` §9b (enlace desde la opción sombreada) |
| Casos de uso | `ADM-UC-190` a `ADM-UC-192` en `doctest/catalogo/adm/` |
| Repos que se tocan | `traz-comp-adm` (vista de presentación, "Me interesa", correo, fila de Funcionalidades); `traz-tools`: recursos **nuevos** en `ADMDataService.dbs`, un script de base chico y, del núcleo, `application/helpers/menu_helper.php` (solo la función nueva `menu_resuelto()` de REQ-009) |
| Riesgo | 🔴 Los nombres de columnas de `seg.intereses` (tabla nueva) y su índice único (lista en "Datos") son **cambio de base aditivo: lo decide el equipo (regla de Rodolfo del 2026-11-10)**. Sigue en rojo solo por el **núcleo de Tools**: la opción sombreada del menú lateral pasa a abrir la vista de presentación (cambio en `menu_resuelto()`, que solo corre con la variable `menu_resuelto_en_tools` encendida) → **análisis de impacto aprobado por Rodolfo** (sección "Análisis de impacto en Tools"). Recursos del DataService nuevos (🟡) |

---

## Para qué sirve

- Con REQ-009 la persona ve en el menú de Tools lo que su empresa **no** tiene (sombreado, con el ícono
  del plan), pero al tocarlo no pasa nada. La idea comercial es que se entere de qué se pierde y le
  avise a su administrador, sin ver datos que no le corresponden.
- El administrador quiere saber qué le pide su gente, y Trazalog qué funcionalidades interesan más (el
  contador del catálogo, que REQ-005 dejó mostrando 0).

## Quién lo usa

- **Supervisor**, **Mantenedor** y cualquier persona de la empresa: toca la opción sombreada y "Me
  interesa".
- **Administrador**: recibe el correo "A <persona> le interesa <funcionalidad>".
- **Superusuario**: ve el contador en el catálogo de la Consola.

## Qué tiene que hacer

1. Ver la vista de presentación de una funcionalidad de otro plan (o con el plan vencido), sin datos
   reales (CU-50, CU-63, RF-91, RNF-07, T-6) → **ADM-UC-190**.
2. Tocar "Me interesa": correo a los administradores, auditoría, contador, y no se repite (RF-92) →
   **ADM-UC-191**.
3. Ver el contador de "Me interesa" por funcionalidad y por empresa en el catálogo (RF-43, CU-17) →
   **ADM-UC-192**.

## Qué NO hace

- **No dibuja el menú sombreado**: lo hace REQ-009 (con la variable `menu_resuelto_en_tools`). Acá solo
  se le agrega el enlace a la vista de presentación.
- **No controla el acceso por dirección en Tools** (RF-94, CP-91, CP-92): una persona que escribe la
  dirección de una pantalla de otro plan todavía entra, hasta el chequeo central T-5 (deuda H-091).
- **No crea pedidos de plan**: "Me interesa" solo avisa; el pedido lo hace el administrador en Plan
  (REQ-010).
- No hace un fondo de relleno distinto por pantalla: uno genérico para todas (ver la duda de ADM-UC-190).
- No cambia "Ver como…" de REQ-009: ahí la opción sombreada sigue sin abrir nada.

---

## Cómo se arma

### Vista de presentación (RF-91, RNF-07)

- Dirección: `traz-comp-adm/presentacion/<modulo>/<opcion>` (la que ya devuelve el servicio "Menú
  resuelto" como `url_presentacion`, REQ-009). Pasa por el controlador base (sesión obligatoria; persona
  y empresa **de la sesión**).
- **Cuándo se muestra**: solo si para esa persona la funcionalidad es `otro_plan` (R2 de REQ-006: de
  otro plan y de tipo pantalla o acción), o si la empresa tiene el plan vencido. El servidor lo
  verifica con el recurso de R2 de REQ-006; no confía en el enlace.
- **Si no corresponde**:
  - la funcionalidad es visible (ya está en su plan): "Esta funcionalidad ya está en tu plan." con
    "Abrir" que lleva a su pantalla **[SUPUESTO]**;
  - sin activar, sin acceso para el rol, sin publicar, herramienta de IA o inexistente: "Esta página no
    está disponible." (404), sin decir por qué, para no mostrar el catálogo **[SUPUESTO]**.
- **Qué muestra** (maqueta `vista-esfumada.html`): ícono grande del plan, nombre de la funcionalidad, "No
  está en tu plan <plan actual> · está incluido en el plan <plan>" (el de menor orden que la trae,
  RF-14), el **texto de presentación** del catálogo (`seg.menues.texto_presentacion`, REQ-005), "👍 Me
  interesa" y, si ya avisó, "Ya avisaste el <fecha>".
- **Plan vencido** (CP-19, CU-63): "El período de prueba de tu empresa terminó" y "Pedile a tu
  administrador que elija un plan", con "Me interesa"; el ícono y el plan son los del plan **no
  gratuito** de menor orden que la incluye.
- **Fondo esfumado**: lo dibuja el navegador con datos de relleno (tarjetas con "00" y una tabla con
  filas inventadas, como la maqueta), **genérico** para todas las funcionalidades. La respuesta del
  servidor trae solo nombre, textos, íconos y planes: **ningún dato de la empresa** (CP-90, RNF-07).
- **Dónde se abre**: desde el menú de Tools, dentro de `#content` con `linkTo` (como cualquier pantalla
  de Tools; el módulo devuelve solo el fragmento). Desde Funcionalidades del Portal (fila 💎, REQ-006),
  como página del Portal **[SUPUESTO]**.
- El texto de presentación lo escribe el superusuario: se **escapa** antes de mostrarlo.

### "Me interesa" (RF-92)

1. La persona toca "👍 Me interesa". El servidor verifica lo mismo que para mostrar la vista.
2. Si ya avisó por esa funcionalidad en esa empresa: no hace nada nuevo y responde "Ya avisaste el
   <fecha>".
3. Si no: fila en `seg.intereses` (empresa, correo, módulo, opción, fecha), auditoría
   `funcionalidad.interes`, en una operación. La base garantiza una por persona, empresa y funcionalidad
   (dos toques a la vez no duplican).
4. Correo a los administradores de la empresa (definición única de REQ-004): "A <nombre> le interesa
   <funcionalidad>. Podés pedir el cambio desde Mi empresa → Plan" (CP-93), con el enlace a Plan.
5. La pantalla muestra "Listo: le avisamos a tu administrador" y el botón queda deshabilitado con "Ya
   avisaste el <fecha>".
6. Si el correo falla, el interés queda guardado y la pantalla lo dice **[SUPUESTO]** (RNF-08).

### Contador en el catálogo (RF-43, CP-42)

La ficha del catálogo de REQ-005 ya muestra "Me interesa (N): <empresa> ×n, …" con el recurso
`GET /catalogo/intereses/{modulo}/{opcion}` sobre `seg.intereses`. Con este requerimiento la tabla
tiene datos reales: no cambia la pantalla, se prueba con intereses hechos con el botón.

### En el menú de Tools (T-6) — núcleo

`menu_resuelto()` de `application/helpers/menu_helper.php` (la función **nueva** de REQ-009) dibuja hoy
la opción `otro_plan` sin navegación. Pasa a llevar `onclick='linkTo("<url_presentacion>")'`, como
cualquier opción. Nada más del menú cambia. `menu()` (el de siempre) no se toca.

### Auditoría

`funcionalidad.interes` (RF-100 "Me interesa"), con empresa, persona y funcionalidad.

---

## De dónde sale cada dato

| Dato | De dónde | Cómo |
|---|---|---|
| Sesión, persona, empresa | Sesión de Tools | Ya existe |
| ¿Es de otro plan para esta persona? Plan de menor orden, plan vencido | `ADMDataService` recurso de R2 de REQ-006 (`otro_plan`, motivo, plan mínimo) | Ya existe (REQ-006) |
| Nombre, ícono, texto de presentación de la funcionalidad | `ADMDataService GET /presentacion/{modulo}/{opcion}` (solo campos del catálogo y del plan) | **NUEVO** |
| Plan actual de la empresa | `ADMDataService GET /empresa/{empr_id}/plan` | Ya existe (REQ-010) |
| Si ya avisó y cuándo | `ADMDataService GET /interes/{email}/empresa/{empr_id}/{modulo}/{opcion}` | **NUEVO** |
| Registrar "Me interesa" (con auditoría) | `ADMDataService POST /interes` | **NUEVO** |
| Administradores (correos) | `ADMDataService GET /empresa/{empr_id}/administradores` | Ya existe (REQ-005) |
| Contador del catálogo | `ADMDataService GET /catalogo/intereses/{modulo}/{opcion}` | Ya existe (REQ-005) |

**Nada va directo a la base.** Correo y empresa salen siempre de la sesión.

---

## Pantallas

### Vista de presentación — `traz-comp-adm/presentacion/<modulo>/<opcion>`

Maqueta `doc/v3/dnato/mockups/vista-esfumada.html` (layout "tools").

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Encabezado | Nombre de la funcionalidad y "Incluido en el plan <ícono> <plan>" | `adm-presentacion` |
| Fondo | Tarjetas y tabla de relleno, esfumadas, dibujadas en el navegador | `adm-presentacion-fondo` |
| Tarjeta | Ícono grande del plan, nombre, "No está en tu plan <plan actual> · está incluido en el plan <plan>", texto de presentación | `adm-presentacion-tarjeta` |
| Plan vencido | "El período de prueba de tu empresa terminó" y "Pedile a tu administrador que elija un plan" | `adm-presentacion-vencido` |
| Botón | "👍 Me interesa" | `adm-presentacion-interes` |
| Pie | "Le avisamos a tu administrador para que pida el cambio de plan." y, si ya avisó, "Ya avisaste el <fecha>." | `adm-presentacion-ya-aviso` |

### Tools — menú lateral (cambio a REQ-009)

La opción sombreada (`adm-tools-menu-otro-plan`) abre la vista de presentación.

### Portal → Funcionalidades (cambio a REQ-006)

Tocar una fila 💎 abre la vista de presentación **[SUPUESTO]** (CU-31).

### Mensajes

| Caso | Mensaje | `data-testid` |
|---|---|---|
| Aviso enviado | "Listo: le avisamos a tu administrador" (RF-92, CP-93) | `adm-presentacion-ok` |
| Ya avisó | "Ya avisaste el <fecha>" (RF-92) | `adm-presentacion-ya-aviso` |
| Ya está en su plan **[SUPUESTO]** | "Esta funcionalidad ya está en tu plan." y "Abrir" | `adm-presentacion-visible` |
| No disponible **[SUPUESTO]** | "Esta página no está disponible." | `adm-presentacion-no-disponible` |
| Correo que no salió **[SUPUESTO]** | "Guardamos tu aviso, pero no pudimos mandar el correo. Tu administrador lo va a ver en el catálogo de intereses." | `adm-presentacion-aviso` |
| Falla del servicio | "No pudimos guardar. Probá de nuevo en un rato." | `adm-presentacion-error` |

Correo al administrador: asunto **[SUPUESTO]** "A <nombre> le interesa <funcionalidad>"; cuerpo "A
<nombre> le interesa <funcionalidad>. Podés pedir el cambio desde Mi empresa → Plan" (CP-93) con el
enlace.

---

## Reglas

1. La vista de presentación se muestra solo si la funcionalidad es de otro plan para la persona de la
   sesión (o la empresa tiene el plan vencido); el servidor lo verifica.
2. La vista no envía datos de la empresa: solo nombre, textos, íconos y planes; el fondo es de relleno.
3. El plan que se muestra es el de menor orden que trae la funcionalidad; con el plan vencido, el no
   gratuito de menor orden.
4. "Me interesa" se registra una vez por persona, empresa y funcionalidad; la segunda vez dice "Ya
   avisaste el <fecha>".
5. Cada "Me interesa" manda correo a los administradores de la empresa y queda en la auditoría; si el
   correo falla, el interés queda.
6. El contador del catálogo cuenta los "Me interesa" por funcionalidad, desglosados por empresa.
7. El texto de presentación se escapa antes de mostrarse.
8. En el menú de Tools, la opción sombreada abre la vista; lo demás del menú no cambia.

## Registro en el log

`log_message('DEBUG', '#TRAZA | ADM | <Clase> | <metodo>() ...')`. Se registran cada "Me interesa"
(empresa, persona, funcionalidad), los pedidos de vista rechazados (no corresponde) y las fallas del
correo.

---

## Datos

**Cambio de base aditivo: lo decide el equipo (regla de Rodolfo del 2026-11-10).** La tabla la crea
REQ-004 (en `seg`) con los atributos; acá
se proponen los nombres **[SUPUESTO]** (si el script de REQ-004 no corrió, van en él; si no, en uno
chico con su vuelta atrás).

| Tabla | Columnas propuestas |
|---|---|
| `seg.intereses` | `interes_id`, `empr_id`, `email`, `modulo`, `opcion` (referencia a `seg.menues`), `fecha`; única por (`empr_id`, `email`, `modulo`, `opcion`) |

Ninguna fila ni columna existente cambia; no hay carga de datos.

---

## Análisis de impacto en Tools (núcleo) — lo aprueba Rodolfo antes de construir

| Qué | Detalle |
|---|---|
| Qué cambia | `application/helpers/menu_helper.php`: en `menu_resuelto()` (función nueva de REQ-009), la opción `otro_plan` lleva `linkTo(url_presentacion)`. `menu()`, `Dash.php`, `Dashs.php` y `layout/Admin.php` no cambian |
| Quién lo consume | El menú lateral de Tools **solo cuando la variable `menu_resuelto_en_tools` está encendida** (REQ-009). Con la variable apagada no hay opciones sombreadas y nada cambia. Los submódulos no usan `menu_resuelto()` |
| Qué se rompe si falla | Si la vista falla, la persona ve un error dentro de `#content` al tocar una opción sombreada; el resto del menú y las pantallas siguen andando |
| Cómo se protege | La vista devuelve siempre un fragmento legible (también en error: "No pudimos cargar esta página. Probá de nuevo en un rato." **[SUPUESTO]**); la variable de REQ-009 apaga todo el menú nuevo sin desplegar; la respuesta no trae datos reales (CP-90) |
| Pruebas | ADM-UC-190 desde el menú de Tools con la variable encendida; ADM-UC-135 de REQ-009 se actualiza: la opción sombreada ahora abre la vista |

---

## Decisiones tomadas

- **El servidor decide si corresponde la vista**, con el mismo recurso de R2 de REQ-006: el enlace del
  menú no alcanza (alguien puede escribir la dirección).
- **Un interés por persona, empresa y funcionalidad** garantizado en la base: así el contador no se
  infla y el correo no se repite.
- **Fondo genérico de relleno dibujado en el navegador**: es la forma más simple de garantizar que no
  viaje ningún dato real.
- **El cambio en Tools va solo en la función nueva** de REQ-009: con la variable apagada, Tools queda
  exactamente como hoy.

## Cómo se revisa (además de DocTest)

- Script de base (aditivo) corrido en una copia de DEMO, con su vuelta atrás.
- **Análisis de impacto en Tools aprobado por Rodolfo.**
- La respuesta de la vista (lo que baja el navegador) no contiene ningún dato de la empresa: se revisa
  con las herramientas del navegador sobre BPM.procesos (CP-90).
- Dos "Me interesa" simultáneos de la misma persona dejan una sola fila y un solo correo.
- `phpcs` con PHPCompatibility para PHP 5.6 sin errores; `./mvnw clean install` del proyecto de APIs.
- **Aviso para el despliegue:** el script de despliegue sube los DataServices pero no las APIs; este
  requerimiento no agrega APIs.

## Dudas abiertas

Están en los casos de uso (campo `dudas`), para contestarlas en un solo lugar.

---

## Casos de prueba de la especificación que cubre

| CP | Qué prueba | Lo cubre |
|---|---|---|
| CP-90 | Vista de presentación sin datos reales | ADM-UC-190 |
| CP-93 | "Me interesa" avisa, audita y no se repite | ADM-UC-191 |
| CP-42 | Contador de "Me interesa" desglosado por empresa | ADM-UC-192 (con intereses hechos con el botón; la pantalla es de REQ-005, ADM-UC-052) |
| CP-67 (parte del clic) | "Al hacer clic se abre la vista de presentación" | ADM-UC-190 (desde el menú de Tools) |
| CP-19 (parte de la vista) | Con el plan vencido, la vista dice "El período de prueba de tu empresa terminó" | ADM-UC-190 |
| CP-91, CP-92 | Pedir a mano una pantalla no visible da 403; lo que el rol no permite no aparece | Fuera de alcance: chequeo central de Tools (T-5, deuda H-091); no son de E9 |
