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
    	log_message('ERROR', '#TRAZA | VALORES | guardarEstablecimiento() >> ');
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
		log_message('INFO','#TRAZA | CLIENTES | borrarEstablecimiento() >> ');
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
    	log_message('ERROR', '#TRAZA | VALORES | guardarEdicionEstablecimiento() >> ');
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

}