# Análisis de impacto: la doble carga de jQuery UI en el layout de tools

## Objetivo

Este documento es para que el PM decida si se toca `application/views/layout/general_scripts.php`
de tools. Es un archivo del núcleo, así que cualquier cambio necesita su aprobación (`CLAUDE.md`). Hay
que leerlo antes de cambiar cómo se carga jQuery UI. No cubre el resto de la migración de MAN, que está en
[MIGRACION-ASSETPLANNER.md](MIGRACION-ASSETPLANNER.md).

**Recomendación: no tocarlo ahora.** Con las vistas de MAN ya convertidas, la doble carga no rompe los
autocompletar. Abajo están la evidencia y los riesgos.

## Qué pasa hoy

El layout de tools (`application/views/layout/general_scripts.php`, que carga `layout/Admin.php`) trae
jQuery UI dos veces:

| Línea | Qué carga | Para qué |
|---|---|---|
| 5 | `lib/bower_components/jquery-ui/jquery-ui.min.js`, **1.11.4** completa | Uso general |
| 115 | `lib/plugins/jHTree/js/jquery-ui-1.10.4.custom.min.js`, **1.10.4** a medida (incluye autocomplete, datepicker, dialog, tooltip, sortable, etc.) | La trae el plugin de árbol jHTree |

La segunda pisa a la primera: en las páginas de tools, `$.ui.version` vale `1.10.4`.

**Comparación con producción (`master`):** las dos cargas están igual en `master`. La línea de jHTree
entró el 2020-10-22 (commit `3089b530`, "Arreglo Estilo"). O sea, producción funciona así desde hace
años y nada de esto es un cambio reciente.

**Quién usa jHTree:** la pantalla de trazabilidad de lotes del módulo de Producción
(`application/modules/traz-prod-trazasoft/views/produccion/lotes/trazabilidad.php:167`,
`$("#tree").jHTree(...)`), que corre dentro de este layout.

**Quién usa jQuery UI** (widgets `autocomplete`, `datepicker`, `dialog`, `tooltip`, `sortable`, `draggable`):
vistas del núcleo de tools (`views/core`) y los módulos `traz-comp-almacenes`, `traz-tools-resi`,
`traz-comp-pan`, `traz-prod-trazasoft`, `yudi-tools-almproc`, `traz-comp-bpm` y `traz-tools-man`.

## Evidencia (2026-10-28, local)

Prueba en navegador sin pantalla (Chromium por Playwright) con la sesión del usuario de prueba de MAN.
Carga tools, abre una pantalla de MAN con `linkTo`, escribe en el autocompletar y cuenta las opciones
que aparecen. Corre dos veces por pantalla: tal como está hoy y simulando la corrección (sin la línea 115,
bloqueando ese archivo).

| Pantalla de MAN | Campo | Con la doble carga (UI 1.10.4) | Sin la línea 115 (UI 1.11.4) |
|---|---|---|---|
| Componentes, asignación | `#componente` | 3 opciones | 3 opciones |
| Backlog, alta | `#tarea` | 3 opciones | 3 opciones |
| Predictivo, alta | `#herramienta` | 1 opción | 1 opción |
| Preventivo, alta | `#insumo` | campo oculto hasta abrir el modal (no se probó) | igual |
| Solicitudes, alta | `#tarea` | el campo no apareció en la prueba | igual |

En las dos variantes aparece el mismo error de JavaScript al mostrar el menú: `r.getClientRects is not a
function`. Es una incompatibilidad conocida entre jQuery UI anterior a 1.12 y jQuery 3 (el host usa jQuery
3), y no impide que el menú se vea ni que se elija una opción.

**Conclusión:** la falla que el plan atribuía a la doble carga ("acá se detuvo Rogelio") no se reproduce en
las pantallas ya portadas. Lo más probable es que lo que rompía el fork fueran las URLs `index.php/X` y los
`.success()`/`.error()` de jQuery 2, que la conversión de cada vista ya corrige.

## Opciones

| | Qué | Riesgo | Cuándo |
|---|---|---|---|
| **1 (recomendada)** | No tocar el layout. Seguir portando y probar cada autocompletar en navegador | Ninguno nuevo: es lo que corre en producción | Ahora |
| 2 | Quitar la línea 115 y dejar 1.11.4 para todo tools | Toda pantalla de tools con jQuery UI pasa de 1.10.4 a 1.11.4. Las APIs son casi iguales, pero hay cambios de comportamiento (por ejemplo en `dialog` y `datepicker`). Puede afectar a jHTree en trazabilidad de lotes | Solo si aparece una falla real atribuible a 1.10.4 |
| 3 | Cargar jHTree y su jQuery UI 1.10.4 solo en la vista de trazabilidad | El resto de tools pasa a 1.11.4 (mismo riesgo que la 2) y trazabilidad sigue igual que hoy | Si se elige la 2, es la forma segura de hacerlo |
| 4 | Pasar a jQuery UI 1.12+ (compatible con jQuery 3, elimina el error `getClientRects`) | El más alto: cambia la versión para todo tools | Proyecto aparte, con pruebas de regresión de todos los módulos |

## Si se elige la 2 o la 3: cómo probarlo

1. En local, con la VPN: aplicar el cambio en una rama y no desplegar.
2. Recorrer en navegador, con un usuario de cada rol, las pantallas que usan jQuery UI. Están en las vistas
   de `views/core` y de los módulos listados arriba; la búsqueda es
   `grep -rlE "\.(autocomplete|datepicker|dialog|tooltip|sortable|draggable)\(" application`.
3. Abrir la trazabilidad de lotes (Producción) y verificar que el árbol se dibuja y se puede expandir.
4. Recién con eso, desplegar una sola vez.
