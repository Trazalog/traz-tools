# Relevamiento de ALM — dossier de validación

## Objetivo

Es lo que tenés que leer para validar el catálogo de Almacenes: qué se relevó, qué se encontró y **qué preguntas hay que responder** para que los casos salgan de `borrador`. Está escrito para el PM. **No** es el catálogo en sí —eso son los 19 YAML de esta carpeta— ni la guía de cómo funciona DocTest, que está en [`../../GUIA-PRUEBAS-Y-AYUDAS.md`](../../GUIA-PRUEBAS-Y-AYUDAS.md).

**Cómo validar, en concreto.** En una terminal, parado en `traz-tools/doctest/`:

```bash
npm run hoja:validacion -- alm
```

Eso deja `.validacion/alm.html`. Abrilo en el navegador (doble clic), leé caso por caso, marcá la decisión de cada uno y usá el botón **Copiar** al final: arma un texto con todas tus decisiones que me pegás acá. Con eso aplico los cambios al catálogo.

- **Fecha:** 2026-08-25 · **Fase:** DocTest F3 (issue #440) · **Casos:** 19, todos en `borrador`
- **Preguntas abiertas:** 61, repartidas entre los 19 casos

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

El submódulo `traz-comp-almacenes` que apunta `develop-v3` está **25 commits atrás** de la rama `develop` del submódulo, que es lo desplegado.

Se notó porque el menú tiene **Movimientos Internos**, la pantalla abre y funciona en el DEMO, y su controlador **no existe** en el árbol de `develop-v3`: entró en uno de esos 25 commits. Es decir, alguien que releve desde `develop-v3` no ve una pantalla que los usuarios están usando.

**Este relevamiento se hizo contra `origin/develop` del submódulo.** No moví el puntero: cambiarlo 25 commits cambia qué código corre y es una decisión de integración, no de relevamiento. → Issue **#481**.

### 1.3 Un `empr_id` fijo en 1

`Notapedido::pedidoExtraordinario()` guarda `$peex['empr_id'] = 1; //!HARDCODE`. Todos los pedidos extraordinarios de todas las empresas quedan como de la empresa 1: la empresa 1 los ve y la que los pidió no. El resto del mismo controlador usa `empresa()` bien, así que es una omisión puntual. → Issue **#480**.

---

## 2. Qué se relevó

**13 pantallas** del menú (11 en Almacenes + Stock Producción, que está en Producción pero es de este módulo), verificadas una por una contra el DEMO: **las 13 responden HTTP 200 y muestran contenido real**. De ahí salieron 19 casos.

| Caso | Título | Perfil | Dudas |
|---|---|---|---|
| ALM-UC-001 | Ver el listado de artículos del almacén | Responsable de Almacén | 2 |
| ALM-UC-002 | Dar de alta un artículo | Responsable de Almacén | 4 |
| ALM-UC-003 | Editar un artículo | Responsable de Almacén | 3 |
| ALM-UC-004 | Dar de baja un artículo | Responsable de Almacén | 3 |
| ALM-UC-005 | Consultar el stock por establecimiento y depósito | Responsable de Almacén | 2 |
| ALM-UC-006 | **Pedir materiales al almacén** | Solicitante | 5 |
| ALM-UC-007 | Ver el detalle de un pedido de materiales | Solicitante | 2 |
| ALM-UC-008 | Editar un pedido de materiales | Solicitante | 3 |
| ALM-UC-009 | Registrar la recepción de materiales de un proveedor | Responsable de Almacén | 4 |
| ALM-UC-010 | Entregar materiales contra un pedido | Responsable de Almacén | 4 |
| ALM-UC-011 | Entregar materiales sin pedido previo | Responsable de Almacén | 3 |
| ALM-UC-012 | Consultar el detalle de las entregas de un período | Responsable de Almacén | 2 |
| ALM-UC-013 | Consultar el stock valorizado | Responsable de Almacén | 3 |
| ALM-UC-014 | Registrar un ajuste de stock | Responsable de Almacén | 5 |
| ALM-UC-015 | Ver los artículos que llegaron al punto de pedido | Responsable de Almacén | 4 |
| ALM-UC-016 | Mover mercadería entre depósitos — salida | Responsable de Almacén | 4 |
| ALM-UC-017 | Mover mercadería entre depósitos — recepción | Responsable de Almacén | 3 |
| ALM-UC-018 | Consultar los movimientos históricos de un artículo | Responsable de Almacén | 2 |
| ALM-UC-019 | Consultar el stock de producción por lote | Responsable de Almacén | 3 |

### Un perfil nuevo, que no inventé

El alta de empresa crea dos roles de almacén en `toolsCOREAPI`: **`Responsable de Almacén <empresa>`** y **`Solicitante de Almacén <empresa>`**. El segundo entra en el `Solicitante` que el catálogo ya tiene; el primero es nuevo y lo agregué al vocabulario como **propuesto**, pendiente de que lo valides.

Verifiqué además que en este caso **el nombre del rol coincide** entre `toolsCOREAPI` y el trigger que asigna los menúes — o sea que ALM **no** tiene el problema de H-012, donde "Responsable de Procesos" se quedaba sin menú por una diferencia de nombre. (Hay un `"Responsable Almacén"` sin "de" en el mismo XML, pero es el nombre del **actor de Bonita**, que es otra cosa.)

---

## 3. Las preguntas que hay que responder

Están todas dentro de cada caso, en su campo `dudas`, y la hoja de validación las muestra al frente. Acá van agrupadas por tema, porque muchas se responden juntas.

### 3.1 Stock: qué número es cuál

Tres pantallas muestran cantidades y no queda claro que hablen de lo mismo. **Punto de Pedido** tiene dos columnas separadas, "Cant. Stock" y "Cant. Disponible", así que la diferencia existe y es del negocio.

- ¿Qué es cada una: existencia física contra existencia sin comprometer?
- El punto de pedido, ¿se compara contra cuál de las dos? (Si hay stock físico pero comprometido, hay que reponer igual.)
- El punto de pedido es un número por artículo: con varios depósitos, ¿el umbral es del total o de cada uno?

*Casos afectados: ALM-UC-005, ALM-UC-015, y de rebote ALM-UC-019.*

### 3.2 Qué operación mueve stock y con qué control

Cuatro operaciones cambian existencias, con controles muy distintos:

| Operación | Efecto | Control hoy |
|---|---|---|
| Recepción de materiales (UC-009) | suma | ninguno más que tener el menú |
| Entrega contra pedido (UC-010) | resta | hay un pedido aprobado detrás |
| **Entrega directa** (UC-011) | resta | **ninguno: saltea el pedido** |
| **Ajuste de stock** (UC-014) | suma o resta | **ninguno: cambia el número sin que entre ni salga nada** |

- **¿Para qué existe la entrega directa?** Si el pedido existe para que alguien apruebe, la entrega directa equivale a saltear esa aprobación. ¿Es para urgencias, para consumos menores, o quedó de una etapa anterior?
- **¿Quién debería poder hacer un ajuste?** Es el mecanismo para corregir diferencias de inventario y hoy alcanza con tener el menú.
- ¿Alguna de estas operaciones puede dejar el stock en negativo?
- ¿Se pueden anular? Hoy ninguna tiene pantalla de anulación: si una cantidad se cargó mal, el stock queda mal.

### 3.3 El pedido de materiales, que es el flujo del piloto MCP

- **Si Bonita falla, el pedido queda huérfano.** El código guarda el pedido y después lanza el proceso: si eso falla, el pedido ya está guardado sin caso asociado. ADR-012 pide explícitamente el patrón INSERT → BPM → **rollback** para la tool MCP. ¿La pantalla debería comportarse igual, o un pedido sin proceso es un estado aceptable que alguien repara después?
- ¿La justificación es obligatoria siempre, o solo cuando el pedido no viene de una orden de trabajo?
- ¿Se puede pedir más de lo que hay en stock?
- **¿Hasta qué estado se puede editar un pedido?** El código no lo verifica, así que hoy se puede editar uno ya entregado. Y al editar se borra todo el detalle anterior y se vuelve a insertar: si había entregas parciales contra esas líneas, ¿qué pasa con ellas?
- ¿Qué estados recorre un pedido y quién los cambia? En el DEMO se ven pedidos "Entregado", pero el catálogo de estados no está en el código.
- ¿El pedido extraordinario se sigue usando, o quedó reemplazado por el normal?

### 3.4 Bajas, otra vez

En DNATO decidiste que **nunca debe haber borrado físico**, porque rompe la trazabilidad. Acá vuelve a aparecer:

- **ALM-UC-004 (dar de baja un artículo):** el listado tiene columna Estado, lo que sugiere baja lógica, pero el modelo expone `eliminar($id)`. ¿Cuál de los dos corre?
- ¿Se puede dar de baja un artículo que tiene stock, o que aparece en pedidos abiertos?
- Un artículo dado de baja, ¿sigue apareciendo para elegir en un pedido nuevo?

### 3.5 Movimientos entre depósitos

- **¿Dónde está la mercadería en tránsito?** Si la salida descuenta del origen y la recepción suma al destino, en el medio no figura en ningún depósito. ¿Es a propósito o debería verse como stock en tránsito?
- **¿Qué pasa si lo que llega no es lo que salió?** ¿Se registra como faltante, se rechaza, se ajusta?
- ¿La recepción tiene que hacerla alguien del destino, o puede hacerla el mismo que registró la salida?

*Estos dos casos están relevados más por arriba que el resto: la pantalla es reciente y no está en el árbol de `develop-v3` (§1.2).*

### 3.6 Dudas sueltas, pero que cambian el caso

- **UC-002:** el formulario de alta tiene **dos campos con la etiqueta "Código"** — el identificador interno y el código de barras. ¿Cuál escribe el usuario? ¿El interno debería estar visible?
- **UC-002:** ¿qué implica "lotear" un artículo para la operación? El manual de almacén no lo explica y el código solo guarda la marca.
- **UC-009:** ¿el número de comprobante tiene que ser único por proveedor? Hoy se puede cargar dos veces el mismo remito y duplicar el stock.
- **UC-009:** para un artículo loteado, ¿el número de lote lo escribe quien recibe o lo genera el sistema?
- **UC-013:** **¿de dónde sale el precio con el que se valoriza el stock?** ¿De la lista de precios, del último remito, de un promedio? El criterio cambia el número y no está escrito en ningún lado.
- **UC-012:** la pantalla filtra por "Obras" y el resto del módulo habla de órdenes de trabajo. ¿Es lo mismo con otro nombre?
- **UC-019:** **Stock Producción está en el menú de Producción pero es del módulo de Almacenes.** ¿Está bien ahí? ¿En qué se diferencia de Almacenes → Stock? De la respuesta depende en qué manual va su ayuda.
- **UC-018:** ¿el histórico incluye los cuatro tipos de movimiento (recepción, entrega, ajuste, movimiento interno)? Si falta alguno, no cierra contra el stock actual y deja de servir para auditar.

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

## 5. Después de que valides

Con los casos en `validado` sigue la segunda mitad de F3, que es mecánica y ya tiene todo el andamiaje de F1: page objects, specs, `.feature` y la ayuda de usuario del módulo. Los casos que queden en `borrador` no generan nada — ni test, ni escenario, ni ayuda —, que es justamente la garantía de que ninguna ayuda le explique a un usuario algo que nadie confirmó.

**Un aviso sobre los tests de ALM:** la empresa de test (`DocTest Empresa SA`) **no tiene el menú de Almacenes** — el trigger de alta solo le asigna menúes al rol Administrador. Para que la suite de ALM corra con datos propios hace falta asignarle el menú de Almacenes a un rol de esa empresa, y eso se hace desde el ABM de menúes, que es justamente `DNATO-UC-024`, uno de los dos casos de DNATO que quedaron en borrador. Lo marco acá porque es la dependencia concreta entre las dos fases.
