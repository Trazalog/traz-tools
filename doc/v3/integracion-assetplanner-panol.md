# AssetPlanner y el Pañol de Trazalog Tools — cómo quedó funcionando hoy

## Objetivo

Explicarle al Product Owner, en lenguaje de mantenimiento y sin tecnicismos, cómo trabaja hoy
AssetPlanner con el Pañol de Trazalog Tools: en qué momentos del ciclo de mantenimiento aparecen las
herramientas, en qué pantallas, qué hace el sistema solo y qué queda en manos de las personas. Sigue
con una lista de dudas funcionales, y cierra con **lo que dicen las buenas prácticas del rubro y una
propuesta de cómo debería quedar** (§7 y §8), para que el PO decida con las dos cosas a la vista.
**No** cubre la integración con Almacenes (materiales e insumos), que es un circuito aparte, ni
describe cómo está construido por dentro.

| | |
|---|---|
| **Estado** | Desarrollado y probado en el ambiente de desarrollo. **No está en producción.** |
| **Fecha del relevamiento** | Septiembre 2026 |
| **A quién va dirigido** | Product Owner (Mauricio) |

---

## 1. La idea en dos líneas

Hasta ahora AssetPlanner tenía **su propio pañol**: una lista de herramientas cargada dentro de
AssetPlanner, sin control de si la herramienta estaba en el pañol o afuera. Ahora **el pañol vive en
Trazalog Tools** y AssetPlanner lo consulta. El pañolero administra las herramientas en Tools; el
planificador y el técnico las usan desde AssetPlanner, y cuando las usan, **salen del pañol**.

---

## 2. Antes y ahora

| | Antes | Ahora |
|---|---|---|
| Dónde se da de alta una herramienta | En AssetPlanner (menú Pañol → Herramientas) | En Trazalog Tools, módulo Pañol |
| Qué herramientas ve el planificador al armar un plan | Todas las que alguna vez se cargaron, estén donde estén | **Solo las que hoy están disponibles en el pañol** de la empresa, ordenadas por nombre |
| Qué pasa cuando el técnico informa que usó una herramienta | Nada: quedaba anotado en el informe y listo | Se genera un **vale de salida en el pañol de Tools** y la herramienta queda **"en tránsito"** (afuera) |
| Qué ve el resto de la gente mientras la herramienta está afuera | La seguían viendo como si estuviera | **Ya no se la ofrece** a nadie hasta que vuelva al pañol |
| Marca de la herramienta | Texto libre, cada uno escribía lo que quería | Sale de la lista de marcas de Tools |
| Menú Pañol dentro de AssetPlanner | Herramientas, Salida, Entrada, Trazabilidad de componentes | **Oculto.** Todo eso se hace en Tools |

---

## 3. Quién hace qué, y dónde

- **El pañolero** trabaja en **Trazalog Tools**: da de alta herramientas, las asigna al pañol, registra
  entradas (devoluciones) y ve qué está afuera y desde cuándo.
- **El planificador** trabaja en **AssetPlanner**: al armar un preventivo, un predictivo, un backlog o
  una orden de trabajo, declara qué herramientas va a necesitar. Solo puede elegir entre las que
  están disponibles.
- **El técnico** trabaja en **AssetPlanner**: al terminar el trabajo confecciona el informe de servicio
  y marca qué herramientas usó realmente. Ese acto es el que las saca del pañol.
- **El supervisor** revisa y valida el informe en AssetPlanner, y ahí ve las herramientas usadas.

---

## 4. Un caso de uso completo: el preventivo de la chancadora

Sigamos una herramienta —una **llave de impacto neumática**— a lo largo de un preventivo mensual de
una chancadora primaria.

### 4.1 El pañolero prepara el pañol (una sola vez, en Tools)

Al arrancar, en Trazalog Tools se crea **un pañol para la empresa** —lo llamamos "Pañol \<nombre de la
empresa\>"— y el pañolero carga ahí las herramientas: la llave de impacto, con su código, marca y
descripción. Queda en estado **disponible**.

Esto lo hace una vez por cliente, al configurarlo. AssetPlanner no muestra ninguna lista para elegir
pañol: siempre trabaja contra el de la empresa.

### 4.2 El planificador arma el preventivo (AssetPlanner)

**Pantalla:** Mantenimiento → Preventivo → Agregar (o editar uno existente) → pestaña **Herramientas**.

El planificador escribe en el buscador "llave" y el sistema le ofrece las herramientas del pañol que
**hoy están disponibles**, ordenadas por nombre. Elige la llave de impacto, pone la cantidad, y la
agrega a la tabla del preventivo. Lo mismo hace con las demás herramientas que el trabajo requiere.

> Si la llave de impacto estuviera en ese momento afuera del pañol (alguien la sacó para otra OT y no
> la devolvió), **no aparecería en la lista**. Ver duda D2.

Exactamente lo mismo pasa en las otras pantallas donde se declaran herramientas:

- Mantenimiento → **Predictivo** → pestaña Herramientas
- Mantenimiento → **Backlog** → pestaña Herramientas
- Mantenimiento → **Órdenes de trabajo** → al agregar o editar una OT, pestaña Herramientas

### 4.3 Vence el preventivo y se genera la OT (AssetPlanner, automático)

Cuando el preventivo se programa en el calendario y se genera la orden de trabajo, **las herramientas
declaradas en el preventivo se copian a la OT**. Si el preventivo se programa en serie (por ejemplo,
doce meses de una vez), cada OT recibe su copia.

En este paso **el pañol no se toca**: la herramienta sigue disponible. La OT solo dice "para este
trabajo vas a necesitar esto". Es una lista de necesidades, no una reserva.

### 4.4 El técnico ejecuta y confecciona el informe de servicio (AssetPlanner)

**Pantalla:** desde la bandeja de tareas → "Confecciona informe de servicio" → pestaña **Herramientas**.

Terminado el trabajo, el técnico abre el informe. En la pestaña Herramientas tiene un buscador igual
al del preventivo, que ofrece las herramientas **disponibles hoy** en el pañol. Busca "llave", elige
la llave de impacto y la agrega a la tabla "Orden de Herramientas". Repite con cada herramienta que
usó. Las herramientas **no vienen precargadas** desde la OT: el técnico las selecciona una por una
(ver duda D6).

Al **guardar el informe**, el sistema hace dos cosas de una:

1. Guarda en AssetPlanner el informe con su lista de herramientas, como siempre.
2. **Genera un vale de salida en el pañol de Tools** a nombre del técnico que confeccionó el informe,
   con destino "Informe de servicio OT N°…", y marca cada herramienta como **en tránsito**.

Desde ese instante, la llave de impacto **desaparece de los buscadores** de AssetPlanner: ningún
planificador puede declararla en un plan nuevo, ningún técnico puede informarla en otro trabajo, hasta
que vuelva al pañol.

### 4.5 El supervisor revisa y valida el informe (AssetPlanner)

**Pantallas:** "Verifica informe de servicio" y "Presta conformidad", desde la bandeja de tareas.

El supervisor ve el informe con la tabla de herramientas usadas —código, marca, descripción— tal como
las cargó el técnico. Puede aprobarlo o devolverlo para corregir. **La validación no mueve nada en el
pañol**: la herramienta sigue en tránsito.

### 4.6 La herramienta vuelve al pañol (Tools, manual)

Cuando el técnico devuelve la llave de impacto, **el pañolero registra la entrada en Trazalog Tools**.
Recién ahí la herramienta vuelve a estar disponible y reaparece en los buscadores de AssetPlanner.

> **Este paso hoy es 100 % manual y ocurre fuera de AssetPlanner.** AssetPlanner no tiene ninguna
> pantalla ni ningún momento del ciclo (validar el informe, cerrar la OT) que devuelva la herramienta
> solo. Es la principal decisión pendiente: ver duda D1.

---

## 5. Lo que hoy el sistema NO hace (para que no haya sorpresas)

1. **No devuelve herramientas solo.** Si nadie registra la entrada en Tools, la herramienta queda en
   tránsito para siempre y nadie puede volver a declararla.
2. **No reserva al planificar.** Declarar una herramienta en un preventivo no la aparta. Dos OT del
   mismo día pueden declarar la misma llave; la va a poder usar el primero que la informe.
3. **No controla cantidades contra el pañol.** El campo "Cantidad" de los planes sigue existiendo, pero
   en el pañol de Tools cada herramienta es un ítem individual con su estado. Poner "cantidad 3" de
   una misma herramienta no significa nada para el pañol (ver duda D4).
4. **Si Tools no responde en el momento de guardar el informe**, el informe se guarda igual en
   AssetPlanner, pero **el vale no se genera y la herramienta sigue figurando como disponible**. Hoy
   nadie se entera de que eso pasó, salvo revisando registros técnicos (ver duda D7).
5. **Las herramientas de planes viejos** que no existen en el pañol de Tools se muestran como
   "(herramienta N no disponible en tools)". No se rompen los planes, pero esa herramienta no se puede
   volver a usar hasta que el pañolero la cargue en Tools (ver duda D8).
6. **Un solo pañol por empresa.** No hay forma, desde AssetPlanner, de trabajar con más de un pañol
   (ver duda D3).

---

## 6. Dudas para resolver con el Product Owner

**D1 — ¿Cuándo vuelve la herramienta al pañol?** Hoy solo cuando el pañolero registra la entrada en
Tools. Alternativas: (a) que siga siendo siempre manual del pañolero, que es lo más parecido a un
pañol real con vale de ida y vuelta; (b) que AssetPlanner la devuelva sola cuando el supervisor
valida el informe; (c) que la devuelva al cerrar la OT. La (a) es la más fiel al control físico; la
(b) y la (c) son más cómodas pero hacen que el sistema diga "volvió" sin que nadie la haya visto
volver.

**D2 — ¿Los planes deben ofrecer solo lo disponible hoy?** Un preventivo que se va a ejecutar dentro
de tres meses hoy solo puede declarar herramientas que **en este momento** están en el pañol. Si la
llave de impacto está afuera hoy, no se puede planificar con ella para el mes que viene. ¿Es lo
deseado, o los planes deberían ver el catálogo completo y que el filtro de disponibilidad aplique solo
al informe de servicio (que es donde la herramienta efectivamente sale)?

**D3 — ¿Un solo pañol por empresa alcanza?** En una operación minera con varios frentes o varias
plantas es habitual tener más de un pañol. Hoy AssetPlanner trabaja contra uno solo, fijado al
configurar el cliente. ¿Hay clientes en la mira que necesiten varios?

**D4 — ¿Qué hacemos con el campo "Cantidad"?** En el pañol de Tools cada herramienta es un ítem con
estado (disponible / en tránsito). La cantidad del plan no dialoga con eso. Opciones: sacar el campo,
dejarlo solo como dato informativo, o modelar en Tools herramientas "de stock" (consumibles tipo
discos de corte) distintas de las "de inventario" (una llave con número de serie).

**D5 — ¿Quién figura como responsable del vale?** Hoy el vale se genera a nombre del usuario que
confecciona el informe y con destino "Informe de servicio OT N°". ¿Es suficiente, o hace falta
registrar el operario real que se llevó la herramienta, el turno, o el equipo?

**D6 — ¿El informe debería precargar las herramientas declaradas en la OT?** Hoy el técnico las busca
y agrega una por una, aunque el plan ya las tuviera declaradas. Precargarlas ahorra trabajo, pero
puede llevar a que se "informen" herramientas que en realidad no se usaron.

**D7 — Si el vale no se pudo generar, ¿avisamos?** Hoy el informe se guarda y el error queda solo en
registros técnicos. ¿Debería avisarle al técnico, bloquear el guardado, o generar una lista de
"vales pendientes" para que el pañolero regularice?

**D8 — Herramientas históricas.** Un cliente real (Caleras San Juan) tiene 2 herramientas y un puñado
de referencias en OT viejas. ¿Las cargamos a mano en el pañol de Tools al migrarlo, o dejamos el
histórico como está y arrancan de cero?

**D9 — Trazabilidad de componentes.** El menú "Trazabilidad de componentes" de AssetPlanner quedó
oculto junto con el resto del Pañol. ¿Alguien lo usaba? ¿Tiene que existir en Tools?

> Las secciones 7 y 8 traen una respuesta propuesta para casi todas estas dudas. Están separadas a
> propósito: lo de arriba es **cómo está hoy**; lo de abajo es **cómo creemos que debería estar**.

---

## 7. Qué dicen las buenas prácticas del rubro

Miramos cómo resuelven esto los sistemas de mantenimiento de referencia (SAP PM e IBM Maximo, que son
los que se encuentran en la gran minería), qué dice la literatura de planificación de mantenimiento
(el manual de Doc Palmer, que es el estándar de la disciplina) y qué exigen las normas de calidad. Las
cuatro ideas que se repiten en todos lados:

### 7.1 Las herramientas son un recurso que se planifica, igual que los repuestos

En SAP y en Maximo la herramienta se asigna **a cada tarea del plan de trabajo**, al lado de los
materiales, los planos y los instrumentos. Y los dos sistemas separan con claridad dos listas: lo
**planificado** (lo que el planificador dijo que iba a hacer falta) y lo **real** (lo que
efectivamente se usó, con horas y costo). Son dos datos distintos y se guardan por separado.

### 7.2 El planificador entrega un paquete completo — y ahí está la plata

Doc Palmer lo dice sin vueltas: el planificador entrega materiales, **lista de herramientas**,
procedimientos, planos, historia del equipo, tiempos y dotación. Y la práctica de *kitting*
(preparar la caja) pre-arma repuestos, herramientas y consumibles **antes de que la OT entre al
programa**. El motivo es el tiempo de llave en mano: que el técnico no pierda media mañana yendo y
viniendo del pañol porque le faltó algo.

### 7.3 El pañol es un circuito de custodia propio, con vale de ida y vuelta

La práctica de pañol (*tool crib*) es simple y universal: **salida con persona responsable, fecha
esperada de devolución y OT asociada**; **entrada con estado de la herramienta** — si vuelve dañada,
se genera su propia orden de reparación. Cada herramienta lleva su historia: quién la tuvo, cuándo,
para qué trabajo. Esto existe para evitar pérdidas y el "acaparamiento" entre turnos (la llave que
cada cuadrilla se guarda "por si acaso"), y para saber qué tiene cada persona cuando cambia de puesto
o se va de la empresa.

Nota importante: **el vale es una transacción del pañol, no un dato del informe de servicio**. El
informe es donde el técnico cuenta qué hizo; el pañol es donde se controla qué salió y qué volvió.
Son dos momentos y dos responsables distintos.

### 7.4 Los instrumentos calibrados tienen una exigencia extra

Torquímetros, manómetros, multímetros: la norma de calidad (ISO 9001, punto 7.1.5) pide calibrarlos a
intervalos, con trazabilidad a patrones, y algo que suele olvidarse: **si un instrumento aparece
descalibrado, hay que revisar si los trabajos anteriores quedaron afectados**. Eso solo se puede
hacer si se sabe **en qué OT se usó ese instrumento en particular** (por su número de serie), no "un
torquímetro cualquiera".

### 7.5 Entonces, ¿para qué registrar qué herramientas se usaron?

| # | Objetivo | Qué dato hace falta | A quién le sirve |
|---|---|---|---|
| 1 | **Preparar el trabajo** — que el técnico llegue al equipo con todo | *Tipo* de herramienta y cantidad, por tarea | Planificador, pañolero |
| 2 | **Custodia y control de pérdidas** — quién tiene qué, desde cuándo, para qué OT | *Herramienta física* (código o serie), responsable, fecha, OT | Pañolero, supervisor |
| 3 | **Trazabilidad de calidad** — si un torquímetro salió descalibrado, qué trabajos revisar | Serie + fecha de calibración vigente al momento del uso, por OT | Calidad, confiabilidad |
| 4 | **Costeo real del trabajo** — incluyendo equipos alquilados o de alto valor | Horas de uso × tarifa por herramienta | Gerencia |
| 5 | **Mantenimiento de la propia herramienta** — disparar su revisión por uso | Cantidad de usos u horas por herramienta | Pañolero |

La conclusión que ordena todo lo demás: **el dato "real" de qué herramientas se usaron sale del vale
del pañol, no de la memoria del técnico al llenar el informe.** Un informe donde el técnico elige a
mano de una lista es el dato menos confiable de todos, y no sirve ni para el control de pérdidas
(objetivo 2) ni para la trazabilidad de calidad (objetivo 3).

---

## 8. Cómo proponemos que quede

Tres capas, cada una con su dueño, su momento y su pantalla.

### 8.1 Planificación — se declaran *tipos* de herramienta, no herramientas físicas (AssetPlanner)

En el preventivo, el predictivo, el backlog y la OT se declara **qué tipo de herramienta** hace falta
y **cuántas**: "2 llaves de impacto 3/4", "1 torquímetro 200–1000 Nm". Se elige del **catálogo
completo** de tipos de Tools, **sin filtrar por disponibilidad**: un plan que se va a ejecutar dentro
de tres meses no tiene por qué saber qué está prestado hoy. La cantidad tiene sentido en esta capa,
porque es de tipo.

Al generar la OT se copia esa lista, como pasa hoy. Es la "lista de necesidades" del trabajo.

### 8.2 Custodia — el vale contra la OT, con herramientas físicas (Tools, pañol)

Cuando la OT se programa o se asigna, el pañolero —o el propio técnico, en autoservicio desde el
celular— hace el **vale de salida contra esa OT**: ve la lista de tipos que la OT necesita y
**entrega herramientas físicas concretas** que la cubren: la llave HERR-0231, el torquímetro TQ-014.
El vale registra responsable, fecha, fecha esperada de devolución y número de OT. Esas herramientas
pasan a "en tránsito".

La **devolución es una entrada contra el mismo vale**, marcando el estado de cada herramienta: en
condiciones / dañada (genera una orden de reparación de la herramienta) / faltante. **Nunca es
automática**: alguien tiene que ver la herramienta volver — eso es exactamente lo que se está
controlando.

Regla de cierre: **la OT no se cierra mientras tenga vales abiertos** (o, como mínimo, avisa). Así la
devolución no queda en el olvido.

Los **consumibles** (discos de corte, electrodos, trapos, mechas) **no van por pañol: son materiales
de Almacén** y se piden como insumo de la OT, igual que un repuesto. Con eso desaparece el problema
de "cantidad" dentro del pañol.

### 8.3 Informe de servicio — muestra el real, no lo vuelve a preguntar (AssetPlanner)

El informe **trae precargadas las herramientas del vale de esa OT** — código, serie y, para los
instrumentos calibrados, la fecha de calibración vigente — y a lo sumo permite marcar "no se usó" o
agregar una excepción. El técnico no vuelve a buscar herramientas en una lista. El supervisor ve en
una sola tabla **planificado / entregado / usado**.

### 8.4 Cómo queda la chancadora con este esquema

Retomando el caso del §4: el planificador declara en el preventivo "1 llave de impacto 3/4" (tipo).
Vence, se genera la OT con esa necesidad. El día del trabajo el pañolero abre la OT en Tools, ve la
necesidad y entrega la HERR-0231 con vale a nombre del técnico, devolución esperada al fin del turno.
El técnico trabaja. Al confeccionar el informe, la HERR-0231 ya figura; solo confirma. Al terminar el
turno devuelve la llave; el pañolero la ingresa contra el vale, "en condiciones". La OT puede cerrarse.
Si el técnico no la devuelve, la OT no cierra y el supervisor lo ve al día siguiente.

### 8.5 Cómo responde esto a las dudas del §6

| Duda | Lo que propone esta práctica |
|---|---|
| D1 ¿cuándo vuelve? | Siempre por entrada contra el vale, registrada por quien la recibe. Nunca al validar el informe ni al cerrar la OT — al revés: la OT **no cierra** con vales abiertos |
| D2 ¿planes solo con lo disponible? | No. Los planes eligen *tipos* del catálogo completo. La disponibilidad se resuelve en el vale, el día del trabajo |
| D3 ¿un solo pañol? | El vale se hace contra el pañol que entrega; un mismo cliente puede tener varios. Es un cambio de configuración, no de circuito |
| D4 cantidad | Es propiedad del *tipo* en el plan. En el vale son herramientas individuales. Los consumibles van por Almacén |
| D5 responsable | El técnico que retira, registrado en el vale; no quien confecciona el informe |
| D6 ¿precargar en el informe? | Sí, desde el vale — es el dato real |
| D7 fallo silencioso | Desaparece: el vale es una operación propia del pañol en Tools, no un efecto de guardar un informe |
| D8 histórico | Las 2 herramientas de Caleras se cargan en el pañol como herramientas físicas; el histórico de OT viejas queda como está |
| D9 trazabilidad de componentes | Es un circuito distinto (componentes de equipos, no herramientas). Se decide aparte |

### 8.6 Qué implica respecto de lo que ya está construido

Sin vueltas: **lo construido hasta ahora puso el vale en el lugar equivocado**. Hoy el vale nace al
guardar el informe de servicio, a nombre de quien lo confecciona, y el filtro de disponibilidad se
aplica a los planes. La práctica del rubro dice lo inverso: el vale nace en la ejecución de la OT
(capa 2, en el pañol de Tools), los planes ven el catálogo completo, y el informe lee el vale.

Nada de lo construido se tira: el catálogo compartido, los estados disponible / en tránsito, las
operaciones de salida y entrada del pañol ya existen y son justamente las piezas de este esquema. Lo
que cambia es **el orden y el dueño de cada paso**. Y coincide con lo que se está desarrollando ahora
en Tools para el módulo de herramientas, así que conviene ver eso antes de decidir el detalle.

---

## 9. Un aviso sobre el estado del código

Todo esto está desarrollado, probado en el ambiente de desarrollo con datos reales y guardado en la
línea de trabajo nueva de AssetPlanner (`develop-v3`). **No está en la línea de producción**, y en la
línea actual de Trazalog Tools se están desarrollando en paralelo mejoras al módulo de herramientas
que habrá que incorporar antes de cerrar esta integración. Las respuestas a las dudas del §6 —y si
se adopta o no el esquema del §8— definen qué se desarrolla a continuación.

---

## Fuentes consultadas para los §7 y §8

- SAP Help — [Production Resources and Tools](https://help.sap.com/docs/SAP_S4HANA_ON-PREMISE/79e86803745943368f3beb4a7d0bca2a/f4ddba53422bb54ce10000000a174cb4.html) y [Allocating Production Resources and Tools](https://help.sap.com/docs/SAP_S4HANA_ON-PREMISE/e72f747389b340229f7fa343975bfa57/49ee484a3c704e08a585a3506188bde9.html)
- IBM Maximo — [Actual tool use on work orders](https://www.ibm.com/docs/en/maximo-eam-saas?topic=orders-actual-tool-use-work), [Actual tool cost on a work order](https://www.ibm.com/support/pages/maximo-support-desk-actual-tool-cost-work-order), [Tools and Stocked Tools applications](https://www.ibm.com/support/pages/maximo-support-desk-tools-and-stocked-tools-applications)
- Doc Palmer — [Maintenance Planning and Scheduling Handbook, 4ª ed.](https://www.accessengineeringlibrary.com/content/book/9781260135282) ([reseña](https://accendoreliability.com/review-maintenance-planning-scheduling-handbook-doc-palmer/))
- [Parts kitting para planificadores de mantenimiento](https://mpulsesoftware.com/blog/cmms/parts-kitting-maintenance/)
- Pañol / tool crib: [UpKeep](https://upkeep.com/product/tool-tracking/), [Reftab](https://www.reftab.com/blog/the-ultimate-guide-to-tool-management), [EZOfficeInventory](https://ezo.io/ezofficeinventory/blog/tool-room-management-software-overview/)
- ISO 9001:2015 §7.1.5 — [trazabilidad de la medición](https://blog.auditortrainingonline.com/blog/iso-9001-7-1-5-2-measurement-traceability), [cláusula explicada](https://www.thecoresolution.com/clause-7-1-5-iso-9001-explained), [gestión de calibración en CMMS](https://micromain.com/calibration-management-cmms/)
