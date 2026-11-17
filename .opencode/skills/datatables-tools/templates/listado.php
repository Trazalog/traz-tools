<?php
/**
 * Plantilla de listado con DataTable server-side para traz-tools.
 * Copiar en la vista correspondiente y reemplazar los placeholders.
 * Patrón de referencia: traz-comp-pan/views/herramienta/list.php
 * Ver .opencode/skills/datatables-tools/SKILL.md
 */
?>
<!-- ______ TABLA PRINCIPAL DE PANTALLA ______ -->
<table id="tabla___nombre__" class="table table-bordered table-striped">
    <thead>
        <tr>
            <th>Acciones</th>
            <th>__COLUMNA_1__</th>
            <th>__COLUMNA_2__</th>
            <th>Estado</th>
        </tr>
    </thead>
    <tbody>
    </tbody>
</table>
<!--_______ FIN TABLA PRINCIPAL DE PANTALLA ______-->

<script>
  // -------------------------------------------------------
  // Encabezado de los reportes: fecha + filtros aplicados
  // -------------------------------------------------------
  function obtenerInfoReporte() {
      var f = new Date();
      var fecha = (f.getDate() < 10 ? '0' : '') + f.getDate() + "/" +
                  ((f.getMonth() + 1) < 10 ? '0' : '') + (f.getMonth() + 1) + "/" +
                  f.getFullYear();

      var partes = [];

      var filtro = $('#filtro___nombre__').val();
      if (filtro) {
          var filtro_txt = $('#filtro___nombre__ option:selected').text();
          if (filtro_txt) partes.push('__Filtro__: ' + filtro_txt);
      }

      return "Fecha de reporte: " + fecha + "\n" +
             (partes.length ? "Filtros: " + partes.join(' | ') : "Filtros: Sin filtros aplicados");
  }

  // Config Tabla
  $('#tabla___nombre__').DataTable({
      "processing": true,
      "serverSide": true,
      "ajax": {
          "url": "<?php echo base_url(__MOD__) ?>__Controlador__/__listarPaginado__",
          "type": "POST",
          "data": function (d) {
              var filtro = $('#filtro___nombre__').val();
              if (filtro) d.__filtro__ = filtro;
          }
      },
      "columns": [
          {
              "data": null,
              "orderable": false,
              "searchable": false,
              "render": function (data, type, row) {
                  return '<i class="fa fa-fw fa-search text-light-blue btnInfo" style="cursor: pointer;margin: 3px;" title="Info"></i>'
                       + '<i class="fa fa-fw fa-pencil text-light-blue btnEditar" style="cursor: pointer;margin: 3px;" title="Editar"></i>'
                       + '<i class="fa fa-fw fa-trash text-light-blue btnEliminar" style="cursor: pointer;margin: 3px;" title="Eliminar"></i>';
              }
          },
          { "data": "__campo1__" },
          { "data": "__campo2__" },
          {
              "data": "__campo_estado__",
              "render": function (data, type, row) {
                  if (data === '__ACTIVO__') {
                      return '<small class="label pull-left bg-green">Activa</small>';
                  } else if (data === '__INHABILITADO__') {
                      return '<small class="label pull-left bg-red">Inhabilitada</small>';
                  }
                  return '<small class="label pull-left bg-gray">' + (data || '-') + '</small>';
              }
          }
      ],
      dom: 'lBfrtip',
      buttons: [
          {
              // Botón para Excel
              extend: 'excel',
              exportOptions: { columns: [1, 2, 3] },
              footer: true,
              title: '__Reporte__',
              filename: '__Reporte__',
              className: 'btn btn-success btn-flat ml-1',
              text: 'Exportar a Excel <i class="fa fa-file-excel-o"></i>',
              action: function (e, dt, button, config) {
                  var self = this;
                  var oldLength = dt.page.len();
                  dt.page.len(1000000);
                  dt.one('draw', function () {
                      $.fn.dataTable.ext.buttons.excelHtml5.action.call(self, e, dt, button, config);
                      setTimeout(function () { dt.page.len(oldLength).draw(); }, 100);
                  });
                  dt.draw();
              },
              messageTop: function () { return obtenerInfoReporte(); }
          },
          {
              // Botón para PDF
              extend: 'pdf',
              orientation: 'landscape',
              pageSize: 'A4',
              exportOptions: { columns: [1, 2, 3] },
              footer: true,
              title: '__Reporte__',
              filename: '__Reporte__',
              className: 'btn btn-danger btn-flat ml-1',
              text: 'Exportar a PDF <i class="fa fa-file-pdf-o"></i>',
              action: function (e, dt, button, config) {
                  var self = this;
                  var oldLength = dt.page.len();
                  dt.page.len(1000000);
                  dt.one('draw', function () {
                      $.fn.dataTable.ext.buttons.pdfHtml5.action.call(self, e, dt, button, config);
                      setTimeout(function () { dt.page.len(oldLength).draw(); }, 100);
                  });
                  dt.draw();
              },
              messageTop: function () { return obtenerInfoReporte(); },
              customize: function (doc) {
                  var title = doc.content[0].text;
                  doc.content.splice(0, 1);

                  var headerColumns = [{
                      text: title,
                      fontSize: 22,
                      bold: true,
                      alignment: 'left',
                      margin: [0, 10, 0, 0]
                  }];

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

                  if (doc.content[1] && doc.content[1].alignment !== undefined) {
                      doc.content[1].alignment = 'left';
                      doc.content[1].margin = [0, 0, 0, 10];
                      doc.content[1].fontSize = 9;
                  }

                  doc.defaultStyle.fontSize = 9;
                  doc.styles.tableHeader.fillColor = '#dd4b39';
                  doc.styles.tableHeader.color = 'white';
                  doc.styles.tableHeader.alignment = 'center';
                  doc.styles.tableHeader.fontSize = 10;
              }
          },
          {
              // Botón Copiar
              extend: 'copy',
              exportOptions: { columns: [1, 2, 3] },
              footer: true,
              title: '__Reporte__',
              filename: '__Reporte__',
              className: 'btn btn-primary btn-flat ml-1',
              text: 'Copiar <i class="fa fa-file-text-o"></i>',
              action: function (e, dt, button, config) {
                  var self = this;
                  var oldLength = dt.page.len();
                  dt.page.len(1000000);
                  dt.one('draw', function () {
                      $.fn.dataTable.ext.buttons.copyHtml5.action.call(self, e, dt, button, config);
                      setTimeout(function () { dt.page.len(oldLength).draw(); }, 100);
                  });
                  dt.draw();
              },
              messageTop: function () { return obtenerInfoReporte(); }
          },
          {
              // Botón Imprimir
              extend: 'print',
              exportOptions: { columns: [1, 2, 3] },
              footer: true,
              title: '__Reporte__',
              filename: '__Reporte__',
              className: 'btn btn-default btn-flat ml-1',
              text: 'Imprimir <i class="fa fa-print"></i>',
              action: function (e, dt, button, config) {
                  var self = this;
                  var oldLength = dt.page.len();
                  dt.page.len(1000000);
                  dt.one('draw', function () {
                      $.fn.dataTable.ext.buttons.print.action.call(self, e, dt, button, config);
                      setTimeout(function () { dt.page.len(oldLength).draw(); }, 100);
                  });
                  dt.draw();
              },
              messageTop: function () { return obtenerInfoReporte(); },
              customize: function (win) {
                  $(win.document.head).find('link[href=""], link[href="#"], link:not([href])').remove();
                  $(win.document.head).find('script[src=""], script[src="#"]').remove();
                  $(win.document.body).find('tr[data-json]').removeAttr('data-json');
                  $(win.document.body).find('h1').remove();

                  var cabecera = '<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; border-bottom: 2px solid #dd4b39; padding-bottom: 10px;">'
                               + '  <h1 style="margin: 0; font-size: 22pt; font-weight: bold; color: #333;">__Reporte__</h1>'
                               + '</div>';
                  $(win.document.body).prepend(cabecera);

                  $(win.document.body).find('div').each(function () {
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
      ],
      "createdRow": function (row, data, dataIndex) {
          $(row).attr('data-json', JSON.stringify(data));
      }
  });

  // Devuelve la fila del data-json (o del DataTable si no esta)
  function obtenerFila(elemento) {
      var tr = $(elemento).closest('tr');
      var data = tr.attr('data-json');
      return data ? JSON.parse(data) : $('#tabla___nombre__').DataTable().row(tr).data();
  }

  // Recarga la tabla manteniendo la pagina actual
  function recargarTabla() {
      if ($.fn.DataTable.isDataTable('#tabla___nombre__')) {
          $('#tabla___nombre__').DataTable().ajax.reload(null, false);
      }
  }

  // Editar
  $(document).off('click', '.btnEditar').on('click', '.btnEditar', function () {
      var rowData = obtenerFila(this);
      if (!rowData) {
          alertify.error('No se pudieron obtener los datos del registro');
          return;
      }
      // abrir el modal y llenar los campos
  });

  // Eliminar
  $(document).off('click', '.btnEliminar').on('click', '.btnEliminar', function () {
      var rowData = obtenerFila(this);
      if (!rowData) {
          alertify.error('No se pudieron obtener los datos del registro');
          return;
      }

      var mensaje = '¿Está seguro que desea eliminar el registro?';

      if (typeof Swal !== 'undefined') {
          Swal.fire({
              title: 'Atención',
              text: mensaje,
              type: 'warning',
              showCancelButton: true,
              confirmButtonColor: '#3085d6',
              cancelButtonColor: '#d33',
              confirmButtonText: 'Sí, continuar',
              cancelButtonText: 'Cancelar'
          }).then(function (result) {
              if (result.value) eliminarRegistro(rowData);
          });
      } else if (confirm(mensaje)) {
          eliminarRegistro(rowData);
      }
  });

  function eliminarRegistro(rowData) {
      wo();
      $.ajax({
          type: 'POST',
          url: '<?php echo base_url(__MOD__) ?>__Controlador__/__borrar__',
          data: { id: rowData.__id__ },
          dataType: 'JSON',
          success: function (resp) {
              wc();
              if (resp) {
                  alertify.success('Registro eliminado con éxito');
                  recargarTabla();
              } else {
                  alertify.error('No se pudo eliminar el registro');
              }
          },
          error: function (err) {
              wc();
              console.error(err);
              alertify.error('Error en el servidor al eliminar el registro');
          }
      });
  }
</script>

<?php $this->load->view('__modulo__/modals/__modal_editar__'); ?>
