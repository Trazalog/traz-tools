<!-- /// ---- HEADER ----- /// -->
<div class="box box-primary animated fadeInLeft">
    <div class="box-header with-border">
        <h4>Lista de Establecimientos</h4>
    </div>
    <div class="box-body">
        <div class="row">
            <div class="col-md-3">
                <button type="button" id="botonEstablecimiento" class="btn btn-primary" data-toggle="modal" data-target="#modalEstablecimiento" aria-label="Left Align">
                Agregar
                </button><br>
            </div>
            <div class="col-md-10 col-lg-11 col-xs-12"></div>
        </div>
    </div>
</div>
<!-- /// ----- HEADER -----/// -->

<!--_______ FORMULARIO ESTABLECIMIENTOS______-->
<div class="box box-primary animated bounceInDown" id="boxDeposito" hidden>
    <div class="box-header with-border">
        <div class="box-tittle">
            <h4>Nuevo Establecimiento</h4>
        </div>
        <div class="box-tools pull-right border ">
            <button type="button" id="btnclose" title="cerrar" class="btn btn-box-tool" data-widget="remove"
                data-toggle="tooltip" title="" data-original-title="Remove">
                <i class="fa fa-times"></i>
            </button>
        </div>
    </div>
    <!--_____________________________________________-->
    <div class="box-body">
        <form class="formLista" id="formLista">
            <!--Nombre-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Nombre">Nombre(<strong style="color: #dd4b39">*</strong>):</label>
                    <input type="text" class="form-control requerido" name="nombreLista" id="nombreLista" onkeypress="return check(event)" placeholder="Ingrese Nombre de lista">
                </div>
            </div>
        </form>
    </div>
    <!--_________________ GUARDAR_________________-->
    <div class="modal-footer">
        <div class="form-group text-right">
            <button type="button" class="btn btn-primary" onclick="" >Confirmar</button>
        </div>
    </div>
    <!--__________________________________-->
</div>
<!--_______ FIN FORMULARIO ESTABLECIMIENTOS ______-->

<!---/////---BOX 2 DATATABLE ESTABLECIMIENTOS---/////----->
<div class="box box-primary">
    <div class="box-body">
        <div class="col-md-3">
            <h4 style="float:left;">Establecimientos</h4>
        </div>
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
<!---/////--- FIN BOX 2 DATATABLE ESTABLECIMIENTOS---//////----->

<!---///////--- MODAL NUEVO ESTABLECIMIENTO ---///////--->
<div class="modal fade bs-example-modal-lg" id="modalEstablecimiento" tabindex="-1" role="dialog" aria-labelledby="myLargeModalLabel">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header bg-blue">
                <button type="button" class="close close_modal_edit" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true" style="color:white;">&times;</span>
                </button>
            </div>
            <div class="modal-body ">
                <form class="" id="formEstablecimiento">
                    <!--Nombre-->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="nombre">Nombre(<strong style="color: #dd4b39">*</strong>):</label>
                            <input type="text" class="form-control requerido" name="nombre" id="nombre" placeholder="Ingrese Nombre...">
                        </div>
                    </div>
                    <!--________________-->
                    <!-- Calle -->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="calle">Calle(<strong style="color: #dd4b39">*</strong>):</label>
                            <input type="text" class="form-control requerido" name="calle" id="calle" placeholder="Ingrese Calle...">
                        </div>
                    </div>
                    <!--________________-->
                    <!--Altura-->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="altura">Altura(<strong style="color: #dd4b39">*</strong>):</label>
                            <input type="text" class="form-control requerido" name="altura" id="altura" placeholder="Ingrese Altura...">
                        </div>
                    </div>
                    <!--________________-->
                    <!--País-->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="pais">País:</label>
                            <select onchange="seleccionPais()" class="form-control select2 select2-hidden-accesible" name="pais" id="pais">
                                <option value="" disabled selected>-Seleccione opción-</option>	
                                <?php
                                    foreach ($listarPaises as $pais) {
                                    echo '<option  value="'.$pais->tabl_id.'">'.$pais->valor.'</option>';
                                    }
                                ?>
                            </select>
                        </div>
                    </div>
                    <!--________________-->
                    <!--Estado-->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="estado">Estado:</label>
                            <select onchange="seleccionEstado()" class="form-control select2 select2-hidden-accesible habilitar" name="estado" id="estado">
                                <option value="" disabled selected>-Seleccione opción-</option>	
                                <?php
                                    foreach ($tipos_clientes as $tipos) {
                                    echo '<option  value="'.$tipos->tabl_id.'">'.$tipos->valor.'</option>';
                                    }
                                ?>
                            </select>
                        </div>
                    </div>
                    <!--________________-->
                    <!--Localidad-->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="localidad">Localidad:</label>
                            <select class="form-control select2 select2-hidden-accesible habilitar" name="localidad" id="localidad">
                                <option value="" disabled selected>-Seleccione opción-</option>	
                                <?php
                                    foreach ($tipos_clientes as $tipos) {
                                    echo '<option  value="'.$tipos->tabl_id.'">'.$tipos->valor.'</option>';
                                    }
                                ?>
                            </select>
                        </div>
                    </div>
                    <!--________________-->
                </form>
            </div>
            <div class="modal-footer">
            <!-- <div class="col-sm-6"> -->
                <div class="form-group text-right">
                    <button type="" class="btn btn-primary habilitar" data-dismiss="modal" id="btnsave_edit" onclick="guardarEstablecimiento()">Guardar</button>
                    <button type="" class="btn btn-default cerrarModalEdit" id="" data-dismiss="modal">Cerrar</button>
                </div>
            <!-- </div> -->
            </div>
        </div>
    </div>
</div>
<!---///////--- FIN MODAL NUEVO ESTABLECIMIENTO ---///////--->

<!---///////--- MODAL EDICION ESTABLECIMIENTO ---///////--->
<div class="modal fade bs-example-modal-lg" id="modalEditarEstablecimiento" tabindex="-1" role="dialog" aria-labelledby="myLargeModalLabel">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header bg-blue">
                <button type="button" class="close close_modal_edit" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true" style="color:white;">&times;</span>
                </button>
            </div>
            <div class="modal-body ">
                <form class="" id="formEdicionEstablecimiento">
                    <input type="text" class="form-control habilitar hidden" name="esta_id" id="esta_id">
                    <!--Nombre-->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="nombre">Nombre(<strong style="color: #dd4b39">*</strong>):</label>
                            <input type="text" class="form-control requerido" name="nombre" id="nombre_edit" placeholder="Ingrese Nombre...">
                        </div>
                    </div>
                    <!--________________-->
                    <!-- Calle -->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="calle">Calle(<strong style="color: #dd4b39">*</strong>):</label>
                            <input type="text" class="form-control requerido" name="calle" id="calle_edit" placeholder="Ingrese Calle...">
                        </div>
                    </div>
                    <!--________________-->
                    <!--Altura-->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="altura">Altura(<strong style="color: #dd4b39">*</strong>):</label>
                            <input type="text" class="form-control requerido" name="altura" id="altura_edit" placeholder="Ingrese Altura...">
                        </div>
                    </div>
                    <!--________________-->
                    <!--País-->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="pais">País:</label>
                            <select onchange="seleccionPais()" class="form-control select2 select2-hidden-accesible" name="pais" id="pais_edit">
                                <option value="" disabled selected>-Seleccione opción-</option>	
                                <?php
                                    foreach ($listarPaises as $pais) {
                                    echo '<option  value="'.$pais->tabl_id.'">'.$pais->valor.'</option>';
                                    }
                                ?>
                            </select>
                        </div>
                    </div>
                    <!--________________-->
                    <!--Estado-->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="estado">Estado:</label>
                            <select onchange="seleccionEstado()" class="form-control select2 select2-hidden-accesible habilitar" name="estado" id="estado_edit">
                                <option value="" disabled selected>-Seleccione opción-</option>	
                                <?php
                                    foreach ($tipos_clientes as $tipos) {
                                    echo '<option  value="'.$tipos->tabl_id.'">'.$tipos->valor.'</option>';
                                    }
                                ?>
                            </select>
                        </div>
                    </div>
                    <!--________________-->
                    <!--Localidad-->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="localidad">Localidad:</label>
                            <select class="form-control select2 select2-hidden-accesible habilitar" name="localidad" id="localidad_edit">
                                <option value="" disabled selected>-Seleccione opción-</option>	
                                <?php
                                    foreach ($tipos_clientes as $tipos) {
                                    echo '<option  value="'.$tipos->tabl_id.'">'.$tipos->valor.'</option>';
                                    }
                                ?>
                            </select>
                        </div>
                    </div>
                    <!--________________-->
                </form>
            </div>
            <div class="modal-footer">
            <!-- <div class="col-sm-6"> -->
                <div class="form-group text-right">
                    <button type="" class="btn btn-primary habilitar" data-dismiss="modal" id="btnsave_edit" onclick="guardarEdicionEstablecimiento()">Guardar</button>
                    <button type="" class="btn btn-default cerrarModalEdit" id="" data-dismiss="modal">Cerrar</button>
                </div>
            <!-- </div> -->
            </div>
        </div>
    </div>
</div>
<!---///////--- FIN MODAL EDICION ESTABLECIMIENTO ---///////--->

<!-- MODAL AVISO ELIMINAR ESTABLECIMIENTO -->
<div class="modal fade" id="modalEliminarEstablecimiento">
    <div class="modal-dialog" role="document">
      <div class="modal-content">
        <div class="modal-header bg-blue">
          <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
          <h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-trash text-light-blue"></span> Eliminar Cliente</h4>
        </div>
        <div class="modal-body">
          <div class="row">
            <div class="col-xs-12">
              <h4>¿Desea realmente eliminar el Establecimiento?</h4>
              <input type="text" id="id_esta" class="hidden">
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button>
          <button type="button" class="btn btn-primary" data-dismiss="modal" onclick="eliminarEstablecimiento()">Aceptar</button>
        </div>
      </div>
    </div>
  </div>
<!-- /  MODAL AVISO ELIMINAR ESTABLECIMIENTO -->

<script>
    // carga tabla de establecimientos
    $("#cargar_tabla").load("index.php/core/Establecimiento/listarEstablecimientos");

    // habilita botones, selects e inputs de modal
    function habilitarEdicion(){
      $('.habilitar').removeAttr("disabled");
    }

    function blockEdicion(){
      $(".habilitar").attr("disabled","disabled");
    }

    // $("#botonEstablecimiento").on("click", function() {
    //     $("#botonEstablecimiento").attr("disabled", "");
    //     $("#boxDeposito").focus();
    //     $("#boxDeposito").show();
    // });

    $("#botonEstablecimiento").on("click", function() {
        // var id_tabla = $("#selectTabla").val();
        // $("#tabla").val(id_tabla);
        $(".modal-header h4").remove();
        //guardo el tipo de operacion en el modal
        $("#operacion").val("Edit");
        //pongo titlo al modal
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Nuevo Establecimiento</h4>');
    });

    // carga Estados dependiendo del pais seleccionado
    function seleccionPais() {
        var id_pais = $("#pais option:selected").text();
        wo();
        $.ajax({
            type: 'GET',
            dataType: "json",
            data: {id_pais},
            url: 'index.php/core/Establecimiento/getEstados',
            success: function(rsp) {
                // const limpiar = () => {
                //     for (let i = $('#estado').options.length; i >= 0; i--) {
                //         $('#estado').remove(i);
                //     }
                // };
                $('#estado').empty();
                $('#localidad').empty();
                if (rsp != null) {
                    habilitarEdicion();
                    var datos = "<option value='' disabled selected>-Seleccione opción-</option>";
                    $('#localidad').html(datos);
                    for (let i = 0; i < rsp.length; i++) {
                        // console.log(rsp[i].tabl_id.toString());
                        var datito = encodeURIComponent(rsp[i].tabl_id);
                        // var dato_nuevo = rsp[i].tabl_id.toString();
                        datos += "<option value=" + datito + ">" + rsp[i].valor + "</option>";
                    }
                    $('#estado').html(datos);
                } else {
                    var datos = "<option value='' disabled selected>-Seleccione opción-</option>";
                    $('#estado').html(datos);
                    $('#localidad').html(datos);
                    // $('#pais').val($('#pais > option:first').val());
                    // $('#estado').val($('#estado > option:first').val());
                    // $('#localidad').val($('#localidad > option:first').val());                    
                    alertify.error("El País no contiene estados");
                }    
                wc();
            },
            error: function(data) {
                alert('Error');
            }
        });
    }

    function seleccionEstado() {
        var id_pais = $("#pais option:selected").text();
        var id_estado = $("#estado option:selected").text();
        wo();
        $.ajax({
            type: 'GET',
            dataType: "json",
            data: {id_pais, id_estado},
            url: 'index.php/core/Establecimiento/getLocalidades',
            success: function(rsp) {
                $('#localidad').empty();
                if (rsp != null) {
                    habilitarEdicion();
                    var datos = "<option value='' disabled selected>-Seleccione opción-</option>";
                    for (let i = 0; i < rsp.length; i++) {
                        var valor = encodeURIComponent(rsp[i].tabl_id);
                        // datos += "<option value='"+ rsp[i].tabl_id + "'>"+ rsp[i].valor + "</option>";
                        datos += "<option value=" + valor + ">" + rsp[i].valor + "</option>";
                    }
                    $('#localidad').html(datos);
                } else {
                    var datos = "<option value='' disabled selected>-Seleccione opción-</option>";
                    $('#localidad').html(datos);
                    // $('#estado').val($('#estado > option:first').val());
                    // $('#localidad').val($('#localidad > option:first').val());  
                    alertify.error("El Estado no contiene localidades");
                }
                wc();
            },
            error: function(data) {
                alert('Error');
            }
        });
    }

    // valida campos obligatorios
    function validarCampos(form){
        var mensaje = "";
        var ban = true;
        $('#' + form).find('.requerido').each(function() {
        if (this.value == "" || this.value=="-1") {
            ban = ban && false;
            return;
        }
        });
        if (!ban){
            if(!alertify.errorAlert){
            alertify.dialog('errorAlert',function factory(){
                return{
                        build:function(){
                            var errorHeader = '<span class="fa fa-times-circle fa-2x" '
                            +    'style="vertical-align:middle;color:#e10000;">'
                            + '</span>Error...!!';
                            this.setHeader(errorHeader);
                        }
                    };
                },true,'alert');
            }
            alertify.errorAlert("Por favor complete los campos Obligatorios(*)..." );
        }
        return ban;
    }

    function guardarEstablecimiento() {
        if( !validarCampos('formEstablecimiento') ){
            return;
        }
        var recurso = "";
        var form = $('#formEstablecimiento')[0];
        var datos = new FormData(form);
        var datos = formToObject(datos);
        recurso = 'index.php/core/Establecimiento/guardarEstablecimiento';
        wo();
        $.ajax({
            type: 'POST',
            data:{ datos },
            dataType: 'JSON',
            url: recurso,
            success: function(result) {
                    $("#cargar_tabla").load("index.php/core/Establecimiento/listarEstablecimientos");
                    $("#modalEstablecimiento").modal('hide');
                    form.reset();
                    // $("#botonAgregar").removeAttr("disabled");
                    alertify.success("Establecimiento agregado con éxito");
                wc();
            },
            error: function(result){
                wc();
                alertify.error("Error agregando Establecimiento");
            }            
        });
    }

    function guardarEdicionEstablecimiento() {
        if( !validarCampos('formEstablecimiento') ){
            return;
        }
        var recurso = "";
        var form = $('#formEstablecimiento')[0];
        var datos = new FormData(form);
        var datos = formToObject(datos);
        recurso = 'index.php/core/Establecimiento/guardarEdicionEstablecimiento';
        wo();
        $.ajax({
            type: 'POST',
            data:{ datos },
            dataType: 'JSON',
            url: recurso,
            success: function(result) {
                    $("#cargar_tabla").load("index.php/core/Establecimiento/listarEstablecimientos");
                    $("#modalEstablecimiento").modal('hide');
                    form.reset();
                    // $("#botonAgregar").removeAttr("disabled");
                    alertify.success("Establecimiento agregado con éxito");
                wc();
            },
            error: function(result){
                wc();
                alertify.error("Error agregando Establecimiento");
            }            
        });
    }
    

</script>