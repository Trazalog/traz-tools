<style>
.navbar-header-tzl{
    float: left;
}
.navbar-custom-menu>.navbar-nav>li>.dropdown-menu {
    width: auto !important;
}
</style>
<div class="navbar-header-tzl">
<ul class="nav navbar-nav">
      <li class="nav-item">
        <a class="nav-link" href="#" onclick="linkTo('traz-comp-bpm/Proceso')">Mis Tareas <span class="sr-only">(current)</span></a>
      </li>
    </ul>
</div>
<div class="navbar-custom-menu">
	<ul class="nav navbar-nav">
		<!-- Help Menu Link -->
		<li>
			<a href="#" data-toggle="modal" data-target="#modalAyuda" title="Ayuda">
				<i class="fa fa-question-circle"></i>
			</a>
		</li>
		<!-- User Account: style can be found in dropdown.less -->
		<!-- Bloque PRUEBA -->
		<li class="dropdown notifications-menu">
			<a href="#" class="dropdown-toggle" data-toggle="dropdown">
				<i class="fa fa-bell-o"></i>
				<span class="label label-success">10</span>
			</a>
			<ul class="dropdown-menu">
				<li class="header">You have 10 notifications</li>
				<li>
					<ul class="menu">
						<li>
							<a href="#">
							<i class="fa fa-users text-aqua"></i> 5 new members joined today
							</a>
						</li>
						<li>
						<a href="#">
							<i class="fa fa-warning text-yellow"></i> Very long description here that may not fit into the page and may cause design problems
							</a>
						</li>
						<li>
						<a href="#">
							<i class="fa fa-users text-red"></i> 5 new members joined
						</a>
						</li>
						<li>
							<a href="#">
								<i class="fa fa-shopping-cart text-green"></i> 25 sales made
							</a>
						</li>
						<li>
							<a href="#">
								<i class="fa fa-user text-red"></i> You changed your username
							</a>
						</li>
					</ul>
				</li>
				<li class="footer"><a href="#">View all</a></li>
			</ul>
		</li>
		<!-- BLOQUE PRUEBA -->
		<li class="dropdown user user-menu">
			<a href="#" class="dropdown-toggle" data-toggle="dropdown" aria-expanded="false">
				<?php 
					echo '<img src="'.imageAdmin($image, $image_name).'" class="user-image" alt="User Image"/>';
				?>
				<span class="hidden-xs"><?php echo $this->session->userdata['first_name'].' '.$this->session->userdata['last_name']?></span>
			</a>
			<ul class="dropdown-menu">
					
					<li class="user-body">
							<a href="<?php echo base_url('Login/edit');?>"><i class="fa fa-pencil"></i> Editar Perfil</a>
					</li>


					<li class="user-body">
						<?php
							$empActiva = empresa();
							foreach($memberships as $memb){
								$group_id = empr_id_BPM($memb);
								echo "<a href='#' class='btnEmpresa' data-json='".json_encode($memb)."'>";

								if( $empActiva == $group_id )
										echo '<i class="fa fa-check"></i>';
								else
										echo '<i class="notFA"></i>';

								echo $memb->group_id->displayName." - ".$memb->role_id->displayName;
								echo "</a>";
							}
						?>

					</li>
					<!-- Menu Footer-->
					<li class="user-footer">
							<?php if($this->session->userdata['role'] == 1){  // si es usr admin 	?>
								<div class="pull-left">
										<a style="color: #fff !important;background-color: #3c8dbc !important" href=<?php echo base_url('Login/list_usuarios')?> class="btn-sm btn-primary pull-right">Usuarios <i class="fa fa-user-circle-o"></i></a>
								</div>
							<?php } ?>
							<div class="pull-right">
									<a style="color: #fff !important;background-color: #3c8dbc !important" href=<?php echo base_url('Login/log_out')?> class="btn-sm btn-primary pull-left">Salir <i class="fa fa-fw fa-sign-out"></i></a>
							</div>
					</li>
			</ul>
		</li>
	</ul>
</div>

<!-- Modal Ayuda Amplio -->
<div class="modal fade" id="modalAyuda" tabindex="-1" role="dialog" aria-labelledby="modalAyudaLabel" style="z-index: 1050;">
    <div class="modal-dialog modal-lg" role="document" style="width: 90%; max-width: 1200px; margin: 30px auto;">
        <div class="modal-content">
            <div class="modal-header bg-blue" style="color: #fff;">
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" style="color: #fff; opacity: 0.8;"><span aria-hidden="true">&times;</span></button>
                <h4 class="modal-title" id="modalAyudaLabel"><i class="fa fa-question-circle"></i> Centro de Ayuda Trazalog Tools</h4>
            </div>
            <div class="modal-body" style="padding: 0; height: 75vh;">
                <iframe src="https://trazalog.com/ayudatools/" style="width: 100%; height: 100%; border: none;"></iframe>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-default pull-right" data-dismiss="modal">Cerrar</button>
            </div>
        </div>
    </div>
</div>

<script>
$(document).ready(function() {
    // Mover el modal al <body> para evitar problemas de stacking context dentro del navbar de AdminLTE
    $('#modalAyuda').appendTo('body');
});
</script>

<style>
	.notFA {margin-left: 27px;}
	.navbar-nav>.user-menu>.dropdown-menu>.user-body {padding: 15px 0;}
	.navbar-nav>.user-menu>.dropdown-menu>.user-footer {padding: 10px 20px;}
</style>


<script>

	$(document).on('click', '.btnEmpresa', function() {

			wo();
			var datajson = $(this).attr('data-json');
			var data = JSON.parse(datajson);
			var grupo = data.group_id.name;
			var name = grupo.split('-');
			var empr_id = name[0];
			var group = name[1];
			cambiarDeEmpresa(empr_id, group);
	});

	function cambiarDeEmpresa(empr_id, group) {

			$.ajax({
					data: {empr_id: empr_id, group:group},
					dataType: 'json',
					type: 'POST',
					url: 'index.php/Dash/cambiarDeEmpresa',
					success: function(result) {
						//window.location.href = 'dash';
						location.reload();
					},
					error: function(result) {
							console.error("Error al cambiar de empresa");
							console.table(result);
					},
			});
	}

	$( document ).ready(function() {
    wc();
	});


</script>