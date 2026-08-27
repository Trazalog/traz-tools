# KPIs de mantenimiento — consultas a Ingeniería

## Objetivo

Este documento reúne **hallazgos y dudas sobre cómo Asset Planner calcula los KPIs de
mantenimiento** (Disponibilidad, MTTR, MTBF/MTTF y cantidad de fallas), para revisarlos con los
ingenieros de mantenimiento de Tierra Capayán.

Está escrito para un **especialista en mantenimiento**, no para un programador: describe *qué
hace el sistema* y *qué supuestos toma*, no cómo está implementado. La mayoría de los puntos no
son errores confirmados — son **decisiones de criterio** que sólo un ingeniero del área puede
validar.

Cada punto trae: qué hace hoy el sistema, qué dice la práctica habitual de la industria, y la
pregunta concreta que necesitamos responder.

**Alcance.** No cubre el uso del sistema ni el módulo de almacenes. Los KPIs analizados son los
del tablero *Mantenimiento → KPIs* de Asset Planner.

| | |
|---|---|
| **Fecha** | 2026-08-15 |
| **Verificado contra** | Base de **producción** (Tierra Capayán, ene-2024 a jul-2026) y código fuente del sistema |
| **Estado** | Para revisión de Ingeniería — **no se modificó ningún cálculo** |

---

## 1. Cómo mide el sistema, en criollo

Antes de los hallazgos, conviene entender el mecanismo, porque de ahí salen casi todas las dudas.

El sistema **no** registra "paradas" ni "fallas" como eventos con inicio y fin. Lo que registra
son **lecturas**: cada vez que alguien toma una lectura de un equipo (horómetro, kilometraje, o
simplemente una verificación), queda un registro con **la fecha** y **el estado en que quedó el
equipo**.

Los estados que aparecen en los datos son:

| Estado | Significado asumido |
|---|---|
| `AC` | Activo / operativo |
| `RE` | En reparación |
| `IN` | *(ver duda D)* |
| `AN` | Anulado |

A partir de esa secuencia de lecturas, el sistema **arma tramos**: cada lectura abre un período
que se cierra cuando llega la lectura siguiente de ese mismo equipo. Si una lectura dice `AC` y la
siguiente llega 8 días después, el sistema entiende que el equipo estuvo operativo 8 días.

```
Lectura 1        Lectura 2        Lectura 3
  AC   ─────────►  RE   ────────►   AC   ─────────►
  |    8 días      |    6 horas     |
  operativo        en reparación    operativo
```

Sobre esos tramos se calcula todo:

| KPI | Cómo se obtiene |
|---|---|
| **Disponibilidad** | tiempo en `AC` ÷ tiempo total × 100 |
| **MTTR** | tiempo en `RE` ÷ cantidad de tramos `RE` |
| **MTBF/MTTF** | tiempo en `AC` ÷ cantidad de tramos `RE` |
| **Cantidad de fallas** | cantidad de tramos `RE` |

**Consecuencia importante:** la calidad de los KPIs depende enteramente de que las lecturas se
tomen con regularidad y con el estado correcto. Si un equipo pasa tres meses sin lecturas, el
sistema asume que estuvo todo ese tiempo en el último estado registrado.

---

## 2. Lo que está bien

**La Disponibilidad está correctamente calculada.** Lo verificamos contra la base de producción:
el cálculo descarta los registros inconsistentes antes de sumar, y el valor que muestra el tablero
es el mismo que da un cálculo independiente. Para el período analizado dio **99,74%**.

La fórmula coincide con la estándar de la industria — *disponibilidad = tiempo operativo ÷
(tiempo operativo + tiempo fuera de servicio)*.

**Con una salvedad importante**, que desarrollamos en la sección siguiente: el cálculo es correcto,
pero opera sobre un historial donde figuran sólo 4 reparaciones. La aritmética está bien; lo que
hay que revisar es si los datos de entrada reflejan la operación real.

---

## 3. El hallazgo principal: 4 reparaciones registradas en dos años y medio

Todo lo demás de este documento es secundario frente a esto.

Contamos las lecturas de la empresa en la base de producción, agrupadas por el estado en que
quedó el equipo:

| Estado | Lecturas registradas |
|---|---|
| `AC` — activo | **24.421** |
| `IN` — *(ver duda D)* | 76 |
| `RE` — en reparación | **4** |

**Cuatro.** En el período completo analizado (enero 2024 a julio 2026), en toda la flota.

**Por qué esto importa tanto.** Los tres indicadores dependen de ese número:

| KPI | Cómo lo usa |
|---|---|
| **Cantidad de fallas** | es ese número |
| **MTTR** | tiempo en reparación ÷ **4** |
| **MTBF/MTTF** | tiempo operativo de toda la flota ÷ **4** |
| **Disponibilidad** | el 99,74% sale de que casi no hay tiempo en `RE` |

Es decir: **el MTTR se calcula sobre 4 eventos, y el MTBF divide el tiempo operativo acumulado de
toda la flota por esos mismos 4**. El 99,74% de disponibilidad no dice tanto "los equipos casi no
paran" como "casi no hay paradas *registradas*".

**Y acá está la prueba de que no fueron 4 paradas reales.** Contamos, en el mismo período y para la
misma empresa, cuántas solicitudes de reparación se cargaron en el sistema:

| | |
|---|---|
| Solicitudes de reparación registradas | **17.372** |
| Equipos puestos en estado "en reparación" | **4** |

**Diecisiete mil trescientas setenta y dos solicitudes, contra cuatro cambios de estado.**

El trabajo de mantenimiento **sí se está registrando** —y con muchísimo detalle— pero pasa por el
circuito de solicitudes y órdenes de trabajo, no por el estado del equipo. Los KPIs, en cambio,
miran **exclusivamente el estado del equipo**. Están leyendo el 0,02% de la actividad.

> **Esto no es un error de ustedes ni de cómo usan el sistema.** Nadie debería tener que marcar dos
> veces la misma cosa. Es una decisión de diseño del cálculo: los KPIs se construyeron sobre el
> historial de estados en lugar de sobre las órdenes de trabajo, que es donde realmente está la
> información.

**Consecuencia práctica: los valores de MTTR, MTBF y cantidad de fallas que hoy muestra el tablero
no representan la operación real, y no se arreglan ajustando la fórmula.** Hay que reconstruirlos a
partir de las órdenes de trabajo.

> **Preguntas para Ingeniería:**
> 1. **¿Cuál es el circuito real cuando un equipo se detiene por una falla?** ¿Se carga una
>    solicitud de reparación, se genera una OT, ambas? ¿En qué momento se considera que el equipo
>    volvió a servicio?
> 2. **¿De qué dato deberíamos tomar el inicio y el fin de una parada?** Necesitamos identificar en
>    la OT qué campo marca "el equipo salió de servicio" y cuál "volvió a operar".
> 3. **¿Toda solicitud de reparación implica que el equipo estuvo detenido?** Suponemos que no —
>    muchas serán tareas menores sin parada. Necesitamos saber cómo distinguirlas.

**Un obstáculo que ya detectamos.** El campo que debería distinguir correctivo de preventivo
(`correctivo`) está **vacío en las 17.372 solicitudes**. Con lo cual hoy, desde los datos, no
podemos separar una falla de un mantenimiento programado. Esa es la primera pieza que necesitamos
resolver con ustedes.

---

## 4. Hallazgos y dudas

### A · MTTR y MTBF no descartan los registros inconsistentes (hallazgo técnico)

**Qué encontramos.** El cálculo de Disponibilidad ignora los tramos imposibles — aquellos donde la
lectura de cierre resulta anterior a la de apertura, algo que ocurre cuando una lectura se carga
con fecha retroactiva. **MTTR y MTBF no aplican ese descarte**, y suman esos tramos con duración
negativa.

**Evidencia en producción.** El MTBF calculado sobre los datos reales de la empresa da un valor
**negativo**. Un tiempo medio entre fallas negativo no tiene interpretación física posible: es la
prueba directa de que se están sumando duraciones negativas.

**El valor concreto: −53.328.934.**

El volumen es mucho mayor de lo que suponíamos al principio, y separamos las dos causas posibles:

| Causa | Tramos | |
|---|---|---|
| Fecha imposible (año 0001, 2092, vacía) | **12** | dato mal cargado |
| **Fin anterior al inicio** | **4.724** | **error de cálculo** |
| Total de tramos cerrados | 20.868 | **22,6% inconsistente** |

**No es un problema de datos: son doce registros mal cargados contra 4.724 tramos que el propio
cálculo construye mal.**

La causa es concreta. El cálculo cierra cada tramo con **la lectura siguiente por número de
registro**, no por fecha. Cuando dos lecturas del mismo equipo se cargaron en distinto orden del
que ocurrieron —normal al regularizar cargas atrasadas— el "fin" queda antes que el "inicio" y la
duración sale negativa.

Es una línea de código: ordenar por fecha en lugar de por número de registro. **Eso solo recupera
el 22,6% de los datos**, y es independiente de todo lo demás que discute este documento.

**La Disponibilidad descarta esos 4.722 tramos y aun así da 99,74%. MTTR y MTBF no los descartan.**

> **Esto no requiere criterio de ingeniería: es un defecto y hay que corregirlo.** Lo listamos
> para que sepan que los valores de MTTR/MTBF de períodos que incluyan esos registros pueden estar
> distorsionados.

**Pregunta:** ¿han notado valores de MTTR o MTBF que les parecieran inexplicables en algún mes en
particular?

---

### B · La unidad de tiempo: ¿el MTBF está expresado en horas?

**Qué encontramos.** El sistema mide la duración de cada tramo en minutos y luego **divide por 24**
para expresarla en la unidad que rotula como "horas". Para convertir minutos a horas hay que
dividir por 60.

Si la intención era expresar **horas**, los valores mostrados estarían **2,5 veces por encima** del
valor real. Si la intención era expresar **días**, faltaría dividir además por 60.

**Por qué importa.** En la Disponibilidad esto no afecta nada: es un porcentaje, y el factor se
cancela arriba y abajo de la división. Pero MTTR y MTBF se informan como una **cantidad de horas**,
y ahí el factor sí queda.

**El número concreto, medido en producción.** Sobre el período completo, el MTTR que produce el
cálculo actual es **0,21** — es decir, el sistema informa que el tiempo medio de reparación es de
unos **13 minutos**. Depurando los tramos inconsistentes sube a 20,25, y convirtiendo correctamente
minutos a horas queda en **8,10 horas**.

| MTTR | Valor |
|---|---|
| Como lo calcula hoy el sistema | **0,21** (≈13 minutos) |
| Descartando tramos inconsistentes | 20,25 |
| Además con la conversión correcta a horas | **8,10 horas** |

Un tiempo medio de reparación de 13 minutos no es creíble para equipos de esta clase. Las 8,1 horas
sí lo son.

En el tablero, el **MTBF ronda las 580 horas**. Si el factor está equivocado, el valor real sería
de unas **232 horas**.

> **Importante:** en el caso del MTBF, corregir la unidad y los tramos negativos **no alcanza**.
> Depurado y convertido correctamente, el valor del período completo da **8.115.231 horas — unos
> 926 años entre fallas**. No es un error de aritmética: es la consecuencia de dividir el tiempo
> operativo de toda la flota por 4 fallas. Mientras el denominador salga del historial de estados,
> ningún ajuste de fórmula va a producir un MTBF con sentido.

**Contraste con la práctica de la industria.** Para equipos críticos se considera *world-class* un
**MTTR menor a 4 horas**. Un MTBF de referencia depende mucho del tipo de activo.

> **Pregunta clave para Ingeniería:**
> Mirando sus equipos y su operación, **¿cuál de los dos números les resulta creíble: un tiempo
> medio entre fallas de ~580 horas (≈24 días) o de ~232 horas (≈10 días)?**
>
> Y para el MTTR: ¿los tiempos de reparación que ven en el tablero se parecen a los reales que
> miden en la práctica, o están sistemáticamente altos?

Su respuesta define si hay que corregir la unidad o no.

---

### C · ¿Qué cuenta como "una falla"?

**Qué hace hoy el sistema.** Cada lectura registrada con estado `RE` cuenta como **una falla**.

**El problema potencial.** Si durante una reparación larga alguien toma tres lecturas del equipo
—todas con estado `RE`, porque sigue en reparación— el sistema contabiliza **tres fallas** donde
para ustedes hubo **una sola parada**.

Eso afecta a los tres indicadores a la vez:
- **Cantidad de fallas**: sobre-cuenta
- **MTTR**: se subestima (el mismo tiempo total dividido por más eventos)
- **MTBF**: se subestima (mismo tiempo operativo dividido por más eventos)

**Qué medimos en producción.** De las 4 lecturas `RE`, **1 viene precedida por otra `RE`** (25%).
Con una muestra de 4 el porcentaje no es estadísticamente significativo, pero confirma que el
fenómeno existe: al menos una de las cuatro "fallas" que informa el tablero es, casi con seguridad,
la continuación de otra.

Con tan pocos eventos, **una sola lectura duplicada mueve el MTTR y el MTBF un 25%**.

**Contraste con la práctica.** La definición estándar es *MTTR = tiempo total fuera de servicio ÷
número de **incidentes***, y *MTBF = tiempo operativo total ÷ número de **fallas***. En ambos casos
la unidad de conteo es el **evento de parada**, no cada registro administrativo.

> **Pregunta para Ingeniería:**
> Cuando un equipo está varios días en reparación, **¿toman lecturas intermedias mientras dura la
> intervención?** Si es así, ¿esas lecturas quedan con estado "En reparación"?
>
> Y conceptualmente: **¿una falla es el evento de parada (desde que sale de servicio hasta que
> vuelve), o cada registro que se hace durante la intervención?**

---

### D · El estado "IN" — ¿qué representa?

**Qué encontramos.** Además de `AC` (activo) y `RE` (en reparación), en los datos aparece un tercer
estado, **`IN`**, con volumen significativo (26 de 97 lecturas en la muestra de desarrollo).

Hoy ese estado **no se cuenta como operativo ni como reparación**: entra en el tiempo total (y por
lo tanto baja la disponibilidad) pero no suma al tiempo de reparación ni cuenta como falla.

**Por qué preguntamos.** La práctica habitual distingue **parada planificada** de **parada por
falla**, porque se corrigen con acciones muy distintas: una parada programada para un preventivo no
debería computarse igual que una rotura imprevista. La disponibilidad estándar incluye todo el
tiempo fuera de servicio, pero se recomienda **poder separar ambos conceptos** en el análisis.

> **Preguntas para Ingeniería:**
> 1. **¿Qué significa `IN` en su operación?** ¿Inactivo, fuera de servicio programado, dado de
>    baja, en tránsito? *(Sabemos que lo genera el sistema al cambiar el estado de un equipo —
>    ver G-bis — pero no qué representa para ustedes.)*
> 2. **¿Un equipo en estado `IN` debería contar como "no disponible"?** (hoy cuenta así)
> 3. ¿Les serviría poder ver la disponibilidad **separando** parada planificada de parada por
>    falla?

---

### E · MTBF o MTTF: no son lo mismo

**Qué encontramos.** El tablero rotula el indicador como **MTBF**, pero internamente el cálculo
está nombrado como **MTTF**. Son métricas distintas:

| Métrica | Se usa para | Qué mide |
|---|---|---|
| **MTBF** (*Mean Time Between Failures*) | Equipos **reparables** | Tiempo promedio **entre** fallas sucesivas |
| **MTTF** (*Mean Time To Failure*) | Componentes **no reparables** (se reemplazan) | Tiempo promedio **hasta** la falla |

La relación canónica es **MTBF = MTTF + MTTR**.

Lo que el sistema calcula (*tiempo operativo ÷ cantidad de fallas*) corresponde a la fórmula de
MTBF para equipos reparables, que es el caso de sus activos. Así que **el rótulo del tablero
parece correcto** y el nombre interno sería el desactualizado.

> **Pregunta para Ingeniería (de validación, no de corrección):**
> Cuando le presentan este indicador a su cliente, **¿lo presentan como "tiempo medio entre
> fallas"?** ¿Y esperan que ese tiempo incluya o excluya las horas que el equipo estuvo en
> reparación?
>
> Lo consultamos porque, según la definición estándar, el MTBF incluye el tiempo de reparación
> (MTBF = MTTF + MTTR) y el cálculo actual **no lo incluye** — sólo suma tiempo operativo. La
> diferencia es pequeña si las reparaciones son cortas, pero conviene dejarlo explícito.

---

### F · Los indicadores de un mes cerrado cambian según cuándo se consulten

**Medido en producción:** hay **3.631 tramos sin cerrar** — lecturas que nunca tuvieron una lectura
posterior del mismo equipo. La más antigua es de **agosto de 2024**, y en promedio arrastran
**438 días** hasta hoy. MTTR y MTBF cierran esos tramos con la fecha de *hoy*, así que cada uno
aporta más tiempo cada día que pasa.

**Qué encontramos.** Cuando un equipo tiene una lectura sin lectura posterior que la cierre (por
ejemplo, la última lectura tomada), el sistema necesita decidir hasta cuándo se extiende ese tramo.
Para la Disponibilidad usa **el fin del período consultado**; para MTTR y MTBF usa **la fecha de
hoy**.

**Consecuencia.** Si consultan el MTBF de julio durante agosto y lo vuelven a consultar en
septiembre, **el número cambia**, aunque julio ya esté cerrado y no se haya cargado ningún dato
nuevo.

En desarrollo encontramos 9 tramos abiertos, el más antiguo de junio de 2023 — es decir, un tramo
que hoy suma **más de 700 días** de duración a los promedios.

> **Pregunta para Ingeniería:**
> **¿Esperan que el KPI de un mes ya cerrado sea un número fijo?** Si presentan un informe mensual
> al cliente y el mes siguiente vuelven a mirar el mismo período, ¿debería dar idéntico?
>
> Y una consulta operativa relacionada: **¿es habitual que un equipo quede sin lecturas por mucho
> tiempo?** Si un equipo deja de reportar, hoy el sistema asume que sigue en el último estado
> conocido indefinidamente.

---

### G-bis · De dónde salen las lecturas y qué valida el sistema

*(Sección agregada tras revisar el código de Asset Planner, a pedido del PM.)*

Revisamos **todos** los caminos por los que se crea una lectura. Son cinco, y se comportan muy
distinto entre sí:

| # | Cuándo ocurre | Fecha que usa | Lectura que guarda | Estado |
|---|---|---|---|---|
| 1 | **Alta de un equipo** | fecha y hora del servidor ✅ | **0** (fija) | `AC` |
| 2 | **Cambio de estado del equipo** | fecha y hora del servidor ✅ | **0** (fija) | **`IN`** |
| 3 | **Carga con lectura real** | fecha y hora del servidor ✅ | la que se ingresa | la que corresponda |
| 4 | **Verificación del informe de servicio** | la del **informe de la OT** ⚠️ | horómetro final del informe | el del equipo |
| 5 | **Verificación masiva de informes** | `fecha_terminada` de la **OT** ⚠️ | horómetro final | **`AC` (fijo)** |

**Tres conclusiones de esto:**

**1. Las fechas inválidas vienen sólo de los caminos 4 y 5.** Los tres primeros usan la fecha del
servidor, que siempre es válida. Los caminos 4 y 5 copian la fecha que tiene cargada la orden de
trabajo, **sin ninguna validación**: no se verifica que exista, que sea una fecha real, ni que no
sea futura. Si la OT tiene la fecha vacía, la lectura se guarda con fecha vacía.

Verificamos en la base: **802 de 966 órdenes de trabajo tienen la fecha de finalización vacía**
(son OTs que nunca se cerraron formalmente). Si la verificación masiva procesa una de ésas, genera
una lectura con fecha inválida.

**2. El estado `IN` se genera automáticamente al cambiar el estado de un equipo** (camino 2). No es
algo que el operario elija en un formulario de lectura: lo pone el sistema.

**3. Muchas lecturas se guardan con el valor `0`.** Los caminos 1 y 2 fijan `lectura = 0` porque no
son lecturas de horómetro: son **marcadores de un cambio de estado**. El problema es que quedan
mezcladas en el mismo historial que las lecturas reales, y el sistema no las distingue.

Esto explica algo que nos había llamado la atención: el campo "última lectura" de varios equipos
figura en **0**, aunque el historial tenga valores reales de horómetro. Es porque el último
registro fue un marcador de estado, no una medición.

> **Preguntas para Ingeniería:**
> 1. **¿Usan la "verificación masiva" de informes de servicio?** Es la que cierra varias OTs juntas.
>    Si la usan seguido, es la principal fuente de fechas inválidas.
> 2. Cuando cierran una OT, **¿siempre completan la fecha de finalización y el horómetro final?**
>    ¿O a veces se saltea ese paso?
> 3. **¿Les resulta útil que un cambio de estado genere una "lectura" con valor 0?** ¿O preferirían
>    que el historial de lecturas tuviera sólo mediciones reales, y los cambios de estado se
>    registraran aparte?

La pregunta 3 es de fondo: hoy el historial mezcla dos cosas distintas —mediciones de uso y
cambios de estado— y los KPIs se calculan sobre esa mezcla.

---

### G · Registros con fechas inválidas generados desde las órdenes de trabajo

**Qué encontramos.** En producción hay **7 lecturas con fechas imposibles**: años 0001, 0025, 2092,
y algunas vacías. Todas tienen una observación con el formato `"Descripción: … | OT: NNNN"`, lo que
indica que **fueron generadas automáticamente desde el flujo de órdenes de trabajo**, no cargadas a
mano por un operario.

Ejemplos reales:

| Equipo | Fecha registrada | Observación |
|---|---|---|
| C11-300-PAS | 0001-01-01 | *Realizar 3 copias de llave del piso c11* |
| FASE 7 | 2092-02-02 | *FASE 7: Comedor-Baños-Sala Star* |
| B1-321-HAB-SV | 0025-03-30 | *Extractor no funciona* |
| COC-AM | *(vacía)* | *Trasladar leña* |

Son pocos registros sobre un total grande, pero **se siguen generando**: mientras no se corrija el
origen, van a seguir apareciendo.

> **Preguntas para Ingeniería:**
> 1. Al cerrar o gestionar una OT, **¿el sistema les pide una lectura del equipo?** ¿Es un campo
>    obligatorio, opcional, o se completa solo?
> 2. ¿Recuerdan haber visto un formulario donde la fecha viniera vacía o con un valor raro?
>
> Esto nos ayudaría a ubicar en qué pantalla se originan.

---

### H · Una observación sobre el valor de disponibilidad

La disponibilidad de **99,74%** está por encima del *world-class* de la industria, que se ubica en
**90-95%** para la mayoría de las operaciones.

Eso puede significar dos cosas muy distintas: que la gestión de mantenimiento es efectivamente
excelente, o que hay tiempo fuera de servicio que no se está registrando como tal — por ejemplo, si
un equipo se repara pero nadie carga la lectura con estado `RE`, para el sistema nunca dejó de
estar operativo.

> **Pregunta para Ingeniería:**
> **¿Ese 99,74% coincide con su percepción de la operación?** ¿Dirían que sus equipos están
> disponibles prácticamente todo el tiempo, o sienten que hay paradas que el sistema no está
> capturando?
>
> Es la pregunta más importante del documento: si el número no refleja la realidad, el problema no
> está en el cálculo sino en la captura del dato, y eso se resuelve de otra manera.

---

## 5. Resumen de lo que necesitamos

| # | Tema | Qué necesitamos de Ingeniería |
|---|---|---|
| **★** | **17.372 solicitudes vs 4 cambios de estado — los KPIs leen el 0,02% de la actividad** | **¿Cuál es el circuito real ante una falla? ¿Qué campo de la OT marca inicio y fin de parada?** |
| **★★** | **El campo `correctivo` está vacío en las 17.372 solicitudes** | **¿Cómo distinguen hoy una falla de un mantenimiento programado?** |
| A | MTTR/MTBF con registros inconsistentes (22,8%) | Nada — es un defecto, lo corregimos nosotros |
| **B** | **Unidad de tiempo** | **¿MTBF de ~580 hs o de ~232 hs es el creíble?** |
| **C** | **Qué cuenta como falla** | **¿Toman lecturas durante una reparación en curso?** |
| **D** | **Estado `IN`** | **¿Qué representa? ¿Debe contar como no disponible?** |
| E | MTBF vs MTTF | ¿El indicador debería incluir el tiempo de reparación? |
| F | Estabilidad de períodos cerrados | ¿El KPI de un mes cerrado debe ser fijo? |
| G | Fechas inválidas desde OTs | ¿En qué pantalla se cargan esas lecturas? |
| **G-bis** | **Origen de las lecturas** | **¿Usan la verificación masiva? ¿Completan siempre fecha y horómetro al cerrar una OT?** |
| **H** | **Valor de disponibilidad** | **¿99,74% refleja su realidad operativa?** |

Los marcados en negrita son los que más impacto tienen sobre los números que hoy se le informan al
cliente.

---

## 6. Cómo seguimos

1. **Esta revisión con Ingeniería** — validar los criterios de arriba.
2. **Con las respuestas**, separar qué es defecto (se corrige) de qué es decisión de criterio (se
   define y se documenta).
3. **Antes de cambiar cualquier fórmula**, medir el impacto sobre los valores históricos. Si un KPI
   que se viene informando al cliente cambia, hay que poder explicar por qué.

**Nada de esto se modificó todavía.** Todos los análisis se hicieron con consultas de sólo lectura
sobre la base, y con revisión del código fuente del sistema.

### Sobre las validaciones — respuesta corta

Se consultó específicamente si la aplicación valida lo que se carga. La respuesta es **no, en el
camino que importa**: las lecturas generadas automáticamente al cerrar órdenes de trabajo copian
la fecha de la OT sin verificar que sea válida. Las cargadas por los otros caminos usan la fecha
del servidor y no pueden ser inválidas.

Agregar esa validación es un cambio acotado y de bajo riesgo. Lo que **no** es acotado, y por eso
lo consultamos, es decidir qué hacer cuando la OT no tiene fecha: ¿no generar la lectura?,
¿usar la fecha de cierre real?, ¿pedirla al usuario?

---

## Referencias

Definiciones y benchmarks contrastados para este documento:

- [MTTF vs MTBF vs MTTR: Key Failure Metrics Explained — eMaint](https://www.emaint.com/mtbf-mttf-mttr-maintenance-kpis/)
- [Mean time between failures — Wikipedia](https://en.wikipedia.org/wiki/Mean_time_between_failures)
- [MTBF, MTTR, MTTA, and MTTF — Atlassian](https://www.atlassian.com/incident-management/kpis/common-metrics)
- [What Is System Availability? Metrics & How To Calculate It — MaintainX](https://www.getmaintainx.com/learning-center/system-availability)
- [Availability (Maintenance Metric): Definition, Formula and How to Calculate — Tractian](https://tractian.com/en/glossary/availability-maintenance-metric)
- [8 KPIs for Maintenance Management — Tractian](https://tractian.com/en/blog/8-kpis-for-maintenance-management)
- [World-Class Maintenance Metrics for Operational Excellence — eWorkOrders](https://eworkorders.com/cmms-industry-articles-eworkorders/important-metrics/)
- [Planned Downtime — Tractian](https://tractian.com/en/glossary/planned-downtime)
