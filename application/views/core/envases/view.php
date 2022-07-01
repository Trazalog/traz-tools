<!-- /// ---- HEADER ----- /// -->
<div class="box box-primary animated fadeInLeft">
    <div class="box-header with-border">
        <h4>Envases</h4>
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

<!--_______ FORMULARIO ENVASES______-->
<div class="box box-primary animated bounceInDown" id="boxDatos" hidden>
    <div class="box-header with-border">
        <div class="box-tittle">
            <h4>Nuevo Envase</h4>
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
        <form class="formEnvases" id="formEnvases">
            <!--Nombre-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Nombre">Nombre(<strong style="color: #dd4b39">*</strong>):</label>
                    <input type="text" class="form-control requerido" name="nombre" id="nombre" placeholder="Ingrese Nombre...">
                </div>
            </div>
            <!--________________-->
            <!--Recetas-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Receta">Receta(<strong style="color: #dd4b39">*</strong>):</label>
                    <select class="form-control select2 select2-hidden-accesible habilitar requerido" name="receta" id="receta">
                        <option value="" disabled selected>-Seleccione opción-</option>	
                        <?php
                            foreach ($listadoFormulas as $formula) {
                            echo '<option  value="'.$formula->form_id.'">'.$formula->descripcion.'</option>';
                            }
                        ?>
                    </select>
                </div>
            </div>
            <!--________________-->
            <!--Descripcion-->
            <div class="col-md-12 col-sm-12 col-xs-12">
                <div class="form-group">
                <label for="Descripcion">Descripción(<strong style="color: #dd4b39">*</strong>):</label>
                    <textarea class="form-control" name="descripcion" id="descripcion" rows="3" placeholder="Ingrese Descripción..."></textarea>
                </div>
            </div>
            <!--________________-->
            <!--Unidad de medida-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Unidad_medida">Unidad de medida(<strong style="color: #dd4b39">*</strong>):</label>
                    <select class="form-control select2 select2-hidden-accesible habilitar requerido" name="unidad_medida" id="unidad_medida">
                        <option value="" disabled selected>-Seleccione opción-</option>	
                        <?php
                            foreach ($listadoUnidades as $unidad) {
                            echo '<option  value="'.$unidad->tabl_id.'">'.$unidad->valor.'</option>';
                            }
                        ?>
                    </select>
                </div>
            </div>
            <!--________________-->
            <!--Contenido neto-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Contenido">Contenido neto(<strong style="color: #dd4b39">*</strong>):</label>
                    <input type="text" class="form-control requerido" name="contenido" id="contenido" placeholder="Ingrese Contenido neto...">
                </div>
            </div>
            <!--________________-->
            <!--Tara-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Tara">Tara(<strong style="color: #dd4b39">*</strong>):</label>
                    <input type="text" class="form-control requerido" name="tara" id="tara" placeholder="Ingrese Tara...">
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
<!--_______ FIN FORMULARIO ENVASES ______-->

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
                            <form class="frm_envase_edit" id="frm_envase_edit">
                                <input type="text" class="form-control habilitar hidden" name="empa_id" id="empa_id_edit">                    
                                <!--_____________ NOMBRE _____________-->
                                <div class="col-sm-6">
                                    <div class="form-group">
                                        <label for="nombre_edit" class="col-sm-4 control-label">Nombre:</label>
                                        <div class="col-sm-8">
                                            <input type="text" class="form-control habilitar requerido" name="nombre" id="nombre_edit">
                                        </div>
                                    </div>
                                </div>
                                <!--___________________________-->
                                <!--_____________ RECETA _____________-->
                                <div class="col-sm-6">
                                    <div class="form-group">
                                        <label for="receta_edit" class="col-sm-4 control-label">Receta:</label>
                                        <div class="col-sm-8">
                                            <!-- <input type="text" class="form-control habilitar" id="vehiculo_edit">  -->
                                            <select class="form-control select2 select2-hidden-accesible habilitar requerido" name="receta" id="receta_edit">	
                                            <?php
                                                foreach ($listadoFormulas as $formula) {
                                                echo '<option  value="'.$formula->form_id.'">'.$formula->descripcion.'</option>';
                                                }
                                            ?>
                                            </select>
                                        </div>
                                    </div>
                                </div>
                                <!--__________________________-->
                                <!--_____________ DESCRIPCION _____________-->
                                <div class="col-sm-12">
                                    <div class="form-group">
                                        <label for="descripcion_edit" class="col-sm-2 control-label">Descripción:</label>
                                        <div class="col-sm-10">
                                            <textarea class="form-control habilitar requerido" name="descripcion" id="descripcion_edit"></textarea>
                                        </div>
                                    </div>
                                </div>
                                <!--___________________________-->
                                <!--_____________ UNIDAD DE MEDIDA _____________-->
                                <div class="col-sm-6">
                                    <div class="form-group">
                                        <label for="unidad_medida_edit" class="col-sm-4 control-label">Unidad de medida:</label>
                                        <div class="col-sm-8">
                                            <!-- <input type="text" class="form-control habilitar" id="vehiculo_edit">  -->
                                            <select class="form-control select2 select2-hidden-accesible habilitar requerido" name="unidad_medida" id="unidad_medida_edit">	
                                            <?php
                                                foreach ($listadoUnidades as $unidad) {
                                                echo '<option  value="'.$unidad->tabl_id.'">'.$unidad->valor.'</option>';
                                                }
                                            ?>
                                            </select>
                                        </div>
                                    </div>
                                </div>
                                <!--_____________ CONTENIDO NETO _____________-->
                                <div class="col-sm-6">
                                    <div class="form-group">
                                        <label for="contenido_edit" class="col-sm-4 control-label">Contenido neto:</label>
                                        <div class="col-sm-8">
                                            <input type="text" class="form-control habilitar requerido" name="contenido" id="contenido_edit">
                                        </div>
                                    </div>
                                </div>
                                <!--___________________________-->
                                <!--_____________ TARA _____________-->
                                <div class="col-sm-6">
                                    <div class="form-group">
                                        <label for="tara_edit" class="col-sm-4 control-label">Tara:</label>
                                        <div class="col-sm-8">
                                            <input type="text" class="form-control habilitar requerido" name="tara" id="tara_edit">
                                        </div>
                                    </div>
                                </div>
                                <!--___________________________-->
                                <!-- </div> -->
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
// carga tabla genaral de envases
    $("#cargar_tabla").load("index.php/core/Envase/Listar_Envases");

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
//Alta de envase en sistmea
function guardar(operacion){
  var recurso = "";
  if (operacion == "editar") {
    if( !validarCampos('formEdicion') ){
      return;
    }
    var form = $('#formEdicion')[0];
    var datos = new FormData(form);
    var datos = formToObject(datos);
    recurso = 'index.php/core/Envase/Editar_Envase';
  } else {
    if( !validarCampos('formEnvases') ){
      return;
    }
    var form = $('#formEnvases')[0];
    var datos = new FormData(form);
    var datos = formToObject(datos);
    recurso = 'index.php/core/Envase/Guardar_Envase';
  }
  wo();
  $.ajax({
      type: 'POST',
      data:{ datos },
      //dataType: 'JSON',
      url: recurso,
      success: function(resp) {
        $("#cargar_tabla").load("index.php/core/Envase/Listar_Envases");
        wc();
        $("#boxDatos").hide(500);
        $("#formEnvases")[0].reset();
        $("#botonAgregar").removeAttr("disabled");
        if (operacion == "editar") {
            alertify.success("Envase editado exitosamente");             
        }else{
            alertify.success("Envase creado exitosamente");
        }
      },
      error: function(result){
        alertify.error("Error agregando envase");
        wc();
      },
      complete: function(){
        wc();
      }
  });

}
</script>