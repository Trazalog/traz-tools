# Plan — REQ-001 · Módulo Administración — Análisis inicial (sin código)

| Campo | Valor |
|---|---|
| Requerimiento | [REQ-001](REQ-001-administracion-analisis.md) |
| Entregable | `doc/v3/administracion/ANALISIS_INICIAL.md` (secciones A a F) |
| Estado | En revisión (PR en borrador, esperando `✅ Plan aprobado`) |
| Fuentes | `doc/v3/dnato/` (especificación 0.5.2 + relevamiento), `traz-comp-dnato` (rama `feat/oauth-login-empresas-igual-que-el-web`, solo lectura), `traz-tools` |

## Reglas del plan

- Cada tarea se hace en **una o dos horas** y termina con un resultado revisable: una sección (o
  parte) de `ANALISIS_INICIAL.md` escrita.
- Cada tarea dice **qué sección cubre** y **qué archivos va a leer**.
- Están **ordenadas por dependencia**: el inventario A va antes que la propuesta de armado F; el
  criterio membresía→empresa (B.4) se cierra antes de tocar identidad en C/D.
- Nada de "hacer el análisis completo" en una tarea.
- **Compatibilidad v2 y "producción primero"**: ningún DataService/API cambia lo que devuelve; todo
  se asume funcionando en producción (`REQ-001` §"Reglas para el análisis").

---

## Tareas

### A. Inventario de DNATO

**T-01 · Inventario de controllers (sección A.1)**
- Lee: `traz-comp-dnato/application/controllers/` (Main, Register, Bulkload, Oauth, Oauthlogin, Empresa, Menu, Rol, Cli, Email, Test, Test_formularios, `Bulkload copy.php`) + `doc/v3/dnato/DNATO_v2_RELEVAMIENTO.md` §1.7.
- Escribe: tabla A.1 (copiar / reutilizar / descartar, con motivo), con ruta:línea.
- Resultado revisable: sección A.1 lista.

**T-02 · Inventario de models, librerías, helpers y config (secciones A.2 y A.4)**
- Lee: `traz-comp-dnato/application/models/`, `libraries/`, `helpers/`, `config/` + relevamiento §1.2, §7.1, §7.2.
- Escribe: tablas A.2 (models) y A.4 (librerías/helpers/config que toca la identidad).
- Resultado revisable: secciones A.2 y A.4.

**T-03 · Inventario de vistas (sección A.3)**
- Lee: `traz-comp-dnato/application/views/` (y subdirs `empresas/`, `menu/`, `bulkload/`, `oauth/`) + relevamiento §6.3.
- Escribe: tabla A.3 por grupo (login/registro, layout interno, ABM, carga masiva, OAuth, muertas).
- Resultado revisable: sección A.3.

### B. Tablas y DataServices

**T-04 · Tablas y canales de acceso (sección B.1)**
- Lee: relevamiento §2.0 y §2.1; `dnato/application/config/database.php`, `constants.php`.
- Escribe: B.1 (tabla "qué tablas por qué canal", tabla de tablas relevantes).
- Resultado revisable: sección B.1.

**T-05 · DataServices existentes y faltantes + extensiones (secciones B.2 y B.3)**
- Lee: `traz-tools/_backend/api/ToolsAPIProject/…/data-services/COREDataService.dbs`, `…/apis/toolsCOREAPI.xml`; `doc/v3/dnato/02_MODELO_Y_REGLAS.md` §2; relevamiento §2.0 (las 4 copias del `.dbs`).
- Escribe: B.2 (recursos que sirven vs. faltan) y B.3 (extensiones de §2).
- Resultado revisable: secciones B.2 y B.3.

**T-06 · Criterio membresía→empresa R8 (sección B.4)**
- Lee: `dnato/scripts/sql/verificar-membresias-vs-empresas.sql`, `02_MODELO_Y_REGLAS.md` §3 (R8), relevamiento §2.2.
- Escribe: B.4 con la **decisión ya tomada** (`nombre = "group"`, decisión 1) y sus tres derivadas:
  B.4a (corregir una vez las membresías que matchean solo por `descripcion`, con impacto en Bonita),
  B.4b (impedir nombres de empresa repetidos en el alta), B.4c (alinear `getUsersXGroup` y
  `getEsAdminXEmailEmpresa` a `nombre` sin cambiar lo que devuelven a v2). Los números reales quedan
  pendientes de la tarea manual T-SQL.
- Resultado revisable: sección B.4 redactada (sin números de DEMO/copia).

### C. Registración e ingreso copiados

**T-07 · Lista de lo que se copia (sección C.1)**
- Lee: `dnato/application/controllers/Main.php` (métodos login/register/complete/forgot/reset/seleccionar_empresa/logout), `Register.php`; vistas `login*`, `register*`, `forgot`, `reset_password`, `complete_password`, `crear_empresa_page`, `formulario_page`, `bienvenida_page`; `constants.php`.
- Escribe: C.1 (controllers/métodos, vistas, estilos, constantes, llamadas WSO2/Bonita/AssetPlanner, correos, usuarios/establecimiento por defecto).
- Resultado revisable: sección C.1.

**T-08 · Excepción pública, convivencia, redirección y prueba (secciones C.2–C.5)**
- Lee: `traz-tools/application/controllers/Dash.php`, `helpers/sesion_helper.php`, `helpers/login_helper.php`, `config/config.php` (sesión); relevamiento §3.1 (sesión compartida) y §3.4.
- Escribe: C.2 (excepción pública → **control general de Tools**, decisión 4), C.3 (convivencia, con el tiempo de sesión configurable en `constants.php`, decisión 2), C.4 (redirección futura → último paso, decisión 7), C.5 (prueba DNATO-UC-001 a 008).
- Resultado revisable: secciones C.2 a C.5.

### D. Impacto en el agente (MCP)

**T-09 · Qué ata al agente a DNATO + D1 (secciones D.1 y D.2)**
- Lee: `dnato/application/controllers/Oauth.php`, `Oauthlogin.php`, `libraries/JwtIssuer.php`, `config/jwt.php`, `config/oauth_clients.php`; `traz-tools/_backend/api/ApimDiscoveryProject/src/OAuthDiscovery_1.0.0/oauth-discovery.xml`, `…/sequences/JwtValidator.xml`, `…/sequences/EmprIdFromHeader.xml`.
- Escribe: D.1 (tabla de dependencias) y D.2 (convivencia D1 + qué se rompería si no).
- Resultado revisable: secciones D.1 y D.2.

**T-10 · D2 futuro + servicios nuevos (secciones D.3 y D.4)**
- Lee: `traz-tools/_backend/api/…/apis/toolsMANAPI.xml`, `toolsMCPAPI.xml`, `toolsCOREAPI.xml`; `02_MODELO_Y_REGLAS.md` §4 y §5.
- Escribe: D.3 (migración D2, solo descripción) y D.4 (servicio "Consumir cuota").
- Resultado revisable: secciones D.3 y D.4.

### E. Impacto en Tools

**T-11 · Puntos T-1 a T-10 + menú (secciones E.1 y E.2)**
- Lee: `02_MODELO_Y_REGLAS.md` §9b; `traz-tools/application/controllers/Dash.php`, `helpers/menu_helper.php`.
- Escribe: E.1 (T-1 a T-10 ajustados al replanteo) y E.2 (dónde entra el módulo en el menú, quién lo ve, con el Portal/Consola de **diseño propio** — decisión 6).
- Resultado revisable: secciones E.1 y E.2.

**T-12 · Todo lo que Tools apunta a DNATO (sección E.3)**
- Lee: `traz-tools/application/config/constants.php`, `helpers/login_helper.php`, `helpers/sesion_helper.php`, `modules/traz-comp-pan/views/layout/perfil.php` + grep `DNATO` sobre `application/`.
- Escribe: E.3 (tabla de dependencias con qué pasa con cada una).
- Resultado revisable: sección E.3.

### F. Cómo se arma el módulo

**T-13 · Nombre, forma, estructura y herencia (secciones F.1, F.2, F.3)**
- Lee: `traz-tools/application/modules/traz-comp-pan/` (estructura), `application/config/constants.php` (prefijos); **las maquetas del Portal y la Consola** (`doc/v3/dnato/mockups/inicio-admin.html`, `tools-barra-superior.html` y las `consola-*.html`/`empresa-*.html`) para respetar su diseño (decisión 6).
- Escribe: F.1 (submódulo `traz-comp-adm`), F.2 (estructura de carpetas + constante `ADM` confirmada + los dos layouts: identidad y "portal"), F.3 (herencia de Tools + correctivos que nacen resueltos).
- Resultado revisable: secciones F.1 a F.3.

**T-14 · Orden de construcción + cierre del documento (sección F.4 + supuestos/decisiones/pendientes)**
- Lee: `doc/v3/dnato/PROMPT_CLI_DNATO_V3_BUILD.md` (E0–E12), `requerimientos/README.md`.
- Escribe: F.4 (mapeo E0→E12 a REQ-002+) y la sección final de supuestos, decisiones `[DECISIÓN]` y pendientes.
- Resultado revisable: sección F.4 + cierre. **Con esto el documento queda completo y se pasa el PR a "Ready for review".**

---

## Tarea manual (la ejecuta Rodolfo — NO yo)

### T-SQL · Correr `verificar-membresias-vs-empresas.sql` en DEMO y en la copia de producción

> La ejecuta **Rodolfo a mano**. Todo es de **solo lectura** (solo `SELECT`s, no modifica nada). **NUNCA
> contra producción directa**; la copia la provee Rodolfo. El resultado alimenta la sección B.4.
>
> **El criterio ya está decidido (Rodolfo 2026-11-04):** `core.empresas.nombre = seg.memberships_users."group"`.
> Por eso no se comparan criterios: se miden los **tres números concretos** que necesita la sección B.4.

**Paso a paso:**

1. **Conseguir acceso de solo lectura** a la base PostgreSQL de DNATO de **DEMO** y a la **copia de
   producción** (host, usuario, base). No usar el usuario/clave de aplicación.

2. **DEMO primero.** Desde una terminal con `psql` (o pegando cada consulta en DBeaver/pgAdmin), correr
   las tres consultas de abajo.

3. **Medición 1 — usuarios y membresías que quedarían sin empresa usando solo `nombre`** (con el listado):
   ```sql
   -- 1a. Membresías huérfanas: el group no coincide con ningún nombre de empresa activa
   SELECT mu.email, mu."group" AS grupo_sin_empresa
     FROM seg.memberships_users mu
    WHERE NOT EXISTS (
          SELECT 1 FROM core.empresas e
           WHERE TRIM(e.nombre) <> '' AND UPPER(TRIM(e.nombre)) = UPPER(TRIM(mu."group"))
             AND e.eliminado = false)
    GROUP BY mu.email, mu."group"
    ORDER BY mu."group", mu.email;

   -- 1b. Usuarios que quedarían SIN NINGUNA empresa resoluble (la más importante: ideal 0 filas)
   SELECT u.email, COUNT(DISTINCT mu."group") AS membresias_totales
     FROM seg.users u
     JOIN seg.memberships_users mu ON LOWER(TRIM(mu.email)) = LOWER(TRIM(u.email))
    WHERE NOT EXISTS (
          SELECT 1 FROM seg.memberships_users mu2
           JOIN core.empresas e
             ON TRIM(e.nombre) <> '' AND UPPER(TRIM(e.nombre)) = UPPER(TRIM(mu2."group")) AND e.eliminado = false
          WHERE LOWER(TRIM(mu2.email)) = LOWER(TRIM(u.email)))
    GROUP BY u.email
    ORDER BY u.email;
   ```

4. **Medición 2 — cuántas de esas membresías hoy matchean únicamente por `descripcion`** (son las que
   habría que corregir una vez, punto B.4a):
   ```sql
   SELECT mu.email, mu."group", e.descripcion
     FROM seg.memberships_users mu
     JOIN core.empresas e
       ON TRIM(e.descripcion) <> '' AND UPPER(TRIM(e.descripcion)) = UPPER(TRIM(mu."group")) AND e.eliminado = false
    WHERE NOT EXISTS (
          SELECT 1 FROM core.empresas e2
           WHERE TRIM(e2.nombre) <> '' AND UPPER(TRIM(e2.nombre)) = UPPER(TRIM(mu."group")) AND e2.eliminado = false)
    ORDER BY mu."group", mu.email;
   ```

5. **Medición 3 — empresas activas con el mismo nombre** (ignorando mayúsculas y espacios; son el riesgo
   del punto B.4b):
   ```sql
   SELECT UPPER(TRIM(nombre)) AS nombre_normalizado, COUNT(*) AS cantidad
     FROM core.empresas
    WHERE eliminado = false
    GROUP BY UPPER(TRIM(nombre))
   HAVING COUNT(*) > 1
    ORDER BY cantidad DESC;
   ```

6. **Repetir 2–5 contra la copia de producción** (la provee Rodolfo). **Nunca** contra producción directa.

7. **Volcar los tres números** (DEMO y copia de producción) en `doc/v3/administracion/ANALISIS_INICIAL.md`
   §B.4. Con eso quedan medidos los casos que hay que corregir (B.4a) y los nombres repetidos (B.4b).

---

## Decisiones de Rodolfo (2026-11-04)

Las 9 dudas que abrí al leer quedaron contestadas. Quedan registradas acá para que el análisis las
respete:

1. ✅ **Criterio membresía→empresa:** `core.empresas.nombre = seg.memberships_users."group"` (el que ya
   usa el disparador de alta de empresa). Sin comparar `descripcion` ni agregar columna.
2. ✅ **Tiempo de sesión:** el de Tools (sin límite), dejándolo **configurable** en `constants.php`.
3. ✅ **Estilos de login/registro:** se copian **tal cual**, sin unificar.
4. ✅ **Excepción pública de identidad:** control **general de Tools** (no del módulo).
5. ✅ **Prefijo del módulo:** `ADM` confirmado.
6. ✅ **Portal/Consola:** diseño propio, respetando las maquetas. Al presionar "Mi empresa" se sale del
   contexto visual de Tools. Se estudian las maquetas a detalle y **no se toman decisiones que rompan
   esa experiencia** (si falta algún artefacto de diseño, se lo pide al agente de diseño).
7. ✅ **Redirección futura:** último paso del desarrollo, con análisis de impacto al final.
8. ✅ **Secretos de configuración:** se dejan para una tarea de infraestructura aparte.
9. ✅ **Servicios de datos:** la fuente de verdad está en `traz-tools/_backend/api/ToolsAPIProject/…/artifacts`;
   las copias en `dnato/development/…` son restos viejos, no lo desplegado.

---

**Decisión agregada (2026-11-05, condición de aprobación):**

10. ✅ **Acceso a datos de la registración e ingreso copiados:** siguen accediendo **directo a la base**,
    igual que hoy en DNATO. Es una **excepción aprobada** a la regla de que todo pasa por WSO2, para poder
    comparar en paralelo con DNATO. Pasarlos a WSO2 queda para una tarea posterior. **Las pantallas nuevas
    no tienen esta excepción:** sus datos van por DataServices. La lista de accesos directos que se copian
    está en la sección C del análisis (`doc/v3/administracion/ANALISIS_INICIAL.md`).
