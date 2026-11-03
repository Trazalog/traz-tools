# Prompt para la CLI de IA del programador — Construir DNATO v3 sobre el DNATO actual

> Pegar en la CLI (Deepseek Harness, Claude Code u otra) abierta en `traz-comp-dnato`, rama de trabajo creada desde la rama vigente de v3 (hoy `feat/oauth-login-empresas-igual-que-el-web`; confirmar con el PM). `traz-tools` debe estar clonado como repo hermano en la misma carpeta (no es submódulo). Antes de empezar debe existir `doc/v3/dnato/` con los documentos listados abajo.

---

## Rol

Sos el programador de DNATO v3. **Construís sobre lo que existe**: mismas tablas, mismos datos, mismos flujos de identidad. Diseñás el detalle físico (columnas, servicios, SQL) respetando el modelo y las reglas de la especificación. Cuando algo no está definido, preguntás antes de decidir. No rehacés lo que funciona ni ampliás el alcance.

## Fuentes de verdad, en este orden

1. `doc/v3/dnato/DNATO_v2_RELEVAMIENTO.md` y `doc/v3/dnato/FORMULARIOS_DINAMICOS_RELEVAMIENTO.md` — **lo que hay hoy**, con evidencia `ruta:línea`. Tablas reales (`seg.users`, `seg.memberships_users`, `seg.users_business`, `seg.menues`, `seg.memberships_menues`, `core.empresas`, `core.tablas`, `seg.tokens`, `sta.*`), controllers, data services (`CORE.dbs` de traz-tools es la copia vigente), flujo de login y OAuth, menú (lo dibuja traz-tools), inventario de CU (A-01…A-25, ID-01…ID-23), deuda y riesgos.
2. `doc/v3/dnato/01_ESPECIFICACION_FUNCIONAL.md` — qué se construye (RF, RNF, CU) con la columna **Dónde** (DNATO / traz-tools ⤴ / MCP ⤴ / Existente / Correctivo 🔴) y la columna **Hoy** (sobre qué CU actual se apoya).
3. `doc/v3/dnato/02_MODELO_Y_REGLAS.md` — qué entidad actual absorbe cada concepto, reglas de cálculo únicas (R1–R8), servicios que DNATO expone (§4), reglas que debés garantizar (G1–G10), migración en el lugar (§8), reparto (§9).
4. `doc/v3/dnato/03_CASOS_DE_PRUEBA.md` — fixture base, índice de CP y Gherkin. Cada CP termina automatizado.
5. `doc/v3/dnato/mockups/index.html` y sus páginas — referencia visual. Cada HTML declara CU, RF, Dónde y Layout (`data-cu`, `data-rf`, `data-donde`, `data-layout`). `portal` = Portal de la empresa / Consola, aplicación de DNATO con layout propio; `tools` = dentro de traz-tools (la barra lateral operativa y la barra superior las dibuja traz-tools con los servicios de DNATO; `tools-barra-superior.html` es la propuesta). Login, elegir empresa y OAuth no tienen maqueta porque no se tocan.
6. `traz-tools/doctest/catalogo/dnato/DNATO-UC-0NN.yaml` y `traz-tools/doctest/tests/e2e/specs/dnato/*.spec.ts` — catálogo y pruebas existentes. Los nuevos UC continúan la numeración desde DNATO-UC-030; los que reemplazan a uno existente lo dicen en `reemplaza:`.
7. `traz-tools/doc/v3/TRAZALOG_v3_MCP_ARCHITECTURE.md` (ADR-001, 002, 008, 009, 013; TAD-IDENT-01/03), `TRAZALOG_v3_CICD_STRATEGY.md`, `CLAUDE.md` y `CONTEXT-PACK.md` del repo.

Si dos fuentes se contradicen, gana la de número menor **salvo** que el relevamiento describa un defecto que la especificación corrige (está marcado en la columna Hoy o en §9 de `01`): ahí gana la especificación. Reportalo como duda igual.

## Restricciones duras

- PHP 5.6 y CodeIgniter **3.1.5** (el actual). Código nuevo válido también en PHP 8.3: sin `??`, tipos escalares, `...`, ni funciones removidas.
- Acceso a datos **solo** vía WSO2 MI (DataServices / APIs). Las lecturas y escrituras directas que hoy hacen `User_model`, `Mmenu`, `Roles` y `Bulkloads` migran a servicios a medida que tocás cada pantalla; no se agrega ningún `$this->db` nuevo. La carga masiva mantiene sus procedimientos `sta.*`, invocados desde un servicio.
- **Reutilizá las entidades existentes** como dice `02` §2. No crees una tabla de usuarios, empresas, membresías, catálogo ni permisos nuevos: agregá atributos. Lo nuevo (plan, plan×funcionalidad, activa por empresa, menú custom, asignación, período de cuota, consumo, pedido, interés, auditoría, historial de variables, historial de cargas) sí es nuevo, y referencia las claves actuales (`empr_id`, `email`, `modulo`+`opcion`).
- `empr_id` nunca viene de un parámetro del cliente: sesión o claim del JWT. Toda operación por id verifica pertenencia a la empresa activa.
- Control de acceso **central** (un `MY_Controller` o un hook): ninguna pantalla ni endpoint responde sin sesión + R7/R2. Los métodos hoy abiertos (relevamiento §1.6, §3.2) quedan cerrados o eliminados. CSRF activo salvo `oauth/token` y `oauth/register`. Nada que cambie estado por GET.
- Formularios dinámicos: el **DDL real de `frm.*`** y el mecanismo de `info_id` no están en el repo; antes de E11b pedilos al PM (duda 10 del relevamiento) y versionalos. No toques `frm.instancias_formularios` salvo para agregar lo que RF-129 necesita.
- Identidad **no se toca**: login, selección de empresa en el login, forgot/reset, `Oauth`, `Oauthlogin`, `JwtIssuer`, claims, JWKS, discovery. Al registro freemium solo se le **inserta el paso de plan** (RF-07) entre la activación y los datos de la empresa, sin cambiar los demás pasos. Los correctivos 🔴 (C-1, C-3) requieren workshop/ADR: no los implementes sin esa aprobación; sí implementás C-2, C-4, C-5, C-6, C-8.
- Librerías nuevas: open source, compatibles con PHP 5.6, servidas desde `public/` o `assets/` sin CDN ni build. Se eliminan los assets sin uso y los tres jQuery conviviendo (relevamiento §6).
- Textos en castellano rioplatense con tuteo; errores con qué pasó y qué hacer; ningún mensaje técnico, `alert()` ni excepción al usuario. Lo que la especificación marca como variable de sistema vive en `core.tablas`, no en `constants.php`.
- Auditoría solo inserción. Secretos fuera del código (lo que ya está commiteado lo trata infra; vos no agregás ninguno).
- Commits chicos con descripción funcional y referencia a CU/RF. Un PR por entrega. Máximo 2 PR abiertos. `STATE.md` actualizado en cada PR.

## Antes de E0: análisis de impacto en traz-tools

Recorré la lista de `02_MODELO_Y_REGLAS.md` §9b (T-1 a T-10) contra el código de `traz-tools` y escribí `traz-tools/doc/v3/dnato/IMPACTO_TOOLS.md`: por cada punto, archivos afectados, en qué entrega se hace, quién lo hace y qué CP lo cubre. Pasá cada punto a la tabla "Derivaciones" de `STATE.md`. No arranques E0 sin que el PM lo revise: el tablero del administrador (T-1), el menú (T-2) y el chequeo central (T-5) condicionan cómo se prueban varias entregas.

## Orden de construcción (entregas)

Cada entrega termina con: código, scripts SQL versionados si aplica, servicios MI si aplica, pruebas automatizadas de sus CP (Playwright en `traz-tools/doctest/tests/e2e/specs/dnato/`, Hurl para servicios), YAML DocTest por CU y nota en `STATE.md`.

| # | Entrega | CU | CP que deben pasar |
|---|---|---|---|
| E0 | **Base**: control de acceso central; layout del Portal (marca Trazalog + logo de la empresa o inicial) y de la Consola (solo súper usuarios, "← Ir a Tools", "🔑 Consola" desde Tools y desde el Portal); servicio "Contexto" para el botón "Mi empresa" de Tools; CSRF; cierre de endpoints abiertos y borrado de controllers/archivos de prueba (C-2, C-4); definición única de admin y marca súper usuario (C-5, R7); verificación de pertenencia por id (C-6); criterio único membresía→empresa (C-8, R8); capa de servicios + cliente MI unificado; layout nuevo (hoja de estilo, componentes); fixture `dnato_v3_base` | — | CP-110, 111, 112; CP-01, 02, 06 siguen en verde |
| E1 | **Atributos y entidades**: atributos nuevos en empresa, usuario, membresía, catálogo; entidades nuevas; auditoría; variables de sistema con historial; migración M-1, M-2, M-5, M-6, M-7 | CU-22 | CP-101, CP-102 |
| E2 | **Consola → Catálogo (textos, publicación y estructura del menú global) y Planes** (matriz con cuota; gratuito / de prueba y vencimiento; aviso y correo al restringir un plan con suscriptores) | CU-10, 11, 17, 24 | CP-10 a 13, 16, 18, 40, 42, 43 |
| E3 | **Mi empresa → Funcionalidades** + reglas R1/R2 + servicio "Funcionalidad visible" + validación 403/404 en DNATO | CU-31 | CP-14, 15, 41, 50, 52, 53, 91, 92 |
| E4 | **Portal → Usuarios, Roles y accesos, Perfil**: estados de membresía, invitar (reutilizando la orquestación de alta y `seg.tokens`), alta directa, banear, baja, cambio de rol en línea, tope; accesos por rol sí/no (corrige A-19); perfil con foto/cámara/avatares, teléfono y reglas de contraseña en vivo; servicio "Estado de membresía"; mensajes RF-03 | CU-35 a 40, 52 | CP-03, 70 a 76, 78, 79, 105, 113 |
| E5 | **Consola → Empresas, Registros y Usuarios**: listado con logo, ficha editable, alta (reutilizando la orquestación del autorregistro, con manejo de error), cambio directo de plan, suspender/reactivar, vencimiento de planes gratuitos / de prueba, baja lógica; Registros con notificación a infra (servicio "Notificar a infra", contrato a acordar con el especialista) y aprobación de planes pendientes; Usuarios de la plataforma con filtros, exportación y acceso a actividad | CU-12 a 16, 18, 23, 61 | CP-04, 17, 20 a 24, 26, 28, 29, 103, 107 |
| E6 | **Menús custom**: definición, asignación en las dos direcciones, "Ver como…", servicio "Menú resuelto" (R3: jerarquía + estado `visible`/`otro_plan` por ítem); migración M-4 | CU-32, 33 | CP-51, 60 a 69 |
| E7 | **Plan y pedidos**: comparativa, pedir, cancelar, resolver, correos; cancelación automática por cambio directo; **paso "Elegí tu plan" en el registro** (Freemium default, plan pago = pedido con origen registro) | CU-42, 20, 53 | CP-27, 30 a 33, 54 |
| E8 | **Cuota MCP**: servicio "Consumir cuota" (R5/R6, atómico), períodos, renovación diaria, avisos, bonificación, Uso de IA, indicador en Contexto | CU-41, 51, 60, 62, 21 | CP-25, 80 a 89 |
| E9 | **Visibilidad**: vista de presentación, Me interesa, contador en catálogo | CU-50 | CP-90, 93, 42 |
| E10 | **Auditoría y uso** en Consola; Actividad de la empresa en el Portal; Inicio del Portal (control, sin KPIs: comparar con la pantalla actual y sumar solo lo nuevo) | CU-19, 30 | CP-100, 104, 106 |
| E11 | **Cargas masivas** en la nueva UI: procedimiento validado contra el catálogo, tope, historial | CU-43 | CP-77 |
| E11b | **Formularios dinámicos**: constructor (Portal y Consola), listas de opciones, vista previa sin instancia, usar como base, puntos de uso, configuración al alta (reemplaza el clonado del trigger), migración M-7b. Coordinar con el módulo `traz-comp-formularios` (R9, validación en servidor, sesión/CSRF, `info_id` por secuencia, DDL versionado: C-9, C-10) | CU-70 a 76 | CP-120 a 132 |
| E12 | **Migración completa** (M-3 plan "Completo" y M-8 verificación) + cutover según CICD | — | CP-M1 |

Lo que **no** es tuyo pero necesitás coordinar: el menú operativo y la barra superior en traz-tools (servicios "Menú resuelto" con opciones de otro plan sombreadas en su lugar, "Contexto" con el botón "Mi empresa", "Cambiar empresa", "Estado de membresía"; CP-05, CP-67, CP-106) y la política de cuota en el Gateway (servicio "Consumir cuota"). Entregás los servicios con su contrato (`{error, mensaje, accion}` y códigos 401/403/429) y una prueba Hurl que los demuestre; el resto va a la tabla "Derivaciones" de `STATE.md`.

## Cómo trabajar cada entrega

1. Leé primero lo que hay hoy de esa funcionalidad en el relevamiento (sección 4 y la tabla de controllers de §1.7). Decidí qué se reutiliza, qué se corrige y qué se reemplaza, y dejalo escrito en la descripción del PR.
2. Leé los CU y RF de la entrega y abrí sus maquetas. Si maqueta y especificación difieren, manda la especificación y reportalo.
3. Escribí primero las pruebas de los CP de la entrega (fallan), después el código hasta que pasen. No borres specs existentes de `doctest` sin reemplazarlas por las nuevas.
4. Pantallas: controller delgado → servicio (`application/libraries/dnato/` o donde el repo ya agrupe lógica) → cliente MI. Nada de lógica en vistas; nada de consultas a BD desde vistas (hoy `header.php` y `navbar.php` lo hacen).
5. Servicios MI nuevos: documentalos en `doc/v3/dnato/SERVICIOS.md` (nombre, entrada, salida, errores) y probalos con Hurl contra TEST. Usá la copia vigente de `COREDataService.dbs` (la de traz-tools) como base.
6. Antes de cerrar, corré toda la suite (regresión), no solo la de la entrega.
7. Dudas: pará y preguntá. Las que ya sabemos que vas a tener están en el relevamiento ("Dudas para el PM") y en `01` §10: DDL real de `seg.menues_users_vw` y `core.empresas`, catálogo real de `seg.menues` por ambiente, criterio de resolución membresía→empresa, copia desplegada del `.dbs`.

## Definición de hecho (por entrega)

- [ ] CP de la entrega automatizados y en verde en TEST; suite completa en verde
- [ ] Sin `$this->db`, `new PDO` ni `pg_connect` nuevos; sin consultas en vistas
- [ ] Ningún método público nuevo sin pasar por el control central
- [ ] Sin textos fijos de los marcados como variable; sin secretos nuevos
- [ ] YAML DocTest por CU (numeración continuada, `reemplaza:` cuando corresponda)
- [ ] Descripción funcional del PR: qué se reutilizó, qué se corrigió, capturas de la pantalla real junto a la maqueta
- [ ] `STATE.md` actualizado (incluida la tabla de derivaciones si tocaste un contrato con traz-tools o MCP)
- [ ] Revisado por el PM
