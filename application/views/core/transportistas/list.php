
<!-- ______ TABLA PRINCIPAL DE PANTALLA ______ -->
<table id="tabla_transportistas" class="table table-bordered table-striped">
		<thead class="thead-dark" bgcolor="#eeeeee">
      <th>Acciones</th>
      <th>Razón social</th>
      <th>Cuit</th>
      <th>Teléfono</th>
      <th>Email</th>
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
            echo '<td>'.$value->razon_social.'</td>';
            echo '<td>'.$value->cuit.'</td>';
            echo '<td>'.$value->telefono.'</td>';
            echo '<td>'.$value->email.'</td>';
            echo '</tr>';
          }
				}
			?>
		</tbody>
</table>
<!--_______ FIN TABLA PRINCIPAL DE PANTALLA ______-->

<script>
    $(".btnEditar").on("click", function(e) {
      $("#formEdicion")[0].reset();
        $(".modal-header h4").remove();
        //guardo el tipo de operacion en el modal
        $("#operacion").val("Edit");
        //pongo titulo al modal
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Editar Transportista </h4>');
        data = $(this).parents("tr").attr("data-json");
        datajson = JSON.parse(data);
        $("#btnsave_edit").show();
        habilitarEdicion();
        llenarModal(datajson);
    });

    // extrae datos de la tabla
    $(".btnInfo").on("click", function(e) {
      // $("#formEdicion")[0].reset();
        $(".modal-header h4").remove();        
        //guardo el tipo de operacion en el modal
        $("#operacion").val("Info");
        //pongo titulo al modal
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Info Transportista </h4>');
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
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil text-light-blue"></span> Agregar Transportista </h4>');
        ///FIXME: LIMPIAR LOS CAMPOS Y SELECTS
    });

    // llena modal para edicion y muestra
    function llenarModal(datajson){
        // creo los select de estado y localidad
        $("#formEdicion")[0].reset();
        $('#pais_id_edit').prop('selectedIndex',0);
        $('#tipo_transporte_edit').prop('selectedIndex',-1);
        $('#pais_id_edit option[value="'+ datajson.pais_id +'"]').removeAttr("selected"); 
        $('#tipo_transporte_edit option[value="'+ datajson.tipo_transporte +'"]').removeAttr("selected");
        $("#prov_id_edit").append('<option value="' + datajson.prov_id + '">' + datajson.estado + '</option>');
        $('#prov_id_edit option[value="'+ datajson.prov_id +'"]').attr("selected",true);
        $("#loca_id_edit").append('<option value="' + datajson.loca_id + '">' + datajson.localidad + '</option>');
        $('#loca_id_edit option[value="'+ datajson.loca_id +'"]').attr("selected",true);
        $("#prov_id_edit").val(datajson.prov_id);
        $("#loca_id_edit").val(datajson.loca_id);
        // deshabilitar los select de estado y localidad
        $("#prov_id_edit").prop('disabled', true);
        $("#loca_id_edit").prop('disabled', true);
        $('#tran_id_edit').val(datajson.tran_id);
        $('#razon_social_edit').val(datajson.razon_social);
        $('#cuit_edit').val(datajson.cuit);
        $('#telefono_edit').val(datajson.telefono);
        $('#email_edit').val(datajson.email);
        $('#direccion_edit').val(datajson.direccion);
        $('#observaciones_edit').val(datajson.observaciones);
        $('#pais_id_edit option[value="'+ datajson.pais_id +'"]').attr("selected",true);
        $('#tipo_transporte_edit option[value="'+ datajson.tipo_transporte +'"]').attr("selected",true);
    }

    // deshabilita botones, selects e inputs de modal
    function blockEdicion(){
      $(".habilitar").attr("readonly","readonly");
      $(".selec_habilitar").attr('disabled', 'disabled');
    }

    // habilita botones, selects e inputs de modal
    function habilitarEdicion(){
      $('.habilitar').removeAttr("readonly");//
      $(".selec_habilitar").removeAttr("disabled");
    }

    // Levanta modal prevencion eliminar herramienta
    $(".btnEliminar").on("click", function() {
      $(".modal-header h4").remove();
      $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-times text-light-blue"></span> Eliminar Transportista </h4>');
      // datajson = $(this).parents("tr").attr("data-json");
      // data = JSON.parse(datajson);
      data = $(this).parents("tr").attr("data-json");
        datajson = JSON.parse(data);
        $('#tran_id_delete').val(datajson.tran_id);
      // var tran_id = datajson.tran_id;
      // guardo tran_id en modal para usar en funcion eliminar
      // $("#tran_id").val(tran_id);
      //levanto modal
      $("#modalaviso").modal('show');
      // console.log(datajson.tran_id);
    });

    // Elimina Transportista
    function eliminar(){
      var tran_id = $("#tran_id_delete").val();
      wo();
      $.ajax({
          type: 'POST',
          data:{tran_id: tran_id},
          url: 'index.php/core/Transportista/Borrar_Transportista',
          success: function(result) {
            $("#cargar_tabla").load("index.php/core/Transportista/Listar_Transportistas");
            wc();
            alertify.success("Transportista eliminado con éxito");
            $("#modalaviso").modal('hide');
          },
          error: function(result){
            wc();
            $("#modalaviso").modal('hide');
            alertify.error('Error en eliminado de Transportista...');
          }
      });
    }

    // Config Tabla
    DataTable($('#tabla_transportistas'));
</script>

<!-- Modal aviso eliminar -->
<div class="modal fade" id="modalaviso">
    <div class="modal-dialog" role="document">
      <div class="modal-content">
        <div class="modal-header bg-blue">
          <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
          <h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-trash text-light-blue"></span> Eliminar Transportista <?php  ?></h4>
        </div>
        <div class="modal-body">
          <div class="row">
            <div class="col-xs-12">
              <h4>¿Desea realmente eliminar el Transportista?</h4>
              <input type="text" id="tran_id_delete" class="hidden">
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
