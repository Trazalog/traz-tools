# REQ-001 · Módulo Administración — Análisis inicial (sin código)

## Objetivo

Primer trabajo de Pablo para el módulo nuevo **Administración** de Tools (`traz-comp-adm`), que
reemplaza a DNATO por partes. Es un análisis, no se programa nada: deja escrito qué se reutiliza de DNATO, qué impacto
tiene en el agente (MCP) y en Tools, y cómo queda armado el módulo. Lo lee Pablo para hacer el
análisis y Rodolfo para aprobarlo. **No** cubre la construcción del módulo: eso va en REQ-002 y
siguientes (ver [`README.md`](README.md)). La forma de trabajar está en
[`doc/metodologia/GUIA_REQUERIMIENTOS_CLAUDE_DEEPSEEK.md`](../doc/metodologia/GUIA_REQUERIMIENTOS_CLAUDE_DEEPSEEK.md).

| Campo | Valor |
|---|---|
| Estado | Listo para Pablo (al unirse a `develop`). Dudas contestadas por Rodolfo el 2026-11-03 |
| Qué entrega | `doc/v3/administracion/ANALISIS_INICIAL.md` (un solo documento, secciones A a F de abajo) |
| Fuente de lo funcional | Especificación DNATO v3 0.5.2 en `doc/v3/dnato/` (requisitos, casos de prueba, maquetas). Se usa el **qué**; el **cómo** (parchar DNATO) queda reemplazado por este replanteo |
| Repos que se leen | `traz-comp-dnato` (rama `feat/oauth-login-empresas-igual-que-el-web`), `traz-tools` |
| Riesgo | 🟢 Solo documentación. Pero lo que decide condiciona todo lo que sigue: Rodolfo lo aprueba antes de REQ-002 |
| Casos de uso | No tiene: es un análisis. Los casos de uso del módulo se escriben en REQ-002 con lo que salga de acá |

---

## El replanteo, en cuatro reglas

Decisión de Rodolfo (2026-11-03). Reemplaza el principio de la especificación "DNATO v3 se
construye sobre el DNATO actual" (`01_ESPECIFICACION_FUNCIONAL.md`, línea 8).

1. **Mismas tablas**, más lo que haga falta extender. `core.empresas`, `seg.users`,
   `seg.memberships_users`, `seg.menues`, `seg.memberships_menues`, `core.tablas`, `seg.tokens` y
   `sta.*` se siguen usando; lo nuevo se **agrega** (columnas o tablas), nunca se cambia lo que v2 usa.
2. **La registración y el ingreso se copian tal cual** están hoy en DNATO al módulo nuevo: mismo
   comportamiento, mismos pasos, mismas llamadas. DNATO **sigue funcionando en paralelo**, así se
   prueban los dos a la vez; cuando el módulo ande bien, se redirige a él y se apaga esa parte de DNATO.
3. **Se estudia el impacto en el servidor del agente (MCP).** Por ahora DNATO queda funcionando
   **solo** para lo que necesita el agente (opción D1). A futuro se migra el 100 % de DNATO y se apaga.
4. **Pantallas 100 % nuevas**, hechas de cero, con los datos leídos y escritos por DataServices.
   Se reutiliza lógica de DNATO solo cuando conviene.

```mermaid
flowchart LR
  subgraph NUEVO["Módulo Administración, dentro de Tools"]
    P[Pantallas nuevas]:::nuevo
    R[Registración e ingreso copiados tal cual]:::copia
    C[Carga masiva reutilizada]:::copia
  end
  DS[DataServices de WSO2]:::reusa
  T[Mismas tablas más extensiones]:::reusa
  D[DNATO: en paralelo y para el agente]:::viejo
  P --> DS
  R --> DS
  C --> DS
  DS --> T
  D --> DS
  classDef nuevo fill:#cfe8ff,color:#1a1a1a
  classDef copia fill:#fff1c2,color:#1a1a1a
  classDef reusa fill:#d9f2d9,color:#1a1a1a
  classDef viejo fill:#eeeeee,color:#1a1a1a
```

## Qué tiene que tener el análisis

El documento `doc/v3/administracion/ANALISIS_INICIAL.md` tiene estas seis secciones. Cada afirmación
dice de dónde sale (archivo y línea). Lo que sea un supuesto se marca como supuesto.

### A. Inventario de DNATO: qué se reutiliza

Una tabla con **cada controller, modelo y vista** de `traz-comp-dnato/application/` y, para cada uno:
**copiar tal cual / reutilizar la lógica / descartar**, y por qué. Punto de partida (propuesta de
Rodolfo y Claude, Pablo la verifica y la corrige):

| Pieza de DNATO | Propuesta | Motivo |
|---|---|---|
| `Register.php` y sus vistas (`register*.php`, `crear_empresa_page.php`, `formulario_registro.php`, `bienvenida_page.php`, `registro_completo.php`) | Copiar tal cual | Regla 2 |
| `Main::register`, `procesarRegistro`, `guardarFormularioRegistro`, `complete`, `successregister`, `successresetpassword` | Copiar tal cual | Regla 2 |
| `Bulkload.php`, `Bulkload_model.php`, `Bulkloads.php`, vistas `bulkload/` | Reutilizar la lógica, pantalla nueva | Regla 4 |
| `User_model`, `Empresas`, `Roles`, `Mmenu`, `Tablas`, `Establecimientos` | Reutilizar la lógica que llama a WSO2, si sirve | Ya acceden por WSO2, no van directo a la base |
| `Main` (usuarios, roles, niveles, baneo), `Menu`, `Empresa`, `Rol` y sus vistas | Descartar: pantallas nuevas | Regla 4. Hoy tienen los agujeros de seguridad del relevamiento §1.6 |
| `Oauth.php`, `Oauthlogin.php`, `OauthCode_model.php`, vistas `oauth/` | Quedan en DNATO (ver sección D) | Los usa el agente |
| `Main::login`, `checkLoginUser`, `seleccionar_empresa`, `logout`, `forgot`, `reset_password` y sus vistas (`login*.php`, `forgot.php`, `reset_password.php`, `complete*.php`) | Copiar tal cual | Regla 2. DNATO conserva los suyos en paralelo |
| `Email`, `Test`, `Test_formularios`, `Bulkload copy.php`, `*_old*`, archivos `smtp_*`/`test_*` de la raíz | Descartar | Son de prueba o están sin uso |

### B. Tablas y DataServices

- Qué tablas lee y escribe hoy DNATO y por **qué DataService** de WSO2 (nombre del `.dbs` y del
  recurso).
- Qué recursos ya existen y sirven tal cual para las pantallas nuevas, y cuáles faltan.
- Qué **extensiones** pide la especificación (`02_MODELO_Y_REGLAS.md` §2: plan, consumo MCP,
  auditoría, atributos nuevos), cada una como **agregado** sin tocar lo que v2 usa.
- El criterio para unir **membresía → empresa** (hoy distinto en DNATO y en los DataServices: regla
  R8 de la especificación). Medir con `traz-comp-dnato/scripts/sql/verificar-membresias-vs-empresas.sql`
  en DEMO y en una copia de producción cuántos usuarios quedan sin empresa con cada criterio, y poner
  los números. El script solo lee. **Nunca** se corre contra producción directa; la copia la provee
  Rodolfo.

### C. Registración e ingreso copiados

- La lista completa de lo que hay que copiar para que la registración y el ingreso (iniciar sesión,
  elegir empresa, salir, recuperar y restablecer contraseña) funcionen igual: controllers,
  vistas, archivos de estilo, constantes, llamadas a WSO2, a Bonita y a AssetPlanner, correos,
  usuarios por defecto, establecimiento por defecto.
- Qué cambia al vivir dentro de Tools: Tools exige sesión iniciada, y la registración y el ingreso
  tienen que ser públicos. Cómo se arma la excepción sin abrir otras rutas.
- Cómo conviven las dos versiones mientras corren en paralelo: las dos escriben en las mismas tablas
  y en Bonita, así que un usuario o una empresa creados por una tienen que funcionar en la otra. Qué
  sesión arma cada una y si Tools acepta las dos.
- Cómo se hará, el día que se decida, la redirección de las direcciones de hoy
  (`traz-comp-dnato/main/register`, `main/login`, enlaces en correos y en la web comercial). Se
  describe, no se hace.
- Cómo se prueba que quedó igual: las pruebas DNATO-UC-001 a 008 del catálogo tienen que pasar contra
  la copia, igual que pasan contra DNATO.

### D. Impacto en el agente (MCP)

Hoy el agente depende de DNATO para la identidad (decisión ADR-008 de
`doc/v3/TRAZALOG_v3_MCP_ARCHITECTURE.md`): DNATO emite el token que valida el APIM.
- Recorrer y listar todo lo que lo ata a DNATO: `Oauth.php` (`authorize`, `token`, `jwks`,
  `authorization_server_metadata`, `register_client`), `Oauthlogin.php`, la dirección de DNATO como
  emisor del token, la configuración del APIM como administrador de claves, y en `traz-tools`
  `_backend/api/ApimDiscoveryProject/src/OAuthDiscovery_1.0.0/oauth-discovery.xml`,
  `JwtValidator.xml`, `EmprIdFromHeader.xml`, `toolsCOREAPI.xml`, `toolsMANAPI.xml`.
- **Decidido por ahora: D1. DNATO queda para el agente.** No se toca nada de lo anterior. El análisis
  confirma que el módulo nuevo puede convivir así (por ejemplo, que un usuario creado por la
  registración copiada pueda usar el agente) y lista lo que se rompería si no.
- Para el futuro (migrar el 100 % de DNATO y apagarlo), describir qué haría falta para **D2. Mover la
  identidad del agente al módulo nuevo**: cambia el emisor del token, hay que reconfigurar el APIM y
  los clientes del agente se vuelven a registrar. Solo se describe; no entra en este trabajo.
- Qué servicios nuevos de la especificación necesita el agente (por ejemplo "Consumir cuota",
  `02_MODELO_Y_REGLAS.md` §4 y §5) y desde dónde se sirven en cada opción.

### E. Impacto en Tools

- Recorrer los puntos T-1 a T-10 de `doc/v3/dnato/02_MODELO_Y_REGLAS.md` §9b contra el código de
  Tools, ajustados al replanteo (por ejemplo, "Mi empresa" deja de ser un salto a otro sistema).
- Dónde entra el módulo en el menú de Tools y quién lo ve.
- Todo lo de Tools que hoy apunta a DNATO (por ejemplo la constante `DNATO` de
  `application/config/constants.php:93`, enlaces del menú, `Dash::cambiarDeEmpresa`) y qué pasa con
  cada uno.

### F. Cómo se arma el módulo

- Nombre y forma, ya decididos: submódulo **`traz-comp-adm`** con repositorio propio, en
  `application/modules/traz-comp-adm`, igual que `traz-comp-pan`. El repositorio lo crea Rodolfo
  antes de REQ-002.
- Estructura de carpetas (`controllers/`, `models/`, `views/`, constante de prefijo para cargarlo
  desde otros módulos, como `PRD` o `ALM`).
- Cómo hereda de Tools la sesión, la empresa activa, el menú y el control de permisos, de modo que
  **desde el primer día** tenga: sesión obligatoria, permiso por pantalla, protección contra envíos
  falsificados y la empresa siempre tomada de la sesión (nunca del navegador). Son los correctivos
  C-2, C-4 y C-6 de la especificación, que en el módulo nuevo nacen resueltos.
- Una propuesta de orden de construcción (qué REQ va después de cuál), usando las entregas E0 a E12
  de `doc/v3/dnato/PROMPT_CLI_DNATO_V3_BUILD.md` como lista de lo que hay que hacer.

## Qué NO hace

- **No** programa nada ni crea el repositorio del módulo.
- **No** cambia DNATO: sigue en producción como está.
- **No** decide: propone. Lo que queda por decidir (sobre todo el criterio membresía → empresa y el
  orden de construcción) lo decide Rodolfo al aprobar el análisis.

## Reglas para el análisis

- **Producción primero:** todo lo que hay hoy se asume funcionando en producción. Para cada pieza,
  mirar cómo está en `master` (Tools) y en la rama de producción de DNATO.
- **Compatibilidad v2:** ningún DataService ni API cambia lo que devuelve; si hace falta otra cosa,
  se agrega un recurso nuevo.
- **PHP 5.6:** lo que se copie o se proponga no puede usar sintaxis de PHP 7.

## Cómo lo aprueba Rodolfo

Igual que un plan (sección 2.4 de la guía): Pablo abre un pull request en borrador con
`ANALISIS_INICIAL.md`; Rodolfo comenta "✅ Plan aprobado" o pide cambios. Con eso aprobado, Rodolfo y
Claude escriben REQ-002 y sus casos de uso.

## Decisiones tomadas

Rodolfo, 2026-11-03:

1. El módulo es un **submódulo con repositorio propio** y se llama **`traz-comp-adm`**.
2. **El ingreso también se copia** (iniciar sesión, elegir empresa, salir, recuperar contraseña).
   DNATO sigue arriba en paralelo para probar los dos; si todo anda bien, en algún momento se redirige
   al módulo y se baja DNATO.
3. **D1 por ahora:** DNATO queda para lo del agente. Queda anotado como objetivo futuro migrar el
   100 % de DNATO y apagarlo.
4. Se trabaja sobre **`develop`**, siempre en una rama propia (`feature/req-001-...`) y entrando por
   pull request, nunca directo en `develop`.
5. Pablo **puede** correr el script de verificación de membresías en DEMO y en una copia de producción.

## Dudas abiertas

Ninguna por ahora. Las que aparezcan durante el análisis van en el pull request.
