<style>
    .accionesDepositos{
        width: 20%;
        text-align: center;
    }
</style>
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
                            <select onchange="seleccionPais()" class="form-control select2 select2-hidden-accesible" name="pais" id="pais" style='width: 100%;'>
                                <option value="" disabled selected>-Seleccione país-</option>	
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
                            <label for="estado">Estado:</label><br>
                            <select onchange="seleccionEstado()" class="form-control select2 select2-hidden-accesible habilitar" name="estado" id="estado" style='width: 100%;'>
                                <option value="" disabled selected>-Seleccione estado-</option>	
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
                            <label for="localidad">Localidad:</label><br>
                            <select class="form-control select2 select2-hidden-accesible habilitar" name="localidad" id="localidad" style='width: 100%;'>
                                <option value="" disabled selected>-Seleccione localidad-</option>	
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
                            <select onchange="seleccionPaisEditar()" class="form-control select2 select2-hidden-accesible" name="pais" id="pais_edit" style="width: 100%;">
                                <option value="" disabled selected>-Seleccione país-</option>	
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
                            <select onchange="seleccionEstadoEditar()" class="form-control select2 select2-hidden-accesible habilitar" name="estado" id="estado_edit" style="width: 100%;">
                                <option value="" disabled selected>-Seleccione estado-</option>	
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
                            <select class="form-control select2 select2-hidden-accesible habilitar" name="localidad" id="localidad_edit" style="width: 100%;">
                                <option value="" disabled selected>-Seleccione localidad-</option>	
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
                  <th>Encargados</th>
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
<div class="modal modal-fade" id="modalAgregarDeposito" tabindex="-1" role="dialog" aria-labelledby="myLargeModalLabel">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header bg-blue">
                <button type="button" class="close close_modal_edit" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true" style="color:white;">&times;</span>
                </button>
            </div>
            <form class="frmDeposito" id="frmDeposito">
                <div class="modal-body">
                    <div class="row">
                        <input type="text" class="form-control habilitar hidden" name="esta_id" id="establecimiento_id">
                        <!-- Nombre -->
                        <div class="col-md-6 col-sm-6 col-xs-6">
                            <div class="form-group">
                                <label for="nombreDeposito">Nombre(<strong style="color: #dd4b39">*</strong>):</label>
                                <input type="text" class="form-control requerido" name="nombreDeposito" id="depoNombre" placeholder="Ingrese nombre...">
                            </div>
                        </div>
                        <!--________________-->
                        <!-- Establecimiento Asociado -->
                        <div class="col-md-6 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="estaDepositoModal">Establecimiento Asociado(<strong style="color: #dd4b39">*</strong>):</label>
                                <input type="text" class="form-control" id="estaDepositoModal" disabled>
                            </div>
                        </div>
                        <!--________________-->
                    </div>
                    <div class="row">
                        <!-- Depósito -->
                        <div class="col-md-12 col-sm-12 col-xs-12">
                            <div class="form-group">
                                <label for="deposito">Descripción(<strong style="color: #dd4b39">*</strong>):</label>
                                <textarea class="form-control requerido" name="descripcion" id="deposito" placeholder="Ingrese descripción..."></textarea>
                            </div>
                        </div>
                        <!--________________-->
                    </div>
                    <div class="row">
                        <!-- Encargados -->
                        <div class="col-md-12 col-sm-12 col-xs-12 ocultar">
                            <div class="form-group">
                                <label for="encargadosDeposito">Encargados(<strong style="color: #dd4b39">*</strong>):</label>
                                <select class="form-control select2 select2-hidden-accesible requerido" name="encargadosDeposito" id="encargadosDeposito" required style="width: 100%;" multiple>
                                    <?php
                                    if(!empty($listarEncargados)){
                                        foreach ($listarEncargados->usuarios->usuario as $users) {
                                            echo "<option data-json='".json_encode($users)."' value='".$users->id."'>".$users->first_name." ".$users->last_name."</option>";
                                        }
                                    }
                                    ?>
                                </select>
                            </div>
                        </div>
                        <!--____________-->
                    </div>
                </div>
                <div class="modal-footer">
                    <div class="form-group text-right">
                        <button type="" class="btn btn-primary habilitar" data-dismiss="modal" id="btnsave_edit" onclick="guardarDeposito(this)">Guardar</button>
                        <button type="" class="btn btn-default cerrarModalEdit" id="" data-dismiss="modal">Cerrar</button>
                    </div>
                </div>
            </form>
        </div>
    </div>
</div>
<!---///////--- FIN MODAL AGREGAR DEPOSITO ---///////--->

<!---///////--- MODAL EDITAR DEPOSITO ---///////--->
<div class="modal modal-fade" id="modalEditarDeposito" tabindex="-1" role="dialog" aria-labelledby="myLargeModalLabel">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header bg-blue">
                <button type="button" class="close close_modal_edit" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true" style="color:white;">&times;</span>
                </button>
            </div>
            <form class="frmDepositoEditar" id="frmDepositoEditar">
                <div class="modal-body">
                    <input type="text" class="form-control habilitar hidden" name="depo_id" id="depo_idEdit">
                    <input type="text" class="form-control habilitar hidden" name="esta_id" id="establecimiento_idEdit">
                    <div class="row">
                        <!-- Nombre -->
                        <div class="col-md-6 col-sm-6 col-xs-6">
                            <div class="form-group">
                                <label for="nombreDeposito">Nombre(<strong style="color: #dd4b39">*</strong>):</label>
                                <input type="text" class="form-control requerido" name="nombreDeposito" id="depoNombreEdit" placeholder="Ingrese nombre...">
                            </div>
                        </div>
                        <!--________________-->
                        <!-- Establecimiento Asociado -->
                        <div class="col-md-6 col-sm-6 col-xs-12">
                            <div class="form-group">
                                <label for="estaDepositoModal">Establecimiento Asociado(<strong style="color: #dd4b39">*</strong>):</label>
                                <input type="text" class="form-control" id="estaDepositoEdit" disabled>
                            </div>
                        </div>
                        <!--________________-->
                    </div>
                    <div class="row">
                        <!-- Descripción -->
                        <div class="col-md-12 col-sm-12 col-xs-12">
                            <div class="form-group">
                                <label for="deposito">Descripción(<strong style="color: #dd4b39">*</strong>):</label>
                                <textarea type="text" class="form-control requerido" name="descripcion" id="depositoEdit"></textarea>
                            </div>
                        </div>
                        <!--________________-->
                    </div>
                    <div class="row">
                        <!-- Encargados -->
                        <div class="col-md-12 col-sm-12 col-xs-12 ocultar">
                            <div class="form-group">
                                <label for="encargadosDeposito">Encargados(<strong style="color: #dd4b39">*</strong>):</label>
                                <select class="form-control select2 select2-hidden-accesible requerido" name="encargadosDeposito" id="encargadosDepositoEdit" required style="width: 100%;" multiple>
                                    <?php
                                    if(!empty($listarEncargados)){
                                        foreach ($listarEncargados->usuarios->usuario as $users) {
                                            echo "<option data-json='".json_encode($users)."' value='".$users->id."'>".$users->first_name." ".$users->last_name."</option>";
                                        }
                                    }
                                    ?>
                                </select>
                            </div>
                        </div>
                        <!--____________-->
                    </div>
                </div>
                <div class="modal-footer">
                    <div class="form-group text-right">
                        <button type="" class="btn btn-primary habilitar" data-dismiss="modal" id="btnsave_edit_deposito" onclick="guardarDeposito(this)">Editar</button>
                        <button type="" class="btn btn-default cerrarModalEdit" id="" data-dismiss="modal">Cerrar</button>
                    </div>
                </div>
            </form>
        </div>
    </div>
</div>
<!---///////--- FIN MODAL EDITAR DEPOSITO ---///////--->

<!---///////--- MODAL LISTADO PAÑOLES ---///////--->
<div class="modal fade bs-example-modal-lg" id="modalpanoles" tabindex="-1" role="dialog" aria-labelledby="myLargeModalLabel">
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
            <button class="btn btn-block btn-primary" style="width: 100px; margin-top: 10px;" onclick="agregarPanol()">Agregar</button>
              <table id="tabla_panoles" class="table table-bordered table-striped">
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
<!---///////--- FIN MODAL LISTADO PAÑOLES ---///////--->

<!---///////--- MODAL AGREGAR PAÑOL ---///////--->
<div class="modal fade bs-example-modal-lg" id="modalAgregarPanol" tabindex="-1" role="dialog" aria-labelledby="myLargeModalLabel">
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
              <form class="frmPanol" id="frmPanol">
                <div class="col-sm-12">
                    <input type="hidden" name="esta_id" id="establecimiento_id_panol">
                    <!-- Nombre -->
                    <div class="col-md-5 col-sm-5 col-xs-12">
                        <div class="form-group">
                            <label for="nombre">Nombre(<strong style="color: #dd4b39">*</strong>):</label>
                            <input type="text" class="form-control requerido" name="nombre" id="nombre" placeholder="Ingrese Nombre...">
                        </div>
                    </div>
                    <!--________________-->

                    <!-- Encargados -->
                    <div class="col-md-6 col-sm-6 col-xs-12 ocultar" style="margin-left: 5%;">
                        <div class="form-group">
                            <label for="encargados">Encargados(<strong style="color: #dd4b39">*</strong>):</label>
                            <select class="form-control select2 select2-hidden-accesible requerido" name="encargados" id="encargados" required style="width: 100%;" multiple>
                                <?php
                                if(!empty($listarEncargados)){
                                    foreach ($listarEncargados->usuarios->usuario as $users) {
                                        echo "<option data-json='".json_encode($users)."' value='".$users->id."'>".$users->first_name." ".$users->last_name."</option>";
                                    }
                                }
                                ?>
                            </select>
                        </div>
                    </div>
                    <!--____________-->
                </div>
                <!--Descripcion-->
                <div class="col-sm-12">
                    <div class="col-md-12 col-sm-12 col-xs-12">
                        <div class="form-group">
                        <label for="Descripcion">Descripción:</label>
                            <textarea class="form-control" name="descripcion" id="descripcion" rows="3" placeholder="Ingrese Observaciones..."></textarea>
                        </div>
                    </div>
                </div>
                <!--________________-->
              </form>
            </div>
          </div>
      </div>
      <div class="modal-footer">
          <div class="form-group text-right">
              <button type="" class="btn btn-primary habilitar" data-dismiss="modal" id="btnsave_edit" onclick="guardarPanol()">Guardar</button>
              <button type="" class="btn btn-default cerrarModalEdit" id="" data-dismiss="modal">Cerrar</button>
          </div>
      </div>
    </div>
  </div>
</div>
<!---///////--- FIN MODAL AGREGAR PAÑOL ---///////--->

<script>
    $(document).ready(function () {
        $(".select2").select2();
    });
    // carga tabla de establecimientos
    $("#cargar_tabla").load("index.php/core/Establecimiento/listarEstablecimientos");

    // habilita botones, selects e inputs de modal
    function habilitarEdicion(){
      $('.habilitar').removeAttr("disabled");
    }

    function blockEdicion(){
      $(".habilitar").attr("disabled","disabled");
    }

    $("#botonEstablecimiento").on("click", function() {
        $(".modal-header h4").remove();
        //guardo el tipo de operacion en el modal
        $("#operacion").val("Edit");
        //pongo titlo al modal
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Nuevo Establecimiento</h4>');
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
            url: 'index.php/core/Establecimiento/getEstados',
            success: function(rsp) {
                $('#estado').empty();
                $('#localidad').empty();
                if (rsp != null) {
                    // habilitarEdicion();
                    var datos = "<option value='' disabled selected>-Seleccione opción-</option>";
                    $('#localidad').html(datos);
                    for (let i = 0; i < rsp.length; i++) {
                        var datito = encodeURIComponent(rsp[i].tabl_id);
                        datos += "<option value=" + datito + ">" + rsp[i].valor + "</option>";
                    }
                    $('#estado').html(datos);
                } else {
                    var datos = "<option value='' disabled selected>-Seleccione opción-</option>";
                    $('#estado').html(datos);
                    $('#localidad').html(datos);                   
                    alertify.error("El País no contiene estados");
                }    
                wc();
            },
            error: function(data) {
                alert('Error');
                wc();
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
            url: 'index.php/core/Establecimiento/getEstados',
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
            url: 'index.php/core/Establecimiento/getLocalidades',
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
        if (!ban) 
    	Swal.fire(
            'Error...',
            'Debes completar los campos Obligatorios (*)',
            'error'
        );
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
                if(result.status) {
                    $("#cargar_tabla").load("index.php/core/Establecimiento/listarEstablecimientos");
                    $("#modalEstablecimiento").modal('hide');
                    form.reset();
                    alertify.success("Establecimiento agregado con éxito");
                wc();
                } else {
                    alertify.error("Error agregando Establecimiento");    
                }
            },
            error: function(result){
                wc();
                alertify.error("Error agregando Establecimiento");
            }            
        });
    }

    function guardarEdicionEstablecimiento() {
        if( !validarCampos('formEdicionEstablecimiento') ){
            return;
        }
        var estado = $("#estado_edit option:selected").val();
        var localidad = $("#localidad_edit option:selected").val();
        var recurso = "";
        var form = $('#formEdicionEstablecimiento')[0];
        var datos = new FormData(form);
        var datos = formToObject(datos);
        recurso = 'index.php/core/Establecimiento/guardarEdicionEstablecimiento';
        wo();
        $.ajax({
            type: 'POST',
            data:{ datos, estado, localidad },
            dataType: 'JSON',
            url: recurso,
            success: function(result) {
                if(result.status) {
                    $("#cargar_tabla").load("index.php/core/Establecimiento/listarEstablecimientos");
                    $("#modalEstablecimiento").modal('hide');
                    form.reset();
                    // $("#botonAgregar").removeAttr("disabled");
                    alertify.success("Establecimiento actualizado con éxito");
                wc();
                } else {
                    alertify.error("Error actualizando Establecimiento");    
                }
            },
            error: function(result){
                wc();
                alertify.error("Error actualizando Establecimiento");    
            }            
        });
    }

    function agregarDeposito(tag) {
        var form = $('#frmDeposito')[0];
        form.reset();
        $("#estaDepositoModal").val($("#establecimientoDeposito").text());
        $(".modal-header h4").remove();
        //guardo el tipo de operacion en el modal
        $("#operacion").val("Edit");
        //pongo titulo al modal
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Agregar Depósito</h4>');
        $("#modaldepositos").modal('hide');
        $('#modalAgregarDeposito').modal('show');
        // guardo esta_id en modal para usar en funcion agregar deposito
        var esta_id = $("#id_esta").val();
        $("#establecimiento_id").val(esta_id);
    }

    function guardarDeposito (tag) {
        var idForm = $(tag).closest("form").attr('id');
        if( !validarCampos(idForm) ){
            return;
        }
        var recurso = "";
        var form = $('#'+idForm)[0];
        var datos = new FormData(form);
        var datos = formToObject(datos);
        if(idForm == 'frmDeposito'){
            recurso = 'index.php/core/Establecimiento/guardarDeposito';
        }else{
            recurso = 'index.php/core/Establecimiento/editarDeposito';
        }
        wo();
        $.ajax({
        type: 'POST',
        data:{ datos },
        dataType: 'JSON',
        url: recurso,
        success: function(result) {
            if(result.deposito.status && result.encargados.status){
                $("#cargar_tabla").load("index.php/core/Establecimiento/listarEstablecimientos",() => {
                    wc();
                    hecho();
                    $("#modalAgregarDeposito").hide(500);
                });
            }else{
                wc();
                if(!result.deposito.status){
                    alertify.error(result.deposito.msj);
                }
                if(!result.encargados.status){
                    alertify.error(result.encargados.msj);
                }
            }
        },
        error: function(result){
            wc();
            alertify.error("Error agregando depósito");
        },
        complete: function(){
            $('#encargadosDeposito').val(null).trigger('change');
        }
        });
    }

    function eliminarDeposito(e) {
        var data = JSON.parse($(e).closest('tr').attr('data-json'));
        var depo_id = data.depo_id;
        // var esta_id = data.esta_id;
        $('#depo_id').val(data.depo_id);
        // var esta_id = $("#id_esta").val();
        // var esta_id = $("#establecimiento_id").val();
        // $("#id_establecimiento_borrar").val(esta_id);
        /* $(".modal-header h4").remove();
        //pongo titulo al modal
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Eliminar Depósito </h4>');
        $("#modaldepositos").modal('hide');
        $('#modalAvisoDeposito').modal('show'); */
        Swal.fire({
              title: '¿Realmente desea ELIMINAR el depósito del Establecimiento?',
              text: "No podras revertir la acción!",
              type: 'question',
              showCancelButton: true,
              confirmButtonColor: '#3085d6',
              cancelButtonColor: '#d33',
              confirmButtonText: 'Si, Eliminar!'
            }).then((result) => {
            	if (result.value) {
                eliminarDepositoDeEstablecimiento();                
              }else if (result.dismiss) {
                    Swal.fire('Cancelado', '', 'error')
                }
        })

    }

    function eliminarDepositoDeEstablecimiento() {
        var depo_id = $("#depo_id").val();
        // var esta_id = $("#id_esta").val();
        // var esta_id = $("#id_establecimiento_borrar").val();
        wo();
        $.ajax({
            type: 'POST',
            data:{depo_id: depo_id},
            url: 'index.php/core/Establecimiento/borrarDepositoDeEstablecimiento',
            success: function(result) {
                wc();
                //$("#cargar_tabla").load("index.php/core/Establecimiento/listarEstablecimientos");
                Swal.fire({
                      title: "Hecho",
                      text: "Depósito eliminado!",
                      type: "success",
                      showCancelButton: false,
                      confirmButtonColor: "#3085d6",
                      confirmButtonText: "OK",
                  }).then((result) => {
                      if (result.value) {
                        $("#modaldepositos").modal('hide');
                      }
                  });
                },
                error: function(result){
                wc();
                alertify.error('Error en eliminado de Depósito...');
            }
        });        
    }

    // MODULOS DE PAÑOLES

    function agregarPanol() {
        var form = $('#frmPanol')[0];
        form.reset();
        $(".modal-header h4").remove();
        //guardo el tipo de operacion en el modal
        $("#operacion").val("add");
        //pongo titulo al modal
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Agregar Pañol</h4>');
        $("#modalpanoles").modal('hide');
        $('#modalAgregarPanol').modal('show');
        // guardo esta_id en modal para usar en funcion agregar panol
        var esta_id2 = $("#id_esta").val();
        $("#establecimiento_id_panol").val(esta_id2);
    }

    function guardarPanol () {
        if( !validarCampos('frmPanol') ){
            $("#modalpanoles").modal('show');
            return;
        }
        var recurso = "";
        var form = $('#frmPanol')[0];
        var datos = new FormData(form);
        var data = formToObject(datos);
        
        recurso = 'index.php/core/Establecimiento/guardarPanol';
        wo();
        $.ajax({
            type: 'POST',
            data: {data},
            dataType: 'JSON',
            url: recurso,
            success: function(result) {
                wc();
                if(result.panol.status && result.encargados.status){
                    hecho();
                    $("#cargar_tabla").load("index.php/core/Establecimiento/listarEstablecimientos");
                }else{
                    if(!result.panol.status){
                        error('',result.panol.msj);
                    }
                    if(!result.encargados.status){
                        error('',result.encargados.msj);
                    }
                }
                $("#modalAgregarPanol").hide(500);
                // form.reset();
            },
            error: function(result){
                wc();
                alertify.error("Error agregando Depósito");
            },
            complete: function(){
                $('#encargados').val(null).trigger('change');
            }
        });
    }

    function eliminarPanol(e) {
        var data = JSON.parse($(e).closest('tr').attr('data-json'));
        var panol_id = data.pano_id;
        // var esta_id = data.esta_id;
        $('#panol_id').val(data.pano_id);
        // var esta_id = $("#id_esta").val();
        // var esta_id = $("#establecimiento_id").val();
        // $("#id_establecimiento_borrar").val(esta_id);
        $(".modal-header h4").remove();
        //pongo titulo al modal
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Eliminar Pañol </h4>');
        $("#modalpanoles").modal('hide');
        $('#modalAvisoPanol').modal('show');
    }

    function eliminarPanolDeEstablecimiento() {
        var panol_id = $("#panol_id").val();
        // var esta_id = $("#id_esta").val();
        // var esta_id = $("#id_establecimiento_borrar").val();
        wo();
        $.ajax({
            type: 'POST',
            data:{panol_id: panol_id},
            url: 'index.php/core/Establecimiento/borrarPanolDeEstablecimiento',
            success: function(result) {
            $("#cargar_tabla").load("index.php/core/Establecimiento/listarEstablecimientos");
            setTimeout(function(){ 
                alertify.success("Pañol eliminado con éxito");
                wc();
                // alert("Hello"); 
            }, 3000);
            $("#modalAvisoPanol").modal('hide');
            },
            error: function(result){
            wc();
            $("#modalAvisoPanol").modal('hide');
            alertify.error('Error al Eliminar Pañol...');
            }
        });        
    }    
    function editarDeposito(tag) {
        var form = $('#frmDepositoEditar')[0];
        form.reset();
        $("#estaDepositoEdit").val($("#establecimientoDeposito").text());
        $(".modal-header h4").remove();
        //pongo titulo al modal
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Editar Depósito</h4>');
        $("#modaldepositos").modal('hide');
        $('#modalEditarDeposito').modal('show');
        var data =	JSON.parse($(tag).closest('tr').attr('data-json'));
        $('#depositoEdit').val(data.descripcion);
        $('#depo_idEdit').val(data.depo_id);
        $('#depoNombreEdit').val(data.nombre);
        $('#establecimiento_idEdit').val($("#id_esta").val());
        encargados = [];
        data.encargados.encargado.forEach(x => {
            encargados.push(x.user_id);
        });
        $('#encargadosDepositoEdit').val(encargados);
        $('#encargadosDepositoEdit').trigger('change');
        $('#depositoEdit').attr('readonly',false);
        $('#depo_idEdit').attr('readonly',false);
        $('#encargadosDepositoEdit').attr('disabled',false);
        $('#btnsave_edit_deposito').show();
    }
    function detalleDeposito(tag) {
        var form = $('#frmDepositoEditar')[0];
        form.reset();
        $(".modal-header h4").remove();
        //pongo titulo al modal
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Detalle Depósito</h4>');
        $("#modaldepositos").modal('hide');
        $('#modalEditarDeposito').modal('show');
        var data =	JSON.parse($(tag).closest('tr').attr('data-json'));
        $('#depositoEdit').val(data.descripcion);
        $('#depositoEdit').attr('readonly','readonly');
        $('#depo_idEdit').val(data.depo_id);
        $('#depo_idEdit').attr('readonly','readonly');
        $('#establecimiento_idEdit').val($("#id_esta").val());
        encargados = [];
        data.encargados.encargado.forEach(x => {
            encargados.push(x.user_id);
        });
        $('#encargadosDepositoEdit').val(encargados);
        $('#encargadosDepositoEdit').trigger('change');
        $('#encargadosDepositoEdit').attr('disabled','disabled');
        $('#btnsave_edit_deposito').hide();
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
              <h4>¿Desea realmente eliminar el depósito del establecimiento?</h4>
              <input type="text" id="depo_id" class="hidden">
              <!-- <input type="text" id="id_establecimiento_borrar" class="hidden"> -->
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button>
          <button type="button" class="btn btn-primary" data-dismiss="modal" onclick="eliminarDepositoDeEstablecimiento()">Aceptar</button>
        </div>
      </div>
    </div>
</div>
<!-- /  Modal aviso eliminar deposito-->

<!-- Modal aviso eliminar pañol-->
<div class="modal fade" id="modalAvisoPanol">
    <div class="modal-dialog" role="document">
      <div class="modal-content">
        <div class="modal-header bg-blue">
          <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
          <h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-trash text-light-blue"></span> Eliminar Pañol</h4>
        </div>
        <div class="modal-body">
          <div class="row">
            <div class="col-xs-12">
              <h4>¿Desea realmente eliminar el pañol del establecimiento?</h4>
              <input type="text" id="panol_id" class="hidden">
              <!-- <input type="text" id="id_establecimiento_borrar" class="hidden"> -->
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button>
          <button type="button" class="btn btn-primary" data-dismiss="modal" onclick="eliminarPanolDeEstablecimiento()">Aceptar</button>
        </div>
      </div>
    </div>
</div>
<!-- /  Modal aviso eliminar pañol-->