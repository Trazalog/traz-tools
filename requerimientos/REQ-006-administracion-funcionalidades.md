# REQ-006 · Módulo Administración — Funcionalidades de la empresa

## Objetivo

Sexto trabajo de Pablo para el módulo **Administración** (`traz-comp-adm`): la pantalla del Portal donde
el administrador elige qué usa su empresa **dentro de su plan** y en qué orden, y las dos reglas que
dicen qué ve cada empresa y cada persona (R1 y R2), con el servicio "Funcionalidad visible" que las
expone. Lo leen Pablo para planificar y Rodolfo para aprobarlo. **No** cubre los menús por rol o persona
ni el menú que dibuja Tools ([REQ-009](REQ-009-administracion-menus.md)), la vista de presentación de lo
que es de otro plan (REQ-012), ni que las pantallas de Tools rechacen lo que no es visible (deuda
**H-091**). Lista completa en [`README.md`](README.md).

| Campo | Valor |
|---|---|
| Estado | **Borrador**: Rodolfo tiene que contestar las dudas de los casos |
| Se apoya en | [REQ-002](REQ-002-administracion-esqueleto.md) (controlador base, Portal), [REQ-004](REQ-004-administracion-base-y-atributos.md) (`seg.empresas_funcionalidades`, estado de empresa y de membresía, auditoría, Contexto) y [REQ-005](REQ-005-administracion-catalogo-y-planes.md) (catálogo publicado, planes y matriz) |
| Entrega de la especificación | **E3** de `doc/v3/dnato/PROMPT_CLI_DNATO_V3_BUILD.md`: Mi empresa → Funcionalidades + reglas R1/R2 + servicio "Funcionalidad visible" + respuestas 403/404. CU-31; CP-14, 15, 41, 50, 52, 53, 91, 92. La validación 403/404 en las pantallas de Tools (RF-94 para toda la suite) **no** va acá: ver "Qué NO hace" |
| Casos de uso | `ADM-UC-070` a `ADM-UC-072` en `doctest/catalogo/adm/` |
| Repos que se tocan | `traz-comp-adm` (pantalla, modelo de visibilidad, servicio); `traz-tools`: recursos **nuevos** en `ADMDataService.dbs` |
| Riesgo | 🟡 Pantalla nueva del módulo, recursos nuevos del DataService y lectura de tablas existentes (`seg.menues`, `seg.memberships_menues`, `seg.memberships_users`, `core.empresas`) **sin modificarlas**. No hay columnas, tablas ni migración nuevas en este requerimiento. Si se adelanta M-4 (duda de ADM-UC-071) sigue en 🟡: M-4 solo agrega filas a una tabla nueva (`seg.empresas_funcionalidades`) sin cambiar filas existentes, así que es **cambio de base aditivo: lo decide el equipo (regla de Rodolfo del 2026-11-10)** |

---

## Para qué sirve

- Dentro de su plan, cada empresa usa solo lo que le sirve: apagar una funcionalidad la saca de todos
  sus menús, sin perder datos.
- Que el orden de las funcionalidades sea el del menú predeterminado de la empresa (REQ-009).
- Que "qué ve esta empresa" y "qué ve esta persona" se calculen **en un solo lugar** (R1 y R2), para
  que el Portal, el menú, la vista de presentación y, más adelante, Tools y el agente digan lo mismo.
- Que bajar de plan no borre nada: lo que queda afuera vuelve igual al volver a subir.

## Quién lo usa

- **Administrador** de una empresa: Mi empresa → Funcionalidades.
- **Supervisor** (o cualquier perfil de operación): se usa para probar el servicio "Funcionalidad
  visible" desde su sesión (CP-91).
- **Superusuario**: cambia la matriz de planes (REQ-005) para probar que la empresa conserva lo suyo.

## Qué tiene que hacer

1. Ver las funcionalidades de la empresa en tres grupos (✅ activas, 💤 sin activar, 💎 de otros
   planes), con el ícono del plan más bajo que trae cada una (R1, RF-50, RF-14) → **ADM-UC-070**.
2. Activar, desactivar y ordenar las funcionalidades, conservando todo al salir y volver al plan
   (CU-31, RF-51 a 53) → **ADM-UC-071**.
3. Servicio "Funcionalidad visible" (R2) con respuestas "no está activa para tu empresa" (403) y "no
   existe" (404) → **ADM-UC-072**.

## Qué NO hace

- **No hace que las pantallas de Tools rechacen lo que no es visible** (RF-94 para toda la suite,
  punto T-5 de `02_MODELO_Y_REGLAS.md` §9b). El control de acceso vive solo en el módulo (decisión de
  Rodolfo del 2026-11-10); llevarlo a las pantallas de Tools es la deuda **H-091**, en un requerimiento
  aparte con su análisis de impacto. Acá queda **listo el servicio** que esas pantallas van a llamar.
  Por eso CP-92 ("no ve el botón 'Nuevo equipo'") queda fuera.
- **No cambia el menú de Tools.** Apagar una funcionalidad acá no la saca del menú lateral de Tools
  hasta que Tools dibuje el menú resuelto (REQ-009 y su derivación).
- No hace el aviso "Está en N menús: dejará de verse en ellos" al apagar (CU-31 A1, CP-51): los menús
  custom nacen en REQ-009, que lo agrega.
- No hace la vista de presentación ni "Me interesa" al tocar una funcionalidad de otro plan (CU-50,
  REQ-012), ni la comparativa "Ver qué trae cada plan" (REQ-010).
- No activa funcionalidades en las empresas existentes (M-4, REQ-009) ni al dar de alta una empresa
  (RF-21, REQ-008). Ver la duda de ADM-UC-071.
- No cambia el plan de una empresa (REQ-008); acá solo se muestra el efecto.
- No modifica `seg.memberships_menues` ("Roles y accesos" es REQ-007).
- El agente (MCP) no usa todavía este servicio: el freno en WSO2 es del frente del agente (REQ-011).

---

## Cómo se arma

### R1 — Estado de cada funcionalidad para la empresa

Para cada funcionalidad **publicada** del catálogo (las que REQ-005 define como funcionalidades: con
dirección o de tipo `tool_mcp`):

- `en_plan` = está en `seg.planes_funcionalidades` para el plan de la empresa (`core.empresas.plan_id`).
- `activa` = la fila de `seg.empresas_funcionalidades` de la empresa dice activa; sin fila, no.
- `plan_minimo` = el plan activo de **menor orden** que la incluye (RF-14), con su ícono y nombre.
- Grupos: ✅ `en_plan` y `activa` · 💤 `en_plan` y no `activa` · 💎 no `en_plan`.
- **Plan vencido** (`core.empresas.estado_plan = vencido`, REQ-004): todo es 💎 y `plan_minimo` es el
  plan **no gratuito** de menor orden que la incluye.
- **Empresa sin plan** (`plan_id` nulo, todas hasta M-3 en REQ-016): ver la duda de ADM-UC-070.
  Propuesta: se toma como si el plan trajera todo lo publicado ("nadie pierde nada").
- Lo sin publicar o despublicado **no aparece** en ningún grupo.

### R2 — Visible para una persona

`visible(persona, funcionalidad)` es sí cuando, a la vez:

1. la membresía de la persona en la empresa de la sesión está `activo` (`seg.membresias_estado`) y la
   empresa no está `suspendida` (`core.empresas.estado`);
2. la funcionalidad es ✅ para la empresa (R1);
3. **el rol** de su membresía tiene acceso a la funcionalidad en `seg.memberships_menues` (ver la duda
   de ADM-UC-072 sobre las opciones que hoy solo tienen asignado el padre).

Si no es visible, el **motivo** es el primero que falla, en este orden: `sin_acceso` (1), `fuera_plan`
(💎), `sin_activar` (💤), `sin_permiso` (3). Además `otro_plan` = 💎 y de tipo pantalla o acción (lo usan
REQ-009 y REQ-012).

### Dónde vive cada regla

- **R1 y R2 se calculan en el DataService**, en una consulta cada una (recursos nuevos de
  `ADMDataService`), para que el módulo, el menú resuelto (REQ-009), Tools (H-091) y el agente
  (REQ-011) usen la misma regla sin copiarla (lógica de negocio en las APIs).
- El módulo tiene un modelo (por ejemplo `Visibilidad`, en `traz-comp-adm/models/`) que toma correo y
  empresa **de la sesión** y llama a esos recursos. Otros módulos de Tools lo pueden cargar con el
  prefijo `ADM`, sin pasar por el navegador.
- **Servicio para el navegador**: `GET traz-comp-adm/servicios/funcionalidad-visible/{modulo}/{opcion}`,
  de solo lectura, que pasa por el controlador base (sesión obligatoria; empresa y persona de la sesión;
  cualquier `empr_id` o correo que venga en el pedido se ignora). Responde:

| Caso | Respuesta | Cuerpo (JSON) |
|---|---|---|
| Visible | 200 | `{"visible": true}` |
| No visible | 403 | `{"visible": false, "motivo": "<motivo>", "mensaje": "<texto>"}` |
| Módulo + opción no existe, o no está publicada | 404 | `{"visible": false, "motivo": "no_existe", "mensaje": "Esa página no existe."}` |
| Sin sesión | 401 | (lo resuelve el controlador base de REQ-002) |

Textos del `mensaje` (RF-94, RF-03, RF-04):

| Motivo | Mensaje |
|---|---|
| `fuera_plan`, `sin_activar` | "Esa funcionalidad no está activa para tu empresa." |
| `sin_permiso` | "Tu rol no tiene acceso a esa funcionalidad." **[SUPUESTO]** |
| `sin_acceso` | El de la variable `texto_suspension_miembro` o `texto_suspension_empresa` (REQ-004), con `{empresa}` y `{contacto}` reemplazados |

### Activar, desactivar y ordenar

- Activar o desactivar escribe la fila de la empresa en `seg.empresas_funcionalidades` (la crea si no
  existe). Nunca se borra una fila: al salir del plan se **conservan** `activa` y `orden` (RF-52) y al
  volver reaparece igual.
- Una funcionalidad que se activa por primera vez va **al final** del orden **[SUPUESTO]**.
- Ordenar: se arrastra dentro de ✅ activas y se guarda solo ("Guardado ✓").
- Solo se pueden activar las que están 💤 (en el plan). El servidor rechaza activar una 💎, aunque el
  pedido llegue directo.
- La empresa sale **siempre** de la sesión.
- Cada cambio se audita en `seg.auditoria`, en la misma operación (ver la duda de ADM-UC-071).

### Ícono del plan en el Portal

La cabecera del Portal (marco de REQ-002) suma debajo del nombre de la empresa "<ícono> Plan <nombre>"
(maqueta `empresa-funcionalidades.html`). El Contexto del usuario (REQ-004) agrega ese dato; la barra de
Tools **no** cambia.

---

## De dónde sale cada dato

| Dato | De dónde | Cómo |
|---|---|---|
| Sesión, empresa activa, correo | Sesión de Tools | Ya existe |
| Es administrador | `ADMDataService GET /usuario/es-admin/{email}/empresa/{empr_id}` | Ya existe (REQ-004) |
| Plan de la empresa (ícono, nombre, estado del plan) | `ADMDataService GET /empresa/{empr_id}/plan` | **NUEVO** |
| Funcionalidades con su grupo (R1) | `ADMDataService GET /empresa/{empr_id}/funcionalidades` | **NUEVO** |
| Activar / desactivar | `ADMDataService PUT /empresa/funcionalidad` | **NUEVO** |
| Orden | `ADMDataService PUT /empresa/funcionalidades/orden` | **NUEVO** |
| Visible para una persona (R2) | `ADMDataService GET /funcionalidad-visible/{email}/empresa/{empr_id}/{modulo}/{opcion}` | **NUEVO** |
| Textos de suspensión | `ADMDataService GET /variables` | Ya existe (REQ-004) |
| Auditoría | Dentro de cada recurso que escribe | Tabla de REQ-004 |

**Nada va directo a la base.** Las direcciones van en kebab-case y las claves JSON en snake_case.

---

## Pantallas

### Portal — menú lateral

Se agrega "🧩 Funcionalidades". `data-testid`: `adm-portal-menu-funcionalidades`.

### Portal → Funcionalidades — `traz-comp-adm/portal/funcionalidades`

Maqueta `doc/v3/dnato/mockups/empresa-funcionalidades.html`.

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Plan en la cabecera | "<ícono> Plan <nombre>" debajo del nombre de la empresa | `adm-portal-plan` |
| Título | "Funcionalidades" y "Elegí qué usa tu empresa dentro del plan <ícono> <plan> y ordenalas arrastrando. Ese orden es el del menú predeterminado." | `adm-funcionalidades` |
| ✅ Activas | "N · arrastrá para ordenar · este orden es el del menú predeterminado"; por fila "⋮⋮", ícono y nombre, módulo, interruptor encendido | `adm-func-activas`; fila `adm-func-<modulo>-<opcion>`; interruptor `adm-func-interruptor-<modulo>-<opcion>` |
| 💤 Sin activar | "Están en tu plan, las apagaste. Tus usuarios no las ven."; por fila, interruptor apagado | `adm-func-sin-activar` |
| 💎 De otros planes | Texto (ver la duda de ADM-UC-070); por fila, ícono y nombre, módulo y el ícono y nombre del plan más bajo que la trae; **sin interruptor** | `adm-func-otros-planes`; plan `adm-func-plan-<modulo>-<opcion>` |
| Herramientas de IA | Dentro de cada grupo, las del módulo MCP bajo el rótulo "🤖 IA" | `adm-func-ia` |
| Cómo funciona | Los cinco renglones de la maqueta (activa, sin activar, de otro plan, bajar de plan, herramientas de IA) | `adm-func-ayuda` |
| Guardado | "Guardado ✓" | `adm-guardado` |
| Plan vencido | Aviso arriba: "Tu período de prueba terminó." y todo en 💎 **[SUPUESTO]** del texto completo (el de CP-19 vive en Plan, REQ-010) | `adm-func-plan-vencido` |

Mensajes **[SUPUESTO]** (tuteo, RNF-09):

| Caso | Mensaje | `data-testid` |
|---|---|---|
| Activar algo de otro plan (pedido directo) | "Esa funcionalidad no está en tu plan." | `adm-func-error` |
| Falla del servicio | "No pudimos guardar. Probá de nuevo en un rato." | `adm-func-error` |
| Empresa sin funcionalidades activas | "Todavía no activaste ninguna funcionalidad. Encendé las que use tu empresa." | `adm-func-vacio` |

---

## Reglas

1. Solo el administrador de la empresa activa ve y cambia sus funcionalidades.
2. R1 y R2 se calculan en un solo lugar (el DataService) y todos los que las usan llaman a ese lugar.
3. Solo aparecen funcionalidades publicadas; lo sin publicar o despublicado no está en ningún grupo ni
   es visible para nadie (404 en el servicio).
4. Solo se activa lo que está en el plan; lo de otro plan no tiene interruptor y el servidor rechaza
   activarlo.
5. Lo de otro plan muestra el ícono y nombre del plan de **menor orden** que lo trae.
6. Activar, desactivar y ordenar se guarda solo y queda auditado.
7. Salir del plan conserva activación y orden; volver al plan lo devuelve igual. Nunca se borra la fila.
8. Con plan vencido, todo es de otro plan y el plan que se muestra es el no gratuito de menor orden.
9. Visible para una persona = membresía activa ∧ empresa no suspendida ∧ ✅ para la empresa ∧ su rol
   tiene acceso. Si no, 403 con el primer motivo que falla; si no existe, 404.
10. Empresa y persona salen siempre de la sesión; lo que venga en el pedido se ignora.
11. El servicio es de solo lectura: un GET no cambia nada.

## Registro en el log

`log_message('DEBUG', '#TRAZA | ADM | <Clase> | <metodo>() ...')`. Se registran los rechazos y cada cambio
de activación y de orden (empresa, funcionalidad, quién). El servicio "Funcionalidad visible" registra
solo las respuestas 403 y 404 (correo, empresa, módulo, opción, motivo), no cada consulta.

---

## Datos

**No hay cambios de base en este requerimiento.** Usa tablas que crea REQ-004 y que llena REQ-005:

| Tabla | Uso |
|---|---|
| `seg.empresas_funcionalidades` (`empr_id`, `modulo`, `opcion`, `activa`, `orden`) | Lee y escribe (solo filas de la empresa de la sesión) |
| `seg.planes`, `seg.planes_funcionalidades` | Lee |
| `seg.menues` (publicación, tipo) | Lee |
| `seg.memberships_menues`, `seg.memberships_users` | Lee (acceso del rol y rol de la persona). No se modifican |
| `seg.membresias_estado`, `core.empresas` (estado, plan, estado del plan) | Lee |
| `seg.auditoria` | Agrega filas |

---

## Decisiones tomadas

- **El control 403/404 vive solo en el módulo** (Rodolfo, 2026-11-10). El servicio queda listo para
  Tools; usarlo en las pantallas de Tools es H-091.
- **R1 y R2 en el DataService, no en PHP**: así la regla está una sola vez y la pueden usar el módulo,
  el menú resuelto, Tools y el agente (regla del repositorio: la lógica de negocio va en las APIs).
- **Nunca se borra una fila de funcionalidad de la empresa**: es lo que permite que bajar y volver a
  subir de plan devuelva todo igual (RF-52).
- **El servicio no lee empresa ni persona del pedido**: G2 de la especificación y regla 4 de REQ-002.
- **El orden del motivo es el mismo que el de "Consumir cuota"** (R5): primero el acceso, después el
  plan, después la empresa y por último el rol.

## Cómo se revisa (además de DocTest)

- Con la matriz de REQ-005, quitar una funcionalidad del plan y volver a ponerla: la fila de la empresa
  en `seg.empresas_funcionalidades` sigue igual (activa y orden).
- El servicio responde 401 sin sesión, y no acepta `empr_id` ni correo en la dirección, el formulario o
  un encabezado.
- DocTest `regresion` en verde: el menú de Tools no cambió.
- `phpcs` con PHPCompatibility para PHP 5.6 sin errores; `./mvnw clean install` del proyecto de APIs.
- **Aviso para el despliegue:** el script de despliegue sube los DataServices pero no las APIs; este
  requerimiento no agrega APIs.

## Dudas abiertas

Están en los casos de uso (campo `dudas`), para contestarlas en un solo lugar.

---

## Casos de prueba de la especificación que cubre

| CP | Qué prueba | Lo cubre |
|---|---|---|
| CP-50 | Tres grupos de funcionalidades; las de otros planes sin interruptor | ADM-UC-070 |
| CP-15 | Ícono del plan más bajo | ADM-UC-070 (en Funcionalidades). "Bruno la ve sombreada en el menú": REQ-009 y su derivación en Tools |
| CP-41 | Sin publicar no se ve en ninguna empresa | ADM-UC-070 (no está en ningún grupo) y ADM-UC-072 (404). "Ni en menús": REQ-009 |
| CP-53 | Las herramientas de IA se ven en Funcionalidades | ADM-UC-070 (bajo "IA"). "En la comparativa de Plan": REQ-010. "No en el constructor de menús ni en el menú operativo": REQ-009 |
| CP-14 | Quitar del plan conserva la activación | ADM-UC-071 (activación y orden se conservan). "Queda en el menú de carla@ con estado otro_plan": REQ-009 |
| CP-52 | Bajar y volver a subir conserva activación, orden y menús | ADM-UC-071 (activación y orden, probado quitando y volviendo a poner en la matriz, porque el cambio de plan de una empresa es REQ-008). "Reaparece en el menú Gestión": REQ-009 |
| CP-91 | Pedir a mano una funcionalidad no visible da 403; inexistente 404 | ADM-UC-072, **contra el servicio** "Funcionalidad visible". Que la dirección de la pantalla de Tools responda 403: fuera de alcance (H-091) |
| CP-92 | Lo que el rol no permite no aparece (botón "Nuevo equipo") | En parte: ADM-UC-072 (el servicio responde `sin_permiso`). Que la pantalla de Tools oculte el botón: fuera de alcance (H-091) |
