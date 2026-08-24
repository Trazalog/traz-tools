# Relevamiento de DNATO — resumen para validación

## Objetivo

Es la hoja de ruta de la sesión en la que Rodolfo valida el catálogo funcional de DNATO (registración y administración de cuenta). Está escrito para leerse **antes** de abrir los 25 archivos YAML: dice qué se relevó, qué decisiones ya están tomadas, qué queda por decidir y qué hallazgos aparecieron. **No** cubre el diseño de DocTest (`doc/v3/TRAZALOG_v3_DOCTEST_01/02/03`) ni ningún test: mientras los casos estén en `borrador` no se genera ningún derivado (RF-01.3).

- Fase: **F1** · issue [#438](https://github.com/Trazalog/traz-tools/issues/438) · clase 🟡
- Fuentes: `traz-comp-dnato` rama `develop-v3` (commit `0927209`) · `traz-tools` (`toolsCOREAPI.xml`) · **verificación en vivo contra el entorno DEMO** (2026-08-19)
- Estado: **25 casos en `borrador`, 0 validados.** Nada derivado todavía.
- Revisión 2 (2026-08-19): incorpora las respuestas del PM y una segunda pasada más profunda sobre código y datos.

---

## 1. Cómo funcionan los permisos (esto ordena todo el módulo)

Hay **dos sistemas de permisos que conviven**, y confundirlos era el error de la primera pasada:

| | Perfil de DNATO | Rol de trabajo de Tools |
|---|---|---|
| **Qué dice** | Qué puede **administrar** el usuario | Qué puede **hacer** en la operación |
| **Dónde vive** | `seg.users.role` → `seg.roles` (Dnato) | Bonita: grupo = empresa, rol = trabajo |
| **Alcance** | Global del usuario | Por empresa (un usuario puede tener roles en varias) |
| **Valores** | `Admin` (1) · `Author` (2) · `Usuario externo` (8) | Los 16 que crea el alta de empresa |
| **Quién lo cambia** | Administrador, en "Cambio de Rol" | Administrador, en la misma pantalla |

Y por encima, el **superusuario**: no es un perfil de la base sino **un correo fijado en `constants.php`** (`TOOLS_ADMIN_USER`), distinto por ambiente. Es el único que ve "Gestión de Empresas".

Lo que habilita cada uno, verificado en el menú real:

- **Administrador** (`is_admin`): Gestión de Usuarios · Gestión de Menúes · Carga Masiva · Configuración.
- **Usuario** (no admin): solo sus datos personales.
- **Superusuario**: todo lo anterior **+ Gestión de Empresas** (listar y crear empresas).

**Los 16 roles de trabajo los crea el alta de empresa**, en la orquestación WSO2 `toolsCOREAPI` (POST `/empresa`), con el nombre `<Rol> <NombreEmpresa>`, y los mapea como actores de los procesos de Bonita:

> Responsable de Almacén · Solicitante de Almacén · Responsable de Producción · Responsable de Lote · Responsable de Pañol · Planificador de Tareas · Responsable de Procesos · Supervisor de Mantenimiento · Planificador de Mantenimiento · Solicitante de Mantenimiento · Mantenedor · Administrador · SMA - Transportista · SMA - Generador · SMA - Operario Descarga · SMA - Operador de Bascula

Y **`seg.memberships_menues`** (pantalla "Menu por Rol") es la pieza que conecta esos roles con las opciones de menú que cada usuario ve en Tools.

## 2. Qué se relevó

| Bloque | Casos | Perfil |
|---|---|---|
| Registración freemium | UC-001 registro · UC-002 activación · UC-003 información adicional · UC-004 alta de empresa · UC-005 bienvenida | Visitante → Administrador |
| Acceso | UC-006 login · UC-007 salir · UC-008 recuperar contraseña · UC-009 login OAuth de agentes | Usuario |
| Cuenta propia | UC-010 ver perfil · UC-011 editar perfil · UC-012 cambiar contraseña | Usuario |
| Administración de usuarios | UC-013 listar · UC-014 alta · UC-015 editar · UC-016 habilitar/inhabilitar · UC-017 eliminar · UC-018 roles de trabajo · UC-019 perfil de DNATO · UC-020 usuario externo | Administrador |
| Administración de la plataforma | UC-021 configuración · UC-024 opciones de menú · UC-025 menú por rol | Administrador |
| Empresas | UC-022 listar empresas · UC-023 alta de empresa | Superusuario |

Fuera de alcance por ahora: **Carga Masiva** (`Bulkload.php`) — no es registración ni administración de cuenta; decime si entra.

## 3. Decisiones ya tomadas (2026-08-19)

| # | Decisión |
|---|---|
| 1 | **ABM de Empresas, Menúes y Configuración entran en la Ola 1**, cada uno con su perfil correcto (Empresas = Superusuario; Menúes y Configuración = Administrador) |
| 2 | **Automatización del registro: opción (b)** — se automatiza todo contra una empresa de test descartable y se acepta la basura acumulada, con re-seed periódico. **Queda anotado como deuda: falta un procedimiento de limpieza** (candidato a issue propio) |
| 3 | **La empresa de test se crea de cero**, no se usa Conservas: sus datos en Asset Planner no están bien creados. Verificado: Conservas tiene **un solo rol de trabajo** ("Almacen") porque es anterior al alta automática de 16 roles |
| 4 | **reCAPTCHA no se usa** en el entorno de pruebas: el registro y la recuperación son automatizables de punta a punta |
| 5 | **v3 cambia el login**: se elimina el desplegable de empresas. Se validan las credenciales y, si el usuario tiene más de una empresa, se le muestra un selector; si tiene una sola, entra directo. Aplica a las dos pantallas (web y OAuth), y resuelve la contradicción entre ellas |
| 6 | **La eliminación de usuarios se esperaba lógica** — el código hace borrado físico (ver H2): decisión pendiente |

## 4. Lo que falta para cerrar la fase

### 4.1 Bloqueantes

1. **Casilla de correo de prueba.** Dos casos dependen de leer un mail (activación, UC-002; recuperación, UC-008) y sin eso tampoco puedo crear la empresa de test de cero, porque el alta pasa por el enlace de activación. **Mi recomendación: una casilla de Gmail dedicada** (por ejemplo `doctest.trazalog@gmail.com`) con IMAP habilitado y contraseña de aplicación. El motivo no es la comodidad: al ser un webmail público, el alta **obliga** a tipear el dominio corporativo de la empresa, así que los cinco usuarios iniciales quedan en un dominio inventado (`doctest-empresa.com`) y **no** en `trazalog.com`, donde chocarían con direcciones reales de ustedes. Si preferís una casilla del servidor propio, hay que elegir un dominio que no se use (por ejemplo `doctest.trazalog.com`).
2. **Un administrador de prueba que no sea el superusuario.** El usuario que me pasaste es **el superusuario del DEMO** (ve "Gestión de Empresas") y tiene roles en seis empresas, así que ve usuarios de todas: con esa cuenta el caso de aislamiento (UC-013) no prueba nada. Con la empresa de test nueva queda resuelto: su administrador sirve.
3. **Nombres de los perfiles (UC-019).** Vos los describís como *Administrador* y *Usuario*; la tabla `seg.roles` del DEMO dice **`Admin`** y **`Author`**. ¿Renombramos los datos, o el catálogo y las ayudas adoptan lo que el usuario ve hoy?

### 4.2 Dudas funcionales que quedan abiertas

| Caso | Duda |
|---|---|
| UC-003 | ¿Las respuestas del formulario de registro tienen consecuencia funcional (tier, alta, algo que el usuario vea después) o son información comercial? |
| UC-014 | La etiqueta "Rol" del alta de usuario es en realidad el **perfil de DNATO**. ¿La renombro a "Perfil" para que no se confunda con los roles de trabajo? |
| UC-017 | El borrado es físico (H2): ¿se corrige a baja lógica o el caso documenta lo que hace hoy? |
| UC-020 | Mi lectura: usuario externo = alguien que representa a una empresa de afuera (guarda razón social y CUIT propios, no se crea en Bonita). ¿Es esa la intención? |
| UC-023 | El alta de empresa del superusuario **no valida duplicados** (el control está comentado) y **no crea** el establecimiento, el depósito ni los cinco usuarios iniciales, a diferencia del registro. ¿Es intencional? |
| UC-025 | Cuando se crea una empresa con sus 16 roles, **¿los menúes se asignan solos o hay que asignarlos a mano?** Si es a mano, una empresa recién creada no ve ningún menú y el alta queda incompleta de cara al usuario |
| UC-021 / UC-024 | Tanto la configuración del sitio como las opciones de menú son **globales del sistema**: cualquier administrador de cualquier empresa las cambia para todos. ¿Debería restringirse al superusuario? |

## 5. Hallazgos (documento, no corrijo)

| # | Hallazgo | Evidencia |
|---|---|---|
| H1 | Los cinco usuarios iniciales de cada empresa nacen con contraseña **`12345`**, y la pantalla de bienvenida la muestra en pantalla | `constants.php:230`, `Register::registro_completo()` |
| H2 | 🔴 **El borrado de usuarios es físico, no lógico**: `DELETE` sobre `seg.users_business` y después sobre `seg.users`. Además no da de baja al usuario en Bonita ni en Asset, así que queda huérfano ahí | `User_model.php:770-795`, `Main.php:693-741` |
| H3 | El **superusuario se define por un correo hardcodeado** en `constants.php`, distinto en cada ambiente. En el DEMO ese correo es el del usuario de prueba | `constants.php:105`, `Empresa.php:34,56` |
| H4 | El combo de empresas del login lista **todas** las empresas del sistema a cualquiera que abra la pantalla, sin sesión. Lo resuelve el cambio de v3 (decisión 5) | `Main.php:1362-1400` |
| H5 | Los mensajes de login y recuperación **distinguen** entre "no existe el correo", "no pertenece a la empresa" y "cuenta no aprobada": permiten averiguar desde afuera si un correo está registrado | `Main.php:1412, 1505-1512` |
| H6 | **Código muerto**: `Main::associaterol()` carga una vista `membership` que no existe en el repo; `changelevel.php`, `changeleveluser_old.php`, `changeuser_old` y `banuser_old` son pantallas anteriores ya sin enlace en el menú | `Main.php:1012-1030` y `application/views/` |
| H7 | **Editar un usuario obliga a reescribir su contraseña**: `edituser()` marca contraseña y confirmación como obligatorias igual que el alta | `Main.php:742-771` |
| H8 | `edituser()` y `deleteuser()` **no verifican** que el usuario objetivo pertenezca a una empresa del administrador | `Main.php:693-771` |
| H9 | El mensaje de error de habilitar/inhabilitar dice **"Error al borrar usuario"** — texto copiado de otra pantalla | `Main.php:500-554` |
| H10 | Cambiar la contraseña propia **no pide la contraseña actual** y, a diferencia de la activación, **no se propaga** a Bonita ni a Asset: la contraseña queda distinta entre sistemas | `Main.php:555-610` |
| H11 | El vencimiento de los enlaces de activación y recuperación compara la **fecha** de creación contra la de hoy: valen hasta la medianoche del día en que se generaron. Si la columna `seg.tokens.created` guardara hora, ningún enlace validaría nunca | `User_model.php:111-135` |

## 6. Detalle técnico que sirve para las fixtures

- La sesión es una `ci_session` de CodeIgniter sobre un único host, así que el `storageState` de Playwright (Doc 3 §4.3) es viable — se confirma al escribir las fixtures.
- El login de DNATO redirige a Tools (`/traz-tools/`): para quedarse en las pantallas de administración hay que navegar explícitamente después de entrar.
- La pantalla "Cambio de Rol" (`main/changeleveluser/{id}`) maneja **perfil y roles juntos** y guarda todo en una sola llamada (`changeLevelRolUserObject`), con reversión si falla Bonita. El combo de roles se carga por AJAX al elegir la empresa.
- Los nombres de campo del formulario de registro llevan el prefijo del `empr_id` temporal (`9000-como_enteraste`, `9000-cantidad_empleados`), mientras que `actividad_empresa[]` y `problemas_principales` no.

## 7. Estado y próximo paso

```
25 casos · borrador 25 · validado 0 · obsoleto 0
```

**Próximo paso: tu validación.** Sobre cada caso hace falta una de tres respuestas: *validado* (con las correcciones que quieras), *obsoleto*, o *sigue en borrador*. Recién con los casos en `validado` se generan las fixtures de login, los page objects, los specs y los `.feature`, que es la segunda mitad de F1.
