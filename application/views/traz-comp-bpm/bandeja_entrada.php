<!-- Main content -->
<div class="row">
    <div id="bandeja" class="col-md-12">
        <div class="box box-primary">
            <div class="box-header">
                <h3 class="box-title">
                    <i class="fa fa-list"></i>

                    Bandeja de Tareas
                </h3>
            </div>
            <div class="box-body">

                <div class="table-responsive ">
                    <table class="table table-hover table-striped" id="tareas">
                        <thead>
                       
                            <th></th>
                            <th >Tarea</th>
                            <th class="oculto">Descripción</th>
                            <th class="oculto">Info</th>
                            <th class="oculto">Fec. Venc.</th>
                       
                        </thead>
                        <tbody>
                            <?php
                            foreach ($list as $f) {

                             //   if (true) { //($f->processId'] == BPM_PROCESS_ID_PEDIDOS_NORMALES || $f['processId'] == BPM_PROCESS_ID_PEDIDOS_EXTRAORDINARIOS) {

                                    $id = $f->taskId;
                                    $asig = $f->idUsuarioAsignado;

                                    echo "<tr class='item' id='$id' data-caseId='$f->caseId' data-json='".json_encode($f)."'  style='cursor: pointer;'>";

                                    if ($asig != "") {
                                        echo '<td class="' . ($device == 'android' ? 'hidden"' : '') . '"><i class="fa fa-user text-primary" title="' . formato_fecha_hora($f->fec_asignacion) . '"></i></td>';
                                    } else {
                                        echo '<td class="' . ($device == 'android' ? 'hidden"' : '') . '"><i class="fa fa-user" style="color: #d6d9db;" title="No Asignado"></i></td>';
                                    }

                                    echo '</td>';

                                    echo "<td class='mailbox-name'><a href='#'><b  style='color:$f->color'> $f->nombreProceso </b> </a>|  $f->nombreTarea </td>";

                                    echo '<td class="mailbox-subject oculto">' . substr($f->descripcion, 0, 500) . '</td>';

                                    echo '<td class="mailbox-subject oculto"><span class="label label-primary">OT:??</span> <span class="label label-warning">SS:??</span></td>';

                                    echo '<td class="mailbox-date oculto">' . formato_fecha_hora($f->fec_vencimiento) . 'dd/mm/aaaa</td>';

                                    echo '</tr>';

                                }
                         //   }
                            ?>

                        </tbody>
                    </table>
                    <!-- /.table -->
                </div>
            </div>
            <!-- /.mail-box-messages -->
        </div>
        <!-- /.box-body -->

    </div>
    <!-- /. box -->
    <div id="miniView" class="view col-xs-8">
            
    </div>
</div>


<!-- /.col -->
</div>
<!-- /.row -->

<script>
DataTable('#tareas');

$('.item').single_double_click(function() {
    $('body').addClass('sidebar-collapse');
    $('.oculto').hide();
    $('#bandeja').removeClass().addClass('col-xs-4');
    $('#miniView').empty();
    $('#miniView').load('<?php echo base_url(BPM) ?>Tarea/detalleTarea/' + $(this).attr('id'));

}, function() {
    linkTo('<?php echo BPM ?>Tarea/detalleTarea/' + $(this).attr('id'));

});

function closeView() { 
    $('#miniView').empty();
    $('.oculto').show();
    $('#bandeja').removeClass().addClass('col-md-12');
}

$('input').iCheck({
    checkboxClass: 'icheckbox_flat',
    radioClass: 'iradio_flat'
});
</script>