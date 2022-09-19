<?php defined('BASEPATH') OR exit('No direct script access allowed');

class Cliente extends CI_Controller 
{
    function __construct(){
      parent::__construct();
      $this->load->model('core/Clientes');    
    } 

    /**
	*  Muestra el ABM de los clientes.
	*
	* @param
	* @return  void
	*/
    function index()
	{
    	log_message('INFO','#TRAZA | CLIENTES | index()  >> ');
    	$data['list'] = $this->Clientes->Listar_Clientes();
    	$data['tipos_clientes'] = $this->Clientes->Listar_Tipos_Clientes();
    	$this->load->view('core/clientes/view', $data);
    }
    
	/**
	* Devuelve un listado de las Clientes.
	*
	* @return  Array   Devuelve un arreglo con las Clientes.
	*/
	function Listar_Clientes()
	{
		log_message('INFO','#TRAZA| CLIENTES | Listar_Clientes() >> ');
		$data['list'] = $this->Clientes->Listar_Clientes();
    	$this->load->view('core/clientes/list', $data);
	}

    /**
	* Guarda cliente
	* @param array cliente
	* @return bool true o false segun resultado de servicio de guardado
	*/
	function Guardar_Cliente()
	{
		$cliente = $this->input->post('datos');
		$cliente['usuario_app'] = userNick();
		$cliente['empr_id'] = empresa();
		$resp = $this->Clientes->Guardar_Cliente($cliente);
		echo json_encode($resp);
    	log_message('ERROR', '#TRAZA | CLIENTES | guardar() >> $cliente_id: '.$cliente);
	}

	/**
	* Edita info de Cliente
	* @param array con informacion de Cliente
	* @return bool true o false respuesta del servicio
	*/
	function Editar_Cliente()
	{
    log_message('INFO','#TRAZA | CLIENTES | Editar_Cliente() >> ');
		$cliente = $this->input->post('datos');
		$cliente['usuario_app'] = userNick();
		$resp = $this->Clientes->Editar_Cliente($cliente);
		echo json_encode($resp);
	}

	/**
	* Borra Cliente por id
	* @param
	* @return bool true o false
	*/
	public function Borrar_Cliente()
	{
		log_message('INFO','#TRAZA | CLIENTES | Borrar_Cliente() >> ');
		$clie_id = $this->input->post('clie_id');
		$result = $this->Clientes->Borrar_Cliente($clie_id);
		echo json_encode($result);
	}
}    