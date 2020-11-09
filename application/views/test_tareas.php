<style>
.user-image {
    border-radius: 50%;
    width: 25px;
    height: 25px;
    margin-top: 5px;
}


.btn-group .btn {
    height: 100px;

}

.btn-group {
    display: flex;
    margin: 0;
}

.code {
    flex: 1;
}
</style>
<div class="row">
    <div class="col-md-2">
        <div class="box box-primary">
            <div class="box-header">
                <h3 class="box-title">Pedidos Trabajo</h3>
            </div>
            <div class="xbox-body">
                <table class="table table-hover text-center">
                    <thead>
                        <th> <button type="button" class="btn bg-teal btn-sm btn-flat btn-block"><i
                                    class="fa fa-plus"></i>
                            </button></th>
                    </thead>
                    <tbody>
                        <?php
                   $ots = getJson('ot');
                   foreach ($ots as $key => $o) {
                       echo "<tr>";
                       echo '<td><div class="btn-group">
                                <button type="button" class="btn btn-default code">'.$o->codigo.'<br><img src="http://localhost/traz-tools/lib/dist/img/user2-160x160.jpg" class="user-image" alt="User Image"></button>
                                <button type="button" class="btn btn-default dropdown-toggle" data-toggle="dropdown">
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
            </div>
        </div>
    </div>
    <div class="col-md-2">
        <div class="table table-hover">
            <thead>
                <th><button class="btn btn-primary btn-sm"><i class="fa fa-plus"></i></button></th>
                <th>Hitos</th>
            </thead>
            <tbody></tbody>
        </div>
    </div>
    <div class="col-md-2"></div>
</div>