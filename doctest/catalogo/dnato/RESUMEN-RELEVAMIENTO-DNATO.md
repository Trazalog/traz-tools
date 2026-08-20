# Relevamiento de DNATO — resumen para validación

## Objetivo

Es la hoja de ruta de la sesión en la que Rodolfo valida el catálogo funcional de DNATO (registración y administración de cuenta). Está escrito para leerse **antes** de abrir los 21 archivos YAML: dice qué se relevó, qué quedó afuera, qué hay que decidir y qué hallazgos aparecieron en el camino. **No** cubre el diseño de DocTest (`doc/v3/TRAZALOG_v3_DOCTEST_01/02/03`) ni ningún test: mientras los casos estén en `borrador` no se genera ningún derivado (RF-01.3).

- Fase: **F1** · issue [#438](https://github.com/Trazalog/traz-tools/issues/438) · clase 🟡
- Fuente relevada: `traz-comp-dnato`, rama `develop-v3` (commit `0927209`, 2026-08)
- Fecha del relevamiento: 2026-08-19
- Estado: **21 casos en `borrador`, 0 validados.** Nada derivado todavía.

---

## 1. Qué se relevó

| Bloque | Casos | Pantallas |
|---|---|---|
| Registración de una empresa nueva (freemium) | DNATO-UC-001 … 005 | Registro, activación, formulario de datos, alta de empresa, bienvenida |
| Acceso al sistema | DNATO-UC-006 … 009 | Ingreso con selección de empresa, salir, recuperar contraseña, ingreso OAuth para agentes |
| Cuenta propia | DNATO-UC-010 … 012 | Perfil, editar perfil, cambiar contraseña |
| Administración de usuarios de la empresa | DNATO-UC-013 … 019 | Lista de usuarios, alta, edición, habilitar/inhabilitar, quitar, roles, nivel |
| Otros | DNATO-UC-020, 021 | Usuario externo, configuración del sitio |

Fuentes usadas, en orden: los controladores y vistas de `traz-comp-dnato` (`Main.php` 1833 líneas, `Register.php` 1413, `Oauthlogin.php`, `Oauth.php`, `Empresa.php`, `Menu.php`), `application/config/routes.php`, `application/config/constants.php`, el `CLAUDE.md` del repo, y la verificación de que el entorno DEMO expone efectivamente estas pantallas.

## 2. Qué quedó afuera, y por qué

| Fuera de alcance | Motivo |
|---|---|
| ABM de Empresas (`Empresa.php`: listar, agregar, borrar) | Es administración de la plataforma, no de la cuenta propia. **Decisión tuya**: ¿entra en la Ola 1? |
| Menús y Menú por Rol (`Menu.php`) | Ídem: configuración de la plataforma |
| Carga masiva (`Bulkload.php`) | No es registración ni administración de cuenta |
| Formularios dinámicos (`traz-comp-formularios`) | Es un módulo aparte; acá solo aparece como paso del registro (DNATO-UC-003) |
| `banuser_old`, `changeleveluser_old`, `changeuser_old`, `Bulkload copy.php`, `Test.php` | Parecen restos de versiones anteriores. **Decisión tuya**: ¿se marcan como obsoletos? |

## 3. Lo que necesito de vos para cerrar la fase

### 3.1 Decisiones (bloquean la derivación)

1. **Vocabulario de perfiles.** El catálogo usa un vocabulario cerrado. A los cuatro roles ya validados (Solicitante, Supervisor, Planificador, Mantenedor) el relevamiento agrega tres, que el Doc 1 v1.1 RF-05.4 anticipa pero no nombra: **`Administrador`** (administra usuarios y datos de su empresa), **`Usuario`** (cualquiera autenticado, para los casos de cuenta propia) y **`Visitante`** (todavía no tiene cuenta). ¿Los aprobás con esos nombres?
2. **Alcance.** ¿Entran ABM de Empresas, Menús y Configuración del sitio (DNATO-UC-021) en la Ola 1, o son administración de plataforma y salen?
3. **Hasta dónde llega la automatización del registro.** El camino feliz de DNATO-UC-001 → 005 **crea datos reales**: una empresa, 5 usuarios en BPM, un establecimiento y un depósito, y no hay forma automática de darlos de baja. Las opciones que veo:
   - **(a)** Automatizar solo los caminos de error (correo duplicado, razón social repetida, teléfono inválido, empresa duplicada, dominio de webmail) y dejar el camino feliz como prueba manual documentada en la ayuda. *Es lo que recomiendo para arrancar.*
   - **(b)** Automatizar todo contra una empresa de test descartable y aceptar la basura acumulada, con un re-seed periódico.
   - **(c)** Automatizar todo y construir un procedimiento de limpieza (implica tocar datos: es 🟡 y necesita tu prueba).
4. **Segunda empresa de test.** Hoy tenemos solo Conservas. Sin una segunda no se puede probar el caso que verifica que un administrador **no** ve usuarios de otra empresa (DNATO-UC-013), que es el más valioso de todo el bloque.
5. **reCAPTCHA.** Si está activo en el entorno de pruebas, el registro y la recuperación de contraseña no son automatizables end-to-end. ¿Está activo? ¿Se puede usar una clave de test de Google para el entorno de pruebas?
6. **Correo.** Dos casos dependen de leer un mail (activación y recuperación de contraseña). ¿Hay una casilla de prueba accesible por API, o el test corta en "se envió el correo" y el tramo del enlace se prueba aparte?

### 3.2 Dudas funcionales, caso por caso

Cada YAML tiene su campo `dudas`. Las que más pesan:

| Caso | Duda |
|---|---|
| UC-002 | ¿Qué exige exactamente la regla de contraseña fuerte (`password_strong`)? Sin eso no puedo escribir el caso de contraseña rechazada |
| UC-003 | ¿Qué campos tiene el formulario dinámico del registro y cuáles son obligatorios? Está definido en datos, no en código |
| UC-009 | ¿El login OAuth se prueba acá (Playwright) o en F4 (Hurl)? Y: la regla "un usuario, una empresa" del OAuth contradice al login web, que deja elegir entre varias |
| UC-017 | "Eliminar" ¿saca al usuario de la empresa o borra la cuenta? El código hace las dos cosas y la pantalla no lo aclara |
| UC-018 | Hay cuatro métodos que parecen hacer lo mismo con los roles. ¿Cuáles usa la pantalla real? |
| UC-019 | Conviven "nivel" (1-4, de Dnato) y roles de BPM. ¿Cuál manda de cara al usuario? |
| UC-020 | ¿Qué es funcionalmente un "usuario externo"? |

## 4. Hallazgos del relevamiento (documento, no corrijo)

Aparecieron mirando el código. Ninguno se tocó; los listo para que decidas si abrís issues.

| # | Hallazgo | Dónde |
|---|---|---|
| 1 | Los 5 usuarios que se crean al dar de alta una empresa nacen con la contraseña **`12345`**, y la pantalla de bienvenida la muestra en pantalla. No encontré nada que obligue a cambiarla | `constants.php:230`, `Register::registro_completo()` |
| 2 | **Editar un usuario exige reescribir su contraseña**: `edituser()` marca contraseña y confirmación como obligatorias igual que el alta. Cambiar solo el apellido obliga a fijar una contraseña nueva | `Main.php:742-771` |
| 3 | El mensaje de error de habilitar/inhabilitar dice **"Error al borrar usuario"** — texto copiado de otra pantalla | `Main.php:500-554` |
| 4 | El combo de empresas del login lista **todas** las empresas del sistema a cualquiera que abra la pantalla, sin sesión | `Main.php:1362-1400` |
| 5 | Los mensajes de login y de recuperación **distinguen** entre "no existe el correo", "no pertenece a la empresa" y "cuenta no aprobada": permiten averiguar si un correo está registrado | `Main.php:1412, 1505-1512` |
| 6 | Cambiar la contraseña propia **no pide la contraseña actual** y, a diferencia de la activación, no se propaga a BPM/Asset | `Main.php:555-610` |
| 7 | `edituser()` y `deleteuser()` no verifican que el usuario objetivo pertenezca a la empresa del administrador | `Main.php:693-771` |
| 8 | La configuración del sitio (título, zona horaria, reCAPTCHA, tema) parece **global**, no por empresa | `Main.php:117-177` |

## 5. Estado y próximo paso

```
21 casos · borrador 21 · validado 0 · obsoleto 0
```

El validador pasa en verde (`npm run validate:catalog`), justamente porque cada caso declara sus dudas: la regla R1 exige que un `borrador` las tenga y que no arrastre ningún derivado.

**Próximo paso: tu validación.** Sobre cada caso hace falta una de tres respuestas: *validado* (con las correcciones que quieras al texto), *obsoleto* (el flujo ya no existe o no se sostiene) o *sigue en borrador* (falta definir algo). Recién con los casos en `validado` se generan las fixtures de login, los page objects, los specs y los `.feature`, que es la segunda mitad de F1.
