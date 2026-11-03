# DNATO v3 — Casos de prueba

| Campo | Valor |
|---|---|
| Versión | 0.5.1 |
| Fecha | 2026-11-02 |
| Formato | Gherkin en castellano; cada escenario referencia CU y RF. Se derivan a Playwright (UI, en `traz-tools/doctest/tests/e2e/specs/dnato/`, continuando los UC existentes), Hurl (servicios de §4 de `02`) y al catálogo DocTest |
| Datos base | §1. Toda prueba arranca desde ese estado. Nombres de entidades según el modelo real (`core.empresas`, `seg.users`, membresías, `seg.menues`) |
| Pruebas existentes que se conservan | DNATO-UC-001, 006, 007, 008, 009 (identidad, no se toca); UC-002 a 005 (alta de empresa por autorregistro, a las que se suma el paso de plan: CP-54) |

---

## 1. Datos base (fixture `dnato_v3_base`)

| Entidad | Valores |
|---|---|
| Planes | **Free** (Freemium): orden 1, 5 usuarios, 30 consultas/semana, renovación lunes, base, gratuito sin vencimiento · **Prueba Business**: orden 3b, como Business, gratuito/de prueba con vencimiento 30 días · **Team**: orden 2, 15, 1.000/mes día 1 · **Business**: orden 3, 40, 4.000/mes día 1 · **Enterprise**: orden 4, ilimitado, ilimitado · **SinIA**: orden 0, 3 usuarios, cuota 0 (solo para pruebas) |
| Catálogo publicado (`módulo.opción`) | `MAN.equipos`, `MAN.equipo_alta` (acción), `MAN.ot`, `MAN.indicadores`, `ALM.stock`, `ALM.ajustes`, `PAN.herramientas`, `PAN.prestamos`, `BPM.procesos`, `PRD.produccion`, `MCP.man_get_equipos` (lectura), `MCP.man_get_ots` (lectura), `MCP.man_crear_ot` (escritura) · sin publicar: `MAN.preventivos` · despublicada: `RES.residuos` |
| Matriz | Free: MAN.*, ALM.stock, PAN.*, MCP.man_get_equipos, MCP.man_get_ots · Team: Free + ALM.ajustes, MCP.man_crear_ot · Business: Team + BPM.procesos, PRD.produccion · Enterprise: todo · SinIA: MAN.equipos |
| Empresas | **MinTest_SJ** (Free, activa) · **Empresa Test** (Business, activa, fin de plan = hoy + 2 días) · **Yudica** (Business, activa) · **Tierras de Capayán** (Team, suspendida 15/10) · **Matheu** (Team, admin sin aceptar) · **Prueba SinIA** (SinIA) |
| Membresías MinTest_SJ (5 de 5 lugares) | ana@ Administrador `activo` · bruno@ Supervisor `activo` · carla@ Mantenedor `activo` · dario@ Mantenedor `invitado` (vence 31/10) · elena@ Mantenedor `baneado` (20/10, "licencia") |
| Membresías Empresa Test | ana@ Supervisor `activo` · eva@ Administrador `activo` |
| Membresías Yudica | 20 personas activas |
| Accesos de rol MinTest_SJ (`memberships_menues`, sí/no) | Administrador: todo lo activo · Supervisor: todo salvo `MAN.equipo_alta` · Mantenedor: `MAN.equipos`, `MAN.ot`, `ALM.stock`, `PAN.herramientas`, `MCP.*` |
| Funcionalidades activas MinTest_SJ | todas las de Free salvo `MAN.indicadores` (sin activar), en orden: equipos, equipo_alta, ot, stock, herramientas, prestamos, man_get_equipos, man_get_ots |
| Menús MinTest_SJ | Predeterminado (automático) · "Operación" (grupo "Mi trabajo": equipos con etiqueta "Equipos del taller", ot; grupo "Repuestos": stock) asignado al rol Mantenedor · "Solo equipos" (equipos) asignado a carla@ |
| Súper usuario | root@trazalog (único) |
| Cuota MinTest_SJ | período 26/10 00:00 → 2/11 00:00, 21 de 30 consumidas (bruno@ 15, carla@ 6; man_get_equipos 15, man_get_ots 6); 3 rechazos `fuera_plan` de bruno@ a man_crear_ot |
| Pedidos | Yudica → Enterprise pendiente (29/10, "cerramos minera nueva") |
| Variables | `validez_invitacion_dias` = 7 · `validez_recuperacion_horas` = 24 · `contacto_soporte` = soporte@trazalog.com · `aviso_cuota_porcentaje` = 80 · `precio_plan_team` = "USD 79 / mes" · `precio_plan_enterprise` = "Consultar" · `zona_horaria_cuotas` = America/Argentina/San_Juan |
| Formularios | Globales publicados: "Entrega de materiales" (G-1: solicitante, DNI, comprobante, obra [lista `obras`], observaciones) asignado al alta al punto `formulario_entrega_materiales`; "Salida de pañol" (G-2) al alta al punto `formulario_salida_herramientas`; "Checklist de herramienta" (G-3, borrador). Propios de MinTest_SJ: "Entrega de materiales MinTest" (P-1, copiado de G-1, publicado, 12 respuestas, en uso en `formulario_entrega_materiales`); "Inspección de equipo" (P-2, borrador). Listas: `obras` global (Obra A, Obra B) y `obras` de MinTest_SJ (Veladero, Gualcamayo). Puntos de uso catalogados: entrega de materiales, salida de pañol, recepción de pañol, checklist de herramientas |
| Fecha de "hoy" para las pruebas | jueves 29/10/2026 |

---

## 2. Índice de casos de prueba

| CP | Nombre | CU | Prioridad | Tipo |
|---|---|---|---|---|
| CP-01 | Login con una sola empresa entra directo (existente) | CU-01 | Alta | UI (UC-006) |
| CP-02 | Login multi-empresa pide elegir (existente) | CU-01 | Alta | UI (UC-006) |
| CP-03 | Baneado en su única empresa ve el mensaje de suspensión | CU-01 | Alta | UI |
| CP-04 | Empresa suspendida corta sesiones y MCP | CU-16 | Alta | Servicio |
| CP-05 | Cambiar empresa solo entre membresías activas | CU-03 | Alta | Servicio |
| CP-06 | Recuperar contraseña (existente) | CU-02 | Media | UI (UC-008) |
| CP-10 | Crear plan con cuota semanal | CU-10 | Alta | UI |
| CP-11 | No se da de baja un plan en uso | CU-10 | Media | UI |
| CP-12 | Marcar otro plan como base transfiere la marca | CU-10 | Media | UI |
| CP-13 | Casilla de la matriz se guarda sola y audita | CU-11 | Alta | UI |
| CP-14 | Quitar funcionalidad del plan la oculta y conserva la activación | CU-11 | Alta | Servicio |
| CP-15 | Ícono del plan más bajo | CU-50 | Media | UI |
| CP-16 | Modificar un plan con suscriptores: restricción avisa, confirma y notifica; ampliación solo audita | CU-11, RF-16 | Alta | UI + Servicio |
| CP-17 | Plan gratuito / de prueba con vencimiento: fecha calculada al asignar; columna en el listado | CU-10, RF-26 | Alta | Servicio |
| CP-19 | Plan vencido: todo fuera de plan, invitación a plan no gratuito, MCP rechazado, salida al aprobar | CU-61, CU-63 | Alta | UI + Servicio |
| CP-19b | Un gratuito / de prueba se usa una sola vez por empresa | RF-26b | Alta | Servicio |
| CP-18 | Estructura del menú global: alta, orden, padre; se refleja en todas las empresas | CU-24 | Alta | UI + Servicio |
| CP-20 | Alta de empresa: activa el plan, invita al administrador | CU-12 | Alta | UI |
| CP-21 | Alta con correo que ya es usuario solo crea membresía | CU-12 | Media | UI |
| CP-22 | Correo falla: enlace para copiar | CU-12, 35 | Media | UI |
| CP-23 | Cambio directo a un plan con menos usuarios | CU-15 | Alta | UI |
| CP-24 | Aviso 7 días antes del vencimiento | CU-61 | Media | Proceso |
| CP-25 | Bonificación se suma al período | CU-21 | Media | UI |
| CP-26 | Listado de empresas: filtros y ficha | CU-13, 14 | Media | UI |
| CP-27 | Cambio directo cancela el pedido pendiente | CU-15 | Media | UI |
| CP-28 | Edición de datos y logo de empresa; inicial como sustituto | CU-14 | Media | UI |
| CP-29 | Registros: notificación a infra y aprobación de plan pendiente | CU-23, RF-08, RF-29 | Alta | UI + Servicio |
| CP-30 | Pedido: uno pendiente, no el actual, se puede cancelar | CU-42 | Alta | UI |
| CP-31 | Aprobar pedido | CU-20 | Alta | UI |
| CP-32 | Rechazar pedido | CU-20 | Alta | UI |
| CP-33 | Pedido nuevo avisa al súper usuario y muestra contador | CU-42, 20 | Media | UI |
| CP-40 | Publicar funcionalidad | CU-17 | Alta | UI |
| CP-41 | Sin publicar no se ve en ninguna empresa | CU-17 | Alta | Servicio |
| CP-42 | Contador de Me interesa | CU-17 | Baja | UI |
| CP-43 | El administrador de empresa no puede editar el catálogo | CU-17 | Alta | Servicio |
| CP-50 | Tres grupos de funcionalidades | CU-31 | Alta | UI |
| CP-51 | Apagar una funcionalidad la oculta en menús custom con aviso | CU-31 | Alta | UI |
| CP-52 | Bajar y volver a subir conserva activación, orden y menús | CU-15, 31 | Alta | Servicio |
| CP-53 | Las tools MCP se ven en Funcionalidades pero no en menús | CU-31, 32 | Media | UI |
| CP-54 | Registro: elegir plan con Freemium por default; plan pago genera pedido | CU-53 | Alta | UI |
| CP-60 | Armar menú arrastrando y guardar | CU-32 | Alta | UI |
| CP-61 | El panel solo ofrece funcionalidades visibles | CU-32 | Alta | UI |
| CP-62 | Menú sin opciones no se guarda | CU-32 | Media | UI |
| CP-63 | Nombre de menú repetido se rechaza | CU-32 | Baja | UI |
| CP-64 | Resolución persona > rol > predeterminado | CU-33 | Alta | Servicio |
| CP-65 | Ver como… | CU-32 | Media | UI |
| CP-66 | Asignar sobre un rol que ya tenía menú reemplaza con aviso | CU-33 | Media | UI |
| CP-67 | Menú resuelto: jerarquía del catálogo y opciones de otro plan en su lugar | traz-tools ⤴ | Alta | Servicio |
| CP-68 | Duplicar menú | CU-32 | Baja | UI |
| CP-69 | Las dos direcciones: quién ve cada menú y qué menú tiene cada uno | CU-32, 33 | Media | UI |
| CP-70 | Invitar con lugares disponibles | CU-35 | Alta | UI |
| CP-71 | Tope alcanzado: mensaje y rechazo en servidor | CU-35 | Alta | UI + Servicio |
| CP-72 | Quién ocupa lugar: invitado y baneado sí, baja no | CU-35 a 37 | Alta | Servicio |
| CP-73 | Banear en un clic corta web y MCP | CU-36 | Alta | UI + Servicio |
| CP-74 | No se ofrece ni se acepta banear/dar de baja a uno mismo o al último administrador | CU-36, 37 | Alta | UI + Servicio |
| CP-75 | Reactivar baneado | CU-36 | Media | UI |
| CP-76 | Alta directa con contraseña inicial obliga a cambiarla; IDOR por id rechazado | CU-39 | Media | UI + Servicio |
| CP-77 | Carga masiva que crea usuarios respeta el tope y deja historial | CU-43 | Media | UI |
| CP-78 | Accesos por rol: casilla sí/no sobre activas; Administrador no editable | CU-40 | Alta | UI |
| CP-79 | Cambiar rol en línea con compensación Bonita | CU-38 | Media | Servicio |
| CP-80 | Consumir cuota: ok hasta el tope, rechazo después | CU-51 | Alta | Servicio |
| CP-81 | Concurrencia: 20 llamadas, una pasa | CU-51 | Alta | Servicio |
| CP-82 | Tool fuera del plan: rechazo sin consumir | CU-51 | Alta | Servicio |
| CP-83 | Baneado, baja o empresa bloqueada: `sin_acceso` | CU-51 | Alta | Servicio |
| CP-84 | Renovación semanal | CU-60 | Alta | Proceso |
| CP-85 | Pantalla Uso de IA: cinco estados | CU-41 | Alta | UI |
| CP-86 | Avisos 80 % y 100 % una vez por período | CU-62 | Media | Proceso |
| CP-87 | Cambio de plan a mitad de período recalcula cuota y fin | CU-15 | Media | Servicio |
| CP-88 | Cuota 0 e ilimitado | CU-41, 51 | Media | Servicio |
| CP-89 | Sin período abierto, consumir lo abre al vuelo | CU-51, 60 | Media | Servicio |
| CP-90 | Vista de presentación sin datos reales | CU-50 | Alta | UI |
| CP-91 | Pedir a mano una funcionalidad no visible da 403; inexistente 404 | RF-94 | Alta | Servicio |
| CP-92 | Lo que el rol no permite no aparece | CU-40 | Alta | UI |
| CP-93 | Me interesa avisa, audita y no se repite | CU-50 | Media | UI |
| CP-100 | Auditoría registra cada acción de RF-100 y no el consumo | CU-19 | Alta | Servicio |
| CP-101 | Auditoría inmutable | CU-19 | Alta | DB |
| CP-102 | Variables con historial y vuelta atrás | CU-22 | Media | UI |
| CP-103 | No se desmarca el último súper usuario; ban global | CU-18 | Media | UI |
| CP-107 | Usuarios de la plataforma: filtros, exportar, acceso desde Empresas, ver actividad | CU-18 | Media | UI |
| CP-108 | La Consola solo la ve y la abre el súper usuario; el Portal muestra marca y logo | RF-45, RF-46 | Alta | UI + Servicio |
| CP-104 | Inicio del administrador muestra avisos derivados de la auditoría | CU-30 | Media | UI |
| CP-105 | Perfil: contraseña con reglas en vivo, pide la actual; foto y teléfono | CU-52 | Media | UI |
| CP-106 | Inicio del Portal: control sin KPIs; acceso desde la barra superior de Tools | CU-30, RF-45 | Media | UI |
| CP-110 | Endpoints antes abiertos ahora exigen sesión y rol | C-2 | Alta | Servicio |
| CP-111 | `empr_id` del cliente se ignora | C-1, RNF-02 | Alta | Servicio |
| CP-112 | CSRF activo; nada por GET cambia estado | C-4 | Alta | Servicio |
| CP-113 | Token de invitación: un solo uso, vencimiento | RF-71 | Media | Servicio |
| CP-120 | Listado de formularios: propios y globales, estado, dónde se usa, respuestas | CU-70 | Alta | UI |
| CP-121 | Construir un formulario con todos los tipos y publicarlo | CU-71 | Alta | UI |
| CP-122 | Lista de opciones nueva en línea y lista existente | CU-71 | Alta | UI |
| CP-123 | Nombre interno sugerido; duplicado rechazado; congelado con respuestas | CU-71 | Alta | UI + Servicio |
| CP-124 | Vista previa no crea respuesta y muestra opciones empresa → global | CU-73 | Alta | Servicio |
| CP-125 | Usar como base: copia cabecera, ítems y listas; no sigue al global | CU-72 | Alta | UI |
| CP-126 | Dónde se usa: elegir propio, global o ninguno; la pantalla de Tools lo refleja | CU-74 | Alta | UI + Servicio |
| CP-127 | Alta de empresa escribe la configuración apuntando a los globales "al alta" | CU-12, RF-127 | Alta | Servicio |
| CP-128 | Ciclo de vida: inactivar en uso avisa; baja lógica; respuestas viejas intactas | CU-70, RF-128 | Alta | UI + Servicio |
| CP-129 | Guardar respuesta: sesión, CSRF, obligatorios en servidor, info_id de otra empresa rechazado | CU-76 | Alta | Servicio |
| CP-130 | Un propio nunca aparece en otra empresa; un global sí | RF-130 | Alta | Servicio |
| CP-131 | Consola: globales, puntos de uso, inactivar global usado avisa cuántas empresas | CU-75 | Media | UI |
| CP-132 | Migración de la 9000 a globales y de los sin empresa a su cliente | RF-131 | Alta | Script |
| CP-M1 | Migración: menú v2 = menú v3 por usuario | `02` §8 | Alta | Script |

---

## 3. Escenarios Gherkin

### Identidad y contexto

```gherkin
Característica: CU-01/02/03 Identidad y contexto

  Escenario: CP-01 Login con una sola empresa (existente, UC-006)
    Cuando bruno@ ingresa con su contraseña
    Entonces entra en "MinTest_SJ" y la cabecera no ofrece cambiar de empresa

  Escenario: CP-02 Login con varias empresas (existente, UC-006)
    Cuando ana@ ingresa
    Entonces elige entre "MinTest_SJ (Administrador)" y "Empresa Test (Supervisor)"
    Y "Tierras de Capayán" no aparece aunque tuviera membresía (empresa suspendida)

  Escenario: CP-03 Baneado en su única empresa
    Dado que elena@ solo es miembro de "MinTest_SJ" y está baneada
    Cuando elena@ ingresa
    Entonces ve "Tu acceso a MinTest_SJ está suspendido. Comunicate con el administrador de tu empresa: ana@mintest.com.ar"
    Y no se crea sesión

  Escenario: CP-04 Empresa bloqueada
    Dado que carla@ tiene sesión abierta en "MinTest_SJ" y un JWT vigente
    Cuando root@trazalog suspende "MinTest_SJ" con motivo "falta de pago"
    Entonces el próximo pedido de carla@ recibe "Tu empresa está momentáneamente suspendida. Comunicate con soporte: soporte@trazalog.com" y la sesión se cierra
    Y consumir cuota con su JWT responde sin_acceso
    Y la auditoría tiene empresa.suspender con el motivo

  Escenario: CP-05 Cambiar de empresa
    Dado que ana@ está en "MinTest_SJ"
    Cuando pide cambiar a "Empresa Test"
    Entonces la sesión pasa a Empresa Test, rol Supervisor, groupBpm de Empresa Test
    Cuando pide cambiar a "Yudica" (sin membresía) o a "Tierras de Capayán" (suspendida)
    Entonces se rechaza, la sesión sigue en Empresa Test y el intento queda en la auditoría

  Escenario: CP-06 Recuperar contraseña (existente, UC-008)
    Cuando bruno@ pide recuperar y usa el enlace
    Entonces define una contraseña nueva y entra
```

### Planes y catálogo

```gherkin
Característica: CU-10/11/17 Planes y catálogo

  Escenario: CP-10 Crear plan
    Cuando root@trazalog crea "Starter" con orden 2, 8 usuarios, 50 consultas por semana, lunes
    Entonces aparece entre Free y Team y la auditoría tiene plan.crear

  Escenario: CP-11 Baja en uso
    Cuando root@trazalog intenta dar de baja "Free"
    Entonces ve "Este plan lo usa 1 empresa: cambiala de plan antes de darlo de baja"

  Escenario: CP-12 Plan base
    Cuando root@trazalog marca "Team" como plan base
    Entonces Free deja de serlo y ve "Free dejó de ser el plan base"

  Escenario: CP-13 Casilla
    Cuando root@trazalog marca ALM.ajustes para Free
    Entonces ve "Guardado" sin recargar, Free trae ALM.ajustes y la auditoría tiene plan.funcionalidad.agregar

  Escenario: CP-14 Quitar del plan
    Dado que MinTest_SJ tiene MAN.ot activa y en el menú "Operación"
    Cuando root@trazalog desmarca MAN.ot para Free y confirma "1 empresa la usa"
    Entonces en el menú resuelto de carla@ MAN.ot queda en "Mi trabajo" con estado otro_plan y el ícono de Team
    Y la activación de MinTest_SJ para MAN.ot se conserva (activa, orden 3)

  Escenario: CP-15 Ícono del plan más bajo
    Dado que BPM.procesos está en Business y Enterprise
    Entonces bruno@ la ve en su lugar del menú, sombreada, con el ícono de Business

  Escenario: CP-16 Modificar un plan con suscriptores
    Cuando root@trazalog baja el tope de Free de 5 a 3
    Entonces ve "1 empresa tiene más de 3 lugares usados (MinTest_SJ: 5). Se aplicará y no podrán invitar hasta bajar del tope" y confirma
    Y ana@ recibe correo "Trazalog cambió tu plan Free" y lo ve en el Inicio del Portal
    Cuando root@trazalog agrega ALM.ajustes a Free
    Entonces no hay confirmación ni correo; la auditoría tiene plan.funcionalidad.agregar y MinTest_SJ la ve como "sin activar"

  Escenario: CP-17 Vencimiento
    Cuando root@trazalog crea "Prueba Business" gratuito/de prueba con vencimiento 30 días
    Entonces el listado de planes muestra en la columna "Gratuito / de prueba": Free "Sí · sin vencimiento", Prueba Business "Sí · 30 días", Team "No"
    Cuando asigna Prueba Business a Matheu el 29/10
    Entonces Matheu tiene fecha de vencimiento 28/11 y la ficha permite ajustarla o extenderla
    Cuando intenta poner vencimiento a un plan que no es gratuito/de prueba
    Entonces el campo no está disponible

  Escenario: CP-19 Plan vencido
    Dado Empresa Test en Prueba Business con vencimiento 31/10
    Cuando corre el proceso diario el 31/10
    Entonces Empresa Test queda en estado "plan vencido", eva@ recibe correo y se notifica a infra
    Cuando eva@ y cualquier usuario de Empresa Test entran a Tools
    Entonces entran, pero todas las opciones del menú aparecen sombreadas con el ícono del plan no gratuito de menor orden que las incluye
    Cuando un usuario toca una opción
    Entonces la vista de presentación dice "El período de prueba de tu empresa terminó" e invita a avisar al administrador
    Cuando eva@ abre el Portal
    Entonces abre en Plan con "Tu período de prueba terminó", la comparativa solo de planes no gratuitos y "Pedir plan"; Free y Prueba Business figuran "ya usado"
    Cuando el Gateway consume una tool para Empresa Test
    Entonces responde plan_vencido (403) sin consumir
    Cuando eva@ pide Team y root@trazalog lo aprueba
    Entonces Empresa Test vuelve a operar en Team con sus funcionalidades activas y menús de antes

  Escenario: CP-19b Gratuito una sola vez
    Dado que MinTest_SJ está en Free (gratuito) desde 3/2026
    Cuando root@trazalog intenta cambiarla a Prueba Business
    Entonces la opción está deshabilitada: "MinTest_SJ ya usó un plan gratuito / de prueba"
    Cuando ana@ abre la comparativa
    Entonces Prueba Business aparece como "ya usado" sin botón
    Cuando root@trazalog extiende 15 días el vencimiento de Empresa Test (vencida)
    Entonces Empresa Test vuelve a operar hasta la nueva fecha y la auditoría tiene empresa.extender_vencimiento

  Escenario: CP-18 Estructura del menú global
    Cuando root@trazalog crea la opción MAN / preventivos "Preventivos" con padre MAN / mantenimiento y la arrastra entre equipos y ot
    Entonces aparece en ese orden en el catálogo y, al publicarla y sumarla a Free, en el menú de MinTest_SJ en el próximo pedido
    Cuando intenta moverla al módulo ALM
    Entonces se rechaza

  Escenario: CP-40 Publicar
    Cuando root@trazalog completa nombre y presentación de MAN.preventivos y publica
    Entonces aparece como columna de la matriz
    Y para Yudica aparece sombreada en su lugar del menú (no está en ningún plan todavía)

  Escenario: CP-41 Sin publicar
    Entonces MAN.preventivos no aparece en Funcionalidades de ninguna empresa ni en menús

  Escenario: CP-42 Contador de Me interesa
    Dado 4 "Me interesa" de MinTest_SJ y 3 de Yudica sobre BPM.procesos
    Entonces la ficha del catálogo muestra 7, desglosado por empresa

  Escenario: CP-43 El administrador no edita el catálogo
    Cuando ana@ intenta editar una opción del catálogo (pantalla o pedido directo)
    Entonces no ve la pantalla y el servidor responde 403
```

### Empresas y pedidos

```gherkin
Característica: CU-12 a 16, 20, 21, 42, 61

  Escenario: CP-20 Alta de empresa
    Cuando root@trazalog da de alta "Nueva SA" (Team) con administrador fede@
    Entonces se ejecuta la orquestación de alta (empresa, roles Bonita, establecimiento, depósito)
    Y todas las funcionalidades de Team quedan activas en orden de catálogo
    Y fede@ tiene membresía Administrador invitado con vencimiento a 7 días y recibió el enlace de activación
    Cuando la orquestación falla a mitad
    Entonces la pantalla dice qué quedó creado y ofrece reintentar (no redirige en silencio)

  Escenario: CP-21 Correo que ya es usuario
    Cuando root@trazalog da de alta "Otra SA" con administrador ana@
    Entonces no se crea un usuario nuevo; ana@ suma una membresía Administrador en Otra SA

  Escenario: CP-22 Correo falla
    Dado que el envío de correo falla
    Cuando se invita a fede@
    Entonces la pantalla dice "No pudimos enviar el correo" y muestra el enlace para copiar

  Escenario: CP-23 Menos usuarios que lugares usados
    Cuando root@trazalog cambia Yudica (20 activos) a Team (15)
    Entonces ve "Yudica usa 20 lugares y Team permite 15: sobran 5. No podrá invitar hasta quedar bajo el tope", se aplica
    Y eva@ no puede invitar (409 con el mensaje de tope)

  Escenario: CP-24 Vencimiento de prueba
    Dado que Empresa Test (Business) vence en 2 días
    Cuando corre el proceso diario dos días después
    Entonces Empresa Test queda en Free, BPM.procesos pasa a "de otro plan" y eva@ recibió correo 7 días antes y hoy

  Escenario: CP-25 Bonificación
    Dado MinTest_SJ con 30 de 30
    Cuando root@trazalog bonifica 5 con motivo "demo"
    Entonces Uso de IA muestra 30 de 35 y la auditoría tiene cuota.bonificar

  Escenario: CP-26 Listado y ficha
    Cuando root@trazalog filtra "Con pedido pendiente"
    Entonces ve solo Yudica
    Cuando filtra "Prueba por vencer"
    Entonces ve Empresa Test
    Cuando abre la ficha de MinTest_SJ
    Entonces ve plan Free, 5 de 5 lugares, 21 de 30 IA, historial de planes (derivado de la auditoría) y 5 miembros

  Escenario: CP-27 Cambio directo con pedido pendiente
    Dado el pedido pendiente de Yudica a Enterprise
    Cuando root@trazalog cambia Yudica directamente a Enterprise
    Entonces el pedido queda cancelado con motivo "resuelto por cambio directo" y los administradores reciben correo

  Escenario: CP-28 Editar empresa y logo
    Cuando root@trazalog cambia la descripción, el contacto y sube un logo para MinTest_SJ
    Entonces se guardan, la auditoría tiene empresa.editar y el logo se ve en la ficha, en el listado y en el Portal de ana@
    Cuando Matheu no tiene logo
    Entonces se muestra la inicial "M" como sustituto

  Escenario: CP-29 Registros y notificación
    Cuando un visitante se registra con "Nueva SA" y elige Team
    Entonces Nueva SA se crea en Free con estado "plan pendiente de aprobación: Team"
    Y se llama al servicio de notificación de infra con empresa, administrador, plan y "requiere aprobación"; el envío por Telegram y correo queda registrado
    Y root@trazalog ve la fila en Consola → Registros con estado pendiente
    Cuando aprueba
    Entonces Nueva SA pasa a Team, el administrador recibe correo y la fila queda "aprobada"
    Cuando el servicio de infra falla
    Entonces la fila muestra "notificación fallida", se reintenta y el alta no se bloquea

  Escenario: CP-30 Pedido
    Cuando ana@ pide cambio a Team con motivo "crear OT por IA"
    Entonces queda pendiente; las tarjetas muestran "Pediste pasar al plan Team. Trazalog lo está revisando; te avisamos por correo" con botones deshabilitados
    Cuando intenta pedir Business
    Entonces 409 "Ya hay un pedido pendiente"
    Y la tarjeta Free dice "Tu plan actual" sin botón
    Cuando cancela el pedido
    Entonces puede pedir de nuevo

  Escenario: CP-31 Aprobar
    Dado el pedido de MinTest_SJ a Team
    Cuando root@trazalog aprueba con motivo "venta cerrada"
    Entonces MinTest_SJ queda en Team, ALM.ajustes y MCP.man_crear_ot aparecen "sin activar", ana@ recibe "Tu pedido fue aprobado"
    Y la auditoría tiene pedido.aprobar y empresa.cambiar_plan (origen pedido)

  Escenario: CP-32 Rechazar
    Cuando root@trazalog rechaza con motivo "sin pago"
    Entonces MinTest_SJ sigue en Free, ana@ recibe el motivo y puede pedir de nuevo

  Escenario: CP-33 Aviso de pedido nuevo
    Cuando ana@ crea el pedido
    Entonces root@trazalog recibe correo y el menú Consola muestra el contador 2 (Yudica + MinTest_SJ)
```

### Funcionalidades y menús

```gherkin
Característica: CU-31 a 33

  Escenario: CP-50 Tres grupos
    Cuando ana@ abre Funcionalidades
    Entonces ve Activas (8, en orden), Sin activar (MAN.indicadores) y De otros planes: ALM.ajustes (Team), MCP.man_crear_ot (Team), BPM.procesos (Business), PRD.produccion (Business)
    Y las de otros planes no tienen interruptor

  Escenario: CP-51 Apagar algo que está en menús
    Dado que MAN.ot está en "Operación"
    Cuando ana@ apaga MAN.ot
    Entonces ve "Está en 1 menú: dejará de verse en él. ¿Continuar?"
    Cuando confirma
    Entonces carla@ (menú "Solo equipos") y cualquier Mantenedor con "Operación" no ven MAN.ot
    Y el ítem sigue existiendo en la definición de "Operación", oculto

  Escenario: CP-52 Bajar y volver a subir
    Dado Empresa Test (Business) con BPM.procesos activa en orden 2 y en el menú "Gestión"
    Cuando pasa a Free y luego vuelve a Business
    Entonces BPM.procesos vuelve a Activas en orden 2 y reaparece en "Gestión" sin intervención de eva@

  Escenario: CP-53 Tools MCP
    Entonces MCP.man_get_equipos aparece en Funcionalidades bajo "IA" y en la comparativa de Plan
    Y no aparece en el panel del constructor de menús ni en el menú operativo

  Escenario: CP-54 Registro con plan
    Dado un visitante que activó su cuenta
    Cuando llega al paso "Elegí tu plan"
    Entonces Freemium está preseleccionado con "5 usuarios · Mantenimiento, Almacenes y Herramientas · 30 consultas de IA por semana"
    Cuando sigue con Freemium y completa los datos de la empresa
    Entonces la empresa se crea en Free con esas funcionalidades activas
    Cuando otro visitante elige "Pedir Team"
    Entonces su empresa se crea en Free, queda un pedido pendiente Free → Team con origen "registro", root@trazalog recibe correo y no se piden datos de pago

  Escenario: CP-60 Armar menú
    Cuando ana@ crea "Taller" y arrastra MAN.equipos y MAN.ot a un grupo "Mi trabajo" y guarda
    Entonces el menú tiene un grupo con 2 opciones en ese orden y la auditoría tiene menu.crear

  Escenario: CP-61 Panel solo visibles
    Entonces el panel no incluye ALM.ajustes, BPM.procesos, MAN.indicadores (sin activar) ni MAN.preventivos
    Y el pie dice "Lo que trae tu plan" con enlace a Plan

  Escenario: CP-62 Menú vacío
    Entonces guardar sin opciones responde "Agregá al menos una opción"

  Escenario: CP-63 Nombre repetido
    Entonces crear otro "Operación" responde "Ya tenés un menú con ese nombre"

  Escenario: CP-64 Resolución
    Entonces el menú resuelto de carla@ es "Solo equipos"
    Y el de otro Mantenedor es "Operación"
    Y el de bruno@ (Supervisor sin asignación) es el predeterminado

  Escenario: CP-65 Ver como
    Cuando ana@ elige "Ver como… carla@"
    Entonces ve exactamente lo que devuelve el servicio Menú resuelto para carla@

  Escenario: CP-66 Reemplazo de asignación
    Cuando ana@ asigna "Taller" al rol Mantenedor
    Entonces ve "El rol Mantenedor tenía Operación: se reemplaza" y confirma; queda una sola asignación para el rol

  Escenario: CP-67 Jerarquía y opciones de otro plan en su lugar
    Entonces el menú resuelto de bruno@ (predeterminado) tiene los grupos Mantenimiento, Almacenes, Herramientas, Procesos, Producción en ese orden
    Y dentro de Almacenes, ALM.ajustes aparece con estado otro_plan e ícono de Team después de ALM.stock
    Y Procesos y Producción aparecen con estado otro_plan e ícono de Business
    Y MAN.equipo_alta (sin acceso para Supervisor) y MAN.indicadores (sin activar) no aparecen
    Y no incluye tools MCP ni opciones del Portal
    Cuando bruno@ hace clic en ALM.ajustes
    Entonces se abre la vista de presentación (CP-90)

  Escenario: CP-68 Duplicar
    Cuando ana@ duplica "Operación"
    Entonces aparece "Operación (copia)" con el mismo árbol y sin asignaciones

  Escenario: CP-69 Las dos direcciones
    Cuando ana@ abre el menú "Operación"
    Entonces ve "Lo ven: Mantenedor · Darío Gómez (por rol) · Elena Soto (por rol)"
    Cuando abre la pestaña "Por menú"
    Entonces ve Predeterminado → Administrador, Supervisor, Solicitante, Planificador (3); Operación → Mantenedor (2); Solo equipos → Carla Ruiz (1)
    Cuando abre "Por rol / persona"
    Entonces ve para carla@: asignado "Solo equipos", resuelto "Solo equipos (por persona)"
```

### Usuarios y roles

```gherkin
Característica: CU-35 a 40

  Escenario: CP-70 Invitar
    Dado que dario@ fue dado de baja (4 de 5 lugares)
    Cuando ana@ invita a fede@ como Mantenedor
    Entonces se ejecuta la orquestación de alta, fede@ queda invitado, la pantalla muestra "5 de 5 lugares usados" y recibió el enlace
    Y el token es de un solo uso y vence en 7 días

  Escenario: CP-71 Tope
    Dado 5 de 5
    Cuando ana@ abre Usuarios
    Entonces en vez de "Invitar" ve "Llegaste al tope de 5 usuarios del plan Free. Para invitar a alguien más, dá de baja a un usuario o pedí un cambio de plan" con botón a Plan
    Cuando se llama al servicio de invitar a mano
    Entonces 409 con el mismo mensaje

  Escenario: CP-72 Quién ocupa lugar
    Dado 5 de 5 (dario@ invitado, elena@ baneada)
    Cuando ana@ reactiva a elena@
    Entonces sigue 5 de 5
    Cuando ana@ da de baja a dario@
    Entonces 4 de 5 y puede invitar

  Escenario: CP-73 Banear
    Dado carla@ con sesión y JWT vigentes
    Cuando ana@ banea a carla@ con motivo "licencia"
    Entonces el próximo pedido web de carla@ en MinTest_SJ es rechazado con el mensaje de suspensión
    Y consumir cuota con su JWT responde sin_acceso sin consumir
    Y carla@ sigue pudiendo entrar a otra empresa donde esté activa
    Y la auditoría tiene miembro.banear con motivo

  Escenario: CP-74 A uno mismo y al último administrador
    Entonces la fila de ana@ no ofrece Banear ni Baja
    Y el servicio rechaza banear o dar de baja a ana@ con "Sos la única administradora: nombrá otra antes"

  Escenario: CP-75 Reactivar
    Cuando ana@ reactiva a elena@
    Entonces elena@ entra y la auditoría tiene miembro.reactivar

  Escenario: CP-76 Alta directa e IDOR
    Cuando ana@ crea a gina@ con contraseña inicial
    Entonces gina@ queda activa y al entrar debe cambiar la contraseña antes de seguir
    Cuando eva@ (Empresa Test) pide por id la ficha o el baneo de carla@ (MinTest_SJ)
    Entonces 403

  Escenario: CP-77 Carga masiva
    Dado 3 de 5 lugares
    Cuando ana@ carga un archivo con 4 usuarios nuevos
    Entonces se crean 2, el resultado lista 2 rechazados por "tope del plan" y queda en el historial de cargas (quién, cuándo, entidad, 2 ok, 2 error)
    Cuando se envía un nombre de procedimiento que no está en el catálogo de entidades
    Entonces se rechaza sin ejecutar nada

  Escenario: CP-78 Accesos por rol
    Cuando ana@ abre Roles y accesos → Supervisor
    Entonces ve una casilla por cada una de las 8 activas (sin modo ver/operar); Administrador no es editable
    Cuando desmarca MAN.ot y guarda
    Entonces bruno@ deja de ver MAN.ot en el menú, la url de MAN.ot le responde 403 y la auditoría tiene rol.accesos

  Escenario: CP-79 Cambiar rol
    Cuando ana@ cambia a bruno@ de Supervisor a Planificador
    Entonces se desasigna y asigna la membresía (Bonita y tabla); si Bonita falla, la tabla vuelve atrás
```

### Cuota MCP

```gherkin
Característica: CU-51, 60, 62, 41

  Escenario: CP-80 Hasta el tope
    Dado MinTest_SJ 21 de 30
    Cuando el Gateway consume 9 veces para bruno@ con man_get_equipos
    Entonces responde ok con restantes 8 … 0
    Cuando consume una décima
    Entonces responde sin_cuota (429) "Tu empresa usó las 30 consultas de IA de esta semana del plan Free. Se renueva el lunes 2/11 a las 00:00. Tu administrador puede pedir un cambio de plan desde Mi empresa → Uso de IA"
    Y el consumo tiene 9 ok y 1 sin_cuota

  Escenario: CP-81 Concurrencia
    Dado 29 de 30
    Cuando llegan 20 consumos al mismo tiempo
    Entonces exactamente 1 responde ok y 19 sin_cuota; consumidas = 30

  Escenario: CP-82 Fuera del plan
    Cuando bruno@ consume man_crear_ot (Team)
    Entonces fuera_plan (403) "La herramienta man_crear_ot no está activa para tu empresa. Está incluida en el plan Team"; consumidas sigue 21

  Escenario: CP-83 Sin acceso
    Cuando consume carla@ baneada, dario@ invitado, un dado de baja, o alguien de Tierras de Capayán (suspendida)
    Entonces sin_acceso (401) sin consumir

  Escenario: CP-84 Renovación
    Cuando corre el proceso diario el lunes 2/11 00:05
    Entonces existe el período 2/11 → 9/11 con cuota 30 y 0 consumidas; el anterior queda cerrado con 21; Uso de IA dice "Se renueva el lunes 9/11"

  Escenario: CP-85 Pantalla
    Dado 21 de 30 → barra normal
    Dado 24 de 30 → barra ámbar "Te quedan 6 consultas"
    Dado 30 de 30 → cartel rojo "Sin consultas hasta el lunes 2/11 00:00" y "Pedir cambio de plan"
    Dado Prueba SinIA → "Tu plan no incluye IA" + comparativa
    Dado Enterprise → sin barra, solo consumo
    Y por persona muestra bruno@ 15, carla@ 6; por herramienta man_get_equipos 15 ok, man_get_ots 6 ok, man_crear_ot 0 ok / 3 fuera del plan

  Escenario: CP-86 Avisos
    Cuando pasa de 23 a 24
    Entonces ana@ recibe "Usaste el 80 % de tu cuota de IA"
    Cuando pasa a 25 → sin correo
    Cuando llega a 30 → "Usaste toda tu cuota de IA"

  Escenario: CP-87 Cambio a mitad de período
    Dado 21 de 30
    Cuando MinTest_SJ pasa a Team
    Entonces el período en curso tiene cuota 1.000, consumidas 21 y fin el 1/12 00:00

  Escenario: CP-88 Cuota 0 e ilimitado
    Cuando alguien de Prueba SinIA consume
    Entonces sin_ia (403) "Tu plan no incluye IA"
    Cuando alguien de una empresa Enterprise consume 5.000 veces
    Entonces siempre ok

  Escenario: CP-89 Período al vuelo
    Dado que el proceso diario no corrió y no hay período abierto
    Cuando bruno@ consume
    Entonces se abre el período según el plan y responde ok
```

### Visibilidad

```gherkin
Característica: CU-50, RF-94, CU-40

  Escenario: CP-90 Vista de presentación
    Cuando bruno@ hace clic en BPM.procesos, sombreada en el menú
    Entonces la respuesta no contiene datos de procesos; ve el ícono de Business, "Está incluido en el plan Business", el texto de presentación y "Me interesa"

  Escenario: CP-91 Pedido a mano
    Cuando bruno@ pide la url de BPM.procesos
    Entonces 403 "no está activa para tu empresa"
    Cuando pide la url de MAN.indicadores (sin activar) o de MAN.equipo_alta (sin permiso)
    Entonces 403
    Cuando pide una opción inexistente
    Entonces 404

  Escenario: CP-92 Sin permiso no aparece
    Dado que Supervisor no tiene MAN.equipo_alta
    Entonces bruno@ no ve el botón "Nuevo equipo" (ni deshabilitado)

  Escenario: CP-93 Me interesa
    Cuando bruno@ toca "Me interesa" en BPM.procesos
    Entonces ve "Listo: le avisamos a tu administrador"; ana@ recibe "A Bruno le interesa Procesos. Podés pedir el cambio desde Mi empresa → Plan"; auditoría funcionalidad.interes
    Cuando vuelve
    Entonces ve "Ya avisaste el 29/10"
```

### Auditoría, variables, plataforma, inicio, perfil

```gherkin
Característica: CU-18, 19, 22, 30, 52

  Escenario: CP-100 Acciones auditadas
    Cuando ocurren las acciones de RF-100
    Entonces cada una tiene su fila (quién, empresa, acción, entidad, detalle)
    Y los consumos MCP no están en la auditoría

  Escenario: CP-101 Inmutable
    Cuando se intenta modificar o borrar una fila de auditoría con el rol de base de datos de la aplicación
    Entonces la base lo rechaza

  Escenario: CP-102 Variables
    Cuando root@trazalog cambia validez_invitacion_dias de 7 a 10 y vuelve a la versión anterior
    Entonces vale 7 y el historial tiene 2 entradas

  Escenario: CP-103 Súper usuarios y ban global
    Cuando root@trazalog intenta desmarcarse
    Entonces "Tiene que quedar al menos un súper usuario"
    Cuando root@trazalog aplica ban global a bruno@
    Entonces bruno@ no entra a ninguna empresa y ve el mensaje de soporte

  Escenario: CP-104 Inicio
    Cuando ana@ abre Inicio
    Entonces ve plan Free, 5 de 5, 21 de 30 con renovación lunes 2/11, sin pedido pendiente
    Y los avisos "Se quitó Órdenes de trabajo del plan Free (28/10)" y "Darío no aceptó la invitación (vence 31/10)" salen de la auditoría de los últimos 30 días

  Escenario: CP-107 Usuarios de la plataforma
    Cuando root@trazalog filtra por empresa Yudica y rol Mantenedor
    Entonces ve solo esas membresías; "Exportar" baja un CSV con el listado filtrado
    Cuando llega desde la fila de Yudica en Empresas ("Ver usuarios")
    Entonces el filtro Empresa = Yudica viene aplicado
    Cuando toca "Ver actividad" en bruno@
    Entonces abre Auditoría con el filtro de la persona aplicado

  Escenario: CP-108 Consola solo para súper usuarios; marca y logo en el Portal
    Cuando ana@ (administradora, no súper usuaria) está en Tools o en el Portal
    Entonces no ve el botón "Consola" y cualquier url de la Consola le responde 403
    Cuando root@trazalog está en Tools o en el Portal de una empresa que administra
    Entonces ve "🔑 Consola" y entra
    Cuando ana@ abre el Portal
    Entonces ve la marca Trazalog y el logo de MinTest_SJ (o la inicial "M" si no tiene) con nombre y plan

  Escenario: CP-105 Perfil
    Cuando ana@ escribe una contraseña nueva
    Entonces cada regla (10 caracteres, mayúscula y minúscula, número, símbolo, coinciden) pasa a verde al cumplirse y el botón se habilita solo con todo en verde
    Cuando cambia la contraseña sin poner la actual o con la actual incorrecta
    Entonces se rechaza; con la actual correcta se cambia
    Cuando sube una foto
    Entonces ve la vista previa recortada a cuadrado antes de guardar
    Cuando elige "Tomar foto" sin cámara disponible
    Entonces se le ofrece subir o elegir un avatar
    Cuando carga teléfono "264 555 1234" con +54
    Entonces se valida por país y se guarda

  Escenario: CP-106 Inicio del Portal y acceso desde Tools
    Cuando ana@ (administradora) está en el tablero de Tools
    Entonces la barra superior muestra "🏢 Mi empresa" y el indicador de cuota; el menú del perfil no tiene "Usuarios"
    Cuando bruno@ está en el tablero
    Entonces no ve "Mi empresa" ni la cuota
    Cuando ana@ entra a Mi empresa
    Entonces ve Inicio con tres tarjetas (plan, lugares, IA), los avisos y los accesos; no ve KPIs de operación; "← Ir a Tools" vuelve al tablero
```

### Correctivos

```gherkin
Característica: C-1, C-2, C-4, RF-71

  Escenario: CP-110 Endpoints cerrados
    Cuando un pedido sin sesión llega a cambiar nivel, asignar o quitar membresía, ABM de menú, guardar rol, guardar empresa
    Entonces 401
    Cuando llega con sesión de un usuario sin rol Administrador en la empresa
    Entonces 403
    Y los endpoints de prueba (Email, Test, Test_formularios, scripts SMTP) no existen

  Escenario: CP-111 empr_id del cliente
    Cuando un pedido autenticado incluye un empr_id distinto al de la sesión
    Entonces se usa el de la sesión y el parámetro se ignora

  Escenario: CP-112 CSRF y GET
    Cuando un POST llega sin token CSRF
    Entonces 403
    Cuando se pide por GET una url que antes borraba (deleteuser, borrarEmpresa)
    Entonces no cambia nada

  Escenario: CP-113 Token de invitación
    Cuando se usa dos veces el enlace de activación
    Entonces la segunda vez se rechaza
    Cuando se usa después de 7 días
    Entonces "El enlace venció: pedile a tu administrador que lo reenvíe"
```

### Formularios dinámicos

```gherkin
Característica: CU-70 a CU-76 Formularios dinámicos

  Escenario: CP-120 Listado
    Cuando ana@ abre Mi empresa → Formularios
    Entonces ve "Mis formularios": P-1 (publicado, 5 campos, en uso en Entrega de materiales, 12 respuestas), P-2 (borrador)
    Y "Globales disponibles": G-1, G-2 (publicados) y no ve G-3 (borrador)
    Y en cada global tiene "Usar como base" y "Vista previa", nunca "Editar"

  Escenario: CP-121 Construir y publicar
    Cuando ana@ crea "Inspección de equipo" y agrega un título, un texto "Inspector" obligatorio, un número "Horas", una fecha, una lista desplegable "Obra" con la lista obras, casillas "Fallas" con una lista nueva, opciones excluyentes "Resultado", un archivo y una imagen
    Y arrastra "Inspector" al primer lugar y publica
    Entonces el formulario queda publicado con 9 ítems en ese orden y la auditoría tiene formulario.publicar
    Cuando intenta publicar un formulario sin ítems con nombre
    Entonces "Agregá al menos un campo"

  Escenario: CP-122 Listas de opciones
    Cuando ana@ en "Fallas" elige "Crear lista" y escribe "Pérdida de aceite, Ruido, Vibración"
    Entonces se crea la lista fallas_inspeccion de MinTest_SJ con 3 valores y el ítem la referencia
    Cuando en "Obra" elige la lista existente obras
    Entonces el selector muestra "obras (de tu empresa)" y, si no existiera, "obras (global)"

  Escenario: CP-123 Nombre interno
    Cuando ana@ escribe la etiqueta "Horas de uso"
    Entonces el nombre interno sugerido es horas_de_uso y puede editarlo
    Cuando pone un nombre interno que ya existe en el formulario
    Entonces "Ya hay un campo con ese nombre"
    Cuando edita P-1 (12 respuestas)
    Entonces nombre interno y tipo aparecen bloqueados con "Este formulario ya tiene respuestas"; puede cambiar etiqueta, orden, obligatorio y dar de baja

  Escenario: CP-124 Vista previa
    Cuando ana@ abre la vista previa de P-2
    Entonces se dibuja con el mismo helper de Tools, la lista obras muestra Veladero y Gualcamayo (de la empresa)
    Y no se crea ninguna fila en respuestas
    Cuando eva@ (Empresa Test, sin lista obras propia) previsualiza G-1
    Entonces la lista obras muestra Obra A y Obra B (global)

  Escenario: CP-125 Usar como base
    Cuando eva@ usa G-2 como base con nombre "Salida de pañol Test"
    Entonces Empresa Test tiene un formulario propio en borrador, copiado de G-2, con los mismos ítems y las listas copiadas a Empresa Test
    Y el constructor avisa "Esta copia no sigue los cambios del formulario global"
    Cuando root@trazalog cambia G-2
    Entonces la copia de Empresa Test no cambia

  Escenario: CP-126 Dónde se usa
    Cuando ana@ abre "Dónde se usan" y cambia Entrega de materiales de P-1 a G-1
    Entonces la configuración de MinTest_SJ para formulario_entrega_materiales apunta a G-1
    Y la pantalla de entrega directa de Tools dibuja G-1
    Cuando elige "Ninguno" en Checklist de herramientas
    Entonces avisa "La pantalla quedará sin formulario" y, al confirmar, la pantalla de checklist dice "No se especificó un formulario" y guarda sin info_id (como hoy)
    Y debajo ve, solo lectura, los procesos y tareas estándar con su formulario y el enlace a su ABM

  Escenario: CP-127 Alta de empresa
    Cuando root@trazalog da de alta "Nueva SA"
    Entonces su configuración apunta a G-1 en entrega de materiales y a G-2 en salida de pañol (por referencia, sin copiar)
    Y no se crea ningún formulario con empr_id de Nueva SA

  Escenario: CP-128 Ciclo de vida
    Cuando ana@ inactiva P-1 (en uso)
    Entonces "Está en uso en Entrega de materiales: la pantalla quedará sin formulario hasta que elijas otro" y confirmación
    Cuando confirma
    Entonces P-1 queda inactivo (eliminado lógico, no físico), sus 12 respuestas se siguen viendo en los vales y entregas, y no se ofrece en "Dónde se usan"
    Cuando da de baja el ítem "comprobante" de P-1
    Entonces las cargas nuevas no lo muestran y las 12 respuestas viejas lo conservan

  Escenario: CP-129 Guardar respuesta (Tools)
    Cuando un pedido sin sesión llega a Form/guardar
    Entonces 401
    Cuando bruno@ guarda una entrega dejando vacío "Solicitante" (obligatorio) con el navegador manipulado
    Entonces el servidor responde "Completá Solicitante" y no guarda
    Cuando bruno@ manda un info_id que pertenece a Yudica
    Entonces 403 y nada cambia
    Cuando llama a obtenerTodos
    Entonces solo recibe respuestas de MinTest_SJ (o 404 si el método se eliminó)

  Escenario: CP-130 Ámbito
    Entonces P-1 no aparece en Formularios ni en "Dónde se usan" de Empresa Test
    Y G-1 aparece en las dos empresas
    Y el combo de tareas estándar de Empresa Test muestra sus propios y después G-1, G-2 marcados "(global)"

  Escenario: CP-131 Consola
    Cuando root@trazalog abre Consola → Formularios globales
    Entonces ve G-1 (2 empresas por referencia, 1 copia), G-2, G-3 (borrador) y la pestaña Puntos de uso con la clave, el módulo y el global al alta de cada punto
    Cuando inactiva G-2
    Entonces "Lo usan por referencia 3 empresas: sus pantallas quedarán sin formulario" y confirmación
    Y solo root@trazalog puede elegir los tipos avanzados (service, urlConsultor, urlEvaluador)

  Escenario: CP-132 Migración
    Dado la base de v2 copiada a TEST
    Cuando corre M-7b
    Entonces "Entrega Materiales" de la 9000 queda como global publicado y su lista como global
    Y cada empresa existente conserva su clon y su configuración actual
    Y los formularios sin empresa listados por la consulta §8.5 quedan asignados según la decisión del PM
    Y el informe lista las empresas sin configuración de pañol que quedaron apuntando al global
```

### Migración

```gherkin
Característica: Migración

  Escenario: CP-M1 Menú equivalente
    Dado la base de v2 copiada a TEST y migrada (M-1 a M-7)
    Cuando el script compara, por usuario, las opciones habilitadas por getMenuByUserPermission con el menú resuelto de v3
    Entonces el informe lista 0 diferencias no justificadas
    Y cada diferencia justificada dice el motivo (regla "todos los hijos", opción despublicada, membresía sin empresa)
```

---

## 4. Entrada DocTest de ejemplo (continúa la numeración del catálogo existente)

```yaml
uc: DNATO-UC-036
nombre: Banear o reactivar un usuario de la empresa
modulo: DNATO
actor: Administrador de empresa
pantalla: mockups/empresa-usuarios.html
reemplaza: DNATO-UC-017 (ban global)
rf: [RF-73]
precondiciones:
  - El administrador está en Mi empresa → Usuarios
  - El usuario no es el administrador conectado ni el último administrador activo
pasos:
  - accion: Tocar "Banear" en la fila del usuario
    resultado: Se abre la confirmación con motivo opcional
  - accion: Confirmar
    resultado: El estado pasa a Baneado; toast "Usuario baneado"
postcondiciones:
  - Su próximo pedido en esta empresa es rechazado (web y MCP)
  - Conserva su lugar en el tope del plan
  - Puede seguir usando otras empresas donde esté activo
  - Queda en la auditoría
pruebas: [CP-73, CP-74, CP-75, CP-83]
ayuda: |
  Banear a un usuario le corta el acceso a tu empresa en el momento, también desde la IA.
  No libera un lugar del plan: para eso tenés que darlo de baja.
```
