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

## 3. La propuesta

**Una sola bandeja: la de tools.** El proceso de Mantenimiento se registra en ella con su propio modelo, y la "Bandeja de Tareas" de MAN
se retira del menú cuando lo nuevo esté verificado.

### 3.1 Qué se agrega

1. **Registro:** los tres números del proceso (normal, DEMO y PERU) en `BPM_PROCESS`, color verde, módulo `MAN`, modelo `Mantareas`. De
   paso se corrige el nombre de la entrada de pedidos extraordinarios.
2. **Modelo `Mantareas` (módulo MAN)** con los ganchos de §1.3:
   - **`map` — las pastillas** (todas con los mismos datos y colores que la bandeja vieja):

     | Pastilla | Color |
     |---|---|
     | Tipo de orden ("Urgente", "Backlog", "Preventivo", "Predictivo", "Orden", "Correctivo prog.") | el color del tipo, el mismo del Calendario (rojo, naranja, turquesa, verde, azul, fucsia; `estilo` para el turquesa y el fucsia) |
     | Solicitud N° | celeste |
     | Orden N° | azul |
     | Equipo (código) | gris |
     | Sector y cliente | gris |
     | Responsable (nombre) | verde si tiene, gris "Sin asignar" si no |
     | Estado de la orden (Planificada, Asignada, En curso, Terminada…) | amarillo mientras está pendiente, verde cuando terminó |

     La descripción es la de la orden (o la causa de la solicitud). Los datos salen de una sola consulta por página a `MANDataService`
     (la misma idea de E30).
   - **`desplegarCabecera`** — la franja de equipo, solicitud y orden que ya construí para el detalle (E32).
   - **`desplegarVista`** — las diez pantallas por nombre de tarea que ya están hechas y probadas (E32, E33).
   - **`getContrato`** — el contrato de cierre de cada tarea.
3. **Un gancho nuevo, `cerrar`, en `Proceso::cerrarTarea`.** Las tareas de Mantenimiento no se cierran solo en Bonita: además escriben en
   la base (estados de la orden y del plan, informe, etc.), y eso lo hacen los recursos de `toolsMANAPI` ya hechos (E31), que operan sobre
   Bonita y la base juntos y deshacen si algo falla. Se propone que, si el modelo del proceso define `cerrar($tarea, $form)`, el controller
   lo use en vez del cierre genérico. Es un cambio **chico y compatible** (los demás procesos no lo definen y siguen igual), pero toca el
   módulo central `traz-comp-bpm`: por la regla de `CLAUDE.md` necesita un análisis de impacto que apruebe el PM.

### 3.2 Qué cambia para el usuario de Mantenimiento

- La lista pasa a ser de tarjetas (en vez de tabla con columnas) y las pastillas reemplazan a las columnas.
- Las tareas de Mantenimiento conviven con las de los otros procesos del usuario (pedidos de materiales, producción…): una sola bandeja.
- El detalle se abre al costado. Las pantallas grandes (informe de servicio, ejecutar orden) se pueden abrir a pantalla completa.
- Se conservan: búsqueda por descripción, equipo, solicitud y orden; botón Actualizar; el color por tipo de orden; "Sin asignar".

### 3.3 Cómo se hace y se prueba

1. Registrar el proceso con un `Mantareas` mínimo (solo pastillas) y mirar la bandeja en el navegador.
2. Conectar el detalle (cabecera y las diez pantallas) y el gancho `cerrar`.
3. Prueba punta a punta con casos reales en Bonita de desarrollo, como las de `e2e_bandeja_*`, pero entrando por la bandeja de tools.
4. Las dos bandejas conviven un tiempo (como `Proceso` y `Proceso2`) hasta que el equipo confirme; después se retira la de MAN del menú.
5. Por qué no hay paridad automática con la vista nueva: cambia el formato (tarjetas), así que se compara contra los mismos datos de la
   bandeja de MAN (que ya tiene paridad con asset).

### 3.4 Lo que hay que decidir

1. **¿Se aprueba tocar `traz-comp-bpm` con el gancho `cerrar`?** (alternativa: que las pantallas de Mantenimiento llamen directo a sus
   recursos y el cierre genérico quede sin usar para este proceso; funciona, pero deja dos caminos de cierre distintos.)
2. **¿Detalle al costado o pantalla completa?** Propuesta: al costado, con botón para ampliar.
