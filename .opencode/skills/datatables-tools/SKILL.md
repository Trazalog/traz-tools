---
name: DataTables Tools
description: Armar listados con DataTable server-side paginado en traz-tools (CodeIgniter + AdminLTE) igual que traz-comp-pan/views/herramienta/list.php: columnas con render, panel de filtros, botones Excel/PDF/Copiar/Imprimir con export completo, createdRow data-json, loader wo()/wc() y recarga tras acciones.
---

# Listados DataTable en traz-tools

Patrón de referencia: `application/modules/traz-comp-pan/views/herramienta/list.php`
(controller `Herramienta::listarHerramientasPaginado`, modelo `Herramientas::listarHerramientasPaginado`).

Plantilla copiable: `templates/listado.php` (relativa a este `SKILL.md`).

## Reglas clave

1. **Server-side siempre**: `serverSide: true` + `processing: true`, y el controller devuelve
   `draw / recordsTotal / recordsFiltered / data`. Nunca cargar todas las filas al cliente.
2. **Tabla sin estilos propios**: `class="table table-bordered table-striped"` con `<thead>`
   completo y `<tbody></tbody>` vacío.
3. **La columna “Acciones” va primera**, con `data: null`, `orderable: false`, `searchable: false`
   y un `render` que devuelve los íconos FontAwesome con sus clases `btnAlgo` (`btnInfo`,
   `btnEditar`, `btnEliminar`, ...) y un `title`.
4. **`createdRow` guarda la fila completa** en `data-json`:

   ```js
   createdRow: function (row, data) { $(row).attr('data-json', JSON.stringify(data)); }
   ```

   Después los handlers leen `$(this).closest('tr').attr('data-json')` y, si no está, caen a
   `$('#tabla').DataTable().row(tr).data()`.
5. **Handlers delegados y re-entrantes**:

   ```js
   $(document).off('click', '.btnEditar').on('click', '.btnEditar', function () { ... });
   ```

6. **Filtros**: inputs/selects con ids `filtro_*`; se mandan en `ajax.data` solo si tienen valor.
   Al cambiar un filtro: `$('#tabla').DataTable().ajax.reload();`.
7. **Loader global `wo()` / `wc()`** (en `application/views/layout/general_scripts.php`) alrededor
   de cada AJAX de acción. `wc()` en `success` **y** `error` (o en `complete`) para no dejar el
   overlay trabado.
8. **Recarga tras guardar/eliminar**: `$('#tabla').DataTable().ajax.reload(null, false);`
   (mantiene la página actual), envuelto en `if ($.fn.DataTable.isDataTable('#tabla'))`.
9. **Confirmaciones**: `Swal.fire` si existe, si no `alertify.confirm`, si no `confirm`.
   Avisos: `alertify.success/error`.
10. **Escapado**: para armar HTML con datos usar un helper `esc()`; para celdas simples, `.text()`.

## Configuración base

```js
$('#tabla_x').DataTable({
    "processing": true,
    "serverSide": true,
    "ajax": {
        "url": "<?php echo base_url(MOD) ?>Controlador/listarPaginado",
        "type": "POST",
        "data": function (d) {
            var filtro = $('#filtro_x').val();
            if (filtro) d.filtro = filtro;
        }
    },
    "columns": [
        { "data": null, "orderable": false, "searchable": false, "render": function (data, type, row) {
            return '<i class="fa fa-fw fa-pencil text-light-blue btnEditar" style="cursor: pointer;margin: 3px;" title="Editar"></i>'
                 + '<i class="fa fa-fw fa-trash text-light-blue btnEliminar" style="cursor: pointer;margin: 3px;" title="Eliminar"></i>';
        }},
        { "data": "codigo" },
        { "data": "descripcion" },
        { "data": "estado", "render": function (data) {
            if (data === 'ACTIVO')  return '<small class="label pull-left bg-green">Activa</small>';
            if (data === 'BAJA')    return '<small class="label pull-left bg-red">Inhabilitada</small>';
            return '<small class="label pull-left bg-gray">' + (data || '-') + '</small>';
        }}
    ],
    dom: 'lBfrtip',
    buttons: [ /* ver abajo */ ],
    "createdRow": function (row, data) { $(row).attr('data-json', JSON.stringify(data)); }
});
```

Para columnas calculadas usar `render` y respetar `type` (`if (type !== 'display') return data;`)
cuando el orden/búsqueda deben usar el valor crudo.

## Botones de exportación (Excel / PDF / Copiar / Imprimir)

`dom: 'lBfrtip'` + los 4 botones, en este orden y con estas clases:

| Botón    | Clase                          | Texto                                   |
| -------- | ------------------------------ | --------------------------------------- |
| Excel    | `btn btn-success btn-flat ml-1` | `Exportar a Excel <i class="fa fa-file-excel-o"></i>` |
| PDF      | `btn btn-danger btn-flat ml-1`  | `Exportar a PDF <i class="fa fa-file-pdf-o"></i>`     |
| Copiar   | `btn btn-primary btn-flat ml-1` | `Copiar <i class="fa fa-file-text-o"></i>`            |
| Imprimir | `btn btn-default btn-flat ml-1` | `Imprimir <i class="fa fa-print"></i>`                |

Cada botón lleva:
- `exportOptions.columns` con los índices **sin** la columna Acciones.
- `title`, `filename`, `footer: true`.
- `messageTop: function () { return obtenerInfoReporte(); }` — función que arma
  `"Fecha de reporte: dd/mm/aaaa"` + los filtros aplicados leyendo los `#filtro_*`.
- `action` que exporta **todo**, no solo la página:

```js
action: function (e, dt, button, config) {
    var self = this;
    var oldLength = dt.page.len();
    dt.page.len(1000000);
    dt.one('draw', function () {
        $.fn.dataTable.ext.buttons.excelHtml5.action.call(self, e, dt, button, config);
        setTimeout(function () { dt.page.len(oldLength).draw(); }, 100);
    });
    dt.draw();
}
```

(cambiar `excelHtml5` por `pdfHtml5`, `copyHtml5` o `print` según el botón).

Extras del PDF (`customize`): logo a la derecha si la vista recibe `$logo`, `defaultStyle.fontSize = 9`,
`doc.styles.tableHeader.fillColor = '#dd4b39'`, `color: 'white'`, `alignment: 'center'`,
y `widths` proporcionales al final.

Extras del print (`customize`): borrar `link[href=""]` / `script[src=""]` (generan 404 en
CodeIgniter), quitar `data-json`, sacar el `h1` y prepender una cabecera con borde inferior
`#dd4b39`, estilizar los `th` con fondo `#dd4b39` y texto blanco.

## Backend

**Controller** (contrato DataTables):

```php
$draw      = intval($this->input->post('draw') ?: $this->input->get('draw') ?: 1);
$page_size = intval($this->input->post('length') ?: 10);
$start     = intval($this->input->post('start') ?: 0);
$search    = $this->input->post('search')['value'] ?? '';
$order_dir = strtolower($this->input->post('order')[0]['dir'] ?? 'desc');

$resultado = $this->Modelo->listarPaginado([...]);

echo json_encode([
    'draw'            => $draw,
    'recordsTotal'    => $total,
    'recordsFiltered' => $total,
    'data'            => $filas,
]);
```

**Modelo**: arma los parámetros y llama al REST (`REST_PAN`, `REST_ALM`, etc.); el total se
obtiene con `COUNT(*) OVER()` en la misma consulta (`total_count`). Ojo: WSO2 devuelve un
**objeto** en vez de array cuando hay un solo resultado, así que normalizar:

```php
if (!is_array($filas) && is_object($filas)) { $filas = [$filas]; }
```

## Estructura de la vista

```php
<!-- tabla -->
<table id="tabla_x" class="table table-bordered table-striped">...</table>

<!-- estilos propios del listado, solo si hacen falta visuales (badges, tooltips) -->
<style> ... </style>

<script> ... config + handlers ... </script>

<?php $this->load->view('modulo/modals/modal_editar'); ?>
<?php $this->load->view(COD . 'componentes/modalX'); ?>
```

Los modales van al final; ver el skill `modales-tools` para la estructura de cada uno.

## Verificación

1. `C:\xampp\php\php.exe -l <vista>` y `-l` de controller/modelo tocados.
2. Si el JS es grande, extraerlo a un `.js` temporal y `node --check`.
3. Probar que:
   - la paginación trae `recordsTotal` correcto,
   - los filtros se reflejan en el `messageTop` del reporte,
   - Excel/PDF/Imprimir exportan **todas** las filas y luego la tabla vuelve a la página original,
   - tras guardar/eliminar la tabla se recarga sin saltar de página,
   - `wo()`/`wc()` quedan balanceados en éxito y error.
