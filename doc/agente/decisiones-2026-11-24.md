# Decisiones tomadas por Claude Code para cerrar el plan de agentes (22 al 24 de noviembre de 2026)

## Objetivo

Qué es: la lista de las decisiones que tomé solo, por pedido del PM («si tenés que tomar decisiones hacelo y luego documentá cuáles y si precisás mi revisión», 2026-11-22), mientras avanzaba el plan de agentes hasta el martes 24 a las 9. Para quién: el PM, que las revisa una por una. Cuándo leerlo: antes de unir los cambios propuestos de esta tanda. Qué NO cubre: las decisiones que tomó el PM (están en `doc/v3/STATE.md`) ni el detalle técnico de cada cambio (está en su PR).

**Cómo leer la tabla:** 🔴 = necesita tu revisión antes de unir (toca el núcleo, la marca o algo legal); 🟡 = conviene que la mires, pero no frena; 🟢 = técnica menor, solo para que sepas.

| # | Decisión | Por qué | Dónde | Revisión |
|---|---|---|---|---|
| 1 | Completé los seis bloques del prompt de Quirqui (presentación, advertencias de seguridad, límites, tono, extensión, fuera de tema) y el de Kuntur (cómo acompaña al administrador) | Eran el último pendiente del gate de textos (M-07) y el taller entregó solo las imágenes | `prompts/quirqui.md`, `prompts/kuntur.md` — PR de AGENTE-M-07 | 🔴 marca y responsabilidad: sobre todo las **advertencias de seguridad** (B) y los **límites** (C) |
| 2 | Quirqui, si le preguntan, dice que es un asistente de inteligencia artificial | Es lo honesto y evita un problema si un cliente lo descubre después | bloque A | 🟡 |
| 3 | Las advertencias de seguridad suman riesgos por industria (voladura y polvo en minería, gas sulfhídrico en oil & gas, arco eléctrico en electricidad) y la regla «si difieren, vale el procedimiento más exigente» | El producto es multi-industria (ADR-A11) | bloque B | 🔴 ideal que lo mire un ingeniero de seguridad |
| 4 | El alcance de Quirqui suma Pañol y Tareas | Las herramientas de Pañol ya existen y las de Tareas están en construcción | `prompts/quirqui.md` | 🟢 |
| 5 | Imágenes de los personajes: tapé la marca de agua del generador, fondo transparente, 512×512 | Para usarlas en el panel y en avisos | PR #661 | 🟡 mirá que la marca de agua no se note |
| 6 | Enlace directo a pantallas: el agente escribe `[texto](tools:ruta)` y el panel lo convierte en un enlace que navega dentro de Tools; la ruta sale del catálogo de DocTest | Decisión del PM en AGE-UC-004; así el modelo no inventa rutas | PR #662 | 🟢 |
| 7 | Los motivos rápidos del 👎 usan las categorías que ya existían en la base: «No era eso» → no entendió, «Dato equivocado» → respuesta incorrecta, «No se entiende» → otro | No hace falta cambiar la base | PR #662 | 🟢 |

| 8 | Lectura de Tareas: "finalizado" es un estado que contiene FINALIZADO; "atrasada" usa el fin planificado o, si no tiene, la fecha asignada; "sin asignar" es una tarea sin responsable | Son las reglas más simples que coinciden con cómo guarda Tareas los datos | PR #665, `doc/agente/analisis-impacto-tar-lectura.md` | 🔴 toca WSO2 (núcleo): aprobar el análisis. **Orden de despliegue: con #640 y #645 o después, nunca antes** (si no, se verían tareas de otras empresas) |
| 9 | Quirqui propone "tus tareas atrasadas" en cualquier pantalla, sin enlace a ayuda porque todavía no hay manual de Tareas | Aplica tu decisión de AGE-UC-003 | PR #666 | 🟢 |
| 10 | Los avisos de una meta en riesgo siguen yendo a quien la cargó (D-94), no a todos los administradores (D-85) | Mandar a todos necesita cambiar el mecanismo de avisos de Tools (núcleo) y saber quiénes son los administradores, que llega con Dnato v3 | sin cambios | 🟡 |
| 11 | Un motivo de calificación desconocido se rechaza con un error claro (422) en lugar de un error interno | Lo encontré corriendo las pruebas de la API | PR #662 | 🟢 |
| 12 | Recomendaciones de partes sin usar: catálogo de 7 (metas, preventivo, punto de pedido, certificaciones, movimientos de stock, depósitos, pañol), máximo 3 a la vez, "no me interesa" las esconde 30 días para toda la empresa | Reglas sobre datos, sin el modelo, para que cada cifra tenga fuente | PR #663, `doc/agente/funciones-sin-usar.md` | 🟡 mirá si el catálogo es el correcto |

*(La tabla se completa a medida que avanzo.)*
