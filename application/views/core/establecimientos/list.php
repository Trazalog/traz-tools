<!-- ______ TABLA PRINCIPAL DE PANTALLA ______ -->
<table id="tabla_establecimientos" class="table table-bordered table-striped">
    <thead class="thead-dark" bgcolor="#eeeeee">
        <th>Acciones</th>
        <th>Nombre</th>
        <th>Calle y Altura</th>
        <th>Localidad</th>
        <th>Estado</th>
        <th>País</th>
    </thead>
    <tbody >
        <?php
            if($listarEstablecimientos) {
                foreach($listarEstablecimientos as $establecimiento) {
                    echo "<tr data-json='".json_encode($establecimiento)."'>";
                        echo '<td>';
                            echo '                        
                            <button type="button" title="Eliminar" class="btn btn-primary btn-circle btnEliminar" data-toggle="modal" data-target="#modalEliminarEstablecimiento" id="btnBorrar" ><span class="glyphicon glyphicon-trash" aria-hidden="true" ></span></button>&nbsp
                            <button type="button" title="Editar"  class="btn btn-primary btn-circle btnEditar" data-toggle="modal" data-target="#modalEditarEstablecimiento" id="btnEditar" ><span class="glyphicon glyphicon-pencil" aria-hidden="true"></span></button>&nbsp
                            <button type="button" title="Depósitos" class="btn btn-primary btn-circle btnDepositos" data-toggle="modal" data-target="#modaleditar" ><span class="glyphicon glyphicon-inbox" aria-hidden="true"></span></button>&nbsp
                            <button type="button" title="Pañoles" class="btn btn-primary btn-circle btnPanoles" data-toggle="modal" data-target="#modaleditar" ><span class="glyphicon glyphicon-th-large" aria-hidden="true"></span></button>&nbsp
                            ';
                        echo '</td>';
                        echo '<td>'.$establecimiento->nombre.'</td>';
                        echo '<td>'.$establecimiento->calle.' '.$establecimiento->altura.'</td>';
                        echo '<td>'.$establecimiento->localidad.'</td>';
                        echo '<td>'.$establecimiento->estado.'</td>';
                        echo '<td>'.$establecimiento->pais.'</td>';
                    echo '</tr>';
                }
            }
        ?>
    </tbody>
</table>
<!--_______ FIN TABLA PRINCIPAL DE PANTALLA ______-->

<script>
  // extrae datos de la tabla
  $(".btnEditar").on("click", function(e) {
    // $("#pais_edit").val('');
    $(".modal-header h4").remove();
    //guardo el tipo de operacion en el modal
    $("#operacion").val("Edit");
    //pongo titlo al modal
    $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Editar Establecimiento </h4>');
    data = $(this).parents("tr").attr("data-json");
    datajson = JSON.parse(data);
    // habilitarEdicion();
    // blockEdicion();
    llenarModal(datajson);
  });

  // llena modal para edicion
  function llenarModal(datajson){
    // var form = $('#formEdicionEstablecimiento')[0];
    // form.reset();
    // $("#pais_edit").val('');
    // creo los select de estado y localidad
    var $selectEstado = $("#estado_edit");
    var $selectLocalidad = $("#localidad_edit");
    // a esos select les guardo solamente los valores guardados previamente
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
    $('#esta_id').val(datajson.esta_id);
    $('#nombre_edit').val(datajson.nombre);
    $('#calle_edit').val(datajson.calle);
    $('#altura_edit').val(datajson.altura);
    $('#pais_edit option[value="'+ datajson.pais_id +'"]').attr("selected",true);
  }    

  // Levanta modal prevencion eliminar herramienta
  $(".btnEliminar").on("click", function() {
      $(".modal-header h4").remove();
      $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-times text-light-blue"></span> Eliminar Establecimiento </h4>');
      datajson = $(this).parents("tr").attr("data-json");
      data = JSON.parse(datajson);
      var esta_id = data.esta_id;
      // guardo esta_id en modal para usar en funcion eliminar
      $("#id_esta").val(esta_id);
      //levanto modal
      $("#modalaviso").modal('show');
  });
  // Elimina herramienta
  function eliminarEstablecimiento(){
      var esta_id = $("#id_esta").val();
      wo();
      $.ajax({
          type: 'POST',
          data:{esta_id: esta_id},
          url: 'index.php/core/Establecimiento/borrarEstablecimiento',
          success: function(result) {
              $("#cargar_tabla").load("index.php/core/Establecimiento/listarEstablecimientos");
              setTimeout(function(){ 
                  alertify.success("Artículo eliminado con éxito");
                  wc();
                  // alert("Hello"); 
              }, 3000);
              $("#modalaviso").modal('hide');
          },
          error: function(result){
              wc();
              $("#modalaviso").modal('hide');
              alertify.error('Error en eliminado de Establecimiento...');
          }
      });
  }
  
  $(".btnDepositos").on("click", function(e) {
    $("#modaldepositos td").remove();
    $(".modal-header h4").remove();
    //guardo el tipo de operacion en el modal
    $("#operacion").val("Depositos");
    //pongo titlo al modal
    $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Depósitos del Establecimiento </h4>');
    datajson = $(this).parents("tr").attr("data-json");
    data = JSON.parse(datajson);
    var esta_id = data.esta_id;
    // guardo esta_id en modal para usar en funcion agregar deposito
    $("#id_esta").val(esta_id);
    $.ajax({
      type: 'GET',
      url: 'index.php/core/Establecimiento/listarDepositosXEstablecimiento?esta_id='+esta_id,
      success: function(result) {
        if (result) {
          var tabla = $('#modaldepositos table');    
          $(tabla).find('tbody').html('');
          result.forEach(e => {
            $(tabla).append(
              "<tr data-json= ' "+ JSON.stringify(e) +" '>" +
                "<td><button type='button' title='Eliminar Depósito' class='btn btn-primary btn-circle btnEliminar' onclick='eliminarDeposito(this)' id='btnBorrar'><span class='glyphicon glyphicon-trash' aria-hidden='true' ></span></button>" +
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

  $(".btnPanoles").on("click", function(e) {
    $("#modalpanoles td").remove();
    $(".modal-header h4").remove();
    //guardo el tipo de operacion en el modal
    $("#operacion").val("Panoles");
    //pongo titlo al modal
    $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Pañoles del Establecimiento </h4>');
    datajson = $(this).parents("tr").attr("data-json");
    data = JSON.parse(datajson);
    var esta_id = data.esta_id;
    // guardo esta_id en modal para usar en funcion agregar deposito
    $("#id_esta").val(esta_id);
    $.ajax({
      type: 'GET',
      url: 'index.php/core/Establecimiento/listarPanolesXEstablecimiento?esta_id='+esta_id,
      success: function(result) {
        if (result) {
          var tabla = $('#modalpanoles table');
          $(tabla).find('tbody').html('');
          result.forEach(e => {
            $(tabla).append(
              "<tr data-json= ' "+ JSON.stringify(e) +" '>" +
              "<td><button type='button' title='Eliminar Pañol' class='btn btn-primary btn-circle btnEliminar' onclick='eliminarPanol(this)' id='btnBorrar'><span class='glyphicon glyphicon-trash' aria-hidden='true' ></span></button>" +
                "<td>" + e.nombre + "</td>" +
              "</tr>"
            );
          });            
        };
        $('#modalpanoles').modal('show'); 
      },
      error: function(result) {
          alert('Error');
      },
      dataType: 'json'
    });
    //levanto modal
    // $("#modaldepositos").modal('show');
  });

  // Config Tabla de Establecimientos
  DataTable($('#tabla_establecimientos'));
</script>

<!-- MODAL AVISO ELIMINAR ESTABLECIMIENTO -->
<div class="modal fade" id="modalEliminarEstablecimiento">
  <div class="modal-dialog" role="document">
    <div class="modal-content">
      <div class="modal-header bg-blue">
        <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
        <h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-trash text-light-blue"></span> Eliminar Cliente</h4>
      </div>
      <div class="modal-body">
        <div class="row">
          <div class="col-xs-12">
            <h4>¿Desea realmente eliminar el Establecimiento?</h4>
            <input type="text" id="id_esta" class="hidden">
          </div>
        </div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button>
        <button type="button" class="btn btn-primary" data-dismiss="modal" onclick="eliminarEstablecimiento()">Aceptar</button>
      </div>
    </div>
  </div>
</div>
<!-- /  MODAL AVISO ELIMINAR ESTABLECIMIENTO -->