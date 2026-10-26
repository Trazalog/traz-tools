# Pedido y pañol en la OT — plan de implementación

> **ARCHIVADO el 2026-10-26.** Reemplazado por [`../MIGRACION-ASSETPLANNER.md`](../MIGRACION-ASSETPLANNER.md), que es el único documento vigente de la migración. Se conserva como referencia de detalle; si algo de acá lo contradice, vale aquel.

## Context

Dos huecos en el mismo lugar del circuito, y por eso se resuelven juntos.

**Herramientas.** AssetPlanner declara herramientas en el plan y en la OT, y al guardar el informe
genera un vale contra el pañol de Tools (eso fue M2). El vale nace en el lugar equivocado y nadie
registra qué se usó realmente: la lista del informe es lo que el técnico tipea a mano, no lo que
salió del pañol. Se separan las dos listas — la **declarada** (necesidad del trabajo, del maestro
completo, con texto libre para lo que no está catalogado) y la **usada** (armada desde vales reales,
con el tiempo que cada herramienta estuvo afuera).

**Materiales.** El informe dice "Insumos usados" pero muestra lo **pedido**. M1 separó Pedido /
Entregado / Pendiente, pero "entregado" sigue siendo un número derivado (`pedido − resto`): no se ve
cuándo se entregó, en cuántas veces, de qué lote y depósito, ni con qué remito. Y el supervisor
aprueba el informe sin ver materiales en absoluto. Se agrega el **detalle de entregas** en las cinco
pantallas donde el mantenimiento lo necesita.

**Maquetas validadas** (son la especificación visual de este plan):
- Circuito de herramientas por rol: https://claude.ai/artifact/3ibjnNxxMWfZAsqP36gGUE
- Pedido y pañol en contexto de cada pantalla: https://claude.ai/artifact/8Zb3yVVjWdk3NCbfxAR3sB

**Alcance**: `traz-prod-assetplanner` (las cinco pantallas) y `traz-tools` (el pañolero asocia la OT
al entregar, y las queries que hoy no existen).

---

## 🚨 Restricción que atraviesa todo el plan: PHP 5.6

El PHP de destino es **5.6**; local hay 7.3 y 8.3. Una expresión de 7.x pasa el lint local y recién
revienta en DEMO, donde aparece como bug.

**Nada de**: `??`, `?->`, `<=>`, arrow functions `fn() =>`, type hints escalares, return types,
`declare(strict_types=1)`, clases anónimas, destructuring corto `[$a, $b] = …`, coma final en
llamadas, `JSON_THROW_ON_ERROR`. Sí: `array()` o `[]`, `...` variádico, `::class`, `array_column`.

**El gate es estático, no de runtime.** Antes de cada PR:
`phpcs -p . --standard=PHPCompatibility --runtime-set testVersion 5.6 --extensions=php`
(instalado fuera del repo: `composer global require squizlabs/php_codesniffer phpcompatibility/php-compatibility`),
más un grep de esos patrones como red barata.

**Ya verificado**: el código de M1/M2/F3-F5 de agosto no tiene ninguna de esas expresiones.

---

## Definiciones cerradas

**Herramientas**

| # | Definición |
|---|---|
| 1 | La lista de usadas vive **en asset, en tablas nuevas** — excepción aprobada al freeze del esquema |
| 2 | El campo del formulario dinámico del vale se llama **DNI** (comparación sin distinguir mayúsculas) |
| 3 | Mantenedor sin DNI cargado **no puede asociar** herramientas usadas |
| 4 | El pañolero ve las OT **asignadas al mantenedor que él todavía no cerró** |
| 5 | **Un vale, una sola OT**; una OT acepta varios vales |
| 6 | Mantenimiento no controla la devolución, solo el uso: el informe muestra **días de uso** |
| 7 | El filtro de disponibilidad **se revierte** donde no corresponde (planes y OT vuelven al maestro) |
| 8 | El mantenedor solo quita lo que él asoció; el supervisor puede quitar vales del pañolero |
| 9 | El usuario de asset y el de Tools son **el mismo** |
| 10 | La devolución se deduce por trazabilidad: **primera entrada posterior** a la salida |

**Materiales**

| # | Definición |
|---|---|
| 11 | **El precio no se muestra** en ninguna pantalla. El DataService lo trae; queda para más adelante |
| 12 | **Ver OT es solo lectura**: no se opera el pedido desde ahí |
| 13 | Pedido **rechazado**: Ver OT y Ejecutar OT muestran el motivo y **llevan a la tarea "Comunica Rechazo"** de la bandeja, que ya permite corregir y repetir. **No se crean pedidos nuevos** |
| 14 | Sin pedido: **estado vacío explícito** ("esta OT no generó pedido de materiales"), nunca una tabla en blanco |

---

## Hallazgos que condicionan el diseño

**1. La vista de Entrega Materiales de Tools no usa DataServices.** Su model
`application/modules/traz-comp-almacenes/models/Ordeninsumos.php` tiene **63 consultas SQL directas**
a PostgreSQL y cero REST. Como asset accede a Tools solo por REST, esas consultas **hay que
reprogramarlas como DataServices**: no es reusar una vista, es exponer el dato.

Además la query que alimenta esa pantalla (`get_detalle_entrega`) calcula el stock disponible de los
depósitos que **encarga el usuario logueado** (`core.encargados_depositos`). Para el informe eso no
aplica: al mantenimiento le importa qué se entregó, no qué queda en el depósito de quien mira. La
query nueva **no es un copy** de la existente.

**2. El circuito de corrección del rechazo ya existe y es completo.** La tarea Bonita
**"Comunica Rechazo"** (`application/controllers/traz-comp-almacen/Proceso.php:152`) se atiende desde
la bandeja con `views/traz-comp-almacen/proceso/tareas/pedido_materiales/view_comunica_rechazo.php`:
muestra el motivo, pregunta si se repite, y al elegir "Sí" despliega el pedido **en modo editable**
(`componentes/pedido_materiales.php`) para corregirlo antes de relanzarlo con `pedidoNormal()`. Por
eso la definición 13 no construye nada nuevo: **le da visibilidad a lo que ya está**.

**3. El informe ya itera sobre varios pedidos** (`Ordenservicios::getInsumosPorOT`), pero
`Calendario::verEjecutarOT:642` toma **uno solo** (`getPedidoMaterialesOT(...)->pema_id`). Con la
definición 13 esa asimetría no molesta y no hay que tocarla.

---

## Modelo de datos

### Asset (MariaDB `assetv2`) — excepción aprobada al freeze

```
tbl_otvales                          -- qué vales están asociados a qué OT
  valeot_id   int PK auto
  otId        int NOT NULL           -> orden_trabajo.id_orden
  sapa_id     int NOT NULL           -- vale de salida en pan.salida_panol (Tools)
  origen      varchar(12) NOT NULL   -- PANOLERO | MANTENEDOR | SUPERVISOR
  usrId       int NOT NULL
  fecha       datetime NOT NULL
  id_empresa  int NOT NULL
  UNIQUE KEY uq_vale (sapa_id, id_empresa)   -- definición 5
  KEY idx_ot (otId, id_empresa)

tbl_otherramientasusadas             -- qué herramienta de ese vale se usó
  otherrusada_id int PK auto
  otId, herrId, sapa_id  int NOT NULL
  activa      tinyint(1) NOT NULL DEFAULT 1   -- el tilde de "usó"
  id_empresa  int NOT NULL
  UNIQUE KEY uq_herr_vale (otId, herrId, sapa_id, id_empresa)
  KEY idx_ot (otId, id_empresa)

ALTER TABLE tbl_otherramientas ADD COLUMN descripcion_libre varchar(255) NULL;
-- herrId queda en 0 cuando la fila es texto libre
```

La cabecera existe para poder exigir la unicidad del vale y para registrar quién lo asoció, que es lo
que habilita los permisos de la definición 8. El texto libre va **solo en la OT**, no en los planes:
un ítem sin código no se puede cruzar con un vale.

### Tools — lista de valores

`configuraciones_panol` **no existe**: se crea en `core.tablas` por empresa, con `ASOCIAR_OT` ∈
{`OBLIGATORIA`, `OPTATIVA`, `NO_APLICA`}. Se lee con `Valores->obtenerTablaEmpr_id()`
(`application/models/core/Valores.php:161`); desde asset, con el patrón de `tools_config()`
(`application/helpers/tools_helper.php:65`).

---

## Queries nuevas en Tools (todas aditivas)

**`ALMDataService.dbs`** — para el detalle de entregas

| Query | Resource | Devuelve |
|---|---|---|
| `getEntregasPorPedido` | `GET /entregas/pedido/{pema_id}` | Entregas del pedido: `enma_id`, fecha, comprobante, solicitante, dni, destino |
| `getDetalleEntregaPorId` | `GET /entregas/detalle/{enma_id}` | Qué salió: artículo, cantidad, lote, depósito (el precio se trae pero no se muestra — def. 11) |

**`PANDataservice.dbs`** — para los vales

| Query | Para qué |
|---|---|
| `salidasPorDniYFecha` | Vales del mantenedor: join `pan.salida_panol` → `frm.instancias_formularios` con `lower(name)='dni'` y `valor = :dni`, por empresa y rango de fechas |
| `salidasPorFecha` | Lo mismo sin filtro de DNI, para el supervisor |
| `salidaPorId` | Cabecera + detalle de un vale, para el modal |
| `entradaQueCierraSalida` | Primera entrada de esa herramienta con `fec_alta >= :fecha_salida` — definición 10 |

**`MANDataService.dbs`** — es el que ya consume `assetv2`; por acá Tools lee y escribe en asset

| Query | Para qué |
|---|---|
| `otsSinCerrarPorUsuario` | OT asignadas al mantenedor y no cerradas (join `orden_trabajo` → `asignausuario` → `sisusers`, estado distinto de CE/CN) |
| `setOtVale` / `setOtHerramientaUsada` | Insertan la cabecera y el detalle de las tablas nuevas |

> **Verificar primero**: que el datasource de `MANDataService` tenga escritura sobre `assetv2`. Hoy
> solo se lo usa para lectura. Si es de solo lectura, F6 no puede escribir y hay que resolverlo antes.

---

## Dónde entra cada cosa, pantalla por pantalla

| Pantalla | Vista | Pedido y entregas | Herramientas |
|---|---|---|---|
| **Ejecutar OT** | `views/calendar/view_OtEjecutar_modal.php` | Se amplía la pestaña **Pedido Materiales** que ya existe: estado, entregas, y el acceso a la tarea si está rechazado | **Pestaña nueva** (hoy el modal no tiene nada de herramientas) |
| **Ver OT** | `views/otrabajos/view_agregarOT.php` vía `Otrabajo::getpencil` | **Bloque nuevo** en la pestaña Insumos, en lectura (def. 12) | Se amplía: maestro completo + texto libre + usadas en lectura |
| **Confeccionar informe** | `views/tareas/view_inf_servicio_modal.php` | Se amplía la pestaña **Insumos** con las entregas | Se amplía: declaradas en lectura + usadas desde vales |
| **Verificar informe** | `views/tareas/view_verifica_informe.php` | **Pestaña nueva** (hoy el supervisor no ve materiales) | **Pestaña nueva**: asociar sin filtro de DNI y quitar vales |
| **Ver informe** | `views/tareas/view_presta_presta_conf_modal.php` | **Pestañas nuevas** (la vista hoy no tiene ninguna) | Se amplía con el tiempo de uso |

---

## Fases

Un PR por fase contra `develop-v3` del repo correspondiente.

### F0 — Ajustar la maqueta y verificación visual

- Ajustar la maqueta de pantallas con la definición 13: donde hoy dice "Generar nuevo pedido" pasa a
  ser el motivo del rechazo + acceso a la tarea de la bandeja.
- Levantar AssetPlanner con el PHP 7.3 de XAMPP (`/opt/lampp/bin/php -S`) contra `assetv2` de DEV,
  **con URLs limpias** (sin `index.php` explícito, o el JS duplica el prefijo), navegar las cinco
  pantallas y sacar capturas del estado actual. Sobre esas capturas se marca dónde cae cada agregado
  y se valida con el PM antes de escribir código. **Requiere VPN arriba.**

### F1 — Datos y configuración

- `database/scripts/f7-herramientas-usadas.sql` en asset: las dos tablas y `descripcion_libre`,
  idempotente, con reversa comentada (patrón de `f3-inhabilitar-menu-almacen.sql`).
- Alta de `configuraciones_panol` en `core.tablas` para la empresa de prueba.
- Registrar la excepción al freeze en `doc/migracion/assetplanner-a-traz-tools-man.md` (R1) y en el
  `CONTEXT-PACK.md` de asset.

### F2 — Queries en Tools

Las ocho queries de arriba, probadas una por una con `curl` contra el EI de DEV antes de cerrar la
fase. Recordar que **el script de deploy no sube las APIs**: si hay que tocar `toolsMANAPI.xml` o la
API de PAN, ese despliegue es manual.

### F3 — Asset: declaradas desde el maestro + texto libre

- Revertir el filtro de disponibilidad (def. 7): `tools_herramientas_autocomplete()` y
  `tools_herramientas_full()` vuelven a `tools_herramientas()`. **`tools_herramientas_informe()` no
  cambia**: ahí el filtro sí corresponde.
- `views/otrabajos/view_agregarOT.php`: campo de texto libre bajo la tabla, y la fila se muestra con
  marca de "texto libre" en vez de código.
- `models/Otrabajos.php`: `insertOTHerram()` y `getOTHerramientas()` manejan `descripcion_libre`.

### F4 — Asset: pedido y entregas en las cinco pantallas

- Helper: `tools_entregas_pedido($pema)` y `tools_entrega_detalle($enma)`.
- `models/Ordenservicios.php`: `getEntregasPorOT($idOt)` recorre los pedidos de la OT y arma
  cabeceras + detalle.
- Un **partial reutilizable** con el bloque de pedido (barra de estados, tabla pedido/entregado/
  pendiente, lista de entregas, modal de detalle, estado vacío de la def. 14 y el aviso de rechazo
  con el link a la tarea). Se incluye en las cinco vistas en lugar de repetir el markup cinco veces.
- Para el link de la def. 13: resolver si la tarea "Comunica Rechazo" está abierta con el `getToDoList`
  de Bonita que ya se usa en `Calendario.php:32`.

### F5 — Asset: herramientas usadas (mantenedor y supervisor)

- Model nuevo `models/Otherramientasusadas.php`: `getPorOt`, `asociarVale`, `quitarVale`,
  `setActiva`, `getValesDeOt`.
- Helper: `tools_vales_por_dni($dni, $desde, $hasta)`, `tools_vales($desde, $hasta)`,
  `tools_vale($sapa)`, `tools_usuario_dni($nick)`, `tools_devolucion_herramienta($herrId, $desde)`.
- `controllers/Ordenservicio.php` y `controllers/Tarea.php`: endpoints AJAX `buscarVales`,
  `asociarVale`, `tildarHerramienta`, `quitarVale`, `verVale`.
- Buscador con desde/hasta y atajos (última semana, último mes, últimos 3 meses). **Reusar
  `Vales::printVale`** de Tools (`traz-comp-pan/controllers/Vales.php:24`) para el modal del vale, que
  ya renderiza cabecera, detalle y formulario dinámico.
- Permisos (def. 8) **también en el servidor**, no solo deshabilitando el checkbox en la vista.
- Sin DNI (def. 3): botón deshabilitado con el motivo a la vista.
- `setOrdenServicios()` deja de llamar a `tools_crear_vale_salida()`: el vale ya no nace al guardar el
  informe. Las escrituras de `tbl_valesalida`/`tbl_detavalesalida` se mantienen por el histórico.

### F6 — Tools: el pañolero asocia la OT

`traz-comp-pan/controllers/Movimientoherramientas.php` (`nuevaSalida`, línea 112) y
`views/movimientosherramientas/modal_salida.php`: buscador de usuario, grilla de OT sin cerrar, y los
tres modos de `configuraciones_panol` — `OBLIGATORIA` (requerido, sin OT no se entrega), `OPTATIVA`
(se puede confirmar vacío), `NO_APLICA` (el bloque no se muestra). Al confirmar con OT, escribe en
asset por `MANDataService` con origen `PANOLERO`.

### F7 — Pruebas y ayudas

**Specs** en `tests/e2e/` de asset, con el patrón de `fixtures.js`:
- `07-herramientas-usadas.spec.js`: texto libre, filtro por DNI, filtro de fechas, permisos del
  mantenedor, supervisor quitando un vale del pañolero, días de uso.
- `08-pedido-entregas.spec.js`: el pedido con sus entregas en las cinco pantallas, el estado vacío, el
  aviso de rechazo, y que **el precio no aparezca** (def. 11).

Esta vez **con un caso de escritura que corra por defecto** contra la empresa de prueba: el tramo de
escritura es el más riesgoso y en M2 quedó detrás de un flag sin cubrir (deuda §2.3 del traspaso).

**Casos funcionales** en el catálogo DocTest (`traz-tools/doctest/catalogo/man/`), después de
MAN-UC-037, con la estructura de MAN-UC-014 (`referencias_codigo`, `pantallas`, `flujo_principal`,
`validaciones`): declarar con texto libre, asociar vale propio, destildar lo propio, el supervisor
asocia sin filtro, el pañolero asocia al entregar, el informe con tiempo de uso, y ver las entregas
de un pedido.

**Ayudas**: no se editan los HTML. `npm run features` y `npm run ayudas` en `doctest/` los regeneran
desde el catálogo. Revisar el texto manual de `doctest/ayudas/src/man/manual_mantenimiento.html`, y
recordar el `.gitattributes`: el conflicto en `ayuda/` no se resuelve a mano, se regenera.

### F8 — Prueba integral

En DEV, con capturas, en un documento como `doc/v3/pruebas-f6-resultados.md`: declarar con texto libre
→ el pañolero entrega asociando la OT → el mantenedor completa con un vale propio y destilda uno → el
supervisor quita el vale del pañolero → el informe muestra las dos listas con días de uso, el pedido
con sus dos entregas parciales y sin precio.

---

## Verificación

- **PHP 5.6**: `phpcs --standard=PHPCompatibility --runtime-set testVersion 5.6` en **cada** PR. Es el
  único control que detecta esta clase de bug antes de DEMO.
- **Por pantalla**: F0 al empezar y F8 al terminar, las dos con capturas y validadas con el PM.
- **Por endpoint**: `curl` contra el EI de DEV para cada query nueva de F2, antes de que el PHP la use.
- **Automática**: `cd tests/e2e && PW_CHANNEL=chrome npx playwright test` con la app en XAMPP;
  `cd doctest && npm run validate:catalog` para los casos nuevos.
- **Regresión**: los specs 01 a 06 tienen que seguir verdes. Ojo: el **06 verifica el filtro de
  disponibilidad en los planes**, que F3 revierte — **ese spec hay que actualizarlo**, no es que se rompa.

## Riesgos

1. **Escritura Tools → asset.** Si el datasource de `MANDataService` es de solo lectura, F6 no puede
   escribir. Es lo primero a verificar en F2.
2. **El DNI tiene que estar cargado en los dos lados** para F5 y F6. Con la definición 9 queda
   pendiente el saneamiento de los usuarios que hoy existen solo en asset.
3. **PHP 5.6 en DEMO.** El riesgo más caro porque no se ve hasta el despliegue.
4. **Datos de entrega en DEV.** Para probar el bloque de entregas hace falta un pedido **entregado
   parcialmente y ligado a una OT**. Los entregados que hay en DEV son extraordinarios (`ortr_id = 0`,
   sin OT), así que hay que generar el caso desde las pantallas de almacén de Tools.
5. **Compatibilidad con v2**: todo lo de Tools es aditivo. Lo único que cambia de comportamiento es el
   filtro de disponibilidad, y solo afecta a asset.

## Queda abierto

**Rechazo cerrado con "No, gracias".** Si el mantenedor atiende la tarea "Comunica Rechazo" y elige no
repetir, la tarea se cierra y el pedido queda rechazado **sin ninguna tarea abierta**. Con la
definición 13 (solo llevar a la tarea, sin crear pedidos nuevos) ese caso queda sin salida desde la OT:
habría que pedir desde las pantallas de almacén de Tools. Las pantallas lo van a mostrar como "pedido
rechazado, sin tarea pendiente". Si eso resulta molesto en el uso real, la salida es habilitar el
pedido nuevo — y ahí sí hay que adaptar `Calendario::verEjecutarOT`, que asume un pedido por OT.
