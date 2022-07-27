<?php defined('BASEPATH') OR exit('No direct script access allowed');

class Envase extends CI_Controller 
{
    function __construct(){
      parent::__construct();
      $this->load->model('core/Envases');    
    } 

    /**
	 *  Muestra el ABM de los envases.
	 *
	 * @param
	 * @return  void
	 */

    function index(){
      log_message('INFO','#TRAZA | ENVASES | index()  >> ');
	  $data['listadoFormulas'] = $this->Envases->Listar_Formulas();
	  $data['listadoUnidades'] = $this->Envases->Listar_Unidades_Medidas();
    //   $data['list'] = $this->Envases->Listar_Envases();
    //   $data['tipos_envases'] = $this->Envases->Listar_Tipos_Envases();
      $this->load->view('core/envases/view', $data);
    }
    
 /**
     * Devuelve un listado de las Envases.
     *
     * @return  Array   Devuelve un arreglo con las Envases.
     */
		function Listar_Envases()
	{
		log_message('INFO','#TRAZA| ENVASES | Listar_Envases() >> ');
		$data['list'] = $this->Envases->Listar_Envases();
    	$this->load->view('core/envases/list', $data);
	}
    /**
	* Guarda envase
	* @param array envase
	* @return bool true o false segun resultado de servicio de guardado
	*/
	function Guardar_Envase()
	{
		log_message('ERROR', '#TRAZA | ENVASES | guardar()');
		$envase = $this->input->post('datos');
		$resp = $this->Envases->Guardar_Envase($envase);
		if ( !$resp ) {
			log_message('ERROR', '#TRAZA | ENVASES | guardar()');
			echo json_encode(false);
			return;
		} else {
			echo json_encode(true);
			return;
		}
	}

	/**
	* Edita info de Envase
	* @param array con informacion de Envase
	* @return bool true o false respuesta del servicio
	*/
	function Editar_Envase()
	{
    log_message('INFO','#TRAZA | ENVASES | Editar_Envase() >> ');
		$envase = $this->input->post('datos');
		// $envase['usuario_app'] = userNick();
		$resp = $this->Envases->Editar_Envase($envase);
		echo json_encode($resp);
	}

	/**
	* Borra Envase por id
	* @param
	* @return bool true o false
	*/
	public function Borrar_Envase()
	{
		log_message('INFO','#TRAZA | ENVASES | Borrar_Envase() >> ');
		$empa_id = $this->input->post('empa_id');
		$result = $this->Envases->Borrar_Envase($empa_id);
		echo json_encode($result);
	}
}    