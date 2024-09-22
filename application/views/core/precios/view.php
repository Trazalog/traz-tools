<!-- /// ---- HEADER ----- /// -->
<div class="box box-primary animated fadeInLeft">
    <div class="box-header with-border">
        <h4>Lista de Precios</h4>
    </div>
    <div class="box-body">
        <div class="row">
            <div class="col-md-2 col-lg-1 col-xs-12">
                <!-- <button type="button" id="botonAgregar" class="btn btn-primary" aria-label="Left Align">
                    Agregar
                </button><br> -->
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
                                <input type="text" class="form-control requerido" name="nombre" id="nombre" placeholder="Ingrese Nombre..." onkeyup="verificarNombre()">
                                <small id="mensajeError" style="color: red; display: none;">El nombre ya existe en la base de datos.</small>
                            </div>
                        </div>
                        <!-- Tipo (Select Venta/Compra) -->
                        <div class="col-md-4 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="Tipo">Tipo(<strong style="color: #dd4b39">*</strong>):</label>
                                <select class="form-control requerido" name="tipo" id="tipo">
                                    <option value="Venta">Venta</option>
                                    <option value="Compra">Compra</option>
                                </select>
                            </div>
                        </div>
                        <!-- Versión -->
                        <div class="col-md-4 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="Version">Versión:</label>
                                <input type="text" class="form-control" name="version" id="version" value="1" readonly>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-md-12 col-sm-12 col-xs-12">
                            <div class="form-group">
                                <label for="Detalle">Detalle:</label>
                                <textarea class="form-control" name="detalle" id="detalle" rows="3" placeholder="Ingrese los detalles"></textarea>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <!-- Vigente Desde -->
                        <div class="col-md-3 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="vigenteDesde">Vigente Desde:</label>
                                <input type="date" class="form-control requerido" name="vigenteDesde" id="vigenteDesde" value="<?= date('Y-m-d') ?>">
                            </div>
                        </div>
                        <!-- Vigente Hasta -->
                        <div class="col-md-3 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="vigenteHasta">Vigente Hasta:</label>
                                <input type="date" class="form-control requerido" name="vigenteHasta" id="vigenteHasta">
                            </div>
                        </div>
                        <!-- Agregar Artículo (Select) -->
                        <div class="col-md-3 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="lote">Seleccionar Articulo <strong style="color: #dd4b39">*</strong>:</label>
                                <?php $this->load->view(ALM.'articulo/componente'); ?>
                            </div>
                        </div>
                        <div class="col-md-3 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <button class="btn btn-primary ml-2" type="button" id="agregarArticulo">Agregar</button>
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
                                    <!-- Aquí se añadirán las filas dinámicas -->
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

<script>
    $(document).ready(function () {
        $(".select2").select2();
    });

    $("#cargar_tabla").load("index.php/core/Precio/listarPrecios");

    // function guardarListaPrecio2() {
    //     if (empty($detalle)) {
    //         $detalle = 'Versión original';
    //     }
    // }

    function guardarListaPrecio() {
        var nombre = $('#nombre').val();
        var tipo = $('#tipo').val();
        var version = 1;
        var detalle = $('#detalle').val() || 'Versión original';
        var recurso = 'index.php/core/Precio/verificarNombre';
        $.ajax({
            url: recurso,
            method: 'POST',
            data: {
                nombre: nombre,
                tipo: tipo,
                version: version,
                detalle: detalle
            },
            success: function(response) {
                if (response.success) {
                    alert('Lista de precios guardada correctamente.');
                    $('#modalListaPrecio').modal('hide');
                } else {
                    alert('Error al guardar la lista de precios: ' + response.message);
                }
            },
            error: function() {
                alert('Error al realizar la solicitud.');
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
            const nuevaFila = `
                <tr>
                    <td>
                        <button class="btn btn-danger btn-sm eliminarArticulo">
                            <i class="fa fa-trash"></i>
                        </button>
                    </td>
                    <td>${codigoArticulo}</td>
                    <td>${descripcionArticulo}</td>
                    <td>
                        <input type="text" class="form-control precioUnitario" placeholder="0,00" oninput="formatearPrecio(this)">
                    </td>
                </tr>
            `;
            document.querySelector('#tablaArticulos tbody').insertAdjacentHTML('beforeend', nuevaFila);
            inputArticulo.value = '';
            actualizarBotonesEliminar();
        } else {
            alert('Seleccione un artículo válido.');
        }
    });

    function actualizarBotonesEliminar() {
        document.querySelectorAll('.eliminarArticulo').forEach(function(btn) {
            btn.addEventListener('click', function() {
                this.closest('tr').remove();
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