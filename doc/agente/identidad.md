# Identidad de los agentes — Kuntur, Quirqui y Faustino

## Objetivo

Qué es: la ficha de cada personaje (quién es, cómo se ve, cómo habla), el estilo gráfico común, los estados que necesita la interfaz y el procedimiento para generar y animar los avatares con modelos gratuitos. Para quién: el PM, que aprueba los personajes, y quien genere las imágenes o construya el componente de avatar (tareas AGENTE-ID-03 a ID-06). Cuándo leerlo: antes de generar cualquier imagen y antes de tocar el componente `avatar_agente`. Qué NO cubre: qué hace cada agente (eso está en [`AGENTES_TRAZALOG_ARQUITECTURA_FUNCIONAL.md`](../v3/AGENTES_TRAZALOG_ARQUITECTURA_FUNCIONAL.md)) ni el código del componente.

**Estado:** propuesta para aprobación del PM (2026-10-27). Lo marcado como **[a definir por el PM]** se completa antes de generar.

---

## Reglas comunes

- **Configurables solo por Trazalog**: nombre, avatar y personalidad viven en la configuración del agente (`agente.agente`) y en `assets/agentes/<clave>/`. Son **iguales para todos los clientes**.
- **Siempre visibles**: cada vez que se usa un agente aparece su nombre y su avatar; **toda notificación** va firmada por el agente que la manda, con su avatar.
- **Un estilo para los tres**: tienen que verse como parte de la misma familia.
- **Personajes, no mascotas**: son profesionales que trabajan en la industria. Simpáticos, nunca infantiles ni caricaturas grotescas.

## Estilo gráfico común

| Aspecto | Propuesta |
|---|---|
| Técnica | Ilustración digital semirrealista, línea limpia, sombreado suave; legible a 48 px |
| Encuadre | Busto (de los hombros para arriba), tres cuartos de perfil mirando hacia el texto |
| Fondo | Transparente (PNG/WebP con canal alfa) |
| Paleta | Colores de la marca Trazalog **[a definir por el PM: pasar los códigos]** + los propios de cada personaje |
| Elementos de seguridad | Casco, lentes y chaleco reflectivo, consistentes con equipo de protección real |
| Lo que hay que evitar | Logos de empresas reales, banderas, texto dentro de la imagen |

## Los personajes

### 🦅 Kuntur — el Coach

| | |
|---|---|
| Rol | Coach del administrador: objetivos, desvíos, planes de acción, seguimiento |
| Personaje | Cóndor andino humanizado |
| Vestimenta | Ropa de trabajo de minería / oil & gas de supervisor: casco blanco, chaleco reflectivo, camisa de trabajo; plumaje negro con el collar blanco característico del cóndor |
| Actitud visual | Mirada atenta y serena, de quien ve el panorama desde arriba |
| Cómo habla | Directo, con datos, sin rodeos; trata al administrador de "vos"; propone, nunca ordena; cuando algo no funcionó lo dice |
| Ejemplo de frase | "El cumplimiento del preventivo bajó a 72 %. Te muestro por qué y te propongo un plan." |

### 🦔 Quirqui — el Asistente

| | |
|---|---|
| Rol | Asistente del equipo: guía en cada pantalla, responde, avisa, mide |
| Personaje | Quirquincho (armadillo) humanizado |
| Vestimenta | Minero de terreno: casco amarillo con linterna, chaleco reflectivo, overol; su caparazón como parte del "equipo de protección" |
| Actitud visual | Cercano, activo, siempre listo para ayudar |
| Cómo habla | Cálido, práctico, tuteo argentino; frases cortas; siempre ofrece el siguiente paso |
| Ejemplo de frase | "Tenés dos órdenes vencidas en equipos críticos. ¿Arrancamos por la del compresor?" |

### 🎩 Faustino — el Entrevistador

| | |
|---|---|
| Rol | Entrevistador de expertos: captura el conocimiento de la industria |
| Personaje | Humano con el aire de Domingo Faustino Sarmiento —el software es de San Juan—: rostro ancho, frente amplia, patillas; mayor, sabio, curioso |
| Vestimenta | Mezcla de época y faena: levita o chaqueta oscura con un casco de seguridad en la mano o bajo el brazo, libreta de notas |
| Actitud visual | Escucha con interés genuino, como un maestro que aprende |
| Cómo habla | Respetuoso y curioso; repregunta, pide ejemplos concretos; nunca apura |
| Ejemplo de frase | "Contame la última vez que esa bomba falló sin aviso. ¿Qué fue lo primero que notaste?" |

## Estados que necesita la interfaz

Cada personaje tiene **la misma lista de estados**; el componente `avatar_agente` cambia de uno a otro según lo que pasa en la corrida.

| Estado | Cuándo se muestra | Expresión |
|---|---|---|
| `saludo` | Al abrir el panel o la pantalla | Sonrisa, gesto de saludo |
| `escuchando` | Mientras el usuario escribe | Atento, mirando al texto |
| `pensando` | Mientras el motor procesa | Mirada hacia arriba, mano en el mentón o equivalente |
| `hablando` | Mientras se muestra la respuesta | Boca entreabierta, gesto explicativo |
| `alerta` | En notificaciones y avisos proactivos | Serio, mano levantada o señalando |
| `despedida` | Al cerrar o terminar una sesión | Gesto amable |

Formato de salida: `assets/agentes/<clave>/<estado>.webp` (512×512, fondo transparente) y además `assets/agentes/<clave>/icono.png` (192×192) para las notificaciones push, que solo aceptan una imagen fija. Claves: `kuntur`, `quirqui`, `faustino`.

## Cómo se generan (tarea AGENTE-ID-03)

La máquina de desarrollo no tiene GPU, así que todo se hace en **servicios gratuitos alojados**. Se usan solo modelos con licencia que permite uso comercial.

| Paso | Herramienta | Licencia | Dónde se ejecuta |
|---|---|---|---|
| 1. Bocetos para elegir el estilo (opcional) | Gemini "Nano Banana" | Propietaria; nivel gratuito con marca de agua | Google AI Studio, en el navegador |
| 2. Imagen base de cada personaje | **Qwen-Image** | Apache 2.0 | Space de Hugging Face, en el navegador |
| 3. Estados a partir de la base | **Qwen-Image-Edit** | Apache 2.0 | Space de Hugging Face, en el navegador |
| 4. Quitar fondo y normalizar | Herramienta libre de quitado de fondo | Libre | Terminal local o navegador |
| 5. Loop de video del reposo (opcional) | Wan 2.2 imagen-a-video | Apache 2.0 | Space de Hugging Face, en el navegador |

Reglas del proceso:

1. **Las imágenes de los bocetos (paso 1) no se usan como arte final**: tienen marca de agua y los términos del nivel gratuito no aseguran uso comercial.
2. **Todos los estados se derivan de la misma imagen base** con Qwen-Image-Edit ("el mismo personaje, ahora pensando"); nunca se genera un estado desde cero, porque el personaje cambia.
3. **Se registran el prompt y la semilla** de cada imagen final en la tabla de abajo, para poder regenerar.
4. El PM aprueba la imagen base de cada personaje antes de derivar los estados.

### Registro de generación

| Personaje | Estado | Modelo | Prompt | Semilla | Fecha | Aprobado |
|---|---|---|---|---|---|---|
| *(se completa en AGENTE-ID-03)* | | | | | | |

## El componente (AGENTE-ID-05, hecho)

`application/modules/traz-comp-agente/views/avatar.php` define una sola vez el objeto global `TZAgente`:

| Función | Qué hace |
|---|---|
| `TZAgente.avatar(agente, estado, grande)` | Devuelve el HTML del avatar. `agente` es lo que devuelve `GET /agentes` (`clave`, `nombre`, `avatar`) |
| `TZAgente.estado(elemento, estado)` | Cambia el estado de un avatar ya pintado y recarga la imagen de ese estado |

- **Sin imágenes funciona igual**: busca `assets/agentes/<avatar>/<estado>.webp` y, si no existe, muestra un círculo con la inicial y un color por agente (provisorios hasta tener los colores de la marca: `quirqui` azul, `kuntur` gris oscuro, `faustino` marrón). Cuando se generen las imágenes (AGENTE-ID-03), alcanza con dejar los archivos en esa carpeta: **no hay que tocar código**.
- **El panel de Quirqui lo usa** y toma nombre y avatar de la configuración de los agentes (`GET /agentes`), no de textos fijos. Estados en uso: `saludo` al abrir, `pensando` mientras espera, `hablando` unos segundos al responder, `alerta` si hay una propuesta urgente (lote vencido) y `despedida` al cerrar. `escuchando` todavía no se usa.
- **Animación por CSS** (respirar, balanceo, latido de alerta); quien tiene activada la preferencia de menos movimiento del sistema no la recibe.
- La clave y el nombre se sanean antes de llegar al HTML y a la URL.

## Animación (tarea AGENTE-ID-04)

Se anima con **CSS sobre las imágenes fijas** (parpadeo, respiración, leve balanceo, transición entre estados): pesa casi nada, anda en cualquier celular y no depende de video. El loop de video del paso 5 es opcional y solo para el reposo en el panel.

## Pendiente legal

En Argentina la Ley 11.723 protege obras con autor humano, así que el derecho de autor sobre una imagen generada por IA es incierto. La protección de los personajes va por **registro de marca** de los nombres y de las figuras. Queda dentro de la revisión legal única del frente (AGENTE-LEGAL-01).
