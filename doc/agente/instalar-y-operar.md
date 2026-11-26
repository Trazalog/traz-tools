# Agentes de IA de Trazalog — instalar, probar y operar

## Objetivo

Qué es: la guía única para instalar, levantar, probar y operar los agentes de IA de Trazalog en cada ambiente. Para quién: quien tenga que dejar el motor andando o diagnosticar un problema, sin conocer el historial del proyecto; cada paso dice dónde se ejecuta. Cuándo leerlo: al armar un ambiente, al cambiar una variable o cuando algo no anda. Qué NO cubre: cómo está construido por dentro ni por qué ([`AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md`](../v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md)), el esquema de base ([`db/agente/README.md`](../../db/agente/README.md)) ni el despliegue en Google Cloud ([`deployment-gcp.md`](../v3/deployment-gcp.md)).

| Ambiente | Dónde está |
|---|---|
| Máquina local de desarrollo | Partes 1 y 2 (motor con `./agente/dev.sh`, entrada por `traz-comp.local`) |
| Componentes de infraestructura (Streaming Integrator, conector Firebase, SearXNG) | Parte 3, por ambiente |
| Permiso propio (token de máquina) y metas de KPI | Parte 4 |
| Servidor compartido de DEV (EI 6.5) | [`decisiones.md`](decisiones.md), «Instalación en el servidor compartido de desarrollo» |
| Producción | Parte 3, sección «Producción», y [`deployment-gcp.md`](../v3/deployment-gcp.md) |


---

## Parte 1 — Levantar, configurar y diagnosticar el motor

Guía práctica para **levantar, configurar y diagnosticar** el orquestador de los agentes de IA. Es lo que hay que leer cuando algo no anda o cuando hay que cambiar una variable. Está escrito para seguirse sin conocer el historial del proyecto: cada paso dice dónde se ejecuta.


---

### Levantarlo en desarrollo

Todo en **la terminal local**, desde la raíz del repo.

```
cp .env.example .env
```

Editá `.env` y completá al menos `AGENTE_DB_PASSWORD` y `OPENROUTER_API_KEY`. En la máquina de desarrollo, la contraseña de la base ya está en `~/.agente-minero.env` (se generó al aplicar el esquema) y el script la toma sola.

```
./agente/dev.sh
```

La primera vez crea el entorno virtual e instala las dependencias; después arranca en `http://127.0.0.1:8099` con recarga automática.

**Lo primero que hay que mirar siempre:**

```
curl -s http://127.0.0.1:8099/salud | python3 -m json.tool
```

Devuelve el modelo configurado, el modo de MCP, los problemas de configuración y **qué bloques del prompt siguen con los textos de ejemplo**. Si `problemas_config` no está vacío, el servicio arranca igual pero algo va a fallar cuando lo uses.

Otros comandos:

```
./agente/dev.sh test
```
```
./agente/dev.sh smoke
```

El primero corre toda la suite sin gastar tokens. El segundo pega contra OpenRouter de verdad (centavos) y sirve para verificar que la API key anda, que el modelo hace tool-calling y que los embeddings tienen la dimensión que espera el esquema.

Con Docker, alternativamente:

```
docker compose -f docker-compose.dev.yml up orquestador
```

---

### Las variables que importan

La lista completa con explicaciones está en `.env.example`. Estas son las que más se tocan:

| Variable | Para qué | Cuándo cambiarla |
|---|---|---|
| `AGENTE_MODELO` | El modelo que razona | Al cambiar de proveedor o buscar mejor relación costo/calidad. Tiene que soportar tool-calling |
| `AGENTE_MODELO_EMBEDDINGS` | El modelo que vectoriza | ⚠️ Cambiarlo **obliga a re-ingestar todo**. Ver abajo |
| `AGENTE_RAG_DISTANCIA_MAX` | Cuán parecido tiene que ser un fragmento para usarse | Si el agente trae contexto que no viene al caso, bajala. Si dice "no sé" de más, subila |
| `AGENTE_MAX_ITERACIONES` | Cuántas veces puede pedir datos antes de responder | Subila si ves respuestas cortadas por el tope; bajala si hay consultas que tardan mucho |
| `AGENTE_MCP_MODO` | `apim` (real) o `mi` (desarrollo) | **En demo y producción va `apim`**, siempre |
| `AGENTE_TEMPERATURA` | Cuánta variación en las respuestas | 0.2 por defecto. Para un agente técnico, bajo es mejor |
| `AGENTE_PROMPTS_DIR` | Carpeta con un prompt por agente | Casi nunca: por defecto es `prompts/` del repo |
| `AGENTE_WEB_URL` | URL de SearXNG para la tool `web_buscar` | Vacía = sin búsqueda en internet. Para levantarlo, ver `instalacion.md` §1-ter |
| `AGENTE_DNATO_TOKEN_URL` · `AGENTE_CLAVE_CREDENCIALES` | Token de máquina de los jobs (ADR-A10): el endpoint de Dnato y la clave con que se cifran los secretos | Sin las dos, los jobs no corren. **La clave no se cambia** sin volver a cargar las credenciales: con otra clave no se pueden descifrar |
| `AGENTE_SUGERENCIAS_MAX` · `AGENTE_SUGERENCIA_SILENCIO_DIAS` · `AGENTE_SUGERENCIA_DIAS_CERTIFICACION` | El siguiente paso de Quirqui: cuántas propuestas (3), cuántos días no repetir una descartada (7), con cuánta anticipación avisar una certificación (30) | Valores por defecto: ajustarlos con lo que digan los usuarios |

#### Los modelos: cuáles funcionan y cuáles cuestan

Verificado contra la API el 2026-09-03:

| | Situación |
|---|---|
| **Chat** | Hay **17 modelos gratuitos con tool-calling** (los que terminan en `:free`). Funcionan con cuenta sin crédito. `minimax/minimax-m3:free` está verificado: responde bien en español técnico y hace tool-calling |
| **Embeddings** | **No hay ninguno gratuito.** Necesitan crédito, aunque es barato |

⚠️ **OpenRouter no lista sus modelos de embeddings en `/models`, pero sí los sirve.** Hoy solo están los de OpenAI (`text-embedding-3-small`, `-large`). **`cohere/embed-multilingual-v3.0` no existe ahí**, aunque el nombre suene plausible — fue un error de la primera configuración.

**Sin crédito, el agente igual responde**: si la vectorización falla, sigue sin RAG, con las tools y lo que el modelo sepa. Queda anotado en `agente.interaccion.error` como `RAG no disponible`. Una respuesta sin conocimiento propio es peor que una con él, pero muchísimo mejor que ninguna.

Lo que **no** funciona sin crédito: ingestar documentos y recuperar conocimiento. O sea, media razón de ser del agente.

#### Cambiar el modelo de embeddings no es gratis

La dimensión del vector vive en el DDL (`vector(1024)`). Si el modelo nuevo devuelve otra dimensión hay que alterar las columnas, recrear los índices HNSW **y re-generar todos los embeddings existentes** — los vectores viejos no son comparables con los nuevos. Ver `db/agente/README.md`.

El orquestador falla temprano y con un mensaje claro si detecta el desajuste, en vez de dejar que el `INSERT` explote más adelante.

---

### Los agentes y sus prompts

El motor es uno solo y responde como **Quirqui** (Asistente), **Kuntur** (Coach) o **Faustino** (Entrevistador) según la configuración de la tabla `agente.agente` (script `db/agente/011-agentes.sql`). Esa configuración es **igual para todos los clientes** y el orquestador solo la lee.

| Qué querés cambiar | Dónde |
|---|---|
| Nombre, personalidad, quién lo puede usar, tools permitidas, si está activo | `db/agente/011-agentes.sql`, y volver a aplicarlo (actualiza por `clave`). Se ve en la próxima consulta, sin reiniciar |
| Las instrucciones de cada agente | `prompts/quirqui.md`, `prompts/kuntur.md`, `prompts/faustino.md`. **Se recargan sin reiniciar** |

El nombre y la personalidad **no** están en los archivos de prompt: el orquestador los antepone desde la configuración, así se pueden cambiar sin tocar las instrucciones. Los comentarios HTML de los prompts no le llegan al modelo: están ahí para quien edita.

Mientras queden bloques con los textos de ejemplo, `/salud` los lista en `prompt_bloques_sin_definir`, **agrupados por archivo**. **Antes de exponer un agente a un cliente, su lista tiene que estar vacía.**

**Quién ve a quién.** `GET /agentes` devuelve los agentes que el usuario puede usar. Kuntur exige el nivel de administrador de Dnato (claim `role` = `1`); a cualquier otro usuario no le aparece, y si lo pide en `/consulta` recibe el mismo `404` que con un agente inexistente. Faustino no responde por `/consulta`: se usa desde la pantalla de entrevistas.

---

### Ingestar documentos

Carga manuales, normas y procedimientos al conocimiento compartido.

```
./agente/dev.sh test >/dev/null && .venv-agente/bin/python -m agente.ingesta doc.pdf --tipo manual --tipo-equipo chancadora
```

Primero conviene ver cómo queda troceado, sin escribir ni gastar tokens:

```
.venv-agente/bin/python -m agente.ingesta carpeta/ --dry-run
```

**Etiquetá el área con `--modulo`**, porque de eso depende que el conocimiento se recupere donde corresponde:

| Valor | Para qué material |
|---|---|
| `man` | Manuales de equipos, procedimientos de mantenimiento, planes preventivos |
| `alm` | Procedimientos de depósito, manejo de materiales, criterios de stock |
| `general` | Lo que aplica a las dos: seguridad, normativa transversal. **Se recupera siempre**, sin importar el área de la consulta |

```
.venv-agente/bin/python -m agente.ingesta procedimiento-deposito.md --modulo alm --tipo manual
```

#### Las ayudas de Tools y el catálogo de casos de uso (AGENTE-M-06)

Son el conocimiento **del producto**: con eso Quirqui explica qué se hace en cada pantalla y cita el link de la ayuda. Se cargan con un solo comando, en la **terminal local**, parado en la raíz del repo y con las credenciales del curador:

```
.venv-agente/bin/python -m agente.ingesta ayuda/ doctest/catalogo/
```

- La ingesta las **reconoce sola**: `.html` son ayudas (un fragmento por sección, con su link `ayuda/manual_x.html#sNN`), y `XXX-UC-NNN.yaml` son casos de uso (un fragmento por caso, con su pantalla, sus controladores y el link de su ayuda).
- **Solo entran los casos `validado`**: los borradores tienen dudas abiertas y los obsoletos ya no describen el sistema.
- **De la carpeta del catálogo solo se toman los casos de uso.** Los relevamientos y el esquema que conviven ahí son internos (tienen hallazgos y bugs) y no tienen que llegarle a un cliente.
- **Volver a correrlo reemplaza, no duplica.** Conviene correrlo cada vez que se regenera el sitio de ayudas o se valida un caso nuevo.
- Con el material de hoy son unos 240 fragmentos. El costo de vectorizarlos es de centavos de dólar.

#### Avisos proactivos: el monitoreo operativo (AGENTE-AS-03)

Un job revisa cada empresa con credencial de máquina (lotes vencidos o críticos, stock bajo el punto de pedido, certificaciones por vencer) y **publica los avisos en Tools** (ADR-015: `POST /avisos` de `toolsNTFAPI`, firmados por Quirqui). Les llegan a los **suscriptos** a cada tipo de aviso (`ntf.suscripcion` en la base de Tools); sin suscriptos, no le llega a nadie. El mismo aviso no se repite en el día. La campanita y el push son los de Tools (ver [`doc/notificaciones/instalacion-avisos.md`](../notificaciones/instalacion-avisos.md)).

**Requisitos:** `018` aplicado; `AGENTE_DNATO_TOKEN_URL` y `AGENTE_CLAVE_CREDENCIALES` en el entorno; la credencial de cada empresa cargada (`python -m agente.credenciales alta --empresa <id> --client-id <id>`, pide el secreto por teclado); `AGENTE_AVISOS_URL` (el `POST /avisos` de `toolsNTFAPI` en el gateway; vacía, no se publica nada y los hallazgos quedan en la corrida); y los suscriptos en `ntf.suscripcion` de la base de Tools. Por ejemplo, en la **terminal con `psql` a la base de Tools**:

```
psql -h <host-base> -U <usuario-dueño> -d trazalog_tools -c "INSERT INTO ntf.suscripcion (empr_id, tipo, usuario) VALUES (191, 'material_por_vencer', 'jefe.deposito')"
```

Los tipos que publica el monitoreo: `material_por_vencer`, `stock_critico`, `certificacion_por_vencer` (`*` = todos). **Hoy Dnato todavía no emite tokens de máquina** (espera la aprobación del análisis de impacto): hasta entonces el job termina con `"error"` en cada empresa, sin hacer nada.

Correrlo a mano (**terminal del servidor del orquestador**, parado en el repo):

```
.venv-agente/bin/python -m agente.monitoreo
```

Programado (crontab del usuario del orquestador, una vez por hora en horario laboral):

```
0 7-19 * * 1-6 cd /ruta/a/traz-tools && .venv-agente/bin/python -m agente.monitoreo >> /var/log/agente-monitoreo.log 2>&1
```

Cada empresa queda como una corrida (`disparador = 'evento_operativo'`, canal `scheduler`), con el resumen en `controles`.

#### Kuntur: metas y avisos al administrador (AGENTE-CO-01, CO-03, CO-07)

Desde `023`, **Kuntur está activo y solo lo ven los administradores** (rol 1 de Dnato). En el panel del agente, un administrador ve dos pestañas: Quirqui y Kuntur. Con Kuntur charla sobre los indicadores del Tablero y, cuando acuerdan una meta, Kuntur la **propone** como una tarjeta con el botón "Cargar meta". Kuntur no graba nada: la meta la carga el administrador con ese botón, que hace lo mismo que la tarjeta Metas del Tablero.

**Entrevista de configuración (desde `024`).** La primera vez, Kuntur le propone al administrador unas pocas preguntas: industria, qué partes de Trazalog usa, si trabaja para una operadora y qué le exige, y qué le preocupa. Con "Confirmar" se guarda en `agente.perfil_empresa`, y desde ahí Kuntur lo tiene en cuenta en cada charla. El detalle está en [`kuntur-entrevista-configuracion.md`](../v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md).

**Seguimiento de metas.** Otro trabajo programado revisa las metas vigentes de cada empresa con credencial de máquina. Cada meta queda **ok, en riesgo** (hoy se cumple pero, con la tendencia de los últimos 30 días, no llega a su fecha) **o no se cumple**. Kuntur avisa **cuando el estado cambia**, a quien cargó la meta, firmado por Kuntur (aviso tipo `kpi_desvio`, con enlace al Tablero). Lo que ya avisó queda en `agente.aviso_meta`, y en la pestaña Kuntur el administrador puede tocar "No insistas": no se avisa más de esa meta hasta que vuelva a cumplirse. La disponibilidad de equipos se mide con los últimos 30 días. No usa el modelo de lenguaje: es una regla sobre los datos.

**Requisitos:** los mismos que el monitoreo de arriba (credenciales de máquina, `AGENTE_AVISOS_URL`), más `022` y `023` aplicados y la base de Tools con `v2.8.1.6/kpi_objetivos.sql`. No hace falta suscribir a nadie: el destinatario sale de la meta.

Correrlo a mano (**terminal del servidor del orquestador**, parado en el repo):

```
.venv-agente/bin/python -m agente.coach
```

Programado (crontab del usuario del orquestador, una vez por día a las 8):

```
0 8 * * * cd /ruta/a/traz-tools && .venv-agente/bin/python -m agente.coach >> /var/log/agente-coach.log 2>&1
```

Cada empresa queda como una corrida (`disparador = 'desvio_kpi'`, canal `scheduler`), con el resumen y las metas en desvío en `controles`.

**Mediciones que Kuntur le pide a Quirqui (desde `032`).** Kuntur pide con `kuntur_pedir_medicion` que se mida un número cada cierto tiempo (siempre después de un plan aceptado). Otro trabajo programado las ejecuta con el token de máquina de la empresa y la lista blanca de Quirqui: guarda el valor y la tool de la que salió en `agente.medicion_resultado` y, si la medición es de un plan, el avance de cada tarea en `agente.avance_plan`. El administrador ve y cancela lo pedido en la pestaña Kuntur («Lo que estoy midiendo»). Detalle: [`mediciones.md`](../v3/AGENTES_TRAZALOG_ARQUITECTURA_TECNICA.md).

Correrlo a mano (**terminal del servidor del orquestador**, parado en el repo):

```
.venv-agente/bin/python -m agente.mediciones
```

Programado (crontab del usuario del orquestador, una vez por día a las 6, antes del seguimiento de metas):

```
0 6 * * * cd /ruta/a/traz-tools && .venv-agente/bin/python -m agente.mediciones >> /var/log/agente-mediciones.log 2>&1
```

Cada empresa queda como una corrida (`disparador = 'medicion_pedida'`, canal `scheduler`).

#### La industria de cada empresa (ADR-A11)

El conocimiento está marcado por industria: `mineria`, `oil_gas`, `electricidad` o `general` (aplica a todas). Una empresa con la industria declarada recibe lo de su industria y lo general; **sin declarar, recibe todo**, etiquetado. La industria la carga Trazalog o, desde `024`, la confirma el administrador en la entrevista de Kuntur.

Se declara en la **terminal local** (o en la del servidor de la base), con el propietario de la base o el curador:

```
psql -h 127.0.0.1 -U postgres -d agente_minero -c "SET agente.empr_id = '191'; INSERT INTO agente.perfil_empresa (empr_id, vertical) VALUES (191, 'mineria') ON CONFLICT (empr_id) DO UPDATE SET vertical = EXCLUDED.vertical, fec_mod = now();"
```

Al ingestar material de una sola industria, indicarla con `--vertical` (por defecto `general`):

```
.venv-agente/bin/python -m agente.ingesta manual-bomba-transferencia.pdf --modulo man --vertical oil_gas
```

Las ayudas y los casos de uso son siempre `general`.

#### Documentos de una empresa

Procedimientos internos, instructivos propios: van a la **memoria privada de esa empresa**, nunca al conocimiento compartido (R7). Hace falta que la empresa tenga su partición de memoria (`SELECT agente.crear_particion_empresa(<empr_id>);`).

```
.venv-agente/bin/python -m agente.ingesta procedimientos-internos.pdf --empresa 191 --reemplazar
```

⚠️ **La ingesta escribe en el conocimiento compartido, así que necesita el rol `agente_curador`.** Con las credenciales del orquestador (`agente_app`) va a fallar con `permission denied for table chunk`, y eso es correcto: por ADR-A4 el runtime no escribe conocimiento compartido. Usá las credenciales del curador para ingestar.

---

### El chat dentro de Tools

La vista vive en `application/modules/traz-comp-agente/` y se entra por:

```
<base_url>/traz-comp-agente/agente
```

El panel de feedback negativo, por:

```
<base_url>/traz-comp-agente/agente/admin
```

#### Antes de que funcione, tres cosas

**1. El orquestador tiene que estar corriendo y ser alcanzable desde el PHP.** La URL sale de la constante `REST_AGENTE` (`application/config/constants.php`), que se puede pisar con la variable de entorno `AGENTE_URL`. Por defecto apunta a `http://127.0.0.1:8099`.

**2. Dnato tiene que estar accesible y compartir sesión con Tools** — que es lo normal, porque corren en el mismo host con la misma cookie `ci_session`.

⚠️ **Cuidado con el host.** El flujo OAuth usa la constante `AGENTE_DNATO_OAUTH`, que por defecto vale lo mismo que `DNATO`, pero se puede pisar con la variable de entorno `DNATO_OAUTH_URL`. Hace falta cuando el vhost no coincide con lo que dice `DNATO`: en el entorno de desarrollo, por ejemplo, `DNATO` apunta a `http://localhost/traz-comp-dnato/` mientras el vhost real de XAMPP es `traz-comp.local` con DocumentRoot en `/mnt/win/dev/git`. Si quedan desalineados, el navegador termina en una URL que no sirve.

**El valor tiene que ser el mismo host por el que entra el usuario**, o la cookie de sesión no viaja y Dnato le pide login de nuevo — justamente lo que este flujo evita.

**3. El módulo tiene que estar en el menú.** El menú de Tools sale de la tabla `sismenu`, así que es un alta de **datos**, no de código: hay que dar de alta la entrada apuntando a `traz-comp-agente/agente` y asignarla a los roles que correspondan. Mientras tanto se entra por URL directa.

#### Verificar que la conexión con el agente funciona

Desde el navegador, con sesión iniciada en Tools:

```
<base_url>/traz-comp-agente/agente/salud
```

Devuelve el mismo JSON que `/salud` del orquestador. Si dice `"estado": "inaccesible"`, el problema es de red o de `REST_AGENTE`, no del agente.

#### Si el chat pide reconectar todo el tiempo

El JWT que emite Dnato tiene un TTL (`jwt_ttl` en su `config/jwt.php`). Cuando está por vencer, `/consulta` devuelve `401` y el JS reconecta solo — sin perder lo escrito. Si eso pasa **en cada consulta**, el TTL está muy corto o el reloj del servidor está desfasado.

---

### Troubleshooting

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| `/salud` dice `config_incompleta` | Falta una variable | Mirá `problemas_config`, que las nombra |
| `relation "agente.agente" does not exist` | No se aplicó `011-agentes.sql` | Aplicarlo con el usuario propietario de la base (ver `db/agente/README.md`) |
| `409 Kuntur todavía no está disponible` | Kuntur está inactivo hasta la Fase 5 | Es lo esperado. Se activa en `011-agentes.sql` |
| `function agente.tools_permitidas(text) does not exist` en `interaccion.error` | No se aplicó `012-tools.sql` | Aplicarlo con el usuario propietario. Sin él el agente no responde, a propósito |
| El agente nunca busca en internet | `AGENTE_WEB_URL` vacía, o falta aplicar `014-tool-web.sql` | Las dos cosas hacen falta: el buscador configurado y la tool catalogada |
| `web_buscar` vuelve sin resultados | Los buscadores no responden a tiempo | Ver `instalacion.md` §1-ter, punto 5 |
| Una tool nueva del gateway no la usa ningún agente | No está en el catálogo | Sumarla al seed de `012-tools.sql` con su clase y re-aplicarlo. Si escribe, va como `accion` y no la va a usar nadie |
| El agente contesta "No tengo ese dato confirmado. ¿Querés que lo busque en los datos de tu empresa o en internet?" | El guardián de cifras (R4) encontró un número sin origen y bloqueó la respuesta | Mirar `incidentes` de esa corrida: `respuesta_bloqueada` tiene lo que iba a decir y `cifras` qué número no tenía fuente. Si es un falso positivo (por ejemplo, "5 puntos" no reconocido como discurso), sumar la palabra a `PALABRAS_DE_DISCURSO` en `agente/guardian.py` |
| En `tools_llamadas` aparece `"status": "bloqueada"` | El modelo pidió una tool que no tiene permitida (típicamente, crear una OT) | Es lo esperado: no salió al MCP. Si se repite mucho, revisar el prompt |
| `401` en toda consulta | Falta el header `Authorization: Bearer` | El frontend tiene que reenviar el token de la sesión |
| `403 El token no trae empr_id` | El JWT no tiene el claim | Es un problema de Dnato/APIM, no del agente. Ver ADR-009 |
| Respuestas "problema técnico" siempre | OpenRouter rechaza la key o el modelo no existe | `./agente/dev.sh smoke`. El error real queda en `agente.interaccion.error` |
| El agente dice "no tengo eso registrado" para todo | No hay conocimiento ingestado, o `AGENTE_RAG_DISTANCIA_MAX` es muy baja | `SELECT count(*) FROM agente.chunk WHERE vigente;` |
| `permission denied for table chunk` al ingestar | Estás usando el usuario del orquestador | Ingestá con `agente_curador` (es lo esperado, ver arriba) |
| Las consultas no ven memoria | Falta la partición de esa empresa | `SELECT agente.crear_particion_empresa(<empr_id>);` |
| `El modelo X devolvio vectores de N dimensiones` | El modelo de embeddings no coincide con el esquema | Ver "Cambiar el modelo de embeddings" |
| Una tool falla siempre | `AGENTE_MCP_MODO` o `AGENTE_MCP_URL` mal | Verificá contra qué apunta. En dev, que el MI esté levantado |
| El chat redirige a Dnato y vuelve con error | `client_id` o `redirect_uri` que Dnato no acepta | El `client_id` tiene que ser el de `AGENTE_OAUTH_CLIENT_ID`; el `redirect_uri` se arma solo con `base_url()` |
| "No se pudo validar la vuelta del login" | El `state` no coincide: sesión perdida entre el redirect y la vuelta | Suele ser que Tools y Dnato no comparten la cookie de sesión |
| `code_verifier incorrecto` al canjear | El challenge no coincide con el verifier | `php tests/agente/test-pkce.php` — verifica el cálculo contra el de Dnato |
| El chat dice "el agente no está disponible" | El PHP no llega al orquestador | `<base_url>/traz-comp-agente/agente/salud` lo dice con detalle |

#### Dónde mirar cuando algo salió mal

Todo queda en la base. La última consulta con error:

```
psql -h 127.0.0.1 -U postgres -d agente_minero -c "SELECT fec_alta, empr_id, left(pregunta,60), error, modelo, latencia_ms FROM agente.interaccion WHERE error IS NOT NULL ORDER BY fec_alta DESC LIMIT 5;"
```

Y para entender por qué una respuesta salió mal, la traza completa de lo que usó:

```
psql -h 127.0.0.1 -U postgres -d agente_minero -x -c "SELECT pregunta, respuesta, fragmentos_rag, tools_llamadas FROM agente.interaccion WHERE interaccion_id = '<id>';"
```

`fragmentos_rag` dice qué conocimiento recuperó y `tools_llamadas` qué datos consultó. Con eso se distingue "el conocimiento estaba mal" de "la tool falló" de "el modelo no entendió".

Lo que **vio el modelo** de cada tool, en orden:

```
psql -h 127.0.0.1 -U postgres -d agente_minero -x -c "SELECT orden, tool, status, left(contenido, 500) AS contenido FROM agente.tool_llamada WHERE interaccion_id = '<id>' ORDER BY orden;"
```

Las corridas con algo para revisar (tools bloqueadas, cifras sin fuente):

```
psql -h 127.0.0.1 -U postgres -d agente_minero -c "SELECT fec_alta, empr_id, agente, left(pregunta,50), incidentes FROM agente.interaccion WHERE incidentes <> '[]'::jsonb ORDER BY fec_alta DESC LIMIT 10;"
```

Y el costo por agente en los últimos 30 días:

```
psql -h 127.0.0.1 -U postgres -d agente_minero -c "SELECT agente, count(*) AS corridas, sum(costo_usd) AS usd FROM agente.interaccion WHERE fec_alta > now() - interval '30 days' GROUP BY 1;"
```

> Estas consultas van como `postgres` (el propietario) porque cruzan empresas. Con el usuario del orquestador, por el RLS, no devolverían nada sin fijar antes `agente.empr_id`.

---

### ⚠️ Este servicio no va expuesto a internet

El orquestador **lee los claims del JWT sin validar la firma**, porque la validación la hace el APIM antes (ADR-008/ADR-009). Si el servicio quedara accesible sin el gateway adelante, cualquiera podría armar un token con el `empr_id` que quisiera y leer la memoria de cualquier empresa.

En demo y producción tiene que estar detrás del gateway o, como mínimo, en una red donde solo llegue tráfico que ya pasó por él.

---

## Parte 2 — Probar los agentes en la máquina local

Instrucciones para **entrar al chat del agente y probarlo de punta a punta** en la máquina de desarrollo: qué URL usar, con qué usuario, y qué hacer si algo no responde. Está escrito para seguirse sin conocer el historial: cada paso dice dónde se ejecuta.


---

### 🆕 Probar la tanda de noviembre (rama de prueba integrada)

Desde el 2026-11-22 hay una copia de Tools que junta **todos los cambios de agentes que todavía no están unidos** (avatares, casos validados, textos de Quirqui y Kuntur, funciones sin usar, y los que se vayan sumando: lectura de Tareas, plan de acción, pruebas derivadas). Está en `/mnt/win/dev/git/traz-v35/traz-tools-agentes-prueba`, en la rama local `prueba/agentes-integrado` (nunca se sube ni se une: es solo para probar).

**1. Prender Apache** — en una terminal local (pide tu contraseña):

```
sudo /opt/lampp/lampp startapache
```

**2. Poner al día la base del agente de tu máquina** — en una terminal local, con el usuario dueño de la base (el que creó `agente_minero`; si no es `postgres`, cambialo). Tu base está en el script `011`; esto aplica del `012` al `031` en orden y para en el primer error:

```
cd /mnt/win/dev/git/traz-v35/traz-tools-agentes-prueba && \
for f in db/agente/01[2-9]-*.sql db/agente/02[0-9]-*.sql db/agente/03[01]-*.sql; do \
  case $f in *rollback*) ;; *) psql -h 127.0.0.1 -U postgres -d agente_minero -v ON_ERROR_STOP=1 -f $f || break;; esac; \
done
```

Para volver atrás un script: correr su `.rollback.sql` con el mismo comando, empezando por el número más alto.

**3. Levantar el motor de los agentes** — en otra terminal local (queda corriendo; se corta con Ctrl+C):

```
cd /mnt/win/dev/git/traz-v35/traz-tools-agentes-prueba && ./agente/dev.sh
```

**4. Entrar** — en el navegador: `http://traz-comp.local/traz-v35/traz-tools-agentes-prueba/`, con el usuario de prueba (más abajo). Como es administrador, el panel muestra **Quirqui y Kuntur**.

**Qué no vas a poder probar todavía, y por qué:**
- Las herramientas nuevas que pasan por WSO2 (lectura de Tareas, crear el pedido al aceptar un plan) necesitan desplegar el `.car` de la rama en un MI. Tu MI no lo toco: hasta que lo despliegues, Kuntur responde que no pudo consultar esos datos, y el plan de acción funciona **simulado** (la tarjeta lo dice).
- Los avisos al celular necesitan la conexión segura a desarrollo y el conector de Firebase de AssetPlanner desplegado ahí.

---

### ⚠️ Entrá por `traz-comp.local`, no por `localhost`

Es lo primero y lo que más confunde. XAMPP tiene dos cosas distintas:

| URL | A dónde va | Sirve para el agente |
|---|---|---|
| `http://localhost/` | `/opt/lampp/htdocs` — el htdocs de XAMPP | ❌ da 403 |
| **`http://traz-comp.local/`** | `/mnt/win/dev/git` — donde están los proyectos | ✅ |

El vhost está en `/opt/lampp/etc/extra/httpd-vhosts.conf` y `traz-comp.local` ya resuelve por `/etc/hosts`. **No hay que configurar nada**, solo usar la URL correcta.

> **Ojo con la constante `DNATO`.** Vale `http://localhost/traz-comp-dnato/`, que en este entorno no funciona: por eso el login de Tools redirige a una URL que da 403. El módulo del agente no depende de esa constante — deriva la URL de Dnato **del host por el que entró el usuario**, así que funciona por cualquiera de los dos. El resto de Tools sí arrastra el desajuste.

---

### Las URLs

| Qué | URL |
|---|---|
| Tools | `http://traz-comp.local/traz-tools/` |
| Dnato | `http://traz-comp.local/traz-comp-dnato/` |
| **Chat del agente** | Se entra **por el menú**, desde el Dash — ver abajo |
| Fragmento del chat (directo) | `http://traz-comp.local/traz-tools/traz-comp-agente/agente` (sin estilos: es un fragmento) |
| Orquestador (directo) | `http://127.0.0.1:8099` |
| Bonita | `http://10.142.0.13:8080/bonita` |

---

### El usuario de prueba

Creado el 2026-09-02 para probar el agente. **Las credenciales están en `~/.agente-minero.env`** (permisos 600, fuera del repo), junto a las de la base.

| Dato | Valor |
|---|---|
| Empresa | `AGENTE MINERO TEST` |
| `empr_id` | **191** |
| Email | `agente.minero.test@trazalog.local` |
| Nick (BPM) | `agenteminero` |
| Perfil | Administrador |

#### Qué se creó, exactamente

El alta por el formulario web **no funciona en este entorno**: el registro va por WSO2 (`toolsCOREAPI` → `POST /usuario/registro`) y el MI local responde `The endpoint reference (EPR) for the Operation not found`. Así que se crearon los registros a mano, replicando lo que hace el alta:

| Dónde | Qué |
|---|---|
| `core.empresas` (PostgreSQL `tools_prod_t`) | La empresa, `empr_id` 191 |
| `seg.users` | El usuario, con la contraseña hasheada **por la propia librería `Password` de Dnato** (PBKDF2 `sha256:1000:salt:hash`) |
| `seg.memberships_users` | El vínculo usuario ↔ empresa. Es lo que resuelve el `empr_id` de la sesión |
| Bonita (`API/identity/user`) | El usuario `agenteminero`, id 1901 |

**El de Bonita no es opcional:** el login de Dnato valida contra Bonita y falla con `NO HAY USUARIO EN BPM CON EL NICK` si no está. Fue lo último que faltaba para que el login pasara.

Para dar de baja todo esto: borrar el usuario de Bonita, y las filas de `seg.memberships_users`, `seg.users` y `core.empresas`.

---

### Probarlo, paso a paso

Todo desde **el navegador**, salvo el primer paso.

**1. Levantar el orquestador** — en la terminal, desde la raíz del repo:

```
./agente/dev.sh
```

**2. Entrar a Tools y loguearte:**

```
http://traz-comp.local/traz-tools/Dash
```

**3. Buscar "Agente Minero" en el menú lateral.** Ya está dado de alta para el rol Administrador de la empresa de prueba, con su submenú "Feedback del agente".

**4. No te va a pedir nada más.** El módulo obtiene su token de Dnato **desde el servidor**, aprovechando que Tools y Dnato comparten la sesión. La primera consulta tarda un segundo más que las siguientes porque incluye ese paso.

**5. Preguntale algo.** La vista trae cuatro ejemplos clickeables, dos de mantenimiento y dos de almacenes.

> ⚠️ **No entres por la URL del módulo directamente.** Devuelve el fragmento sin estilos: el layout de Tools referencia sus CSS con rutas relativas y solo funciona desde una URL de un segmento como `/Dash`. Por eso todos los módulos se abren desde el menú.

#### Qué esperar

Con una `OPENROUTER_API_KEY` real, el agente responde. **Sin ella responde "no pude responder ahora mismo por un problema técnico"** — que es el comportamiento correcto: degrada con un mensaje entendible y deja el error real en la base:

```
psql -h 127.0.0.1 -U postgres -d agente_minero -c "SELECT fec_alta, empr_id, left(pregunta,50), error FROM agente.interaccion ORDER BY fec_alta DESC LIMIT 5;"
```

---

### Probar el panel de Quirqui (AGENTE-AS-01)

El panel es el botón redondo "Q" abajo a la derecha, en **todas** las pantallas de Tools. **Esta prueba está pendiente**: al construirlo no había VPN a DEV y la copia v3.5 de Tools respondía 500, así que solo se verificó que la vista renderiza y que el JS es válido.

**Dónde:** navegador, con el orquestador levantado (`./agente/dev.sh` en la terminal local) y los scripts `011` a `016` aplicados.

1. Entrar a Tools por `traz-comp.local` con el usuario de prueba (el que tiene el menú del agente).
2. **Ver el botón "Q" abajo a la derecha.** Si no aparece: el usuario no tiene el ítem del agente en su menú (es a propósito, ver abajo).
3. Ir a **Almacenes → Artículos** y abrir el panel. Tiene que verse el aviso amarillo "Lo que hables con Quirqui se usa para medir indicadores…"; "¿Qué se mide?" despliega el detalle.
4. Preguntar **"¿Qué hago en esta pantalla?"**. La respuesta tiene que hablar de la grilla de artículos (caso ALM-UC-001) y puede citar `ayuda/manual_almacenes.html#s03`. Requiere haber ingestado las ayudas y el catálogo (`operacion.md` → "Las ayudas de Tools y el catálogo").
5. Verificar en la base que la corrida registró la pantalla:
   `psql -h 127.0.0.1 -U postgres -d agente_minero -c "SELECT fec_alta, controles FROM agente.interaccion ORDER BY fec_alta DESC LIMIT 1;"`
   Tiene que aparecer `{"control": "pantalla", "ruta": "traz-comp-almacenes/...", "casos": ["ALM-UC-..."]}`.
6. Cambiar de pantalla sin recargar y volver a preguntar: la ruta del control tiene que ser la nueva.
7. **Siguiente paso (AGENTE-AS-02):** en Almacenes, al abrir el panel tienen que aparecer arriba hasta 3 propuestas (lotes vencidos o críticos, artículos bajo el punto de pedido) si la empresa los tiene. "Ver cómo" muestra qué hacer y el link a la ayuda; "Descartar" la saca y no vuelve por 7 días. Requiere `017` aplicado.

**Quién ve el panel:** solo los usuarios que tienen en su menú el ítem del agente (`traz-comp-agente/agente`, en `seg.menues`). Mostrárselo a todos es una decisión comercial pendiente.

### Lo que ya está verificado

Circuito completo, el 2026-09-02, con este usuario:

| Paso | Resultado |
|---|---|
| Menú del Dash | ✅ "Agente Minero" y "Feedback del agente" aparecen para el rol Administrador |
| Fragmento del chat | ✅ 200, arranca en `<div class="box box-primary">`, sin layout propio |
| OAuth desde el servidor | ✅ token obtenido sin sacar al usuario de la SPA; 1ª consulta 4,5 s, siguientes 1,7 s |
| Login en Dnato | ✅ `sesión abierta. email=agente.minero.test@trazalog.local empr_id=191` |
| `/oauth/authorize` con la sesión | ✅ devuelve el `code` **sin pedir credenciales** |
| Canje del `code` | ✅ JWT con `empr_id: 191`, `sub: agenteminero`, TTL 24 h |
| Consulta al orquestador con ese JWT | ✅ aceptado; la interacción quedó registrada **con `empr_id` 191 derivado del token** |

Lo único que falta para una respuesta real es una `OPENROUTER_API_KEY` válida en el `.env`.

---

### Deuda anotada: el módulo del menú va como `CORE`

El alta en `seg.menues` usa `modulo = 'CORE'` en vez de uno propio, porque el constraint `menues_check` tiene una **lista cerrada** de módulos —`PRD, CORE, ALM, MAN, TAR, PAN, LOG, SEG, TRZ, PRO, FIS, BPM, RESI`— que no incluye al agente.

Agregarle un valor es un cambio de esquema de la base de Tools, así que queda a decisión del PM. Funciona igual: el `modulo` solo agrupa, y lo que resuelve la navegación es la `url`.

---

### Si algo no anda

| Síntoma | Causa | Qué hacer |
|---|---|---|
| 403 en todo | Entraste por `localhost` | Usá `traz-comp.local` |
| El login vuelve al login | El usuario no existe en Bonita | Buscar `NO HAY USUARIO EN BPM` en `traz-comp-dnato/application/logs/` |
| "Sesión Existente" y no entra | Cookie de una sesión anterior | Borrar cookies del sitio |
| El chat pide reconectar siempre | El host del OAuth no es el de la sesión | Entrá y quedate en `traz-comp.local` |
| El chat dice que el agente no está disponible | El orquestador no corre | `./agente/dev.sh`, y mirar `/agente/salud` |
| El registro web falla con 500 | El MI local no tiene `/usuario/registro` | Es del entorno, no del agente. Crear el usuario a mano como se documentó arriba |
| El chat se ve sin estilos | Entraste por la URL del módulo | Entrá por el Dash y usá el menú |
| "No se pudo obtener la autorización" | La cookie de sesión no llegó a Dnato | Verificá que entraste por el mismo host, y mirá el log: `_asegurarToken()` deja el detalle |

---

## Parte 3 — Componentes de infraestructura, por ambiente

Este documento es el **instructivo paso a paso para instalar y dejar operativos los componentes de infraestructura de los agentes de IA de Trazalog** en cada ambiente (desarrollo, demo, producción). Está escrito para que cualquiera pueda seguirlo sin conocer el historial del proyecto: cada paso dice explícitamente dónde se ejecuta y cómo verificar que salió bien.


---

### Estado de este documento

| Componente | Desarrollo | Demo | Producción |
|---|---|---|---|
| **WSO2 Streaming Integrator** | ✅ §1 — instalado y verificado 2026-09-02 | ⏳ §2 — pendiente | ⏳ pendiente |
| Esquema PostgreSQL del agente | ⏳ E1 | ⏳ | ⏳ |
| Orquestador Python/FastAPI | ⏳ E2 | ⏳ | ⏳ |
| **`FirebaseConnectorAPI` en el MI** | ✅ §1-bis — desplegado y verificado hasta FCM el 2026-09-02 | — ya existe | — ya existe |

---

### 1. WSO2 Streaming Integrator — ambiente de desarrollo

> **Desde ADR-015 (2026-10-28)** el agente ya no tiene cola propia: publica en los avisos de Tools (`ntf`) y el transporte es `_backend/siddhi/AvisosPush.siddhi`. Cómo se configuran los datasources y las apps del SI para eso: [`doc/notificaciones/instalacion-avisos.md`](../notificaciones/instalacion-avisos.md). Lo que sigue (instalar el SI) sigue valiendo.

El SI es el transporte entre la cola de avisos y el conector Firebase del MI (Opción C del análisis de E0). Todos los comandos de esta sección se ejecutan en **la terminal local de la máquina de desarrollo** (Ubuntu 24.04).

#### 1.1 Requisitos previos

- **JDK 21** — verificado funcionando con Temurin 21. La ruta usada acá es `/usr/lib/jvm/temurin-21-jdk-amd64`; si en tu máquina está en otro lado, ajustá `JAVA_HOME` en todos los comandos.
- **~600 MB libres en disco** — el zip son 111 MB y la instalación desplegada ocupa ~150 MB, más logs.
- Conexión a internet para bajar el instalable y dos drivers JDBC de Maven Central.

#### 1.2 Descarga e instalación

```
mkdir -p ~/wso2 && cd ~/wso2
```
```
curl -L -o /tmp/wso2si-4.4.0.zip \
  https://github.com/wso2/product-integrator-si/releases/download/v4.4.0/wso2si-4.4.0.zip
```
```
cd ~/wso2 && unzip -q /tmp/wso2si-4.4.0.zip && rm -f /tmp/wso2si-4.4.0.zip
```

Queda instalado en `~/wso2/wso2si-4.4.0`.

#### 1.3 Offset de puertos — obligatorio

**Por qué:** el SI usa el puerto **9443** por defecto, que es el mismo puerto de administración de WSO2 API Manager 4.6.0. Si algún día los dos corren en la misma máquina, chocan. Se le aplica un offset de 10 al SI, así APIM se queda con sus puertos nativos.

Editá a mano el archivo `~/wso2/wso2si-4.4.0/conf/server/deployment.yaml`. En el bloque `wso2.carbon:` → `ports:` (alrededor de la línea 28) cambiá:

```
    offset: 0
```

por:

```
    offset: 10
```

Con el offset aplicado, los puertos del SI quedan así:

| Servicio | Puerto por defecto | Con offset 10 |
|---|---|---|
| API REST del servidor (la usa el extension-installer) | 9090 | **9100** |
| HTTPS de administración | 9443 | **9453** |
| Transporte HTTP | 7070 | 7080 |
| Transporte HTTPS | 7443 | 7453 |

**Segundo paso, imprescindible:** el CLI del extension-installer tiene el puerto hardcodeado en su propia configuración y no lee el offset. Si no lo ajustás, cualquier comando del installer falla con `java.net.ConnectException: Conexión rehusada`. Editá `~/wso2/wso2si-4.4.0/wso2/tools/extension-installer/conf/config.properties` y cambiá la última línea:

```
server.port = 9090
```

por:

```
server.port = 9100
```

#### 1.4 Drivers JDBC — hay que convertirlos a bundles OSGi

**Por qué:** el SI no trae drivers JDBC, y no alcanza con copiar el `.jar` a `lib/`: el runtime es OSGi y necesita que el jar sea un bundle. La herramienta `jartobundle.sh` que viene con el producto hace la conversión.

PostgreSQL es el que necesita el agente; MySQL sirve para probar contra la base de AssetPlanner.

```
mkdir -p /tmp/jdbc-raw && cd /tmp/jdbc-raw
```
```
curl -L -o postgresql-42.7.4.jar \
  https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.4/postgresql-42.7.4.jar
```
```
curl -L -o mysql-connector-j-8.4.0.jar \
  https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.4.0/mysql-connector-j-8.4.0.jar
```
```
cd ~/wso2/wso2si-4.4.0 && export JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64 && \
  ./bin/jartobundle.sh /tmp/jdbc-raw/postgresql-42.7.4.jar lib/ && \
  ./bin/jartobundle.sh /tmp/jdbc-raw/mysql-connector-j-8.4.0.jar lib/
```

Verificá que aparezcan los dos bundles generados (el nombre cambia, con guiones bajos):

```
ls -lh ~/wso2/wso2si-4.4.0/lib/ | grep -iE "postgresql_|mysql_connector"
```

⚠️ **No dejes también los `.jar` originales en `lib/`** — quedarían duplicados. Los originales viven en `/tmp/jdbc-raw`, no se copian a `lib/`.

#### 1.5 Arreglar `siddhi-io-cdc` — sin esto el CDC no funciona

**El problema:** el `siddhi-io-cdc-2.1.1.jar` que viene dentro de la distribución de SI 4.4.0 **no tiene `META-INF/MANIFEST.MF`**. Es un defecto de empaquetado del producto — el mismo jar publicado en Maven Central tiene el mismo problema. Sin manifest, el runtime no lo carga como bundle OSGi y cualquier app que use `@source(type='cdc', ...)` falla al desplegar con:

```
No extension exist for source:cdc. Please check the required dependencies exist.
```

Al arrancar, el síntoma previo es esta advertencia (fácil de pasar por alto entre el resto del log):

```
Error when loading the OSGi bundle information from .../lib/siddhi-io-cdc-2.1.1.jar
java.io.IOException: Invalid OSGi bundle found in the lib folder
```

**El arreglo** es agregarle un manifest mínimo y después convertirlo con `jartobundle.sh`, que genera los headers OSGi. Con el servidor **detenido**:

```
mv ~/wso2/wso2si-4.4.0/lib/siddhi-io-cdc-2.1.1.jar /tmp/jdbc-raw/
```
```
cd /tmp/jdbc-raw && cp siddhi-io-cdc-2.1.1.jar cdc-fix.jar && \
  printf 'Manifest-Version: 1.0\nCreated-By: jartobundle-fix\n\n' > MANIFEST.MF
```
```
/usr/lib/jvm/temurin-21-jdk-amd64/bin/jar --update --file /tmp/jdbc-raw/cdc-fix.jar \
  --manifest=/tmp/jdbc-raw/MANIFEST.MF
```
```
cd ~/wso2/wso2si-4.4.0 && export JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64 && \
  ./bin/jartobundle.sh /tmp/jdbc-raw/cdc-fix.jar lib/
```

Queda `lib/cdc_fix_1.0.0.jar` (~20 MB) y el original ya no está en `lib/`.

> **Lo que NO funciona, para no perder tiempo:** `./bin/extension-installer.sh install cdc` responde `Configuration for extension: cdc was not found` — el catálogo del installer en 4.4.0 no incluye CDC. Y `jartobundle.sh` sobre el jar original falla con `NoSuchFileException: /META-INF/MANIFEST.MF`, porque la herramienta necesita un manifest para determinar si el jar ya es un bundle. Por eso el manifest se agrega antes.

#### 1.6 Arrancar y verificar

```
cd ~/wso2/wso2si-4.4.0 && export JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64 && \
  nohup ./bin/server.sh > /tmp/si.log 2>&1 &
```

Arranca en unos 7 segundos. La línea que confirma el arranque:

```
grep "Streaming Integrator started" /tmp/si.log
```

**Para detenerlo** (no uses `pkill -f wso2si` desde un script: el patrón matchea el propio comando y te mata la shell):

```
for p in $(ps -eo pid,args | grep "wso2si-4.4.0" | grep -v grep | awk '{print $1}'); do kill "$p"; done
```

#### 1.7 Prueba de humo del CDC

Verifica que el source `cdc` en modo polling levanta y lee filas nuevas de una tabla. Las apps Siddhi se despliegan copiando el archivo a `~/wso2/wso2si-4.4.0/wso2/server/deployment/siddhi-files/` — el servidor las toma en caliente, sin reiniciar.

Creá ahí un archivo `PruebaCDC.siddhi` con una app que solo lea y loguee, **sin escribir en ninguna tabla**: un `@source(type='cdc', mode='polling', polling.column='<columna de fecha o id>', jdbc.driver.name='org.postgresql.Driver', url=..., table.name=...)` conectado a un `@sink(type='log', prefix='PRUEBA-CDC >>')`.

En el log del servidor tenés que ver:

```
Siddhi App PruebaCDC deployed successfully
```

El CDC en modo polling **arranca desde el final de la tabla**: solo emite filas nuevas, no las históricas. Para comprobar que lee de verdad hay que insertar una fila después de que la app esté desplegada, esperar el intervalo de polling y buscar el evento en el log:

```
grep "PRUEBA-CDC" /tmp/si.log
```

Cuando termines, **borrá la fila de prueba y el archivo `.siddhi`** — el archivo lleva credenciales de base en claro y no debe quedar en el servidor.

> Un warning que **se puede ignorar**: `The following extensions are required for Siddhi app '...': [cdc-mysql]. Please use the Extension Installer to install them.` Lo emite el installer al chequear su propio catálogo, no el runtime. Si la línea siguiente dice `deployed successfully`, la app está corriendo.

#### 1.8 Verificado en desarrollo el 2026-09-02

| Qué | Resultado |
|---|---|
| SI 4.4.0 con JDK 21 (Temurin) | ✅ arranca en 6,8 s |
| Offset de puertos 10 | ✅ 9100 / 9453 / 7080 / 7453 |
| Drivers PostgreSQL y MySQL como bundles OSGi | ✅ |
| `siddhi-io-cdc` con el arreglo del manifest | ✅ el source `cdc` carga |
| App con CDC polling desplegada | ✅ `deployed successfully` |
| Captura de una fila nueva | ✅ evento capturado con su `data_json` |

La prueba de captura se hizo insertando una fila marcada en `assetv2.synch_notificacion_queue` (base de desarrollo) y **borrándola inmediatamente después**; la tabla quedó con las mismas 434 filas y el mismo último id (562) que antes de la prueba.

---

### 1-bis. Conector Firebase en el WSO2 MI

El `FirebaseConnectorAPI` es el que efectivamente manda el push a FCM. Vive en `_backend/api/FirebaseConnectorAPI/` y **ya está desplegado en los ambientes existentes**; estos pasos son para montarlo en un MI nuevo (por ejemplo el local de desarrollo, donde no estaba).

Todos los comandos van en **la terminal local**.

#### 1-bis.1 Construir y desplegar el CAR

```
cd _backend/api/FirebaseConnectorAPI/FirebaseConnectorAPICompositeExporter && \
  export JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64 && mvn clean install
```
```
cp target/FirebaseConnectorAPICompositeExporter_1.0.0-SNAPSHOT.car \
  ~/.wso2-mi/micro-integrator/wso2mi-4.5.0/repository/deployment/server/carbonapps/
```

⚠️ El build de Maven **borra archivos versionados** dentro de `FirebaseConnectorAPICompositeExporter/tmp/` y deja un `target/` sin trackear. Después de construir, revisar `git status` y restaurar:

```
git checkout -- _backend/api/FirebaseConnectorAPI/FirebaseConnectorAPICompositeExporter/tmp/
```

#### 1-bis.2 Reiniciar el MI — el hot deploy no alcanza

El CAR se despliega en caliente y el API aparece, **pero el connector `googlefirebase` no queda registrado**: el primer `POST` falla con `Sequence template org.wso2.carbon.connector.googlefirebase.init cannot be found`. Hay que reiniciar el MI para que registre la Synapse Library.

#### 1-bis.3 El connector no trae el SDK de Firebase

Después del reinicio el connector se despliega, pero falla al instanciar:

```
NoClassDefFoundError: com/google/firebase/messaging/FirebaseMessagingException
```

El `googlefirebase-connector-1.0.2.zip` contiene **solo las clases del conector, cero jars**. Hay que resolver el SDK y sus transitivas, y dejarlas en `<MI_HOME>/lib`. Con Maven, creando un `pom.xml` mínimo con la dependencia `com.google.firebase:firebase-admin:6.12.2` y ejecutando:

```
mvn dependency:copy-dependencies -DoutputDirectory=jars
```

Son **67 jars, unos 25 MB**. **No los copies todos:** siete ya existen en el MI (`guava`, `gson`, `jackson-core`, `commons-codec`, `commons-lang3`, `commons-logging`, `slf4j-api`) y pisarlos puede romper el runtime. Copiá a `<MI_HOME>/lib` solo los **60 restantes**, comparando por nombre de artefacto contra lo que ya hay en `lib/`, `wso2/lib/`, `dropins/` y `wso2/components/plugins/`.

Después, reiniciar el MI otra vez.

#### 1-bis.4 Verificación

```
curl -s -X POST http://localhost:8290/tools/firebase/send \
  -H "Content-Type: application/json" \
  -d '{"xformValues":{"registrationToken":"TOKEN_INVALIDO","notificationTitle":"Prueba","webPushNotificationBody":"smoke test","webPushNotificationDirection":"AUTO"}}'
```

Si el conector está bien montado, la respuesta trae el rechazo de FCM:

```
{"Result":{"Error":"400 Bad Request\nPOST https://fcm.googleapis.com/v1/projects/traz-prod-assetplanner/messages:send ... The registration token is not a valid FCM registration token"}}
```

Eso **es el resultado esperado** con un token de descarte: significa que el conector se autenticó con la cuenta de servicio y llegó hasta Google.

#### 1-bis.5 ⚠️ Un fallo de envío sale como HTTP 200

Prestá atención al status de esa respuesta: es **200**, con el error adentro del cuerpo. No es un caso de borde — un rechazo explícito de Google sale como éxito HTTP.

Cualquier cosa que consuma este API **tiene que parsear el cuerpo y buscar `Result.Error`**; mirar el status code no alcanza. Es el riesgo R4 del análisis de E0, y es la razón por la que `agente.envio` tiene un `estado` de cuatro valores en vez de un flag binario.

#### 1-bis.6 Verificado en desarrollo el 2026-09-02

| Qué | Resultado |
|---|---|
| CAR construido y desplegado en el MI local | ✅ el API aparece en `/management/apis` |
| Connector `googlefirebase` registrado tras reiniciar | ✅ `Successfully created Synapse Import: googlefirebase` |
| 60 jars del SDK en `lib/`, sin pisar los 7 solapados | ✅ arranque sin `NoClassDefFoundError` |
| `POST` real hasta FCM | ✅ autenticación correcta con la cuenta de servicio; FCM responde |
| Token inválido | ✅ rechazado por FCM — **y devuelto como HTTP 200** |
| Push a un dispositivo real | ⏳ pendiente: hace falta un token FCM válido |

---

### 1-ter. SearXNG — la búsqueda en internet de los agentes (AGENTE-M-05)

SearXNG es un metabuscador libre: le pregunta a varios buscadores y devuelve los resultados juntos, sin API key ni costo. Lo usa la tool `web_buscar`. **Es opcional:** sin él, los agentes funcionan igual pero no buscan en internet.

**Dónde se ejecuta:** terminal local (desarrollo) o terminal de la VM del ambiente (demo/producción), parado en la raíz del repo `traz-tools`.

1. Generar un secreto propio del ambiente y ponerlo en el `.env` como `SEARXNG_SECRET` (cualquier texto largo y aleatorio):
   `python3 -c "import secrets; print(secrets.token_hex(32))"`
2. Levantarlo:
   `docker compose -f docker-compose.dev.yml --profile web up -d searxng`
3. Verificar que devuelve JSON con resultados (si `results` viene vacío, ver el punto 5):
   `curl -s "http://127.0.0.1:8888/search?q=MTBF&format=json" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['results']))"`
4. En el `.env` del orquestador: `AGENTE_WEB_URL=http://127.0.0.1:8888` y reiniciar el orquestador. En `/salud` no cambia nada; en la próxima consulta, Quirqui ya recibe la tool.
5. **Si vuelve sin resultados** y `unresponsive_engines` dice `timeout`: la red tarda más que el timeout. Está subido a 8 s en `agente/searxng/settings.yml` (`outgoing.request_timeout`); con VPN puede hacer falta más.

La configuración está en `agente/searxng/settings.yml`: parte de los valores por defecto, habilita la salida JSON (sin eso responde `403`) y apaga el limitador, porque solo lo consulta el orquestador. La versión de la imagen está fijada en `docker-compose.dev.yml`.

**Verificado en desarrollo el 2026-10-27** con `searxng/searxng:2026.10.11-ad46ebd7d`: 10 resultados para "MTBF mantenimiento" (con el timeout por defecto de 3 s volvía vacío).

### 2. WSO2 Streaming Integrator — ambiente de demo

⏳ **Pendiente.** Se documenta cuando se despliegue. Los pasos son los mismos de §1 con tres diferencias a resolver:

1. **Puertos:** verificar qué ocupa la VM antes de elegir el offset (en la VM de GCP corren APIM y MI nativos, según ADR-011).
2. **Credenciales de base:** en la app Siddhi del agente **no van en claro** en el `.siddhi` — se resuelven por el `deployment.yaml` del SI / secure vault. Las apps de AssetPlanner en `traz-int` tienen usuario y contraseña embebidos; ese patrón no se replica.
3. **Arranque como servicio:** en la VM el SI tiene que levantar solo (unidad systemd), no con `nohup`.

---

### 3. Producción

⏳ **Pendiente.** Solo documentación en esta versión; el pase real lo decide el PM.

---

## Parte 4 — Permiso propio de los agentes y metas de indicadores

Procedimiento para poner en marcha, en un ambiente, las dos piezas que Kuntur necesita antes de existir: el **token de máquina** de los agentes (Dnato emite un permiso por empresa para correr sin un usuario conectado, ADR-A10) y la **historia, metas y desvíos de los KPIs** (ADR-A9). Está escrito para el PM o quien despliegue y se sigue leyendo solo este archivo, en orden. No explica por qué se diseñó así: eso está en [`analisis-impacto-token-maquina.md`](../historial/agente/analisis-impacto-token-maquina.md) y [`analisis-impacto-kpi-objetivos.md`](../historial/agente/analisis-impacto-kpi-objetivos.md). Los avisos (campanita y push) tienen su propio procedimiento: [`../notificaciones/instalacion-avisos.md`](../notificaciones/instalacion-avisos.md).

- **Probado:** todo en la máquina de desarrollo, el 2026-10-29: PostgreSQL 11 (12 pruebas del motor), un MI 4.5.0 aparte apuntando solo a bases locales (recursos del DataService y de `toolsMCPAPI`), Tools en PHP 7.3 contra ese MI (pantalla de metas, 12 controles en navegador) y `JwtIssuer` en PHP 5.6 (10 controles).
- **No probado:** contra DEV ni el APIM (el pedido real a Dnato, la publicación de las tools nuevas).

---

### 0. Antes de empezar

| Qué | Dónde se consigue |
|---|---|
| Acceso `psql` a la base de Tools con el usuario dueño de los esquemas `kpi` y `seg` | El servidor de base del ambiente |
| El código de Dnato con el PR `traz-comp-dnato#48` y el de Tools con la rama `feat/AGENTE-fase4-token-kpi` | GitHub, después del merge |
| El CAR de `ToolsAPIProject` compilado con esa rama | Terminal local de la máquina de build (`mvn clean install`) |
| Acceso al Publisher del APIM | `https://<apim>:9443/publisher` |
| Acceso a la base de los agentes y al entorno del orquestador | El servidor del orquestador |

**Orden:** base de Tools → Dnato → MI → APIM → agentes → Tools (PHP) → Kuntur. Cada paso se puede verificar antes de seguir.

---

### 1. Base de Tools

**Dónde:** terminal con `psql` conectada a la base de Tools del ambiente, parado en la raíz del repo `traz-tools`.

```bash
psql -h <host-base> -U <usuario-dueño> -d <base-tools> -v ON_ERROR_STOP=1 \
  -f _backend/database/scripts/versiones/v2.8.1.6/kpi_objetivos.sql
```

Crea `kpi.historico` y `kpi.objetivos`, las funciones `kpi.objetivos_de`, `kpi.desvios`, `kpi.objetivo_guardar` y `kpi.objetivo_cancelar`, y **reemplaza `kpi.publicar()`** por una que además guarda la historia del día. Lo que lee el Tablero (`kpi.cache`) no cambia.

Verificar que la próxima corrida del cron (cada 5 minutos) llena la historia:

```bash
psql -h <host-base> -U <usuario-dueño> -d <base-tools> \
  -c "select nombre, count(*), max(fecha) from kpi.historico group by nombre"
```

Si no aparece nada después de 5 minutos, mirar el log del motor:

```bash
psql -h <host-base> -U <usuario-dueño> -d <base-tools> \
  -c "select * from kpi.event_log where nombre = 'kpi.historico' order by id desc limit 5"
```

**Vuelta atrás:** `_backend/database/scripts/versiones/v2.8.1.6/kpi_objetivos.rollback.sql` (devuelve `kpi.publicar()` a la versión anterior; **la historia y las metas cargadas se pierden**).

---

### 2. Dnato: clientes de máquina

#### 2.1 La tabla

**Dónde:** terminal con `psql` a la base de Dnato (la del esquema `seg`), parado en la raíz del repo `traz-comp-dnato`.

```bash
psql -h <host-base> -U <usuario-dueño> -d <base-dnato> -v ON_ERROR_STOP=1 \
  -f doc/identity/migrations/002_create_seg_oauth_clients.sql
```

#### 2.2 El código

**Dónde:** el despliegue habitual de Dnato. Va con el código del PR #48: `application/controllers/Oauth.php`, `Cli.php`, `application/models/OauthClient_model.php`, `application/libraries/JwtIssuer.php` y `application/config/jwt.php`.

Verificar en el navegador o con `curl`, desde cualquier terminal:

```bash
curl -s https://<dnato>/oauth/.well-known/oauth-authorization-server
```

Tiene que decir `"grant_types_supported":["authorization_code","client_credentials"]`.

**Antes y después de este paso**, el login de Claude.ai y el chat de los agentes tienen que seguir andando (es la rama que no se tocó). Con un usuario cualquiera, conectarse a Trazalog desde Claude.ai.

#### 2.3 Dar de alta el cliente de una empresa

**Dónde:** terminal en el servidor de Dnato, parado en la carpeta de Dnato.

```bash
php index.php cli oauth_cliente_alta <empr_id> "Agentes de <nombre de la empresa>"
```

Imprime el `client_id` y el **secreto, una sola vez**. Copiarlos en ese momento para el paso 5. Para revocar: `php index.php cli oauth_cliente_baja <client_id>`. Para ver los que hay: `php index.php cli oauth_cliente_lista`.

#### 2.4 Verificar el token

**Dónde:** cualquier terminal.

```bash
curl -s -X POST https://<dnato>/oauth/token \
  -d grant_type=client_credentials \
  -d client_id=<client_id> \
  -d client_secret=<secreto>
```

Tiene que devolver `access_token` y `"expires_in":900`. Con un secreto inventado tiene que devolver `invalid_client` (401). Agregando `-d empr_id=1` tiene que devolver `invalid_request` (400): la empresa no se pide, sale del cliente.

---

### 3. Micro Integrator

**Dónde:** el servidor del MI del ambiente, carpeta `carbonapps`.

Desplegar el CAR nuevo. Trae:

- `ToolsKPIDataService` con cinco recursos más (`/historico/…`, `/objetivos/…`, `/desvios/…`, `POST /objetivo`, `PUT /objetivo/cancelar`). Los tres de antes (`/kpi/…`, `/kpis/…`, `/man/…`) no cambian.
- `toolsMCPAPI` con `GET /mcp/kpi/valor`, `/mcp/kpi/historico`, `/mcp/kpi/objetivos` y `/mcp/kpi/desvios`.
- La secuencia `rechazarTokenMaquina`: `POST /mcp/man/ot` y `POST /mcp/alm/pedido` responden **403** con un token de máquina.

**Ojo:** si alguna fuente de datos del CAR no conecta, el MI revierte el CAR completo. Verificar las conexiones del ambiente antes.

Verificar, en una terminal con acceso al MI:

```bash
curl -s -H 'Accept: application/json' \
  http://<mi>:8290/services/ToolsKPIDataService/objetivos/emprid/<empr_id>
```

Tiene que devolver `{"objetivos":{}}` (o la lista, si ya hay metas).

---

### 4. API Manager

**Dónde:** Publisher del APIM.

En la API unificada de operaciones (la que genera el servidor MCP), sumar las cuatro operaciones `GET /mcp/kpi/valor`, `/mcp/kpi/historico`, `/mcp/kpi/objetivos` y `/mcp/kpi/desvios`, tal como están en `doc/api/trazalog-operaciones.yaml` (etiqueta "Indicadores"). Republicar y regenerar el servidor MCP para que aparezcan como tools.

Verificar que el token de máquina del paso 2.4 pasa por el gateway: una lectura (`man_get_equipos`) tiene que andar y `man_create_ot` tiene que dar 403.

---

### 5. Agentes

**Dónde:** terminal en el servidor del orquestador, parado en la raíz del repo `traz-tools`.

1. Catalogar las tools nuevas en la base de los agentes:

```bash
psql -h <host-agente> -U <usuario-dueño> -d <base-agente> -v ON_ERROR_STOP=1 \
  -f db/agente/022-tools-kpi.sql
```

2. En el entorno del orquestador, `AGENTE_DNATO_TOKEN_URL` = `https://<dnato>/oauth/token` y `AGENTE_CLAVE_CREDENCIALES` = una clave larga al azar (ver `doc/agente/instalar-y-operar.md`).
3. Cargar la credencial de cada empresa (pide el secreto del paso 2.3 por teclado):

```bash
python -m agente.credenciales alta --empresa <empr_id> --client-id <client_id>
```

---

### 6. Tools (PHP)

**Dónde:** el despliegue habitual de Tools.

Va con el código: `application/controllers/Objetivos.php`, `application/models/Objetivos_model.php`, `application/views/dashboard/objetivos.php`, `application/views/dashboard/admin_dashboard.php` y `lib/props/objetivos.js`.

Verificar con un **administrador** de la empresa: en el Tablero, debajo de los indicadores, aparece la tarjeta **Metas**. Cargar una meta, ver que aparece con el valor de hoy y si se cumple, y cancelarla. Con un usuario que **no** es administrador, la tarjeta dice "Solo el administrador de la empresa ve las metas".

---

### 7. Kuntur: charla de metas y avisos

Requiere los pasos 1 a 6. Lo que se activa acá está explicado para el usuario en [`operacion.md`](instalar-y-operar.md), sección "Kuntur: metas y avisos al administrador".

#### 7.1 Activar a Kuntur

**Dónde:** terminal en el servidor del orquestador, parado en la raíz del repo `traz-tools`.

```bash
psql -h <host-agente> -U <usuario-dueño> -d <base-agente> -v ON_ERROR_STOP=1 \
  -f db/agente/023-kuntur-metas.sql
```

Reiniciar el orquestador para que tome el código nuevo (`agente/metas.py`, `agente/coach.py` y los cambios de `agente/orquestador.py` y `agente/api.py`), y desplegar en Tools el panel nuevo: `application/modules/traz-comp-agente/views/panel.php`, `controllers/Agente.php` y `models/Agentes.php`.

Verificar con un **administrador**: en el panel del agente aparecen las pestañas **Quirqui** y **Kuntur**. Pedirle a Kuntur "quiero bajar los artículos bajo punto de pedido": tiene que mirar el valor de hoy y, cuando acuerden, mostrar una tarjeta "Meta propuesta" con el botón **Cargar meta**. Al tocarlo, la meta aparece en la tarjeta Metas del Tablero con la etiqueta "Kuntur". Con un usuario que **no** es administrador, el panel no muestra pestañas.

**Vuelta atrás:** `db/agente/023-kuntur-metas.rollback.sql` (Kuntur queda inactivo; las metas ya cargadas siguen).

#### 7.2 Programar el seguimiento de metas

**Dónde:** crontab del usuario del orquestador, en el servidor del orquestador.

```
0 8 * * * cd /ruta/a/traz-tools && .venv-agente/bin/python -m agente.coach >> /var/log/agente-coach.log 2>&1
```

Verificar a mano, en la terminal del servidor del orquestador parado en el repo, con una meta que hoy no se cumpla:

```bash
.venv-agente/bin/python -m agente.coach --empresa <empr_id>
```

Tiene que imprimir una línea con `"desvios": 1` y `"avisos": 1`, y a quien cargó la meta le tiene que llegar a la campanita "No se cumple la meta: …", firmado por Kuntur. Corrido otra vez la misma semana, no se repite.

## De dónde salió este documento

Fusionado el 2026-11-26 (unificación de documentación, `DOC-UNIF-2`) a partir de:

- `doc/agente/instalar-y-operar.md`
- `doc/agente/instalar-y-operar.md`
- `doc/agente/instalar-y-operar.md`
- `doc/agente/instalar-y-operar.md`

El texto se juntó sin reescribirlo; solo se bajaron niveles de título y se ajustaron enlaces. La historia de cada parte está en `git log --follow` de los archivos originales.
