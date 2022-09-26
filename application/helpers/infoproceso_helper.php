<style>
	#petr_id{
  
    font-size: 14px;
}
</style>
<?php defined('BASEPATH') OR exit('No direct script access allowed');
	/**
	* Cabeceras con informacion variable segun proceso BPM
	*
	* @autor Hugo Gallardo
	*/
	if(!function_exists('infoproceso')){

			function infoproceso($tarea){

				$ci =& get_instance();
				$case_id = $tarea->caseId;
				$processId = $tarea->processId;
				$nombreTarea = $tarea->nombreTarea;
				$data['processId']=$processId;

				switch ($processId) {
					case BPM_PROCESS_ID_PEDIDOS_NORMALES:

							log_message('INFO','#TRAZA|INFOPROCESO_HELPER|/solicitudContenedores/info/.$case_id): $case_id >> '.json_encode($case_id));
							$ci->load->model(ALM . 'Notapedidos');
							$data['info'] = $ci->Notapedidos->getXCaseId($tarea->caseId);
							
							 $data_generico =$data['info'];
					 		$aux = $data_generico;
						break;

					case BPM_PROCESS_ID_PEDIDOS_EXTRAORDINARIOS:

							log_message('INFO','#TRAZA|INFOPROCESO_HELPER|/solicitudRetiro/proceso/retiro/case/.$case_id): $case_id >> '.json_encode($case_id));
							$aux = $ci->rest->callAPI("GET",REST_PRD."/solicitudRetiro/proceso/retiro/case/".$case_id);
							$data =json_decode($aux["data"]);
							$aux = $data->solicitud_retiro;
						break;

					case BPM_PROCESS_ID_ENTREGA_ORDEN_TRANSPORTE:

							log_message('INFO','#TRAZA|INFOPROCESO_HELPER|/ordenTransporte/info/entrega/case/".$case_id : $case_id >> '.json_encode($case_id));

							$aux = $ci->rest->callAPI("GET",REST_PRD."/ordenTransporte/info/entrega/case/".$case_id);
							$data =json_decode($aux["data"]);
							$aux = $data->ordenTransporte;

							$aux_cont = $ci->rest->callAPI("GET",REST_PRD."/contenedoresEntregados/info/entrega/case/".$case_id);
							$data_cont =json_decode($aux_cont["data"]);
							$aux_cont = $data_cont->contenedores->contenedor;
						break;

						
						case BPM_PROCESS_ID_REPARACION_NEUMATICOS:
						
					log_message('INFO','#TRAZA|INFOPROCESO_HELPER|REPARACION_NEUMATICOS/".$case_id : $case_id >> '.json_encode($case_id));
					$ci->load->model(YUDIPROC . 'Yudiproctareas');
				
					$aux = $ci->rest->callAPI("GET",REST_PRO."/pedidoTrabajo/xcaseid/".$case_id);
					 		$data_generico =json_decode($aux["data"]);
					 		$aux = $data_generico->pedidoTrabajo;

					
							 $clie_id = $aux->clie_id;

					$aux_clie = $ci->rest->callAPI("GET",REST_CORE."/cliente/".$clie_id);
					$aux_clie =json_decode($aux_clie["data"]);

						break;

				default:
						
					log_message('INFO','#TRAZA|INFOPROCESO_HELPER|SEIN ALM PAN TAR/".$case_id : $case_id >> '.json_encode($case_id));
					$ci->load->model(SEIN . 'Proceso_tareas');
				
					$aux = $ci->rest->callAPI("GET",REST_PRO."/pedidoTrabajo/xcaseid/".$case_id);
					 		$data_generico =json_decode($aux["data"]);
					 		$aux = $data_generico->pedidoTrabajo;

					
							 $clie_id = $aux->clie_id;

					$aux_clie = $ci->rest->callAPI("GET",REST_CORE."/cliente/".$clie_id);
					$aux_clie =json_decode($aux_clie["data"]);

						break;
				}

				if (BPM_PROCESS_ID_PEDIDOS_NORMALES == $processId) {
					//	echo ' - Orden Nº: '. $aux["ortr_id"]; valores viejos
					$nombreProceso = 'Nº pedido : '.$aux["pema_id"];
					} elseif (BPM_PROCESS_ID_REPARACION_NEUMATICOS == $processId) {
						$nombreProceso = 'Reparación de Neumáticos';
					}  elseif (BPM_PROCESS_ID_INGRESO_CAMIONES == $processId) {
						$nombreProceso = 'Control de Ingreso de Camiones: ' . $nombreTarea;
					}  elseif (BPM_PROCESS_ID_PROCESO_PRODUCTIVO == $processId) {
						$nombreProceso = 'Tarea: ' . $nombreTarea;
					}else{
						$nombreProceso = 'Proceso Estandar';
					}

?>
				<div class="panel-group" id="accordion" role="tablist" aria-multiselectable="true" style="margin-bottom: 7px !important;">
					<div class="panel panel-default">
						<div class="panel-heading" role="tab" id="headingOne">
							<h4 class="panel-title">
								<a class="collapsed" role="button" data-toggle="collapse" data-parent="#accordion" href="#collapseOne" aria-expanded="false" aria-controls="collapseOne">
									Proceso <?php
												echo $nombreProceso;

													?>
								</a>
							</h4>
						</div>
						<div id="collapseOne" class="panel-collapse collapse" role="tabpanel" aria-labelledby="headingOne">
							<div class="panel-body">

								<?php

									switch ($processId) {

										case BPM_PROCESS_ID_PEDIDOS_NORMALES:
								?>
											<!--_____________ Formulario Solicitud Contenedor_____________-->
											<form class="formNombre1" id="IDnombre">
												<div class="col-md-12">

														<div class="col-md-6">
																<div class="form-group">
																		<label for="generador" name="">Nº pedido:</label>
																		<input type="text" class="form-control habilitar" id="generador" value="<?php echo $aux["pema_id"]; ?>"  readonly>
																</div>
														</div>
														<!--_____________________________________________-->

														<div class="col-md-6">
																<div class="form-group">
																		<label for="pedido" name=""> Estado:</label>
																		<input type="text" class="form-control habilitar" id="pedido" value="<?php echo $aux["estado"]; ?>"  readonly>
																</div>
														</div>
														<!--_____________________________________________-->

														<div class="col-md-6">
															<div class="form-group">
																	<label for="domicilio" name="">Justificacion:</label>
																	<input type="text" class="form-control habilitar" id="domicilio" value="<?php echo $aux["justificacion"]; ?>"  readonly>
															</div>
														</div>
														<!--_____________________________________________-->

														<div class="col-md-6">
																<div class="form-group">
																		<label for="fec_alta" name="">Fecha Alta:</label>
																		<input type="text" class="form-control habilitar" id="fec_alta" value="<?php echo $aux["fec_alta"]; ?>"  readonly>
																</div>
														</div>
													<!--_____________________________________________-->
														
												</div>
											</form>
											<!--_____________ fin forulario solicitud _____________-->
								<?php
											break;

										case BPM_PROCESS_ID_RETIRO_CONTENEDORES:
								?>
											<!--_____________ Formulario Solicitud Retiro_____________-->
											<form class="formNombre1" id="IDnombre">
													<div class="col-md-12">

															<div class="col-md-6">
																	<div class="form-group">
																			<label for="generador" name="">Nº Solicitud Retiro:</label>
																			<input type="text" class="form-control habilitar" id="generador" value="<?php echo $aux->sore_id; ?>"  readonly>
																	</div>
															</div>
															<!--_____________________________________________-->

															<div class="col-md-6">
																	<div class="form-group">
																			<label for="pedido" name=""> Fecha Alta:</label>
																			<input type="text" class="form-control habilitar" id="pedido" value="<?php echo $aux->fec_alta; ?>"  readonly>
																	</div>
															</div>
															<!--_____________________________________________-->
													</div>
											</form> 
								<?php			
											break;
												
										case BPM_PROCESS_ID_ENTREGA_ORDEN_TRANSPORTE:
								?>			
											<!--_____________ Formulario Solicitud Retiro_____________-->
											<form class="formNombre1" id="IDnombre">  
												
													<div class="col-md-12">

															<div class="col-md-6">
																	<div class="form-group">
																			<label for="O_Transporte" name="">Nº Orden de Transporte:</label>
																			<input type="text" class="form-control habilitar" id="O_Transporte" value="<?php echo $aux->ortr_id; ?>"  readonly>
																	</div>
															</div>
															<!--_____________________________________________-->
															
															<div class="col-md-6">
																	<div class="form-group">
																			<label for="f_Alta" name=""> Fecha Alta:</label>
																			<input type="text" class="form-control habilitar" id="f_Alta" value="<?php echo $aux->fec_alta; ?>"  readonly>
																	</div>
															</div>
															<!--_____________________________________________-->
													</div>


													<div class="col-md-12">

															<div class="col-md-6">
																	<div class="form-group">
																			<label for="patente" name="">Dominio:</label>
																			<input type="text" class="form-control habilitar" id="patente" value="<?php echo $aux->dominio; ?>"  readonly>
																	</div>
															</div>
															<!--_____________________________________________-->
															
															<div class="col-md-6">
																	<div class="form-group">
																			<label for="desc_vehiculo" name=""> Descripcion:</label>
																			<input type="text" class="form-control habilitar" id="desc_vehiculo" value="<?php echo $aux->descripcion; ?>"  readonly>
																	</div>
															</div>
															<!--_____________________________________________-->
													</div>


													<div class="col-md-12">

															<div class="col-md-6">
																	<div class="form-group">
																			<label for="nom_chof" name="">Nombre Chofer:</label>
																			<input type="text" class="form-control habilitar" id="nom_chof" value="<?php echo $aux->nom_chofer; ?>"  readonly>
																	</div>
															</div>
															<!--_____________________________________________-->
															
															<div class="col-md-6">
																	<div class="form-group">
																			<label for="f_Alta" name=""> DNI:</label>
																			<input type="text" class="form-control habilitar" id="f_Alta" value="<?php echo $aux->documento; ?>"  readonly>
																	</div>
															</div>
															<!--_____________________________________________-->
													</div>
											</form> 

											<!--_____________ Tabla de Contenedores a Entregar_____________-->
											<table id="" class="table table-bordered table-striped">
													<thead class="thead-dark" bgcolor="#eeeeee">
														<th>Contenedor</th>
														<th>Codigo</th>
														<th>Tipo RSU</th>
														<th>% Llenado</th>
														<th>mts3</th> 
													</thead>                       

													<tbody>		
								<?php						
													if($aux_cont){
														foreach($aux_cont as $fila)
														{
																echo '<tr>';
																echo '<td>'.$fila->cont_id.'</td>';
																echo '<td>'.$fila->codigo.'</td>';
																echo '<td>'.$fila->tipo_carga.'</td>';
																echo '<td>'.$fila->porc_llenado.'</td>';
																echo '<td>'.$fila->mts_cubicos.'</td>';
																echo '</tr>';
														}
													}
								?>			
													<tbody>
											</table>			
								<?php	
											break;

										case BPM_PROCESS_ID_INGRESO_CAMIONES:

											$fec = explode("+" , $aux->fec_inicio);
											$fecha = date("d-m-Y",strtotime($fec[0]));
								?>			
											<!--_____________ Cabecera SICPOA _____________-->
											<div class="col-md-12">
												<h3>Datos ingreso por barrera:</h3>
												<hr>
												<!--_____________ Proceso _____________-->
												<div class="col-md-12">
													<div class="form-group">
														<label for="descripcion" name="">Proceso:</label>
														<input type="text" class="form-control" id="descripcionH" value="<?php echo $aux->descripcion; ?>"  readonly>
													</div>
												</div>
												<!--_____________________________________________-->
												<!--_____________ CASE ID _____________-->
												<div class="col-md-4">
													<div class="form-group">
														<label for="descripcion" name="">N° de inspección:</label>
														<input type="text" class="form-control" id="nro_inspeccionH" value="<?php echo $aux->case_id; ?>"  readonly>
													</div>
												</div>
												<!--_____________________________________________-->
												<!--_____________ PETR ID _____________-->
												<div class="col-md-4">
													<div class="form-group">
														<label for="descripcion" name="">Pedido de trabajo:</label>
														<input type="text" class="form-control" id="pedidoTrabajoH" value="<?php echo $aux->petr_id; ?>"  readonly>
													</div>
												</div>
												<!--_____________________________________________-->
												<!--_____________ Fecha Inicio _____________-->
												<div class="col-md-4">
													<div class="form-group">
														<label for="fecha_inicio" name="">Fecha inicio:</label>
														<input type="text" class="form-control" id="fecha_inicio" value="<?php echo $fecha; ?>"  readonly>
													</div>
												</div>
												<!--_____________________________________________-->
												<!--_____________ USUARIO _____________-->
												<div class="col-md-12">
													<div class="form-group">
														<label for="descripcion" name="">Iniciado por:</label>
														<input type="text" class="form-control" id="usuarioH" value="<?php echo $aux->usuario_app; ?>"  readonly>
													</div>
												</div>
												<!--_____________________________________________-->
											</div>
											<div class="col-md-12">
												<h3>Datos inspección:</h3>
												<hr>
												<!--_____________ Chofer _____________-->
												<div class="col-md-6">
													<ul>
														<li><label for="choferC" name="">Chofer:&nbsp;</label><?php echo $tarea->inspeccion->chofer ? $tarea->inspeccion->chofer : ""; ?></li>
													</ul>
												</div>
												<!--_____________________________________________-->
												<!--_____________ DNI CHOFER _____________-->
												<div class="col-md-6">
													<ul>
														<li><label for="chof_idC" name="">Documento:&nbsp;</label><?php echo $tarea->inspeccion->chof_id ? $tarea->inspeccion->chof_id : ""; ?></li>
													</ul>
												</div>
												<!--_____________________________________________-->
												<!--_____________ Patente tractor _____________-->
												<div class="col-md-6">
													<ul>
														<li><label for="patente_tractorC" name="">Patente tractor:&nbsp;</label><?php echo $tarea->inspeccion->patente_tractor ? $tarea->inspeccion->patente_tractor : ""; ?></li>
													</ul>
												</div>
												<!--_____________________________________________-->
												<!--_________________ N° SENASA _________________-->
												<div class="col-md-6">
													<ul>
														<li><label for="nro_senasaC" name="">N° SENASA:&nbsp;</label><?php echo $tarea->inspeccion->nro_senasa ? $tarea->inspeccion->nro_senasa : ""; ?></li>
													</ul>
												</div>
												<!--______________________________________________-->
												<!--__________________ PERMISOS __________________-->
												<div class="col-md-12 col-sm-12 col-xs-12">
													<h4>Permisos:</h4>
													<ul>
														<?php 
														if(!empty($tarea->inspeccion->permisos_transito->permiso_transito)){
															foreach ($tarea->inspeccion->permisos_transito->permiso_transito as $key) {
																echo "<li><b>Id</b>:  $key->perm_id   ---   <b>Tipo</b>:  $key->tipo   ---   <b>Emisión</b>:  $key->lugar_emision   ---   <b>Fecha</b>:  $key->fecha_hora_salida </li>";
															}
														}
														?>
													</ul>
												</div>
												<!--______________________________________________-->
												<div class="col-md-12 col-sm-12 col-xs-12">
													<h4>Empresas:</h4>
													<ul>
													<?php 
														if(!empty($tarea->inspeccion->empresas->empresa)){
															foreach ($tarea->inspeccion->empresas->empresa as $key) {
																echo "<li><b>Razón Social</b>:  $key->razon_social   ---   <b>Rol</b>:  $key->rol".($key->calle ? "   ---   <b>Calle</b>:  ".$key->calle : "" )."".($key->altura ? "   ---   <b>Altura</b>:  ".$key->altura : "")." </li>";	
															}
														}
													?>
													</ul>
												</div>
												<!--______________________________________________-->
												<div class="col-md-12 col-sm-12 col-xs-12">
													<h4>Térmicos:</h4>
													<ul>
														<?php 
															if(!empty($tarea->inspeccion->termicos->termico)){
																foreach ($tarea->inspeccion->termicos->termico as $key) {
																	echo "<li><b>Patente</b>:  $key->patente   ---   <b>T°</b>:  $key->temperatura   ---   <b>Precintos</b>:  $key->precintos</li>";
																}
															}
														?>
													</ul>
												</div>
												<!--______________________________________________-->
												<div class="col-md-12 col-sm-12 col-xs-12">
													<h4>Fotos Ingreso por barrera:</h4>
													<!--CSS-->
													<style>
													.fotos{
														float: left;
														margin-right: 10px;
														display: block;
													}
													#expandedImgC{
														margin-right: auto;
														margin-left:auto;
														display: block;
														max-width: 60%;
													}
													</style>
													<!-- FIN CSS -->
													<div class="row">
														<div class="col-md-12 col-sm-12 col-xs-12">
															<div class="fotos">
																<?php foreach ($tarea->imgsBarrera as $key => $value) {
																	echo "<img class='thumbnail fotos barrera' height='51' width='45' src='$value' alt='' onclick='previewC(this)'>";
																} ?>
															</div>
														</div>
													</div>
													<script>
													function previewC(imgs) {
														var expandImg = document.getElementById("expandedImgC");
														expandImg.src = imgs.src;
													}
													</script>
													<hr>
													<div class="col-sm-12 col-md-12 col-xl-12">
														<div class="contenedor">
															<img src="lib\imageForms\preview.png" id="expandedImgC" >
														</div>
													</div>
												</div>
												<!--______________________________________________-->
											</div><!-- fin col-md --> 
											<!--_____________FIN CABECERA SICPOA_____________-->
								<?php			
											break;	
											
						/*
						DEFAULT DE CABECERA
						* todo lo que pasa x aka debe ser standar de tools
						*/
							default :
							// $data =json_decode($aux);

									?>
									<div class="col-md-3">
										<div class="form-group">
											<label for="generador" name="">Nº pedido:</label>
											<input type="text" class="form-control habilitar" style="font-family: Arial; font-size: 16pt;" id="petr_id" value="<?php echo $aux->petr_id; ?>"  readonly>
										</div>
									</div>
									<div class="col-md-12">
									<p>Datos del Cliente:</p>
									<hr>
										<div class="col-md-6 animated fadeInLeft">
											<div class="form-group">
													<label for="cliente" name="">Cliente:</label>
													<input type="text" class="form-control habilitar" id="cliente" value="<?php echo $aux_clie->cliente->nombre; ?>"  readonly>
											</div>
										</div>


										<div class="col-md-6 animated fadeInLeft">
											<div class="form-group">
													<label for="dir_entrega" name="">Dirección de Entrega:</label>
													<input type="text" class="form-control habilitar" id="dir_entrega" value="<?php echo $aux_clie->cliente->dir_entrega; ?>"  readonly>
											</div>
										</div>
								
									<div class="col-md-12">
									<br>
									<p>Datos del Proyecto:</p>
									<hr>
									<div class="col-md-12 animated fadeInLeft">
											<div class="form-group">
													<label for="tipo_proyecto" name="">Tipo de Proyecto:</label>
													<input type="text" class="form-control habilitar" id="tipo_proyecto" value="<?php echo $aux->tipo; ?>"  readonly>
											</div>
									</div>
									<!--_____________________________________________-->

									<div class="col-md-6 animated fadeInLeft">
											<div class="form-group">
													<label for="codigo_proyecto" name="">Codigo Proyecto:</label>
													<input type="text" class="form-control habilitar" id="codigo_proyecto" value="<?php echo $aux->cod_proyecto; ?>"  readonly>
											</div>
									</div>
									<!--_____________________________________________-->

									<div class="col-md-6 animated fadeInLeft">
											<div class="form-group">
													<label for="descripcion" name=""> Descripcion:</label>
													<input type="text" class="form-control habilitar" id="descripcion" value="<?php echo $aux->descripcion; ?>"  readonly>
											</div>
									</div>
									<!--_____________________________________________-->
								</div>


								<div class="col-md-12 animated fadeInLeft">

									<div class="col-md-6">
											<div class="form-group">
													<label for="fecha_inicio" name="">Fecha Inicio:</label>
													<input type="text" class="form-control habilitar" id="fec_inicio" value="<?php
															

																								
     											$fecha_inicio = date("d-m-Y",strtotime(str_replace('T', ' ', $aux->fec_inicio)));

										
													echo $fecha_inicio ;
													
													?>"  readonly>
											</div>
									</div>
									<!--_____________________________________________-->

									<div class="col-md-6 animated fadeInLeft">
											<div class="form-group">
													<label for="fecha_entrega" name=""> Fecha Entrega:</label>
													<input type="text" class="form-control habilitar" id="fec_entrega" value="<?php
																									
														$fecha_entrega = date("d-m-Y",strtotime(str_replace('T', ' ', $aux->fec_entrega)));
														
														echo $fecha_entrega ;
														
														?>"  readonly>
											</div>
									</div>
									<!--_____________________________________________-->
								</div>


								<div class="col-md-12 animated fadeInLeft">

									<div class="col-md-6">
											<div class="form-group">
													<label for="objetivo" name="">Objetivo:</label>
													<input type="text" class="form-control habilitar" id="objetivo" value="<?php echo $aux->objetivo; ?>"  readonly>
											</div>
									</div>
									<div class="col-md-6">
											<div class="form-group">
													<label for="unidad_medida" name="">Unidad medida:</label>
													<input type="text" class="form-control habilitar" id="unidad_medida" value="<?php echo $aux->unidad_medida; ?>"  readonly>
											</div>
									</div>
								
									<!--_____________________________________________-->
									<div class="col-md-12 animated fadeInLeft">
									<?php
									
									if ($processId !='' )
										{
											$info_id = $aux->info_id;

											$formulario = getForm($info_id);
									
										}

										?>
									<div id="form-dinamico-cabecera" data-frm-id="<?php echo "frm-".$info_id;?>">
									<?php
											
											echo $formulario;

									?>
										<script>
											$(".frm-select").select2();
										var formulario = $('#form-dinamico-cabecera').attr('data-frm-id');
										
										
										$('#form-dinamico-cabecera button.frm-save').addClass('oculto');
										
								
										$('#form-dinamico-cabecera').find(':input').each(function() {
										var elemento= this;
										console.log("elemento.id="+ elemento.id); 

										$(elemento).attr('readonly', true); 

										$(elemento).attr('disabled',true);
												});
												
										</script>
									
									</div>

								</div>
								
<!--_____________________________________________-->

									<?php			
											break;
									}

								?>										
								
								
							</div>
						</div>
					</div>
					
					
				</div>


				<?php
			}
			
	}

?>