<?php defined('BASEPATH') OR exit('No direct script access allowed');

class Establecimiento extends CI_Controller
{
    function __construct(){
      parent::__construct();
      $this->load->model('core/Establecimientos');
    }

    /**
	 *  Muestra el ABM de lista de establecimientos.
	 *
	 * @param
	 * @return  void
	 */
    public function index()
	{
      	log_message('INFO','#TRAZA | ESTABLECIMIENTOS | index()  >> ');
	  	// $data['listarEstablecimientos'] = $this->Establecimientos->listarEstablecimientos();
		$data['listarPaises'] = $this->Establecimientos->listarPaises();
      	$this->load->view('core/establecimientos/view', $data);
    }

	/**
     * Devuelve un listado de los Establecimientos.
     *
     * @return  Array  Devuelve un arreglo con los Establecimientos.
     */
	public function listarEstablecimientos()
	{
		log_message('INFO','#TRAZA| ESTABLECIMIENTOS | listarEstablecimientos() >> ');
		$data['listarEstablecimientos'] = $this->Establecimientos->listarEstablecimientos();
		$data['listarPaises'] = $this->Establecimientos->listarPaises();
    	$this->load->view('core/establecimientos/list', $data);
	}

	public function getEstados()
	{
		log_message('INFO','#TRAZA| ESTABLECIMIENTO | getEstados() >> ');
		$pais = $this->input->get('id_pais');
		$resp = $this->Establecimientos->getEstados($pais);
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
		$resp = $this->Establecimientos->getLocalidades($pais, $estado);
		if ($resp != null) {
			echo json_encode($resp);
		} else {
			echo json_encode($resp);
		}
	}

	  /**
	* Guarda establecimiento nuevo
	* @param array establecimiento nuevo
	* @return bool true o false segun resultado de servicio de guardado
	*/
	public function guardarEstablecimiento()
	{
    	log_message('ERROR', '#TRAZA | ESTABLECIMIENTOS | guardarEstablecimiento() >> ');
		$valor = $this->input->post('datos');
		// $valor['usuario'] = userNick();
		$valor['empr_id'] = empresa();
		$resp = $this->Establecimientos->guardarEstablecimiento($valor);
		if ($resp != null) {
			return json_encode(true);
		} else {
			return json_encode(false);
		}
	}

	/**
	* Borra Establecimiento por id
	* @param
	* @return bool true o false
	*/
	public function borrarEstablecimiento()
	{
		log_message('INFO','#TRAZA | ESTABLECIMIENTOS | borrarEstablecimiento() >> ');
		$esta_id = $this->input->post('esta_id');
		$result = $this->Establecimientos->borrarEstablecimiento($esta_id);
		echo json_encode($result);
	}

	  /**
	* Guarda establecimiento editado
	* @param array establecimiento editado
	* @return bool true o false segun resultado de servicio de guardado
	*/
	public function guardarEdicionEstablecimiento()
	{
    	log_message('ERROR', '#TRAZA | ESTABLECIMIENTOS | guardarEdicionEstablecimiento() >> ');
		$valor = $this->input->post('datos');
		// $valor['usuario'] = userNick();
		$valor['estado'] = $this->input->post('estado');
		$valor['localidad'] = $this->input->post('localidad');
		$valor['empr_id'] = empresa();
		$resp = $this->Establecimientos->guardarEdicionEstablecimiento($valor);
		if ($resp != null) {
			return json_encode(true);
		} else {
			return json_encode(false);
		}
	}

	public function listarDepositosXEstablecimiento() 
	{
		log_message('ERROR', '#TRAZA | ESTABLECIMIENTOS | listarDepositosXEstablecimiento() >> ');
        $esta_id = $this->input->get('esta_id');
        $empr_id = empresa();
        $resp =  $this->Establecimientos->listarDepositosXEstablecimiento($esta_id,$empr_id);
        if ($resp != null) {
			echo json_encode($resp);            
		} else {
			echo json_encode($resp);
		}
    }

	public function guardarDeposito()
	{
		log_message('ERROR', '#TRAZA | ESTABLECIMIENTOS | guardarDeposito() >> ');
		$data = $this->input->post('datos');
		$data['empr_id'] = empresa();
		$resp = $this->Establecimientos->guardarDeposito($data);
        echo json_encode($resp);
	}

	public function borrarDepositoDeEstablecimiento()
	{
		log_message('INFO','#TRAZA | ETAPAS | borrarDepositoDeEstablecimiento() >> ');
		$depo_id = $this->input->post('depo_id');
		$result = $this->Establecimientos->borrarDeposito($depo_id);
		// $result = $this->Establecimientos->borrarArticuloDeEtapa($depo_id, $tipo);
		echo json_encode($result);
	}

}