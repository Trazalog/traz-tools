<!-- /// ---- HEADER ----- /// -->
<div class="box box-primary animated fadeInLeft">
    <div class="box-header with-border">
        <h4>Lista de Valores</h4>
    </div>
    <div class="box-body">
        <div class="row">
            <div class="col-md-3">
                <!-- <input type="text" class="form-control habilitar hidden" name="empresa" id="empresa"> -->
                <select onchange="seleccionTabla(this)" type="text" id="selectTabla" name="selectTabla" class="form-control" >
                    <option value="-1" disabled selected>-Seleccione opción-</option>
                    <?php
                        foreach ($listarValores as $valor) {
                            echo '<option  value="'.$valor->tabla.'">'.$valor->tabla.'</option>';
                        }
                    ?>
                </select>
                <br>
                <button type="button" id="botonAgregar" class="btn btn-primary" aria-label="Left Align">
                    Agregar
                </button><br>
            </div>
            <div class="col-md-10 col-lg-11 col-xs-12"></div>
        </div>
    </div>
</div>
<!-- /// ----- HEADER -----/// -->

<!--_______ FORMULARIO LISTA DE VALORES______-->
<div class="box box-primary animated bounceInDown" id="boxDatos" hidden>
    <div class="box-header with-border">
        <div class="box-tittle">
            <h4>Nueva Lista</h4>
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
            <!--Empresa-->
            <?php 
            $usuario = $this->session->userdata();
            if ($usuario['email'] == TOOLS_ADMIN_USER) {                
            ?>
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="localidad">Empresa:</label>
                    <select class="form-control select2 select2-hidden-accesible habilitar" name="empresaLista" id="empresaLista">
                        <option value="" disabled selected>-Seleccione opción-</option>	
                        <option value="999999">Todas las empresas</option>	
                        <?php
                            foreach ($listarEmpresas as $empresa) {
                            echo '<option  value="'.$empresa->empr_id.'">'.$empresa->descripcion.'</option>';
                            }
                        ?>
                    </select>
                </div>
            </div>
            <?php 
            }
            ?>
        </form>
    </div>
    <!--_________________ GUARDAR_________________-->
    <div class="modal-footer">
        <div class="form-group text-right">
            <button type="button" class="btn btn-primary" onclick="agregarLista()" >Confirmar</button>
        </div>
    </div>
    <!--__________________________________-->
</div>
<!--_______ FIN FORMULARIO LISTA DE VALORES ______-->

<!---/////---BOX 2 DATATABLE VALORES---/////----->
<div class="box box-primary">
    <div class="box-body">
        <div class="col-md-3">
            <h4 style="float:left;">Valores</h4>
            <button type="button" id="agregarValor" class="btn btn-primary" data-toggle="modal" data-target="#modalvalor" aria-label="Left Align" style="float: right">
                Agregar valor
            </button><br>
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
<!---/////--- FIN BOX 2 DATATABLE VALORES---//////----->

<!---///////--- MODAL NUEVO VALOR ---///////--->
<div class="modal fade bs-example-modal-lg" id="modalvalor" tabindex="-1" role="dialog" aria-labelledby="myLargeModalLabel">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header bg-blue">
                <button type="button" class="close close_modal_edit" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true" style="color:white;">&times;</span>
                </button>
            </div>
            <div class="modal-body ">
                <form class="" id="formValores">
                    <div class="form-horizontal">
                        <div class="row">
                        <!-- <form class="frmValor" id="frmValor"> -->
                            <input type="text" class="form-control habilitar hidden" name="tabla" id="tabla">
                            <input type="text" class="form-control habilitar hidden" name="empr_id" id="empr_id">
                            <div class="col-sm-6">
                            <!--_____________ DESCRIPCION _____________-->
                                <div class="form-group">
                                    <label for="descri_edit" class="col-sm-4 control-label">Descripción(<strong style="color: #dd4b39">*</strong>):</label>
                                    <div class="col-sm-8">
                                        <input type="text" class="form-control requerido" name="descripcion" id="descripcion" required>
                                    </div>
                                </div>
                            <!--___________________________-->
                            <!--_____________ VALOR 1 _____________-->
                                <div class="form-group">
                                    <label for="valor1_edit" class="col-sm-4 control-label">Valor 1(<strong style="color: #dd4b39">*</strong>):</label>
                                    <div class="col-sm-8">
                                        <input type="text" class="form-control requerido" name="valor" id="valor">
                                    </div>
                                </div>
                            <!--__________________________-->
                            <!--_____________ VALOR 2 _____________-->
                                <div class="form-group">
                                    <label for="valor2_edit" class="col-sm-4 control-label">Valor 2:</label>
                                    <div class="col-sm-8">
                                        <input type="text" class="form-control" name="valor2" id="valor2">
                                    </div>
                                </div>
                            <!--__________________________-->
                            <!--_____________ VALOR 3 _____________-->
                                <div class="form-group">
                                    <label for="valor3_edit" class="col-sm-4 control-label">Valor 3:</label>
                                    <div class="col-sm-8">
                                        <input type="text" class="form-control" name="valor3" id="valor3">
                                    </div>
                                </div>
                            <!--__________________________-->
                            </div>
                        <!-- </form> -->
                        </div>
                    </div>
                </form>
            </div>
            <div class="modal-footer">
                <div class="form-group text-right">
                    <button type="" class="btn btn-primary habilitar" data-dismiss="modal" id="btnsave_edit" onclick="guardarValor()">Guardar</button>
                    <button type="" class="btn btn-default cerrarModalEdit" id="" onclick="cerrar()" data-dismiss="modal">Cerrar</button>
                </div>
            </div>
        </div>
    </div>
</div>
<!---///////--- FIN MODAL NUEVO VALOR ---///////--->

<!---///////--- MODAL EDICION VALOR ---///////--->
<div class="modal fade bs-example-modal-lg" id="modalEditarValor" tabindex="-1" role="dialog" aria-labelledby="myLargeModalLabel">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header bg-blue">
                <button type="button" class="close close_modal_edit" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true" style="color:white;">&times;</span>
                </button>
            </div>
            <div class="modal-body ">
                <form class="formEditarValores" id="formEditarValores">
                    <div class="form-horizontal">
                        <div class="row">
                        <!-- <form class="frmValor" id="frmValor"> -->
                            <input type="text" class="form-control habilitar hidden" name="tabl_id" id="tabl_id_edit">
                            <div class="col-sm-6">
                            <!--_____________ DESCRIPCION _____________-->
                                <div class="form-group">
                                    <label for="descri_edit" class="col-sm-4 control-label">Descripción(<strong style="color: #dd4b39">*</strong>):</label>
                                    <div class="col-sm-8">
                                        <input type="text" class="form-control requerido" name="descripcion" id="descripcion_edit">
                                    </div>
                                </div>
                            <!--___________________________-->
                            <!--_____________ VALOR 1 _____________-->
                                <div class="form-group">
                                    <label for="valor1_edit" class="col-sm-4 control-label">Valor 1(<strong style="color: #dd4b39">*</strong>):</label>
                                    <div class="col-sm-8">
                                        <input type="text" class="form-control requerido" name="valor" id="valor_edit">
                                    </div>
                                </div>
                            <!--__________________________-->
                            <!--_____________ VALOR 2 _____________-->
                                <div class="form-group">
                                    <label for="valor2_edit" class="col-sm-4 control-label">Valor 2:</label>
                                    <div class="col-sm-8">
                                        <input type="text" class="form-control" name="valor2" id="valor2_edit">
                                    </div>
                                </div>
                            <!--__________________________-->
                            <!--_____________ VALOR 3 _____________-->
                                <div class="form-group">
                                    <label for="valor3_edit" class="col-sm-4 control-label">Valor 3:</label>
                                    <div class="col-sm-8">
                                        <input type="text" class="form-control" name="valor3" id="valor3_edit">
                                    </div>
                                </div>
                            <!--__________________________-->
                            </div>
                        <!-- </form> -->
                        </div>
                    </div>
                </form>
            </div>
            <div class="modal-footer">
                <div class="form-group text-right">
                    <button type="" class="btn btn-primary habilitar" data-dismiss="modal" id="btnsave_edit" onclick="editarValor('editar')">Guardar</button>
                    <button type="" class="btn btn-default cerrarModalEdit" id="" onclick="cerrar()" data-dismiss="modal">Cerrar</button>
                </div>
            </div>
        </div>
    </div>
</div>
<!---///////--- FIN MODAL EDICION VALOR ---///////--->

<script>
    // carga tabla genaral de clientes
    $("#cargar_tabla").load("index.php/core/Valor/Listar_Valores");

    // carga los depositos de acuerdo a establecimiento
	function seleccionTabla(opcion){
        var id_tabla = $("#selectTabla").val();
        wo();
        $.ajax({
            type: 'POST',
            dataType: "json",
            data: {id_tabla},
            url: 'index.php/core/Valor/getValor',
            success: function(result) {
                $("#tabla_valores tbody").empty(); 
                if(result){
                var tabla = $('#tabla_valores');    
                $(tabla).find('tbody').html('');
                result.forEach(e => {
                    $(tabla).append(
                    "<tr data-json= ' "+ JSON.stringify(e) +" '>" +
                        "<td><button type='button' title='Eliminar Artículo' class='btn btn-primary btn-circle btnEliminar' onclick='eliminarValor(this)' ><span class='glyphicon glyphicon-trash' aria-hidden='true' ></span></button>&nbsp<button type='button' title='Editar Artículo' class='btn btn-primary btn-circle btnEditar' onclick='editValor(this)' ><span class='glyphicon glyphicon-edit' aria-hidden='true' ></span></button>" +
                        "<td>" + e.descripcion + "</td>" +
                        "<td>" + e.valor + "</td>" +
                        "<td>" + e.valor2 + "</td>" +
                        "<td>" + e.valor3 + "</td>" +
                    "</tr>"
                    );                
                });
                }
            wc();
            },
            error: function(data) {
                alert('Error');
            }
        });
    }

    $("#botonAgregar").on("click", function() {
        $("#botonAgregar").attr("disabled", "");
        $("#boxDatos").focus();
        $("#boxDatos").show();
    });

    $("#agregarValor").on("click", function() {
        var id_tabla = $("#selectTabla").val();
        $("#tabla").val(id_tabla);
        $(".modal-header h4").remove();
        //guardo el tipo de operacion en el modal
        $("#operacion").val("Edit");
        //pongo titlo al modal
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Nuevo valor para '+ id_tabla +'</h4>');
    });
        
    function agregarLista(){
        var $select = $("#selectTabla");
        var empresa = <?= json_encode(empresa()) ?>;
        var valor = $("#nombreLista").val();
        var valor2 = $("#empresaLista").val();
        $("#empr_id").val(valor2);
        $select.append($("<option>", {
            value: valor,
            text: valor,
        }));
        $("#selectTabla").val(valor);
        $("#boxDatos").hide(500);
        $("#botonAgregar").removeAttr('disabled');
        $("#formLista")[0].reset();
    }

    function editValor(e) {
        var data = JSON.parse($(e).closest('tr').attr('data-json'));
        var tabl_id = data.tabl_id;
        $(".modal-header h4").remove();
        //guardo el tipo de operacion en el modal
        $("#operacion").val("Edit");
        //pongo titulo al modal
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Editar Valor para '+ tabl_id +'</h4>');
        $('#tabl_id_edit').val(data.tabl_id);
        $('#descripcion_edit').val(data.descripcion);
        $('#valor_edit').val(data.valor);
        $('#valor2_edit').val(data.valor2);
        $('#valor3_edit').val(data.valor3);
        $('#modalEditarValor').modal('show');
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
    
    function guardarValor() {
        if( !validarCampos('formValores') ){
            return;
        }
        var recurso = "";
        var form = $('#formValores')[0];
        var datos = new FormData(form);
        var datos = formToObject(datos);
        recurso = 'index.php/core/Valor/guardarValor';
        wo();
        $.ajax({
            type: 'POST',
            data:{ datos },
            url: recurso,
            success: function(result) {
                seleccionTabla(result);
                wc();
                $("#boxDatos").hide(500);
                form.reset();
                $("#botonAgregar").removeAttr("disabled");
                alertify.success("Valor agregado con éxito");
            },
            error: function(result){
                wc();
                alertify.error("Error agregando Valor");
            }            
        });
    }

    function editarValor(operacion) {
        if( !validarCampos('formEditarValores') ){
            return;
        }        
        var recurso = "";
        var form = $('#formEditarValores')[0];
        var datos = new FormData(form);
        var datos = formToObject(datos);
        recurso = 'index.php/core/Valor/editarValor';
        wo();
        $.ajax({
            type: 'POST',
            data:{ datos },
            url: recurso,
            success: function(result) {
                seleccionTabla(result);
                wc();
                $("#boxDatos").hide(500);
                form.reset();
                $("#botonAgregar").removeAttr("disabled");                
                if (operacion == "editar") {
                    alertify.success("Valor editado exitosamente");
                }else{
                    alertify.success("Valor agregado con éxito");
                }
            },
            error: function(result){
            wc();
            alertify.error("Error agregando Valor");
            }            
        });
    }

    function eliminarValor(e) {
        var data = JSON.parse($(e).closest('tr').attr('data-json'));
        var tabl_id = data.tabl_id;
        $('#tabl_id').val(data.tabl_id);
        $(".modal-header h4").remove();
        //pongo titulo al modal
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Eliminar Valor </h4>');
        $('#modalaviso').modal('show');
	}

    function eliminar() {
        var tabl_id = $("#tabl_id").val();
        wo();
        $.ajax({
            type: 'POST',
            data:{tabl_id: tabl_id},
            url: 'index.php/core/Valor/borrarValor',
            success: function(result) {
                seleccionTabla(tabl_id)
                wc();
                $("#modalaviso").modal('hide');
            },
            error: function(result){
            wc();
            $("#modalaviso").modal('hide');
            alertify.error('Error en eliminado de Valor...');
            }
        });        
    }

    function cerrar() {
        var form = $('#formValores')[0];
        form.reset();
    }

    function check(e) {
        tecla = (document.all) ? e.keyCode : e.which;
        //Tecla de retroceso para borrar, siempre la permite
        if (tecla == 8) {
            return true;
        }
        // Patron de entrada, en este caso solo acepta numeros y letras
        patron = /[A-Za-z0-9_]/;
        tecla_final = String.fromCharCode(tecla);
        return patron.test(tecla_final);
    }
    
</script>

<!-- MODAL AVISO ELIMINAR VALOR-->
<div class="modal fade" id="modalaviso">
  <div class="modal-dialog" role="document">
    <div class="modal-content">
      <div class="modal-header bg-blue">
        <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
        <h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-trash text-light-blue"></span> Eliminar Valor</h4>
      </div>
      <div class="modal-body">
        <div class="row">
          <div class="col-xs-12">
            <h4>¿Desea realmente eliminar este Valor?</h4>
            <input type="text" id="tabl_id" class="hidden">
          </div>
        </div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button>
        <button type="button" class="btn btn-primary" data-dismiss="modal" onclick="eliminar()">Aceptar</button>
      </div>
    </div>
  </div>
</div>
<!--/ MODAL AVISO ELIMINAR VALOR-->