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
				$data['processId']=$processId;

				switch ($processId) {
					case BPM_PROCESS_ID_PEDIDOS_NORMALES:

							log_message('INFO','#TRAZA|INFOPROCESO_HELPER|/solicitudContenedores/info/.$case_id): $case_id >> '.json_encode($case_id));
							$ci->load->model(ALM . 'Notapedidos');
							$data['info'] = $ci->Notapedidos->getXCaseId($tarea->caseId);
							
							
							// $aux = $ci->rest->callAPI("GET",REST_PRD."/solicitudContenedores/info/".$case_id);
							// $aux =json_decode($aux["data"]);
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


				default:
						
					log_message('INFO','#TRAZA|INFOPROCESO_HELPER|chuka/".$case_id : $case_id >> '.json_encode($case_id));
					$ci->load->model(YUDIPROC . 'Yudiproctareas');
				
					$aux = $ci->rest->callAPI("GET",REST_PRO."/pedidoTrabajo/xcaseid/".$case_id);
					 		$data_generico =json_decode($aux["data"]);
					 		$aux = $data_generico->pedidoTrabajo;

					//HARCODE CHUKA	
							 $clie_id = $aux->clie_id;

					$aux_clie = $ci->rest->callAPI("GET",REST_CORE."/cliente/".$clie_id);
					$aux_clie =json_decode($aux_clie["data"]);

						break;
				}

?>
				<div class="panel-group" id="accordion" role="tablist" aria-multiselectable="true" style="margin-bottom: 7px !important;">
					<div class="panel panel-default">
						<div class="panel-heading" role="tab" id="headingOne">
							<h4 class="panel-title">
								<a class="collapsed" role="button" data-toggle="collapse" data-parent="#accordion" href="#collapseOne" aria-expanded="false" aria-controls="collapseOne">
									Proceso <?php
														if (BPM_PROCESS_ID_PEDIDOS_NORMALES == $processId) {
															echo ' - Orden Nº: '.$aux->ortr_id;
														} elseif (BPM_PROCESS_ID_REPARACION_NEUMATICOS == $processId) {
															echo 'Reparación de Neumáticos';
														}

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
																		<input type="text" class="form-control habilitar" id="generador" value="<?php echo $data->info->pema_id; ?>"  readonly>
																</div>
														</div>
														<!--_____________________________________________-->

														<div class="col-md-6">
																<div class="form-group">
																		<label for="pedido" name=""> Estado:</label>
																		<input type="text" class="form-control habilitar" id="pedido" value="<?php echo $data->info->estado; ?>"  readonly>
																</div>
														</div>
														<!--_____________________________________________-->

														<div class="col-md-6">
															<div class="form-group">
																	<label for="domicilio" name="">Justificacion:</label>
																	<input type="text" class="form-control habilitar" id="domicilio" value="<?php echo $data->info->justificacion; ?>"  readonly>
															</div>
														</div>
														<!--_____________________________________________-->

														<div class="col-md-6">
																<div class="form-group">
																		<label for="fec_alta" name="">Fecha Alta:</label>
																		<input type="text" class="form-control habilitar" id="fec_alta" value="<?php echo $data->info->fec_alta; ?>"  readonly>
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
											
								
											
							##############YUDICA CHUKA	
							default :
							$data =json_decode($aux,true);

									?>
									<div class="col-md-12">
									<p>Datos del Cliente:</p>
									<hr>
										<div class="col-md-6">
											<div class="form-group">
													<label for="cliente" name="">Cliente:</label>
													<input type="text" class="form-control habilitar" id="cliente" value="<?php echo $aux_clie->cliente->nombre; ?>"  readonly>
											</div>
										</div>


										<div class="col-md-6">
											<div class="form-group">
													<label for="dir_entrega" name="">Dirección de Entrega:</label>
													<input type="text" class="form-control habilitar" id="dir_entrega" value="<?php echo $aux_clie->cliente->dir_entrega; ?>"  readonly>
											</div>
										</div>
									</div>
									<!--_____________________________________________-->

									<div class="col-md-12">
									<br>
									<p>Datos del Proyecto:</p>
									<hr>
									<div class="col-md-6">
											<div class="form-group">
													<label for="codigo_proyecto" name="">Codigo Proyecto:</label>
													<input type="text" class="form-control habilitar" id="codigo_proyecto" value="<?php echo $aux->cod_proyecto; ?>"  readonly>
											</div>
									</div>
									<!--_____________________________________________-->

									<div class="col-md-6">
											<div class="form-group">
													<label for="descripcion" name=""> Descripcion:</label>
													<input type="text" class="form-control habilitar" id="descripcion" value="<?php echo $aux->descripcion; ?>"  readonly>
											</div>
									</div>
									<!--_____________________________________________-->
								</div>


								<div class="col-md-12">

									<div class="col-md-6">
											<div class="form-group">
													<label for="fecha_inicio" name="">Fecha Inicio:</label>
													<input type="text" class="form-control habilitar" id="patente" value="<?php
															

																								
     											$fecha = date("d-m-Y",strtotime($data->fec_inicio));

													// 	  $fecha =	date('d-m-Y', strtotime($data->fec_inicio)) . '+00:00:00';

													echo $fecha ;
													
													?>"  readonly>
											</div>
									</div>
									<!--_____________________________________________-->

									<div class="col-md-6">
											<div class="form-group">
													<label for="fecha_entrega" name=""> Fecha Entrega:</label>
													<input type="text" class="form-control habilitar" id="descripcion" value="<?php
																									
														$fecha = date("d-m-Y",$data->fec_entrega);
														
														echo $fecha ;
														
														?>"  readonly>
											</div>
									</div>
									<!--_____________________________________________-->
								</div>


								<div class="col-md-12">

									<div class="col-md-12">
											<div class="form-group">
													<label for="objetivo" name="">Objetivo:</label>
													<input type="text" class="form-control habilitar" id="objetivo" value="<?php echo $aux->objetivo; ?>"  readonly>
											</div>
									</div>
								
									<!--_____________________________________________-->
									<div class="col-md-12">
									<?php
									
									if ($processId == BPM_PROCESS_ID_REPARACION_NEUMATICOS )
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
										var formulario = $('#form-dinamico-cabecera').attr('data-frm-id');
										
										
										$('#form-dinamico-cabecera button.frm-save').addClass('oculto');
										
								
										$('#form-dinamico-cabecera').find(':input').each(function() {
										var elemento= this;
										console.log("elemento.id="+ elemento.id); 

										var new_elemento = "#"+elemento.id;
										
										$(new_elemento).attr('readonly', true); 

										
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
