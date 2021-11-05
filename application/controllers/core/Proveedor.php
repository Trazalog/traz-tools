<?php defined('BASEPATH') OR exit('No direct script access allowed');

class Proveedor extends CI_Controller
{
    function __construct(){
      parent::__construct();
      $this->load->model('core/Proveedores');
    }

    /**
	 *  Muestra el ABM de lista de proveedores.
	 *
	 * @param
	 * @return  void
	 */
    public function index()
	{
      	log_message('INFO','#TRAZA | PROVEEDORES | index()  >> ');
	  	// $data['listarProveedores'] = $this->Proveedores->listarProveedores();
		$data['listarPaises'] = $this->Proveedores->listarPaises();
      	$this->load->view('core/proveedores/view', $data);
    }

	/**
     * Devuelve un listado de los Proveedores.
     *
     * @return  Array  Devuelve un arreglo con los Proveedores.
     */
	public function listarProveedores()
	{
		log_message('INFO','#TRAZA| PROVEEDORES | listarProveedores() >> ');
		$data['listarProveedores'] = $this->Proveedores->listarProveedores();
		$data['listarPaises'] = $this->Proveedores->listarPaises();
    	$this->load->view('core/proveedores/list', $data);
	}

	public function getEstados()
	{
		log_message('INFO','#TRAZA| ESTABLECIMIENTO | getEstados() >> ');
		$pais = $this->input->get('id_pais');
		$resp = $this->Proveedores->getEstados($pais);
		// foreach ($resp as $res)
		// {
		// 	$estados[] = $res['tabl_id'];
		// }
		if ($resp != null) {
			echo json_encode($resp);
		} else {
			echo json_encode($resp);
		}
	}

	public function getLocalidades()
	{
		log_message('INFO','#TRAZA| ESTABLECIMIENTO | getLocalidades() >> ');
		$pais = $this->input->get('id_pais');
		$estado = $this->input->get('id_estado');
		$resp = $this->Proveedores->getLocalidades($pais, $estado);
		if ($resp != null) {
			echo json_encode($resp);
		} else {
			echo json_encode($resp);
		}
	}

	  /**
	* Guarda proveedor nuevo
	* @param array proveedor nuevo
	* @return bool true o false segun resultado de servicio de guardado
	*/
	public function guardarProveedor()
	{
    	log_message('ERROR', '#TRAZA | PROVEEDORES | guardarProveedor() >> ');
		$valor = $this->input->post('datos');
		// $valor['usuario'] = userNick();
		$valor['empr_id'] = empresa();
		$result = $this->Proveedores->guardarProveedor($valor);
        echo json_encode($result);
		// if ($resp != null) {
		// 	return json_encode(true);
		// } else {
		// 	return json_encode(false);
		// }
	}

	/**
	* Borra Proveedor por id
	* @param
	* @return bool true o false
	*/
	public function borrarProveedor()
	{
		log_message('INFO','#TRAZA | PROVEEDORES | borrarProveedor() >> ');
		$prov_id = $this->input->post('id');
		$result = $this->Proveedores->borrarProveedor($prov_id);
		echo json_encode($result);
	}

	  /**
	* Guarda proveedor editado
	* @param array proveedor editado
	* @return bool true o false segun resultado de servicio de guardado
	*/
	public function guardarEdicionProveedor()
	{
    	log_message('ERROR', '#TRAZA | PROVEEDORES | guardarEdicionProveedor() >> ');
		$valor = $this->input->post('datos');
		// $valor['usuario'] = userNick();
		$valor['estado'] = $this->input->post('estado');
		$valor['localidad'] = $this->input->post('localidad');
		$valor['empr_id'] = empresa();
		$resp = $this->Proveedores->guardarEdicionProveedor($valor);
        echo json_encode($result);
		// if ($resp != null) {
		// 	return json_encode(true);
		// } else {
		// 	return json_encode(false);
		// }
	}

	public function listarDepositosXProveedor() 
	{
		log_message('ERROR', '#TRAZA | PROVEEDORES | listarDepositosXProveedor() >> ');
        $prov_id = $this->input->get('prov_id');
        $empr_id = empresa();
        $resp =  $this->Proveedores->listarDepositosXProveedor($prov_id,$empr_id);
        if ($resp != null) {
			echo json_encode($resp);            
		} else {
			echo json_encode($resp);
		}
    }

	public function guardarDeposito()
	{
		log_message('ERROR', '#TRAZA | PROVEEDORES | guardarDeposito() >> ');
		$data = $this->input->post('datos');
		$data['empr_id'] = empresa();
		$resp = $this->Proveedores->guardarDeposito($data);
        echo json_encode($resp);
	}

	public function borrarDepositoDeProveedor()
	{
		log_message('INFO','#TRAZA | ETAPAS | borrarDepositoDeProveedor() >> ');
		$depo_id = $this->input->post('depo_id');
		$result = $this->Proveedores->borrarDeposito($depo_id);
		// $result = $this->Proveedores->borrarArticuloDeEtapa($depo_id, $tipo);
		echo json_encode($result);
	}

}