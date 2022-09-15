<!-- ______ TABLA PRINCIPAL DE PANTALLA ______ -->
<table id="tabla_clientes" class="table table-bordered table-striped">
		<thead class="thead-dark" bgcolor="#eeeeee">
      <th>Acciones</th>
      <th>Nombre</th>
      <th>Dir. entrega</th>
      <th>Observaciones</th>
      <th>Tipo cliente</th>
		</thead>
		<tbody >
			<?php
				if($list)
				{
					foreach($list as $value)
          {
            echo "<tr data-json='".json_encode($value)."'>";
            echo '<td>';
                echo '<button  type="button" title="Editar"  class="btn btn-primary btn-circle btnEditar" data-toggle="modal" data-target="#modaleditar" id="btnEditar"  ><span class="glyphicon glyphicon-pencil" aria-hidden="true"></span></button>&nbsp
                <button type="button" title="Info" class="btn btn-primary btn-circle btnInfo" data-toggle="modal" data-target="#modaleditar" ><span class="glyphicon glyphicon-info-sign" aria-hidden="true"></span></button>&nbsp
                <button type="button" title="Eliminar" class="btn btn-primary btn-circle btnEliminar" id="btnBorrar"  ><span class="glyphicon glyphicon-trash" aria-hidden="true" ></span></button>&nbsp';
            echo '</td>';
            echo '<td>'.$value->nombre.'</td>';
            echo '<td>'.$value->dir_entrega.'</td>';
            echo '<td>'.$value->observaciones.'</td>';
            echo '<td>'.$value->tipo_cliente.'</td>';
            echo '</tr>';
          }
				}
			?>
		</tbody>
</table>
<!--_______ FIN TABLA PRINCIPAL DE PANTALLA ______-->

<script>
  $(".btnEditar").on("click", function(e) {
      $(".modal-header h4").remove();
      //guardo el tipo de operacion en el modal
      $("#operacion").val("Edit");
      //pongo titulo al modal
      $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Editar Cliente </h4>');
      data = $(this).parents("tr").attr("data-json");
      datajson = JSON.parse(data);
      $("#btnsave_edit").show();
      habilitarEdicion();
      llenarModal(datajson);
  });
  // extrae datos de la tabla
  $(".btnInfo").on("click", function(e) {
      $(".modal-header h4").remove();
      //guardo el tipo de operacion en el modal
      $("#operacion").val("Info");
      //pongo titulo al modal
      $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Info Cliente </h4>');
      data = $(this).parents("tr").attr("data-json");
      datajson = JSON.parse(data);
      $("#btnsave_edit").hide();
      blockEdicion();
      llenarModal(datajson);
  });
  //cambia encabezado para agregar una herramienta
  $("#btnAdd").on("click", function(e) {
      $("#operacion").val("Add");
      $(".modal-header h4").remove();
      $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil text-light-blue"></span> Agregar Cliente </h4>');
      ///FIXME: LIMPIAR LOS CAMPOS Y SELECTS
  });
  // llena modal para edicion y muestra
  function llenarModal(datajson){
    $('#clie_id_edit').val(datajson.clie_id);
    $('#nombre_edit').val(datajson.nombre);
    $('#dir_entrega_edit').val(datajson.dir_entrega);
    $('#observaciones_edit').val(datajson.observaciones);
    // var $selectTipo = $("#ticl_id_edit");
    // // a ese select le guardo solamente el valor guardado previamente
    // $selectTipo.append($("<option>", {
    //     value: datajson.ticl_id,
    //     text: datajson.tipo_cliente,
    // }));
    // $('[name="tinc_id"]').val(json['tinc_id']);
    // $('#ticl_id_edit').val(datajson.tipo_cliente);
    // este de abajo si lo marca pero no selecciona al principio
    // $('#ticl_id_edit').val(datajson.ticl_id); 
    // $('[name="ticl_id_edit"]').val(datajson.ticl_id);
    // este de abajo tambien lo marca pero no selecciona al principio
    // $("#ticl_id_edit option[value="+ datajson.ticl_id +"]").attr("selected",true);
    // este de abajo tambien lo marca pero no selecciona al principio
    // $("#ticl_id_edit option[value="+ datajson.ticl_id +"]").prop("selected",true);
    // este de abajo tambien lo marca pero no selecciona al principio
    // $("#ticl_id_edit option[value="+ datajson.ticl_id +"]").prop('selected','selected');
    // $("#ticl_id_edit option").filter("[value=»" + datajson.ticl_id + "»]").prop("selected", "selected");
    // $('#ticl_id_edit > option[value=datajson.ticl_id]').attr('selected', 'selected');
  }
  // deshabilita botones, selects e inputs de modal
  function blockEdicion(){
    $(".habilitar").attr("readonly","readonly");
    $("#ticl_id_edit").prop('disabled', true);
  }
  // habilita botones, selects e inputs de modal
  function habilitarEdicion(){
    $('.habilitar').removeAttr("readonly");//
    $("#ticl_id_edit").prop('disabled', false);
  }
  // Levanta modal prevencion eliminar herramienta
  $(".btnEliminar").on("click", function() {
    $(".modal-header h4").remove();
    $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-times text-light-blue"></span> Eliminar Cliente </h4>');
    datajson = $(this).parents("tr").attr("data-json");
    data = JSON.parse(datajson);
    var clie_id = data.clie_id;
    // guardo clie_id en modal para usar en funcion eliminar
    $("#clie_id").val(clie_id);
    //levanto modal
    $("#modalaviso").modal('show');
  });

// Elimina Cliente
function eliminar(){
  var clie_id = $("#clie_id").val();
  wo();
  $.ajax({
    type: 'POST',
    data:{clie_id: clie_id},
    url: 'index.php/core/Cliente/Borrar_Cliente',
    success: function(result) {
      $("#cargar_tabla").load("index.php/core/Cliente/Listar_Clientes");
      wc();
      $("#modalaviso").modal('hide');
    },
    error: function(result){
      wc();
      $("#modalaviso").modal('hide');
      alertify.error('Error en eliminado de Herramientas...');
    }
  });
}
// Config Tabla
DataTable($('#tabla_clientes'));
</script>

<!-- Modal aviso eliminar -->
<div class="modal fade" id="modalaviso">
  <div class="modal-dialog" role="document">
    <div class="modal-content">
      <div class="modal-header bg-blue">
        <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
        <h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-trash text-light-blue"></span> Eliminar Cliente</h4>
      </div>
      <div class="modal-body">
        <div class="row">
          <div class="col-xs-12">
            <h4>¿Desea realmente eliminar el Cliente?</h4>
            <input type="text" id="clie_id" class="hidden">
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
<!-- /  Modal aviso eliminar -->
