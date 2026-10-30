# Errores de AssetPlanner que siguen en producción

## Objetivo

Lista, en lenguaje simple, de los errores de AssetPlanner (asset) encontrados durante la migración a tools.
Está escrita para el PM y para quien tenga que explicarle a un cliente por qué conviene pasar a tools
antes de que asset se apague. **Asset no se corrige** (decisión del PM del 2026-10-29): cada error queda
anotado acá y se resuelve en el módulo de mantenimiento de tools (MAN). El detalle técnico de cada uno
(archivos, líneas, cómo se corrigió) está en
[`MIGRACION-ASSETPLANNER.md` §5.2](MIGRACION-ASSETPLANNER.md#52-bugs-heredados-de-asset-están-hoy-en-producción),
con el mismo número.

- Última actualización: 2026-10-29
- Alcance: solo errores de asset. Los de tools y del integrador (T5 en tools, T9, T17, T18, T21, T25, T26)
  se corrigen en tools y están únicamente en el plan.

## Cómo leer la lista

- **Gravedad**: 🔴 una empresa puede ver o modificar datos de otra, o el error abre una puerta de
  seguridad. 🟠 pierde o desordena datos de la propia empresa. ⚪ molesta o confunde, pero no daña datos.
- **En MAN**: "Corregido" quiere decir que la pantalla portada ya no lo tiene y que hay una prueba que lo
  comprueba. "Pendiente" quiere decir que la pantalla todavía no se portó.

## Errores entre empresas y de seguridad 🔴

| # | Qué pasa, dicho simple | En MAN |
|---|---|---|
| T1 | Al cargar una lectura de equipo, el control de empresa queda anulado por una condición mal escrita: se pueden tocar datos de equipos de otra empresa | La lectura ya no toca otras empresas. La parte que marca los preventivos se rehace con Calendario (E16 del plan) |
| T2 | Unas quince consultas a la base se arman pegando lo que escribe el usuario. Alguien con mala intención puede leer o borrar datos de cualquier empresa | Corregido en lo portado; Calendario pendiente |
| T11 | Área y Proceso: con el número de un registro de otra empresa se lo puede ver o dar de baja | Corregido |
| T20 | En Backlog y Predictivo, borrar un adjunto borra el adjunto del **preventivo** que tenga ese número, de cualquier empresa | Corregido |
| T22 | Al guardar equipos y planes se acepta el número de una tarea, componente, sector o cliente de otra empresa, y después su nombre aparece en los listados | Corregido en equipos y planes; herramientas y artículos quedan para la integración con el pañol |
| T23 | Los adjuntos de equipos aceptan cualquier tipo de archivo y quedan en una carpeta que el servidor web publica: un archivo de programa subido como adjunto podría ejecutarse | Sigue igual que en asset: falta restringir los tipos de archivo |
| T27 | La pantalla de solicitudes terminadas muestra las de todas las empresas | Corregido |
| T29 | El detalle de las órdenes de trabajo muestra clientes y equipos de otras empresas cuando los datos quedaron cruzados | Corregido (MAN filtra todo por empresa) |
| T34 | El botón "Verificar" de informes cierra el informe y la orden de trabajo que mande el navegador, sin mirar la empresa: un usuario puede cerrar los de otra empresa | Corregido |
| T35 | En la carga de lecturas de parámetros se puede borrar la lectura de otra empresa con su número, y grabar lecturas sobre equipos de otra empresa | Corregido |
| T36 | Las acciones de la bandeja (tomar, soltar, decidir urgencia, ejecutar la orden, verificar el informe, prestar conformidad) usan el usuario administrador de Bonita y los números de tarea, orden y solicitud que manda el navegador, sin mirar la empresa ni el usuario: cualquiera puede cerrar o reasignar tareas y cambiar estados de otra empresa | Corregido: el caso de la tarea tiene que ser de la empresa y la orden y su origen salen de ese caso |

## Errores que pierden o desordenan datos 🟠

| # | Qué pasa, dicho simple | En MAN |
|---|---|---|
| T3 | "Generar órdenes en serie" con frecuencia cero crea órdenes de trabajo y casos en Bonita sin parar, hasta que el servidor corta | Pendiente (Calendario) |
| T6 | La periodicidad mensual se toma como 30 días y "cada 500 horas" se toma como 500 días | Pendiente (Calendario) |
| T7 | La lectura del contador del equipo se toma de dos lugares distintos y pueden no coincidir | Pendiente (Calendario) |
| T8 | La regla que decide si un mantenimiento está vencido está programada cuatro veces, con tres fórmulas distintas | Pendiente (Calendario) |
| T12 | Al cargar una lectura, el cálculo de la próxima lectura asigna en vez de sumar, y si el equipo no tiene preventivo la operación falla a mitad de camino con la lectura ya grabada | Igual que T1: esa parte se rehace con Calendario |
| T13 | Al subir varios archivos juntos, todos toman el nombre del primero: desde el segundo, el archivo guardado no coincide con el registrado | Corregido |
| T15 | Las lecturas se guardan en una tabla que no permite deshacer: si una operación falla a medias, la lectura queda igual | Sigue igual: es de la base compartida y se resuelve en el paso a PostgreSQL |
| T16 | El detalle de un preventivo busca las herramientas en la tabla vieja: muestra otra herramienta o ninguna | Corregido |
| T28 | El alta de una solicitud lanza el caso de Bonita con una contraseña común; si el usuario tiene otra, la solicitud falla y se borra | Corregido |
| T30 | Al asignar una orden de trabajo, la tarea de Bonita queda asignada a otra persona, o falla, porque se usa el número de usuario de asset en lugar del de Bonita | Corregido |
| T31 | El alta de una orden de trabajo responde siempre "error", y si Bonita falla borra la orden pero sigue grabando su detalle | Corregido |
| T37 | Verificar informe y prestar conformidad responden "OK" aunque Bonita no haya cerrado la tarea (usan una variable que no existe), y el estado del backlog se cambia antes de cerrar la tarea: si Bonita falla queda cambiado igual | Corregido: primero se cierra la tarea y recién después se cambian los estados; si falla, se informa el error |
| T38 | Al rechazar una conformidad ("no conforme"), la solicitud y la orden pasan al estado "Solicitado" porque se compara un texto "false" como si fuera verdadero; y el inicio de una orden de tipo 1 o 10 intenta cambiar un predictivo con el número de la orden | La conformidad rechazada se conserva igual (es lo que espera el proceso de Bonita); en el inicio, el tipo 1 y 10 no toca ningún predictivo hoy porque no existen esos números |
| T32 | "Verificar" informes busca la tarea solo entre las 10 primeras de la bandeja: si no está ahí, cierra el informe en la base y deja la tarea abierta en Bonita | Corregido |

## Errores que molestan pero no dañan datos ⚪

| # | Qué pasa, dicho simple | En MAN |
|---|---|---|
| T4 | Fechas vacías escritas como "0000-00-00", que impiden actualizar la versión de la base | Pendiente (Calendario) |
| T10 | Código que va a fallar cuando el servidor pase a PHP 8 | Corregido en lo portado |
| T14 | El código de equipo no se puede repetir entre empresas distintas (dos clientes no pueden tener un "BOMBA-01") | Se mantiene la regla, ahora configurable |
| T19 | Un mensaje de error no definido rompe la respuesta de Backlog y Solicitudes cuando algo falla | Corregido |
| T33 | Al abrir un informe desde la lista, los datos del equipo aparecen vacíos | Corregido |

## Correcciones ya hechas en asset antes de esta decisión

T11, T20 y T27 se corrigieron también en asset con el
[PR #339](https://github.com/Trazalog/traz-prod-assetplanner/pull/339), fusionado en la rama
`develop-v3` del repositorio de asset antes de la decisión del 2026-10-29. Esa rama **no está en
producción**: producción corre `master`, que no tiene la corrección. No se revierte: no afecta a
producción, y revertirla costaría otro PR sin beneficio. No se hacen más correcciones en asset.

## Si la versión nueva no sale a tiempo

Decisión del PM del 2026-10-29: si al terminar la migración no hay fecha de salida para tools v3 y
asset tiene que seguir en uso, se corrigen sobre el asset actual los errores graves (los 🔴 de este
documento), empezando por T34, T2 y T1. Para eso, el detalle técnico de cada uno está en
[`MIGRACION-ASSETPLANNER.md` §5.2](MIGRACION-ASSETPLANNER.md#52-bugs-heredados-de-asset-están-hoy-en-producción),
y la corrección hecha en MAN sirve de referencia. Esa corrección toca producción, así que antes pasa
por el análisis de impacto que aprueba el PM (regla del `CLAUDE.md` de tools).
