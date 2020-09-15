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

				switch ($processId) {
					case BPM_PROCESS_ID_PEDIDO_CONTENEDORES:

							log_message('INFO','#TRAZA|INFOPROCESO_HELPER|/solicitudContenedores/info/.$case_id): $case_id >> '.json_encode($case_id));
							$aux = $ci->rest->callAPI("GET",REST."/solicitudContenedores/info/".$case_id);
							$aux =json_decode($aux["data"]);
						break;

					case BPM_PROCESS_ID_RETIRO_CONTENEDORES:

							log_message('INFO','#TRAZA|INFOPROCESO_HELPER|/solicitudRetiro/proceso/retiro/case/.$case_id): $case_id >> '.json_encode($case_id));
							$aux = $ci->rest->callAPI("GET",REST."/solicitudRetiro/proceso/retiro/case/".$case_id);
							$data =json_decode($aux["data"]);
							$aux = $data->solicitud_retiro;
						break;

					case BPM_PROCESS_ID_ENTREGA_ORDEN_TRANSPORTE:

							log_message('INFO','#TRAZA|INFOPROCESO_HELPER|/ordenTransporte/info/entrega/case/".$case_id : $case_id >> '.json_encode($case_id));

							$aux = $ci->rest->callAPI("GET",REST."/ordenTransporte/info/entrega/case/".$case_id);
							$data =json_decode($aux["data"]);
							$aux = $data->ordenTransporte;

							$aux_cont = $ci->rest->callAPI("GET",REST."/contenedoresEntregados/info/entrega/case/".$case_id);
							$data_cont =json_decode($aux_cont["data"]);
							$aux_cont = $data_cont->contenedores->contenedor;
						break;

					default:
						# code...
						break;
				}

?>
				<div class="panel-group" id="accordion" role="tablist" aria-multiselectable="true" style="margin-bottom: 7px !important;">
					<div class="panel panel-default">
						<div class="panel-heading" role="tab" id="headingOne">
							<h4 class="panel-title">
								<a class="collapsed" role="button" data-toggle="collapse" data-parent="#accordion" href="#collapseOne" aria-expanded="false" aria-controls="collapseOne">
									Proceso <?php
														if (BPM_PROCESS_ID_ENTREGA_ORDEN_TRANSPORTE == $processId) {
															echo ' - Orden Transporte Nº: '.$aux->ortr_id;
														}

													?>
								</a>
							</h4>
						</div>
						<div id="collapseOne" class="panel-collapse collapse" role="tabpanel" aria-labelledby="headingOne">
							<div class="panel-body">

								<?php

									switch ($processId) {

										case BPM_PROCESS_ID_PEDIDO_CONTENEDORES:
								?>
											<!--_____________ Formulario Solicitud Contenedor_____________-->
											<form class="formNombre1" id="IDnombre">
												<div class="col-md-12">

														<div class="col-md-6">
																<div class="form-group">
																		<label for="generador" name="">Nº Solicitud:</label>
																		<input type="text" class="form-control habilitar" id="generador" value="<?php echo $aux->solicitud->soco_id; ?>"  readonly>
																</div>
														</div>
														<!--_____________________________________________-->

														<div class="col-md-6">
																<div class="form-group">
																		<label for="pedido" name=""> Estado:</label>
																		<input type="text" class="form-control habilitar" id="pedido" value="<?php echo $aux->solicitud->estado; ?>"  readonly>
																</div>
														</div>
														<!--_____________________________________________-->

														<div class="col-md-6">
															<div class="form-group">
																	<label for="domicilio" name="">Observacion:</label>
																	<input type="text" class="form-control habilitar" id="domicilio" value="<?php echo $aux->solicitud->observaciones; ?>"  readonly>
															</div>
														</div>
														<!--_____________________________________________-->

														<div class="col-md-6">
																<div class="form-group">
																		<label for="fec_alta" name="">Fecha Alta:</label>
																		<input type="text" class="form-control habilitar" id="fec_alta" value="<?php echo $aux->solicitud->fec_alta; ?>"  readonly>
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
										
										default:
											# code...
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