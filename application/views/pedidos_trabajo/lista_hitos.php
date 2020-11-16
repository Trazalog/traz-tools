<style>
.srow {
    background-color: #82E0AA
}
</style>
<table id="tbl-hitos" class="table table-hover t-btn">
    <thead>
        <th><button data-toggle="modal" data-target="#mdl-hito" class="btn btn-sm btn-block btn-flat"><i class="fa fa-plus mr-2"></i> Nuevo
                Hito</button></th>
    </thead>
    <tbody>
        <?php
            $ots = getJson('ot');
            foreach ($ots as $key => $o) {
                echo "<tr>";
                echo '<td><div class="btn-group">
                        <button onclick="selectHito('."123".',\''.$o->codigo.'\')" type="button" class="btn code"><h4>'.$o->codigo.'</h4><img src="http://localhost/traz-tools/lib/dist/img/user2-160x160.jpg" class="user-image" alt="User Image"></button>
                        <button type="button" class="btn dropdown-toggle" data-toggle="dropdown">
                            <span class="caret"></span>
                            <span class="sr-only">Toggle Dropdown</span>
                        </button>
                        <ul class="dropdown-menu" role="menu">
                            <li><a href="#">Action</a></li>
                            <li><a href="#">Another action</a></li>
                            <li><a href="#">Something else here</a></li>
                            <li class="divider"></li>
                            <li><a href="#">Separated link</a></li>
                        </ul>
                        </div></td>';
                echo "</tr>";
            }
        ?>
    </tbody>
</table>

<script>
var s_hito_row = false;
$('#tbl-hitos tbody').find('tr').click(function(){
    $(s_hito_row).removeClass('srow');
    s_hito_row = this;
    $(this).addClass('srow');
});
function selectHito(id, codigo) {
    reload('#tareas_planificadas', id);
}
</script>