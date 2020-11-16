
<?php
    $this->load->view('pedidos_trabajo/mdl_hitos');
?>

<style>
.user-image {
    border-radius: 50%;
    width: 25px;
    height: 25px;
    margin-top: 5px;
}

.t-btn .btn-group .btn {
    height: 100px;
}

.t-btn .btn-group {
    display: flex;
    margin: 0;
}

.code {
    flex: 1;
}

/* .my-custom-scrollbar {
    position: relative;
    height: 70vh;
    overflow-y: auto;
    overflow-x: hidden;
}

.table-wrapper-scroll-y {
    display: block;
} */
</style>
<div class="row">
    <div class="col-md-2">
        <div class="box box-primary">
            <div class="box-header  with-border">
                <h3 class="box-title">Pedidos Trabajo</h3>
            </div>
            <div class="box-body">
                <?php echo comp('pedidos-trabajos', base_url('test/pedidosTrabajos'), true)?>
            </div>
        </div>
    </div>
    <div class="col-md-2">
        <div class="box box-primary">
            <div class="box-header  with-border">
                <h3 class="box-title">Hitos:</h3>
                <h3 class="box-title pull-right"><cite>
                        <peta></peta>
                    </cite></h3>
            </div>
            <div class="box-body">
                <?php echo comp('hitos', base_url('test/hitos')) ?>
                <div class="text-center">
                    <i class="fa fa-lightbulb-o fa-4x text-gray"></i><br>
                    <cite>Selecciona un <b>Pedido de Trabajo</b> para ver los hitos asociados.</cite>
                </div>
            </div>
        </div>
    </div>
    <div class="col-md-8">
        <!-- <tareas>
            <script>
            $('tareas').load('<?php #echo base_url(TST) ?>Tarea/planificar/BATCH/0');
            </script>
        </tareas> -->
        <?php echo comp('tareas_planificadas', base_url(TST.'tarea/planificar/PEMA'), true) ?>
    </div>
</div>

<script>
$('.sidebar-toggle').click();

function collapse(e) {
    e = $(e).closest('.box');

    if (e.hasClass('collapsed-box')) {
        $(e).removeClass('collapsed-box');
    } else {
        $(e).addClass('collapsed-box');
    }

}
</script>