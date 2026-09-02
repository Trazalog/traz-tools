# Agente Minero — operación

## Objetivo

Guía práctica para **levantar, configurar y diagnosticar** el orquestador del Agente Minero. Es lo que hay que leer cuando algo no anda o cuando hay que cambiar una variable. Está escrito para seguirse sin conocer el historial del proyecto: cada paso dice dónde se ejecuta.

**Qué NO cubre:** no explica cómo está construido por dentro (`doc/agente/arquitectura.md`), ni cómo se instalan los componentes de infraestructura como el Streaming Integrator o el conector Firebase (`doc/agente/instalacion.md`), ni el esquema de base (`db/agente/README.md`).

---

## Levantarlo en desarrollo

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

## Las variables que importan

La lista completa con explicaciones está en `.env.example`. Estas son las que más se tocan:

| Variable | Para qué | Cuándo cambiarla |
|---|---|---|
| `AGENTE_MODELO` | El modelo que razona | Al cambiar de proveedor o buscar mejor relación costo/calidad. Tiene que soportar tool-calling |
| `AGENTE_MODELO_EMBEDDINGS` | El modelo que vectoriza | ⚠️ Cambiarlo **obliga a re-ingestar todo**. Ver abajo |
| `AGENTE_RAG_DISTANCIA_MAX` | Cuán parecido tiene que ser un fragmento para usarse | Si el agente trae contexto que no viene al caso, bajala. Si dice "no sé" de más, subila |
| `AGENTE_MAX_ITERACIONES` | Cuántas veces puede pedir datos antes de responder | Subila si ves respuestas cortadas por el tope; bajala si hay consultas que tardan mucho |
| `AGENTE_MCP_MODO` | `apim` (real) o `mi` (desarrollo) | **En demo y producción va `apim`**, siempre |
| `AGENTE_TEMPERATURA` | Cuánta variación en las respuestas | 0.2 por defecto. Para un agente técnico, bajo es mejor |

### Cambiar el modelo de embeddings no es gratis

La dimensión del vector vive en el DDL (`vector(1024)`). Si el modelo nuevo devuelve otra dimensión hay que alterar las columnas, recrear los índices HNSW **y re-generar todos los embeddings existentes** — los vectores viejos no son comparables con los nuevos. Ver `db/agente/README.md`.

El orquestador falla temprano y con un mensaje claro si detecta el desajuste, en vez de dejar que el `INSERT` explote más adelante.

---

## Editar el prompt del agente

`prompts/agente-minero.md` es lo que el agente lee antes de cada conversación. **Se recarga sin reiniciar**: editás, guardás, y la próxima consulta ya usa la versión nueva.

Los comentarios HTML del archivo no le llegan al modelo: están ahí para explicarle cosas a quien edita.

Mientras queden bloques con los textos de ejemplo, `/salud` los lista en `prompt_bloques_sin_definir`. **Antes de exponer el agente a un cliente, esa lista tiene que estar vacía.**

---

## Ingestar documentos

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

⚠️ **La ingesta escribe en el conocimiento compartido, así que necesita el rol `agente_curador`.** Con las credenciales del orquestador (`agente_app`) va a fallar con `permission denied for table chunk`, y eso es correcto: por ADR-A4 el runtime no escribe conocimiento compartido. Usá las credenciales del curador para ingestar.

---

## Troubleshooting

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| `/salud` dice `config_incompleta` | Falta una variable | Mirá `problemas_config`, que las nombra |
| `401` en toda consulta | Falta el header `Authorization: Bearer` | El frontend tiene que reenviar el token de la sesión |
| `403 El token no trae empr_id` | El JWT no tiene el claim | Es un problema de Dnato/APIM, no del agente. Ver ADR-009 |
| Respuestas "problema técnico" siempre | OpenRouter rechaza la key o el modelo no existe | `./agente/dev.sh smoke`. El error real queda en `agente.interaccion.error` |
| El agente dice "no tengo eso registrado" para todo | No hay conocimiento ingestado, o `AGENTE_RAG_DISTANCIA_MAX` es muy baja | `SELECT count(*) FROM agente.chunk WHERE vigente;` |
| `permission denied for table chunk` al ingestar | Estás usando el usuario del orquestador | Ingestá con `agente_curador` (es lo esperado, ver arriba) |
| Las consultas no ven memoria | Falta la partición de esa empresa | `SELECT agente.crear_particion_empresa(<empr_id>);` |
| `El modelo X devolvio vectores de N dimensiones` | El modelo de embeddings no coincide con el esquema | Ver "Cambiar el modelo de embeddings" |
| Una tool falla siempre | `AGENTE_MCP_MODO` o `AGENTE_MCP_URL` mal | Verificá contra qué apunta. En dev, que el MI esté levantado |

### Dónde mirar cuando algo salió mal

Todo queda en la base. La última consulta con error:

```
psql -h 127.0.0.1 -U postgres -d agente_minero -c "SELECT fec_alta, empr_id, left(pregunta,60), error, modelo, latencia_ms FROM agente.interaccion WHERE error IS NOT NULL ORDER BY fec_alta DESC LIMIT 5;"
```

Y para entender por qué una respuesta salió mal, la traza completa de lo que usó:

```
psql -h 127.0.0.1 -U postgres -d agente_minero -x -c "SELECT pregunta, respuesta, fragmentos_rag, tools_llamadas FROM agente.interaccion WHERE interaccion_id = '<id>';"
```

`fragmentos_rag` dice qué conocimiento recuperó y `tools_llamadas` qué datos consultó. Con eso se distingue "el conocimiento estaba mal" de "la tool falló" de "el modelo no entendió".

---

## ⚠️ Este servicio no va expuesto a internet

El orquestador **lee los claims del JWT sin validar la firma**, porque la validación la hace el APIM antes (ADR-008/ADR-009). Si el servicio quedara accesible sin el gateway adelante, cualquiera podría armar un token con el `empr_id` que quisiera y leer la memoria de cualquier empresa.

En demo y producción tiene que estar detrás del gateway o, como mínimo, en una red donde solo llegue tráfico que ya pasó por él.
