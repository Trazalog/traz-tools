# Análisis de impacto — lectura del módulo de Tareas para los agentes

## Objetivo

Qué es: el análisis de impacto que exige el `CLAUDE.md` antes de tocar el núcleo (APIs de WSO2), para darles a Kuntur y Quirqui cuatro herramientas de **solo lectura** del módulo de Tareas: `tar_get_pedidos`, `tar_get_pedido`, `tar_get_tareas` y `tar_get_atrasadas` (TAR-API del plan de agentes, AGENTE-TAR-01). Para quién: el PM, que lo aprueba; sin su aprobación no se une ni se despliega. Cuándo leerlo: antes de aprobar el PR de AGENTE-TAR-01 y **antes de desplegarlo** (ver §5, orden de despliegue). Qué NO cubre: el plan de acción de Kuntur que **crea** pedidos (eso es [`analisis-impacto-plan-accion-kuntur.md`](analisis-impacto-plan-accion-kuntur.md)) ni las correcciones de aislamiento de Tareas (PRs #640 y #645, de la sesión de Tareas).

| Campo | Valor |
|---|---|
| Fecha | 2026-11-22 |
| Tarea | AGENTE-TAR-01 (TAR-API, lectura) |
| Estado | **Hecho en rama, espera aprobación del PM** |
| Comparado contra | `origin/master` (producción) y `origin/develop-v3.5`, el 2026-11-22 |

---

## 1. Qué cambia

**Solo se suman** cuatro recursos `GET` a la fachada de los agentes (`_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/apis/toolsMCPAPI.xml`, líneas 2446-2993). **Ningún servicio de datos se modifica** y ningún recurso existente cambia.

| Herramienta | Recurso nuevo | Llama a (sin cambios) |
|---|---|---|
| `tar_get_pedidos` | `GET /mcp/tar/pedidos?buscar=&todos=` | `PRODataService` `GET /pedidoTrabajo/{empr_id}/{clave}` (`getPedidosTrabajo`, `PRODataService.dbs:38`, recurso `:185`), la misma lista que usa Ingreso por barrera |
| `tar_get_pedido` | `GET /mcp/tar/pedido/{petr_id}` | La misma lista (para la cabecera y para saber si el pedido es de la empresa) y `TARDataService` `GET /pedidostrabajo/hitos/{petr_id}?empr_id=` (`getHitos`, `TARDataService.dbs:214`, recurso `:484`), que trae anidadas las tareas de cada hito |
| `tar_get_tareas` | `GET /mcp/tar/tareas?hito_id=&estado=` | `TARDataService` `GET /tareas/planificar/PETR/{orta_id}?empr_id=` (`getTareasPlanificadas`, `:154`, recurso `:428`); con `orta_id` vacío trae las de toda la empresa |
| `tar_get_atrasadas` | `GET /mcp/tar/atrasadas` | El mismo recurso que `tar_get_tareas`, sin hito; el filtro se hace en la fachada |

Además, en el motor de los agentes:
- `db/agente/029-tools-tar.sql` (+ rollback): las cuatro filas del catálogo `agente.tool`, clase `lectura`. Kuntur y Quirqui ya tenían el patrón `tar_get_*` permitido desde `011`; Faustino no.
- `doc/api/trazalog-operaciones.yaml`: las cuatro operaciones (es lo que publica el gateway como herramientas del MCP).
- `agente/mcp_client.py` (modo desarrollo): rutas de las cuatro y parámetros de URL.

## 2. Reglas que respeta

- **La empresa sale del token** (`jwt_empr_id`, ADR-013). El agente nunca la manda; si la manda, el cliente la descarta.
- **Pedido de otra empresa → 404 sin pedir nada más.** El detalle de pedido que usan las pantallas (`getinfopedidotrabajo`, `PRODataService.dbs:54`) **no filtra por empresa**: por eso no se usa. La cabecera sale de la lista de la empresa; si el pedido no está ahí, se responde `no_encontrado` antes de pedir los hitos.
- **Parámetros inválidos → 400 sin llamar al servicio de datos** (número de pedido o hito no numérico, búsqueda con barras, `%` o `?`, más de 100 caracteres).
- **Errores del servicio de datos → 502 al instante**, respondidos dentro del recurso y no con `toolsFault` (deuda técnica registrada en STATE: su `<send/>` después de un `<call>` deja colgado al cliente). Antes de cada `GET` se vacía el cuerpo, porque si no el MI lo manda como parámetros.
- **Topes**: 200 pedidos y 300 tareas por respuesta, con el total real.

## 3. Criterios propios (supuestos, no salen del módulo de Tareas)

- **"No finalizado"** = el estado del pedido no contiene `FINALIZADO`, que es el estado final por defecto (`traz-comp-bpm/models/Pedidotrabajos.php`). Un proceso propio de un cliente con otro estado final (`esfi_id`) aparecería como abierto. Con `todos=true` vienen todos.
- **"Atrasada"** = no está finalizada y su vencimiento ya pasó. Vencimiento = el fin planificado (`fec_fin`) o, si no tiene, la fecha asignada (`fecha`). Una tarea "sin fecha" (31-12-3000) no cuenta. La hora es la del servidor del MI.
- **"Sin asignar"** = la tarea no tiene `user_id`. Es lo que Kuntur va a usar para ver qué falta asignar de un plan de acción.

## 4. Qué se puede romper

| Riesgo | Qué pasa | Cómo se cubre |
|---|---|---|
| Recurso nuevo con error de sintaxis | El MI no despliega `toolsMCPAPI` y **caen todas las herramientas de los agentes** | Se desplegó en una copia del MI 4.5 sin errores (§6) y se valida el XML en las pruebas |
| `tareas/planificar/PETR/` con el último tramo vacío | Si el servicio de datos real no acepta el tramo vacío, `tar_get_tareas` sin hito y `tar_get_atrasadas` responderían 502 | **No verificado contra el servicio de datos real** (solo contra el simulador). Las pantallas usan tramos vacíos en el medio de la ruta (`/tareas/kpi/basico/desde//hasta/…`, `Reportes.php`), no al final. Verificar en el primer despliegue en DEV; si falla, propuesta: un recurso nuevo en `TARDataService` sin el tramo (cambio de núcleo, con su análisis) |
| Volumen | La lista de pedidos del servicio de datos devuelve hasta 20.000 filas | La fachada recorta a 200; para una pyme es suposición mía que no llega a ese tope |
| Producción | Nada: los recursos son nuevos y nadie más los llama | — |

## 5. Orden de despliegue — IMPORTANTE

En `origin/master` (producción), `getHitos` y `getTareasPlanificadas` **no filtran por empresa** (comparado el 2026-11-22): lo agregaron #640 y #645, que hoy están en `develop-v3.5`. Si la fachada nueva se despliega con los servicios de datos viejos, el parámetro `empr_id` se ignora y **`tar_get_tareas` y `tar_get_atrasadas` devolverían tareas de todas las empresas**.

**Regla:** la fachada con `tar_get_*` se despliega **en el mismo `.car` o después** de `TARDataService` y `PRODataService` con #640 y #645. Nunca antes. Como `deploymcp.sh` despliega un `.car` armado desde una sola rama, alcanza con desplegar desde una rama que tenga los tres cambios.

## 6. Cómo se probó

- **Copia aislada del MI 4.5** (puerto 8301, sin los `.car`, desconectada de DEV, con `apiconfig.xml` apuntando a `scripts/dev/simulador-tar-ds.py`): `tests/security/mcp-tar-lectura.hurl`, **14 de 14**. Cubre: sin identidad 503; la empresa 42 no ve el pedido ni el hito de la 99; parámetros inválidos 400 sin llamar al servicio; sin finalizados por defecto; error del servicio 502 en menos de 5 segundos. El registro del simulador confirma que cada llamada llevó la empresa del token y que el pedido ajeno no pidió hitos.
- `tests/test_mcp_tar_facade.py` (13): los scripts de la fachada corridos en Node con respuestas de la forma real (fila única como objeto, listas vacías, filtros, atrasadas).
- `tests/test_tar_tools.py` (6): URLs del modo desarrollo (el número de pedido no puede cambiar la ruta), spec OpenAPI y recursos.
- Base de prueba del agente: `029` aplicado, deshecho y vuelto a aplicar; estructura 142/142, aislamiento 28/28.
- **No probado:** contra los servicios de datos reales de DEV ni a través del gateway (APIM): falta publicar las cuatro operaciones en el Publisher, igual que con las herramientas anteriores.

## 7. Qué tiene que aprobar el PM

- [ ] Los cuatro recursos nuevos de la fachada (§1) y los criterios de §3.
- [ ] El orden de despliegue de §5.
