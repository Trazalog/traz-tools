
<!-- ______ TABLA PRINCIPAL DE PANTALLA ______ -->
<table id="tabla_equipos" class="table table-bordered table-striped">
		<thead class="thead-dark" bgcolor="#eeeeee">
      <th>Acciones</th>
      <th>Id</th>
      <th>Descripción</th>
      <th>Área</th>
      <th>Código</th>
      <th>Sector</th>
      <th>Criticidad</th>
      <th>Estado</th>
		</thead>
		<tbody >
			<?php
				if($list)
				{
					foreach($list as $value)
          {
            echo "<tr data-json='".json_encode($value)."'>";
            echo '<td>';
                echo '<button  type="button" title="Editar"  class="btn btn-primary btn-circle btnEditar" data-toggle="modal" data-target="#" id="btnEditar"  ><span class="glyphicon glyphicon-pencil" aria-hidden="true"></span></button>&nbsp
                <button type="button" title="Info" class="btn btn-primary btn-circle btnInfo" data-toggle="modal" data-target="#" ><span class="glyphicon glyphicon-info-sign" aria-hidden="true"></span></button>&nbsp
                <button type="button" title="Eliminar" class="btn btn-primary btn-circle btnEliminar" id="btnBorrar"  ><span class="glyphicon glyphicon-trash" aria-hidden="true" ></span></button>&nbsp';
            echo '</td>';
            echo '<td>'.$value->equi_id.'</td>';
            echo '<td>'.$value->descripcion.'</td>';
            echo '<td>'.$value->area_id.'</td>';
            echo '<td>'.$value->codigo.'</td>';
            echo '<td>'.$value->sect_id.'</td>';
            echo '<td>'.$value->crit_id.'</td>';
            echo '<td>'.$value->estado.'</td>';
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
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Editar Equipo </h4>');
        data = $(this).parents("tr").attr("data-json");
        datajson = JSON.parse(data);
        habilitarEdicion();
        llenarModal(datajson);
    });
    // extrae datos de la tabla
    $(".btnInfo").on("click", function(e) {
        $(".modal-header h4").remove();
        //guardo el tipo de operacion en el modal
        $("#operacion").val("Info");
        //pongo titulo al modal
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Info Equipo </h4>');
        data = $(this).parents("tr").attr("data-json");
        datajson = JSON.parse(data);
        blockEdicion();
        llenarModal(datajson);
    });
    //cambia encabezado para agregar una herramienta
    $("#btnAdd").on("click", function(e) {
        $("#operacion").val("Add");
        $(".modal-header h4").remove();
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil text-light-blue"></span> Agregar Equipo </h4>');
        ///FIXME: LIMPIAR LOS CAMPOS Y SELECTS
    });
    // llena modal para edicion y muestra
    function llenarModal(datajson){
      $('#equi_id_edit').val(datajson.equi_id);
      $('#nombre_edit').val(datajson.nombre);
      $('#descripcion_edit').val(datajson.descripcion);
      $('#contenido_edit').val(datajson.capacidad);
      $('#tara_edit').val(datajson.tara);
      $('#ticl_id_edit option[value="'+ datajson.ticl_id +'"]').attr("selected",true);
    }
        // deshabilita botones, selects e inputs de modal
    function blockEdicion(){
      $(".habilitar").attr("readonly","readonly");
      //$(".selec_habilitar").attr('disabled', 'disabled');
    }
    // habilita botones, selects e inputs de modal
    function habilitarEdicion(){
      $('.habilitar').removeAttr("readonly");//
      //$(".selec_habilitar").removeAttr("disabled");
    }
      // Levanta modal prevencion eliminar herramienta
      $(".btnEliminar").on("click", function() {
        $(".modal-header h4").remove();
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-times text-light-blue"></span> Eliminar Equipo</h4>');
        datajson = $(this).parents("tr").attr("data-json");
        data = JSON.parse(datajson);
        var equi_id = data.equi_id;
        // guardo equi_id en modal para usar en funcion eliminar
        $("#id_equi").val(equi_id);
        //levanto modal
        $("#modalaviso").modal('show');
      });

// Elimina Equipo
function eliminar(){
  var equi_id = $("#id_equi").val();
  wo();
  $.ajax({
      type: 'POST',
      data:{equi_id: equi_id},
      url: 'index.php/core/Equipo/Borrar_Equipo',
      success: function(result) {
        $("#cargar_tabla").load("index.php/core/Equipo/Listar_Equipos");
        setTimeout(function(){ 
          alertify.success("Equipo eliminado con éxito");
          wc();
          // alert("Hello"); 
        }, 3000);
        $("#modalaviso").modal('hide');
      },
      error: function(result){
        wc();
        $("#modalaviso").modal('hide');
        alertify.error('Error en eliminado de Equipo...');
      }
  });
}
   // Config Tabla
   DataTable($('#tabla_equipos'));
</script>

<!-- Modal aviso eliminar -->
<div class="modal fade" id="modalaviso">
    <div class="modal-dialog" role="document">
      <div class="modal-content">
        <div class="modal-header bg-blue">
          <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
          <h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-trash text-light-blue"></span> Eliminar Equipo</h4>
        </div>
        <div class="modal-body">
          <div class="row">
            <div class="col-xs-12">
              <h4>¿Desea realmente eliminar el Equipo?</h4>
              <input type="text" id="id_equi" class="hidden">
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
