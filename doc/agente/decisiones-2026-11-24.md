# Decisiones tomadas por Claude Code para cerrar el plan de agentes (22 al 24 de noviembre de 2026)

## Objetivo

Qué es: la lista de las decisiones que tomé solo, por pedido del PM («si tenés que tomar decisiones hacelo y luego documentá cuáles y si precisás mi revisión», 2026-11-22), mientras avanzaba el plan de agentes hasta el martes 24 a las 9. Para quién: el PM, que las revisa una por una. Cuándo leerlo: antes de unir los cambios propuestos de esta tanda. Qué NO cubre: las decisiones que tomó el PM (están en `doc/v3/STATE.md`) ni el detalle técnico de cada cambio (está en su PR).

**Cómo leer la tabla:** 🔴 = necesita tu revisión antes de unir (toca el núcleo, la marca o algo legal); 🟡 = conviene que la mires, pero no frena; 🟢 = técnica menor, solo para que sepas.

| # | Decisión | Por qué | Dónde | Revisión |
|---|---|---|---|---|
| 1 | Completé los seis bloques del prompt de Quirqui (presentación, advertencias de seguridad, límites, tono, extensión, fuera de tema) y el de Kuntur (cómo acompaña al administrador) | Eran el último pendiente del gate de textos (M-07) y el taller entregó solo las imágenes | `prompts/quirqui.md`, `prompts/kuntur.md` — PR de AGENTE-M-07 | 🔴 marca y responsabilidad: sobre todo las **advertencias de seguridad** (B) y los **límites** (C) |
| 2 | Quirqui, si le preguntan, dice que es un asistente de inteligencia artificial | Es lo honesto y evita un problema si un cliente lo descubre después | bloque A | 🟡 |
| 3 | Las advertencias de seguridad suman riesgos por industria (voladura y polvo en minería, gas sulfhídrico en oil & gas, arco eléctrico en electricidad) y la regla «si difieren, vale el procedimiento más exigente» | El producto es multi-industria (ADR-A11) | bloque B | 🔴 ideal que lo mire un ingeniero de seguridad |
| 4 | El alcance de Quirqui suma Pañol y Tareas | Las herramientas de Pañol ya existen y las de Tareas están en construcción | `prompts/quirqui.md` | 🟢 |
| 5 | Imágenes de los personajes: tapé la marca de agua del generador, fondo transparente, 512×512 | Para usarlas en el panel y en avisos | PR #661 | 🟡 mirá que la marca de agua no se note |
| 6 | Enlace directo a pantallas: el agente escribe `[texto](tools:ruta)` y el panel lo convierte en un enlace que navega dentro de Tools; la ruta sale del catálogo de DocTest | Decisión del PM en AGE-UC-004; así el modelo no inventa rutas | PR #662 | 🟢 |
| 7 | Los motivos rápidos del 👎 usan las categorías que ya existían en la base: «No era eso» → no entendió, «Dato equivocado» → respuesta incorrecta, «No se entiende» → otro | No hace falta cambiar la base | PR #662 | 🟢 |

| 8 | Lectura de Tareas: "finalizado" es un estado que contiene FINALIZADO; "atrasada" usa el fin planificado o, si no tiene, la fecha asignada; "sin asignar" es una tarea sin responsable | Son las reglas más simples que coinciden con cómo guarda Tareas los datos | PR #665, `doc/agente/analisis-impacto-tar-lectura.md` | 🔴 toca WSO2 (núcleo): aprobar el análisis. **Orden de despliegue: con #640 y #645 o después, nunca antes** (si no, se verían tareas de otras empresas) |
| 9 | Quirqui propone "tus tareas atrasadas" en cualquier pantalla, sin enlace a ayuda porque todavía no hay manual de Tareas | Aplica tu decisión de AGE-UC-003 | PR #666 | 🟢 |
| 10 | Los avisos de una meta en riesgo siguen yendo a quien la cargó (D-94), no a todos los administradores (D-85) | Mandar a todos necesita cambiar el mecanismo de avisos de Tools (núcleo) y saber quiénes son los administradores, que llega con Dnato v3 | sin cambios | 🟡 |
| 11 | Un motivo de calificación desconocido se rechaza con un error claro (422) en lugar de un error interno | Lo encontré corriendo las pruebas de la API | PR #662 | 🟢 |
| 12 | Recomendaciones de partes sin usar: catálogo de 7 (metas, preventivo, punto de pedido, certificaciones, movimientos de stock, depósitos, pañol), máximo 3 a la vez, "no me interesa" las esconde 30 días para toda la empresa | Reglas sobre datos, sin el modelo, para que cada cifra tenga fuente | PR #663, `doc/agente/funciones-sin-usar.md` | 🟡 mirá si el catálogo es el correcto |

| 13 | **No armé los indicadores por industria** (KPI-VERT: cumplimiento de preventivos, tareas en plazo por usuario, rotación de repuestos críticos) | Dependen de tu documento de indicadores, que no está aprobado, y son un cambio de base de datos en el ambiente compartido. "Tarea en plazo" además necesita definir contra qué fecha se compara, y Tareas no guarda un fin planificado separado del real | queda pendiente | 🔴 decisión tuya: aprobar el documento de indicadores |
| 14 | El riesgo anotado en la lectura de Tareas (pedir las tareas con el último tramo de la dirección vacío) lo considero bajo | El informe de Indicadores de Tareas que hoy usa producción ya llama al servicio de datos con tramos vacíos (`Reportes.php:52`) y funciona | PR #665 | 🟢 igual conviene probarlo en DEV al desplegar |

| 15 | Plan de acción: al aceptar, el pedido se crea con el **primer cliente activo** de la empresa y cada hito con el **primer establecimiento** | Tareas exige cliente (las listas no muestran un pedido sin cliente) y el hito pide establecimiento; elegirlo en la tarjeta suma un paso más para el administrador | PR #669, análisis §«Decisiones de AGENTE-CO-04» | 🟡 ¿preferís que el administrador elija el cliente en la tarjeta? |
| 16 | Plan de acción: topes de 6 hitos, 30 tareas y 26 semanas; una propuesta sin respuesta vence a los 7 días | Una puesta en marcha de PyME; planes más grandes no se leen en una tarjeta | PR #669 | 🟡 |
| 17 | Plan de acción: **funciona simulado**. Los 5 recursos que crean en Tareas (pedido, hito, tarea y sus bajas) están escritos, pero ningún agente los llama hasta tu aprobación | Tocan WSO2 (núcleo) | PR #669, anexo A del análisis | 🔴 aprobar el anexo A y probarlos en DEV |
| 18 | Mediciones: la que pide Kuntur queda activa enseguida, sin tarjeta de confirmación; el administrador la ve en «Lo que estoy midiendo» y la puede cancelar. Tope de 20 activas por empresa | Solo escribe en la base del agente, no en Tools; la regla R11 pide que la vea y la cancele, no que la confirme | PR #668, `doc/agente/mediciones.md` | 🟡 |
| 19 | Mediciones: corren todos los días a las 6, aparte del monitoreo que corre cada hora; los indicadores de Mantenimiento se miden sobre los últimos 30 días | Un indicador no cambia de una hora a otra | PR #668 | 🟢 |

| 20 | Medir si el plan funcionó: se compara el primer valor medido con el último; "funcionó" es que mejoró aunque sea poco, en el sentido del indicador (atrasadas, fallas y tiempo de reparación mejoran si bajan; disponibilidad, si sube). Una medición cancelada no se evalúa | Regla simple y explicable; cada número sale de una medición guardada | PR #670, `doc/agente/mediciones.md` | 🟡 ¿querés una mejora mínima (por ejemplo, 2 puntos) para decir que funcionó? |
| 21 | El aviso "terminó el plan" les llega a quienes estén suscriptos al tipo de aviso `plan_accion_resultado` | No se guarda qué administrador aceptó el plan y avisar "a todos los administradores" todavía no se puede (decisión 10) | PR #670 | 🔴 hay que **suscribir a los administradores** a ese aviso en Tools, o no le llega a nadie |
| 22 | Si el plan funcionó, se propone como práctica a la cola de curaduría, sin números, sin la empresa y sin el número de pedido | Las prácticas se comparten entre empresas (ADR-A4) | PR #670 | 🟡 el curador tiene que revisar que no queden nombres propios o códigos de equipo |

| 23 | Temas de Faustino por industria: chancado y molienda pasan a minería; se suman 5 temas de oil & gas (bombeo mecánico y pozos, compresores, separadores y tanques, integridad de ductos, gas sulfhídrico y atmósferas explosivas) y 5 de electricidad (transformadores y subestaciones, líneas, protecciones y maniobras, trabajo con tensión y arco eléctrico, generación) | La lista inicial era solo minera y el producto es para las tres industrias (ADR-A11) | `db/agente/034-taxonomia-verticales.sql`, PR #664 | 🟡 mirá si faltan familias de equipos de tus clientes |

| 24 | Preparé el resumen para el abogado (aviso de medición, datos personales y proveedor de inteligencia artificial fuera del país, responsabilidad por recomendaciones técnicas, imágenes y nombres como marca) | Para que lo legal no frene el lanzamiento: solo hay que mandarlo | `doc/agente/revision-legal.md` | 🟡 leelo antes de mandarlo |

| 25 | Si el servidor de herramientas (gateway) no responde, el agente contesta igual con lo que sabe y avisa que no vio los datos de la empresa | Antes, con el gateway caído, ninguna pregunta tenía respuesta | PR #671 | 🟢 |

| 26 | Las 5 escrituras del plan se probaron en una copia aislada del servidor de WSO2: 21 de 21. Se corrigió que, cuando el servicio de datos responde sin cuerpo, el servidor devolvía una respuesta vacía y el motor se quedaba sin el número de la tarea creada | Probar antes de pedirte la aprobación | PR #669, anexo A del análisis | 🔴 junto con la aprobación del anexo A: quedan 5 verificaciones en DEV (lista «Semanas», cliente activo y tipo General en empresas reales, cómo se ve el hito en Tareas, código real del servicio, que TST001 arranque al asignar) |

| 27 | Modelos **gratuitos** por defecto: chat `nvidia/nemotron-3-ultra-550b-a55b:free` y búsqueda por significado `nvidia/nemotron-3.5-embed-1b:free` (pidiendo vectores de 1024, el tamaño de la base) | La cuenta sin crédito responde 402 a los pagos y el gratuito anterior dejó de serlo. Con estos, los agentes contestan de verdad: probado de punta a punta | PR #672 | 🔴 para producción conviene un modelo pago (los gratuitos tienen límites de uso y cambian seguido). Cambiar el modelo de búsqueda obliga a recargar el conocimiento ya cargado |

| 28 | Motor más robusto con modelos chicos: un reintento si la respuesta viene vacía o bloqueada (siempre pasa por el guardián), no repetir una consulta idéntica, esperar ante «demasiadas consultas», hasta 8 consultas por pregunta y 4000 de tope por respuesta (con 1500 se cortaban los planes) | Probando con el modelo real, Kuntur no llegaba a proponer el plan; con estos cambios, 3 de 3 | PR #673 y #672 | 🟡 el reintento es una segunda oportunidad al modelo, no afloja la regla de cifras |
| 29 | Las fuentes se nombran en palabras («según el indicador de disponibilidad») y no se hacen cuentas propias | El administrador no entiende `man_get_kpi_disponibilidad`, y una cuenta propia («9 de 10») se bloquea | `prompts/`, PR #664 | 🟢 |

| 30 | **Prueba de punta a punta contra DEV hecha (2026-11-23), sin esperar el despliegue:** levanté una copia propia del servidor de WSO2 (puerto 8301, aparte del tuyo) con todas las APIs y servicios de datos de `develop-v3.5`, conectada a las bases de DEV (`scripts/dev/mi-local-agentes.sh`). Kuntur leyó el stock real de la empresa 191 (3 artículos bajo el punto de pedido), propuso un plan y, al aceptarlo, se creó en Tareas el **pedido 978** (código `K-261123-5C56DB`, Proceso Estándar, cliente 82, tipo General, 14 días) con **2 hitos** (H01 y H02, 7 días cada uno) y **6 tareas** sin responsable ni fecha (31-12-3000), sin proceso de Bonita lanzado. Kuntur lo lee; otra empresa recibe «no encontrado» | Me pediste levantar el servidor local y desplegar vos | Base de DEV, empresa 191 | 🟡 el pedido 978 quedó en DEV como prueba: borralo o dejalo, como prefieras |
| 31 | El modo de desarrollo del motor ahora sabe crear y deshacer el plan en Tareas (antes solo leía y aceptar fallaba). Esas 5 operaciones **no se le ofrecen al modelo**: solo las usa el botón «Aceptar» | Sin esto no se podía probar el plan real sin el gateway | `agente/mcp_client.py` | 🟢 |
| 32 | El guardián de cifras revisa **todo** el texto del plan que va a Tareas (nombres y descripciones de hitos y tareas), y acepta las semanas y la meta que fija el propio plan («Semana 1», «al 13/12») | En la prueba, «Semana 1» bloqueó la respuesta aunque la tarjeta quedaba creada, y una tarea llevaba cantidades inventadas («sugerido: 100 u. de aceite») que terminaron en el pedido real | `agente/orquestador.py`, `agente/planes.py` | 🟡 si Kuntur propone menos planes por esto, lo vemos |
| 33 | Las herramientas de indicadores de mantenimiento le dicen al modelo que piden fechas (desde y hasta) | El modelo las llamaba sin fechas y la fachada tardaba un minuto entero en fallar | `agente/mcp_client.py` | 🟢 |
| 34 | Si el guardián bloquea la respuesta pero el plan propuesto no tiene cifras sin fuente, la tarjeta del plan vuelve a mostrarse cuando el reintento pasa | En la prueba contra DEV el texto se bloqueó por un "13", el reintento salió bien, pero la tarjeta se había perdido y Kuntur decía "te dejé la tarjeta" sin que hubiera ninguna | `agente/orquestador.py` | 🟢 |
| 35 | En la capa de los agentes, las comparaciones entre textos se hacen con `String(a) == String(b)` en vez de `===` | En el WSO2 6.5 del servidor compartido, `===` entre dos textos armados con `"" + x` da falso aunque sean iguales: "ver el detalle del pedido 978" devolvía "no encontrado". En el WSO2 4.5 local andaba bien | `toolsMCPAPI.xml` (3 lugares) | 🟢 |
| 36 | La consulta de stock de los agentes (`alm_get_stock`) devuelve también el **faltante**: cuánto le falta a cada artículo para llegar a su punto de pedido, calculado por la base (`punto de pedido − stock`, 0 si no falta). Kuntur copia ese número en el plan en vez de hacer la cuenta | Decisión del PM (opción A): «lo útil es que si el plan muestra una cifra, esa cifra salga de lo que faltaba de ese artículo». Antes, una cuenta bien hecha («pedir 40») se bloqueaba igual porque el 40 no estaba escrito en ningún dato | `ALMDataService.dbs` (`getStockFiltradoMcp`), `agente/mcp_client.py`, `prompts/kuntur.md` | 🟢 |
| 37 | El guardián ya no lee «10.0» como «100»: un punto o una coma solo separan miles si los siguen grupos de tres cifras | Lo encontró la prueba de la decisión 36: un stock de 10.0 (como lo devuelve la base) respaldaba un «100» inventado, justo el caso del aceite | `agente/guardian.py` | 🟢 |
| 38 | Si el plan apunta a un valor del indicador («que baje a 0»), Kuntur lo pone en la meta del plan; y si un plan igual se cae por una cifra sin respaldo, la respuesta lo dice en vez de hablar de una tarjeta que no está | En la prueba contra DEV la tarea decía «que baje a 0» sin meta, el plan se cayó y la respuesta decía «te dejé la tarjeta» | `prompts/kuntur.md`, `agente/orquestador.py` | 🟢 |
| 39 | La consulta de stock usa cada filtro **una sola vez** (los filtros se leen una vez en una subconsulta) | En el WSO2 6.5 del servidor compartido, la consulta con el mismo filtro repetido fallaba siempre (error interno de WSO2), con o sin filtros. Con la forma nueva anda en los dos WSO2 | `ALMDataService.dbs` | 🟢 |
| 40 | **Gate 2 cerrado con tus textos (2026-11-24).** Los seis bloques de Quirqui, Kuntur y Faustino quedan tal cual los entregaste (`doc/agente/gate2-textos-pm/`); reemplazan los que había puesto yo (decisión 1). Para que no se contradigan: saqué «Trazalog» de lo que leen y dicen los agentes (títulos de los prompts, preguntas y avisos de Kuntur, encabezado de las ayudas), saqué el «de vos» fijo de su personalidad y dejé el plan de Kuntur en «no más de 3 hitos» | Tu bloque (A) dice «nunca nombres la marca del sistema» y el (D) «el español del país del usuario» | `prompts/*.md`, `db/agente/035-textos-pm.sql`, `agente/configuracion.py`, `agente/evaluacion.py`, `agente/fuentes.py` | 🟢 |
| 41 | Dos líneas que **agregué yo** a tus textos: «si no sabés de qué país es la persona, hablá de vos» y «si te preguntan de qué marca es el sistema, decí que lo puede contar quien administra la empresa» | En la prueba real, sin la primera Kuntur pasó al «tú» («tú decides»); sin la segunda Quirqui contestaba «no nombro la marca», que suena raro | `prompts/*.md` | 🟡 revisalas: si no te gustan, se sacan |
| 42 | **Agenda de Faustino = tu tabla:** 42 temas por industria (16 generales, 10 de minería, 9 de oil & gas, 7 de electricidad). Los que renombraste conservan lo ya capturado («Equipos móviles» → «Equipos móviles de mina», y los de oil & gas y electricidad que yo había puesto). Los que no están en tu tabla dejan de preguntarse pero no se borran: las raíces viejas (Mantenimiento, Almacenes, General, Oil & gas, Electricidad) y dos temas de seguridad que yo había sumado («Gas sulfhídrico y atmósferas explosivas», «Trabajo con tensión y arco eléctrico») | Tu bloque 2 | `db/agente/035-textos-pm.sql` | 🟡 los dos de seguridad quedaron afuera: si querés que vuelvan, se suman a la tabla |
| 43 | Faustino **marca** lo que suena inseguro (bloque 5 C): el hecho se guarda tal cual, con el motivo en `metadata.revisar`, para que una persona lo revise. Hoy la pantalla de curaduría todavía no lo muestra resaltado | Tu bloque 5 (C) | `agente/entrevistador.py`, `prompts/faustino.md` | 🟡 falta mostrarlo en pantalla |

### Lo que encontré en DEV con la prueba (2026-11-23)

- 🔴 **El servicio de datos de Tareas de DEV es el viejo y no filtra por empresa.** Con la fachada nueva apuntando a él, la empresa 191 (sin pedidos) veía tareas atrasadas de 2020 de otras empresas. Con el servicio de `develop-v3.5` (los arreglos #640 y #645) ve cero, como corresponde. **Al desplegar en DEV, primero los servicios de datos y después la fachada** (ya estaba en el orden de despliegue; ahora está comprobado).
- 🟡 **Si a un indicador de mantenimiento le faltan las fechas, la fachada se cuelga un minuto** en vez de responder «faltan las fechas»: la secuencia de error vieja (`toolsFault`) no contesta. Es una falla previa del núcleo (no la toqué; arreglarla pide su análisis de impacto). Del lado del agente quedó evitada (decisión 33).
- 🟡 En DEV no están desplegadas las APIs de almacenes, pañol y núcleo de `develop-v3.5` (stock y depósitos daban 404); en la copia local funcionan.

*(La tabla se completa a medida que avanzo.)*

---

## ⛔ Lo que frena que los agentes funcionen de verdad (lo tenés que hacer vos)

| # | Qué | Por qué | Dónde se hace |
|---|---|---|---|
| 1 | **Para producción: decidir si se carga saldo en OpenRouter** y se usa un modelo pago | Para probar ya no frena: con #672 los agentes usan modelos gratuitos que funcionan (decisión 27). Sin saldo, los modelos pagos responden 402 | Panel web de openrouter.ai, sección de créditos |
| 2 | ~~Aprobar los análisis que tocan el núcleo~~ | **Hecho el 2026-11-22** | — |
| 3 | Desplegar el `.car` con `toolsMCPAPI.xml` nuevo en un MI y publicar las operaciones en el gateway | Sin eso, Kuntur y Quirqui no ven Tareas | Servidor de DEV (sigue «Orden para desplegar») |
| 3b | **Correr las verificaciones de DEV de una vez** (solo leen): Proceso Estándar, empresas sin cliente activo o sin tipo General, lista de Semanas, pedidos sin empresa, quién recibe el aviso de fin de plan. Al final del archivo está, comentado, cómo suscribir a un administrador | Desde acá no se alcanza la base de DEV (hace falta la conexión segura) | Terminal local con VPN: `psql -h 10.142.0.13 -U postgres -d tools_prod_t -f scripts/dev/verificaciones-dev-agentes.sql` |
| 4 | Suscribir a los administradores al aviso `plan_accion_resultado` | Si no, el aviso «terminó el plan» no le llega a nadie (decisión 21) | Tools, pantalla de avisos |
| 5 | Probar un aviso real al celular con el Firebase de AssetPlanner | Nunca se probó contra Firebase real | DEV, con la conexión segura (`doc/notificaciones/instalacion-avisos.md`) |
| 6 | Mandar `doc/agente/revision-legal.md` al abogado | Antes del primer cliente | — |

## Orden para unir los cambios propuestos

> ✅ **Hecho el 2026-11-22**: el PM aprobó unir todo (incluidos los análisis de #665 y del anexo A de #669) y los 14 cambios se unieron en este orden. El plan de acción ya no es simulado.

Están todos en borrador contra `develop-v3.5`. Algunos van apilados (cada uno contiene al anterior), así que conviene unirlos en este orden. Entre ramas hay choques menores esperables (la lista de scripts de `db/agente/tests/test-estructura.sql`, `db/agente/README.md`, las importaciones de `agente/orquestador.py` y `agente/api.py`, los contenedores de la pestaña Kuntur en `views/panel.php`, `prompts/kuntur.md` y `doc/v3/STATE.md`). Todos se resuelven **conservando las dos partes**; ya los resolví así en la rama de prueba integrada, donde pasan las 507 pruebas del motor, la prueba de estructura de la base y las 11 pruebas del panel en el navegador.

| Orden | PR | Qué | Toca el núcleo |
|---|---|---|---|
| 1 | #643 | Análisis y ADR-A13 del plan de acción | No (documentos) |
| 2 | #664 | Textos de Quirqui y Kuntur, este registro de decisiones, cómo probar | No |
| 3 | #661 | Avatares, iconos de avisos, cara en la campanita | No |
| 4 | #662 → #667 | Casos de uso validados y sus cambios en Quirqui → pruebas y ayuda derivadas | No |
| 5 | #663 | Funciones sin usar (Kuntur) | No |
| 6 | #665 → #666 → #668 → #670 | Lectura de Tareas → tus tareas atrasadas → mediciones → medir si el plan funcionó | **Sí, #665** (4 lecturas nuevas en WSO2) |
| 7 | #669 | Plan de acción (simulado hasta aprobar sus 5 escrituras en WSO2) | **Sí** (anexo A) |
| 8 | #671 | Responder sin el gateway | No |
| 9 | #672 → #673 | Modelos gratuitos y vectores de 1024 → motor robusto con modelos chicos | No |

## Orden para desplegar (cuando se unan)

1. **Base del agente:** aplicar los scripts `029` a `034` en orden (con el usuario dueño de la base).
2. **WSO2:** el `.car` con `toolsMCPAPI.xml` nuevo, **después** de que estén desplegados #640 y #645 de Tareas (si no, la lectura de tareas vería otras empresas). Publicar en el Publisher del gateway las operaciones nuevas (`doc/api/trazalog-operaciones.yaml`).
3. **Tools (PHP):** el módulo del agente, `lib/props/avisos.js` y `assets/agentes/`.
4. **Avisos al celular:** `NTF_ICONOS_URL` apuntando a `https://<tools>/assets/agentes/iconos` en el Streaming Integrator.
5. **Trabajos programados:** sumar `python -m agente.mediciones` todos los días a las 6 (ver `doc/agente/mediciones.md`).

## Instalación en el servidor compartido de desarrollo (2026-11-24)

Autorizada por el PM ("4 listo"). Respaldo previo en el servidor: `/home/rodolfo/respaldo-wso2-antes-agentes-20261124-1808.tgz`.

- **Instalado:** servicios de datos `TARDataService` (el que filtra por empresa), `PRODataService`, `MANDataService` y `PANDataservice` (estos dos solo suman consultas), `MANEquiposDataService` y `PINGDataService` (nuevos); interfaces `toolsMCPAPI` (la de los agentes), `toolsALMAPI` y `toolsPANAPI` (nuevas); secuencias `emprIdFromHeader` y `rechazarTokenMaquina` (nuevas).
- **No instalado, a propósito:**
  - ~~🟡 `ALMDataService`~~ → **instalado el 2026-11-24** (ver abajo).
  - `toolsCOREAPI`, `toolsMANAPI`, `toolsbpmAPI`, `toolsLogAPI`, `COREDataService` y el resto: son las de la versión 2 que usa el equipo; no se tocan. Por eso `core_get_empresa_actual` da 404 en el servidor compartido.
  - `toolsNTFAPI` y `NTFDataService` (avisos al teléfono): necesitan el esquema `ntf` en la base, que todavía no está.
  - `ToolsKPIDataService`: en el servidor está como `ToolsKPIDataService.dbs.dbs` y distinto; queda como está.
  - `toolsFaultSequence.xml`: el servidor ya tiene su `toolsFault`; se usa ese.
- **Probado** con la empresa de prueba 191: `tar_get_pedidos`, `tar_get_atrasadas`, `tar_get_pedido/978` (y 404 para otra empresa), `pan_get_herramientas`, `alm_get_depositos`, `man_get_kpi_fallas`. Sin identidad, 503. La versión 2 sigue respondiendo.
- `man_get_ots` falla porque el token de prueba no trae la empresa de AssetPlanner; con un usuario real debería andar (supuesto, no probado).

### Almacén en el servidor compartido (2026-11-24, segunda parte)

Autorizado por el PM («hazlo y después vemos»). Respaldo del archivo anterior en el servidor: `/home/rodolfo/respaldo-ALMDataService-20261124-2026.dbs`.

- **Corrección de lo que dije antes:** el `ALMDataService` del servidor no tenía «agregados a mano»; tenía una versión **vieja**. Las dos consultas que solo estaban ahí (`GET /articulos` y `GET /articulos/obtener/{arti_id}`) son las que se retiraron a propósito en la versión 2.5 (PR #494) porque leen artículos **sin filtrar por empresa** (fijan la empresa 1); en ese momento se verificó que nadie las usa, y en el código de hoy tampoco aparecen. Producción (`master`) ya no las tiene.
- **Versión instalada** = la de `develop` (que ya juntaba todo: lo de los agentes y los transportistas) + el faltante (decisión 36) + la consulta de stock con cada filtro una sola vez (decisión 39). Queda en `develop-v3.5` por este PR, así que deja de haber diferencias entre el servidor y una rama.
- **Probado en el servidor:** stock de la empresa 191 (3 artículos, con faltante 40, 90 y 17), con filtro de depósito y de búsqueda; vencimientos; depósitos; detalle de artículo con empresa; otra empresa (900999) no ve nada; establecimientos (versión 2) sigue andando.
- **Kuntur de punta a punta contra el servidor:** pidió el stock, propuso un plan de 3 hitos con «pedir 40 / 90 / 17» y la meta «artículos bajo punto de pedido ≤ 0», sin ningún bloqueo del guardián. No lo acepté: no se creó ningún pedido.
- **Ojo (supuesto, no probado):** `getOTsByEmpresa` de `MANDataService` también repite un filtro (`estado`); si `man_get_ots` sigue fallando con un usuario real, es el primer sospechoso.

