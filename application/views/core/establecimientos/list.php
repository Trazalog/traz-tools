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
                            <button type="button" title="Depósitos" class="btn btn-primary btn-circle btnInfo" data-toggle="modal" data-target="#modaleditar" ><span class="glyphicon glyphicon-inbox" aria-hidden="true"></span></button>&nbsp
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
    // Config Tabla de Establecimientos
    DataTable($('#tabla_establecimientos'));

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
                wc();
                $("#modalaviso").modal('hide');
            },
            error: function(result){
            wc();
            $("#modalaviso").modal('hide');
            alertify.error('Error en eliminado de Establecimiento...');
            }
        });
    }

    // llena modal para edicion
    function llenarModal(datajson){
        var $selectEstado = $("#estado_edit");
        // var $selectLocalidad = $("#localidad_edit");

        // var valor = $("#nombreLista").val();
        $selectEstado.append($("<option>", {
            value: datajson.estado_id,
            text: datajson.estado,
        }));
        $("#estado_edit").val(datajson.estado_id);

        $('#esta_id').val(datajson.esta_id);
        //$('#pano_id').val(datajson.pano_id);
        $('#nombre_edit').val(datajson.nombre);
        $('#calle_edit').val(datajson.calle);
        $('#altura_edit').val(datajson.altura);
        $('#pais_edit option[value="'+ datajson.pais_id +'"]').attr("selected",true);
        // $('#estado_edit option[value="'+ datajson.id_estado +'"]').attr("selected",true);
        // $('#localidad_edit option[value="'+ datajson.localidad_id +'"]').attr("selected",true);
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
        $(".modal-header").append('<h4 class="modal-title"  id="myModalLabel"><span id="modalAction" class="fa fa-fw fa-pencil"></span> Editar Establecimiento </h4>');
        data = $(this).parents("tr").attr("data-json");
        datajson = JSON.parse(data);
        // habilitarEdicion();
        // blockEdicion();
        llenarModal(datajson);
    });

    // function guardarEdicionEstablecimiento() {
    //     if( !validarCampos('formEdicionEstablecimiento') ){
    //         return;
    //     }
    //     var recurso = "";
    //     var form = $('#formEdicionEstablecimiento')[0];
    //     var datos = new FormData(form);
    //     var datos = formToObject(datos);
    // }
</script>