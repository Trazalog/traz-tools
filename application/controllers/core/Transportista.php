<?php defined('BASEPATH') OR exit('No direct script access allowed');

class Transportista extends CI_Controller 
{
    function __construct(){
      parent::__construct();
      $this->load->model('core/Transportistas');    
    } 

    /**
	*  Muestra el ABM de los transportistas.
	*
	* @param
	* @return  void
	*/
    function index()
	{
		log_message('INFO','#TRAZA | TRANSPORTISTAS | index()  >> ');
		$data['tipos_transportistas'] = $this->Transportistas->Listar_Tipos_Transportistas();
		$this->load->view('core/transportistas/view', $data);
    }
    
 	/**
	* Devuelve un listado de las Transportistas.
	*
	* @return  Array   Devuelve un arreglo con las Transportistas.
	*/
	function Listar_Transportistas()
	{
		log_message('INFO','#TRAZA| TRANSPORTISTAS | Listar_Transportistas() >> ');
		$data['list'] = $this->Transportistas->Listar_Transportistas();
    	$this->load->view('core/transportistas/list', $data);
	}

    /**
	* Guarda transportista
	* @param array transportista
	* @return bool true o false segun resultado de servicio de guardado
	*/
	function Guardar_Transportista()
	{
		$transportista = $this->input->post('datos');
		$transportista['usuario_app'] = userNick();
		$transportista['empr_id'] = empresa();
		$resp = $this->Transportistas->Guardar_Transportista($transportista);
		echo json_encode($resp);
    	log_message('ERROR', '#TRAZA | TRANSPORTISTAS | guardar() >> $transportista_id: '.$transportista);
		// if ($resp != null) {
		// 	return json_encode(true);
		// } else {
		// 	return json_encode(false);
		// }
	}

	/**
	* Edita info de Transportista
	* @param array con informacion de Transportista
	* @return bool true o false respuesta del servicio
	*/
	function Editar_Transportista()
	{
    	log_message('INFO','#TRAZA | TRANSPORTISTAS | Editar_Transportista() >> ');
		$transportista = $this->input->post('datos');
		$transportista['usuario_app'] = userNick();
		$resp = $this->Transportistas->Editar_Transportista($transportista);
		echo json_encode($resp);
	}

	/**
	* Borra Transportista por id
	* @param
	* @return bool true o false
	*/
	public function Borrar_Transportista()
	{
		log_message('INFO','#TRAZA | TRANSPORTISTAS | Borrar_Transportista() >> ');
		$cuit = $this->input->post('cuit');
		$result = $this->Transportistas->Borrar_Transportista($cuit);
		echo json_encode($result);
	}
}    