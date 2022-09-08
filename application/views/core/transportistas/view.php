<!-- /// ---- HEADER ----- /// -->
<div class="box box-primary animated fadeInLeft">
    <div class="box-header with-border">
        <h4>Transportistas</h4>
    </div>
    <div class="box-body">
        <div class="row">
            <div class="col-md-2 col-lg-1 col-xs-12">
                <button type="button" id="botonAgregar" class="btn btn-primary" aria-label="Left Align">
                    Agregar
                </button><br>
            </div>
            <div class="col-md-10 col-lg-11 col-xs-12"></div>
        </div>
    </div>
</div>
<!-- /// ----- HEADER -----/// -->

<!--_______ FORMULARIO TRANSPORTISTAS______-->
<div class="box box-primary animated bounceInDown" id="boxDatos" hidden>
    <div class="box-header with-border">
        <div class="box-tittle">
            <h4>Nuevo Transportista</h4>
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
        <form class="formTransportistas" id="formTransportistas">
            <!--Nombre-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Nombre">Nombre(<strong style="color: #dd4b39">*</strong>):</label>
                    <input type="text" class="form-control requerido" name="nombre" id="nombre" placeholder="Ingrese Nombre...">
                </div>
            </div>
            <!--________________-->
            <!-- Dirección de Entrega -->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="dir_entrega">Dirección Entrega:</label>
                    <input type="text" class="form-control" name="dir_entrega" id="dir_entrega" placeholder="Ingrese Dirección...">
                </div>
            </div>
            <!--________________-->
            <!--Observaciones-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                <label for="Observaciones">Observaciones:</label>
                    <textarea class="form-control" name="observaciones" id="observaciones" rows="3" placeholder="Ingrese Observaciones..."></textarea>
                </div>
            </div>
            <!--________________-->
            <!--Tipo Transportista-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Tipo">Tipo(<strong style="color: #dd4b39">*</strong>):</label>
                    <select class="form-control select2 select2-hidden-accesible habilitar requerido" name="ticl_id" id="ticl_id">
                        <option value="" disabled selected>-Seleccione opción-</option>	
                        <?php
                            foreach ($tipos_transportistas as $tipos) {
                            echo '<option  value="'.$tipos->tabl_id.'">'.$tipos->valor.'</option>';
                            }
                        ?>
                    </select>
                </div>
            </div>
            <!--________________-->
        </form>
    </div>
    <!--_________________ GUARDAR_________________-->
    <div class="modal-footer">
        <div class="form-group text-right">
            <button type="button" class="btn btn-primary" onclick="guardar('nueva')" >Guardar</button>
        </div>                
    </div>
    <!--__________________________________-->
</div>
<!--_______ FIN FORMULARIO TRANSPORTISTAS ______-->

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

<!---///////--- MODAL EDICION E INFORMACION ---///////--->
<div class="modal fade bs-example-modal-lg" id="modaleditar" tabindex="-1" role="dialog" aria-labelledby="myLargeModalLabel">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header bg-blue">
                <button type="button" class="close close_modal_edit" data-dismiss="modal" aria-label="Close">
                        <span aria-hidden="true" style="color:white;">&times;</span>
                </button>
            </div>
            <div class="modal-body ">
                <form class="formEdicion" id="formEdicion">
                    <div class="form-horizontal">
                        <div class="row">
                            <form class="frm_transportista_edit" id="frm_transportista_edit">
                                <input type="text" class="form-control habilitar hidden" name="clie_id" id="clie_id_edit">
                                <div class="col-sm-6">
                                    <!--_____________ NOMBRE _____________-->
                                    <div class="form-group">
                                        <label for="nombre_edit" class="col-sm-4 control-label">Nombre:</label>
                                        <div class="col-sm-8">
                                            <input type="text" class="form-control habilitar requerido" name="nombre" id="nombre_edit">
                                        </div>
                                    </div>
                                    <!--___________________________-->
                                    <!--_____________ DIR ENTREGA _____________-->
                                    <div class="form-group">
                                        <label for="dir_entrega_edit" class="col-sm-4 control-label">Dirección Entrega:</label>
                                        <div class="col-sm-8">
                                            <input type="text" class="form-control habilitar" name="dir_entrega" id="dir_entrega_edit">
                                        </div>
                                    </div>
                                    <!--__________________________-->
                                    <!--_____________ OBSERVACIONES _____________-->
                                    <div class="form-group">
                                        <label for="observaciones_edit" class="col-sm-4 control-label">Observaciones:</label>
                                        <div class="col-sm-8">
                                            <input type="text" class="form-control habilitar" name="observaciones" id="observaciones_edit">
                                        </div>
                                    </div>
                                    <!--__________________________-->
                                </div>
                                <div class="col-sm-6">
                                    <!--_____________ TIPO TRANSPORTISTA _____________-->
                                    <div class="form-group">
                                        <label for="ticl_id_edit" class="col-sm-4 control-label">Tipo:</label>
                                        <div class="col-sm-8">
                                            <!-- <input type="text" class="form-control habilitar" id="vehiculo_edit">  -->
                                            <select class="form-control select2 select2-hidden-accesible habilitar requerido" name="ticl_id" id="ticl_id_edit">	
                                            <?php
                                                foreach ($tipos_transportistas as $tipos) {
                                                echo '<option  value="'.$tipos->tabl_id.'">'.$tipos->valor.'</option>';
                                                }
                                            ?>
                                            </select>
                                        </div>
                                    </div>
                                    <!--__________________________-->
                                </div>
                            </form>
                        </div>
                    </div>
                </form>
            </div>
            <div class="modal-footer">
                <div class="form-group text-right">
                    <button type="" class="btn btn-primary habilitar" data-dismiss="modal" id="btnsave_edit" onclick="guardar('editar')">Guardar</button>
                    <button type="" class="btn btn-default cerrarModalEdit" id="" data-dismiss="modal">Cerrar</button>
                </div>
            </div>
        </div>
    </div>
</div>
<!---///////--- FIN MODAL EDICION E INFORMACION ---///////--->
<script>
    // carga tabla genaral de transportistas
    $("#cargar_tabla").load("index.php/core/Transportista/Listar_Transportistas");

    // muestra box de datos al dar click en boton agregar
    $("#botonAgregar").on("click", function() {
        $("#botonAgregar").attr("disabled", "");
        //$("#boxDatos").removeAttr("hidden");
        $("#boxDatos").focus();
        $("#boxDatos").show();
    });

    // muestra box de datos al dar click en X
    $("#btnclose").on("click", function() {
        $("#boxDatos").hide(500);
        $("#botonAgregar").removeAttr("disabled");
        //$('#formDatos').data('bootstrapValidator').resetForm();
        $("#formDatos")[0].reset();
    });

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
//Alta de transportista en sistmea
function guardar(operacion){
    var recurso = "";
    if (operacion == "editar") {
        if( !validarCampos('formEdicion') ){
            return;
        }
        var form = $('#formEdicion')[0];
        var datos = new FormData(form);
        var datos = formToObject(datos);
        recurso = 'index.php/core/Transportista/Editar_Transportista';
    } else {
        if( !validarCampos('formTransportistas') ){
            return;
        }
        var form = $('#formTransportistas')[0];
        var datos = new FormData(form);
        var datos = formToObject(datos);
        recurso = 'index.php/core/Transportista/Guardar_Transportista';
    }
    wo();
    $.ajax({
        type: 'POST',
        data:{ datos },
        //dataType: 'JSON',
        url: recurso,
        success: function(result) {
            // $("#cargar_tabla").load("index.php/core/Transportista/Listar_Transportistas");
            // wc();
            $("#boxDatos").hide(500);
            $("#formTransportistas")[0].reset();
            $("#botonAgregar").removeAttr("disabled");
            if(result.status){
                $("#cargar_tabla").load("index.php/core/Transportista/Listar_Transportistas", () => {
                    if (operacion == "editar") {
                    alertify.success("Transportista Editado Exitosamente");
                        }else{
                    alertify.success("Transportista Agregado con Éxito");
                    }
                });            
            }else{
                alertify.error("Error agregando Transportista");
            }
        },
        error: function(result){
            wc();
            alertify.error("Error agregando Transportista");
        }
    });
}
</script>