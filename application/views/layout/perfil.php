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
		<!-- La ayuda se sirve desde este mismo repo (carpeta /ayuda), no desde un
		     sitio aparte: decision del PM del 2026-08-25. La direccion sale de
		     URL_AYUDA en constants.php, que es lo que se toca al desplegar.
		     El defined() es la red por si llegara una vista sin la constante: el
		     enlace sigue funcionando en vez de tirar un fatal.
		     Hasta v2.4 esta linea apuntaba a https://trazalog.com/ayudatools/, el
		     sitio de afuera. Desde v2.5 la ayuda es parte del repo y se sirve desde
		     /ayuda; el sitio viejo queda solo para las versiones anteriores. -->
		<?php
			$url_ayuda = defined('URL_AYUDA') ? URL_AYUDA : 'ayuda/';
			if ( ! preg_match('#^https?://#i', $url_ayuda))
			{
				$url_ayuda = base_url() . ltrim($url_ayuda, '/');
			}
		?>
		<li>
			<a href="<?php echo $url_ayuda; ?>" target="_blank" title="Ayuda">
				<i class="fa fa-question-circle"></i>
			</a>
		</li>
		<!-- User Account: style can be found in dropdown.less -->
		<!-- Campanita de avisos (ADR-015), para todos los usuarios. La llena
		     lib/props/avisos.js desde index.php/Avisos. Hasta la v3.5 aca habia
		     una maqueta con 10 notificaciones de ejemplo fijas. -->
		<li class="dropdown notifications-menu" id="tz-avisos-menu">
			<a href="#" class="dropdown-toggle" data-toggle="dropdown" title="Avisos">
				<i class="fa fa-bell-o"></i>
				<span class="label label-warning" id="tz-avisos-numero" style="display:none"></span>
			</a>
			<ul class="dropdown-menu">
				<li class="header" id="tz-avisos-titulo">No tenés avisos nuevos</li>
				<li>
					<ul class="menu" id="tz-avisos-lista"></ul>
				</li>
				<li class="footer">
					<a href="#" id="tz-avisos-push" style="display:none"></a>
					<a href="#" id="tz-avisos-todos">Marcar todos como leídos</a>
				</li>
			</ul>
		</li>
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

<style>
	.notFA {margin-left: 27px;}
	.navbar-nav>.user-menu>.dropdown-menu>.user-body {padding: 15px 0;}
	.navbar-nav>.user-menu>.dropdown-menu>.user-footer {padding: 10px 20px;}
	#tz-avisos-lista .tz-aviso {white-space: normal;}
	#tz-avisos-lista .tz-aviso-leido .tz-aviso {opacity: .6;}
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