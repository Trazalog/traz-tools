# Consulta jurídica: asistentes de inteligencia artificial de Trazalog Tools

## Objetivo

Qué es: la consulta formal que Trazalog dirige a su asesor legal sobre los asistentes de inteligencia artificial incorporados a su sistema de gestión. Para quién: un abogado o abogada en ejercicio en la República Argentina, sin conocimientos previos de informática ni del producto. Cuándo leerlo: antes de ofrecer los asistentes a la primera empresa cliente real. Qué NO cubre: la política comercial ni los precios. Tampoco reemplaza el resumen interno [`revision-legal.md`](revision-legal.md), del que este documento es la versión dirigida al profesional.

| Campo | Valor |
|---|---|
| Consultante | Trazalog (en adelante, «Trazalog» o «la consultante») |
| Fecha | 24 de noviembre de 2026 |
| Carácter | Consulta. Las normas citadas son una referencia orientativa para ubicar cada tema. El encuadre jurídico lo determina el profesional |
| Convención | Lo marcado **[a confirmar por Trazalog]** es un hecho que la consultante debe verificar antes de que el profesional se apoye en él |

---

## 1. Antecedentes

### 1.1 La consultante y su producto

Trazalog desarrolla y comercializa **Trazalog Tools**, un sistema informático de gestión que las empresas contratan para administrar su operación diaria por internet:

- mantenimiento de equipos;
- depósitos y materiales;
- herramientas;
- tareas del personal.

Los clientes son pequeñas y medianas empresas industriales, hoy de minería, petróleo y gas y energía eléctrica, con foco inicial en la provincia de San Juan.

Cada empresa cliente («la empresa cliente») da acceso al sistema a sus propios empleados mediante usuario y contraseña. Trazalog presta el servicio y aloja la información. La empresa cliente es quien carga sus datos y decide qué hace con ellos.

### 1.2 Qué es un «asistente de inteligencia artificial»

Es un programa con el que el usuario conversa por escrito, como en un servicio de mensajería. El usuario pregunta en lenguaje corriente («¿qué equipos tienen el mantenimiento atrasado?») y el programa contesta en el mismo lenguaje.

Para redactar la respuesta, el sistema envía la pregunta, junto con la información necesaria para contestarla, a un **modelo de lenguaje**. Se trata de un programa de un tercero, especializado en producir texto, que funciona en servidores de ese tercero y no en los de Trazalog. El modelo devuelve el texto y el sistema se lo muestra al usuario.

### 1.3 Los tres asistentes

Trazalog presentará los asistentes como tres personajes ilustrados, con nombre y figura propios. Son iguales para todas las empresas clientes y solo Trazalog puede modificarlos.

| Personaje | Figura | Quién lo usa | Qué hace |
|---|---|---|---|
| **Quirqui** | Un quirquincho con ropa de minero | Todo el personal de la empresa cliente | Explica cómo usar el sistema; responde con los datos de la empresa; sugiere el próximo paso; avisa situaciones urgentes (materiales por vencer, tareas atrasadas) |
| **Kuntur** | Un cóndor con ropa de supervisor | Solo el administrador de la empresa cliente | Lo ayuda a configurar el sistema y a fijar metas sobre indicadores. Cuando una meta no se cumple, propone un plan de trabajo y después mide si funcionó |
| **Faustino** | Un hombre mayor con el aspecto de Domingo Faustino Sarmiento | Expertos de la industria convocados por Trazalog | Los entrevista para registrar su conocimiento técnico, que luego usan los otros dos asistentes con todas las empresas clientes |

### 1.4 Reglas de funcionamiento ya adoptadas

- **Los asistentes aconsejan, no ejecutan.** Indican cómo hacer las cosas pero no las hacen. Hay una excepción: Kuntur puede cargar datos de configuración y crear un plan de trabajo, siempre que el administrador lo confirme expresamente con un botón.
- **Toda cifra debe tener origen.** Un control automático revisa cada número de la respuesta. Si no sale de los datos del sistema o de una fuente de internet citada, la respuesta se bloquea y el usuario ve «no tengo datos para responder eso».
- **Separación entre empresas.** Cada empresa cliente ve solo su información. La separación está implementada en la base de datos y se verifica con pruebas automáticas.
- **Advertencias de seguridad.** Cuando el asistente explica una tarea sobre un equipo, agrega advertencias obligatorias de seguridad industrial y aclara que prevalece el procedimiento de la empresa.

### 1.5 Qué información se registra y quién accede

| Información | Quién la produce | Quién puede verla | Plazo de conservación |
|---|---|---|---|
| Cada consulta y su respuesta, con el usuario, la empresa y la fecha | El empleado al conversar | Trazalog, para mejorar el servicio. **No se le muestra al administrador de la empresa cliente** | Hoy no se borra automáticamente **[a definir; ver consulta 3]** |
| Indicadores de cumplimiento sobre el trabajo cargado en el sistema (p. ej., tareas cerradas en plazo), por actividad, por equipo o **por persona** | El sistema, a pedido del administrador | El administrador de la empresa cliente | Mientras dure la medición pedida **[a confirmar por Trazalog]** |
| Lo que el administrador le cuenta a Kuntur para configurar el sistema | El administrador | La empresa cliente y Trazalog | Sin plazo definido **[a confirmar por Trazalog]** |
| Entrevistas a expertos (transcripción completa) y el conocimiento que se extrae de ellas | El experto | Trazalog. El conocimiento se usa con todas las empresas clientes, sin datos de la empresa de origen | Sin plazo definido |
| Planillas que sube el administrador para cargar datos | El administrador | La empresa cliente y Trazalog | **[a confirmar por Trazalog]** |

**Lugar de alojamiento:** los servidores de Trazalog están en Google Cloud, un servicio de alojamiento de Google. La región física (país) del centro de datos es **[a confirmar por Trazalog]**.

---

## 2. Consultas

### Consulta 1. Aviso de medición al personal de la empresa cliente

**Hechos.**

- El administrador de la empresa cliente puede pedir que se midan indicadores de cumplimiento del trabajo que el personal carga en el sistema. La medición puede ser por actividad, por equipo o **por persona**.
- **Por decisión de diseño, la persona medida no recibe una notificación individual cada vez que se la mide.**
- En su lugar, el panel de Quirqui muestra siempre el siguiente aviso, cuyo texto es provisorio:

> Lo que hables con Quirqui se usa para medir indicadores de tu empresa. **¿Qué se mide?**

- Al tocar «¿Qué se mide?» se despliega este detalle:

> Se registran tus consultas y las respuestas para mejorar el asistente. El administrador de tu empresa puede pedir indicadores de cumplimiento sobre el trabajo que cargás en Trazalog —por ejemplo, tareas cerradas en plazo—. Lo que conversás con Quirqui no se le muestra.

- Hoy no se pide aceptación expresa del aviso: el aviso está, pero el usuario no hace clic en «Acepto».

**Duda jurídica.** Si el aviso transcripto cumple el deber de informar al trabajador sobre los controles de su desempeño, y si la falta de notificación individual de cada medición es válida.

**Marco orientativo.**

- Ley de Contrato de Trabajo 20.744, arts. 70 a 72: controles del empleador, dignidad del trabajador y conocimiento de los sistemas de control.
- Ley 25.326 de Protección de los Datos Personales: arts. 4 (calidad de los datos), 5 (consentimiento) y 6 (información al titular).

**Preguntas concretas.**

- 1.a. ¿Alcanza el aviso permanente o hace falta una notificación individual cuando se pide una medición sobre una persona determinada?
- 1.b. ¿Hace falta un consentimiento expreso, por ejemplo un «Entendido» la primera vez? ¿O la base legal es la relación laboral y no se requiere consentimiento?
- 1.c. ¿Qué texto debe tener el aviso? Le pedimos la redacción final.
- 1.d. ¿El deber de informar al trabajador es de la empresa cliente (empleadora) o de Trazalog? ¿Cómo debe reflejarse en el contrato con la empresa cliente?

### Consulta 2. Rol de Trazalog frente a los datos personales

**Hechos.**

- La empresa cliente carga los datos de su personal y decide qué medir.
- Trazalog aloja esos datos, los procesa para prestar el servicio y conserva las conversaciones para mejorar los asistentes.

**Duda jurídica.** Si Trazalog actúa como responsable de la base de datos, como prestador de servicios de tratamiento por cuenta de la empresa cliente, o con los dos roles según el dato.

**Marco orientativo.**

- Ley 25.326, arts. 2 (definiciones), 9 y 10 (seguridad y confidencialidad), 21 (registro de bases de datos) y 25 (prestación de servicios de tratamiento por cuenta de terceros).
- Normativa de la Agencia de Acceso a la Información Pública.

**Preguntas concretas.**

- 2.a. ¿Qué rol tiene Trazalog respecto de los datos operativos de la empresa cliente? ¿Y respecto de las conversaciones que conserva para mejorar los asistentes?
- 2.b. ¿Debe Trazalog inscribir alguna base de datos ante la Agencia de Acceso a la Información Pública?
- 2.c. ¿Qué cláusulas debe tener el contrato con la empresa cliente (anexo de tratamiento de datos)? Le pedimos un modelo.

### Consulta 3. Conservación de las conversaciones y pedidos de supresión

**Hechos.** Las consultas y respuestas se guardan con identificación del usuario. Hoy no hay un plazo de borrado automático ni un procedimiento para que un empleado pida eliminar sus conversaciones.

**Duda jurídica.** Plazo razonable de conservación y deberes ante el ejercicio de los derechos del titular.

**Marco orientativo.** Ley 25.326, arts. 4 inc. 7 (destrucción de los datos cuando dejan de ser necesarios), 14 (acceso) y 16 (rectificación, actualización y supresión).

**Preguntas concretas.**

- 3.a. ¿Qué plazo máximo de conservación recomienda?
- 3.b. ¿Quién recibe y resuelve un pedido de supresión: la empresa cliente o Trazalog? ¿Con qué plazo de respuesta?

### Consulta 4. Envío de datos a un proveedor de inteligencia artificial en el exterior

**Hechos.**

- Para que el modelo de lenguaje redacte la respuesta, el sistema le envía:
  - la pregunta del usuario;
  - las instrucciones del asistente;
  - el conocimiento técnico pertinente;
  - **los datos de la empresa cliente que el asistente consultó para responder**. Por ejemplo, el estado del stock o un listado de tareas, que puede incluir nombres de personas responsables.
- No se envían el nombre ni el usuario de quien pregunta como dato aparte. Sí pueden viajar dentro de la información consultada.
- Si el administrador sube una planilla, al modelo se le envían solo los encabezados y unas 20 filas.
- El sistema también envía la pregunta a un servicio externo que la convierte en un formato numérico para buscar el conocimiento pertinente. Lo presta el mismo intermediario.
- El envío se hace a través de **OpenRouter**, un intermediario que deriva cada pedido a distintos proveedores de modelos de lenguaje, con servidores fuera de la Argentina, principalmente en los Estados Unidos **[a confirmar por Trazalog]**.
- En las pruebas se usan **modelos gratuitos**. Algunos proveedores de modelos gratuitos se reservan el derecho de usar lo que reciben para entrenar sus programas **[a confirmar por Trazalog en los términos de OpenRouter y de cada proveedor, y a decidir qué modelo se usa con clientes reales]**.
- Los avisos al teléfono del usuario se envían por el servicio de notificaciones de Google (Firebase). El aviso incluye un texto breve, por ejemplo «hay una tarea atrasada».

**Duda jurídica.** Si estos envíos constituyen una transferencia internacional de datos personales y qué requisitos deben cumplirse.

**Marco orientativo.**

- Ley 25.326, art. 12 (transferencia internacional) y su reglamentación.
- Disposiciones de la autoridad de aplicación sobre países con protección adecuada y cláusulas contractuales modelo.

**Preguntas concretas.**

- 4.a. ¿Es una transferencia internacional en los términos del art. 12? ¿Qué se necesita para que sea lícita: consentimiento, cláusulas contractuales o país con protección adecuada?
- 4.b. ¿Puede usarse un proveedor que se reserve el derecho de entrenar con los datos recibidos? ¿O hay que exigir por contrato que no lo haga?
- 4.c. ¿Qué hay que informar a la empresa cliente y a sus empleados sobre estos envíos?

### Consulta 5. Conocimiento aportado por los expertos (Faustino)

**Hechos.**

- Trazalog convoca a expertos de la industria. Faustino los entrevista por escrito y guarda la transcripción completa.
- Del relato se extraen «hechos» técnicos, como «tal falla suele anticiparse por tal síntoma». El experto valida esos hechos y después se usan para responder a **todas** las empresas clientes, sin indicar de qué empresa provino la experiencia.
- El sistema registra el nombre del experto y lo muestra como autor de cada hecho.
- El acuerdo con el experto sobre la titularidad de lo aportado **se gestiona fuera del sistema y hoy no existe un modelo [a confirmar por Trazalog]**.

**Duda jurídica.** Titularidad y licencia de uso del conocimiento aportado, y posible conflicto con deberes de confidencialidad del experto hacia su empleador actual o anterior.

**Marco orientativo.**

- Ley 11.723 de Propiedad Intelectual, aplicable a la expresión escrita del aporte.
- Ley 24.766 de Confidencialidad sobre información y productos.
- Código Civil y Comercial, en materia de contratos.

**Preguntas concretas.**

- 5.a. ¿Qué contrato o cesión debe firmar el experto para que Trazalog pueda usar su aporte con todos los clientes? Le pedimos un modelo.
- 5.b. ¿Cómo se evita que el experto revele información confidencial de su empleador?
- 5.c. ¿Puede mostrarse el nombre del experto como autor? ¿Con qué consentimiento?

### Consulta 6. Responsabilidad por las recomendaciones del asistente

**Hechos.**

- Los asistentes dan recomendaciones técnicas en ambientes industriales de riesgo, como mantenimiento de equipos pesados.
- Incluyen advertencias de seguridad y remiten al procedimiento de la empresa.
- Si se le pregunta, el asistente dice que es un programa de inteligencia artificial. No lo anuncia de entrada en cada respuesta **[a confirmar por Trazalog]**.

**Duda jurídica.** Alcance de la responsabilidad de Trazalog por una recomendación errónea y cómo limitarla válidamente.

**Marco orientativo.**

- Código Civil y Comercial, arts. 1708 y siguientes (responsabilidad civil) y 988 (cláusulas abusivas en contratos de adhesión).
- Ley 24.240 de Defensa del Consumidor, si corresponde por el tipo de cliente.

**Preguntas concretas.**

- 6.a. ¿Qué texto de limitación de responsabilidad debe figurar en el panel y en los términos de uso? Le pedimos la redacción.
- 6.b. ¿Conviene que el asistente informe siempre, de entrada, que es un programa de inteligencia artificial?

### Consulta 7. Derechos sobre las imágenes de los personajes generadas con inteligencia artificial

**Hechos.**

- Las imágenes de los tres personajes las generó el titular de Trazalog con un programa de generación de imágenes de uso libre, Qwen-Image. Es un programa de la empresa china Alibaba, publicado con la licencia Apache 2.0, que permite el uso comercial.
- Se usó en una página web del servicio Hugging Face.
- El titular escribió las descripciones y eligió y ajustó los resultados. No se registraron las descripciones exactas usadas.
- Las imágenes se usan en el sistema y en los avisos a los usuarios.

**Duda jurídica.** Si existe derecho de autor sobre imágenes generadas con inteligencia artificial y, si no, cómo proteger los personajes.

**Marco orientativo.**

- Ley 11.723, que protege obras con autor humano.
- Términos de uso del servicio Hugging Face y licencia Apache 2.0.

**Preguntas concretas.**

- 7.a. ¿Trazalog tiene algún derecho sobre las imágenes? ¿Qué actos de intervención humana conviene documentar para fortalecerlo?
- 7.b. ¿La licencia del programa o los términos del servicio usado imponen alguna obligación o restricción?
- 7.c. ¿Conviene encargar a un ilustrador una versión final, con cesión de derechos por contrato?

### Consulta 8. El personaje Faustino y la figura de Domingo F. Sarmiento

**Hechos.** Faustino está inspirado expresamente en el aspecto de Domingo Faustino Sarmiento: rostro, patillas y vestimenta de época. La elección rinde homenaje al origen sanjuanino del producto. El nombre «Faustino» es el segundo nombre de Sarmiento. El personaje no se presenta como Sarmiento ni usa su nombre completo.

**Duda jurídica.** Si el uso comercial de la imagen evocada de un prócer fallecido en 1888 tiene alguna restricción, y si puede afectar la registrabilidad como marca.

**Marco orientativo.**

- Código Civil y Comercial, art. 53 (derecho a la imagen, con su régimen para personas fallecidas).
- Ley de Marcas 22.362, art. 3 (signos no registrables, entre ellos los que ofendan la moral o usen símbolos patrios, y los nombres o retratos de personas sin su consentimiento o el de sus herederos).
- Ley 11.723, art. 31.

**Preguntas concretas.**

- 8.a. ¿Hay impedimento legal o riesgo de reclamo por usar un personaje parecido a Sarmiento?
- 8.b. ¿Ese parecido impide o complica registrar la figura de Faustino como marca?

### Consulta 9. Registro de los nombres y de las figuras como marca

**Hechos.** Los nombres **Kuntur**, **Quirqui** y **Faustino** y sus figuras identifican a los asistentes en el sistema y en los avisos. No se hizo ninguna búsqueda de antecedentes en el Instituto Nacional de la Propiedad Industrial (INPI) **[a confirmar por Trazalog]**.

**Marco orientativo.** Ley de Marcas 22.362 y Clasificación de Niza (en principio, clases 9 —programas informáticos— y 42 —servicios informáticos—, a criterio del profesional).

**Preguntas concretas.**

- 9.a. ¿Son registrables los tres nombres? «Kuntur» significa cóndor en quechua: ¿eso afecta su distintividad?
- 9.b. ¿En qué clases conviene registrar, y como marca denominativa, figurativa o mixta?
- 9.c. ¿Puede encargarse de la búsqueda de antecedentes y del trámite? ¿Con qué costo y plazo estimados?

---

## 3. Lo que solicitamos

Le pedimos, en orden de prioridad (primero lo que impide ofrecer el producto a un cliente):

1. **Texto final del aviso de medición** (consulta 1) y criterio sobre la notificación individual y el consentimiento.
2. **Modelo de anexo de tratamiento de datos** para el contrato con las empresas clientes (consultas 2, 3 y 4), con plazo de conservación y procedimiento de supresión.
3. **Requisitos para el envío de datos al exterior** y para elegir el proveedor de inteligencia artificial (consulta 4).
4. **Texto de limitación de responsabilidad** para el panel y los términos de uso (consulta 6).
5. **Modelo de contrato con los expertos** entrevistados (consulta 5).
6. **Opinión sobre los personajes y la figura de Sarmiento**, y propuesta de registro de marcas con costo y plazo (consultas 7, 8 y 9).

## 4. Contacto

Para dudas sobre el funcionamiento del producto, el profesional puede dirigirse al responsable de producto de Trazalog, que coordina esta consulta.
