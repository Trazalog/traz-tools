<!-- /// ---- HEADER ----- /// -->
<div class="box box-primary animated fadeInLeft">
    <div class="box-header with-border">
        <h4>Equipos</h4>
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

<!--_______ FORMULARIO EQUIPOS______-->
<div class="box box-primary animated bounceInDown" id="boxDatos" hidden>
    <div class="box-header with-border">
        <div class="box-tittle">
            <h4>Nuevo Equipo</h4>
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
        <form class="formEquipos" id="formEquipos">
            <!--Descripcion-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Descripcion">Descripción(<strong style="color: #dd4b39">*</strong>):</label>
                    <input type="text" class="form-control requerido" name="descripcion" id="descripcion" placeholder="Ingrese Nombre...">
                </div>
            </div>
            <!--________________-->
            <!--Marca-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Marca">Marca(<strong style="color: #dd4b39">*</strong>):</label>
                    <input type="text" class="form-control requerido" name="marca" id="marca" placeholder="Ingrese Marca...">
                </div>
            </div>
            <!--________________-->            
            <!--Tipos de Acivos-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Tipo">Tipo(<strong style="color: #dd4b39">*</strong>):</label>
                    <select class="form-control select2 select2-hidden-accesible habilitar requerido" name="activos_id" id="activos_id">
                        <option value="" disabled selected>-Seleccione opción-</option>	
                        <?php
                            foreach ($listadoTiposActivos as $tipo) {
                                echo '<option  value="'.$tipo->tabl_id.'">'.$tipo->valor.'</option>';
                            }
                        ?>
                    </select>
                </div>
            </div>
            <!--________________-->
            <!--Sectores-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Sector">Sector(<strong style="color: #dd4b39">*</strong>):</label>
                    <select class="form-control select2 select2-hidden-accesible habilitar requerido" name="sect_id" id="sect_id">
                        <option value="" disabled selected>-Seleccione opción-</option>	
                        <?php
                            foreach ($listadoSectores as $sector) {
                                echo '<option  value="'.$sector->tabl_id.'">'.$sector->valor.'</option>';
                            }
                        ?>
                    </select>
                </div>
            </div>
            <!--________________-->
            <!--Areas-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Area">Área(<strong style="color: #dd4b39">*</strong>):</label>
                    <select class="form-control select2 select2-hidden-accesible habilitar requerido" name="area_id" id="area_id">
                        <option value="" disabled selected>-Seleccione opción-</option>	
                        <?php
                            foreach ($listadoAreas as $area) {
                                echo '<option  value="'.$area->tabl_id.'">'.$area->valor.'</option>';
                            }
                        ?>
                    </select>
                </div>
            </div>
            <!--________________-->
            <!--Codigo-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Codigo">Código(<strong style="color: #dd4b39">*</strong>):</label>
                    <input type="text" class="form-control requerido" name="codigo" id="codigo" placeholder="Ingrese Código...">
                </div>
            </div>
            <!--________________-->
            <!--Unidad de medida-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Unidad_medida">Unidad de medida(<strong style="color: #dd4b39">*</strong>):</label>
                    <select class="form-control select2 select2-hidden-accesible habilitar requerido" name="unme_id" id="unme_id">
                        <option value=null disabled selected>-Seleccione opción-</option>	
                        <?php
                            foreach ($listadoUnidades as $unidad) {
                            echo '<option  value="'.$unidad->tabl_id.'">'.$unidad->valor.'</option>';
                            }
                        ?>
                    </select>
                </div>
            </div>
            <!--________________-->
            <!--Criticidad-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Criticidad">Criticidad(<strong style="color: #dd4b39">*</strong>):</label>
                    <select class="form-control select2 select2-hidden-accesible habilitar requerido" name="crit_id" id="crit_id">
                        <option value="0" disabled selected>-Seleccione opción-</option>	
                        <?php
                            foreach ($listadoCriticidad as $criticidad) {
                            echo '<option  value="'.$criticidad->tabl_id.'">'.$criticidad->valor.'</option>';
                            }
                        ?>
                    </select>
                </div>
            </div>
            <!--________________-->
            <!--Grupo-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Grupo">Grupo(<strong style="color: #dd4b39">*</strong>):</label>
                    <input type="number" class="form-control requerido" name="grup_id" id="grup_id" placeholder="Ingrese Grupo...">
                </div>
            </div>
            <!--________________-->            
            <!--Numero de serie-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Numero">Número de serie(<strong style="color: #dd4b39">*</strong>):</label>
                    <input type="number" class="form-control requerido" name="numero_serie" id="numero_serie" placeholder="Ingrese Número de serie...">
                </div>
            </div>
            <!--________________-->            
            <!--Fecha de Ingreso-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Fecha_ingreso">Fecha de Ingreso:</label>
                    <input type="date" class="form-control" name="fecha_ingreso" id="fecha_ingreso" placeholder="Ingrese Fecha de Ingreso...">
                </div>
            </div>
            <!--________________-->
            <!--Fecha de Garantía-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Fecha_garantia">Fecha de Garantía:</label>
                    <input type="date" class="form-control" name="fecha_garantia" id="fecha_garantia" placeholder="Ingrese Fecha de Garantía...">
                </div>
            </div>
            <!--________________-->
            <!--Ubicacion-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Ubicacion">Ubicación(<strong style="color: #dd4b39">*</strong>):</label>
                    <input type="text" class="form-control requerido" name="ubicacion" id="ubicacion" placeholder="Ingrese Ubicación...">
                </div>
            </div>
            <!--________________-->
            <!--Descripción Tecnica-->
            <div class="col-md-12 col-sm-12 col-xs-12">
                <div class="form-group">
                <label for="Descripcion_tecnica">Descripción Técnica:</label>
                    <textarea class="form-control" name="descrip_tecnica" id="descrip_tecnica" rows="3" placeholder="Ingrese Descripción..."></textarea>
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
<!--_______ FIN FORMULARIO EQUIPOS ______-->

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
                            <form class="frm_equipo_edit" id="frm_equipo_edit">
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
// carga tabla genaral de equipos
    $("#cargar_tabla").load("index.php/core/Equipo/Listar_Equipos");

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
//Alta de equipo en sistmea
function guardar(operacion){
  var recurso = "";
  if (operacion == "editar") {
    if( !validarCampos('formEdicion') ){
      return;
    }
    var form = $('#formEdicion')[0];
    var datos = new FormData(form);
    var datos = formToObject(datos);
    recurso = 'index.php/core/Equipo/Editar_Equipo';
  } else {
    if( !validarCampos('formEquipos') ){
      return;
    }
    var form = $('#formEquipos')[0];
    var datos = new FormData(form);
    var datos = formToObject(datos);
    recurso = 'index.php/core/Equipo/Guardar_Equipo';
  }
  wo();
  $.ajax({
      type: 'POST',
      data:{ datos },
      //dataType: 'JSON',
      url: recurso,
      success: function(resp) {
        $("#cargar_tabla").load("index.php/core/Equipo/Listar_Equipos");
        wc();
        $("#boxDatos").hide(500);
        $("#formEquipos")[0].reset();
        $("#botonAgregar").removeAttr("disabled");
        if (operacion == "editar") {
            alertify.success("Equipo editado exitosamente");             
        }else{
            alertify.success("Equipo creado exitosamente");
        }
      },
      error: function(result){
        alertify.error("Error agregando equipo");
        wc();
      },
      complete: function(){
        wc();
      }
  });

}
</script>