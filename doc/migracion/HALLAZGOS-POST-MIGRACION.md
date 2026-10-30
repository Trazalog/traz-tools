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
