# Ayuda — Trazalog Tools

Sitio estático de ayuda/documentación (en español) para **Trazalog Tools**, un sistema de gestión de mantenimiento. No es una app con backend: son páginas HTML autocontenidas (CSS y JS inline) servidas por XAMPP.

No es un repositorio git — no hay historial de commits que consultar. Cualquier contexto de "qué se hizo y por qué" tiene que vivir en este archivo.

## Estructura

- [index.html](index.html) — portada: hero con buscador, tarjetas de acceso a cada manual, sección de "preguntas frecuentes" con respuestas inline, y un índice de búsqueda en JS (`searchData`, cerca de la línea 670) que alimenta el buscador del hero.
- `manual_configuracion_inicial.html` — ingreso al sistema (1 sección: `s01`).
- `manual_alta_equipos_componentes.html` — alta de equipos y componentes (1 sección: `s01`).
- `manual_mantenimiento_correrctivo.html` *(nombre de archivo con typo, no corregir: rompería los links)* — mantenimiento correctivo, 9 secciones (`s01`–`s09`): roles del sistema, ingreso, equipos/componentes, artículos de almacén, solicitud de servicio, análisis de la solicitud, planificar OT, ejecutar OT, verificación del informe.
- `manual_mantenimeinto_preventivo.html` *(nombre de archivo con typo, no corregir)* — mantenimiento preventivo, secciones `s01`–`s0N` (incluye `s07` planificación/generación de OT preventiva).
- `manual_almacen_mantenimiento.html` — almacén, 2 secciones (`s01`, `s02`): artículos del almacén, cómo funciona el almacén.

Cada manual usa anclas `id="s01"`, `id="s02"`, etc. por sección, y `index.html` enlaza a esas anclas directamente (`manual_x.html#s03`).

## Roles del sistema (dominio)

Cuatro roles fijos, repetidos en toda la documentación — útil para mantener el vocabulario consistente:

- **Solicitante** — genera solicitudes de servicio, adjunta fotos de la falla.
- **Supervisor** — acepta/rechaza solicitudes, da de alta equipos/componentes, verifica el informe final.
- **Planificador** — programa actividades, carga mantenimientos preventivos, asigna OTs.
- **Mantenedor** — ejecuta las OTs y confecciona el informe de servicio.

## Estado conocido / pendiente

- **El índice de búsqueda de `index.html` está incompleto.** El array `searchData` solo tiene entradas para `manual_mantenimiento_correrctivo.html` y `manual_mantenimeinto_preventivo.html`. Los otros tres manuales (`manual_configuracion_inicial.html`, `manual_alta_equipos_componentes.html`, `manual_almacen_mantenimiento.html`) están linkeados como tarjetas en la portada pero **no aparecen si buscás su contenido** desde el buscador. Si se sigue trabajando en el buscador, esto es lo primero a completar.
- `.claude/settings.json` y `.claude/settings.local.json` tienen permisos para `python3 _build2.py` y `python3 _replace_cal.py`, pero ninguno de esos scripts existe actualmente en el directorio — probablemente se usaron una vez para generar/editar HTML y se borraron después. Si aparece la necesidad de regenerar contenido de forma masiva, puede valer la pena recrear un script así en vez de editar los HTML a mano.

## Convenciones a mantener

- Todo el contenido es en español (Argentina/Latam, tuteo: "podés", "ingresá").
- Paleta de colores y tipografías están definidas como variables CSS (`--red`, `--dark`, `--amber`, fuentes DM Sans / DM Serif Display / JetBrains Mono) duplicadas al inicio de cada archivo HTML — si se cambia una, hay que replicarla en los demás para mantener consistencia visual.
- Los nombres de archivo con typo (`correrctivo`, `mantenimeinto`) son los nombres reales enlazados desde `index.html` — no renombrar sin actualizar todos los links.
