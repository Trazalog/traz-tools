# El proceso de mantenimiento, paso a paso

## Objetivo

Descifra el proceso BPMN que gobierna todo el módulo de Mantenimiento: quién hace qué, en qué orden,
y **por dónde pasa cada artefacto cambiando de estado**. Está escrito para entender el módulo antes
de tocarlo — sirve para relevar, para escribir la ayuda y para saber qué se rompe si se cambia algo.
**No** cubre las pantallas una por una (eso es el catálogo en `doctest/catalogo/man/`) ni el enganche
con Almacenes y Pañol, que está en `circuitos-man-alm-pan.md` del repo de AssetPlanner.

Fuente: el diagrama **Proceso de Mantenimiento AssetPlanner 1.0**, que está acá al lado
([`proceso-mantenimiento-assetplanner.gif`](proceso-mantenimiento-assetplanner.gif)).

---

## La idea en tres líneas

**Todo el mantenimiento es un solo proceso de Bonita.** Empieza de dos maneras —alguien pide un
servicio, o se planifica una actividad— y termina de dos maneras —el solicitante presta conformidad,
o la actividad planificada se cierra—. Entre medio, cada paso es **una tarea que aparece en la
bandeja de entrada** de quien le toca.

Eso explica dos cosas que confunden al usarlo por primera vez:

1. **Casi no se navega por menú.** Salvo cuando se lanza una solicitud y cuando se planifica en el
   calendario, el trabajo llega solo: aparece en *Mis Tareas*.
2. **Los estados no se cambian a mano.** Los artefactos —solicitud, backlog, orden de trabajo,
   informe— cambian de estado porque el proceso avanza, no porque alguien elija un estado.

---

## Los cinco carriles

| Carril | Qué hace en el proceso |
|---|---|
| **Solicitante** | Pide el servicio, y al final presta —o no— conformidad con el trabajo |
| **Supervisor de Taller** | Analiza la solicitud, decide si es urgente, asigna responsable en el camino urgente, y verifica el informe |
| **Planificador de Mantenimiento** | Planifica el backlog y las actividades planificadas, y asigna responsable |
| **Mantenedor** | Ejecuta la orden de trabajo y confecciona el informe de servicio |
| **IT** | Dos esperas técnicas: el proceso queda detenido hasta que la orden pasa a "a Ejecutar" |

---

## El recorrido

### 1 · Arranque: dos puertas de entrada

El proceso arranca con **Solicitud de Servicio o Planificación**, y lo primero que se pregunta es
**¿Es Solicitud de Servicio?**

- **Sí** → algo se rompió: va al *Análisis de Solicitud de Servicio* del Supervisor.
- **No** → es una actividad planificada (un preventivo, un predictivo): va directo al Planificador,
  a la compuerta *¿Planifica Actividad?*.

### 2 · El Supervisor analiza, y decide la urgencia

*Análisis de Solicitud de Servicio* desemboca en la pregunta que parte el circuito en dos:
**¿Es Urgente?**

**Si es urgente:**

1. *Actualizar Solicitud como Urgente* — automática, cambia el estado.
2. *Planificar Solicitud* — el Supervisor le pone fecha.
3. El proceso espera (carril IT) hasta que la orden pasa a **"a Ejecutar"**.
4. *Asignar Responsable OT Urgente* — el **Supervisor** elige quién la hace.
5. → *Ejecutar OT*.

**Si no es urgente:**

1. *Generar backlog* — automática: la solicitud se convierte en un pendiente.
2. *Editar Backlog* — el Supervisor lo completa.
3. *Planificar Backlog* — ahora interviene el **Planificador**, que le pone fecha.
4. El proceso espera (carril IT) hasta **"a Ejecutar"**.
5. *Asignar Responsable OT* — el **Planificador** elige quién la hace.
6. → *Ejecutar OT*.

> **La diferencia entre los dos caminos no es solo la velocidad: cambia quién decide.** En el urgente,
> el Supervisor planifica y asigna. En el no urgente, pasa al Planificador. Eso responde por qué el
> backlog existe como entidad aparte: **es la solicitud que no era urgente**.

### 3 · La rama planificada

Si el arranque no fue una solicitud, el Planificador decide en *¿Planifica Actividad?*:

- **Sí** → *Asignar Responsable OT* → *Ejecutar OT*.
- **No** → el proceso termina sin hacer nada (*Contrato proceso vacío*).

### 4 · El Mantenedor ejecuta

*Ejecutar OT* → *Confecciona informe de servicio*. Los dos pasos son del Mantenedor, y son el único
punto donde el trabajo se hace de verdad.

### 5 · La verificación, con dos vueltas atrás

*Verifica Informe de Servicio* (Supervisor) → **¿Informe correcto?**

- **No** → **vuelve al Mantenedor** a *Confeccionar informe de servicio*. El informe se corrige y se
  vuelve a presentar.
- **Sí** → **¿Es Solicitud de Servicio?**
  - **No** (era planificada) → *Fin Actividad Planificada*. Se cierra ahí.
  - **Sí** → el Solicitante *Presta conformidad*.

### 6 · El cierre, que el solicitante puede rechazar

**¿Conforme con el trabajo?**

- **Sí** → *Fin Solicitud Servicio*.
- **No** → **vuelve al principio**, al *Análisis de Solicitud de Servicio*.

> Ese "no" es el detalle más importante del final: **una solicitud rechazada por el solicitante no
> queda colgada — reabre el circuito completo.** El Supervisor vuelve a analizarla y puede decidir
> otra vez si es urgente, generando un nuevo recorrido.

---

## Las dos vueltas atrás, juntas

Son los dos lugares donde el proceso retrocede, y conviene tenerlos presentes porque explican por qué
un mismo trabajo puede recorrerse varias veces:

| Dónde | Quién rechaza | A dónde vuelve |
|---|---|---|
| *¿Informe correcto?* | el Supervisor | al Mantenedor, a rehacer el informe |
| *¿Conforme con el trabajo?* | el Solicitante | al Supervisor, a analizar la solicitud de nuevo |

---

## Los estados, y qué paso del proceso los pone

Cada tarea que se cierra escribe un estado. Éstos salen de `Tarea.php`, siguiendo el mismo nombre de
tarea que el diagrama:

| Código | Nombre | Lo pone… |
|---|---|---|
| `S` | **Solicitada** | al crearse la solicitud — y al volver atrás cuando el solicitante no presta conformidad |
| `PL` | **Planificada** | al generar la orden desde el plan de mantenimiento |
| `C` | **en Curso** | `inicioTarea()`: cuando el Mantenedor arranca la ejecución de la OT |
| `T` | **Terminada** | cuando el Mantenedor cierra su tarea |
| `CE` | **Cerrada** | `verificarInforme()`: cuando el Supervisor da por correcto el informe |
| `CN` | **Conforme** | `prestarConformidad()`: cuando el Solicitante acepta el trabajo |
| `AC` / `AN` | activo / anulado | son los del **equipo**, no del circuito |

> **El detalle que más importa del final:** en `prestarConformidad()` el estado por defecto es `CN`,
> pero **si el solicitante no da conformidad el estado vuelve a `S`** — el mismo con el que nació.
> No queda marcada como "no conforme": **la solicitud vuelve al principio** y el Supervisor la
> analiza de nuevo, tal como muestra el diagrama. Es coherente entre el proceso y el código.

Quedan códigos que aparecen en el modelo y **no se pudo confirmar qué son**: `RE`, `IN`, `P`, `EL`,
`ASC`, `GET`. Pueden ser de versiones anteriores o de caminos que hoy no se usan; conviene
verificarlo antes de documentarlos.

## Qué significa esto para la ayuda de usuario

- **La bandeja de entrada es el lugar de trabajo**, no una pantalla más. Alguien que llega sin
  soporte tiene que aprender primero a mirar *Mis Tareas*; el resto del menú es para consultar y
  configurar.
- **Nadie elige un estado.** Si el manual dice "poné la orden en estado X", está mal: los estados los
  mueve el proceso.
- **Hay dos caminos y se distinguen por una sola decisión** —urgente o no—, tomada por el Supervisor
  en un único punto. Vale la pena explicarlo temprano, porque después todo depende de eso.
- **Un trabajo puede volver atrás dos veces.** Conviene decirlo, para que nadie se sorprenda de ver
  reaparecer algo que creía cerrado.
