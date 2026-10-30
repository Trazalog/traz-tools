# Propuesta: la Bandeja de Mantenimiento dentro de la bandeja de tools (MIG-7)

## Objetivo

Explica cómo funciona hoy la bandeja de tareas de tools (la de `traz-comp-bpm`), cómo usa la bandeja vieja de asset el equipo de
Mantenimiento, y propone cómo unir las dos en una sola. Está escrita para el PM, que decide la propuesta, y para quien la implemente.
No cubre el lanzamiento de órdenes (MIG-8) ni las notificaciones (MIG-9); ver [MIGRACION-ASSETPLANNER.md](MIGRACION-ASSETPLANNER.md).

Estado: **propuesta, sin implementar** (2026-10-30). El proceso de Bonita de referencia es el diagrama "Proceso de Mantenimiento
AssetPlanner" que compartió el PM (`~/Descargas/Proceso de Mantenimiento AssetPlanner-1.0 (1).gif`).

---

## 1. Cómo funciona la bandeja de tools

**Archivos:** `application/modules/traz-comp-bpm/` — controller `Proceso2` (hereda de `Proceso`), modelo `Procesos2` (hereda de `Procesos`),
vista `bandeja_entrada2.php`. Menú: "Mis Tareas" (`traz-comp-bpm/Proceso2`).

### 1.1 La lista

- Una tabla de una sola columna: **cada fila es una tarjeta** de una tarea pendiente del usuario. DataTables del lado del servidor
  (paginado y búsqueda en la base, 10 por página, búsqueda desde los 3 caracteres).
- Los datos salen de `BandejaDataService`: las tareas pendientes del usuario en Bonita, filtradas por la empresa activa
  (`core.case_empresa`) y por la búsqueda, ordenadas por llegada. **Solo las tareas de la página** se enriquecen con los datos propios de
  cada proceso.
- Hacer clic en una tarjeta abre el detalle **al costado** (la bandeja se achica a un tercio y el detalle ocupa el resto).

### 1.2 La tarjeta y sus pastillas de colores

Cada tarjeta muestra, de izquierda a derecha:

| Pieza | Qué es |
|---|---|
| Icono de persona | Azul si la tarea tiene responsable (con la fecha de asignación al pasar el mouse), gris si no está asignada |
| Nombre del proceso | Con el **color del proceso** (verde Mantenimiento, naranja pedidos de materiales, azul producción…) |
| Nombre de la tarea | Tal cual está en Bonita |
| `case: N` | El número del caso, chico y gris |
| **Pastillas** | Una por dato importante del caso: `<p class="label label-{color}">texto</p>` |
| Descripción | Una línea con el detalle del caso |

Si la tarea falló en Bonita, el proceso se pinta de rojo.

**Las pastillas las arma cada proceso.** Cada una es un objeto `{color, texto, estilo}`: `color` es la clase de AdminLTE (`warning`
amarillo, `default` gris, `success` verde, `danger` rojo, `info` celeste, `primary` azul) y `estilo` es un estilo suelto opcional (sirve
para colores que no existen como clase). Ejemplo, pedidos de materiales: "N° Pedido", "Lote" y "Estado" en amarillo, "Fecha" en gris.

### 1.3 Los ganchos ("hooks") de cada proceso

No hay un sistema de eventos: lo que hay es un **registro** y **cuatro ganchos** que cada proceso implementa en su modelo.

1. **Registro:** la constante `BPM_PROCESS` (`application/config/constants.php`) asocia el número de proceso de Bonita con su nombre, su
   color, su módulo y el modelo que lo atiende. Un proceso que no está registrado cae en el modelo genérico `Gentareas`: aparece en la
   bandeja sin pastillas, con el texto "Te faltó definir el modelo" y sin pantalla de trabajo.
2. **`map($tarea)`** — arma las pastillas, la descripción y una etiqueta de caso para la tarjeta.
3. **`desplegarCabecera($tarea)`** — la franja de datos que va arriba en el detalle.
4. **`desplegarVista($tarea)`** — la pantalla de trabajo, elegida **por el nombre de la tarea** (un `switch`).
5. **`getContrato($tarea, $form)`** — también por nombre de tarea: arma los datos con que se cierra la tarea en Bonita.

Lo común a todos los procesos lo da `Proceso`: tomar, soltar, cerrar (llama a `getContrato` y cierra en Bonita), comentarios y línea de
tiempo del caso.

### 1.4 Dónde está hoy Mantenimiento en esa bandeja

- El proceso de Mantenimiento (`8664799170016058315`; también están las versiones DEMO y PERU en la Bonita de desarrollo) **no está
  registrado** en `BPM_PROCESS`. La constante `BPM_PROCESS_ID_MANTENIMIENTO` existe, pero no se usa en el registro, y la entrada que dice
  "Proc. Mantenimiento" en realidad lleva el número de **Pedidos de materiales extraordinarios**.
- Resultado: las tareas de Mantenimiento ya aparecen en "Mis Tareas" de tools (los casos se registran en `core.case_empresa` al lanzarlos),
  pero sin pastillas ni pantalla de trabajo.

---

## 2. Cómo se usa hoy la bandeja de asset

(Es lo que ya se migró a MAN como "Bandeja de Tareas".)

- **La lista:** una fila por tarea con tipo de tarea (una **bolita de color por tipo de orden**: rojo urgente, naranja backlog, turquesa
  preventivo, verde predictivo, azul orden de trabajo, fucsia correctivo programado), estado, asignado, fecha de asignación, equipo, sector,
  cliente, tarea, descripción, número de solicitud, de orden y de pedido. Búsqueda, orden por columna, botón Actualizar y recarga automática.
- **La tarea:** al abrirla se ve una **pantalla completa** con el equipo, la solicitud y la orden, los comentarios y la línea de tiempo, y
  la pantalla propia de la tarea.
- **Qué hace cada rol en el proceso** (según el diagrama):

| Quién | Tarea de Bonita | Qué hace en la pantalla |
|---|---|---|
| Supervisor Taller | Análisis de Solicitud de Servicio | Decide si es urgente |
| Supervisor Taller | Editar Backlog | Completa el backlog generado |
| Supervisor Taller / Planificador | Planificar Solicitud / Planificar Backlog | Va al Calendario y genera la orden |
| Supervisor Taller / Planificador | Asignar Responsable OT (Urgente) | Elige responsable y tarea |
| Mantenedor | Ejecutar OT | Inicia la orden, hace las subtareas y la termina |
| Mantenedor | Confecciona informe servicio | Carga el informe |
| Supervisor Taller | Verifica Informe de Servicio | Aprueba o devuelve el informe |
| Solicitante | Presta conformidad | Conforme o no conforme |

---

## 3. Cómo se cierra una tarea en la bandeja de tools (el mecanismo, estudiado a fondo)

El detalle se arma en `Proceso::detalleTarea` y se muestra en la plantilla `notificacion_estandar.php`:

1. **Arriba:** la cabecera (`desplegarCabecera`).
2. **Pestañas:** Acciones, Comentarios, Trazabilidad e Información. Comentarios, línea de tiempo e información **ya los da la plantilla**
   para cualquier proceso, con los datos de Bonita (es lo mismo que yo había hecho aparte para MAN).
3. **Pestaña Acciones:** botones **Tomar tarea / Soltar tarea** (genéricos: asignan la tarea en Bonita al usuario), la **pantalla de trabajo**
   (`desplegarVista`) metida en una caja que queda **bloqueada con un velo hasta que se toma la tarea**, y abajo **Cerrar** (cierra el
   panel) y **Hecho**.
4. **El botón "Hecho" no cierra nada por sí mismo: llama a la función `cerrarTarea()` que defina la pantalla de trabajo.** Esa función
   decide adónde mandar los datos. Los procesos de pedidos de materiales mandan a `Proceso/cerrarTarea` (que usa `getContrato` y cierra en
   Bonita), pero nada obliga a eso: la pantalla puede mandar a sus propios recursos.

**Conclusión: no hace falta tocar el módulo central de la bandeja.** Alcanza con registrar el proceso en `BPM_PROCESS` (en `constants.php`,
como indicó el PM) y escribir el modelo del proceso en el módulo MAN. Mi propuesta anterior de agregar un gancho `cerrar` a
`Proceso::cerrarTarea` era innecesaria.

## 4. La propuesta (corregida)

**Una sola bandeja: la de tools.** El proceso de Mantenimiento (**solo el normal**, `8664799170016058315`; DEMO y PERU no van) se registra
y se le agrega su modelo. Hoy las tareas ya aparecen en la bandeja de tools, pero **el panel del costado sale vacío** porque el proceso no
está registrado y cae en `Gentareas`, que no devuelve pantalla.

### 4.1 Qué se agrega

1. **Registro** (`application/config/constants.php`, `BPM_PROCESS`): el proceso de Mantenimiento con su nombre, color verde, módulo `MAN` y
   modelo `Mantareas`. Es el único cambio fuera de MAN y es configuración. Como `constants.php` figura como núcleo en `CLAUDE.md`, va en el
   pedido de integración con este análisis de impacto: **qué cambia** una entrada más en un arreglo; **qué lo consume** la bandeja de tools
   (nombre y color del proceso y qué modelo atiende cada tarea) y la búsqueda de la base de la bandeja; **qué se rompe** nada de lo que ya
   está registrado; **por qué hoy no está** la constante `BPM_PROCESS_ID_MANTENIMIENTO` existe pero nadie la registró. Dato aparte: la
   entrada que dice "Proc. Mantenimiento" lleva en realidad el número de Pedidos extraordinarios; no se toca.
2. **Modelo `Mantareas` (módulo MAN)** con los ganchos de §1.3:
   - **`map` — las pastillas.** Mismos datos y colores que la bandeja vieja de asset:

     | Pastilla | Color |
     |---|---|
     | Tipo de orden (Urgente, Backlog, Preventivo, Predictivo, Orden, Correctivo prog.) | el color del tipo, el mismo del Calendario (`estilo` para los que no tienen clase: turquesa y fucsia) |
     | Solicitud N° | celeste |
     | Orden N° | azul |
     | Equipo (código) | gris |
     | Sector y cliente | gris |
     | Responsable (nombre, o "Sin asignar") | verde / gris |
     | Estado de la orden (Planificada, Asignada, En curso, Terminada…) | amarillo mientras está pendiente, verde si terminó |

     La descripción es la de la orden o la causa de la solicitud. Los datos salen de `MANDataService`, una consulta por tarea de la página (10).
   - **`desplegarCabecera`**: la franja de equipo, solicitud y orden (E32).
   - **`desplegarVista`**: **las mismas pantallas de la bandeja de MAN, adaptadas a la bandeja de tools** (ver 4.2).
   - **`getContrato`**: vacío (el cierre no pasa por ahí).
3. **Adaptar las diez pantallas** (Análisis, Planificar Solicitud/Backlog, Asignar Responsable, Ejecutar OT, Confecciona informe,
   Verifica informe, Presta conformidad, Editar Backlog y las de espera) al panel del costado.

### 4.2 Cómo se adapta cada pantalla al panel

- Se muestran **solo el formulario o la acción** de la tarea: la cabecera, los comentarios y la línea de tiempo los pone la plantilla.
- Las pantallas **quedan bloqueadas hasta que se toma la tarea**, como ya hace la plantilla.
- Lo que antes era un botón propio de cierre ("Aceptar", "Confirmar"…) pasa a ser la función **`cerrarTarea()`** que llama el botón **Hecho**:
  valida, manda a los mismos recursos de `toolsMANAPI` de hoy (E31 a E33), y al terminar cierra el panel y refresca la lista.
- Las pantallas que hoy navegan con `linkTo` a otras pantallas (por ejemplo, ir al Calendario a planificar, o a la lista de órdenes a asignar)
  se resuelven así: **Planificar** abre el Calendario (otra pantalla de MAN) y **Asignar** muestra el formulario de responsable y tarea en el panel.
- Las pantallas anchas (informe de servicio, ejecutar orden) usan el ancho completo del panel; si no alcanza, el panel se puede ampliar.

### 4.3 Qué hay que verificar

1. Registrar el proceso con un `Mantareas` mínimo (pastillas) y **mirar la bandeja en el navegador**.
2. Pantalla por pantalla, con un caso real en cada tarea, entrando por la bandeja de tools: tomar, hacer, **Hecho**, y ver que la tarea siguiente
   aparece y que la base queda como en asset.
3. Las dos bandejas conviven hasta que el equipo confirme; después se saca "Bandeja de Tareas" del menú de MAN.
