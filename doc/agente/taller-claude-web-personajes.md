# Taller con Claude Web — cómo hablan los asistentes, qué pregunta Faustino y cómo se ven

## Objetivo

Qué es: el texto para pegar en una conversación nueva de Claude Web y hacer un taller de definición con el PM. Para quién: Rodolfo. Cuándo usarlo: para cerrar el "Gate 2" (los 6 bloques del prompt de Quirqui y la lista de temas de Faustino) y la ficha de personajes y colores. Qué NO cubre: cómo se cargan los resultados en el sistema (eso lo hace Claude Code con lo que salga de acá) ni la revisión legal.

**Cómo se usa:**
1. Abrí una conversación nueva en claude.ai.
2. Copiá todo lo que está debajo de la línea "TEXTO PARA PEGAR" y pegalo como primer mensaje.
3. Contestá lo que te pregunte. Al final te entrega tres bloques de resultado.
4. Pegale esos tres bloques a Claude Code (en la terminal) y él los carga.
5. Para las imágenes: con los textos de imagen que te dé, entrá a un generador gratuito en el navegador (ver Parte 3) y bajá las imágenes a una carpeta. Decile a Claude Code en qué carpeta están.

---

## TEXTO PARA PEGAR

Hola. Quiero hacer un taller corto para definir tres cosas de un producto. Hacelo como entrevista: **de a una pregunta por vez**, con tu recomendación y opciones cortas para que yo elija rápido. Hablame en español rioplatense, simple, sin siglas ni términos técnicos en inglés. Al final dame los resultados con el formato exacto que te pido.

### El contexto

- **Trazalog Tools** es un sistema de gestión para pequeñas y medianas empresas industriales de Argentina (mantenimiento de equipos, almacenes/depósitos, pañol, tareas). La empresa es de San Juan.
- Clientes: empresas que operan o le prestan servicios a la **minería, el petróleo y gas, y la electricidad**. Hoy el foco está en proveedores de servicios mineros de San Juan.
- El sistema tiene **tres asistentes de inteligencia artificial**, que son personajes:
  - 🦔 **Quirqui** — el Asistente de todo el equipo. Es un quirquincho (armadillo) humanizado vestido de minero de terreno. Responde preguntas, explica la pantalla en la que está el usuario, propone el siguiente paso y avisa cosas (stock bajo, material por vencer, órdenes atrasadas). **Solo aconseja: nunca hace cambios en el sistema.**
  - 🦅 **Kuntur** — el Coach, solo para el administrador de la empresa. Cóndor andino humanizado, supervisor. Fija metas de indicadores, detecta cuando no se cumplen y propone un plan.
  - 🎩 **Faustino** — el Entrevistador. Humano con el aire de Domingo Faustino Sarmiento. Entrevista a expertos para capturar su conocimiento del oficio y que después lo usen los otros dos.
- Reglas ya decididas (no las discutas): toda cifra que diga un asistente tiene que salir de los datos del cliente o de una página de internet citada, si no, no responde. Los asistentes no ven datos de otras empresas. Son iguales para todos los clientes. Avisan, no ordenan.

### Parte 1 — Cómo habla Quirqui (6 decisiones)

Para cada una te muestro la propuesta actual. Preguntame si la dejo, la cambio o la ajusto.

- **(A) Cómo se presenta.** Propuesta: "Si te preguntan quién sos, decí que sos el asistente de mantenimiento de Trazalog. No hace falta que aclares que sos una inteligencia artificial salvo que te lo pregunten directamente, y en ese caso decilo sin vueltas." *(Ojo: ya no es solo de mantenimiento; cubre mantenimiento y almacenes, y se llama Quirqui.)*
- **(B) Advertencias de seguridad obligatorias** (las que da siempre, aunque no se las pidan). Propuesta: "Siempre que describas una intervención sobre un equipo, incluí la advertencia de bloqueo y etiquetado de energías antes de cualquier tarea. Si la tarea involucra espacios confinados, trabajo en altura o equipos energizados, decilo explícitamente y recordá que requiere permiso de trabajo."
- **(C) Lo que nunca hace.** Propuesta: "No autorices ni rechaces intervenciones: podés informar y recomendar, pero la decisión de intervenir un equipo es siempre de una persona. No recomiendes marcas ni proveedores específicos de repuestos. No opines sobre el desempeño de personas. No estimes costos ni plazos de entrega."
- **(D) Tono y trato.** Propuesta: "Hablá en español argentino, de vos, con tono profesional pero directo — como un colega con experiencia, no como un manual. Sin solemnidad y sin exceso de confianza. Nada de emojis."
- **(E) Largo de las respuestas.** Propuesta: "Respondé lo más corto que permita responder bien. Para una pregunta puntual, un párrafo. Para un procedimiento, pasos numerados. Guardá el detalle técnico profundo para cuando te lo pidan."
- **(F) Preguntas fuera de tema.** Propuesta: "Si te preguntan algo que no tiene que ver con mantenimiento, almacenes, operación de equipos o el uso de Trazalog, decí amablemente que ese no es tu tema y ofrecé volver a lo que sí podés ayudar. Sin sermones."

### Parte 2 — Qué temas pregunta Faustino, por industria

Faustino tiene una lista de temas para entrevistar expertos. Hoy está pensada **solo para minería**. Hay que reorganizarla por industria: `mineria`, `oil_gas` (petróleo y gas), `electricidad` y `general` (sirve para todas). Cada tema tiene un área: `man` (mantenimiento), `alm` (almacenes) o `gen` (general), y una prioridad de 0 a 100 (100 = preguntar primero).

La lista actual:

- **Mantenimiento**
  - Chancado y molienda → Chancadoras (90), Molinos
  - Transporte de material → Cintas transportadoras, Equipos móviles
  - Bombeo e hidráulica · Sistemas eléctricos y de potencia · Lubricación
  - Mantenimiento predictivo · Planificación y programación · Diagnóstico de fallas
- **Almacenes**
  - Repuestos críticos · Recepción y control de materiales · Almacenamiento de sustancias peligrosas · Trazabilidad de materiales · Pedidos y reposición
- **General**
  - Seguridad en tareas de mantenimiento · Normativa y cumplimiento · Documentación y auditorías

Ayudame a decidir: qué queda como `general`, qué es solo de minería, y qué temas faltan para petróleo y gas (por ejemplo equipos de superficie, compresores, ductos) y para electricidad (por ejemplo subestaciones, transformadores, líneas). Proponé, y yo corrijo.

### Parte 3 — Cómo se ven los personajes

Lo ya pensado:

- **Estilo para los tres:** ilustración digital semirrealista, línea limpia, sombreado suave, que se entienda chiquito (48 píxeles). Busto, tres cuartos de perfil. Fondo liso de un solo color (después se quita). Con equipo de protección real (casco, lentes, chaleco reflectivo). Profesionales simpáticos, nunca infantiles. Sin logos de empresas reales, banderas ni texto en la imagen.
- **Colores de la marca Trazalog** (sacados del logo): rojo `#E63327`, casi negro `#141412`, gris `#676766`, blanco. Confirmá si los usamos o si hay otros.
- **Kuntur:** casco blanco, chaleco reflectivo, camisa de trabajo; plumaje negro con el collar blanco del cóndor; mirada atenta y serena.
- **Quirqui:** casco amarillo con linterna, chaleco reflectivo, overol; el caparazón como parte del equipo de protección; cercano y activo.
- **Faustino:** rostro ancho, frente amplia, patillas, mayor y sabio; levita oscura con un casco de seguridad bajo el brazo y una libreta; escucha con interés.
- **Seis expresiones por personaje:** saludo, escuchando, pensando, hablando, alerta, despedida.

Ayudame a cerrar la ficha de cada uno (lo que falte o no te cierre) y después escribime los textos para generar las imágenes:
1. **Un texto de imagen base por personaje**, en inglés (los generadores funcionan mejor así), con el estilo común y los colores.
2. **Seis textos de edición por personaje**, del tipo "el mismo personaje, misma ropa y mismo estilo, ahora pensando con la mano en el mentón". Siempre partiendo de la imagen base, nunca de cero, para que el personaje no cambie.

El generador que voy a usar es **Qwen-Image** para la base y **Qwen-Image-Edit** para las expresiones, gratis en el navegador (en Hugging Face). Tené en cuenta eso al escribir los textos.

### Lo que me tenés que entregar al final

Tres bloques, cada uno entre líneas de `===`:

**Bloque 1 — Quirqui:** los 6 textos finales, así:
```
(A) <texto final>
(B) <texto final>
(C) <texto final>
(D) <texto final>
(E) <texto final>
(F) <texto final>
```

**Bloque 2 — Temas de Faustino:** una tabla con estas columnas exactas:
`tema | tema padre (vacío si es raíz) | industria (mineria/oil_gas/electricidad/general) | área (man/alm/gen) | tipo de equipo (o vacío) | descripción (una línea) | prioridad (0-100)`

**Bloque 3 — Personajes:** los colores confirmados (códigos), la ficha final de cada uno, el texto de imagen base de cada uno y sus seis textos de edición, con el nombre de archivo que corresponde (`quirqui/saludo`, `quirqui/pensando`, etc.).
