# Análisis de impacto — barra superior de Tools (REQ-004)

| Campo | Valor |
|---|---|
| Tarea | REQ-004 · Tarea 1 (análisis de impacto, núcleo) |
| Fecha | 2026-11-24 |
| Aprueba | Rodolfo (puerta 🔴 antes de tocar `Dash.php`/`perfil.php`) |
| Pide | Agregar "🏢 Mi empresa" (administradores) y "🔑 Consola" (superusuarios) en la barra superior de Tools |

Este documento responde lo que pide la Tarea 1 del plan: qué pantallas dibujan la barra, qué pasa si el
módulo o el servicio no responden, cuánto suma al tiempo de carga y qué pruebas de regresión aplican.
Además deja redactadas las cargas **M-2** y **M-6** para su aprobación.

---

## 1. Dónde vive la barra (inventario)

La barra superior se arma en **`application/views/layout/perfil.php`**. Ese archivo **no se carga solo**:
lo carga `layout/Admin.php` (línea 162 del compartido). Hay 5 archivos `perfil.php`:

| Archivo | Líneas | Lo carga | ¿Se dibuja? |
|---|---|---|---|
| `application/views/layout/perfil.php` (compartido) | 173 | `application/views/layout/Admin.php` → `Dash.php` global y módulos sin `Admin.php` propio | **Sí** |
| `application/modules/traz-comp-pan/views/layout/perfil.php` | 89 | `traz-comp-pan` `Dash.php` → su propio `layout/Admin.php` | No efectivamente (ver §2) |
| `application/modules/traz-prod-trazasoft/views/layout/perfil.php` | 41 | `traz-prod-trazasoft` `Dash.php` → su propio `layout/Admin.php` | No efectivamente (ver §2) |
| `application/modules/traz-tools-resi/views/layout/perfil.php` | 39 | Ningún controlador carga su `layout/Admin.php` → huérfano | **No** |
| `application/modules/traz-comp-tareasestandar/views/layout/perfil.php` | 50 | Su `layout/Admin.php` es una plantilla demo y **no** carga `perfil.php` → huérfano | **No** |

Las cuatro copias de módulo **no son copias fieles**: son versiones viejas y divergentes (41–89 líneas
contra 173 del compartido). `tareasestandar`, además, tiene datos de demostración fijos ("solicitante1",
"veladero", "unidad agregada 1…") — es un resto de prueba.

## 2. Qué se dibuja de verdad

**Sólo se dibuja el `perfil.php` compartido.** Evidencia:

1. **Código:** el único punto de entrada real es `application/controllers/Dash.php` → `index()` (línea 44,
   `$this->load->view('layout/Admin',$data)`). Los módulos `traz-comp-formularios`, `traz-comp-codigos`,
   `ddpe-tools-pro` y `traz-comp-almacenes` también cargan `layout/Admin`, pero **no tienen `Admin.php`
   propio**, así que resuelven al compartido y dibujan el `perfil.php` compartido. Las pantallas de módulo
   se abren dentro de `#content` por AJAX (`linkTo`), así que la barra es la que trajo la página principal.
2. **Nada enlaza a las pantallas con copia:** no hay ninguna referencia a `traz-comp-pan/Dash`,
   `traz-prod-trazasoft/Dash` ni a la pantalla de `traz-tools-resi` fuera de las propias carpetas.
   `traz-prod-trazasoft` tiene `default_controller = login` (no `dash`), y `traz-comp-pan` no tiene
   `routes.php`; los `Dash.php` de esos módulos son restos de una versión anterior.
3. **Registro (logs):** en los `application/logs/` de los últimos meses **nunca** aparece un
   `modules/<módulo>/views/layout/perfil.php`; sí aparece cientos de veces el compartido
   (`application/views/layout/perfil.php`).
4. `traz-tools-resi` no tiene `Dash.php` ni ningún controlador que cargue su `layout/Admin.php`, y
   `traz-comp-tareasestandar` tiene un `Admin.php` de plantilla AdminLTE que no carga `perfil.php`.

**Conclusión:** el cambio va **sólo** en `application/views/layout/perfil.php` (compartido) y en
`application/controllers/Dash.php::index()`. Las cuatro copias de módulo quedan **sin tocar**: no se
dibujan y tocarlas sería riesgo sin beneficio. Si en el futuro alguna pantalla vieja de módulo empezara
a usarse, se le agregan los botones en ese momento (es una edición chica).

> Nota para Rodolfo: confirmar que en producción nadie entra a mano a `traz-comp-pan/Dash` ni a la
> pantalla vieja de `traz-prod-trazasoft`. Si alguien lo usara, esa pantalla mostraría la barra vieja sin
> los botones, pero no se rompe nada.

## 3. Qué pasa si el módulo o el servicio no responden

- El `Dash.php` global pedirá el "Contexto" al módulo **sólo si el módulo está montado**
  (`APPPATH.'modules/traz-comp-adm'` presente y su modelo cargable). Si no está, no se llama y no se
  muestran los botones.
- Si el módulo está montado pero el DataService no responde (o no hay red a WSO2), el modelo "Contexto"
  devuelve `es_admin = false` y `es_super = false` (mismo patrón que `Dashs::esAdminEmpresa` y
  `ADM_Controller::es_administrador`, que ya devuelven `false` ante excepción). **El tablero carga
  igual, sin botones y sin mensaje de error.** Nunca un fatal ni un error visible en la barra.
- El "Contexto" se pide **una vez por carga del tablero**, y el resto de Tools sigue cargando por AJAX.

## 4. Cuánto suma al tiempo de carga

El Contexto hace como máximo **3 llamadas** (empresa, es_admin, es_super), cada una igual a las que ya usa
el Portal:

| Llamada | Servicio | Ya existía |
|---|---|---|
| Nombre de la empresa | `REST_CORE/empresa/{empr_id}` | Sí (lo usa el Portal) |
| Es administrador | `ADMDataService /usuario/es-admin/...` | **Nueva** (Tarea 3) |
| Es superusuario | `ADMDataService /usuario/es-super/...` | **Nueva** (Tarea 3) |

Medición: se mide en DEMO al implementar (Tarea 6). **Si el total supera ½ segundo**, se guarda el
resultado del Contexto en la sesión hasta **60 segundos** (RNF-06, resolución D3 de ADM-UC-030). No se
cachea nada más.

## 5. Pruebas de regresión de la barra

- DocTest `regresion` en verde (las pantallas de Tools siguen cargando con la misma barra para usuarios que
  no son administradores ni superusuarios).
- El menú del perfil, el selector de empresa, "Salir" y "Ayuda" quedan igual (sólo se agregan dos botones
  a la izquierda del perfil).
- ADM-UC-030 en verde: administrador ve "Mi empresa"; usuario común no ve ninguno; superusuario ve
  "Consola"; servicio caído no muestra nada y el tablero carga.

## 6. Recomendación

1. Tocar **sólo** `application/views/layout/perfil.php` y `application/controllers/Dash.php::index()`.
2. No tocar las cuatro copias de módulo (no se dibujan); documentarlo en el PR.
3. Mantener el `try/catch` del Contexto con fallback "no admin, no super" (nunca romper el tablero).
4. Cachear el Contexto en sesión **sólo si** la medición da más de ½ segundo.

---

## 7. Carga M-2 (para aprobación de Rodolfo — toca `seg.menues`)

**Qué hace:** cargar las herramientas del agente como filas del catálogo, para que la futura
Consola → Catálogo las pueda listar y publicar por plan.

- **Módulo:** `MCP` (una fila de nivel 1 "IA / Herramientas del agente", si no existe).
- **Filas:** una por cada tool del agente, `tipo = tool_mcp`, `publicacion = publicada`, `eliminado = 0`.
  Lista de hoy (25 tools del contrato `doc/api/trazalog-operaciones.yaml`):

  | Módulo | Tools |
  |---|---|
  | `man_` (11) | `man_get_equipos`, `man_get_equipo`, `man_get_ots`, `man_get_ot`, `man_create_ot`, `man_get_lecturas`, `man_get_preventivos`, `man_get_kpi_disponibilidad`, `man_get_kpi_mttr`, `man_get_kpi_mttf`, `man_get_kpi_fallas` |
  | `alm_` (9) | `alm_get_stock`, `alm_get_depositos`, `alm_get_vencimientos`, `alm_get_movimientos`, `alm_get_entregas`, `alm_get_movimientos_internos`, `alm_get_pedidos_materiales`, `alm_get_pedido_material`, `alm_crear_pedido_materiales` |
  | `pan_` (4) | `pan_get_herramientas`, `pan_get_herramienta`, `pan_get_movimientos`, `pan_get_certificaciones` |
  | `core_` (1) | `core_get_empresa_actual` |

- **NO se cargan las opciones del módulo `SEG`** (las pantallas del Portal no entran al catálogo; manda
  RF-44, resolución D19).
- **Riesgo (verificado en el código):** `getMenuByUserPermission` (`COREDataService.dbs:8`) devuelve
  **todas** las filas de `seg.menues` con un flag `habilitado` (por permisos de `seg.menues_users_vw`), y
  `menu()` (`application/helpers/menu_helper.php:121-126`) muestra **todos los hijos** cuando el módulo
  padre está habilitado y ningún hijo lo está (regla "si ningún hijo está habilitado se muestran todos").
  Por eso, agregar filas a `seg.menues` **puede** hacer aparecer el módulo `MCP` en el menú de algunos roles.
- **Freno:** si al probar con un usuario de prueba el menú cambia, **no se aplica M-2** en este
  requerimiento y se difiere a REQ-005/011 (resolución D20). La verificación es "el menú es el mismo antes
  y después" (ADM-UC-035).
- **Exactitud:** la forma de las filas (columnas reales de `seg.menues` en el ambiente) se valida contra el
  catálogo real antes de correr el script; este documento define el contenido, no el SQL final.

## 8. Carga M-6 (para aprobación de Rodolfo — toca `seg.users`)

**Qué hace:** marcar `superusuario = true` en el usuario cuyo correo es el de `TOOLS_ADMIN_USER` **del
ambiente**.

- El correo **no** queda escrito en el repositorio: el script lo recibe como parámetro
  (en el `constants.php` de referencia del repo vale `admin@gmail.com`, pero cada ambiente tiene el suyo).
- Si no existe un usuario con ese correo (o hay varios), **no marca a nadie** y lo avisa; Rodolfo dice a
  quién marcar en ese ambiente (resolución D5/D6).
- En este requerimiento la marca **no se audita** (la acción "súper usuario" de RF-100 se audita en
  REQ-008). La marca sólo la pone el script hasta que exista la pantalla de Usuarios.
- **Efecto:** después de M-6, el módulo y Tools (cuando usen la marca) reconocen al superusuario; DNATO y
  el resto de Tools siguen usando el correo hasta la redirección final (los dos criterios coinciden
  porque se marca justo a ese correo).

---

## 9. Riesgos y notas

- 🔴 **Núcleo:** la barra es de todas las pantallas de producción; cualquier cambio debe mantener el
  fallback (módulo ausente o servicio caído = sin botones, tablero igual).
- 🟠 **Dos definiciones de administrador:** Tools sigue resolviendo el aterrizaje con
  `Dashs::esAdminEmpresa` (por `descripcion`), y el módulo/Contexto usará la definición por `nombre`. Hasta
  B.4c pueden discrepar. Este requerimiento **no** toca `esAdminEmpresa` (resolución D7/D9); la medición de
  B.4 cuantifica los casos.
- 🟢 **M-2/M-6:** son aditivas a la base y las aprueba Rodolfo antes de correr el script en DEMO (M-7 lo
  decide el equipo).
