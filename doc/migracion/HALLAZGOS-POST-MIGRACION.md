# Hallazgos a revisar después de la migración

## Objetivo

Lista de cosas que aparecieron mientras se migraba Mantenimiento (MAN) y que no se resolvieron en el
momento: dudas, supuestos propios, partes sin probar de punta a punta y decisiones tomadas por
autonomía que conviene revisar. Está escrita para el PM, para repasarla junto cuando lo migrado ya
funcione. No reemplaza a [ERRORES-ASSET.md](ERRORES-ASSET.md) (errores de asset) ni a las decisiones
de [MIGRACION-ASSETPLANNER.md](MIGRACION-ASSETPLANNER.md) §3.8.

**Cómo se usa:** cada fila dice dónde está el tema, qué hay que revisar y quién. Estado: ⏳ pendiente,
✅ revisado.

| # | Tema | Qué hay que revisar | Estado |
|---|---|---|---|
| H1 | Editar Backlog (Bandeja) | Está hecho pero no se probó de punta a punta: en desarrollo no hay forma simple de generar esa tarea. Probar con un backlog real devuelto | ⏳ |
| H2 | Pantallas en el navegador | Nadie vio todavía las pantallas migradas (Bandeja y Calendario) en el navegador: el asistente no puede escribir la contraseña en `traz-comp.local`. Comparar con asset, mismo mes y misma empresa | ⏳ |
| H3 | Botones de la empresa 6 y ABM de tareas estándar | No se portaron (decisión E30). Confirmar que nadie los usa | ⏳ |
| H4 | Decisión de urgencia | No se probó de punta a punta | ⏳ |
| H5 | Ejecutar OT | Usa la ubicación del navegador y muestra el procedimiento sin visor de PDF propio | ⏳ |
| H6 | Fechas de series (Calendario) | Se eligió el cálculo por calendario (mismo día de cada mes) en vez de los días fijos de asset (mes = 30 días). Confirmar que las series nuevas que ve el usuario son las esperadas | ⏳ |
| H7 | Planes y órdenes con el equipo de otra empresa | En la base de desarrollo, 130 de 134 preventivos, 7 de 9 predictivos, 42 de 45 backlogs y 922 de 966 órdenes tienen un equipo cargado en otra empresa distinta de la suya (ej.: planes de la empresa 6 sobre equipos de la empresa 8). El motor nuevo los rechaza ("no se creó ninguna orden: el equipo no es de la empresa"), asset los dejaba pasar. Antes del corte hay que **correr la misma cuenta en producción** y decidir: corregir los datos o permitirlo | ⏳ |
| H8 | Fechas de series mensuales, semestrales y anuales | MAN las calcula por calendario (el mismo día de cada mes, y el último si el mes no lo tiene); asset usaba 30, 180 y 365 días y se iba corriendo (una serie mensual desde el 31 de enero terminaba el año el 26 de enero). Las series que ya están creadas en producción no cambian. Confirmar con un usuario que lo nuevo es lo que esperan | ⏳ |
| H9 | Tope de 400 órdenes por pedido y de 36 meses | Decisión propia (asset no tenía tope y se colgaba con frecuencia cero). La serie diaria más larga que hay hoy en desarrollo es de 135 órdenes. Confirmar que 400 y 36 alcanzan para el uso real | ⏳ |
| H10 | Tiempo de espera de una serie larga | Programar una serie crea un caso de Bonita por orden: 16 órdenes tardaron 14 segundos. Una de 400 podría tardar más de 5 minutos y el navegador o el servidor la cortarían. Medir con una serie real larga y, si hace falta, dar aviso de espera o bajar el tope | ⏳ |
| H11 | Casos de Bonita borrados al deshacer | Cuando una programación falla y se deshace, el caso se borra de Bonita y de la base de asset, pero queda su fila en `core.case_empresa` de PostgreSQL (lo mismo pasa hoy al deshacer el alta de una orden o de una solicitud). Son filas huérfanas inofensivas; decidir si se limpian a mano o con un recurso nuevo de `toolsbpmAPI` | ⏳ |
| H12 | Solicitudes urgentes de la tabla del Calendario | Se arman con las tareas pendientes del usuario en Bonita (pide hasta 20 páginas de 50). Con un usuario con cientos de tareas puede tardar. Medir con un usuario real | ⏳ |
| H13 | Reintento ante un corte de Bonita | Si Bonita corta la conexión justo en la primera llamada, WSO2 suspende ese destino 30 segundos y las llamadas siguientes fallan hasta que pase ese tiempo (se vio una vez en desarrollo). El usuario ve un error y reintenta. Evaluar si conviene un reintento automático | ⏳ |
| H14 | Pestañas de pañol y almacén en la ventana de la orden | La ventana de la orden de MAN no trae "Herramientas" (vales de pañol) ni "Pedido Materiales" (decisión del PM: lo de almacenes y pañol no se migra). Confirmar con los usuarios que mientras tanto lo siguen usando por la aplicación de almacenes de tools | ⏳ |
| H15 | Subtareas con formulario al asignar | Al asignar una orden, asset creaba las subtareas con sus formularios (tablas `frm_*` que no existen en la base de desarrollo). MAN no las crea (E34). Si algún cliente las usa, hay que portar los formularios | ⏳ |
| H16 | Datos de prueba con tildes mal guardadas | Varios equipos y solicitudes de la empresa de prueba se ven con letras raras ("Bomba centrÃ­fuga"). Los datos se guardaron con la codificación equivocada; asset los muestra igual, así que no es un error de la migración. Conviene corregirlos en la base de desarrollo | ⏳ |
| H17 | Permisos fijos en el menú | Para que se puedan agregar, editar y borrar, el menú de MAN trae los permisos en la dirección de cada opción, iguales para todos los usuarios de la empresa (ver `MENU-MAN.md`). El mapeo real con los grupos de asset es MIG-5 | ⏳ |
| H18 | Pantallas lentas | La lista de Solicitudes de Servicio tarda unos 15 segundos en cargar en desarrollo (junta los casos de Bonita) y el Calendario tarda varios segundos en mostrar la tabla de solicitudes urgentes. Medir con un usuario con muchas tareas | ⏳ |
| H19 | Empresa del PM sin vincular | "Ruiz Technologies Inc." no está vinculada con los datos de Mantenimiento (`core.empresas.empr_id_mysql` vacío), por eso el PM entra con el usuario de prueba. Vincularla toca una tabla central y necesita su aprobación | ⏳ |
| H20 | Datos de ejemplo en la empresa de prueba | Se cargaron datos de ejemplo (planes, órdenes de octubre y noviembre de 2026, informes, lecturas y tres solicitudes con caso de Bonita) para poder mirar las pantallas. Se borran con `seed_demo_man.py --borrar` y `seed_demo_bonita.py --borrar` | ⏳ |
| H21 | "Administrar Órdenes" no estaba en el plan | La pantalla de entregar y reprogramar órdenes terminadas (`Envio`) no figuraba en el inventario de la migración; se portó el 2026-10-30. Revisar si hay otras pantallas de asset fuera del inventario | ⏳ |
| H22 | ABM de Tareas estándar mal descartado | Se había dejado afuera por creer que ninguna pantalla lo usaba; el menú de asset lo tiene activo (`Tarea/index2`). Se porta con los demás ABMs | ⏳ |
| H23 | "trazabilidad Activos" del menú de asset | Está activa pero su dirección es un texto suelto (`fa fa-calendar`), así que no abre nada en asset. Confirmar si alguien la usa o es un resto | ⏳ |
| H24 | Casos viejos sin datos en la bandeja | Los casos 30001–30008 y 29006–29007 muestran "Sin datos de Mantenimiento para este caso" en la bandeja de tools: no tienen solicitud ni orden en las tablas de MAN. Revisar si se limpian o se dejan | ⏳ |
| H25 | Sesión vencida mostraba una dirección suelta | `validarInactividad()` (`sesion_helper.php`) escribía la dirección de `Login/log_out` en pantalla en vez de redirigir. Existía igual en `master`. Corregido en la migración: navegación directa redirige, Ajax conserva el comportamiento. Revisar si el mismo defecto está en los submódulos que tienen su propia copia del helper | ⏳ |
| H26 | Bandejas con distinto modo de recarga | "Mis Tareas" (`Proceso`) es una tabla fija y `Proceso2` una tabla de servidor; el panel de MAN distingue las dos. Si se unifican, simplificar `cargarVista` | ⏳ |
