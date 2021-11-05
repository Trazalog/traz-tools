<!-- /// ---- HEADER ----- /// -->
<div class="box box-primary animated fadeInLeft">
    <div class="box-header with-border">
        <h4>Lista de Proveedores</h4>
    </div>
    <div class="box-body">
        <div class="row">
            <div class="col-md-3">
                <button type="button" id="botonProveedor" class="btn btn-primary" data-toggle="modal" data-target="#modalProveedor" aria-label="Left Align">
                Agregar
                </button><br>
            </div>
            <div class="col-md-10 col-lg-11 col-xs-12"></div>
        </div>
    </div>
</div>
<!-- /// ----- HEADER -----/// -->

<!--_______ FORMULARIO PROVEEDORES______-->
<div class="box box-primary animated bounceInDown" id="boxDeposito" hidden>
    <div class="box-header with-border">
        <div class="box-tittle">
            <h4>Nuevo Proveedor</h4>
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
<!--_______ FIN FORMULARIO PROVEEDORES ______-->

<!---/////---BOX 2 DATATABLE PROVEEDORES---/////----->
<div class="box box-primary">
    <div class="box-body">
        <div class="col-md-3">
            <h4 style="float:left;">Proveedores</h4>
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
<!---/////--- FIN BOX 2 DATATABLE PROVEEDORES---//////----->

<!---///////--- MODAL NUEVO PROVEEDOR ---///////--->
<div class="modal fade bs-example-modal-lg" id="modalProveedor" tabindex="-1" role="dialog" aria-labelledby="myLargeModalLabel">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header bg-blue">
                <button type="button" class="close close_modal_edit" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true" style="color:white;">&times;</span>
                </button>
            </div>
            <div class="modal-body ">
                <form class="" id="formProveedor">
                    <!--Nombre-->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="nombre">Nombre(<strong style="color: #dd4b39">*</strong>):</label>
                            <input type="text" class="form-control requerido" name="nombre" id="nombre" placeholder="Ingrese Nombre...">
                        </div>
                    </div>
                    <!--________________-->
                    <!-- Cuit -->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="cuit">Cuit(<strong style="color: #dd4b39">*</strong>):</label>
                            <input type="text" class="form-control requerido" name="cuit" id="cuit" placeholder="Ingrese Cuit...">
                        </div>
                    </div>
                    <!--________________-->
                    <!--Domicilio-->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="domicilio">Domicilio(<strong style="color: #dd4b39">*</strong>):</label>
                            <input type="text" class="form-control requerido" name="domicilio" id="domicilio" placeholder="Ingrese Domicilio...">
                        </div>
                    </div>
                    <!--________________-->
                    <!--Teléfono-->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="telefono">Teléfono(<strong style="color: #dd4b39">*</strong>):</label>
                            <input type="text" class="form-control requerido" name="telefono" id="telefono" placeholder="Ingrese Teléfono...">
                        </div>
                    </div>
                    <!--________________-->
                    <!--Email-->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="email">Email(<strong style="color: #dd4b39">*</strong>):</label>
                            <input type="text" class="form-control requerido" name="email" id="email" placeholder="Ingrese Email...">
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
                    <button type="" class="btn btn-primary habilitar" data-dismiss="modal" id="btnsave_edit" onclick="guardarProveedor()">Guardar</button>
                    <button type="" class="btn btn-default cerrarModalEdit" id="" data-dismiss="modal">Cerrar</button>
                </div>
            <!-- </div> -->
            </div>
        </div>
    </div>
</div>
<!---///////--- FIN MODAL NUEVO PROVEEDOR ---///////--->

<!---///////--- MODAL EDICION PROVEEDOR ---///////--->
<div class="modal fade bs-example-modal-lg" id="modalEditarProveedor" tabindex="-1" role="dialog" aria-labelledby="myLargeModalLabel">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header bg-blue">
                <button type="button" class="close close_modal_edit" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true" style="color:white;">&times;</span>
                </button>
            </div>
            <div class="modal-body ">
                <form class="" id="formEdicionProveedor">
                    <input type="text" class="form-control habilitar hidden" name="prov_id" id="prov_id">
                    <!--Nombre-->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="nombre">Nombre(<strong style="color: #dd4b39">*</strong>):</label>
                            <input type="text" class="form-control requerido" name="nombre" id="nombre_edit" placeholder="Ingrese Nombre...">
                        </div>
                    </div>
                    <!--________________-->
                    <!-- Cuit -->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="cuit">Cuit(<strong style="color: #dd4b39">*</strong>):</label>
                            <input type="text" class="form-control requerido" name="cuit" id="cuit_edit" placeholder="Ingrese Cuit...">
                        </div>
                    </div>
                    <!--________________-->
                    <!--Domicilio-->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="domicilio">Domicilio(<strong style="color: #dd4b39">*</strong>):</label>
                            <input type="text" class="form-control requerido" name="domicilio" id="domicilio_edit" placeholder="Ingrese Domicilio...">
                        </div>
                    </div>
                    <!--________________-->
                    <!--Teléfono-->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="telefono">Teléfono(<strong style="color: #dd4b39">*</strong>):</label>
                            <input type="text" class="form-control requerido" name="telefono" id="telefono_edit" placeholder="Ingrese Teléfono...">
                        </div>
                    </div>
                    <!--________________-->
                    <!--Email-->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="email">Email(<strong style="color: #dd4b39">*</strong>):</label>
                            <input type="text" class="form-control requerido" name="email" id="email_edit" placeholder="Ingrese Email...">
                        </div>
                    </div>
                    <!--________________-->
                    <!--País-->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="pais">País:</label>
                            <select onchange="seleccionPaisEditar()" class="form-control select2 select2-hidden-accesible" name="pais" id="pais_edit">
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
                            <select onchange="seleccionEstadoEditar()" class="form-control select2 select2-hidden-accesible habilitar" name="estado" id="estado_edit">
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
                    <button type="" class="btn btn-primary habilitar" data-dismiss="modal" id="btnsave_edit" onclick="guardarEdicionProveedor()">Guardar</button>
                    <button type="" class="btn btn-default cerrarModalEdit" id="" data-dismiss="modal">Cerrar</button>
                </div>
            <!-- </div> -->
            </div>
        </div>
    </div>
</div>
<!---///////--- FIN MODAL EDICION PROVEEDOR ---///////--->

<!---///////--- MODAL DEPOSITOS ---///////--->
<div class="modal fade bs-example-modal-lg" id="modaldepositos" tabindex="-1" role="dialog" aria-labelledby="myLargeModalLabel">
  <div class="modal-dialog modal-lg" role="document">
    <div class="modal-content">
      <div class="modal-header bg-blue">
        <button type="button" class="close close_modal_edit" data-dismiss="modal" aria-label="Close">
          <span aria-hidden="true" style="color:white;">&times;</span>
        </button>
      </div>
      <div class="modal-body ">
        <div id="example2_wrapper" class="dataTables_wrapper form-inline dt-bootstrap">						
          <div class="row">
            <div class="col-sm-6"></div>
            <div class="col-sm-6"></div>
          </div>
          <div class="row">            
            <div class="col-sm-12 table-scroll">
              <input type="text" id="id_esta" class="hidden">
            <button class="btn btn-block btn-primary" style="width: 100px; margin-top: 10px;" onclick="agregarDeposito()">Agregar</button>
              <table id="tabla_depositos" class="table table-bordered table-striped">
                <thead class="thead-dark" bgcolor="#eeeeee">
                  <th>Acción</th>
                  <th>Nombre</th>
                </thead>
                <tbody >
                  <!--TABLE BODY -->
                </tbody>
              </table>
            </div>
          </div>						
        </div>
      </div>
      <div class="modal-footer">
        <div class="form-group text-right">
          <button type="button" class="btn btn-default cerrarModalEdit" data-dismiss="modal">Cerrar</button>
        </div>
      </div>
    </div>
  </div>  
</div>
<!---///////--- FIN MODAL DEPOSITOS ---///////--->

<!---///////--- MODAL AGREGAR DEPOSITO ---///////--->
<div class="modal fade bs-example-modal-lg" id="modalAgregarDeposito" tabindex="-1" role="dialog" aria-labelledby="myLargeModalLabel">
  <div class="modal-dialog modal-lg" role="document">
    <div class="modal-content">
      <div class="modal-header bg-blue">
        <button type="button" class="close close_modal_edit" data-dismiss="modal" aria-label="Close">
          <span aria-hidden="true" style="color:white;">&times;</span>
        </button>
      </div>
      <div class="modal-body ">
          <div class="form-horizontal">
            <div class="row">
              <form class="frmDeposito" id="frmDeposito">
                <div class="col-sm-6">
                    <input type="text" class="form-control habilitar hidden" name="prov_id" id="proveedor_id">
                    <!-- Depósito -->
                    <div class="col-md-6 col-sm-6 col-xs-12">
                        <div class="form-group">
                            <label for="deposito">Depósito(<strong style="color: #dd4b39">*</strong>):</label>
                            <input type="text" class="form-control requerido" name="descripcion" id="deposito" placeholder="Ingrese Depósito...">
                        </div>
                    </div>
                    <!--________________-->
                </div>
              </form>
            </div>
          </div>
      </div>
      <div class="modal-footer">
          <div class="form-group text-right">
              <button type="" class="btn btn-primary habilitar" data-dismiss="modal" id="btnsave_edit" onclick="guardarDeposito()">Guardar</button>
              <button type="" class="btn btn-default cerrarModalEdit" id="" data-dismiss="modal">Cerrar</button>
          </div>
      </div>
    </div>
  </div>
</div>
<!---///////--- FIN MODAL AGREGAR DEPOSITO ---///////--->

<script>
    // carga tabla de proveedores
    $("#cargar_tabla").load("index.php/core/Proveedor/listarProveedores");

    // habilita botones, selects e inputs de modal
    function habilitarEdicion(){
      $('.habilitar').removeAttr("disabled");
    }

    function blockEdicion(){
      $(".habilitar").attr("disabled","disabled");
    }

    // $("#botonProveedor").on("click", function() {
    //     $("#botonProveedor").attr("disabled", "");
    //     $("#boxDeposito").focus();
    //     $("#boxDeposito").show();
    // });

    $("#botonProveedor").on("click", function() {
        // var id_tabla = $("#selectTabla").val();
        // $("#tabla").val(id_tabla);
        $(".modal-header h4").remove();
        //guardo el tipo de operacion en el modal
        $("#operacion").val("Edit");
        //pongo titlo al modal
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Nuevo Proveedor</h4>');
    });

    // carga Estados dependiendo del pais seleccionado
    function seleccionPais() {
        var id_pais = $("#pais option:selected").text();
        $("#estado_edit").prop('disabled', false);
        $("#localidad_edit").prop('disabled', false);
        $("#estado_edit").empty();
        $("#localidad_edit").empty();
        wo();
        $.ajax({
            type: 'GET',
            dataType: "json",
            data: {id_pais: id_pais},
            url: 'index.php/core/Proveedor/getEstados',
            success: function(rsp) {
                // const limpiar = () => {
                //     for (let i = $('#estado').options.length; i >= 0; i--) {
                //         $('#estado').remove(i);
                //     }
                // };
                $('#estado').empty();
                $('#localidad').empty();
                if (rsp != null) {
                    // habilitarEdicion();
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

    // carga Estados dependiendo del pais seleccionado
    function seleccionPaisEditar() {
        var id_pais = $("#pais_edit option:selected").text();
        $("#estado_edit").prop('disabled', false);
        $("#estado_edit").empty();
        $("#localidad_edit").empty();
        wo();
        $.ajax({
            type: 'GET',
            dataType: "json",
            data: {id_pais},
            url: 'index.php/core/Proveedor/getEstados',
            success: function(rsp) {
                if (rsp != null) {
                    var datos = "<option value='' disabled selected>-Seleccione opción-</option>";
                    $('#localidad_edit').html(datos);
                    for (let i = 0; i < rsp.length; i++) {
                        var datito = encodeURIComponent(rsp[i].tabl_id);
                        datos += "<option value=" + datito + ">" + rsp[i].valor + "</option>";
                    }
                    $('#estado_edit').html(datos);
                } else {
                    var datos = "<option value='' disabled selected>-Seleccione opción-</option>";
                    $('#estado_edit').html(datos);
                    $('#localidad_edit').html(datos);                    
                    alertify.error("El País no contiene estados");
                }    
                wc();
            },
            error: function(data) {
                alert('Error');
            }
        });
    }

    // carga Localidades dependiendo del estado seleccionado
    function seleccionEstado() {
        var id_pais = $("#pais option:selected").text();
        var id_estado = $("#estado option:selected").text();
        wo();
        $.ajax({
            type: 'GET',
            dataType: "json",
            data: {id_pais, id_estado},
            url: 'index.php/core/Proveedor/getLocalidades',
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

    // carga Localidades dependiendo del estado seleccionado
    function seleccionEstadoEditar() {
        var id_pais = $("#pais_edit option:selected").text();
        var id_estado = $("#estado_edit option:selected").text();
        $("#localidad_edit").prop('disabled', false);
        $("#localidad_edit").empty();
        wo();
        $.ajax({
            type: 'GET',
            dataType: "json",
            data: {id_pais, id_estado},
            url: 'index.php/core/Proveedor/getLocalidades',
            success: function(rsp) {
                if (rsp != null) {
                    var datos = "<option value='' disabled selected>-Seleccione opción-</option>";
                    for (let i = 0; i < rsp.length; i++) {
                        var valor = encodeURIComponent(rsp[i].tabl_id);
                        datos += "<option value=" + valor + ">" + rsp[i].valor + "</option>";
                    }
                    $('#localidad_edit').html(datos);
                } else {
                    var datos = "<option value='' disabled selected>-Seleccione opción-</option>";
                    $('#localidad_edit').html(datos); 
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

    function guardarProveedor() {
        if( !validarCampos('formProveedor') ){
            return;
        }
        var recurso = "";
        var form = $('#formProveedor')[0];
        var datos = new FormData(form);
        var datos = formToObject(datos);
        recurso = 'index.php/core/Proveedor/guardarProveedor';
        wo();
        $.ajax({
            type: 'POST',
            data:{ datos },
            dataType: 'JSON',
            url: recurso,
            success: function(result) {
                $("#cargar_tabla").load("index.php/core/Proveedor/listarProveedores");
                $("#modalProveedor").modal('hide');
                form.reset();
                // $("#botonAgregar").removeAttr("disabled");
                alertify.success("Proveedor agregado con éxito");
                wc();
            },
            error: function(result){
                wc();
                alertify.error("Error agregando Proveedor");
            }            
        });
    }

    function guardarEdicionProveedor() {
        if( !validarCampos('formEdicionProveedor') ){
            return;
        }
        var estado = $("#estado_edit option:selected").val();
        var localidad = $("#localidad_edit option:selected").val();
        var recurso = "";
        var form = $('#formEdicionProveedor')[0];
        var datos = new FormData(form);
        var datos = formToObject(datos);
        recurso = 'index.php/core/Proveedor/guardarEdicionProveedor';
        wo();
        $.ajax({
            type: 'POST',
            data:{ datos, estado, localidad },
            dataType: 'JSON',
            url: recurso,
            success: function(result) {
                    $("#cargar_tabla").load("index.php/core/Proveedor/listarProveedores");
                    $("#modalProveedor").modal('hide');
                    form.reset();
                    // $("#botonAgregar").removeAttr("disabled");
                    alertify.success("Proveedor agregado con éxito");
                wc();
            },
            error: function(result){
                wc();
                alertify.error("Error agregando Proveedor");
            }            
        });
    }

    function eliminarDeposito(e) {
        var data = JSON.parse($(e).closest('tr').attr('data-json'));
        var depo_id = data.depo_id;
        // var prov_id = data.prov_id;
        $('#depo_id').val(data.depo_id);
        // var prov_id = $("#id_esta").val();
        // var prov_id = $("#proveedor_id").val();
        // $("#id_proveedor_borrar").val(prov_id);
        $(".modal-header h4").remove();
        //pongo titulo al modal
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Eliminar Depósito </h4>');
        $("#modaldepositos").modal('hide');
        $('#modalAvisoDeposito').modal('show');
    }

    function eliminarDepositoDeProveedor() {
        var depo_id = $("#depo_id").val();
        // var prov_id = $("#id_esta").val();
        // var prov_id = $("#id_proveedor_borrar").val();
        wo();
        $.ajax({
            type: 'POST',
            data:{depo_id: depo_id},
            url: 'index.php/core/Proveedor/borrarDepositoDeProveedor',
            success: function(result) {
            $("#cargar_tabla").load("index.php/core/Proveedor/listarProveedores");
            setTimeout(function(){ 
                alertify.success("Depósito eliminado con éxito");
                wc();
                // alert("Hello"); 
            }, 3000);
            $("#modalAvisoDeposito").modal('hide');
            },
            error: function(result){
            wc();
            $("#modalAvisoDeposito").modal('hide');
            alertify.error('Error en eliminado de Depósito...');
            }
        });        
    }
    

</script>

<!-- Modal aviso eliminar deposito-->
<div class="modal fade" id="modalAvisoDeposito">
    <div class="modal-dialog" role="document">
      <div class="modal-content">
        <div class="modal-header bg-blue">
          <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
          <h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-trash text-light-blue"></span> Eliminar Depósito</h4>
        </div>
        <div class="modal-body">
          <div class="row">
            <div class="col-xs-12">
              <h4>¿Desea realmente eliminar el depósito del proveedor?</h4>
              <input type="text" id="depo_id" class="hidden">
              <!-- <input type="text" id="id_proveedor_borrar" class="hidden"> -->
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button>
          <button type="button" class="btn btn-primary" data-dismiss="modal" onclick="eliminarDepositoDeProveedor()">Aceptar</button>
        </div>
      </div>
    </div>
</div>
<!-- /  Modal aviso eliminar deposito-->