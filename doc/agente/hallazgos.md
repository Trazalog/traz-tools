# Hallazgos de las pruebas de los agentes

## Objetivo

- 📌 Es el registro de los **problemas encontrados al probar los agentes** (Quirqui, Kuntur y Faustino): en el recorrido automático, al preparar los datos o en la prueba manual del PM.
- 🕐 Hay que leerlo **antes de planificar arreglos**. Todo lo que aparezca se anota acá: **no se arregla en el mismo cambio en que se encuentra**, salvo que impida seguir probando.
- 🚫 **No cubre** los pedidos nuevos ni las opiniones de producto: esas salen de la planilla de opiniones y las decide el PM. El guion de la prueba está en [guion-prueba-agentes.md](guion-prueba-agentes.md).

## Audiencia

- 👤 **El PM**, para decidir qué se arregla y cuándo.
- 🛠️ Quien programa o prueba los agentes.

## Referencias

| Documento | Para qué sirve |
|---|---|
| [guion-prueba-agentes.md](guion-prueba-agentes.md) | El guion que sigue el PM, con las funciones F01… que citan estos hallazgos |
| [decisiones.md](decisiones.md) | Las decisiones de criterio de los agentes (por ejemplo, D-15 a D-19 del control de cifras) |
| [instalar-y-operar.md](instalar-y-operar.md) | Cómo se instala y se opera el motor de los agentes |

## Cómo se usa

- 🔢 Cada hallazgo tiene un identificador **H-n** que no cambia nunca.
- 🚦 Estados: 🔴 abierto · 🟡 en discusión (hace falta una decisión del PM) · ✅ resuelto (con la fecha y la entrega).
- 📍 **Origen**: 🤖 recorrido automático, 🌱 al preparar los datos, 👤 prueba del PM.
- 🧪 Cuando se arregla, el arreglo lleva su prueba automática y acá se anota cuál es.

## Abiertos

| ID | Estado | Qué pasa | Dónde se ve | Origen | Propuesta |
|---|---|---|---|---|---|
| H-1 | 🔴 abierto | **"Feedback del agente" y "Capturar conocimiento" los ve cualquiera que tenga a Quirqui.** En el menú son hijos de "Agente Minero" (`seg.menues.opcion_padre = 'agente_minero'`), y Dnato muestra los hijos junto con el padre. El operario de prueba los ve sin tenerlos asignados | F44, F45 | 🌱 2026-11-26 | Sacarlos de abajo de "Agente Minero" y asignarlos por rol. Es un cambio de datos del menú de Tools (núcleo): necesita tu aprobación |
| H-2 | 🟡 en discusión | **El control de cifras bloquea respuestas buenas que cuentan cosas.** Quirqui armó bien cómo dar de alta un artículo ("tenés que completar estos **cuatro** obligatorios…") y se bloqueó por el "4", que no salía de ningún dato. El usuario recibe "No tengo ese dato confirmado" | F09 | 🤖 2026-11-26 | Sumar "obligatorio(s)", "campo(s)" y "dato(s)" a las palabras de discurso del control (D-15 a D-19), o no controlar un número que es la cantidad de ítems de la lista que la misma respuesta enumera. Es un criterio ya decidido: lo decidís vos |
| H-3 | 🔴 abierto | **Un usuario común puede leer el feedback negativo de toda la empresa.** El motor no controla el rol en `GET /admin/feedback`; hoy lo frena solo el menú, y por H-1 el menú tampoco lo frena | F44 | 🤖 2026-11-26 | Que el motor pida administrador, como hace con Kuntur (`_admin_de_kuntur`) |
| H-4 | 🟡 en discusión | **En la prueba local Kuntur dice que no puede dar de alta depósitos, establecimientos ni valores**, aunque esas altas existen (ADR-A12, script `027`). En el modo de prueba (`AGENTE_MCP_MODO=mi`) el motor solo ofrece las lecturas y las del plan de acción | F40 | 🤖 2026-11-26 | Sumar las tres altas al modo de prueba, igual que las del plan. Escriben en DEV, siempre en la empresa del usuario |
| H-5 | 🟡 en discusión | **Las respuestas tardan entre 10 y 150 segundos** con el modelo gratuito (`nemotron-3-ultra:free`). Las de Kuntur con varias consultas son las más lentas | todo el guion | 🤖 2026-11-26 | Probar un modelo pago para comparar tiempo y costo |
| H-6 | 🔴 abierto | **Se escapan palabras técnicas e inglesas.** Kuntur dice `valores_fijos` y `codigo` al explicar una planilla; Quirqui usa "mantle" y "bowl liner" cuando contesta con conocimiento general | F30, F41 | 🤖 2026-11-26 | Reforzar en las instrucciones de cada agente que no nombre campos técnicos ni use palabras en inglés |
| H-7 | 🟡 en discusión | **Quirqui contesta con conocimiento general del modelo, sin fuente**, cuando no tiene nada registrado ("Conocimiento general de chancadoras…"). Lo aclara, pero lo dice con la misma seguridad que lo registrado | F30 | 🤖 2026-11-26 | Decidir si tiene que decir "no lo tengo registrado" y ofrecer buscar en internet, o si puede usar lo general avisando |
| H-8 | 🟡 en discusión | **La empresa 191 estaba unida en AssetPlanner a la empresa 8 (CSJ-CIENAGUITA)**, con datos que no son de prueba. Con el ingreso real, Quirqui le mostraba esos equipos y esas órdenes a la empresa de prueba. La preparación de la prueba la pasó a su propia empresa, la 191, en `core.empresas.empr_id_mysql` de DEV | — | 🌱 2026-11-26 | Confirmar que nadie usaba la 191 para ver los datos de la 8. Para volver atrás: `UPDATE core.empresas SET empr_id_mysql = 8 WHERE empr_id = 191;` en la base de Tools de DEV |
| H-9 | 🟡 en discusión | **El Tablero de inicio no tiene caso de uso**, así que Quirqui no puede explicarlo (dice que no lo tiene registrado, y ya no inventa). Quedó relevado el caso `DNATO-UC-029` con su ayuda, en borrador | F08 | 🌱 2026-11-26 | Validarlo con la hoja de DocTest (`npm run hoja:validacion -- dnato`). Después se generan las ayudas y se cargan |

## Lo que no es un error (para no anotarlo de nuevo)

- 🌐 **La búsqueda en internet está apagada** en la prueba local (`AGENTE_WEB_URL` vacío). Quirqui dice que no tiene el dato.
- ⏰ **Los procesos que corren solos no están prendidos** en la prueba local: la revisión diaria de metas (`agente.coach`), las mediciones y los avisos. Necesitan la llave de máquina de la empresa, que todavía no se da de alta en local.
- 🧪 **La validación cruzada entre dos expertos no tiene pantalla**: existe en el motor, pero Faustino todavía no la ofrece.
- 🔐 **Faustino no controla el rol en el motor**: cualquiera con el menú puede entrevistar. Está decidido así (D-05 en [decisiones.md](decisiones.md)): el control queda en el menú de Tools hasta que exista un rol de curador. Ojo, que por H-1 hoy el menú tampoco lo frena.
- 🔁 **Dnato, al entrar, manda a `traz-v3/traz-tools`**, que en esta máquina da error. Es del entorno: el guion dice qué dirección escribir.

## Resueltos

| ID | Qué pasaba | Cómo se resolvió | Prueba |
|---|---|---|---|
| H-10 | La carga de conocimiento se cortaba entera: el modelo gratuito de vectores rechazaba un fragmento inocente de la ayuda de Almacenes («content safety screening», 422) | ✅ 2026-11-26: la carga parte el lote hasta aislar el fragmento y lo saltea con un aviso (rama `feat/AGENTE-PRUEBAS-01`) | `tests/test_ingesta_lotes.py` |
| H-11 | Lo que un experto le contaba a Faustino nunca llegaba a Quirqui: no había forma de aprobarlo (la función existía, pero nadie la llamaba) | ✅ 2026-11-26: comando del curador `python -m agente.curar listar / aprobar` | `tests/test_curar.py` |

## Glosario

| Término | Qué es |
|---|---|
| **Control de cifras** | La revisión que hace el motor antes de mostrar una respuesta: todo número tiene que salir de un dato que el agente leyó. Si no, la respuesta se bloquea |
| **Curador** | La persona que aprueba lo que contaron los expertos para que pase al conocimiento compartido. En la base usa un usuario propio, porque el del motor no puede escribir ese conocimiento |
| **Modo de prueba (`mi`)** | El motor habla directo con una copia del integrador de WSO2 en esta máquina, en vez de pasar por el gateway |
| **AssetPlanner** | El sistema donde hoy viven los equipos y las órdenes de trabajo de Mantenimiento |
| **Llave de máquina** | La credencial con la que los procesos automáticos de los agentes consultan los datos de una empresa sin que haya nadie conectado |
