// Columna "Acciones" — patron de traz-comp-almacenes/views/articulo/list.php
// Ver .opencode/skills/iconos-acciones/SKILL.md
//
// El color va en el <td> (text-light-blue = #3c8dbc), no en los iconos.
// Reemplazar las funciones onclick por las del listado.

// ---------------------------------------------------------------------------
// Opcion A: columnDefs (formato usado en articulo/list.php)
// Copiar el objeto dentro de la config del DataTable.
// ---------------------------------------------------------------------------
var opcionColumnDefs = {
    columnDefs: [
        {
            targets: '_all',
            defaultContent: '-'
        },
        {
            targets: [0],
            orderable: false,
            searchable: false,
            createdCell: function (td, cellData, rowData, row, col) {
                $(td).attr('class', 'text-center text-light-blue');
            },
            data: 'acciones',
            render: function (data, type, row) {
                return '<i class="fa fa-search" style="cursor: pointer; margin: 3px;" title="Ver Detalles" onclick="ver(this);"></i>'
                     + '<i class="fa fa-fw fa-pencil" style="cursor: pointer; margin: 3px;" title="Editar" onclick="editar(this)"></i>'
                     + '<i class="fa fa-fw fa-times-circle" style="cursor: pointer; margin: 3px;" title="Eliminar" onclick="eliminar(this)"></i>';
            }
        }
    ]
};

// ---------------------------------------------------------------------------
// Opcion B: API columns (formato del skill datatables-tools)
// Copiar el objeto dentro de la config del DataTable.
// ---------------------------------------------------------------------------
var opcionColumns = {
    columns: [
        {
            data: null,
            orderable: false,
            searchable: false,
            className: 'text-center',
            // createdCell (y no className) para que el celeste no se aplique al th "Acciones"
            createdCell: function (td, cellData, rowData, row, col) {
                $(td).addClass('text-light-blue');
            },
            render: function (data, type, row) {
                return '<i class="fa fa-search" style="cursor: pointer; margin: 3px;" title="Ver Detalles" onclick="ver(this);"></i>'
                     + '<i class="fa fa-fw fa-pencil" style="cursor: pointer; margin: 3px;" title="Editar" onclick="editar(this)"></i>'
                     + '<i class="fa fa-fw fa-times-circle" style="cursor: pointer; margin: 3px;" title="Eliminar" onclick="eliminar(this)"></i>';
            }
        }
    ]
};

// ---------------------------------------------------------------------------
// Opcion C: handlers delegados (sin onclick en el markup)
// ---------------------------------------------------------------------------
// Render:
//   '<i class="fa fa-search btnVer" style="cursor: pointer; margin: 3px;" title="Ver Detalles"></i>'
//   '<i class="fa fa-fw fa-pencil btnEditar" style="cursor: pointer; margin: 3px;" title="Editar"></i>'
//   '<i class="fa fa-fw fa-times-circle btnEliminar" style="cursor: pointer; margin: 3px;" title="Eliminar"></i>'
//
// Handlers:
// $(document).off('click', '.btnVer').on('click', '.btnVer', function () {
//     var tr = $(this).closest('tr');
//     var data = tr.attr('data-json');
//     var rowData = data ? JSON.parse(data) : $('#tabla_x').DataTable().row(tr).data();
//     ver(rowData);
// });
