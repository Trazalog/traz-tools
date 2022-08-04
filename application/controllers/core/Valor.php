<?php defined('BASEPATH') OR exit('No direct script access allowed');

class Valor extends CI_Controller 
{
    function __construct(){
      parent::__construct();
      $this->load->model('core/Valores');    
    } 

    /**
	 *  Muestra el ABM de lista de valores.
	 *
	 * @param
	 * @return  void
	 */
    function index()
	{
      	log_message('INFO','#TRAZA | VALORES | index()  >> ');
	  	$data['listarValores'] = $this->Valores->Listar_Valores();
	  	$data['listarEmpresas'] = $this->Valores->Listar_Empresas();
      	$this->load->view('core/valores/view', $data);
    }
    
 	/**
     * Devuelve un listado de los Valores.
     *
     * @return  Array  Devuelve un arreglo con los Valores.
     */
	function Listar_Valores()
	{
		log_message('INFO','#TRAZA| VALORES | Listar_Valores() >> ');
    	$this->load->view('core/valores/list', $data);
	}

	/**
	* Obtener contenido de una lista
	* @param array lista
	* @return bool true o false segun resultado de servicio de guardado
	*/
	function getValor()
	{
		log_message('INFO','#TRAZA| VALORES | getValor() >> ');
		$tabla = $this->input->post('id_tabla');
		$resp = $this->Valores->getValor($tabla);
		if ($resp != null) {
			echo json_encode($resp);
		} else {
			echo json_encode($resp);
		}
	}

    /**
	* Guarda valor de lista
	* @param array valor de lista
	* @return bool true o false segun resultado de servicio de guardado
	*/
	function guardarValor()
	{
    	log_message('ERROR', '#TRAZA | VALORES | guardarValor() >> ');
		$valor = $this->input->post('datos');
		$resp = $this->Valores->guardarValor($valor);
		if ($resp != null) {
			return json_encode(true);
		} else {
			return json_encode(false);
		}
	}

	function editarValor()
	{
    	log_message('ERROR', '#TRAZA | VALORES | guardarValor() >> ');
		$valor = $this->input->post('datos');
		$resp = $this->Valores->editarValor($valor);
		if ($resp != null) {
			return json_encode(true);
		} else {
			return json_encode(false);
		}
	}

	/**
	* Borrado lógico de valor por ID
	* @param
	* @return bool true o false
	*/
	public function borrarValor()
	{
		log_message('INFO','#TRAZA | VALORES | borrarValor() >> ');
		$tabl_id = $this->input->post('tabl_id');
		$result = $this->Valores->borrarValor($tabl_id);
		echo json_encode($result);
	}
}    