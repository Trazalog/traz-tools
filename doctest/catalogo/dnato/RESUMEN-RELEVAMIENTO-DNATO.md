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
| 6 | **La eliminación de usuarios se esperaba lógica** — el código hace borrado físico (H-002): decisión pendiente, issue #451 |
| 7 | **Los menúes se asignan solos** al crear la empresa (trigger `core.configuracion_inicial_empresa_trg()`); la pantalla "Menu por Rol" es el ajuste posterior. Verificado en el script del trigger |
| 8 | **Los hallazgos van a un registro central**: `doc/hallazgos/REGISTRO.md`. Los bugs además abren issue con label `hallazgo` |

## 4. Lo que falta para cerrar la fase

### 4.1 Bloqueantes

1. **Casilla de correo de prueba.** Dos casos dependen de leer un mail (activación, UC-002; recuperación, UC-008) y sin eso tampoco puedo crear la empresa de test de cero, porque el alta pasa por el enlace de activación. **Mi recomendación: una casilla de Gmail dedicada** (por ejemplo `doctest.trazalog@gmail.com`) con IMAP habilitado y contraseña de aplicación. El motivo no es la comodidad: al ser un webmail público, el alta **obliga** a tipear el dominio corporativo de la empresa, así que los cinco usuarios iniciales quedan en un dominio inventado (`doctest-empresa.com`) y **no** en `trazalog.com`, donde chocarían con direcciones reales de ustedes. Si preferís una casilla del servidor propio, hay que elegir un dominio que no se use (por ejemplo `doctest.trazalog.com`).
2. **El usuario de prueba nuevo todavía no puede entrar.** `admin@doctest-empresa.com` no supera la validación de credenciales en el DEMO (verificado por dos caminos, ver §4.2), y no hay ninguna empresa cuyo nombre contenga "doctest" entre las 32 del sistema. Hasta que eso se resuelva, el caso de aislamiento (UC-013) sigue sin poder probarse: el usuario anterior era **el superusuario del DEMO** y tenía roles en seis empresas.
3. **Nombres de los perfiles (UC-019).** Vos los describís como *Administrador* y *Usuario*; la tabla `seg.roles` del DEMO dice **`Admin`** y **`Author`**. ¿Renombramos los datos, o el catálogo y las ayudas adoptan lo que el usuario ve hoy?

### 4.2 Diagnóstico del usuario de prueba nuevo (2026-08-24)

`admin@doctest-empresa.com` / la contraseña provista **no entra** en el DEMO. Verificado por dos caminos independientes, ninguno con efectos sobre los datos:

1. **Login web**: no aparece ninguna empresa con "doctest" entre las 32 del combo, y con las tres candidatas (`ClientesTrazalog`, `Empresa_de_Prueba_2`, `Prueba 1`) el sistema responde *"El usuario no corresponde a la empresa seleccionada"* — mensaje que sale **antes** de validar la contraseña.
2. **Login OAuth** (`/oauth/login`, que no pide empresa y resuelve la membresía sola): responde *"Correo o contraseña incorrectos"*. Como control, el mismo camino con el usuario anterior sí emite el código de autorización, así que la mecánica de la prueba es correcta.

Las tres explicaciones posibles, en orden de probabilidad: la cuenta se creó pero **nunca se activó** (queda sin contraseña, y `checkLogin` falla igual que con una contraseña equivocada); la empresa se creó en `core.empresas` pero **sin el grupo en Bonita**, que es de donde sale el combo; o la contraseña es otra.

### 4.3 Dudas funcionales que quedan abiertas

| Caso | Duda |
|---|---|
| UC-003 | ¿Las respuestas del formulario de registro tienen consecuencia funcional (tier, alta, algo que el usuario vea después) o son información comercial? |
| UC-014 | La etiqueta "Rol" del alta de usuario es en realidad el **perfil de DNATO**. ¿La renombro a "Perfil" para que no se confunda con los roles de trabajo? |
| UC-017 | El borrado es físico (H2): ¿se corrige a baja lógica o el caso documenta lo que hace hoy? |
| UC-020 | Mi lectura: usuario externo = alguien que representa a una empresa de afuera (guarda razón social y CUIT propios, no se crea en Bonita). ¿Es esa la intención? |
| UC-023 | El alta de empresa del superusuario **no valida duplicados** (el control está comentado) y **no crea** el establecimiento, el depósito ni los cinco usuarios iniciales, a diferencia del registro. ¿Es intencional? |
| UC-025 | Cuando se crea una empresa con sus 16 roles, **¿los menúes se asignan solos o hay que asignarlos a mano?** Si es a mano, una empresa recién creada no ve ningún menú y el alta queda incompleta de cara al usuario |
| UC-021 / UC-024 | Tanto la configuración del sitio como las opciones de menú son **globales del sistema**: cualquier administrador de cualquier empresa las cambia para todos. ¿Debería restringirse al superusuario? |

## 5. Hallazgos

Ya no viven acá: se mudaron al **registro central** [`doc/hallazgos/REGISTRO.md`](../../../doc/hallazgos/REGISTRO.md), que es el lugar único para bugs, deudas y mejoras de todo el proyecto. Los que salieron de este relevamiento son **H-001 a H-014**.

Con issue abierto (los cuatro bugs más pesados):

| Hallazgo | Issue | Qué es |
|---|---|---|
| H-002 🔴 | [#451](https://github.com/Trazalog/traz-tools/issues/451) | La eliminación de usuarios es **física**, no lógica, y no da de baja en Bonita ni Asset |
| H-012 🔴 | [#452](https://github.com/Trazalog/traz-tools/issues/452) | El rol **Responsable de Procesos nunca ve su menú**: el trigger lo escribe sin "de" |
| H-008 🔴 | [#453](https://github.com/Trazalog/traz-tools/issues/453) | `edituser`/`deleteuser` **no verifican** que el usuario sea de una empresa del administrador |
| H-001 🔴 | [#454](https://github.com/Trazalog/traz-tools/issues/454) | Los usuarios iniciales nacen con contraseña `12345`, mostrada en pantalla |

Los otros diez (H-003 a H-007, H-009 a H-011, H-013, H-014) quedan en el registro esperando tu triaje.

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
