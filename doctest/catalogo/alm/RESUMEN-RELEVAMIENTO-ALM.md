# Relevamiento de ALM — dossier de validación

## Objetivo

Deja registro de cómo se relevó Almacenes, qué se encontró y en qué quedó cada caso después de la validación del PM. Está escrito para el PM y para quien retome F3. **No** es el catálogo en sí —eso son los 19 YAML de esta carpeta, que son la fuente— ni la guía de cómo funciona DocTest, que está en [`../../GUIA-PRUEBAS-Y-AYUDAS.md`](../../GUIA-PRUEBAS-Y-AYUDAS.md).

> **Validado el 2026-08-25.** Las 61 preguntas están respondidas y aplicadas al catálogo. Lo que queda abierto está en §6. Este dossier se conserva porque documenta cómo se relevó y qué se encontró; para el estado actual de cada caso, la fuente son los YAML.

**Cómo validar, en concreto.** En una terminal, parado en `traz-tools/doctest/`:

```bash
npm run hoja:validacion -- alm
```

Eso deja `.validacion/alm.html`. Abrilo en el navegador (doble clic), leé caso por caso, marcá la decisión de cada uno y usá el botón **Copiar** al final: arma un texto con todas tus decisiones que me pegás acá. Con eso aplico los cambios al catálogo.

- **Fecha:** 2026-08-25 · **Fase:** DocTest F3 (issue #440)
- **Estado tras la validación del PM:** 19 casos → **16 validados**, 2 en `borrador`, 1 `obsoleto`
- **Preguntas abiertas:** 1 (era 61)

---

## 1. Lo primero: tres cosas que conviene mirar antes que el catálogo

### 1.1 Una empresa puede leer los datos de otra — verificado en vivo

No es una sospecha de lectura de código. Con dos sesiones simultáneas contra el DEMO, desde **DocTest Empresa SA** pedí datos de **Conservas**:

| Lo que pedí | Lo que devolvió |
|---|---|
| `Notapedido/getNotaPedidoId?id_nota=882` | el pedido completo de Conservas: "Durazno descarozado", cantidad 72, código PP001 |
| `Articulo/getLotes/1477` | el panel "Artículo: Durazno descarozado" |

La causa no es un descuido puntual: **los listados filtran por empresa, pero las 36 funciones que buscan por id no**. Como el id viaja en la URL, alcanza con cambiar el número. El aislamiento vive en la pantalla, no en los datos.

Es **el mismo gap que ADR-012 detectó en el DataService**, del lado del PHP. Y toca directamente el piloto MCP: el ADR especifica que `get_pedido_material` debe devolver vacío si el pedido es de otra empresa, y hoy el modelo que hay debajo no hace esa distinción.

→ Issues **#478** (el caso puntual) y **#479** (el patrón, con tres opciones de alcance para que elijas).

**Las funciones de escritura no las ejecuté** —`update_editar`, `editarDetalle`, `updateaDeposito`, `eliminar`, `setEstado`— porque eso habría modificado datos de una empresa real. Ahí el hallazgo es lo que dice el código, no una prueba.

### 1.2 El código que ve `develop-v3` no es el que corre en el DEMO

**Cuatro submódulos** de `develop-v3` están atrás de `develop`, que es lo desplegado: `traz-comp-almacenes` (25 commits), `traz-comp-bpm`, `traz-comp-pan` y `traz-prod-trazasoft`. En el repo padre, en cambio, casi no hay diferencia.

Se notó porque el menú tiene **Movimientos Internos**, la pantalla abre y funciona en el DEMO, y su controlador **no existe** en el árbol de `develop-v3`: entró en uno de esos 25 commits. Es decir, alguien que releve desde `develop-v3` no ve una pantalla que los usuarios están usando.

**Este relevamiento se hizo contra `origin/develop` del submódulo**, y está verificado que es la versión correcta: el commit que releví (`de535f6`) es exactamente el que apunta `develop` del repo padre. No moví el puntero: cambiarlo 25 commits cambia qué código corre y es una decisión de integración, no de relevamiento. → Issue **#481**.

**Cómo leer `develop` sin tocar `develop-v3`** quedó escrito en [`../../GUIA-PRUEBAS-Y-AYUDAS.md` §1.4](../../GUIA-PRUEBAS-Y-AYUDAS.md): `git show`, `git grep` y `git ls-tree` aceptan una referencia, así que se lee la otra rama sin cambiar de rama ni tocar el working tree.

### 1.3 Un `empr_id` fijo en 1

`Notapedido::pedidoExtraordinario()` guarda `$peex['empr_id'] = 1; //!HARDCODE`. Todos los pedidos extraordinarios de todas las empresas quedan como de la empresa 1: la empresa 1 los ve y la que los pidió no. El resto del mismo controlador usa `empresa()` bien, así que es una omisión puntual. → Issue **#480**.

---

## 2. Qué se relevó

**13 pantallas** del menú (11 en Almacenes + Stock Producción, que está en Producción pero es de este módulo), verificadas una por una contra el DEMO: **las 13 responden HTTP 200 y muestran contenido real**. De ahí salieron 19 casos.

| Caso | Título | Perfil | Estado |
|---|---|---|---|
| ALM-UC-001 | Ver el listado de artículos del almacén | Responsable de Almacén | validado |
| ALM-UC-002 | Dar de alta un artículo | Responsable de Almacén | validado |
| ALM-UC-003 | Editar un artículo | Responsable de Almacén | validado |
| ALM-UC-004 | Dar de baja un artículo | Responsable de Almacén | validado |
| ALM-UC-005 | Consultar el stock por establecimiento y depósito | Responsable de Almacén | validado |
| ALM-UC-006 | **Pedir materiales al almacén** | Solicitante | validado |
| ALM-UC-007 | Ver el detalle de un pedido de materiales | Solicitante | borrador |
| ALM-UC-008 | Editar un pedido de materiales | Solicitante | obsoleto |
| ALM-UC-009 | Registrar la recepción de materiales de un proveedor | Responsable de Almacén | validado |
| ALM-UC-010 | Entregar materiales contra un pedido | Responsable de Almacén | validado |
| ALM-UC-011 | Entregar materiales sin pedido previo | Responsable de Almacén | validado |
| ALM-UC-012 | Consultar el detalle de las entregas de un período | Responsable de Almacén | validado |
| ALM-UC-013 | Consultar el stock valorizado | Responsable de Almacén | validado |
| ALM-UC-014 | Registrar un ajuste de stock | Responsable de Almacén | validado |
| ALM-UC-015 | Ver los artículos que llegaron al punto de pedido | Responsable de Almacén | validado |
| ALM-UC-016 | Mover mercadería entre depósitos — salida | Responsable de Almacén | validado |
| ALM-UC-017 | Mover mercadería entre depósitos — recepción | Responsable de Almacén | validado |
| ALM-UC-018 | Consultar los movimientos históricos de un artículo | Responsable de Almacén | validado |
| ALM-UC-019 | Consultar el stock de producción por lote | Responsable de Almacén | borrador |

### Un perfil nuevo, que no inventé

El alta de empresa crea dos roles de almacén en `toolsCOREAPI`: **`Responsable de Almacén <empresa>`** y **`Solicitante de Almacén <empresa>`**. El segundo entra en el `Solicitante` que el catálogo ya tiene; el primero es nuevo y se agregó al vocabulario. **Validado por el PM el 2026-08-25** al aceptar los casos que lo usan.

Verifiqué además que en este caso **el nombre del rol coincide** entre `toolsCOREAPI` y el trigger que asigna los menúes — o sea que ALM **no** tiene el problema de H-012, donde "Responsable de Procesos" se quedaba sin menú por una diferencia de nombre. (Hay un `"Responsable Almacén"` sin "de" en el mismo XML, pero es el nombre del **actor de Bonita**, que es otra cosa.)

---

## 3. Qué se respondió, y lo que cambió al profundizar

La validación no solo cerró las preguntas: al pedir el PM que se estudiara mejor el código, **cinco respuestas resultaron más precisas —o distintas— de lo que se había supuesto**. Eso es lo que vale la pena leer acá.

### 3.1 El disponible no descuenta solo los pedidos aprobados

La regla, tal como la valida `Lotes::getPuntoPedido()`:

```
disponible = SUM(alm_lotes.cantidad) − reservado
reservado  = SUM(resto) de los detalles de pedidos de la empresa cuyo estado NO es
             Entregado, Rechazado, Cancelado, Finalizado Ent. Parcial ni Finalizado Sin Entrega
```

Un artículo aparece en Punto de Pedido cuando `disponible < punto_pedido`.

**El matiz:** como el filtro es por exclusión de estados cerrados, un pedido en `Creada` —todavía sin aprobar— **ya descuenta disponible**. La validación decía "pedidos aprobados". Conviene confirmar si es lo esperado.

### 3.2 El pedido tiene ocho estados, no cuatro

De `models/Almtareas.php` y `models/Lotes.php`:

| Estado | Cuándo |
|---|---|
| `Creada` | al crearse el pedido |
| `Aprobado` / `Rechazado` | tarea de Bonita "Aprueba pedido de Recursos Materiales" |
| `Entregado` | entrega completa |
| `Ent. Parcial` | entrega parcial |
| `Finalizado Ent. Parcial` | se cierra el pedido con lo entregado |
| `Finalizado Sin Entrega` | se cierra sin entregar nada |
| `Cancelado` | aparece en el cálculo del punto de pedido |

Los cambia **Bonita**, a través de las tareas del proceso, no la pantalla. **Los dos estados de cierre no estaban en la lista de la validación** — quedan por confirmar (§6).

### 3.3 El precio del stock valorizado sale de la recepción, y se activa por empresa

Confirmado tal como lo describió el PM. `Remitos::getConfigPrecios()` busca en `core.tablas` un registro de la empresa cuya `tabla` contiene `alm_configs`: **si su campo `valor2` viene con valor**, la pantalla de recepción muestra Precio Unitario en pesos y en dólares con sus totales. Ese es el valor que después informa Stock Valorizado — no una lista de precios.

### 3.4 Las reglas de "no de más" existen, pero solo en la pantalla

El PM confirmó dos reglas: no se puede entregar más de lo pedido, y **nunca** se puede sacar más de lo que hay. Las dos están implementadas… en el JavaScript de la vista:

| Regla | Dónde está |
|---|---|
| No entregar de más | la vista oculta el botón si `cant_pedida <= cant_entregada` o `cant_disponible == 0` |
| No sacar más de lo que hay (movimiento interno) | `MovimientoSalida.php:674` avisa cuántas unidades tiene el lote |

Del lado del servidor no hay nada: `insert_entrega_materiales()` guarda el `resto` que venga del formulario y `actualizar_lote()` descuenta sin verificar que alcance. Es el mismo patrón que en DNATO. → **#483**.

### 3.5 El ajuste de stock: acá el relevamiento estaba mal, y el PM lo marcó

Las preguntas de la primera pasada ("¿la justificación es obligatoria?", "¿admite negativos?", "¿se puede anular?") estaban mal planteadas por dos motivos:

1. **Capturé el modal de detalle de un ajuste existente, no el formulario de alta.** El alta se abre por `nuevoAjuste()` y carga otra vista.
2. **Busqué en el PHP una lógica que no está ahí.** `Ajustestocks::guardarDetalleAjustes()` arma las líneas y las manda a `REST_ALM + /stock/ajuste/detalle_batch_req`: **el ajuste no escribe en la base desde el PHP**, lo resuelve el DataService. Por eso desde el PHP no se puede responder si admite negativos.

Lo que sí quedó claro del código: el ajuste se aplica **sobre un lote concreto**, cada línea lleva su propio tipo de ajuste (la cabecera ya no lo usa — lo dice un comentario en el código), y una salida se guarda como cantidad negativa.

### 3.6 El histórico cubre ocho tipos de movimiento, incluida la producción

De `Historico_articulos.view.php`: Recepción, Entrega, Movimiento Interno de ingreso y de egreso, Ajuste, y tres de producción (consumo de materia prima, consumo de producto semi terminado, salida de producto de etapa productiva). **Sí se puede reconstruir el stock** sumándolos, como esperaba la validación.

### 3.7 Lo demás, confirmado sin sorpresas

- **Lotear** (UC-002): la marca `es_loteado` hace que la recepción exija número de lote y que las existencias se lleven por lote dentro de cada depósito.
- **El lote en la recepción lo escribe quien recibe** (UC-009): campo de texto libre, obligatorio, que la vista habilita solo para artículos loteados.
- **La justificación por diferencia en movimientos internos es obligatoria** (UC-017): la pantalla compara contra lo enviado y muestra *«La cantidad ingresada es distinta a la cantidad enviada, por favor ingrese justificación»*.
- **"Obras" no es orden de trabajo** (UC-012): es un formulario dinámico que se carga a mano y solo se usa en clientes constructores.
- **La entrega directa existe a propósito** (UC-011): hay clientes con procedimientos menos estrictos. El control está en quién puede usarla — solo el Responsable de Almacén.

---

## 4. Cómo se relevó

1. **Menú real, no supuesto.** Entré al DEMO y leí el menú que efectivamente se muestra, en vez de deducirlo de los controladores que existen. Ahí aparecieron las 11 opciones de Almacenes y Stock Producción.
2. **Las 13 pantallas, una por una**, anotando qué columnas, filtros y botones tiene cada una.
3. **Los formularios de alta**, abriéndolos y listando sus campos reales.
4. **El código de los controladores y modelos**, contra `origin/develop` del submódulo (§1.2).
5. **Verificación cruzada de aislamiento** con dos sesiones simultáneas de empresas distintas.

Lo que **no** hice: ejecutar ninguna operación que modifique datos. El DEMO tiene datos de una empresa real (Conservas, 77 pedidos y 60 entregas), y un relevamiento no debería dejar rastro. Por eso las escrituras están relevadas del código y las dudas dicen "hoy nada lo impide" en vez de "lo probé".

Aplicada la lección de F1: **un hallazgo no se reporta sin verificarlo contra la pantalla real.** Dos ejemplos de esta tanda:

- El menú tiene un tabulador dentro del destino de "Stock Valorizado" (`linkTo("…/Stockvalorizado\t")`). Parecía un link roto; lo probé y **el navegador lo normaliza**: la pantalla abre bien. Quedó como suciedad (H-040), no como bug.
- El rol "Responsable Almacén" sin "de" parecía el mismo problema que H-012; resultó ser el nombre del actor de Bonita, que es otra cosa. **No es un hallazgo.**

---

## 5. En qué quedó cada caso

| Caso | Estado |
|---|---|
| ALM-UC-001 a 006, 009 a 018 | **validado** (16) |
| ALM-UC-007 — Ver el detalle de un pedido | `borrador`: el PM pidió expresamente no validarlo todavía |
| ALM-UC-019 — Stock de producción por lote | `borrador`: se mueve a Producción por el ABM de menúes, y ese módulo no se ataca aún |
| ALM-UC-008 — Editar un pedido de materiales | **obsoleto**: hoy un pedido no se puede editar |

---

## 6. Lo único que queda abierto

1. **ALM-UC-007** — ¿un Solicitante ve **solo sus propios pedidos** o todos los de su empresa? Al validar quedó como *"debería ver solo los propios, hoy no lo hace creo"*. De la respuesta depende si es una restricción del caso o una mejora aparte. El resto del caso ya está confirmado: el detalle no debe verse desde otra empresa.
2. **Dos estados de cierre por confirmar** — `Finalizado Ent. Parcial` y `Finalizado Sin Entrega` (§3.2).
3. **El disponible descuenta pedidos sin aprobar** — confirmar si es lo esperado (§3.1).

Ninguna de las tres frena la segunda mitad de F3.

---

## 7. Aviso que sigue vigente para los tests

**Un aviso sobre los tests de ALM:** la empresa de test (`DocTest Empresa SA`) **no tiene el menú de Almacenes** — el trigger de alta solo le asigna menúes al rol Administrador. Para que la suite de ALM corra con datos propios hace falta asignarle el menú de Almacenes a un rol de esa empresa, y eso se hace desde el ABM de menúes, que es justamente `DNATO-UC-024`, uno de los dos casos de DNATO que quedaron en borrador. Lo marco acá porque es la dependencia concreta entre las dos fases.
