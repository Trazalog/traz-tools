<!-- ______ TABLA PRINCIPAL DE PANTALLA ______ -->
<div class="form-group">
    <label><input type="radio" name="tipoFiltro" id="filtroVenta" value="Venta"> Venta</label>
    <label><input type="radio" name="tipoFiltro" id="filtroCompra" value="Compra"> Compra</label>
</div>
<table id="tabla_precios" class="table table-bordered table-striped">
    <thead class="thead-dark" bgcolor="#eeeeee">
      <th>Acciones</th>
      <th>Nombre</th>
      <th>Versión</th>
      <th>Detalle versión</th>
      <th>Tipo</th>
      <th>Fecha vigencia desde</th>
    </thead>
    <tbody>
      <?php
        if($listas_precios) {
          foreach($listas_precios as $precio) {
            $fechaOriginal = new DateTime($precio->fec_alta);
            $fechaOriginal->modify('+3 hours');
            $fechaFormateada = $fechaOriginal->format('d-m-Y H:i:s');
            echo "<tr data-tipo='".$precio->tipo."' data-json='".json_encode($precio)."'>";
              echo '<td>';
              echo '<button type="button" title="Ver" class="btn btn-primary btn-circle btnVer" data-toggle="modal" data-target="#modalVerListaPrecio" ><span class="glyphicon glyphicon-search" aria-hidden="true" ></span></button>&nbsp';
              if ($precio->nro_version > 1) {
                //   echo '<button type="button" title="Versiones" class="btn btn-primary btn-circle btnVersiones" data-toggle="modal" data-target="#modalVersiones"><span class="glyphicon glyphicon-align-justify" aria-hidden="true"></span></button>&nbsp';
              }
              echo '<button type="button" title="Crear Versión" class="btn btn-primary btn-circle btnCrearVersion" data-toggle="modal" data-target="#modalCrearVersion"><span class="glyphicon glyphicon-dashboard" aria-hidden="true"></span></button>&nbsp';
              echo '</td>';
              echo '<td>'.$precio->nombre.'</td>';
              echo '<td>'.$precio->nro_version.'</td>';
              echo '<td>'.$precio->descripcion.'</td>';
              echo '<td>'.$precio->tipo.'</td>';
              echo '<td>'.$fechaFormateada.'</td>';
            echo '</tr>';
          }
        }
      ?>
    </tbody>
</table>
<!--_______ FIN TABLA PRINCIPAL DE PANTALLA ______-->

<script>
    // DataTable($('#tabla_precios'));

    $(document).ready(function() {
        $('#tabla_precios').DataTable({
            responsive: true,
            language: {
                url: '<?php base_url() ?>lib/bower_components/datatables.net/js/es-ar.json' //Ubicacion del archivo con el json del idioma.
            },
            dom: 'lBfrtip',
            buttons: [{
                    //Botón para Excel
                    extend: 'excel',
                    exportOptions: {
                        columns: [1, 2, 3, 4, 5]
                    },
                    footer: true,
                    title: 'Lista de Precios',
                    filename: 'Lista de Precios',

                    //Aquí es donde generas el botón personalizado
                    text: '<button class="btn btn-success ml-2 mb-2 mb-2 mt-3">Exportar a Excel <i class="fa fa-file-excel-o"></i></button>'
                },
                //Botón para PDF
                {
                    extend: 'pdf',
                    exportOptions: {
                        columns: [1, 2, 3, 4, 5]
                    },
                    footer: true,
                    title: 'Lista de Precios',
                    filename: 'Lista de Precios',
                    text: '<button class="btn btn-danger ml-2 mb-2 mb-2 mt-3">Exportar a PDF <i class="fa fa-file-pdf-o mr-1"></i></button>'
                },
                {
                    extend: 'copy',
                    exportOptions: {
                        columns: [1, 2, 3, 4, 5]
                    },
                    footer: true,
                    title: 'Lista de Precios',
                    filename: 'Lista de Precios',
                    text: '<button class="btn btn-primary ml-2 mb-2 mb-2 mt-3">Copiar <i class="fa fa-file-text-o mr-1"></i></button>'
                },
                {
                    extend: 'print',
                    exportOptions: {
                        columns: [1, 2, 3, 4, 5]
                    },
                    footer: true,
                    title: 'Lista de Precios',
                    filename: 'Lista de Precios',
                    text: '<button class="btn btn-default ml-2 mb-2 mb-2 mt-3">Imprimir <i class="fa fa-print mr-1"></i></button>'
                }
            ]
        });
    });
    

    $(document).ready(function(){
        $('input[name="tipoFiltro"]').on('change', function() {
            var tipoSeleccionado = $(this).val();
            $('#tabla_precios tbody tr').show();
            $('#tabla_precios tbody tr').each(function(){
                var tipo = $(this).data('tipo');
                if(tipo !== tipoSeleccionado) {
                    $(this).hide();
                }
            });
        });
        
        var tablaDetalleVer; // Declarar la variable fuera para que pueda ser accedida globalmente.

        // Código para rellenar el modal
        $(document).on("click", ".btnVer", function() {

            // Destruir DataTable si ya está inicializado
            if ($.fn.DataTable.isDataTable('#tablaDetalleVer')) {
                $('#tablaDetalleVer').DataTable().clear().destroy();
            }

            $("#tablaDetalleVer tbody").empty();
            data = $(this).parents("tr").attr("data-json");
            datajson = JSON.parse(data);
            detalle_lista = datajson.detalles_lista_precio.detalle_lista_precio;
            $("#nombreVer").val(datajson.nombre);
            $("#tipoVer").val(datajson.tipo);
            $("#versionVer").val(detalle_lista != null ? "v"+detalle_lista[0].nro_version : 1);
            $("#detalleVer").val(detalle_lista != null ? detalle_lista[0].descripcion : "Versión original");
            var fecFormateada = datajson.fec_alta.split(" ");
            $("#vigenteDesdeVer").val(fecFormateada[0]);
            
            if (detalle_lista != null) {
                detalle_lista.forEach(function(item, index){
                    $("#tablaDetalleVer tbody").append("<tr><td>"+item.barcode+"</td><td>"+item.producto+"</td><td>"+item.precio+"</td></tr>");
                });
            }

            // Inicializar DataTable nuevamente
            tablaDetalleVer = $('#tablaDetalleVer').DataTable({
                responsive: true,
                language: {
                    url: '<?php echo base_url(); ?>lib/bower_components/datatables.net/js/es-ar.json'
                },
                dom: 'lBfrtip',
                buttons: [
                    {
                        extend: 'excel',
                        exportOptions: {
                            columns: [0, 1, 2] // Índices de las columnas que quieres exportar.
                        },
                        footer: true,
                        title: 'Detalle de la Lista de Precios',
                        filename: 'Detalle_Lista_Precios',
                        text: '<button class="btn btn-success ml-2 mb-2 mt-3">Exportar a Excel <i class="fa fa-file-excel-o"></i></button>'
                    },
                    {
                        extend: 'pdf',
                        exportOptions: {
                            columns: [0, 1, 2]
                        },
                        footer: true,
                        title: 'Detalle de la Lista de Precios',
                        filename: 'Detalle_Lista_Precios',
                        text: '<button class="btn btn-danger ml-2 mb-2 mt-3">Exportar a PDF <i class="fa fa-file-pdf-o"></i></button>'
                    },
                    {
                        extend: 'copy',
                        exportOptions: {
                            columns: [0, 1, 2]
                        },
                        footer: true,
                        title: 'Detalle de la Lista de Precios',
                        filename: 'Detalle_Lista_Precios',
                        text: '<button class="btn btn-primary ml-2 mb-2 mt-3">Copiar <i class="fa fa-copy"></i></button>'
                    },
                    {
                        extend: 'print',
                        exportOptions: {
                            columns: [0, 1, 2]
                        },
                        footer: true,
                        title: 'Detalle de la Lista de Precios',
                        filename: 'Detalle_Lista_Precios',
                        text: '<button class="btn btn-default ml-2 mb-2 mt-3">Imprimir <i class="fa fa-print"></i></button>'
                    }
                ]
            });
        });
    });

    $(document).ready(function(){        
        var tablaArticulosCrearVersion; // Declarar la variable fuera para que pueda ser accedida globalmente.

        // Código para rellenar el modal
        $(document).on("click", ".btnCrearVersion", function() {
            $("#tablaArticulosCrearVersion tbody").empty();
            data = $(this).parents("tr").attr("data-json");
            datajson = JSON.parse(data);
            // console.log(datajson);
            detalle_lista = datajson.detalles_lista_precio.detalle_lista_precio;

            $("#nombreCrearVersion").val(datajson.nombre);
            $("#tipoCrearVersion").val(datajson.tipo);

            // let nuevaVersion = detalle_lista != null ? detalle_lista[0].nro_version + 1 : 1;
            let nuevaVersion = parseInt(datajson.nro_version) + 1;
            $("#versionCrearVersion").val("v" + nuevaVersion);

            // $("#versionCrearVersion").val(detalle_lista != null ? "v"+detalle_lista[0].nro_version + 1 : 1);
            var fecFormateada = datajson.fec_alta.split(" ");
            $("#vigenteDesdeCrearVersion").val(fecFormateada[0]);

            let descripcionVersion = `Versión v${nuevaVersion} vigente desde ${fecFormateada[0]}`;
            $("#detalleCrearVersion").val(descripcionVersion);

            if (detalle_lista != null) {
                detalle_lista.forEach(function(item, index){
                    $("#tablaArticulosCrearVersion tbody").append(`
                        <tr>
                            <td>
                                <button class="btn btn-danger btn-sm eliminarArticulo">
                                    <i class="fa fa-trash"></i>
                                </button>
                            </td>
                            <td>${item.barcode}</td>
                            <td>${item.producto}</td>
                            <td>${item.precio}</td>
                        </tr>
                    `);
                });
            }

            // Destruir DataTable si ya está inicializado
            if ( $.fn.DataTable.isDataTable('#tablaArticulosCrearVersion') && tablaArticulosCrearVersion ) {
                tablaArticulosCrearVersion.destroy();
            }

            // Inicializar DataTable nuevamente
            tablaArticulosCrearVersion = $('#tablaArticulosCrearVersion').DataTable();

            // Asignar eventos a los botones de eliminar después de generar las filas
            actualizarBotonesEliminarCrearVersion();
        });
    });

    // Función para asignar el evento al botón de eliminar
    function actualizarBotonesEliminarCrearVersion() {
        $('.eliminarArticulo').on('click', function() {
            const row = $(this).closest('tr');
            $('#tablaArticulosCrearVersion').DataTable().row(row).remove().draw(false);
        });
    }

</script>
