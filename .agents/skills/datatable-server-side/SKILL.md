---
name: datatable-server-side
description: "Plantilla y estandar para generar DataTables paginados server-side en el sistema Trazalog / CodeIgniter con botones de exportacion completos (Excel, PDF con cabecera y logo, Copiar, Imprimir) con truco de paginacion para exportar todos los registros."
---

# DataTable Paginado Server-Side con Botones de Exportación

Usa esta guía y estructura estándar cada vez que el usuario solicite implementar un DataTable con procesamiento server-side en el sistema (CodeIgniter + AdminLTE / Bootstrap 3).

---

## 1. Patrón de Exportación Total en Server-Side (Truco dt.page.len)

En DataTables server-side, por defecto los botones de exportación solo exportan la página actual (ej. 10 o 25 filas).
Para que exporte **todos los registros del servidor**, se implementa el callback `action`:
1. Guarda la longitud actual de página (`oldLength`).
2. Fija `dt.page.len(1000000)` para pedir todos los registros.
3. Espera el evento `dt.one('draw', ...)` donde invoca el exportador nativo de DataTables.
4. Restaura la longitud original con `dt.page.len(oldLength).draw()`.

---

## 2. Estructura Estándar del DataTable

```javascript
$('#ID_TABLA').DataTable({
    "processing": true,
    "serverSide": true,
    "ajax": {
        "url": "<?php echo base_url(PAN) ?>Controlador/metodoPaginado", // Ajustar módulo y controlador
        "type": "POST",
        "data": function (d) {
            // Parámetros de filtros adicionales si existen
            var filtro = $('#filtro_id').val();
            if (filtro) d.filtro = filtro;
        }
    },
    "columns": [
        {
            "data": "id",
            "render": function (data, type, row) {
                return '<i class="fa fa-search text-light-blue" style="cursor: pointer; margin: 3px;" title="Ver"></i>';
            },
            "orderable": false
        },
        { "data": "codigo" },
        { "data": "descripcion" },
        { "data": "fec_alta" }
    ],
    "order": [[3, "desc"]],
    dom: 'lBfrtip',
    buttons: [
        // --- BOTÓN EXCEL ---
        {
            extend: 'excel',
            exportOptions: {
                columns: [1, 2, 3] // Índices de columnas sin incluir las acciones
            },
            footer: true,
            title: 'TITULO_REPORTE',
            filename: 'NOMBRE_ARCHIVO',
            className: 'btn btn-success btn-flat ml-1',
            text: 'Exportar a Excel <i class="fa fa-file-excel-o"></i>',
            action: function (e, dt, button, config) {
                var self = this;
                var oldLength = dt.page.len();
                dt.page.len(1000000);
                dt.one('draw', function () {
                    $.fn.dataTable.ext.buttons.excelHtml5.action.call(self, e, dt, button, config);
                    setTimeout(function() {
                        dt.page.len(oldLength).draw();
                    }, 100);
                });
                dt.draw();
            },
            messageTop: function () {
                var f = new Date();
                var fecha = (f.getDate() < 10 ? '0' : '') + f.getDate() + "/" + ((f.getMonth() + 1) < 10 ? '0' : '') + (f.getMonth() + 1) + "/" + f.getFullYear();
                return "Fecha de reporte: " + fecha;
            }
        },

        // --- BOTÓN PDF ---
        {
            extend: 'pdf',
            orientation: 'landscape',
            pageSize: 'A4',
            exportOptions: {
                columns: [1, 2, 3]
            },
            footer: true,
            title: 'TITULO_REPORTE',
            filename: 'NOMBRE_ARCHIVO',
            className: 'btn btn-danger btn-flat ml-1',
            text: 'Exportar a PDF <i class="fa fa-file-pdf-o"></i>',
            action: function (e, dt, button, config) {
                var self = this;
                var oldLength = dt.page.len();
                dt.page.len(1000000);
                dt.one('draw', function () {
                    $.fn.dataTable.ext.buttons.pdfHtml5.action.call(self, e, dt, button, config);
                    setTimeout(function() {
                        dt.page.len(oldLength).draw();
                    }, 100);
                });
                dt.draw();
            },
            messageTop: function () {
                var f = new Date();
                var fecha = (f.getDate() < 10 ? '0' : '') + f.getDate() + "/" + ((f.getMonth() + 1) < 10 ? '0' : '') + (f.getMonth() + 1) + "/" + f.getFullYear();
                return "Fecha de reporte: " + fecha;
            },
            customize: function (doc) {
                // Remover título original de DataTables
                var title = doc.content[0].text;
                doc.content.splice(0, 1);

                // Cabecera: Título Izquierda, Logo Derecha si existe
                var headerColumns = [
                    {
                        text: title,
                        fontSize: 22,
                        bold: true,
                        alignment: 'left',
                        margin: [0, 10, 0, 0]
                    }
                ];

                <?php if (!empty($logo)) { ?>
                headerColumns.push({
                    image: '<?php echo $logo; ?>',
                    width: 100,
                    alignment: 'right',
                    margin: [0, 0, 0, 0]
                });
                <?php } ?>

                doc.content.splice(0, 0, {
                    columns: headerColumns,
                    margin: [0, 0, 0, 20]
                });

                // MessageTop (Fecha)
                doc.content[1].alignment = 'left';
                doc.content[1].margin = [0, 0, 0, 10];

                // Estilo general y encabezado
                doc.defaultStyle.fontSize = 9;
                doc.styles.tableHeader.fillColor = '#dd4b39';
                doc.styles.tableHeader.color = 'white';
                doc.styles.tableHeader.alignment = 'center';
                doc.styles.tableHeader.fontSize = 10;

                // Anchos proporcionales según número de columnas exportadas
                var tableIndex = doc.content.length - 1;
                // Ajustar porcentaje por cada columna: doc.content[tableIndex].table.widths = ['25%', '50%', '25%'];
            }
        },

        // --- BOTÓN COPIAR ---
        {
            extend: 'copy',
            exportOptions: {
                columns: [1, 2, 3]
            },
            footer: true,
            title: 'TITULO_REPORTE',
            filename: 'NOMBRE_ARCHIVO',
            className: 'btn btn-primary btn-flat ml-1',
            text: 'Copiar <i class="fa fa-file-text-o"></i>',
            action: function (e, dt, button, config) {
                var self = this;
                var oldLength = dt.page.len();
                dt.page.len(1000000);
                dt.one('draw', function () {
                    $.fn.dataTable.ext.buttons.copyHtml5.action.call(self, e, dt, button, config);
                    setTimeout(function() {
                        dt.page.len(oldLength).draw();
                    }, 100);
                });
                dt.draw();
            }
        },

        // --- BOTÓN IMPRIMIR ---
        {
            extend: 'print',
            exportOptions: {
                columns: [1, 2, 3]
            },
            footer: true,
            title: 'TITULO_REPORTE',
            filename: 'NOMBRE_ARCHIVO',
            className: 'btn btn-default btn-flat ml-1',
            text: 'Imprimir <i class="fa fa-print"></i>',
            action: function (e, dt, button, config) {
                var self = this;
                var oldLength = dt.page.len();
                dt.page.len(1000000);
                dt.one('draw', function () {
                    $.fn.dataTable.ext.buttons.print.action.call(self, e, dt, button, config);
                    setTimeout(function() {
                        dt.page.len(oldLength).draw();
                    }, 100);
                });
                dt.draw();
            },
            messageTop: function () {
                var f = new Date();
                var fecha = (f.getDate() < 10 ? '0' : '') + f.getDate() + "/" + ((f.getMonth() + 1) < 10 ? '0' : '') + (f.getMonth() + 1) + "/" + f.getFullYear();
                return "Fecha de reporte: " + fecha;
            },
            customize: function (win) {
                // Remover links o scripts rotos que causan 404 /index en CodeIgniter
                $(win.document.head).find('link[href=""], link[href="#"], link:not([href])').remove();
                $(win.document.head).find('script[src=""], script[src="#"]').remove();
                $(win.document.body).find('tr[data-json]').removeAttr('data-json');

                $(win.document.body).find('h1').remove();

                var cabecera = '<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; border-bottom: 2px solid #dd4b39; padding-bottom: 10px;">' +
                               '  <h1 style="margin: 0; font-size: 22pt; font-weight: bold; color: #333;">TITULO_REPORTE</h1>' +
                               '</div>';
                $(win.document.body).prepend(cabecera);

                $(win.document.body).find('div').each(function() {
                    if ($(this).text().indexOf('Fecha de reporte:') !== -1) {
                        $(this).css({
                            'white-space': 'pre-line',
                            'font-size': '10pt',
                            'margin-bottom': '15px',
                            'line-height': '1.5',
                            'background-color': '#f9f9f9',
                            'padding': '10px',
                            'border': '1px solid #ddd',
                            'border-radius': '4px'
                        });
                    }
                });

                $(win.document.body).css('font-size', '9pt');
                $(win.document.body).find('table')
                    .addClass('compact')
                    .css('font-size', '9pt')
                    .css('width', '100%');

                $(win.document.body).find('th').css({
                    'background-color': '#dd4b39',
                    'color': 'white',
                    'text-align': 'center',
                    'font-size': '10pt',
                    'padding': '8px'
                });
            }
        }
    ]
});
```

---

## 3. Checklist al Generar un Nuevo DataTable
1. Verificar los índices en `exportOptions.columns` para no incluir columnas de botones o acciones.
2. Definir correctamente los anchos proporcionales en `customize` del PDF (`doc.content[tableIndex].table.widths`).
3. Reemplazar `TITULO_REPORTE` y `NOMBRE_ARCHIVO` según la entidad.
4. Mantener los estilos corporativos (`#dd4b39` en cabeceras de tabla, botones planos de AdminLTE `btn-flat`, limpieza de scripts y enlaces rotos en la impresión).
