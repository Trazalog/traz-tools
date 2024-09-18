<!-- ______ TABLA PRINCIPAL DE PANTALLA ______ -->
<!-- Radios para filtrar -->
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
            // Convertir y formatear la fecha fec_alta
            $fechaOriginal = new DateTime($precio->fec_alta);
            $fechaOriginal->modify('+3 hours'); // Agregar 3 horas
            $fechaFormateada = $fechaOriginal->format('d-m-Y H:i:s'); // Formato deseado

            // Agregar el atributo data-tipo para cada fila
            echo "<tr data-tipo='".$precio->tipo."' data-json='".json_encode($precio)."'>";
              echo '<td>';
              echo '                        
              <button type="button" title="Ver" class="btn btn-primary btn-circle btnVer" data-toggle="modal" data-target="#modalVerPrecio" id="btnBorrar" ><span class="glyphicon glyphicon-search" aria-hidden="true" ></span></button>&nbsp';

              if ($precio->version > 1) {
                  echo '<button type="button" title="Versiones" class="btn btn-primary btn-circle btnVersiones" data-toggle="modal" data-target="#modalVersiones" id="btnVersiones" ><span class="glyphicon glyphicon-align-justify" aria-hidden="true"></span></button>&nbsp';
              }

              echo '<button type="button" title="Editar" class="btn btn-primary btn-circle btnEditar" data-toggle="modal" data-target="#modalEditarPrecio" id="btnEditar" ><span class="glyphicon glyphicon-dashboard" aria-hidden="true"></span></button>&nbsp';
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
  // Config Tabla de precios
  DataTable($('#tabla_precios'));

  $(document).ready(function(){
      // Función que filtra las filas de la tabla según el valor del radio button seleccionado
      $('input[name="tipoFiltro"]').on('change', function() {
          var tipoSeleccionado = $(this).val(); // Obtener el valor del radio seleccionado (Venta o Compra)
          
          // Mostrar todas las filas inicialmente
          $('#tabla_precios tbody tr').show();
          
          // Filtrar las filas según el campo "tipo"
          $('#tabla_precios tbody tr').each(function(){
              var tipo = $(this).data('tipo'); // Obtener el valor del atributo data-tipo
              if(tipo !== tipoSeleccionado) {
                  $(this).hide(); // Ocultar las filas que no coinciden
              }
          });
      });
  });
</script>
