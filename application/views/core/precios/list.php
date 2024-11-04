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
                echo '<button type="button" title="Versiones" class="btn btn-primary btn-circle btnVersiones" data-toggle="modal" data-target="#modalVersiones"><span class="glyphicon glyphicon-align-justify" aria-hidden="true"></span></button>&nbsp';
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
    var tablaDetalleVer; // Declarar la variable fuera para que pueda ser accedida globalmente.
    // DataTable($('#tabla_precios'));
    $(document).ready(function() {
        tablaArticulosCrearVersion = $('#tablaArticulosCrearVersion').DataTable();
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
        
        // Código para rellenar el modal
        $(document).on("click", ".btnVer", function() {
            //debugger;
            // Destruir DataTable si ya está inicializado
            if ($.fn.DataTable.isDataTable('#tablaDetalleVer') && tablaDetalleVer) {
                tablaDetalleVer.destroy(); // Destruye la instancia existente
            }   

            $("#tablaDetalleVer tbody").empty();
            data = $(this).parents("tr").attr("data-json");
            datajson = JSON.parse(data);

            //selecciono articulos de la version 
            let nroVersionActual = datajson.nro_version;
            let detalle_lista = datajson.detalles_lista_precio.detalle_lista_precio.filter(function(item) {
                return item.nro_version === nroVersionActual;
            });
            //detalle_lista = datajson.detalles_lista_precio.detalle_lista_precio;
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
        
        //---- boton crear Version ----// 
         $(document).on("click", ".btnCrearVersion", function() {

             // Destruir DataTable si ya está inicializado
            if ( $.fn.DataTable.isDataTable('#tablaArticulosCrearVersion') && tablaArticulosCrearVersion ) {
                tablaArticulosCrearVersion.destroy();
            } 

            $("#tablaArticulosCrearVersion tbody").empty();
            data = $(this).parents("tr").attr("data-json");
            datajson = JSON.parse(data);
            //console.log(datajson);
            //detalle_lista = datajson.detalles_lista_precio.detalle_lista_precio;
            
            //selecciono articulos de la version 
            let nroVersionActual = datajson.nro_version;
            let detalle_lista = datajson.detalles_lista_precio.detalle_lista_precio.filter(function(item) {
                return item.nro_version === nroVersionActual;
            });

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

            $("#lipr_id").val(datajson.lipr_id);

            //guardo en data-precio-original el precio original por si aplica coeficiente y despues volver a precio original
            if (detalle_lista != null) {
                detalle_lista.forEach(function(item, index){
                    $("#tablaArticulosCrearVersion tbody").append(`
                        <tr>
                            <td>
                                <button class="btn btn-danger btn-sm eliminarArticulo">
                                    <i class="fa fa-trash"></i>
                                </button>
                            </td>
                            <td><span data-json='{"arti_id":${item.arti_id}}'>${item.barcode}</td>
                            <td>${item.producto}</td>
                            <td>
                                <input type="text" class="form-control precioUnitario" value="${item.precio.replace('.', ',')}"
                                data-precio-original="${item.precio.replace('.', ',')}" placeholder="0,00" oninput="formatearPrecio(this)">
                            </td>
                        </tr>
                    `);
                });
            }

            // Inicializar DataTable nuevamente
            tablaArticulosCrearVersion = $('#tablaArticulosCrearVersion').DataTable();

        });


        //---- boton agregar un nuevo articulo en una version ----// 
        document.getElementById('agregarArticuloCrearVersion').addEventListener('click', function() {
            const inputArticulo = document.getElementById('inputarti');
            //console.log('Valor de inputArticulo:', inputArticulo.value);
            const articuloSeleccionado = document.querySelector(`#articulos option[value="${inputArticulo.value}"]`);
           // console.log('Articulo seleccionado:', articuloSeleccionado);
            if (articuloSeleccionado) {
                const dataJson = JSON.parse(articuloSeleccionado.getAttribute('data-json'));
                const codigoArticulo = dataJson.barcode;
                const descripcionArticulo = dataJson.descripcion;
                const dataCodificada = JSON.stringify({
                    arti_id: dataJson.arti_id
                });

                tablaArticulosCrearVersion.row.add([
                    `<button class="btn btn-danger btn-sm eliminarArticulo">
                        <i class="fa fa-trash"></i>
                    </button>`,
                    `<span data-json='${dataCodificada}'>${codigoArticulo}</span>`,
                    descripcionArticulo,
                    `<input type="text" class="form-control precioUnitario" placeholder="0,00" oninput="formatearPrecio(this)">`
                ]).draw(false);
                inputArticulo.value = '';
            } else {
                error("Error",'Seleccione un artículo válido.');
            }
        }); 

    });


    //---- aplicar coeficiente a articulos ----// 
    document.getElementById('aplicarCoeficiente').addEventListener('click', function() {
        const coeficienteInput = document.getElementById('coeficiente');
        const coeficiente = parseFloat(coeficienteInput.value.replace(',', '.')) / 100;

        if (isNaN(coeficiente)) {
            alert("Ingrese un coeficiente válido.");
            return;
        }

        $('#tablaArticulosCrearVersion tbody tr').each(function() {
            const precioUnitarioInput = $(this).find('.precioUnitario');
            let precioActual = parseFloat(precioUnitarioInput.val().replace(',', '.'));

            if (!isNaN(precioActual)) {
                const nuevoPrecio = precioActual * (1 + coeficiente);
                precioUnitarioInput.val(nuevoPrecio.toFixed(2).replace('.', ','));
            }
        });
    }); 

   //---- volver a version original precio sin coeficiente ----// 
    document.getElementById('valorOriginal').addEventListener('click', function() {
        $('#tablaArticulosCrearVersion tbody tr').each(function() {
            const precioUnitarioInput = $(this).find('.precioUnitario');
            const precioOriginal = precioUnitarioInput.data('precio-original');

            if (precioOriginal !== undefined) {
                precioUnitarioInput.val(precioOriginal);
            }
        });
    });


   //---- Función para asignar el evento al botón de eliminar ----// 
   $('#tablaArticulosCrearVersion tbody').on('click', '.eliminarArticulo', function() {
        const row = $(this).closest('tr');
        tablaArticulosCrearVersion.row(row).remove().draw(false);
    });
    

// guarda una nueva version de la lista de precios 
    function guardarNuevaVersion() {

        var nombre = $('#nombreCrearVersion').val();
        if (!nombre) {
            error('Error','El campo nombre es obligatorio.');
            return;
        }
        var version = $("#versionCrearVersion").val();
        var numeroVersion = version.substring(1);
        var detalle = $('#detalleCrearVersion').val() || 'Versión original';
        var tipo = $('#tipoCrearVersion').val();
        var recurso = 'index.php/core/Precio/agregarListaPrecio';
        var lipr_id = $("#lipr_id").val();
        var articulosTabla = [];
        $('#tablaArticulosCrearVersion').find('tbody tr').each(function() {
          
            var col = $(this).find('td');
            var dataJson = $(this).find('span').attr('data-json');
            var data = {};
            if (dataJson) {
                var parsedData = JSON.parse(dataJson);
                data.arti_id = parsedData.arti_id;
            } else {
                console.error("data-json is undefined or invalid.");
                return;
            }

            data.precio = col.last().find('input').val().replace(',', '.');
           // console.log(data.precio);
            articulosTabla.push(data);
        });

        if (articulosTabla.length === 0) {
            error('Error', 'Debe agregar al menos un artículo antes de guardar la lista de precios.');
            return;
        }
        wo();
       $.ajax({
            url: recurso,
            method: 'POST',
            dataType: "json",
            data: {
                nombre: nombre,
                version: numeroVersion,
                detalle: detalle,
                tipo: tipo,
                articulos: articulosTabla,
                lipr_id: lipr_id  //id de lista de precio
            },
            success: function(response) {
                if (response.status) {
                    
                    wc();
                    hecho("Hecho",'Lista de precios guardada correctamente.');
                    // resetFormAndSelect2();
                    $('#modalCrearVersion').modal('hide');
                    cargarTablaPrecios();
                } else {
                    wc();
                    error('Error','Error en el procedimiento de guardado: ' + response.message);
                }
            },
            error: function() {
                wc();
                error('Error','Error al realizar la solicitud.');
            }
        });
    }

    $(document).ready(function() {
        $(document).off("click", ".btnVersiones").on("click", ".btnVersiones", function() {
            $("#tablaDetalleVersiones tbody").empty();
            let data = $(this).parents("tr").attr("data-json");
            let datajson = JSON.parse(data);

            $("#nombreVersiones").val(datajson.nombre);
            $("#tipoVersiones").val(datajson.tipo);
            var recurso = 'index.php/core/Precio/obtenerVersiones';
            var lipr_id = datajson.lipr_id;
            // console.log(lipr_id);
            
            $.ajax({
                url: recurso,
                type: "POST",
                data: { lipr_id: lipr_id },
                dataType: "json",
                success: function(response) {
                    // Recorrer el array de versiones y agregarlas al tbody
                    response.forEach(function(version) {
                        let fec_alta = new Date(version.fec_alta).toLocaleDateString("es-AR");
                        let fec_hasta = version.fec_hasta ? new Date(version.fec_hasta).toLocaleDateString("es-AR") : "-";
                        $("#tablaDetalleVersiones tbody").append(
                            `<tr data-json='${JSON.stringify(version)}'>
                                <td>
                                    <button class="btn btn-danger btn-sm VER">
                                        <i class="glyphicon glyphicon-search"></i>
                                    </button>
                                </td>
                                <td>${version.nro_version}</td>
                                <td>${version.descripcion}</td>
                                <td>${fec_alta}</td>
                                <td>${fec_hasta}</td>
                            </tr>`
                        );
                    });
                },
                error: function() {
                    alert("Error al obtener las versiones de la lista de precios.");
                }
            });
        });

        // Evento para abrir el modal y cargar la información de la versión
        $(document).on("click", ".btn-danger.btn-sm.VER", function() {
            event.preventDefault();
            // Lógica para abrir el modal y cargar la información
            const versionData = $(this).closest('tr').attr("data-json");
            const version = JSON.parse(versionData);
            
            // Aquí llama a la función que ya tienes para cargar el modal
            cargarDatosModal(version);
        });
    });

    // Función para cargar los datos en el modal
    function cargarDatosModal(datajson) {
        // Destruir DataTable si ya está inicializado
        if ($.fn.DataTable.isDataTable('#tablaDetalleVer')) {
            $('#tablaDetalleVer').DataTable().destroy(); // Destruye la instancia existente
        }

        $("#tablaDetalleVer tbody").empty(); // Limpiar la tabla

        // Cargar datos en el modal
        $("#nombreVer").val(datajson.descripcion);
        // $("#tipoVer").val(datajson.tipo);
        $("#versionVer").val("v"+datajson.nro_version);
        $("#detalleVer").val(datajson.descripcion);

        let fec_alta = new Date(datajson.fec_alta).toLocaleDateString("es-AR");
        let fec_hasta = datajson.fec_hasta ? new Date(datajson.fec_hasta).toLocaleDateString("es-AR") : "-";

        $("#vigenteDesdeVer").val(fec_alta); // Formato de fecha (ej. dd/mm/aaaa)
        $("#vigenteHastaVer").val(fec_hasta); // Mostrar "-" si es null

        // Verificar si hay detalles de artículos
        if (datajson.detalles_articulos_version && datajson.detalles_articulos_version.detalle_articulos_version) {
            const detalle_articulos = datajson.detalles_articulos_version.detalle_articulos_version;

            // Cargar los detalles en la tabla
            detalle_articulos.forEach(function(item) {
                $("#tablaDetalleVer tbody").append(
                    `<tr>
                        <td>${item.barcode}</td>
                        <td>${item.producto}</td>
                        <td>${item.precio}</td>
                    </tr>`
                );
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

         // Ocultar el modal de versiones si está abierto
        $("#modalVersiones").modal('hide');
        
        // Mostrar el modal de lista de precios
        $("#modalVerListaPrecio").modal('show');
    }

</script>
