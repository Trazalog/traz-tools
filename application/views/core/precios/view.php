<style>
    th {
        white-space: nowrap;
    }
    table {
        table-layout: auto;
    }
</style>
<!-- /// ---- HEADER ----- /// -->
<div class="box box-primary animated fadeInLeft">
    <div class="box-header with-border">
        <h4>Lista de Precios</h4>
    </div>
    <div class="box-body">
        <div class="row">
            <div class="col-md-2 col-lg-1 col-xs-12">
                <button type="button" id="botonListaPrecios" class="btn btn-primary" data-toggle="modal" data-target="#modalListaPrecio" aria-label="Left Align">
                Agregar
                </button><br>
            </div>
            <div class="col-md-10 col-lg-11 col-xs-12"></div>
        </div>
    </div>
</div>
<!-- /// ----- HEADER -----/// -->

<!---/////---BOX 2 DATATBLE ---/////----->
<div class="box box-primary">
    <div class="box-body">
        <div id="example2_wrapper" class="dataTables_wrapper form-inline dt-bootstrap">                
            <div class="row">
                <div class="col-sm-6"></div>
                <div class="col-sm-6"></div>
            </div>
            <div class="row">
                <div class="col-sm-12 table-scroll" id="cargar_tabla">
                </div>
            </div>                
        </div>
    </div>
</div>
<!---/////--- FIN BOX 2 DATATABLE---//////----->

<!---/////---MODAL NUEVA LISTA DE PRECIO ---/////----->
<div class="modal fade bs-example-modal-lg" id="modalListaPrecio" tabindex="-1" role="dialog" aria-labelledby="myLargeModalLabel">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header bg-blue">
                <h4 class="modal-title" id="myLargeModalLabel">Nueva Lista de Precios</h4>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true" style="color:white;">&times;</span>
                </button>
            </div>
            <div class="modal-body">
                <form class="formLista" id="formLista">
                    <div class="row">
                        <!-- Nombre -->
                        <div class="col-md-4 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="nombre">Nombre(<strong style="color: #dd4b39">*</strong>):</label>
                                <input type="text" class="form-control requerido" name="nombre" id="nombre" placeholder="Ingrese nombre de la lista" onkeyup="verificarNombre()">
                                <small id="mensajeError" style="color: red; display: none;">El nombre ya existe en la base de datos.</small>
                            </div>
                        </div>
                        <!-- Tipo -->
                        <div class="col-md-2 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="Tipo">Tipo(<strong style="color: #dd4b39">*</strong>):</label>
                                <select class="form-control requerido" name="tipo" id="tipo">
                                    <option value="Venta">Venta</option>
                                    <option value="Compra">Compra</option>
                                </select>
                            </div>
                        </div>
                        <!-- Version -->
                        <div class="col-md-1 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="Version">Versión:</label>
                                <input type="text" class="form-control" name="version" id="version" value="1" readonly>
                            </div>
                        </div>
                        <!-- Detalle -->
                        <div class="col-md-5 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="Detalle">Descripción versión:</label>
                                <input type="text" class="form-control" name="detalle" id="detalle" placeholder="Ingrese la descripción para la nueva versión">
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <!-- Vigente Desde -->
                        <div class="col-md-2 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="vigenteDesde">Vigente Desde:</label>
                                <input type="date" class="form-control requerido" name="vigenteDesde" id="vigenteDesde" value="<?= date('Y-m-d') ?>" readonly>
                            </div>
                        </div>
                        <!-- Vigente Hasta -->
                        <div class="col-md-2 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="vigenteHasta">Vigente Hasta:</label>
                                <input type="date" class="form-control requerido" name="vigenteHasta" id="vigenteHasta" readonly>
                            </div>
                        </div>
                        <!-- Agregar Artículo -->
                        <div class="col-md-6 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="lote">Seleccionar Artículo <strong style="color: #dd4b39">*</strong>:</label>
                                <?php $this->load->view(ALM.'articulo/componente'); ?>
                            </div>
                        </div>
                        <div class="col-md-2 col-sm-6 col-xs-12">
                            <div style="padding-top: 25px" class="form-group">
                                <button class="btn btn-primary ml-2" type="button" id="agregarArticulo"><i class="fa fa-plus"></i>  Agregar</button>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-md-12 col-sm-12 col-xs-12">
                            <table class="table table-bordered" id="tablaArticulos">
                                <thead>
                                    <tr>
                                        <th>Acciones</th>
                                        <th>Código Artículo</th>
                                        <th>Descripción</th>
                                        <th>Precio Unitario</th>
                                    </tr>
                                </thead>
                                <tbody>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </form>
            </div>
            <div class="modal-footer">
                <div class="form-group text-right">
                    <button type="button" class="btn btn-default cerrarModalEdit" data-dismiss="modal">Cancelar</button>
                    <button type="button" class="btn btn-primary habilitar" data-dismiss="modal" id="btnsave_edit" onclick="guardarListaPrecio()">Guardar</button>
                </div>
            </div>
        </div>
    </div>
</div>
<!---/////--- FIN MODAL NUEVA LISTA DE PRECIO ---/////----->

<!---/////---MODAL VER LISTA DE PRECIO ---/////----->
<div class="modal fade bs-example-modal-lg" id="modalVerListaPrecio" tabindex="-1" role="dialog" aria-labelledby="myLargeModalLabel">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header bg-blue">
                <h4 class="modal-title" id="myLargeModalLabel">Ver Lista de Precios</h4>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true" style="color:white;">&times;</span>
                </button>
            </div>
            <div class="modal-body">
                <form class="formLista" id="formLista">
                    <div class="row">
                        <!-- Nombre -->
                        <div class="col-md-4 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="nombreVer">Nombre(<strong style="color: #dd4b39">*</strong>):</label>
                                <input type="text" class="form-control" name="nombreVer" id="nombreVer" readonly>
                            </div>
                        </div>
                        <!-- Tipo -->
                        <div class="col-md-2 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="tipoVer">Tipo(<strong style="color: #dd4b39">*</strong>):</label>
                                <input type="text" class="form-control" name="tipoVer" id="tipoVer" readonly>
                            </div>
                        </div>
                        <!-- Version -->
                        <div class="col-md-1 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="Version">Versión:</label>
                                <input type="text" class="form-control" name="versionVer" id="versionVer" readonly>
                            </div>
                        </div>
                        <!-- Detalle -->
                        <div class="col-md-5 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="Detalle">Descripción versión:</label>
                                <input type="text" class="form-control" name="detalleVer" id="detalleVer" readonly>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <!-- Vigente Desde -->
                        <div class="col-md-2 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="vigenteDesdeVer">Vigente Desde:</label>
                                <input type="date" class="form-control requerido" name="vigenteDesdeVer" id="vigenteDesdeVer" readonly>
                            </div>
                        </div>
                        <!-- Vigente Hasta -->
                        <div class="col-md-2 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="vigenteHastaVer">Vigente Hasta:</label>
                                <input type="date" class="form-control requerido" name="vigenteHastaVer" id="vigenteHastaVer" readonly>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-md-12 col-sm-12 col-xs-12">
                            <table class="table table-bordered" id="tablaDetalleVer">
                                <thead>
                                    <tr>
                                        <th>Código Artículo</th>
                                        <th>Descripción</th>
                                        <th>Precio Unitario</th>
                                    </tr>
                                </thead>
                                <tbody>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </form>
            </div>
            <div class="modal-footer">
                <div class="form-group text-right">
                    <button type="button" class="btn btn-default cerrarModalEdit" data-dismiss="modal">Cancelar</button>
                </div>
            </div>
        </div>
    </div>
</div>
<!---/////--- FIN MODAL VER LISTA DE PRECIO ---/////----->
<script>
    $(document).ready(function () {
        $(".select2").select2();
        $('#tablaArticulos').DataTable({
        "columnDefs": [
            { "orderable": true, "targets": [1, 2] }, 
            { "orderable": false, "targets": [0, 3] }
        ],
        "order": [[1, 'asc']],
        "autoWidth": false,
        "columns": [
            { "width": "auto" }, // Acciones
            { "width": "auto" }, // Código Artículo
            { "width": "auto" }, // Descripción
            { "width": "120px" } // Precio Unitario
        ],
        "createdRow": function(row, data, dataIndex) {
            $(row).addClass('centrar');
        }
    });
    });

    $("#cargar_tabla").load("index.php/core/Precio/listarPrecios");

    function guardarListaPrecio() {
        var nombre = $('#nombre').val();
        var version = 1;
        var detalle = $('#detalle').val() || 'Versión original';
        var tipo = $('#tipo').val();
        var recurso = 'index.php/core/Precio/agregarListaPrecio';
        
        var articulosTabla = [];
        $('#tablaArticulos').find('tbody tr').each(function() {
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
            articulosTabla.push(data);
        });

        $.ajax({
            url: recurso,
            method: 'POST',
            dataType: "json",
            data: {
                nombre: nombre,
                version: version,
                detalle: detalle,
                tipo: tipo,
                articulos: articulosTabla
            },
            success: function(response) {
                if (response.status) {
                    hecho("Hecho",'Lista de precios guardada correctamente.');
                    $('#modalListaPrecio').modal('hide');
                } else {
                    error('Error','Error en el procedimiento de guardado: ' + response.message);
                }
            },
            error: function() {
                error('Error','Error al realizar la solicitud.');
            }
        });
    }
    
    function verificarNombre() {
        var nombre = $('#nombre').val();
        var recurso = 'index.php/core/Precio/verificarNombre';
        if (nombre.length > 0) {
            $.ajax({
                url: recurso,
                method: 'POST',
                data: { nombre: nombre },
                success: function(response) {
                    if (response == 'existe') {
                        $('#mensajeError').show();
                    } else {
                        $('#mensajeError').hide();
                    }
                }
            });
        } else {
            $('#mensajeError').hide();
        }
    }

    document.getElementById('agregarArticulo').addEventListener('click', function() {
        const inputArticulo = document.getElementById('inputarti');
        const articuloSeleccionado = document.querySelector(`#articulos option[value="${inputArticulo.value}"]`);
        if (articuloSeleccionado) {
            const dataJson = JSON.parse(articuloSeleccionado.getAttribute('data-json'));
            const codigoArticulo = dataJson.barcode;
            const descripcionArticulo = dataJson.descripcion;
            const dataCodificada = JSON.stringify({
                arti_id: dataJson.arti_id
            });

            const table = $('#tablaArticulos').DataTable();
            table.row.add([
                `<button class="btn btn-danger btn-sm eliminarArticulo">
                    <i class="fa fa-trash"></i>
                </button>`,
                `<span data-json='${dataCodificada}'>${codigoArticulo}</span>`,
                descripcionArticulo,
                `<input type="text" class="form-control precioUnitario" placeholder="0,00" oninput="formatearPrecio(this)">`
            ]).draw(false);
            inputArticulo.value = '';
            actualizarBotonesEliminar();
        } else {
            error("Error",'Seleccione un artículo válido.');
        }
    });

    function actualizarBotonesEliminar() {
        document.querySelectorAll('.eliminarArticulo').forEach(function(btn) {
            btn.addEventListener('click', function() {
                const row = this.closest('tr');
                $('#tablaArticulos').DataTable().row(row).remove().draw(false);
            });
        });
    }

    function formatearPrecio(input) {
        const posicionCursor = input.selectionStart;
        let valor = input.value.replace(/\./g, '').replace(',', '.');
        if (!isNaN(valor) && valor !== '') {
            valor = parseFloat(valor).toFixed(2);
            input.value = valor.replace('.', ',');
        }
        input.setSelectionRange(posicionCursor, posicionCursor);
    }

</script>