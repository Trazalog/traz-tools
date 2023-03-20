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
		$data['tipos_transporte'] = $this->Transportistas->getTiposTransporte();
		$data['listarPaises'] = $this->Transportistas->listarPaises();
		$this->load->view('core/transportistas/view', $data);
    }

	/**
	* Devuelve un listado de estados dependiendo del id de pais que le enviemos.
	*
	* @return  Array   Devuelve un arreglo con estados.
	*/
	public function getEstados()
	{
		log_message('INFO','#TRAZA| TRANSPORTISTAS | getEstados() >> ');
		$pais = $this->input->post('id_pais');
		$resp = $this->Transportistas->getEstados($pais);
		echo json_encode($resp);
	}

	/**
	* Devuelve un listado de localidades dependiendo del id de estado que le enviemos.
	*
	* @return  Array   Devuelve un arreglo con localidades.
	*/
	public function getLocalidades()
	{
		log_message('INFO','#TRAZA| TRANSPORTISTAS | getLocalidades() >> ');
		$pais = $this->input->post('id_pais');
		$estado = $this->input->post('id_estado');
		$resp = $this->Transportistas->getLocalidades($pais, $estado);
		echo json_encode($resp);
	}

	/**
	* Devuelve un listado de tipos de transporte.
	*
	* @return  Array   Devuelve un arreglo con tipos de transporte.
	*/
	// public function getTiposTransporte()
	// {
	// 	log_message('INFO','#TRAZA| TRANSPORTISTAS | getTiposTransporte() >> ');
	// 	$resp = $this->Transportistas->getTiposTransporte();
	// 	echo json_encode($resp);
	// }
    
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
		$data = $this->input->post('datos');
		$pais_id = urlencode($data['pais_id']);
		$prov_id = urldecode($data['prov_id']);
		$loca_id = urldecode($data['loca_id']);
		$data['empr_id'] = empresa();
		$data['pais_id'] = $pais_id;
		$data['prov_id'] = $prov_id;
		$data['loca_id'] = $loca_id;
		$data['tipo_transporte'] = urldecode($data['tipo_transporte']);
		$resp = $this->Transportistas->Guardar_Transportista($data);
		if ($resp['status']) {
			$resp['message'] = "Se agregó el transportista correctamente";
		}else{
			$resp['message'] = "Se produjo un error al guardar el transportista";
		}
		echo json_encode($resp);
    	log_message('ERROR', '#TRAZA | TRANSPORTISTAS | guardar() >> $transportista_id: '.$data);
	}

	/**
	* Edita info de Transportista
	* @param array con informacion de Transportista
	* @return bool true o false respuesta del servicio
	*/
	function Editar_Transportista()
	{
    	log_message('INFO','#TRAZA | TRANSPORTISTAS | Editar_Transportista() >> ');
		$data = $this->input->post('datos');
		$pais_id = urlencode($data['pais_id']);
		$prov_id = urldecode($data['prov_id']);
		$loca_id = urldecode($data['loca_id']);
		$data['empr_id'] = empresa();
		$data['pais_id'] = $pais_id;
		$data['prov_id'] = $prov_id;
		$data['loca_id'] = $loca_id;
		$data['tipo_transporte'] = urldecode($data['tipo_transporte']);
		$resp = $this->Transportistas->Editar_Transportista($data);
		if ($resp['status']) {
			$resp['message'] = "Se editó el transportista correctamente";
		}else{
			$resp['message'] = "Se produjo un error al editar el transportista";
		}
		echo json_encode($resp);
    	log_message('ERROR', '#TRAZA | TRANSPORTISTAS | guardar() >> $transportista_id: '.$data);
	}

	/**
	* Borra Transportista por id
	* @param
	* @return bool true o false
	*/
	public function Borrar_Transportista()
	{
		log_message('INFO','#TRAZA | TRANSPORTISTAS | Borrar_Transportista() >> ');
		$tran_id = $this->input->post('tran_id');
		$result = $this->Transportistas->Borrar_Transportista($tran_id);
		echo json_encode($result);
	}

	/**
	* Valida que el CUIT del transportista no este repetido
	* @param
	* @return bool true o false
	*/
	public function Validar_Cuit () {
		log_message('INFO','#TRAZA| TRANSPORTISTAS | Validar_cuit() >> ');
		$cuit = $this->input->post('datos');
		$result = $this->Transportistas->Validar_cuit($cuit);
		echo $result;
		
		
	}
}    