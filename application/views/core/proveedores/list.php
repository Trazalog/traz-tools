<!-- ______ TABLA PRINCIPAL DE PANTALLA ______ -->
<table id="tabla_proveedores" class="table table-bordered table-striped">
    <thead class="thead-dark" bgcolor="#eeeeee">
        <th>Acciones</th>
        <th>Nombre</th>
        <th>CUIT</th>
        <th>Domicilio</th>
        <th>Localidad</th>
        <th>Estado</th>
        <th>País</th>
    </thead>
    <tbody >
        <?php
            if($listarProveedores) {
                foreach($listarProveedores as $proveedor) {
                    echo "<tr data-json='".json_encode($proveedor)."'>";
                        echo '<td>';
                            echo '                        
                            <button type="button" title="Eliminar" class="btn btn-primary btn-circle btnEliminar" data-toggle="modal" data-target="#modalEliminarProveedor" id="btnBorrar" ><span class="glyphicon glyphicon-trash" aria-hidden="true" ></span></button>&nbsp
                            <button type="button" title="Editar"  class="btn btn-primary btn-circle btnEditar" data-toggle="modal" data-target="#modalEditarProveedor" id="btnEditar" ><span class="glyphicon glyphicon-pencil" aria-hidden="true"></span></button>&nbsp
                            ';
                        echo '</td>';
                        echo '<td>'.$proveedor->titulo.'</td>';
                        echo '<td>'.$proveedor->cuit.'</td>';
                        echo '<td>'.$proveedor->domicilio.'</td>';
                        echo '<td>'.$proveedor->localidad.'</td>';
                        echo '<td>'.$proveedor->estado.'</td>';
                        echo '<td>'.$proveedor->pais.'</td>';
                    echo '</tr>';
                }
            }
        ?>
    </tbody>
</table>
<!--_______ FIN TABLA PRINCIPAL DE PANTALLA ______-->

<script>
    // Config Tabla de ProvelistarProveedores
    DataTable($('#tabla_proveedores'));

    // Levanta modal prevencion eliminar herramienta
    $(".btnEliminar").on("click", function() {
        $(".modal-header h4").remove();
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-times text-light-blue"></span> Eliminar Proveedor </h4>');
        datajson = $(this).parents("tr").attr("data-json");
        data = JSON.parse(datajson);
        var id = data.id;
        // guardo id en modal para usar en funcion eliminar
        $("#id_prov").val(id);
        //levanto modal
        $("#modalaviso").modal('show');
    });
    // Elimina herramienta
    function eliminarProveedor(){
        var id = $("#id_prov").val();
        wo();
        $.ajax({
            type: 'POST',
            data:{id: id},
            url: 'index.php/core/Proveedor/borrarProveedor',
            success: function(result) {
                $("#cargar_tabla").load("index.php/core/Proveedor/listarProveedores");
                setTimeout(function(){ 
                    alertify.success("Proveedor eliminado con éxito");
                    wc();
                    // alert("Hello"); 
                }, 3000);
                $("#modalaviso").modal('hide');
            },
            error: function(result){
                wc();
                $("#modalaviso").modal('hide');
                alertify.error('Error en eliminado de Proveedor...');
            }
        });
    }    

    // habilita botones, selects e inputs de modal
    // function habilitarEdicion(){
    //     $('.habilitar').removeAttr("readonly");//
    //     $("#pais_edit").removeAttr("disabled");
    //     $("#estado_edit").removeAttr("disabled");
    //     $("#localidad_edit").removeAttr("disabled");
    //     $('#btnsave_edit').show();
    // }

    // extrae datos de la tabla
    $(".btnEditar").on("click", function(e) {
        $(".modal-header h4").remove();
        //guardo el tipo de operacion en el modal
        $("#operacion").val("Edit");
        //pongo titlo al modal
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Editar Proveedor </h4>');
        data = $(this).parents("tr").attr("data-json");
        datajson = JSON.parse(data);
        // habilitarEdicion();
        // blockEdicion();
        llenarModal(datajson);
    });

    // llena modal para edicion
    function llenarModal(datajson){
        // creo los select de estado y localidad
        var $selectEstado = $("#estado_edit");
        var $selectLocalidad = $("#localidad_edit");
        // a esos select les guardo solamente los valores guardados previamente
        // var valor = $("#nombreLista").val();
        $selectEstado.append($("<option>", {
            value: datajson.estado_id,
            text: datajson.estado,
        }));
        $selectLocalidad.append($("<option>", {
            value: datajson.localidad_id,
            text: datajson.localidad,
        }));
        // selecciono en los select los id
        $("#estado_edit").val(datajson.estado_id);
        $("#localidad_edit").val(datajson.localidad_id);
        // deshabilitar los select de estado y localidad
        $("#estado_edit").prop('disabled', true);
        $("#localidad_edit").prop('disabled', true);
        $('#prov_id').val(datajson.id);
        //$('#pano_id').val(datajson.pano_id);
        $('#nombre_edit').val(datajson.titulo);
        $('#cuit_edit').val(datajson.cuit);
        $('#domicilio_edit').val(datajson.domicilio);
        $('#telefono_edit').val(datajson.telefono);
        $('#email_edit').val(datajson.email);
        $('#pais_edit option[value="'+ datajson.pais_id +'"]').attr("selected",true);
        // $('#estado_edit option[value="'+ datajson.id_estado +'"]').attr("selected",true);
        // $('#localidad_edit option[value="'+ datajson.localidad_id +'"]').attr("selected",true);
    }
    
    $(".btnDepositos").on("click", function(e) {
    $("#modaldepositos td").remove();
    $(".modal-header h4").remove();
    //guardo el tipo de operacion en el modal
    $("#operacion").val("Depositos");
    //pongo titlo al modal
    $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Depósitos del Proveedor </h4>');
    datajson = $(this).parents("tr").attr("data-json");
    data = JSON.parse(datajson);
    var id = data.id;
    // guardo id en modal para usar en funcion agregar deposito
    $("#id_prov").val(id);
    $.ajax({
        type: 'GET',
        url: 'index.php/core/Proveedor/listarDepositosXProveedor?id='+id,
        success: function(result) {
          if (result) {
            var tabla = $('#modaldepositos table');    
            $(tabla).find('tbody').html('');
            result.forEach(e => {
                $(tabla).append(
                  "<tr data-json= ' "+ JSON.stringify(e) +" '>" +
                    "<td><button type='button' title='Eliminar Artículo' class='btn btn-primary btn-circle btnEliminar' onclick='eliminarDeposito(this)' id='btnBorrar'><span class='glyphicon glyphicon-trash' aria-hidden='true' ></span></button>" +
                    "<td>" + e.descripcion + "</td>" +
                  "</tr>"
                );
            });            
          };
          $('#modaldepositos').modal('show'); 
        },
        error: function(result) {
            alert('Error');
        },
        dataType: 'json'
    });
    //levanto modal
    // $("#modaldepositos").modal('show');
  });

    // function guardarEdicionProveedor() {
    //     if( !validarCampos('formEdicionProveedor') ){
    //         return;
    //     }
    //     var recurso = "";
    //     var form = $('#formEdicionProveedor')[0];
    //     var datos = new FormData(form);
    //     var datos = formToObject(datos);
    // }
</script>

<!-- MODAL AVISO ELIMINAR PROVEEDOR -->
<div class="modal fade" id="modalEliminarProveedor">
    <div class="modal-dialog" role="document">
      <div class="modal-content">
        <div class="modal-header bg-blue">
          <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
          <h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-trash text-light-blue"></span> Eliminar Cliente</h4>
        </div>
        <div class="modal-body">
          <div class="row">
            <div class="col-xs-12">
              <h4>¿Desea realmente eliminar el Proveedor?</h4>
              <input type="text" id="id_prov" class="hidden">
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button>
          <button type="button" class="btn btn-primary" data-dismiss="modal" onclick="eliminarProveedor()">Aceptar</button>
        </div>
      </div>
    </div>
</div>
<!-- /  MODAL AVISO ELIMINAR PROVEEDOR -->