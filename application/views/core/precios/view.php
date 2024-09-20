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
                        <div class="col-md-4 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="vigenteDesde">Vigente Desde:</label>
                                <input type="date" class="form-control requerido" name="vigenteDesde" id="vigenteDesde" value="<?= date('Y-m-d') ?>">
                            </div>
                        </div>
                        <!-- Vigente Hasta -->
                        <div class="col-md-4 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="vigenteHasta">Vigente Hasta:</label>
                                <input type="date" class="form-control requerido" name="vigenteHasta" id="vigenteHasta">
                            </div>
                        </div>
                        <!-- Agregar Artículo (Select) -->
                        <div class="col-md-4 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="agregarArticulo">Agregar Artículo:</label>
                                <select class="form-control" name="agregarArticulo" id="agregarArticulo">
                                    <option value="">Seleccione un artículo</option>
                                    <!-- Permitir agregar nuevos articulos con buscador por código o descripción, similar al de Recepción de materiales, pero para agregarlo debe apretar el botón. se agrega al final de la lista  -->
                                </select>
                            </div>
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

    // carga tabla de precios
    $("#cargar_tabla").load("index.php/core/Precio/listarPrecios");

    function guardarListaPrecio2() {    
        // Si no se ingresa un detalle, asignar "Versión original"
        if (empty($detalle)) {
            $detalle = 'Versión original';
        }
    }

    function guardarListaPrecio() {
        var nombre = $('#nombre').val();
        var tipo = $('#tipo').val();
        var version = 1;
        var detalle = $('#detalle').val() || 'Versión original';
        // var vigenteDesde = $('#vigenteDesde').val();
        var vigenteHasta = $('#vigenteHasta').val();
        var agregarArticulo = $('#agregarArticulo').val();
        var recurso = 'index.php/core/Precio/verificarNombre';
        $.ajax({
            url: recurso,
            method: 'POST',
            data: {
                nombre: nombre,
                tipo: tipo,
                version: version,
                detalle: detalle,
                vigenteHasta: vigenteHasta,
                agregarArticulo: agregarArticulo
            },
            success: function(response) {
                if (response.success) {
                    alert('Lista de precios guardada correctamente.');
                    $('#modalListaPrecio').modal('hide');  // Cerrar el modal
                    // Aquí puedes recargar la lista o actualizar la vista
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
                data: { nombre: nombre },  // Enviar el nombre como parámetro
                success: function(response) {
                    if (response == 'existe') {
                        $('#mensajeError').show();  // Mostrar mensaje si el nombre existe
                    } else {
                        $('#mensajeError').hide();  // Ocultar el mensaje si no existe
                    }
                }
            });
        } else {
            $('#mensajeError').hide();  // Ocultar el mensaje si no hay texto
        }
    }
</script>