<!-- ______ TABLA PRINCIPAL DE PANTALLA ______ -->
<div class="form-group">
    <label><input type="radio" name="tipoFiltro" id="filtroVenta" value="Venta"> Venta</label>
    <label><input type="radio" name="tipoFiltro" id="filtroCompra" value="Compra"> Compra</label>
</div>
<table id="tabla_precios" class="table table-bordered table-striped">
    <thead class="thead-dark" bgcolor="#eeeeee">
      <th>Acciones</th>
      <th>Nombre</th>
      <th>Versión</th>
      <th>Detalle versión</th>
      <th>Tipo</th>
      <th>Fecha vigencia desde</th>
    </thead>
    <tbody>
      <?php
        if($listas_precios) {
          foreach($listas_precios as $precio) {
            $fechaOriginal = new DateTime($precio->fec_alta);
            $fechaOriginal->modify('+3 hours');
            $fechaFormateada = $fechaOriginal->format('d-m-Y H:i:s');
            echo "<tr data-tipo='".$precio->tipo."' data-json='".json_encode($precio)."'>";
              echo '<td>';
              echo '                        
              <button type="button" title="Ver" class="btn btn-primary btn-circle btnVer" data-toggle="modal" data-target="#modalVerPrecio" id="btnBorrar" ><span class="glyphicon glyphicon-search" aria-hidden="true" ></span></button>&nbsp';
              if ($precio->version > 1) {
                  echo '<button type="button" title="Versiones" class="btn btn-primary btn-circle btnVersiones" data-toggle="modal" data-target="#modalVersiones" id="btnVersiones" ><span class="glyphicon glyphicon-align-justify" aria-hidden="true"></span></button>&nbsp';
              }
              echo '<button type="button" title="Crear Versión" class="btn btn-primary btn-circle btnCrearVersion" data-toggle="modal" data-target="#modalEditarPrecio" id="btnCrearVersion" ><span class="glyphicon glyphicon-dashboard" aria-hidden="true"></span></button>&nbsp';
              echo '</td>';
              echo '<td>'.$precio->nombre.'</td>';
              echo '<td>'.$precio->version.'</td>';
              echo '<td>'.$precio->detalle.'</td>';
              echo '<td>'.$precio->tipo.'</td>';
              echo '<td>'.$fechaFormateada.'</td>';
            echo '</tr>';
          }
        }
      ?>
    </tbody>
</table>
<!--_______ FIN TABLA PRINCIPAL DE PANTALLA ______-->

<script>
  DataTable($('#tabla_precios'));

  $(document).ready(function(){
      $('input[name="tipoFiltro"]').on('change', function() {
          var tipoSeleccionado = $(this).val();
          $('#tabla_precios tbody tr').show();
          $('#tabla_precios tbody tr').each(function(){
              var tipo = $(this).data('tipo');
              if(tipo !== tipoSeleccionado) {
                  $(this).hide();
              }
          });
      });
  });
</script>
