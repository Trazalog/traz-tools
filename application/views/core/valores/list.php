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
  // habilita botones, selects e inputs de modal
  function habilitarEdicion(){
    $('.habilitar').removeAttr("readonly");//
    //$(".selec_habilitar").removeAttr("disabled");
  }

  // Config Tabla
  DataTable($('#tabla_valores'));
</script>
