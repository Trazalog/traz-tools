# Bandeja de Tareas (`Proceso2`): funcionamiento actual

**Estado:** documento de referencia. Describe el código del working tree al 2026-10-22.

**Alcance:** bandeja 2 (`traz-comp-bpm/Proceso2`), apertura de tareas, cabecera eager y carga diferida de comentarios, trazabilidad e información.

---

## 1. Resumen

La bandeja 2 resuelve el paginado y la búsqueda en la base. Al abrir una tarea:

- **la tarea se obtiene siempre desde Bonita** con `Procesos->obtener($taskId)`;
- **la cabecera se dibuja antes de mostrar la tarea**, en el mismo request del detalle;
- **comentarios, trazabilidad e información se cargan recién cuando el usuario abre cada pestaña**.

No se usa cache de tareas en sesión ni se completan datos con el JSON de la fila de la bandeja.

---

## 2. Componentes y rutas

| Ruta | Método | Qué hace |
|---|---|---|
| `Proceso2/index` | GET | Carga la vista `bandeja_entrada2`. |
| `Proceso2/paginarServerSide` | POST (DataTables) | Pide la página a `Procesos2::listarPaginaServerSide()` y arma las filas. |
| `Proceso2/detalleTarea/{taskId}` | GET | Obtiene la tarea desde Bonita, dibuja la cabecera y renderiza el detalle. |
| `Proceso2/cargarComentarios/{taskId}` | GET | Carga la pestaña Comentarios bajo demanda. |
| `Proceso2/cargarTimeline/{taskId}` | GET | Carga Trazabilidad e Información bajo demanda. |
| `Proceso/tomarTarea` | POST | Asigna la tarea al usuario. |
| `Proceso/soltarTarea` | POST | Libera la tarea. |
| `Proceso/cerrarTarea/{taskId}` | POST | Cierra la tarea. |

`Proceso2` hereda de `Proceso`. Las rutas de tomar, soltar y cerrar siguen entrando por `Proceso`, que es el código compartido con la bandeja vieja.

### Archivos principales

| Archivo | Rol |
|---|---|
| `controllers/Proceso2.php` | Controller de la bandeja 2; reutiliza el paginado y el detalle de `Proceso`. |
| `controllers/Proceso.php` | Paginado, detalle, cabecera, comentarios, timeline y acciones. |
| `models/Procesos2.php` | Consulta la página al `BandejaDataService` y arma las tareas. |
| `models/Procesos.php` | `map()`, `mapeo()`, `obtener()` y validación de empresa. |
| `views/bandeja_entrada2.php` | Tabla DataTables y click en la fila. |
| `views/notificacion_estandar.php` | Detalle de la tarea, cabecera eager y pestañas lazy. |
| `BandejaDataService.dbs` | Consulta SQL que combina tareas de Bonita con `core.case_empresa`. |

---

## 3. Flujo de carga inicial y paginado

```text
Navegador
  -> Proceso2/index
  -> DataTables AJAX: Proceso2/paginarServerSide
       -> Procesos2::listarPaginaServerSide($start, $length, $search)
            -> BandejaDataService
                 -> tareas pendientes del usuario en Bonita
                 -> core.case_empresa: solo la empresa activa
                 -> búsqueda y totales en SQL
            -> map(): enriquece SOLO las tareas de la página
       -> Proceso::paginarServerSide()
            -> arma el HTML de cada fila
       -> respuesta JSON para DataTables
```

Puntos importantes:

- La página se consulta una sola vez. No se traen todas las tareas para después filtrar en PHP.
- `map()` se ejecuta únicamente sobre las tareas de la página.
- La respuesta de cada fila contiene `DT_RowId`, `DT_RowClass` y el HTML de la columna `0`.
- No se envía `DT_RowData.json`: la fila no transporta una copia completa de la tarea.
- No se guarda nada en la sesión al paginar.

---

## 4. Apertura de una tarea

```text
Click en la fila (.item)
  -> $('#miniView').load('Proceso2/detalleTarea/' + taskId)
       (sin POST: el navegador no manda el JSON de la tarea)
  -> Proceso::detalleTarea($taskId)
       -> Procesos->obtener($taskId)
            -> BPM getTarea
            -> mapeo() + bandejaEmpresa() (validación de empresa)
            -> map() (enriquecimiento del proceso)
       -> si no hay tarea: show_404()
       -> deplegarCabecera($tarea)
       -> deplegarVista($tarea)
       -> render notificacion_estandar
```

La tarea usada para el detalle siempre sale de Bonita. No se toma el `caseId` del navegador ni de la fila de la bandeja.

### Validación de empresa

`Procesos->obtener()` pasa por `mapeo()`, que llama a `bandejaEmpresa($caseId, empresa())` antes de devolver la tarea. Si el caso no pertenece a la empresa activa, `obtener()` devuelve `null` y el detalle responde 404.

### Por qué se quitó el cache de la página

El cache guardaba el objeto que armaba la bandeja (`Procesos2::armarTarea()` + `map()`), no el que devuelve `obtener()`. Eso generaba dos riesgos:

- el objeto podía no tener exactamente las mismas propiedades que espera cada modelo del proceso;
- la entrada quedaba vieja después de tomar, soltar, cerrar o cambiar de empresa.

Volver a `obtener()` elimina esa diferencia y restaura el camino conocido de la bandeja vieja.

---

## 5. Cabecera eager y pestañas lazy

### Cabecera

La cabecera se carga antes de mostrar la tarea:

```php
$data['cabecera'] = $this->deplegarCabecera($tarea);
```

La vista la dibuja con:

```php
<?php echo $cabecera; ?>
```

No hay endpoint `cargarCabecera` ni click previo: cuando el detalle aparece, la cabecera ya está dibujada.

`deplegarCabecera()` carga el modelo del proceso y llama a su `desplegarCabecera()`. Si el modelo imprime HTML en vez de devolverlo, se mantiene el comportamiento original de la vista.

### Comentarios

- Se dispara al abrir la pestaña `#tab_2`.
- Pide `Proceso2/cargarComentarios/{taskId}`.
- Resuelve la tarea con `Procesos->obtener($taskId)`.
- Llama a `ObtenerComentarios($tarea->caseId)`.
- El flag `cargadoComentarios` evita repetir la carga.

### Trazabilidad e Información

- Se disparan al abrir `#tab_3` o `#tab_1`.
- Una sola llamada a `Proceso2/cargarTimeline/{taskId}` devuelve los dos bloques.
- Resuelve la tarea con `Procesos->obtener($taskId)`.
- Llama a `ObtenerLineaTiempo($tarea->processId, $tarea->caseId)`.
- `timeline()` y `timelineInfoActual()` imprimen HTML; se capturan con `ob_start()`.
- El flag `cargadoTimeline` evita repetir la carga.

> `ObtenerLineaTiempo()` sigue siendo la operación más costosa de las pestañas: hace varios logins y consultas a Bonita. La diferencia es que ahora no se ejecuta al abrir la tarea, sino solo si el usuario abre Trazabilidad o Información.

---

## 6. Acciones sobre la tarea

### Tomar

```text
POST Proceso/tomarTarea
  -> BPM setUsuario(taskId, userId)
  -> devuelve status y user_id
```

No se modifica ningún cache local.

### Soltar

```text
POST Proceso/soltarTarea
  -> BPM setUsuario(taskId, "")
  -> devuelve el resultado
```

### Cerrar

```text
POST Proceso/cerrarTarea/{taskId}
  -> BPM getTarea + mapeoTarea + getContrato
  -> BPM cerrarTarea
  -> devuelve el resultado
```

La próxima apertura de la tarea vuelve a consultar Bonita y refleja el estado real.

---

## 7. Seguridad

- El detalle no usa datos enviados por el navegador para armar la tarea.
- La tarea se obtiene desde Bonita por `taskId`.
- `mapeo()` valida que el `caseId` pertenezca a la empresa activa con `bandejaEmpresa()`.
- Si la tarea no existe o no pertenece a la empresa, se responde 404.
- Los endpoints lazy (`cargarComentarios`, `cargarTimeline`) también resuelven la tarea con `obtener()`, por lo que repiten la validación de empresa.
- No se agregó autenticación nueva ni CSRF; se mantiene el esquema existente.

---

## 8. Rendimiento

| Acción | Consultas a Bonita / REST | Observación |
|---|---|---|
| Cargar o paginar la bandeja | 1 consulta al `BandejaDataService` + enriquecimiento de la página | No se enriquece la bandeja completa. |
| Abrir tarea | 1 `getTarea` + `mapeo()` | Es el costo de no usar cache ni datos de la bandeja. |
| Dibujar cabecera | 0 `getTarea` extra | Usa la misma tarea ya obtenida para el detalle. |
| Abrir comentarios | 1 `getTarea` + 1 `ObtenerComentarios` | La tarea se vuelve a resolver al abrir la pestaña. |
| Abrir trazabilidad | 1 `getTarea` + `ObtenerLineaTiempo` | `ObtenerLineaTiempo` sigue siendo costoso por dentro. |
| Paginar | 0 llamadas extra | No se escribe cache en sesión. |

No se instrumentó ni se midió formalmente; la evaluación es por análisis del flujo.

---

## 9. Casos borde

| Caso | Comportamiento |
|---|---|
| URL directa a `detalleTarea/{taskId}` | Igual que desde la bandeja: `obtener()` + validación de empresa. |
| Volver a una página anterior y abrir una tarea | No depende de cache: se obtiene de nuevo desde Bonita. |
| Cambiar de empresa | `obtener()` valida contra la empresa activa; si no corresponde, 404. |
| Tarea cerrada desde otra sesión | Al abrirla, Bonita devuelve el estado actual o la tarea ya no existe. |
| Tomar o soltar | Se refleja en la próxima apertura o paginado. |
| Cerrar | La tarea sale de la lista; no queda estado local que limpiar. |
| Bandeja vieja (`Proceso`) | Sigue con `obtener()` como antes. |
| Búsqueda sin resultados | La tabla queda vacía; no hay cache que invalidar. |
| Varias pestañas del navegador | Cada detalle se resuelve con su propia consulta a Bonita. |

---

## 10. Verificación realizada

- `php -l` sobre `Proceso.php`, `Procesos.php`, `Proceso2.php`, `notificacion_estandar.php` y `bandeja_entrada2.php`.
- `git diff --check` sin errores.
- No se ejecutó una prueba funcional en navegador dentro de esta sesión.

### Checklist manual sugerida

1. Entrar a la bandeja 2 y verificar que la primera página carga.
2. Abrir una tarea: la cabecera debe verse sin hacer click.
3. Abrir Comentarios, Trazabilidad e Información: deben cargar recién al clickear.
4. Verificar que no se escribe `bpm_tareas_vista` en la sesión.
5. Paginar, buscar y abrir una tarea de la nueva página.
6. Tomar y soltar una tarea; verificar el ícono de asignado.
7. Cerrar una tarea; verificar que desaparece.
8. Abrir una tarea por URL directa.
9. Cambiar de empresa y verificar que no se abre una tarea de la empresa anterior.
10. Abrir la bandeja vieja y confirmar que sigue funcionando.

---

## 11. Pendientes conocidos

- `BPM::loggin()` no cachea el token: cada operación que lo necesita vuelve a loguearse.
- `ObtenerLineaTiempo()` sigue haciendo varios logins y consultas.
- El lock de sesión de CodeIgniter y los timeouts de `REST.php` no se tocaron.
- Quedan `debugger;` en `bandeja_entrada2.php`, `tarea_std.php`, `comentarios.php` y `notificacion_estandar.php`.
- No hay tests automatizados de este flujo.

---

## 12. Archivos modificados en esta etapa

```text
application/modules/traz-comp-bpm/controllers/Proceso.php
application/modules/traz-comp-bpm/models/Procesos.php
application/modules/traz-comp-bpm/views/bandeja_entrada2.php
application/modules/traz-comp-bpm/views/notificacion_estandar.php
```

`views/scripts/tarea_std.php` aparece modificado en el working tree por cambios previos (marcadores `debugger;`), no por esta etapa.
