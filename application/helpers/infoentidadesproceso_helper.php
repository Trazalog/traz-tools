<?php defined('BASEPATH') OR exit('No direct script access allowed');

  /**
  * cabeceras informacion Generadores y Transpoortistas
  *
  * @autor Hugo Gallardo
  */
  if(!function_exists('infoentidadesproceso')){

      function infoentidadesproceso($tarea){

        $ci2 =& get_instance();
        $ent_case_id = $tarea->caseId;
        $processId = $tarea->processId;

        switch ($processId) {
          case BPM_PROCESS_ID_SOLICITUD_CONTENEDORES:
              log_message('DEBUG','#TRAZA | INFOENTIDADESPROCESO_HELPER | infoentidadesproceso($tarea) >> '.json_encode($tarea));
              log_message('DEBUG','#TRAZA | INFOENTIDADESPROCESO_HELPER | infoentidadesproceso($tarea) $ent_case_id: >> '.json_encode($ent_case_id));
              $aux_gen = $ci2->rest->callAPI("GET",REST_RESI."/solicitantesTransporte/case/".$ent_case_id);
              $aux_gen =json_decode($aux_gen["data"]);

              $aux_tran = $ci2->rest->callAPI("GET",REST_RESI."/transportistas/case/".$ent_case_id);
              $aux_tran =json_decode($aux_tran["data"]);
            break;

          case BPM_PROCESS_ID_SOLICITUD_RETIRO_CONTENEDORES:
              log_message('DEBUG','#TRAZA | INFOENTIDADESPROCESO_HELPER | infoentidadesproceso($tarea) >> '.json_encode($tarea));
              log_message('DEBUG','#TRAZA | INFOENTIDADESPROCESO_HELPER | infoentidadesproceso($tarea) $ent_case_id: >> '.json_encode($ent_case_id));
              $aux_gen = $ci2->rest->callAPI("GET",REST_RESI."/solicitantesTransporte/proceso/retiro/case/".$ent_case_id);
              $aux_gen =json_decode($aux_gen["data"]);

              $aux_tran = $ci2->rest->callAPI("GET",REST_RESI."/transportistas/proceso/retiro/case/".$ent_case_id);
              $aux_tran =json_decode($aux_tran["data"]);
            break;

          case BPM_PROCESS_ID_ORDEN_TRANSPORTE:
              log_message('DEBUG','#TRAZA | INFOENTIDADESPROCESO_HELPER | infoentidadesproceso($tarea) >> '.json_encode($tarea));
              log_message('DEBUG','#TRAZA | INFOENTIDADESPROCESO_HELPER | infoentidadesproceso($tarea) $ent_case_id: >> '.json_encode($ent_case_id));

              $aux_gen = $ci2->rest->callAPI("GET",REST_RESI."/solicitantesTransporte/proceso/ingreso/case/".$ent_case_id);
              $aux_gen =json_decode($aux_gen["data"]);

              $aux_tran = $ci2->rest->callAPI("GET",REST_RESI."/transportistas/proceso/ingreso/case/".$ent_case_id);
              $aux_tran =json_decode($aux_tran["data"]);
            break;

          default:
            # code...
            break;
        }

?>

			<div class="panel-group" id="accordion" role="tablist" aria-multiselectable="true" style="margin-bottom: 7px !important;">	
				<div class="panel panel-default">
					<div class="panel-heading" role="tab" id="headingTwo">
						<h4 class="panel-title">
							<a class="collapsed" role="button" data-toggle="collapse" data-parent="#accordion" href="#collapseTwo" aria-expanded="false" aria-controls="collapseTwo">
								Generador y Transportista
							</a>
						</h4>
					</div>
					<div id="collapseTwo" class="panel-collapse collapse" role="tabpanel" aria-labelledby="headingTwo">
						<div class="panel-body">
              <div>
                  <!-- Nav tabs -->
                  <ul class="nav nav-tabs" role="tablist">
                    <li role="presentation" class="active"><a href="#tab_generador" aria-controls="tab_generador" role="tab" data-toggle="tab">Generador</a></li>
                    <li role="presentation" class="privado"><a href="#tab_transportista" aria-controls="tab_transportista" role="tab" data-toggle="tab">Transportista</a></li>
                  </ul>
                  <!-- Tab panes -->
                  <div class="tab-content">
                    <div class="tab-pane active" id="tab_generador">
                      <!--_____________ Formulario Generador _____________-->
                      <form class="formNombre1" id="formGenerador">  
                        <div class="col-md-12">
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label for="razon_social" name="">Razón Social:</label>
                                    <input type="text" class="form-control habilitar" id="razon_social" value="<?php echo $aux_gen->generador->razon_social; ?>"  readonly>
                                </div>
                            </div>
                            <!--_____________________________________________-->
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label for="cuit" name=""> CUIT:</label>
                                    <input type="text" class="form-control habilitar" id="cuit" value="<?php echo $aux_gen->generador->cuit; ?>"  readonly>
                                </div>
                            </div>
                            <!--_____________________________________________-->
                            <div class="col-md-6">
                              <div class="form-group">
                                  <label for="domicilio" name="">Dirección:</label>
                                  <input type="text" class="form-control habilitar" id="domicilio" value="<?php echo $aux_gen->generador->domicilio; ?>"  readonly>
                              </div>
                            </div>
                            <!--_____________________________________________-->
                            <div class="col-md-6">
                              <div class="form-group">
                                  <label for="num_registro" name="">Nº Registro:</label>
                                  <input type="text" class="form-control habilitar" id="num_registro" value="<?php echo $aux_gen->generador->num_registro; ?>"  readonly>
                              </div>
                            </div>
                            <!--_____________________________________________-->

                            <div class="col-md-6">
                              <div class="form-group">
                                  <label for="tipo_generador" name="">Tipo Generador:</label>
                                  <input type="text" class="form-control habilitar" id="tipo_generador" value="<?php echo $aux_gen->generador->tipo_generador; ?>"  readonly>
                              </div>
                            </div>
                            <!--_____________________________________________-->
                            <div class="col-md-6">
                              <div class="form-group">
                                  <label for="departamento" name="">Departamento:</label>
                                  <input type="text" class="form-control habilitar" id="departamento" value="<?php echo $aux_gen->generador->departamento; ?>"  readonly>
                              </div>
                            </div>
                            <!--_____________________________________________-->
                            <div class="col-md-6">
                              <div class="form-group">
                                  <label for="zona" name="">Zona:</label>
                                  <input type="text" class="form-control habilitar" id="zona" value="<?php echo $aux_gen->generador->zona; ?>"  readonly>
                              </div>
                            </div>
                            <!--_____________________________________________-->
                            <div class="col-md-6">
                              <div class="form-group">
                                  <label for="rubro" name="">Rubro:</label>
                                  <input type="text" class="form-control habilitar" id="rubro" value="<?php echo $aux_gen->generador->rubro; ?>"  readonly>
                              </div>
                            </div>
                            <!--_____________________________________________-->
                            <div class="col-md-6" style="display: none;">
                              <div class="form-group">
                                  <label for="rubro" name="">Tipos de RSU:</label>
                                  <input type="text" class="form-control habilitar" id="rubro" value="<?php 
                                    // foreach ($aux_gen->generador->tiposCarga->carga as $tipocarga) {
                                    //   echo $tipocarga->valor.', ';
                                    // }
                                   ?>"  readonly>
                              </div>
                            </div>
                            <!--_____________________________________________-->
                        </div>
                      </form>
                      <!--_____________ Fin Formulario Generador _____________-->
                    </div>
                    <div class="tab-pane" id="tab_transportista">
                      <!--_____________ Formulario Transportista _____________-->
                      <form class="formNombre1" id="formTransportista">
                        <div class="col-md-12">
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label for="razon_social_tran" name="">Razón Social:</label>
                                    <input type="text" class="form-control habilitar" id="razon_social_tran" value="<?php echo $aux_tran->transportista->razon_social; ?>"  readonly>
                                </div>
                            </div>
                            <!--_____________________________________________-->
                            
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label for="cuit_tran" name=""> CUIT:</label>
                                    <input type="text" class="form-control habilitar" id="cuit_tran" value="<?php echo $aux_tran->transportista->cuit; ?>"  readonly>
                                </div>
                            </div>
                            <!--_____________________________________________-->
        
                            <div class="col-md-6">
                              <div class="form-group">
                                  <label for="direccion" name="">Dirección:</label>
                                  <input type="text" class="form-control habilitar" id="direccion" value="<?php echo $aux_tran->transportista->direccion; ?>"  readonly>
                              </div>
                            </div>
                            <!--_____________________________________________-->
        
                            <div class="col-md-6">
                              <div class="form-group">
                                  <label for="registro" name="">Nº Registro:</label>
                                  <input type="text" class="form-control habilitar" id="registro" value="<?php echo $aux_tran->transportista->registro; ?>"  readonly>
                              </div>
                            </div>
                            <!--_____________________________________________-->

                            <div class="col-md-6">
                              <div class="form-group">
                                  <label for="resolucion" name="">Resolución:</label>
                                  <input type="text" class="form-control habilitar" id="resolucion" value="<?php echo $aux_tran->transportista->resolucion; ?>"  readonly>
                              </div>
                            </div>
                            <!--_____________________________________________-->

                                                       
                        </div>
                      </form>
                      <!--_____________ fin forulario Transportista _____________-->
                      
                    </div>
                    
                  </div>

              </div>

						</div>
					</div>
				</div>				
			</div>

<?php

    }

}