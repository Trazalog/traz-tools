# REQ-011 · Módulo Administración — Cuota del agente de IA

## Objetivo

Undécimo trabajo de Pablo para el módulo **Administración** (`traz-comp-adm`): el servicio **"Consumir
cuota"** (reglas R5 y R6) que dice si una consulta del agente de IA se puede hacer y la descuenta, los
**períodos** de cuota con su renovación diaria, los **avisos** al 80 % y al 100 %, la **bonificación**
del superusuario, la pantalla **Uso de IA** del Portal y el **indicador** de cuota en la barra de Tools y
del Portal. Lo leen Pablo para planificar y Rodolfo para aprobar el script de base, el análisis de
impacto de la barra y el contrato con el frente del agente. **No** cubre el freno en el portero de WSO2
(Gateway / APIM): lo hace el **frente del agente (MCP)** con el contrato de la sección "Derivación al
frente del agente" ([`doc/v3/TRAZALOG_v3_MCP_ARCHITECTURE.md`](../doc/v3/TRAZALOG_v3_MCP_ARCHITECTURE.md),
ADR-008). Lista completa en [`README.md`](README.md).

| Campo | Valor |
|---|---|
| Estado | **Borrador**: Rodolfo tiene que contestar las dudas de los casos, aprobar el script de base y el análisis de impacto de la barra, y acordar el contrato con el frente del agente |
| Se apoya en | [REQ-002](REQ-002-administracion-esqueleto.md) (controlador base, Portal, Consola), [REQ-004](REQ-004-administracion-base-y-atributos.md) (`seg.cuota_periodos`, `seg.consumos_mcp`, auditoría, variables `aviso_cuota_porcentaje` y `zona_horaria_cuotas`, servicio Contexto, barra de Tools), [REQ-005](REQ-005-administracion-catalogo-y-planes.md) (cuota, período y día de renovación del plan; herramientas de IA en el catálogo), [REQ-006](REQ-006-administracion-funcionalidades.md) (R1, R2), [REQ-007](REQ-007-administracion-usuarios-roles-perfil.md) (estado de membresía, columna "IA esta semana"), [REQ-008](REQ-008-administracion-consola-empresas.md) (proceso diario del módulo, ficha, listado, plan vencido) y [REQ-010](REQ-010-administracion-plan-y-pedidos.md) (paso único de cambio de plan, pantalla Plan) |
| Entrega de la especificación | **E8** de `doc/v3/dnato/PROMPT_CLI_DNATO_V3_BUILD.md`: servicio "Consumir cuota" (R5/R6, atómico), períodos, renovación diaria, avisos, bonificación, Uso de IA, indicador en Contexto. CU-41, CU-51, CU-60, CU-62, CU-21; CP-25, CP-80 a 89 |
| Casos de uso | `ADM-UC-170` a `ADM-UC-175` en `doctest/catalogo/adm/` |
| Repos que se tocan | `traz-comp-adm` (Uso de IA, bonificación en la ficha, columnas de IA, procesos de línea de comandos, Contexto); `traz-tools`: recursos **nuevos** en `ADMDataService.dbs`, script de base (funciones nuevas), y del núcleo `application/views/layout/perfil.php` (indicador) |
| Riesgo | 🔴 **Cambio de base de datos; Rodolfo aprueba el script antes de construir**: nombres de columnas de `seg.cuota_periodos` y `seg.consumos_mcp`, índices y **funciones nuevas** de base (consumo atómico) (lista en "Datos"). 🔴 **Núcleo de Tools**: indicador en la barra superior (`perfil.php`), que se ve en todas las pantallas → análisis de impacto aprobado por Rodolfo. Dos tareas programadas en cada servidor (como REQ-008). El freno en WSO2 queda **fuera** (derivación al frente del agente). Recursos del DataService nuevos (🟡) |

---

## Para qué sirve

- Hoy el agente de IA no tiene límite de uso por empresa: cualquier empresa con el conector consulta
  sin tope, y no hay forma de vender la IA por plan (Free 30 por semana, Team 1.000 por mes, etc.).
- El administrador no ve cuánto usa su empresa, quién, con qué herramienta, ni cuándo se renueva.
- Trazalog necesita poder regalar consultas extra (una demo, un reclamo) sin cambiar el plan.
- La regla tiene que estar en **un solo lugar** (el DataService), para que el portero de WSO2 la use sin
  copiarla y la pantalla muestre lo mismo que lo que se cobra.

## Quién lo usa

- **Supervisor**, **Mantenedor** (o cualquier persona de la empresa) desde el agente de IA: cada
  consulta descuenta una (lo prueba el servicio).
- **Administrador**: Mi empresa → Uso de IA, el indicador y los correos de aviso.
- **Superusuario**: bonifica consultas desde la ficha de la empresa y ve el uso en la Consola.

## Qué tiene que hacer

1. Servicio "Consumir cuota": verifica en orden acceso, plan, IA y cuota, descuenta de forma atómica y
   registra cada intento (CU-51, R5, RF-81, RF-82) → **ADM-UC-170**.
2. Períodos de cuota: abrir y cerrar según el plan, el proceso diario, el período al vuelo y el
   recálculo al cambiar de plan (CU-60, R6, RF-80, RF-86) → **ADM-UC-171**.
3. Pantalla Uso de IA con sus cinco estados, por día, por persona, por herramienta y períodos
   anteriores (CU-41, RF-83) → **ADM-UC-172**.
4. Avisos por correo al 80 % y al 100 %, una vez por período (CU-62, RF-84) → **ADM-UC-173**.
5. Bonificar consultas del período en curso, y el uso de IA en la Consola (CU-21, RF-85, RF-27) →
   **ADM-UC-174**.
6. Indicador de cuota en la barra de Tools y del Portal, y la columna "IA esta semana" de Usuarios
   (Contexto, RF-83) → **ADM-UC-175**.

## Qué NO hace

- **No frena al agente en WSO2.** Llamar a "Consumir cuota" antes de cada `tools/call`, cortar la
  ejecución y devolver el mensaje al cliente es del **frente del agente (MCP)**: política en el Gateway
  o secuencia común en MI (`02_MODELO_Y_REGLAS.md` §5). Acá se entrega el servicio, probado, y el
  contrato (sección "Derivación al frente del agente").
- **No cambia la identidad del agente** (ADR-008, ADR-009, D1 del análisis): el JWT lo sigue emitiendo
  DNATO, lo valida el APIM, y el `empr_id` llega del token. No hay JWT nuevo ni lista de revocación: un
  baneado o una empresa suspendida se rechazan por estado (`sin_acceso`, §4).
- **No configura el freno técnico por minuto** de WSO2 (protección del servidor, D-03): es del frente
  del agente.
- No cambia la tarjeta del tablero de Tools (T-1): queda para REQ-013 (inicio del Portal) **[SUPUESTO]**, a confirmar por Rodolfo.
- No hace las pantallas de Auditoría ni Uso de la plataforma (REQ-013): acá la bonificación se audita y
  el uso se ve en la ficha.
- No cobra: la bonificación no factura.

---

## Cómo se arma

### R5 — Consumir cuota (servicio para el portero de WSO2)

Entrada: `empr_id`, correo de la persona y nombre de la herramienta. Se verifica **en este orden**, con
**un solo resultado**:

| Paso | Si no se cumple | Resultado | Código | Mensaje |
|---|---|---|---|---|
| 1. Membresía `activo` (REQ-007) en esa empresa, sin ban global, y empresa no `suspendida` | — | `sin_acceso` | 401 | "No tenés acceso a <empresa>. Comunicate con el administrador de tu empresa." **[SUPUESTO]** |
| 1b. Empresa con plan vencido (`estado_plan = vencido`) | — | `plan_vencido` | 403 **[SUPUESTO]** | "El período de prueba de tu empresa terminó. Tu administrador puede pedir un plan desde Mi empresa → Plan" (R5) |
| 2. Herramienta publicada y en el plan de la empresa | — | `fuera_plan` | 403 | "La herramienta <tool> no está activa para tu empresa. Está incluida en el plan <plan>" (RF-81, `plan` = el de menor orden que la trae) |
| 3. Plan con cuota distinta de 0 | — | `sin_ia` | 403 | "Tu plan no incluye IA" (CP-88) |
| 4. `consumidas < cuota + bonificación` del período en curso (o ilimitado) | — | `sin_cuota` | 429 | "Tu empresa usó las <N> consultas de IA de esta <semana / este mes> del plan <plan>. Se renueva el <día> <fecha> a las 00:00. Tu administrador puede pedir un cambio de plan desde Mi empresa → Uso de IA" (CP-80) |
| Todo bien | — | `ok` | 200 | — ; con `restantes` y `fin_periodo` |

- **El paso 4 es atómico** (RNF-10, G4): una sola sentencia "sumar 1 si cabe" sobre la fila del período,
  dentro de una **función de base** que hace los cuatro pasos y registra el intento en la misma
  transacción. Veinte llamadas a la vez con un lugar libre: pasa exactamente una (CP-81).
- **Si no hay período en curso** (el proceso diario no corrió), la función lo abre en el momento según
  el plan y sigue (CP-89).
- **Cada intento** queda en `seg.consumos_mcp` (empresa, correo, herramienta, fecha, resultado), también
  los rechazos (RF-82). Los rechazos no descuentan.
- **Ilimitado** (cuota nula): siempre `ok` (si pasa 1 a 3), y se cuentan igual las consultas (CP-88).
- **Herramienta** = la opción del catálogo con módulo `MCP` y tipo `tool_mcp` (REQ-005, RF-15); su
  código es el nombre de la herramienta (ADR-013).
- **Empresa sin plan** (todas hasta M-3, REQ-016): ver la duda de ADM-UC-170.
- Tiempo objetivo: menos de 50 ms (§4, RNF-10). Se mide en la copia de DEMO.
- **Lugar de la regla:** un recurso nuevo de `ADMDataService` que llama a la función. El módulo no tiene
  un intermediario en PHP: el portero de WSO2 llama directo al DataService (lógica de negocio en las
  APIs; el agente no pasa por la web).

### R6 — Período de cuota

- **Inicio y fin** según el plan (REQ-005: `periodo`, `dia_renovacion`), en la zona horaria de la
  variable `zona_horaria_cuotas` (por defecto `America/Argentina/San_Juan`): semana = del día de
  renovación 00:00 al mismo día de la semana siguiente; mes = del día N 00:00 al día N del mes siguiente.
  La base guarda la hora en UTC (como hoy, `doc/infra/kpi-cron-refresh.md`); la función convierte.
- Una fila por empresa y por período (única por empresa e inicio): cuota y bonificación del período,
  consumidas, y si ya se mandaron los avisos de 80 % y 100 %.
- **Cambio de plan a mitad de período** (RF-86, CP-87): el período en curso toma **la cuota del plan
  nuevo y el fin del plan nuevo** (la próxima renovación del plan nuevo después de ahora); lo consumido
  **no** se descuenta. Se hace **en la misma operación** que el cambio de plan: se agrega al paso único
  de cambio de plan de REQ-008 / REQ-010 (`PUT /consola/empresa/plan`), así vale para el cambio
  directo, la aprobación de un pedido y la del registro (lo que REQ-008 dejó para acá, duda de
  ADM-UC-113).
- La bonificación es del período en curso: al renovarse, el nuevo arranca con bonificación 0.

### Proceso diario de renovación (CU-60)

El **mismo mecanismo que propuso REQ-008** para vencer planes: un proceso del módulo por línea de
comandos (por ejemplo `php index.php traz-comp-adm/procesos/renovar_cuotas`), que lanza una tarea
programada del sistema operativo de cada servidor, como el refresco de indicadores que ya corre por
cron en DEMO y producción (`doc/infra/kpi-cron-refresh.md`). El proceso no va directo a la base: llama a
un recurso nuevo del DataService, que llama a una función de base.

- Corre todos los días a las 00:05 **[SUPUESTO]** (CP-84). Para cada empresa con plan con IA, si el
  período en curso terminó, abre el siguiente con la cuota del plan y 0 consumidas; el anterior queda
  como estaba (cerrado por fecha).
- Si un día no corrió, el siguiente abre lo que falta; y aunque no corra nunca, R5 abre el período al
  vuelo (CP-89). Correrlo dos veces no duplica (única por empresa e inicio).
- Deja en el log cuántos períodos abrió y si algo falló.

### Avisos al 80 % y al 100 % (CU-62, RF-84)

- La función de consumo, al pasar el umbral (variable `aviso_cuota_porcentaje`, 80) o al llegar al
  total, **marca** en la fila del período que hay un aviso para mandar, una sola vez por período y por
  tipo (CP-86: de 23 a 24 sí; a 25 no).
- El portero de WSO2 no manda correos, así que los manda **otro proceso del módulo** por línea de
  comandos (`procesos/avisos_cuota`), con el mismo mecanismo, cada 5 minutos **[SUPUESTO]**: toma los
  avisos marcados y no enviados, manda el correo a los administradores (definición única de REQ-004) y
  los marca como enviados. Ver la duda de ADM-UC-173.
- Asuntos: "Usaste el 80 % de tu cuota de IA" y "Usaste toda tu cuota de IA" (CP-86); el número es la
  variable. Cuerpo **[SUPUESTO]** con consumidas, cuota, renovación y el enlace a Uso de IA.

### Bonificación (CU-21, RF-85)

- En la ficha de la empresa (Consola, REQ-008): "Otorgar consultas de IA extra · se suman al período en
  curso", Cantidad (entero mayor que 0) y Motivo, "Bonificar".
- Suma a la bonificación del período en curso (si no hay, lo abre), auditoría `cuota.bonificar`
  (CP-25) con cantidad y motivo, y correo a los administradores **[SUPUESTO]** "Trazalog te sumó <N>
  consultas de IA". Si la empresa estaba bloqueada, vuelve a tener consultas en el mismo momento.

### Contexto e indicador

- El servicio **Contexto** (REQ-004, del módulo) suma `cuota`: consumidas, cuota + bonificación (o
  ilimitado / sin IA), período ("esta semana" / "este mes") y estado. **Solo para administradores**.
- **Barra de Tools** (`perfil.php`, núcleo): "🤖 <consumidas>/<total>" al lado de "🏢 Mi empresa", solo
  si es administrador; lleva a Uso de IA. Si el Contexto falla, no aparece y Tools sigue igual (regla 5
  de REQ-004).
- **Barra del Portal**: "🤖 <consumidas>/<total> esta semana" (o "este mes").
- **Usuarios del Portal** (REQ-007): la columna "IA esta semana" (o "este mes") con las consultas `ok`
  de cada persona en el período en curso.
- **Consola** (REQ-008): columna "IA (período)" del listado de empresas, tarjeta "IA este período" de
  la ficha ("<consumidas> / <total> renueva <día> <fecha> · <N> bonificadas"), "Uso de IA · últimos 6
  períodos" de la ficha y columna "IA período" de Usuarios de la plataforma.

### Auditoría

`cuota.bonificar` (RF-100). El consumo **no** va a la auditoría (RF-100): tiene su registro propio.

---

## Derivación al frente del agente (lo que el módulo le entrega)

El módulo entrega el servicio construido y probado; el frente del agente lo engancha en WSO2. Contrato
propuesto (se cierra con el frente del agente antes de construir):

| # | Qué | Detalle |
|---|---|---|
| 1 | Recurso | `ADMDataService POST /cuota/consumir` en el MI (red interna) |
| 2 | Entrada | `{"empr_id": "...", "email": "...", "herramienta": "man_get_equipos"}`, cuerpo envuelto como piden los DataServices de MI para POST (`_post_cuota_consumir`) |
| 3 | De dónde sale cada dato | `empr_id`: del JWT ya validado por el APIM (ADR-008; en el MI, de `X-JWT-Assertion` por `EmprIdFromHeader`, ADR-009). Correo: de la persona del mismo JWT (ver la duda de ADM-UC-170). Herramienta: el nombre de la `tools/call`. **Nunca** de parámetros de la herramienta (TAD-IDENT-01) |
| 4 | Salida | `{"resultado", "codigo_http", "mensaje", "accion", "restantes", "fin_periodo"}`; `resultado` ∈ `ok`, `sin_acceso`, `plan_vencido`, `fuera_plan`, `sin_ia`, `sin_cuota`. El DataService responde siempre 200; el Gateway usa `codigo_http` para la respuesta al cliente |
| 5 | Cuándo | Antes de **cada** `tools/call`; si `resultado` no es `ok`, la herramienta **no** se ejecuta y el cliente recibe `mensaje` como error MCP (§5) |
| 6 | Tiempo | Objetivo menos de 50 ms (RNF-10) |
| 7 | Freno técnico | El límite por minuto lo configura el frente en WSO2 como protección (D-03); no es la cuota de negocio |
| 8 | Si el servicio no responde | A decidir con el frente y Rodolfo (duda de ADM-UC-170) |
| 9 | Prueba | El módulo entrega las pruebas del servicio (ADM-UC-170, ADM-UC-171) con pedidos directos al recurso; el frente prueba punta a punta con un cliente MCP (CP-80 a 83, 88 desde Claude) |
| 10 | Herramientas | Cada herramienta del facade tiene que estar en el catálogo (módulo `MCP`, REQ-005, M-2); una que no esté se rechaza como `fuera_plan` |

---

## De dónde sale cada dato

| Dato | De dónde | Cómo |
|---|---|---|
| Consumir (R5) | `ADMDataService POST /cuota/consumir` → función `seg.consumir_cuota(…)` | **NUEVO** |
| Período en curso de la empresa | `ADMDataService GET /empresa/{empr_id}/cuota` | **NUEVO** |
| Consumo por día, por persona, por herramienta | `ADMDataService GET /empresa/{empr_id}/cuota/detalle/{periodo_id}` | **NUEVO** |
| Últimos 6 períodos | `ADMDataService GET /empresa/{empr_id}/cuota/periodos` | **NUEVO** |
| Exportar CSV | El mismo detalle, sin paginar (el módulo arma el CSV) | **NUEVO** |
| Renovar períodos (proceso) | `ADMDataService POST /cuota/renovar` → función `seg.renovar_cuotas(…)` | **NUEVO** |
| Avisos pendientes y marcarlos enviados (proceso) | `ADMDataService GET /cuota/avisos-pendientes`, `PUT /cuota/aviso-enviado` | **NUEVO** |
| Bonificar | `ADMDataService PUT /consola/empresa/cuota/bonificacion` (con auditoría) | **NUEVO** |
| IA del período en listados de la Consola | `ADMDataService GET /consola/empresas`, `GET /consola/personas` | Existen (REQ-008); **se amplían** con la columna (recursos del módulo) |
| IA por persona en Usuarios del Portal | `ADMDataService GET /empresa/{empr_id}/personas` | Existe (REQ-007); **se amplía** |
| Recálculo al cambiar de plan | `ADMDataService PUT /consola/empresa/plan` | Existe (REQ-008 / REQ-010); **se amplía** |
| Plan, cuota, período, día de renovación | `seg.planes` (REQ-005) dentro de las funciones | — |
| Estado de membresía, ban, empresa suspendida, plan vencido | `seg.membresias_estado`, `seg.users`, `core.empresas` dentro de la función | Tablas de REQ-004 |
| Umbral y zona horaria | Variables `aviso_cuota_porcentaje`, `zona_horaria_cuotas` | Ya existen (REQ-004) |
| Administradores (correos) | `ADMDataService GET /empresa/{empr_id}/administradores` | Ya existe (REQ-005) |

**Nada va directo a la base.** Los recursos del Portal toman la empresa de la sesión; los de la Consola
verifican que la empresa exista; `POST /cuota/consumir` no lo llama el navegador (lo llama el portero de
WSO2 por la red interna).

---

## Pantallas

### Portal — menú lateral

Se agrega "🤖 Uso de IA" bajo "Plan y consumo". `data-testid`: `adm-portal-menu-uso-ia`.

### Portal → Uso de IA — `traz-comp-adm/portal/uso-ia`

Maqueta `doc/v3/dnato/mockups/empresa-uso-ia.html`.

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Título | "Uso de IA", "Consultas MCP de tu empresa en el período del plan <ícono> <plan>." y "⬇ Exportar CSV" | `adm-uso-ia`; `adm-uso-ia-exportar` |
| Tarjeta (un estado por vez) | **Normal**: "<N> / <M> esta semana" con barra y "Se renueva el <día> <fecha> a las 00:00". **Aviso**: barra ámbar y "Te quedan <K> consultas · avisamos por correo". **Bloqueado**: cartel rojo "Sin consultas hasta el <día> <fecha> 00:00" y "Pedir cambio de plan". **Sin IA**: "Tu plan no incluye IA" y la comparativa. **Ilimitado**: sin barra, solo lo consumido | `adm-uso-ia-tarjeta` (con `data-estado` = `normal`, `aviso`, `bloqueado`, `sin_ia`, `ilimitado`); `adm-uso-ia-pedir-plan` |
| Lo que ve el usuario | En el estado bloqueado, "🤖 Lo que ve el usuario en Claude cuando no hay cuota" con el mensaje de `sin_cuota` | `adm-uso-ia-mensaje-agente` |
| Por día | "Consultas por día <inicio> → <fin>", una barra por día | `adm-uso-ia-por-dia` |
| Por persona | Usuario, Consultas (las `ok`) | `adm-uso-ia-por-persona` |
| Por herramienta | Herramienta (con el ícono del plan si es de otro plan), Ok, Rechazadas ("<N> fuera del plan") | `adm-uso-ia-por-herramienta` |
| Períodos anteriores | Período, Usadas, Cuota, y "bloqueado <N> días" si llegó al tope | `adm-uso-ia-periodos` |

"Pedir cambio de plan" y la comparativa del estado sin IA llevan a Plan (REQ-010).

### Barras (núcleo en Tools)

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Indicador en Tools | "🤖 <N>/<M>" (o "🤖 <N>" si es ilimitado), solo administradores; lleva a Uso de IA | `adm-tools-cuota` |
| Indicador en el Portal | "🤖 <N>/<M> esta semana" (o "este mes") | `adm-portal-cuota` |
| Columna en Usuarios del Portal | "IA esta semana" / "IA este mes" | `adm-usuarios-ia` |

### Consola → Ficha de empresa (agregado a REQ-008)

| Elemento | Qué muestra | `data-testid` |
|---|---|---|
| Tarjeta | "IA este período" "<N> / <M>" y "renueva <día> <fecha> · <K> bonificadas" | `adm-ficha-ia` |
| Bonificar | "Otorgar consultas de IA extra" y "se suman al período en curso", Cantidad, Motivo, "Bonificar", y "Queda en la auditoría y se avisa por correo al administrador." | `adm-ficha-bonificar`; `adm-bonificar-cantidad`, `adm-bonificar-motivo`, `adm-bonificar-enviar` |
| Historial | "Uso de IA · últimos 6 períodos" | `adm-ficha-ia-periodos` |
| Pestaña | "Uso de IA": la misma pantalla del Portal en solo lectura, para esa empresa **[SUPUESTO]** | `adm-ficha-tab-uso-ia` |

Columnas: "IA (período)" en Consola → Empresas (`adm-empresa-ia`) y "IA período" en Usuarios de la
plataforma (`adm-persona-ia`).

### Mensajes

| Caso | Mensaje | `data-testid` |
|---|---|---|
| Bonificado **[SUPUESTO]** | "Sumamos <N> consultas a <empresa> en este período." | `adm-ficha-ok` |
| Cantidad inválida **[SUPUESTO]** | "Ingresá una cantidad mayor que 0." | `adm-ficha-error` |
| Exportar sin datos **[SUPUESTO]** | "No hay consultas en este período." | `adm-uso-ia-vacio` |
| Falla del servicio | "No pudimos cargar el uso. Probá de nuevo en un rato." / "No pudimos guardar. Probá de nuevo en un rato." | `adm-uso-ia-error`, `adm-ficha-error` |

---

## Reglas

1. R5 se verifica en orden (acceso, plan vencido, plan, IA, cuota) y devuelve un solo resultado.
2. El descuento es atómico: nunca se pasa del tope, ni con llamadas simultáneas.
3. Cada intento se registra con su resultado; los rechazos no descuentan.
4. Si no hay período en curso, consumir lo abre al vuelo según el plan.
5. El período sigue el plan (semana desde el día de renovación, mes desde el día N), en la zona horaria
   de la variable.
6. Al cambiar de plan, el período en curso toma cuota y fin del plan nuevo, sin descontar lo consumido,
   en la misma operación que el cambio.
7. El proceso diario abre los períodos que faltan; correrlo dos veces o saltear días no duplica ni
   pierde.
8. Cada aviso (umbral y total) se manda una sola vez por período, a los administradores.
9. Solo el superusuario bonifica; suma al período en curso, se audita y se avisa.
10. Uso de IA y el indicador los ve solo el administrador de la empresa activa; la empresa sale de la
    sesión.
11. Si el Contexto falla, la barra de Tools sigue igual, sin indicador.
12. El `empr_id` y la persona de "Consumir cuota" salen del token validado, nunca de parámetros de la
    herramienta.

## Registro en el log

`log_message('DEBUG', '#TRAZA | ADM | <Clase> | <metodo>() ...')` en el módulo. Se registran las
bonificaciones, cada corrida de los procesos (períodos abiertos, avisos mandados, fallas) y los
rechazos de las pantallas. Cada consumo **no** va al log de PHP: queda en `seg.consumos_mcp`.

---

## Datos

**🔴: Rodolfo aprueba el script antes de construir.** Las tablas las crea REQ-004 con los atributos;
acá se proponen nombres **[SUPUESTO]** y se agregan funciones e índices (si el script de REQ-004 no
corrió, van en él; si no, en uno chico con su vuelta atrás).

### Columnas de `seg.cuota_periodos`

| Columna | Qué guarda |
|---|---|
| `periodo_id` | Número del período |
| `empr_id`, `plan_id` | Empresa y plan con que se abrió (o al que se recalculó) |
| `inicio`, `fin` | Desde y hasta (hora en UTC) |
| `cuota` | Cuota del período; nulo = ilimitado |
| `bonificacion` | Consultas extra del período (0 por defecto) |
| `consumidas` | Consultas `ok` del período |
| `aviso_umbral`, `aviso_total` | `no` / `pendiente` / `enviado` |

Única por (`empr_id`, `inicio`).

### Columnas de `seg.consumos_mcp`

`consumo_id`, `empr_id`, `periodo_id` (nulo si se rechazó antes de abrir período), `email`,
`herramienta`, `fecha`, `resultado`. Índices por (`empr_id`, `fecha`) y (`periodo_id`).

### Funciones nuevas

| Función | Qué hace |
|---|---|
| `seg.consumir_cuota(empr_id, email, herramienta)` | R5 completo, abre el período al vuelo, suma 1 si cabe, marca avisos, registra el intento; todo en una transacción |
| `seg.periodo_de(empr_id, momento)` | Inicio y fin del período según el plan y la zona horaria (la usan las otras) |
| `seg.renovar_cuotas(momento)` | Abre los períodos que faltan (proceso diario) |
| `seg.recalcular_periodo(empr_id)` | R6 al cambiar de plan; la llama el paso único de cambio de plan |

El usuario de base que usa WSO2 solo puede **ejecutar** estas funciones e insertar en
`seg.consumos_mcp`; no modifica ni borra consumos **[SUPUESTO]**.

Ninguna fila ni columna existente cambia; no hay carga de datos.

---

## Análisis de impacto en Tools (núcleo) — lo aprueba Rodolfo antes de construir

| Qué | Detalle |
|---|---|
| Qué cambia | `application/views/layout/perfil.php`: el indicador "🤖 N/M" al lado de "🏢 Mi empresa" (REQ-004), con el dato del Contexto que `Dash::index` ya pide desde REQ-004. `Dash.php` no cambia más |
| Quién lo consume | La barra superior de **todas** las pantallas de Tools, y las copias de `perfil.php` en submódulos (por ejemplo `traz-comp-pan/views/layout/perfil.php`), que **no** cambian: no muestran el indicador |
| Qué se rompe si falla | El Contexto tarda o falla → la barra tarda o se ve mal en todas las pantallas |
| Cómo se protege | Si el Contexto no responde o no trae `cuota`, el indicador no aparece y el resto de la barra queda igual (regla 11); se mide cuánto suma al tiempo de carga del tablero en la copia de DEMO; el indicador se ve solo para administradores |
| Pruebas | ADM-UC-175 (con administrador, sin administrador, con el Contexto caído) y la suite `regresion` de DocTest en verde |

Las tareas programadas (`renovar_cuotas` y `avisos_cuota`) se instalan en cada servidor como la de
REQ-008: análisis de quién las instala y cómo se ve si fallaron, en el mismo documento de REQ-008.

---

## Decisiones tomadas

- **La regla vive en una función de base, detrás de un recurso del DataService**: es la única forma de
  que el descuento sea atómico y rápido, y de que el portero de WSO2 y las pantallas usen lo mismo.
- **El portero de WSO2 llama al DataService directo**, sin pasar por PHP: el agente no tiene sesión web.
- **El recálculo al cambiar de plan va en el paso único de cambio de plan** (REQ-008 / REQ-010): vale
  para el cambio directo, el pedido aprobado y el registro.
- **Los procesos usan el mecanismo de REQ-008** (módulo por línea de comandos + tarea programada del
  servidor), no uno nuevo.
- **Los correos de aviso los manda un proceso**, porque el portero de WSO2 no manda correos y la función
  de base tampoco.

## Cómo se revisa (además de DocTest)

- Script de base aprobado por Rodolfo, corrido en una copia de DEMO, con su vuelta atrás.
- **Prueba de concurrencia** (CP-81): 20 pedidos simultáneos al recurso con un lugar libre → 1 `ok` y
  19 `sin_cuota`, consumidas = tope.
- Tiempo del recurso "Consumir cuota" medido en la copia de DEMO (objetivo menos de 50 ms).
- **Análisis de impacto de la barra aprobado por Rodolfo**; DocTest `regresion` en verde.
- Contrato con el frente del agente acordado (sección "Derivación") antes de que el frente lo enganche.
- `phpcs` con PHPCompatibility para PHP 5.6 sin errores; `./mvnw clean install` del proyecto de APIs.
- **Aviso para el despliegue:** el script de despliegue sube los DataServices pero no las APIs; este
  requerimiento no agrega APIs. Las dos tareas programadas se instalan aparte en cada servidor.

## Dudas abiertas

Están en los casos de uso (campo `dudas`), para contestarlas en un solo lugar.

---

## Casos de prueba de la especificación que cubre

| CP | Qué prueba | Lo cubre |
|---|---|---|
| CP-80 | Hasta el tope y rechazo con el mensaje | ADM-UC-170 (contra el servicio). Desde Claude: frente del agente |
| CP-81 | Concurrencia: 20 llamadas, una pasa | ADM-UC-170 |
| CP-82 | Herramienta fuera del plan, sin consumir | ADM-UC-170 |
| CP-83 | Baneado, invitado, baja o empresa suspendida: `sin_acceso` | ADM-UC-170 |
| CP-88 | Cuota 0 e ilimitado | ADM-UC-170 |
| CP-89 | Sin período abierto, consumir lo abre | ADM-UC-170 y ADM-UC-171 |
| CP-84 | Renovación semanal | ADM-UC-171 |
| CP-87 | Cambio de plan a mitad de período | ADM-UC-171 |
| CP-85 | Uso de IA: cinco estados, por persona y por herramienta | ADM-UC-172 |
| CP-86 | Avisos 80 % y 100 % una vez por período | ADM-UC-173 |
| CP-25 | Bonificación se suma al período | ADM-UC-174 |
| CP-19 (parte del agente) | Plan vencido: el agente se rechaza con `plan_vencido` | ADM-UC-170 contra el servicio; el corte en WSO2 es del frente del agente |
| CP-04, CP-73 (parte del agente) | Empresa suspendida o persona baneada: el agente se rechaza | ADM-UC-170 (`sin_acceso`) contra el servicio; el corte en WSO2 es del frente del agente |
