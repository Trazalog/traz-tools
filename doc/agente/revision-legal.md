# Revisión legal de los agentes de IA de Trazalog

## Objetivo

Qué es: el resumen para que un abogado revise, en una sola pasada, los temas legales de los agentes de inteligencia artificial de Trazalog Tools (tarea AGENTE-LEGAL-01, decisión D12 del PM: «legal al final, en una sola revisión»). Para quién: el abogado que contrate el PM; está escrito para alguien que no conoce el producto. Cuándo leerlo: antes de ofrecer los agentes al primer cliente real. Qué NO cubre: los contratos comerciales con clientes ni la política de precios. La versión para mandarle al abogado, en lenguaje jurídico, es [`consulta-legal-abogado.md`](../historial/agente/consulta-legal-abogado.md).

| Campo | Valor |
|---|---|
| Fecha | 2026-11-22 |
| Preparado por | Claude Code, por pedido del PM |
| Estado | Para enviar al abogado. **No es opinión legal**: lo de abajo describe el producto y lista las preguntas. Las referencias a leyes son orientativas, para ubicar el tema |

---

## 1. Qué es el producto, en pocas palabras

Trazalog Tools es un sistema de gestión para pymes industriales (minería, petróleo y gas, electricidad): mantenimiento, almacenes, herramientas y tareas. Suma tres asistentes de inteligencia artificial:

| Asistente | Quién lo usa | Qué hace |
|---|---|---|
| **Quirqui** | Todo el personal de la empresa cliente | Responde preguntas sobre cómo usar el sistema y sobre los datos de la empresa; propone el siguiente paso; avisa cosas urgentes (material vencido, tareas atrasadas) |
| **Kuntur** | Solo el administrador de la empresa cliente | Lo ayuda a poner en marcha el sistema, fijar metas sobre indicadores, propone planes de acción cuando una meta viene mal y mide si funcionaron |
| **Faustino** | Expertos de la industria que Trazalog convoca | Los entrevista para registrar conocimiento técnico, que después usan los otros dos asistentes |

Los tres son personajes dibujados (un quirquincho, un cóndor y un señor parecido a Sarmiento) con nombre propio, iguales para todos los clientes.

---

## 2. Los temas a revisar

### 2.1 El aviso de medición a los empleados

**Qué pasa:** el administrador de una empresa puede pedir indicadores de cumplimiento sobre el trabajo que cada persona carga en el sistema (por ejemplo, tareas cerradas en plazo). Las conversaciones con Quirqui se guardan para mejorar el asistente. **El contenido de lo que cada persona conversa no se le muestra al administrador** (está bloqueado por diseño). La persona no recibe un aviso cada vez que se la mide; en cambio, el panel de Quirqui muestra **siempre** este texto, hoy provisorio:

> Lo que hables con Quirqui se usa para medir indicadores de tu empresa. **¿Qué se mide?** Se registran tus consultas y las respuestas para mejorar el asistente. El administrador de tu empresa puede pedir indicadores de cumplimiento sobre el trabajo que cargás en Trazalog —por ejemplo, tareas cerradas en plazo—. Lo que conversás con Quirqui no se le muestra.

**Preguntas:**
1. ¿El texto alcanza como información al trabajador sobre el control de su desempeño (Ley de Contrato de Trabajo, arts. 70 a 72, controles del empleador)? ¿Qué hay que cambiar?
2. ¿Hace falta un consentimiento expreso (por ejemplo, un «Entendido» la primera vez) o alcanza con el aviso permanente?
3. ¿Quién es responsable frente al trabajador: Trazalog o la empresa cliente que pide la medición? ¿Cómo lo dejamos escrito en los términos de uso?

### 2.2 Datos personales (Ley 25.326)

**Qué pasa:**
- Se guardan las consultas y respuestas, con el usuario y la empresa. Cada empresa ve solo lo suyo (aislamiento técnico verificado con pruebas automáticas).
- Para responder, el sistema manda la pregunta y los datos necesarios a **un modelo de inteligencia artificial de un proveedor externo** (hoy a través de OpenRouter, con servidores fuera de la Argentina).
- Cuando el administrador sube una planilla de su empresa para cargarla, al modelo se le mandan **solo los encabezados y unas 20 filas** (decisión del PM, sujeta a esta revisión).
- La búsqueda en internet se hace con un buscador propio y no manda datos de la empresa (está prohibido por las instrucciones del asistente).
- El conocimiento que aporta un experto entrevistado por Faustino se comparte entre todos los clientes, sin datos de la empresa de origen.

**Preguntas:**
1. ¿Mandar datos a un proveedor de inteligencia artificial fuera del país es una transferencia internacional que requiere algo especial? ¿Qué tiene que decir el contrato con el proveedor?
2. ¿Hay que registrar la base de datos de los asistentes ante la Agencia de Acceso a la Información Pública?
3. ¿Cuánto tiempo podemos guardar las conversaciones? ¿Hay que ofrecer borrarlas a pedido?
4. ¿Qué cláusula hace falta con los expertos que entrevista Faustino para que su conocimiento se pueda usar con todos los clientes?

### 2.3 Responsabilidad por lo que dice el asistente

**Qué pasa:** los asistentes **dicen cómo hacer las cosas, pero no las hacen** (salvo Kuntur, que carga datos de configuración y crea planes **solo después de que el administrador lo confirma**). Toda cifra tiene que salir de los datos del sistema o de una fuente citada; si no, la respuesta se bloquea. Cuando explica una tarea sobre un equipo, Quirqui incluye advertencias de seguridad obligatorias (bloqueo de energías, permisos de trabajo, riesgos de cada industria) y aclara que manda el procedimiento de la empresa.

**Preguntas:**
1. ¿Qué aviso de limitación de responsabilidad hace falta (en el panel y en los términos de uso) para una recomendación técnica en un ambiente industrial de riesgo?
2. ¿Cambia algo que el asistente sea «de inteligencia artificial»? Hoy lo dice si se lo preguntan.

### 2.4 Imágenes de los personajes

**Qué pasa:** las imágenes de los tres personajes las generó el PM con un modelo de imágenes de uso libre (Qwen-Image, licencia Apache 2.0), en un servicio web de Hugging Face. Uno de los personajes está inspirado en el aspecto de Domingo F. Sarmiento.

**Preguntas:**
1. ¿Quién es titular de los derechos de una imagen generada con inteligencia artificial? ¿Podemos protegerla?
2. ¿Hay algún problema en usar un personaje parecido a una figura histórica como Sarmiento?
3. ¿Conviene registrar los personajes como marca figurativa?

### 2.5 Nombres de los personajes como marca

**Qué pasa:** se usan los nombres **Kuntur**, **Quirqui** y **Faustino** en el producto y en los avisos.

**Preguntas:**
1. ¿Se pueden registrar ante el INPI? ¿En qué clases (software, servicios)?
2. ¿Hay que verificar antes que no estén registrados por otros?

---

## 3. Qué le pedimos al abogado

- Respuestas a las preguntas de la sección 2, priorizando lo que **frena** ofrecer el producto a un cliente.
- El texto definitivo del aviso de medición (2.1) y del aviso de limitación de responsabilidad (2.3).
- Una lista de lo que tiene que ir en los términos de uso y en el contrato con los clientes.

Contacto para dudas técnicas: el PM de Trazalog.
