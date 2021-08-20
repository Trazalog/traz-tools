<!-- ______ TABLA PRINCIPAL DE PANTALLA ______ -->
<table id="tabla_valores" class="table table-bordered table-striped">
    <thead class="thead-dark" bgcolor="#eeeeee">
        <th>Acciones</th>
        <th>Descripción</th>
        <th>Valor</th>
        <th>Valor 2</th>
        <th>Valor 3</th>
    </thead>
    <tbody >
        <!--TABLE BODY -->
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
      habilitarEdicion();
      llenarModal(datajson);
  });

  // habilita botones, selects e inputs de modal
  function habilitarEdicion(){
    $('.habilitar').removeAttr("readonly");//
    //$(".selec_habilitar").removeAttr("disabled");
  }

   // Config Tabla
   DataTable($('#tabla_valores'));
</script>
