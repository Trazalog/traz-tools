# Registro de hallazgos

## Objetivo

Es el lugar único donde se anotan los **hallazgos** del proyecto: bugs, deudas y mejoras que aparecen mientras se hace otra cosa (un relevamiento, una migración, un despliegue) y que **no se corrigen en esa misma tarea**. Está escrito para el PM, que tría y prioriza, y para Claude Code, que lo alimenta. **No** es un backlog de features (eso son los issues del Project) ni un registro de decisiones (eso es `doc/v3/STATE.md`).

Sin este archivo, un hallazgo vive en la descripción de un PR que se mergea y se pierde de vista. Acá queda con su evidencia y su estado.

---

## Cómo se usa

**Al encontrar algo:**

1. Agregar una fila a la tabla con el próximo `H-NNN`. Nunca se reutiliza un número.
2. Escribir la evidencia concreta: archivo y línea, o la consulta/verificación que lo demuestra. Un hallazgo sin evidencia no entra.
3. **Si es un bug** (el sistema hace algo distinto de lo que dice hacer): además se abre un issue de GitHub con label `hallazgo` + `bug`, y se pone su número en la columna Issue.
4. **Si es una mejora o una deuda**: queda solo acá hasta que el PM decida. Si decide hacerlo, ahí se abre el issue.

**Regla:** el hallazgo se documenta, **no se corrige en la tarea que lo encontró** — salvo que el PM lo pida explícitamente. Corregir de paso mezcla el diff y rompe la revisión.

**Estados:** `abierto` · `en issue #N` · `corregido en #N` · `descartado (motivo)` · `es correcto` (se verificó y funciona como se espera).

**Severidad:** 🔴 datos incorrectos, fuga entre empresas o pérdida de información · 🟡 afecta al usuario pero tiene rodeo · 🟢 cosmético o interno.

---

## Hallazgos

| ID | Fecha | Origen | Repo / Módulo | Tipo | Sev | Resumen | Evidencia | Estado |
|---|---|---|---|---|---|---|---|---|
| H-001 | 2026-08-19 | DocTest F1 | traz-comp-dnato / registración | bug | 🔴 | Los cinco usuarios iniciales de cada empresa nacen con la contraseña `12345`, y la pantalla de bienvenida la muestra en pantalla. Nada obliga a cambiarla | `constants.php:230`, `Register::registro_completo()` | en issue #454 |
| H-002 | 2026-08-19 | DocTest F1 | traz-comp-dnato / usuarios | bug | 🔴 | "Eliminar usuario" hace **borrado físico**: `DELETE` sobre `seg.users_business` y después sobre `seg.users`. Se esperaba baja lógica. Además no da de baja al usuario en Bonita ni en Asset, así que queda huérfano ahí | `User_model.php:770-795`, `Main.php:693-741` | en issue #451 |
| H-003 | 2026-08-19 | DocTest F1 | traz-comp-dnato + BD | deuda | 🟡 | El superusuario está definido **en dos lugares distintos y desacoplados**: `TOOLS_ADMIN_USER` en `constants.php` (controla el menú de Gestión de Empresas) y `core.tablas.coresuper_admin` (lo usa el trigger de alta de empresa, con `jperez@prueba.com` como default hardcodeado). Si no coinciden, el sistema tiene dos "superusuarios" con poderes distintos. **El trigger además agrega ese usuario a TODA empresa nueva con rol Administrador** — verificado en vivo el 2026-08-24: aparece en la lista de usuarios de la empresa de test recién creada | `constants.php:105`, `configuracion_inicial_empresa_trg_func.sql:15-25,55-60` | abierto |
| H-004 | 2026-08-19 | DocTest F1 | traz-comp-dnato / login | mejora | 🟡 | El combo de empresas del login lista **todas** las empresas del sistema a cualquiera que abra la pantalla, sin sesión | `Main.php:1362-1400` | abierto — lo resuelve el cambio de login previsto en v3 |
| H-005 | 2026-08-19 | DocTest F1 | traz-comp-dnato / login | mejora | 🟢 | Los mensajes de login y recuperación distinguen entre "no existe el correo", "no pertenece a la empresa" y "cuenta no aprobada": permiten averiguar desde afuera si un correo está registrado | `Main.php:1412`, `Main.php:1505-1512` | abierto |
| H-006 | 2026-08-19 | DocTest F1 | traz-comp-dnato | mejora | 🟢 | Código muerto: `Main::associaterol()` carga una vista `membership` que no existe en el repo; `changelevel.php`, `changeleveluser_old.php`, `changeuser_old`, `banuser_old` y `Bulkload copy.php` son versiones anteriores sin enlace en el menú | `Main.php:1012-1030`, `application/views/` | abierto |
| H-007 | 2026-08-19 | DocTest F1 | traz-comp-dnato / usuarios | bug | 🟡 | Editar un usuario **obliga a reescribir su contraseña**: `edituser()` marca contraseña y confirmación como `required`, igual que el alta. Cambiar solo el apellido fuerza una contraseña nueva | `Main.php:742-771` | abierto |
| H-008 | 2026-08-19 | DocTest F1 | traz-comp-dnato / usuarios | bug | 🔴 | `edituser()` y `deleteuser()` **no verifican** que el usuario objetivo pertenezca a una empresa del administrador conectado: con el id en la URL, un administrador puede editar o borrar usuarios de otra empresa | `Main.php:693-771` | en issue #453 |
| H-009 | 2026-08-19 | DocTest F1 | traz-comp-dnato / usuarios | bug | 🟢 | El mensaje de error de habilitar/inhabilitar dice "Error al borrar usuario" — texto copiado de otra pantalla | `Main.php:500-554` | abierto |
| H-010 | 2026-08-19 | DocTest F1 | traz-comp-dnato / cuenta | bug | 🟡 | Cambiar la contraseña propia no pide la contraseña actual y, a diferencia de la activación, **no se propaga** a Bonita ni a Asset: la contraseña queda distinta entre sistemas | `Main.php:555-610` | abierto |
| H-011 | 2026-08-19 | DocTest F1 | traz-comp-dnato / tokens | bug | 🟢 | El vencimiento de los enlaces de activación y recuperación compara la **fecha** de creación con la de hoy (`createdTS != todayTS`): valen hasta la medianoche, y si la columna guardara hora ningún enlace validaría nunca | `User_model.php:111-135` | abierto |
| H-012 | 2026-08-24 | DocTest F1 | traz-tools + BD / alta de empresa | bug | 🔴 | **Un rol se queda sin menú por una diferencia de nombre**: el alta crea el rol `Responsable de Procesos <empresa>` (en `toolsCOREAPI`) pero el trigger le asigna el menú a `Responsable Procesos <empresa>` (sin "de"). Los dos nombres nunca coinciden, así que ese rol no ve el módulo Procesos | `toolsCOREAPI.xml` (roles del POST /empresa) vs `configuracion_inicial_empresa_trg_func.sql:33-44` | en issue #452 |
| H-013 | 2026-08-24 | DocTest F1 | traz-tools + BD / alta de empresa | bug | 🟡 | El alta de empresa crea **16 roles** pero el trigger asigna menúes a **8**. Quedan sin ningún menú los cuatro de Mantenimiento (Supervisor, Planificador, Solicitante, Mantenedor) y los cuatro de SMA/Residuos (Transportista, Generador, Operario Descarga, Operador de Bascula). Para Mantenimiento puede ser correcto (vive en Asset Planner, aplicación aparte), pero **SMA es un módulo de Tools** | `toolsCOREAPI.xml` vs `configuracion_inicial_empresa_trg_func.sql:33-44` | abierto |
| H-014 | 2026-08-19 | DocTest F1 | traz-comp-dnato / empresas | deuda | 🟡 | El alta de empresa del superusuario **no valida duplicados** (el control de razón social está comentado) y **no crea** el establecimiento, el depósito ni los usuarios iniciales, a diferencia del alta por registración. Dos caminos para lo mismo, con resultados distintos | `Empresa.php:46-105` (control comentado en 118-121) vs `Register::guardarEmpresa()` | abierto |

---

## Origen de los hallazgos

| Origen | Qué es |
|---|---|
| `DocTest F1` | Relevamiento del catálogo funcional de DNATO (issue #438) |
| `DocTest F2..F5` | Fases siguientes de DocTest |
| `<tarea>` | Cualquier otra tarea del `STATE.md` que haya encontrado el hallazgo |
